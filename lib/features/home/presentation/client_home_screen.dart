import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/chat/presentation/chat_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_vehicle.dart';
import 'package:majichrono/features/delivery/domain/entities/majunga_places.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/providers/location_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/delivery/presentation/widgets/city_map.dart';
import 'package:majichrono/features/delivery/presentation/widgets/vehicle_picker.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_center_provider.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Accueil de l'expediteur.
///
/// MajiChrono est une plateforme de **livraison** : l'accueil est construit
/// pour qu'un envoi parte en quelques gestes. La carte de Majunga situe
/// l'expediteur ; la feuille du bas porte l'action principale (envoyer un
/// colis), le choix du vehicule — qui ouvre l'assistant deja regle dessus — et
/// les dernieres livraisons a suivre.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final MapController _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _recenter(GeoPoint? me) {
    final target = me ?? MajungaZone.center;
    _map.move(LatLng(target.latitude, target.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentPositionProvider).valueOrNull;
    final active = ref.watch(activeDeliveriesProvider);

    // La position arrive apres l'affichage de la carte (GPS a froid) : on la
    // centre alors sur l'expediteur, une seule fois.
    ref.listen(currentPositionProvider, (previous, next) {
      final position = next.valueOrNull;
      if (position != null && previous?.valueOrNull == null) {
        try {
          _map.move(LatLng(position.latitude, position.longitude), 15);
        } on Object {
          // Carte pas encore montee : elle s'ouvrira deja centree dessus.
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CityMap(
              controller: _map,
              center: me ?? MajungaZone.center,
              me: me,
              // La feuille du bas recouvre le coin habituel : la mention du
              // fournisseur se place en haut a droite, sous les boutons.
              attributionAlignment: Alignment.topRight,
              attributionPadding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 84,
                right: AppSpacing.sm,
              ),
            ),
          ),
          const _TopBar(),
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            snap: true,
            builder: (context, scroll) => _CommandSheet(
              scroll: scroll,
              active: active.isEmpty ? null : active.first,
              onRecenter: () => _recenter(me),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final name = switch (auth) {
      AuthAuthenticated(:final account) => account.displayName,
      _ => '',
    };
    final first = name.trim().split(' ').first;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (items) => items.fold<int>(0, (sum, c) => sum + c.unread),
          orElse: () => 0,
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: _Pill(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          first.isEmpty ? 'M' : first[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          first.isEmpty
                              ? l10n.homeHelloAnonymous
                              : l10n.homeHello(first),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundAction(
              icon: Icons.forum_outlined,
              badge: unreadMessages,
              tooltip: l10n.messagesTitle,
              onTap: () => context.push(AppRoutes.messages),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundAction(
              icon: Icons.settings_outlined,
              tooltip: l10n.settingsTitle,
              onTap: () => context.push(AppRoutes.settings),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundAction(
              icon: Icons.notifications_none_rounded,
              badge: unreadNotifications,
              tooltip: l10n.notifCenterTitle,
              onTap: () => context.push(AppRoutes.notifications),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }
}

/// Pastille bleue de la charte, posee sur la carte.
class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: AppRadii.pillAll,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) => _Pill(
    child: Badge(
      isLabelVisible: badge > 0,
      backgroundColor: AppColors.accent,
      textColor: AppColors.primaryDark,
      label: Text(badge > 99 ? '99+' : '$badge'),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    ),
  );
}

class _CommandSheet extends ConsumerWidget {
  const _CommandSheet({
    required this.scroll,
    required this.active,
    required this.onRecenter,
  });

  final ScrollController scroll;
  final Delivery? active;
  final VoidCallback onRecenter;

  void _send(BuildContext context, [DeliveryVehicle? vehicle]) {
    HapticFeedback.selectionClick();
    context.push(AppRoutes.clientNewDelivery, extra: vehicle);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deliveries = ref.watch(deliveriesProvider).valueOrNull;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: AppRadii.pillAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeServicesTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l10n.homeRecenter,
                onPressed: onRecenter,
                icon: Icon(
                  Icons.my_location_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (active != null) ...[
            _ActiveDeliveryBanner(delivery: active!),
            const SizedBox(height: AppSpacing.md),
          ],
          _SendParcelCard(onTap: () => _send(context)),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.homeVehiclesTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.82,
            children: [
              for (final vehicle in DeliveryVehicle.values)
                _VehicleShortcut(
                  vehicle: vehicle,
                  onTap: () => _send(context, vehicle),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeMyDeliveries,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.clientDeliveries),
                child: Text(l10n.commonSeeAll),
              ),
            ],
          ),
          if (deliveries == null)
            const SizedBox(height: 120, child: McSkeletonList(itemCount: 1))
          else if (deliveries.isEmpty)
            McEmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.emptyDeliveries,
              message: l10n.homeSendParcelHint,
              actionLabel: l10n.emptyDeliveriesAction,
              onAction: () => _send(context),
            )
          else
            for (final delivery in deliveries.take(3)) ...[
              DeliveryCard(delivery: delivery),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

/// Action principale de l'accueil : envoyer un colis.
class _SendParcelCard extends StatelessWidget {
  const _SendParcelCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      borderRadius: AppRadii.cardAll,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.primaryDark,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeSendParcel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.homeSendParcelHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Raccourci vers l'assistant d'envoi, deja regle sur un vehicule.
class _VehicleShortcut extends StatelessWidget {
  const _VehicleShortcut({required this.vehicle, required this.onTap});

  final DeliveryVehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: vehicle.label(l10n),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: AppRadii.cardAll,
        child: InkWell(
          borderRadius: AppRadii.cardAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(vehicle.icon, size: 30, color: scheme.primary),
                const SizedBox(height: 6),
                // Un mot ne se coupe jamais en deux : le libelle retrecit
                // plutot, sur une ou deux lignes coupees entre les mots.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    vehicle.label(l10n).replaceFirst(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDeliveryBanner extends StatelessWidget {
  const _ActiveDeliveryBanner({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = delivery.vehicle;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: AppColors.accent.withValues(alpha: 0.18),
      borderRadius: AppRadii.cardAll,
      child: InkWell(
        borderRadius: AppRadii.cardAll,
        onTap: () => context.push(AppRoutes.clientTracking(delivery.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(
                  vehicle?.icon ?? Icons.inventory_2_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeActiveRide,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      delivery.dropoff.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                l10n.homeOpenRide,
                style: TextStyle(fontWeight: FontWeight.w800, color: primary),
              ),
              Icon(Icons.chevron_right_rounded, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
