import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/features/driver/presentation/widgets/available_delivery_card.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_app_header.dart';
import 'package:majichrono/shared/widgets/mc_delivery_card.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Accueil livreur : interrupteur de service, course en cours, file d'attente.
///
/// L'ordre suit la question que se pose un livreur quand il ouvre l'application :
/// suis-je en service, qu'ai-je a faire maintenant, et sinon qu'y a-t-il a
/// prendre.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  Timer? _refresh;

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  /// Renouvelle la file a l'expiration de la fenetre d'acceptation.
  ///
  /// Sans ce renouvellement, les propositions restaient affichees avec un
  /// bouton mort une fois le compte a rebours ecoule : le livreur se retrouvait
  /// devant un mur d'offres perimees, sans autre issue qu'un tirer-pour-
  /// rafraichir qu'il ne devine pas.
  ///
  /// La cadence suit le **profil reseau mesure**, comme le suivi client
  /// (EXI-C20) : en 2G, rafraichir toutes les 30 s couterait du forfait pour
  /// une file qui n'a pas eu le temps de changer (§4.4).
  void _scheduleRefresh({required bool online}) {
    _refresh?.cancel();
    if (!online) return;

    final profile =
        ref.read(networkStatusProvider).valueOrNull?.profile ??
        NetworkProfile.threeG;
    final interval = profile.trackingRefreshInterval > _acceptanceWindow
        ? profile.trackingRefreshInterval
        : _acceptanceWindow;

    _refresh = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() => _cycle++);
      ref.invalidate(availableDeliveriesProvider);
    });
  }

  /// Numero du cycle de rafraichissement.
  ///
  /// Il entre dans la cle de chaque carte, et c'est indispensable : sans cle
  /// distincte, Flutter **recycle l'objet `State`** de la carte occupant la
  /// meme position dans la liste. Le compte a rebours, porte par cet etat, ne
  /// repartait donc jamais de 30 s : la file se renouvelait bien, mais tous les
  /// boutons restaient desactives. Le defaut n'etait visible qu'a l'ecran, une
  /// fois la premiere fenetre ecoulee.
  int _cycle = 0;

  static const Duration _acceptanceWindow = Duration(seconds: 30);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(driverOnlineProvider);
    final active = ref.watch(activeDriverDeliveryProvider);
    final offers = ref.watch(availableDeliveriesProvider);

    // Le minuteur suit l'etat de service : arme a la mise en ligne, desarme
    // des le passage hors service, pour ne pas interroger le serveur au repos.
    ref.listen<bool>(
      driverOnlineProvider,
      (_, next) => _scheduleRefresh(online: next),
    );
    if (online && _refresh == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scheduleRefresh(online: true),
      );
    }

    final network = ref.watch(networkStatusProvider);
    final connected = network.valueOrNull?.isOnline ?? false;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final name = _driverName(ref);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          McAppHeader(
            greeting: name != null
                ? l10n.authWelcome(name)
                : l10n.driverHomeTitle,
            subtitle: l10n.roleDriver,
            statusLabel: connected
                ? l10n.networkOnline
                : (pending > 0
                      ? l10n.networkOfflinePending(pending)
                      : l10n.networkOfflineNoPending),
            statusIcon: connected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            statusOnline: connected,
            actions: [
              IconButton(
                tooltip: l10n.messagesTitle,
                icon: const Icon(Icons.forum_outlined, color: Colors.white),
                onPressed: () => context.push(AppRoutes.messages),
              ),
              IconButton(
                tooltip: l10n.settingsTitle,
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(availableDeliveriesProvider),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const _OnlineSwitch(),
                  const SizedBox(height: AppSpacing.md),
                  const _DashboardStats(),
                  const SizedBox(height: AppSpacing.lg),
                  if (active != null) ...[
                    McSectionHeader(title: l10n.driverActiveDelivery),
                    const SizedBox(height: AppSpacing.sm),
                    McDeliveryCard(
                      statusLabel: statusLabel(l10n, active.status),
                      statusIcon: statusIcon(active.status),
                      statusTone: statusTone(active.status),
                      origin: active.pickup.summary,
                      destination: active.dropoff.summary,
                      accent: AppColors.primaryLight,
                      onTap: () =>
                          context.push(AppRoutes.driverActive(active.id)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  McSectionHeader(title: l10n.driverAvailable),
                  const SizedBox(height: AppSpacing.sm),
                  if (!online)
                    SizedBox(
                      height: 220,
                      child: Card(
                        child: McEmptyState(
                          icon: Icons.toggle_off_outlined,
                          title: l10n.driverOfflineEmpty,
                          message: l10n.driverOfflineHelp,
                        ),
                      ),
                    )
                  else
                    offers.when(
                      loading: () =>
                          const McSkeletonList(itemCount: 2, nested: true),
                      error: (_, _) => SizedBox(
                        height: 200,
                        child: Card(
                          child: McEmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: l10n.driverNoOffers,
                            message: l10n.errorNetwork,
                          ),
                        ),
                      ),
                      data: (all) {
                        // Les offres ecartees a la main ne remontent plus
                        // (EXI-L05, §15).
                        final dismissed = ref.watch(dismissedOffersProvider);
                        final items = all
                            .where(
                              (o) => !dismissed.contains(o.delivery.id),
                            )
                            .toList();
                        return items.isEmpty
                          ? SizedBox(
                              height: 220,
                              child: Card(
                                child: McEmptyState(
                                  icon: Icons.inbox_outlined,
                                  title: l10n.driverNoOffers,
                                  message: l10n.driverNoOffersHelp,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final offer in items) ...[
                                  AvailableDeliveryCard(
                                    key: ValueKey(
                                      '${offer.delivery.id}_$_cycle',
                                    ),
                                    offer: offer,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                              ],
                            );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nom affichable du compte livreur, quand la session en porte un.
  String? _driverName(WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    return switch (auth) {
      AuthAuthenticated(:final account) => account.displayName,
      AuthLocked(:final account) => account.displayName,
      _ => null,
    };
  }
}

/// Tuiles de synthese du tableau de bord (§14) : ce qu'un livreur veut savoir
/// d'un coup d'oeil en ouvrant l'application — combien de courses a prendre,
/// combien en cours, combien terminees aujourd'hui, et son solde.
///
/// Rendu **statique** dans tous les etats (jamais d'indicateur qui tourne) :
/// une tuile qui charge affiche un tiret, pour ne pas animer en boucle ni
/// dependre du reseau au premier plan.
class _DashboardStats extends ConsumerWidget {
  const _DashboardStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(driverOnlineProvider);

    final dismissed = ref.watch(dismissedOffersProvider);
    final offers = ref.watch(availableDeliveriesProvider).valueOrNull;
    final available = offers
        ?.where((o) => !dismissed.contains(o.delivery.id))
        .length;
    final active = ref.watch(activeDriverDeliveriesProvider).length;
    final earnings = ref.watch(earningsProvider).valueOrNull;
    final balance = ref.watch(majiPayBalanceProvider(UserRole.driver)).valueOrNull;

    String orDash(int? v) => v == null ? '—' : '$v';

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.inbox_outlined,
            // Hors service, la file n'est pas interrogee : on montre un tiret
            // plutot qu'un zero trompeur.
            value: online ? orDash(available) : '—',
            label: l10n.dashAvailable,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.local_shipping_outlined,
            value: '$active',
            label: l10n.dashActive,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_outline,
            value: orDash(earnings?.todayCount),
            label: l10n.dashDoneToday,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.account_balance_wallet_outlined,
            value: balance == null
                ? '—'
                : formatAriary(balance.availableAriary),
            label: l10n.dashBalance,
            color: AppColors.primary,
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.dense = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (dense ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur en ligne / hors service (EXI-L03).
class _OnlineSwitch extends ConsumerWidget {
  const _OnlineSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final online = ref.watch(driverOnlineProvider);

    return Card(
      color: online ? AppColors.success.withValues(alpha: 0.10) : null,
      child: SwitchListTile(
        value: online,
        onChanged: (value) =>
            ref.read(driverOnlineProvider.notifier).set(online: value),
        secondary: Icon(
          online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
          color: online
              ? AppColors.success
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          online ? l10n.driverOnline : l10n.driverOffline,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(online ? l10n.driverOnlineHelp : l10n.driverOfflineHelp),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
