import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/admin/presentation/widgets/fleet_map.dart';
import 'package:majichrono/features/admin/presentation/widgets/reason_sheet.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_error_view.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Carte de flotte, filtrable par statut (EXI-A02).
///
/// La carte et la liste montrent la meme population, jamais deux populations
/// differentes : le filtre agit sur les deux a la fois. Une carte qui afficherait
/// tout le monde sous une liste filtree ferait compter faux.
class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fleet = ref.watch(adminFleetProvider);
    final filter = ref.watch(fleetFilterProvider);

    // Un seul instant de reference pour la carte et la liste : deux appels
    // separes peuvent tomber de part et d'autre du seuil d'anciennete, et
    // afficher un repere plein sous une ligne qui dit le contraire.
    final now = DateTime.now();

    String label(FleetStatus status) => switch (status) {
      FleetStatus.available => l10n.adminFleetAvailable,
      FleetStatus.busy => l10n.adminFleetBusy,
      FleetStatus.offline => l10n.adminFleetOffline,
      FleetStatus.suspended => l10n.adminFleetSuspended,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminFleetTitle)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.adminFleetAll),
                  selected: filter == null,
                  onSelected: (_) =>
                      ref.read(fleetFilterProvider.notifier).state = null,
                ),
                for (final status in FleetStatus.values) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: Text(label(status)),
                    selected: filter == status,
                    onSelected: (_) =>
                        ref.read(fleetFilterProvider.notifier).state = status,
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: fleet.when(
              loading: () => const McSkeletonList(itemCount: 4),
              error: (error, _) => McErrorView(
                failure: error is Failure ? error : const UnknownFailure(),
                onRetry: () => ref.invalidate(adminFleetProvider),
              ),
              data: (drivers) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminFleetProvider),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    FleetMap(drivers: drivers, now: now),
                    const SizedBox(height: AppSpacing.lg),
                    if (drivers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          l10n.adminFleetEmpty,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final driver in drivers)
                        _DriverTile(
                          driver: driver,
                          label: label(driver.status),
                          now: now,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTile extends ConsumerStatefulWidget {
  const _DriverTile({
    required this.driver,
    required this.label,
    required this.now,
  });

  final FleetDriver driver;
  final String label;
  final DateTime now;

  @override
  ConsumerState<_DriverTile> createState() => _DriverTileState();
}

class _DriverTileState extends ConsumerState<_DriverTile> {
  bool _busy = false;

  /// Suspension ou reintegration (EXI-A06).
  ///
  /// Le motif est demande **avant** l'appel : la feuille rend une decision deja
  /// valide, ou rien du tout. Il n'existe donc pas de chemin menant a une
  /// suspension sans explication.
  Future<void> _toggleSuspension() async {
    final l10n = AppLocalizations.of(context);
    final suspended = widget.driver.status == FleetStatus.suspended;

    final decision = await askForReason(
      context,
      action: suspended
          ? ModerationAction.reinstateAccount
          : ModerationAction.suspendAccount,
      title: suspended ? l10n.adminReinstate : l10n.adminSuspend,
      actionLabel: suspended ? l10n.adminReinstate : l10n.adminSuspend,
      help: suspended ? l10n.adminReinstateHelp : l10n.adminSuspendHelp,
      destructive: !suspended,
    );
    if (decision == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(adminActionsProvider)
          .setSuspension(driverId: widget.driver.id, decision: decision);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final driver = widget.driver;

    final tone = switch (driver.status) {
      FleetStatus.available => AppColors.success,
      FleetStatus.busy => AppColors.primary,
      FleetStatus.offline => AppColors.offline,
      FleetStatus.suspended => AppColors.danger,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tone.withValues(alpha: 0.15),
                  child: Icon(Icons.two_wheeler, color: tone),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        [
                          widget.label,
                          ?driver.plate,
                          if (driver.rating != null)
                            '${driver.rating!.toStringAsFixed(1)} ★',
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const McLoader.small()
                else
                  IconButton(
                    tooltip: driver.status == FleetStatus.suspended
                        ? l10n.adminReinstate
                        : l10n.adminSuspend,
                    icon: Icon(
                      driver.status == FleetStatus.suspended
                          ? Icons.lock_open_outlined
                          : Icons.block_outlined,
                      color: driver.status == FleetStatus.suspended
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    onPressed: _toggleSuspension,
                  ),
              ],
            ),

            // Une position ancienne se dit : afficher un point sans reserve
            // enverrait chercher quelqu'un qui n'y est plus.
            if (driver.position != null && driver.isStaleAt(widget.now)) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.adminFleetStale, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],

            // Le motif de suspension reste affiche tant qu'elle dure : une
            // decision qu'on ne peut plus relire est une decision qu'on ne peut
            // plus lever en connaissance de cause.
            if (driver.suspensionReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.adminSuspendedSince(driver.suspensionReason!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
