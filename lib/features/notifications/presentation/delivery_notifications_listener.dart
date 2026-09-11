import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Emet une notification locale a chaque etape marquante d'une course (EXI-N01).
///
/// Faute de push distant, c'est l'application qui, en observant l'avancement des
/// courses de l'utilisateur, declenche les notifications : « course acceptee »,
/// « colis recupere », « livraison terminee »... Chaque notification ouvre le
/// suivi de la course concernee (EXI-N04) et vient garnir le centre de
/// notifications.
///
/// Il vit haut dans l'arbre, sous `MaterialApp` (donc avec les traductions) et
/// sous le service de notifications (deja arme). Le premier chargement ne
/// notifie rien : on ne previent que d'un **changement**, pas de l'existant.
class DeliveryNotificationsListener extends ConsumerStatefulWidget {
  const DeliveryNotificationsListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeliveryNotificationsListener> createState() =>
      _DeliveryNotificationsListenerState();
}

class _DeliveryNotificationsListenerState
    extends ConsumerState<DeliveryNotificationsListener> {
  /// Dernier statut connu de chaque course. Sert a ne notifier qu'un vrai
  /// changement, et jamais deux fois le meme.
  final Map<String, DeliveryStatus> _seen = {};
  bool _primed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Delivery>>>(deliveriesProvider, (_, next) {
      final list = next.valueOrNull;
      if (list == null) return;

      // Premier chargement : on enregistre l'existant sans rien annoncer.
      if (!_primed) {
        for (final delivery in list) {
          _seen[delivery.id] = delivery.status;
        }
        _primed = true;
        return;
      }

      for (final delivery in list) {
        final previous = _seen[delivery.id];
        if (previous == delivery.status) continue;
        _seen[delivery.id] = delivery.status;
        // On ne notifie qu'une **transition** d'une course deja vue : une course
        // qui apparait (creation) ne declenche rien.
        if (previous != null) _notify(delivery);
      }
    });

    return widget.child;
  }

  void _notify(Delivery delivery) {
    final l10n = AppLocalizations.of(context);
    final content = _contentFor(delivery.status, l10n);
    if (content == null) return;

    final (title, body, channel) = content;
    unawaitedShow(
      AppNotification(
        channel: channel,
        title: title,
        body: body,
        route: _routeFor(delivery.id),
        // Un id stable par course : deux mises a jour d'une meme course se
        // remplacent dans la barre systeme au lieu de s'empiler.
        id: delivery.id.hashCode & 0x7fffffff,
      ),
    );
  }

  void unawaitedShow(AppNotification notification) {
    // Le canal commercial est le seul desactivable ; les autres passent toujours.
    final commercialEnabled = ref.read(commercialNotificationsProvider);
    ref.read(notificationServiceProvider).show(
      notification,
      commercialEnabled: commercialEnabled,
    );
  }

  /// Lien profond vers le suivi de la course, selon le profil courant.
  String? _routeFor(String deliveryId) {
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return null;
    return switch (auth.account.role) {
      UserRole.driver => AppRoutes.driverActive(deliveryId),
      _ => AppRoutes.clientTracking(deliveryId),
    };
  }

  (String, String, McNotificationChannel)? _contentFor(
    DeliveryStatus status,
    AppLocalizations l10n,
  ) => switch (status) {
    DeliveryStatus.accepted => (
      l10n.notifEventAcceptedTitle,
      l10n.notifEventAcceptedBody,
      McNotificationChannel.courses,
    ),
    DeliveryStatus.pickedUp => (
      l10n.notifEventPickedUpTitle,
      l10n.notifEventPickedUpBody,
      McNotificationChannel.courses,
    ),
    DeliveryStatus.inTransit => (
      l10n.notifEventInTransitTitle,
      l10n.notifEventInTransitBody,
      McNotificationChannel.courses,
    ),
    DeliveryStatus.atDestination => (
      l10n.notifEventArrivedTitle,
      l10n.notifEventArrivedBody,
      McNotificationChannel.courses,
    ),
    DeliveryStatus.delivered || DeliveryStatus.deliveredWithReserves => (
      l10n.notifEventDeliveredTitle,
      l10n.notifEventDeliveredBody,
      McNotificationChannel.courses,
    ),
    DeliveryStatus.paid => (
      l10n.notifEventPaidTitle,
      l10n.notifEventPaidBody,
      McNotificationChannel.payment,
    ),
    DeliveryStatus.cancelled => (
      l10n.notifEventCancelledTitle,
      l10n.notifEventCancelledBody,
      McNotificationChannel.incidents,
    ),
    _ => null,
  };
}
