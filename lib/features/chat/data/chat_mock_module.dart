import 'dart:convert';

import 'package:majichrono/core/network/mock/mock_backend.dart';

/// Routes simulees de la discussion de course (expediteur <-> livreur).
///
/// Le vrai serveur tient ces messages ; sans ce module, le mode simule
/// renverrait 404 et l'ecran de discussion resterait vide. Comme un seul
/// appareil ne porte qu'une identite a la fois, la conversation a deux serait
/// invisible : on ajoute donc une **reponse automatique** du livreur apres
/// chaque message, pour que la discussion se voie vraiment des deux cotes en
/// demonstration.
class ChatMockModule extends MockModule {
  /// Messages par course.
  final Map<String, List<Map<String, dynamic>>> _threads = {};
  int _sequence = 0;

  /// Identite du « livreur » simule, distincte de l'utilisateur : c'est elle qui
  /// fait qu'une bulle s'affiche du cote oppose.
  static const String _botId = 'usr_livreur';

  static const List<String> _replies = [
    'Bien recu, j\'arrive !',
    'Je suis en route.',
    'Je serai la dans quelques minutes.',
    'D\'accord, merci.',
    'Je vous appelle en arrivant.',
  ];

  @override
  void register(MockBackend backend) {
    backend.get('/conversations', _conversations);
    backend.get('/deliveries/{id}/messages', _list);
    backend.post('/deliveries/{id}/messages', _send);
    backend.post('/deliveries/{id}/messages/read', _markRead);
  }

  /// Boite de reception simulee : une entree par course ayant au moins un
  /// message, la plus recente en tete, avec le dernier message et les non-lus.
  Future<MockResponse> _conversations(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final me = _currentUser(req);
    final items = <Map<String, dynamic>>[];
    for (final entry in _threads.entries) {
      final thread = entry.value;
      if (thread.isEmpty) continue;
      final last = thread.last;
      final unread = thread
          .where((m) => m['senderId'] != me && m['readAt'] == null)
          .length;
      items.add({
        'deliveryId': entry.key,
        // Cote client, l'interlocuteur est le livreur ; cote livreur, le client.
        'counterpartyName': me == _botId ? 'Client' : 'Livreur',
        'lastMessage': '${last['body'] ?? ''}',
        'lastSenderId': last['senderId'],
        'lastAt': '${last['createdAt']}',
        'unread': unread,
      });
    }
    items.sort(
      (a, b) => '${b['lastAt']}'.compareTo('${a['lastAt']}'),
    );
    return MockResponse.ok({'items': items});
  }

  @override
  Future<void> reset() async {
    _threads.clear();
    _sequence = 0;
  }

  List<Map<String, dynamic>> _thread(String id) =>
      _threads.putIfAbsent(id, () => []);

  /// Identifiant de l'utilisateur courant, tire du jeton (comme le module
  /// d'authentification : un JSON base64url dont le champ `sub` porte l'id).
  String _currentUser(MockRequest req) {
    try {
      final token = req.bearer;
      if (token == null || token.isEmpty) return 'usr_client';
      final claims =
          jsonDecode(utf8.decode(base64Url.decode(token)))
              as Map<String, dynamic>;
      return '${claims['sub'] ?? 'usr_client'}';
    } on Object {
      return 'usr_client';
    }
  }

  Future<MockResponse> _list(MockRequest req, Map<String, String> params) async {
    final thread = _thread(params['id']!);
    return MockResponse.ok({'items': List<Map<String, dynamic>>.from(thread)});
  }

  Future<MockResponse> _send(MockRequest req, Map<String, String> params) async {
    final id = params['id']!;
    final thread = _thread(id);
    final me = _currentUser(req);
    final now = DateTime.now();

    final message = {
      'id': 'msg_${++_sequence}',
      'senderId': me,
      'body': '${req.json['body'] ?? ''}',
      'createdAt': now.toUtc().toIso8601String(),
      'readAt': null,
    };
    thread.add(message);

    // Reponse automatique du livreur, une seconde plus tard, pour que la
    // discussion se lise des deux cotes. Ignoree si c'est le livreur qui ecrit.
    if (me != _botId) {
      thread.add({
        'id': 'msg_${++_sequence}',
        'senderId': _botId,
        'body': _replies[_sequence % _replies.length],
        'createdAt': now
            .add(const Duration(seconds: 1))
            .toUtc()
            .toIso8601String(),
        'readAt': null,
      });
    }

    return MockResponse.ok(message);
  }

  Future<MockResponse> _markRead(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final me = _currentUser(req);
    final now = DateTime.now().toUtc().toIso8601String();
    // On accuse reception des messages **recus** (ceux de l'autre partie).
    for (final message in _thread(params['id']!)) {
      if (message['senderId'] != me && message['readAt'] == null) {
        message['readAt'] = now;
      }
    }
    return MockResponse.ok({'ok': true});
  }
}
