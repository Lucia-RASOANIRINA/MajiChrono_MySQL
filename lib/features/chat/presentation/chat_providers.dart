import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';

/// Une conversation dans la boite de reception (espace « Messages »).
///
/// Une conversation = une course ayant une discussion. On n'en tient pas de fil
/// autonome : coordonner une livraison est la seule raison d'ecrire.
class Conversation {
  const Conversation({
    required this.deliveryId,
    required this.counterpartyName,
    required this.lastMessage,
    required this.lastAt,
    required this.unread,
    this.lastSenderId,
  });

  final String deliveryId;
  final String counterpartyName;
  final String lastMessage;
  final DateTime lastAt;
  final int unread;
  final String? lastSenderId;

  bool get hasUnread => unread > 0;

  static Conversation? fromJson(Map<String, dynamic> json) {
    final id = json['deliveryId'] as String?;
    if (id == null) return null;
    return Conversation(
      deliveryId: id,
      counterpartyName: '${json['counterpartyName'] ?? ''}',
      lastMessage: '${json['lastMessage'] ?? ''}',
      lastAt:
          DateTime.tryParse('${json['lastAt']}')?.toLocal() ?? DateTime.now(),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      lastSenderId: json['lastSenderId'] as String?,
    );
  }
}

/// Boite de reception : la liste des conversations, relue a chaque ouverture de
/// l'espace « Messages ».
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) async {
    final res = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(ApiEndpoints.conversations);
    return (res['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .whereType<Conversation>()
        .toList();
  },
);

/// Un message de la discussion d'une course.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  /// Pose quand l'autre partie a lu le message. Nul tant qu'il reste
  /// « envoye » : c'est ce que porte le double crochet de l'accuse de lecture.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    readAt: json['readAt'] != null
        ? DateTime.parse(json['readAt'] as String)
        : null,
  );
}

/// Etat de la discussion : les messages, le premier chargement, l'envoi en
/// cours, et une eventuelle erreur reseau — que l'ecran affiche sans masquer
/// les messages deja lus.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final Object? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    Object? error,
    bool clearError = false,
  }) => ChatState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Pilote une discussion de course : premier chargement, relecture periodique
/// du nouveau (curseur `after`), et envoi.
///
/// Pas de canal permanent : on relit toutes les trois secondes. La relecture
/// est complete — et non un simple curseur `after` — parce qu'un message deja
/// envoye change encore : l'autre partie le lit, et son accuse de lecture doit
/// remonter. Le curseur ne verrait jamais cette bascule, posee sur un message
/// anterieur. Une discussion de course tient en quelques lignes ; relire le
/// tout est negligeable, et se reprend seul a la reconnexion, la ou un WebSocket
/// tomberait a la premiere zone d'ombre.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._client, this._deliveryId) : super(const ChatState()) {
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  final ApiClient _client;
  final String _deliveryId;
  Timer? _timer;

  String get _path => ApiEndpoints.deliveryMessages(_deliveryId);

  Future<void> _load() async {
    try {
      final items = await _fetch();
      if (mounted) {
        state = state.copyWith(messages: items, loading: false, clearError: true);
      }
      // Ouvrir la discussion vaut lecture : on pose l'accuse pour l'autre.
      unawaited(markRead());
    } catch (error) {
      if (mounted) state = state.copyWith(loading: false, error: error);
    }
  }

  Future<void> _poll() async {
    try {
      final items = await _fetch();
      if (!mounted) return;
      // On ne remplace que si quelque chose a bouge — contenu ou accuse de
      // lecture — pour ne pas relancer un rendu a chaque tour a vide.
      if (_changed(state.messages, items)) {
        state = state.copyWith(messages: items, clearError: true);
      } else if (state.error != null) {
        state = state.copyWith(clearError: true);
      }
      unawaited(markRead());
    } catch (_) {
      // Un echec de relecture est silencieux : le prochain tour reessaie, et
      // les messages deja lus restent a l'ecran.
    }
  }

  Future<List<ChatMessage>> _fetch() async {
    final res = await _client.get<Map<String, dynamic>>(_path);
    return (res['items'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Vrai si la liste relue differe de celle affichee — nouveau message, ou
  /// accuse de lecture pose depuis.
  bool _changed(List<ChatMessage> current, List<ChatMessage> fresh) {
    if (current.length != fresh.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != fresh[i].id ||
          current[i].readAt != fresh[i].readAt) {
        return true;
      }
    }
    return false;
  }

  /// Pose l'accuse de lecture sur les messages recus. Silencieux : un echec ne
  /// derange pas l'utilisateur, le prochain tour reessaie.
  Future<void> markRead() async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiEndpoints.deliveryMessagesRead(_deliveryId),
      );
    } catch (_) {
      // Sans consequence : l'accuse se reposera au tour suivant.
    }
  }

  Future<bool> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return false;
    state = state.copyWith(sending: true, clearError: true);
    try {
      final res = await _client.post<Map<String, dynamic>>(
        _path,
        body: {'body': text},
      );
      final message = ChatMessage.fromJson(res);
      state = state.copyWith(
        messages: [...state.messages, message],
        sending: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(sending: false, error: error);
      return false;
    }
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Une discussion par course. `autoDispose` : la relecture periodique s'arrete
/// des que l'ecran se ferme.
final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(
      (ref, deliveryId) =>
          ChatController(ref.watch(apiClientProvider), deliveryId),
    );
