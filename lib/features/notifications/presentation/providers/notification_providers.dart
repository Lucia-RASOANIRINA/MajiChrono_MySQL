import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/notifications/data/notification_service.dart';

/// Le service d'affichage des notifications, partage dans toute l'application.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Preference « recevoir les annonces commerciales » (EXI-N03). Persistee, vraie
/// par defaut ; l'utilisateur peut la couper sans toucher aux canaux
/// operationnels.
class CommercialNotificationsController extends Notifier<bool> {
  static const _key = 'notif_commercial_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true;
  }

  Future<void> set({required bool enabled}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

final commercialNotificationsProvider =
    NotifierProvider<CommercialNotificationsController, bool>(
      CommercialNotificationsController.new,
    );
