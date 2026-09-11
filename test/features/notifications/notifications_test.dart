import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_providers.dart';

void main() {
  test('les identifiants de canaux sont stables et uniques', () {
    final ids = McNotificationChannel.values.map((c) => c.id).toList();
    // Uniques : le systeme lie les preferences de l'utilisateur a ces ids.
    expect(ids.toSet().length, ids.length);
    // Stables : figes pour ne pas orpheliner les reglages deja poses.
    expect(McNotificationChannel.courses.id, 'mc_courses');
    expect(McNotificationChannel.commercial.id, 'mc_commercial');
  });

  test('preference commerciale : vraie par defaut, persistee a faux', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(commercialNotificationsProvider), isTrue);

    await container
        .read(commercialNotificationsProvider.notifier)
        .set(enabled: false);

    expect(container.read(commercialNotificationsProvider), isFalse);
    expect(prefs.getBool('notif_commercial_enabled'), isFalse);
  });
}
