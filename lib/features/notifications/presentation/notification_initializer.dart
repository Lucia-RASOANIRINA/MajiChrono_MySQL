import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/router/app_router.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/features/notifications/data/notification_service.dart';
import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';
import 'package:majichrono/features/notifications/domain/entities/center_notification.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_center_provider.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Branche le service de notifications dans l'arbre, sous `MaterialApp`.
///
/// Il vit ici, et pas dans l'amorcage, parce qu'il a besoin de deux choses que
/// seul l'arbre fournit : les libelles de canaux **traduits** (donc un contexte
/// localise) et le **routeur** pour ouvrir le lien profond d'une notification
/// touchee (EXI-N04). A chaque changement de langue, les noms de canaux sont
/// refaits pour suivre la langue du compte (EXI-N05).
class NotificationInitializer extends ConsumerStatefulWidget {
  const NotificationInitializer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationInitializer> createState() =>
      _NotificationInitializerState();
}

class _NotificationInitializerState
    extends ConsumerState<NotificationInitializer> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le plugin de notifications n'existe que sur mobile : sur un hote de test
    // ou de bureau, ses appels levent une erreur synchrone. On ne cable donc
    // rien hors Android / iOS.
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // `didChangeDependencies` se rejoue au changement de langue : on en profite
    // pour reconfigurer les noms de canaux.
    final l10n = AppLocalizations.of(context);
    final channels = _channelStrings(l10n);
    final service = ref.read(notificationServiceProvider);

    if (!_started) {
      _started = true;
      _bootstrap(channels);
    } else {
      service.configureChannels(channels);
    }
  }

  Future<void> _bootstrap(
    Map<McNotificationChannel, NotificationChannelStrings> channels,
  ) async {
    final service = ref.read(notificationServiceProvider);
    // Chaque notification affichee vient garnir le centre de notifications, qui
    // en garde l'historique et l'etat de lecture (EXI-N06).
    service.onShown = (notification) => ref
        .read(notificationCenterProvider.notifier)
        .add(CenterNotification.fromDisplayed(notification));
    try {
      await service.init(
        onSelectRoute: (route) => ref.read(routerProvider).go(route),
        channels: channels,
      );
      // Demarrage a froid depuis une notification : on ouvre son ecran.
      final launchRoute = await service.launchRoute();
      if (launchRoute != null && launchRoute.isNotEmpty && mounted) {
        ref.read(routerProvider).go(launchRoute);
      }
      await service.requestPermission();
      // Capture large et volontaire : sur un hote sans plugin (tests) ou une
      // plateforme non geree, l'initialisation peut lever une Error autant
      // qu'une Exception. Une notification qui echoue a s'armer ne doit jamais
      // empecher l'application de demarrer.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stack) {
      AppLogger.instance.error(
        'notification_init_failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Map<McNotificationChannel, NotificationChannelStrings> _channelStrings(
    AppLocalizations l10n,
  ) => {
    McNotificationChannel.courses: NotificationChannelStrings(
      name: l10n.notifChannelCoursesName,
      description: l10n.notifChannelCoursesDesc,
    ),
    McNotificationChannel.payment: NotificationChannelStrings(
      name: l10n.notifChannelPaymentName,
      description: l10n.notifChannelPaymentDesc,
    ),
    McNotificationChannel.incidents: NotificationChannelStrings(
      name: l10n.notifChannelIncidentsName,
      description: l10n.notifChannelIncidentsDesc,
    ),
    McNotificationChannel.commercial: NotificationChannelStrings(
      name: l10n.notifChannelCommercialName,
      description: l10n.notifChannelCommercialDesc,
    ),
  };

  @override
  Widget build(BuildContext context) => widget.child;
}
