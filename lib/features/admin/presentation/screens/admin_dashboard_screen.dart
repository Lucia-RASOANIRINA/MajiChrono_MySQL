import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_app_header.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_error_view.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_stat_tile.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Tableau de bord de l'exploitation (EXI-A01).
///
/// Il repond a une seule question : **qu'est-ce qui demande une action tout de
/// suite ?** Les compteurs sont ranges par urgence — ce qui attend une decision
/// humaine (dossiers, litiges, incidents) d'abord, l'operationnel ensuite, le
/// chiffre d'affaires en dernier. Chaque tuile est cliquable et mene a l'ecran
/// qui permet d'agir, et ne prend une teinte d'alerte que lorsqu'elle reclame
/// vraiment une action : un tableau entierement colore ne signale plus rien.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(adminDashboardProvider);
    final online =
        ref.watch(networkStatusProvider).valueOrNull?.isOnline ?? false;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final name = _adminName(ref);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          McAppHeader(
            greeting: name != null
                ? l10n.authWelcome(name)
                : l10n.adminDashboardTitle,
            subtitle: l10n.roleAdmin,
            statusLabel: online
                ? l10n.networkOnline
                : (pending > 0
                      ? l10n.networkOfflinePending(pending)
                      : l10n.networkOfflineNoPending),
            statusIcon: online
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            statusOnline: online,
            actions: [
              IconButton(
                tooltip: l10n.settingsTitle,
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminDashboardProvider),
              child: summary.when(
                loading: () => const McSkeletonList(itemCount: 5),
                error: (error, _) => ListView(
                  children: [
                    McErrorView(
                      failure: error is Failure
                          ? error
                          : const UnknownFailure(),
                      onRetry: () => ref.invalidate(adminDashboardProvider),
                    ),
                  ],
                ),
                data: (data) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Ce qui attend une decision humaine, d'abord.
                    _Grid(
                      tiles: [
                        McStatTile(
                          icon: Icons.badge_outlined,
                          label: l10n.adminPendingKyc,
                          value: '${data.pendingKyc}',
                          tint: data.pendingKyc > 0 ? AppColors.warning : null,
                          onTap: () => context.push(AppRoutes.adminKyc),
                        ),
                        McStatTile(
                          icon: Icons.gavel_outlined,
                          label: l10n.adminOpenDisputes,
                          value: '${data.openDisputes}',
                          tint: data.openDisputes > 0 ? AppColors.danger : null,
                          onTap: () => context.go(AppRoutes.adminDisputes),
                        ),
                        McStatTile(
                          icon: Icons.report_problem_outlined,
                          label: l10n.adminOpenIncidents,
                          value: '${data.openIncidents}',
                          tint: data.openIncidents > 0
                              ? AppColors.warning
                              : null,
                          onTap: () => context.push(AppRoutes.adminDeliveries),
                        ),
                        McStatTile(
                          icon: Icons.local_shipping_outlined,
                          label: l10n.adminActiveDeliveries,
                          value: '${data.activeDeliveries}',
                          tint: AppColors.info,
                          onTap: () => context.push(AppRoutes.adminDeliveries),
                        ),
                        McStatTile(
                          icon: Icons.two_wheeler_outlined,
                          label: l10n.adminOnlineDrivers,
                          value: '${data.onlineDrivers}',
                          tint: AppColors.success,
                          onTap: () => context.go(AppRoutes.adminFleet),
                        ),
                        McStatTile(
                          icon: Icons.payments_outlined,
                          label: l10n.adminRevenueToday,
                          value: formatAriary(data.revenueTodayAriary),
                          tint: AppColors.accent,
                        ),
                        McStatTile(
                          icon: Icons.people_outline,
                          label: l10n.adminTotalClients,
                          value: '${data.totalClients}',
                          onTap: () => context.push(
                            '${AppRoutes.adminUsers}?role=client',
                          ),
                        ),
                        McStatTile(
                          icon: Icons.badge_outlined,
                          label: l10n.adminTotalDrivers,
                          value: '${data.totalDrivers}',
                          onTap: () => context.push(
                            '${AppRoutes.adminUsers}?role=driver',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.query_stats_outlined),
                        title: Text(l10n.adminStatsManage),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.adminStats),
                      ),
                    ),
                    if (data.byStatus.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      McSectionHeader(title: l10n.adminByStatus),
                      const SizedBox(height: AppSpacing.md),
                      _StatusBreakdown(byStatus: data.byStatus),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _adminName(WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    return switch (auth) {
      AuthAuthenticated(:final account) => account.displayName,
      AuthLocked(:final account) => account.displayName,
      _ => null,
    };
  }
}

/// Grille de tuiles a deux colonnes, hauteurs egalisees par rangee.
class _Grid extends StatelessWidget {
  const _Grid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: right ?? const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Repartition des courses par statut.
///
/// Un total de courses actives ne dit rien : vingt courses en attente
/// d'acceptation et vingt courses en transit decrivent deux journees opposees,
/// l'une ou il manque des livreurs, l'autre ou tout roule.
class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.byStatus});

  final Map<DeliveryStatus, int> byStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = byStatus.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return McCard(
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  McStatusBadge(
                    label: statusLabel(l10n, entry.key),
                    icon: statusIcon(entry.key),
                    tone: statusTone(entry.key),
                  ),
                  const Spacer(),
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
