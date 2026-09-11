import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Ecran « elements en attente » (EXI-S06).
///
/// L'exigence demande quatre choses : la liste, l'age, la cause, et une relance
/// manuelle. Les quatre vont ensemble. Une liste sans cause ne dit pas si le
/// bouton de relance servira a quelque chose ; un age sans liste ne dit pas ce
/// qui attend. Un livreur qui a fait sa tournee en zone blanche doit pouvoir
/// verifier, le soir, que ses constats sont bien partis — et voir lesquels ne le
/// sont pas.
class PendingSyncScreen extends ConsumerWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(pendingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncPendingTitle),
        actions: [
          if ((items.valueOrNull ?? const []).isNotEmpty)
            TextButton(
              onPressed: () async {
                await ref.read(syncQueueProvider).retryAll();
                await ref.read(syncSchedulerProvider).drain();
              },
              child: Text(l10n.syncRetryAll),
            ),
        ],
      ),
      body: items.when(
        loading: () => const McSkeletonList(itemCount: 4),
        error: (_, _) => McEmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.errorUnknown,
          message: l10n.syncPendingEmptyHelp,
        ),
        data: (list) {
          if (list.isEmpty) {
            return McEmptyState(
              icon: Icons.cloud_done_outlined,
              title: l10n.syncPendingEmpty,
              message: l10n.syncPendingEmptyHelp,
            );
          }

          final now = DateTime.now();

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.syncPendingHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final item = list[index - 1];
              return _PendingCard(
                item: item,
                now: now,
                onRetry: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(syncQueueProvider).retryNow(item.id);
                  await ref.read(syncSchedulerProvider).drain();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.syncRetryQueued)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.item,
    required this.now,
    required this.onRetry,
  });

  final SyncItem item;
  final DateTime now;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final label = switch (item.priority) {
      SyncPriority.custody => l10n.syncItemCustody,
      SyncPriority.transition => l10n.syncItemTransition,
      SyncPriority.position => l10n.syncItemPosition,
      SyncPriority.rating => l10n.syncItemRating,
    };

    final cause = switch (item.cause) {
      SyncFailureCause.none => l10n.syncCauseNone,
      SyncFailureCause.network => l10n.syncCauseNetwork,
      SyncFailureCause.server => l10n.syncCauseServer,
      SyncFailureCause.conflict => l10n.syncCauseConflict,
      SyncFailureCause.rejected => l10n.syncCauseRejected,
      SyncFailureCause.exhausted => l10n.syncCauseExhausted,
    };

    final icon = switch (item.priority) {
      SyncPriority.custody => Icons.fact_check_outlined,
      SyncPriority.transition => Icons.local_shipping_outlined,
      SyncPriority.position => Icons.my_location_outlined,
      SyncPriority.rating => Icons.star_outline,
    };

    // Rouge pour ce qui ne repartira pas de soi-meme, ambre pour ce qui a
    // echoue mais reste programme, neutre pour ce qui attend simplement son
    // tour. La couleur ne porte jamais seule : le libelle de cause la double
    // (EXI-T09).
    //
    // Le ton neutre est `onSurfaceVariant` et non `outline` : cette derniere
    // est une couleur de bordure, trop pale pour porter du texte. La ligne de
    // cause est precisement celle qu'il faut pouvoir lire — elle dit si le
    // bouton de relance servira a quelque chose.
    final tone = switch (item.status) {
      SyncItemStatus.abandoned => AppColors.danger,
      SyncItemStatus.failed => AppColors.warning,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
                Text(
                  _age(l10n, item.ageAt(now)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              cause,
              style: theme.textTheme.bodyLarge?.copyWith(color: tone),
            ),
            if (item.attempts > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.syncAttempts(item.attempts),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (item.neverAbandon) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.syncNeverAbandon,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.syncRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Age lisible. La minute suffit : personne ne lit « il y a 2 h 14 min 8 s ».
  String _age(AppLocalizations l10n, Duration age) {
    if (age.inMinutes < 1) return l10n.syncAgeNow;
    if (age.inHours < 1) return l10n.syncAgeMinutes(age.inMinutes);
    if (age.inDays < 1) return l10n.syncAgeHours(age.inHours);
    return l10n.syncAgeDays(age.inDays);
  }
}
