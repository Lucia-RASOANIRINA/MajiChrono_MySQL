import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/admin/presentation/widgets/reason_sheet.dart';
import 'package:majichrono/features/custody/presentation/widgets/custody_proof_action.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_error_view.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

String disputeLabel(AppLocalizations l10n, DisputeStatus status) =>
    switch (status) {
      DisputeStatus.open => l10n.adminDisputeOpen,
      DisputeStatus.investigating => l10n.adminDisputeInvestigating,
      DisputeStatus.resolved => l10n.adminDisputeResolved,
      DisputeStatus.rejected => l10n.adminDisputeRejected,
    };

Color disputeColor(DisputeStatus status) => switch (status) {
  DisputeStatus.open => AppColors.danger,
  DisputeStatus.investigating => AppColors.warning,
  DisputeStatus.resolved => AppColors.success,
  DisputeStatus.rejected => AppColors.neutral,
};

/// Liste des litiges (EXI-A05).
class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final disputes = ref.watch(disputesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDisputesTitle)),
      body: disputes.when(
        loading: () => const McSkeletonList(itemCount: 3),
        error: (error, _) => McErrorView(
          failure: error is Failure ? error : const UnknownFailure(),
          onRetry: () => ref.invalidate(disputesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return McEmptyState(
              icon: Icons.gavel_outlined,
              title: l10n.adminDisputesEmpty,
              message: l10n.adminDisputeResolveHelp,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(disputesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final dispute = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Icon(
                      Icons.gavel_outlined,
                      color: disputeColor(dispute.status),
                    ),
                    title: Text(dispute.reason),
                    subtitle: Text(
                      '${disputeLabel(l10n, dispute.status)} · '
                      '${_age(dispute.ageAt(DateTime.now()))}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DisputeDetailScreen(id: dispute.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _age(Duration age) {
  if (age.inHours < 1) return '${age.inMinutes} min';
  if (age.inDays < 1) return '${age.inHours} h';
  return '${age.inDays} j';
}

/// Instruction d'un litige (EXI-A05).
///
/// L'ecran donne acces au comparateur des deux constats — **celui du module 5,
/// tel quel**. EXI-CC31 impose que les trois profils voient la meme chose ; une
/// vue enrichie reservee a l'exploitation ne serait plus une preuve
/// contradictoire, ce serait un dossier a charge.
class DisputeDetailScreen extends ConsumerStatefulWidget {
  const DisputeDetailScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DisputeDetailScreen> createState() =>
      _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  final TextEditingController _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reply() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;

    await _run(() async {
      await ref
          .read(adminActionsProvider)
          .reply(disputeId: widget.id, body: body);
      _message.clear();
    });
  }

  Future<void> _decide({required bool resolve}) async {
    final l10n = AppLocalizations.of(context);

    final decision = await askForReason(
      context,
      action: resolve
          ? ModerationAction.resolveDispute
          : ModerationAction.rejectDispute,
      title: resolve ? l10n.adminDisputeResolve : l10n.adminDisputeDismiss,
      actionLabel: resolve
          ? l10n.adminDisputeResolve
          : l10n.adminDisputeDismiss,
      help: resolve
          ? l10n.adminDisputeResolveHelp
          : l10n.adminDisputeDismissHelp,
      destructive: !resolve,
    );
    if (decision == null || !mounted) return;

    await _run(
      () => ref
          .read(adminActionsProvider)
          .decide(disputeId: widget.id, decision: decision),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dispute = ref.watch(disputeProvider(widget.id));
    final deliveries = ref.watch(deliveriesProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDisputesTitle),
        actions: [
          // Le comparateur, si la course est connue localement.
          if (dispute.valueOrNull != null && deliveries != null)
            ...deliveries
                .where((d) => d.id == dispute.valueOrNull!.deliveryId)
                .map((d) => CustodyProofAction(delivery: d)),
        ],
      ),
      body: dispute.when(
        loading: () => const McSkeletonList(itemCount: 3),
        error: (error, _) => McErrorView(
          failure: error is Failure ? error : const UnknownFailure(),
          onRetry: () => ref.invalidate(disputeProvider(widget.id)),
        ),
        data: (data) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Card(
                    color: disputeColor(data.status).withValues(alpha: 0.10),
                    child: Padding(
                      padding: AppSpacing.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            disputeLabel(l10n, data.status),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: disputeColor(data.status),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.adminDisputeReason,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(data.reason, style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),

                  // La decision reste affichee apres coup, avec son motif : une
                  // decision qu'on ne peut plus relire ne peut plus etre
                  // expliquee a celui qui la conteste.
                  if (data.decision != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: AppSpacing.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.adminDisputeDecidedBy(
                                data.decision!.decidedBy ?? '-',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              data.decision!.reason,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  for (final message in data.messages)
                    Align(
                      alignment: message.fromOperations
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        color: message.fromOperations
                            ? theme.colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: AppSpacing.card,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.authorLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(message.body),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Un litige clos ne se poursuit pas : le champ disparait plutot que
            // de rester grise, et l'ecran dit pourquoi.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: data.status.isClosed
                    ? Text(
                        l10n.adminDisputeClosed,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _message,
                                  decoration: InputDecoration(
                                    hintText: l10n.adminDisputeMessage,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: _busy ? null : _reply,
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(resolve: false),
                                  child: Text(l10n.adminDisputeDismiss),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(resolve: true),
                                  child: Text(l10n.adminDisputeResolve),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
