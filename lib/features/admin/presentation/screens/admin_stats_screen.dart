import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_stat_tile.dart';

/// Statistiques & rapports (§13, EXI-A08) : volumes, taux, temps, puis trois
/// histogrammes — zones, heures de pointe, performance des livreurs. Les barres
/// sont dessinees a la main : un petit rapport n'a pas besoin d'une dependance
/// graphique, et rester leger sert la charte reseau du projet.
class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminStatsTitle)),
      body: stats.when(
        loading: () => const McSkeletonList(itemCount: 5),
        error: (_, _) => McEmptyState(
          icon: Icons.query_stats_outlined,
          title: l10n.statNoData,
          message: l10n.errorNetwork,
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            await ref.read(adminStatsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              McSectionHeader(title: l10n.statVolumes),
              const SizedBox(height: AppSpacing.md),
              _Grid(
                tiles: [
                  McStatTile(
                    icon: Icons.local_shipping_outlined,
                    label: l10n.statTotalDeliveries,
                    value: '${s.totalDeliveries}',
                    tint: AppColors.info,
                  ),
                  McStatTile(
                    icon: Icons.payments_outlined,
                    label: l10n.statRevenue,
                    value: formatAriary(s.revenueAriary),
                    tint: AppColors.accent,
                  ),
                  McStatTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: l10n.statDriverEarnings,
                    value: formatAriary(s.driverEarningsAriary),
                  ),
                  McStatTile(
                    icon: Icons.schedule,
                    label: l10n.statAvgTime,
                    value: l10n.statMinutes(s.avgDeliveryMinutes),
                  ),
                  McStatTile(
                    icon: Icons.report_problem_outlined,
                    label: l10n.statIncidents,
                    value: '${s.incidents}',
                    tint: s.incidents > 0 ? AppColors.warning : null,
                  ),
                  McStatTile(
                    icon: Icons.gavel_outlined,
                    label: l10n.statDisputes,
                    value: '${s.disputes}',
                    tint: s.disputes > 0 ? AppColors.danger : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              McSectionHeader(title: l10n.statRates),
              const SizedBox(height: AppSpacing.md),
              _RateBar(
                label: l10n.statSuccessRate,
                fraction: s.successRate,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              _RateBar(
                label: l10n.statCancellationRate,
                fraction: s.cancellationRate,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.xl),
              McSectionHeader(title: l10n.statTopZones),
              const SizedBox(height: AppSpacing.md),
              _BarChart(bars: s.topZones, l10n: l10n),
              const SizedBox(height: AppSpacing.xl),
              McSectionHeader(title: l10n.statPeakHours),
              const SizedBox(height: AppSpacing.md),
              _HourHistogram(hours: s.peakHours),
              const SizedBox(height: AppSpacing.xl),
              McSectionHeader(title: l10n.statDriverPerformance),
              const SizedBox(height: AppSpacing.md),
              _BarChart(bars: s.driverPerformance, l10n: l10n, showSub: true),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.md,
    childAspectRatio: 1.6,
    children: tiles,
  );
}

/// Barre de taux, avec le pourcentage en clair : la couleur ne porte jamais
/// seule l'information (EXI-T09).
class _RateBar extends StatelessWidget {
  const _RateBar({
    required this.label,
    required this.fraction,
    required this.color,
  });

  final String label;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (fraction.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '$pct %',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadii.componentAll,
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Histogramme horizontal : une ligne par entree, barre proportionnelle au max.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars, required this.l10n, this.showSub = false});

  final List<StatBar> bars;
  final AppLocalizations l10n;
  final bool showSub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (bars.isEmpty) {
      return Text(
        l10n.statNoData,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.neutral),
      );
    }
    final max = bars.map((b) => b.value).fold(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final bar in bars)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    bar.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadii.componentAll,
                    child: LinearProgressIndicator(
                      value: bar.value / max,
                      minHeight: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  showSub && bar.sub != null
                      ? '${bar.value} · ★${bar.sub}'
                      : '${bar.value}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Histogramme vertical des 24 heures : la hauteur des colonnes dit ou se
/// concentrent les demandes dans la journee.
class _HourHistogram extends StatelessWidget {
  const _HourHistogram({required this.hours});

  final List<StatBar> hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (hours.isEmpty) return const SizedBox.shrink();
    final max = hours.map((h) => h.value).fold(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < hours.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (hours[i].value / max) * 96 + 2,
                      decoration: BoxDecoration(
                        color: hours[i].value == max
                            ? AppColors.accent
                            : AppColors.primary.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Une graduation toutes les six heures : afficher les 24
                    // libelles les rendrait illisibles sur un telephone.
                    if (i % 6 == 0)
                      Text(
                        '${i}h',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.neutral,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
