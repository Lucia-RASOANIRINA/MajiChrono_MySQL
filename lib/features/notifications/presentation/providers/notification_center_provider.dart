import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/notifications/domain/entities/center_notification.dart';

/// Historique des notifications recues (EXI-N06).
///
/// Il est **persiste** : une notification qu'on retrouve le lendemain n'a de
/// valeur que si elle a survecu a la fermeture de l'application. On garde les
/// plus recentes en tete et on plafonne la liste — un centre qui grossit sans
/// fin finit par ralentir l'ouverture sans rien apporter.
class NotificationCenter extends Notifier<List<CenterNotification>> {
  static const _key = 'notification_center';
  static const _max = 50;

  @override
  List<CenterNotification> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CenterNotification.fromJson)
          .whereType<CenterNotification>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _persist() async {
    final raw = jsonEncode(state.map((n) => n.toJson()).toList());
    await ref.read(sharedPreferencesProvider).setString(_key, raw);
  }

  /// Ajoute une notification en tete de liste.
  Future<void> add(CenterNotification notification) async {
    state = [notification, ...state].take(_max).toList();
    await _persist();
  }

  /// Marque une ligne comme lue, sans la retirer : elle reste consultable.
  Future<void> markRead(int index) async {
    if (index < 0 || index >= state.length) return;
    final next = [...state];
    next[index] = next[index].copyWith(read: true);
    state = next;
    await _persist();
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(read: true)).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}

final notificationCenterProvider =
    NotifierProvider<NotificationCenter, List<CenterNotification>>(
      NotificationCenter.new,
    );

/// Nombre de notifications non lues, pour la pastille de la cloche.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCenterProvider).where((n) => !n.read).length;
});
