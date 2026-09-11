import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/support/presentation/providers/dispute_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Liste des litiges ouverts par l'utilisateur (§13, assistance).
class DisputesListScreen extends ConsumerWidget {
  const DisputesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final disputes = ref.watch(clientDisputesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.disputesTitle)),
      body: disputes.when(
        loading: () => const McSkeletonList(),
        error: (_, _) => McEmptyState(
          icon: Icons.gavel_outlined,
          title: l10n.disputesEmpty,
          message: l10n.errorUnknown,
        ),
        data: (items) => items.isEmpty
            ? McEmptyState(
                icon: Icons.gavel_outlined,
                title: l10n.disputesEmpty,
                message: l10n.disputesEmptyHelp,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clientDisputesProvider);
                  await ref.read(clientDisputesProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _DisputeTile(dispute: items[index]),
                ),
              ),
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, tone) = disputeStatusView(l10n, dispute.status);

    return McCard(
      onTap: () => context.push(AppRoutes.dispute(dispute.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: McStatusBadge(
                  label: label,
                  icon: disputeStatusIcon(dispute.status),
                  tone: tone,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.neutral),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dispute.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.disputeOpenedOn(_formatDate(dispute.openedAt)),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.neutral),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

/// Icone d'un statut de litige, partagee entre la liste et le detail. La
/// couleur ne porte jamais seule l'etat : cette icone la double (EXI-T09).
IconData disputeStatusIcon(DisputeStatus status) => switch (status) {
  DisputeStatus.open => Icons.error_outline,
  DisputeStatus.investigating => Icons.search,
  DisputeStatus.resolved => Icons.check_circle_outline,
  DisputeStatus.rejected => Icons.cancel_outlined,
};

/// Libelle et ton d'un statut de litige, partages entre la liste et le detail.
(String, McStatusTone) disputeStatusView(
  AppLocalizations l10n,
  DisputeStatus status,
) => switch (status) {
  DisputeStatus.open => (l10n.disputeStatusOpen, McStatusTone.warning),
  DisputeStatus.investigating => (
    l10n.disputeStatusInvestigating,
    McStatusTone.info,
  ),
  DisputeStatus.resolved => (l10n.disputeStatusResolved, McStatusTone.success),
  DisputeStatus.rejected => (l10n.disputeStatusRejected, McStatusTone.danger),
};
