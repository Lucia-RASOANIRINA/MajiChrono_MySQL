import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/support/presentation/providers/dispute_providers.dart';
import 'package:majichrono/features/support/presentation/screens/disputes_list_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Detail d'un litige : motif, fil d'echanges, decision, et zone de reponse
/// tant que le dossier n'est pas clos (§13).
class DisputeDetailScreen extends ConsumerStatefulWidget {
  const DisputeDetailScreen({required this.disputeId, super.key});

  final String disputeId;

  @override
  ConsumerState<DisputeDetailScreen> createState() =>
      _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(disputeActionsProvider)
          .reply(disputeId: widget.disputeId, body: body);
      _controller.clear();
    } on Failure catch (failure) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.localizedMessage(l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(clientDisputeProvider(widget.disputeId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.disputesTitle)),
      body: async.when(
        loading: () => const McSkeletonList(),
        error: (_, _) => Center(child: Text(l10n.errorUnknown)),
        data: (dispute) => _DisputeBody(
          dispute: dispute,
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
      ),
    );
  }
}

class _DisputeBody extends StatelessWidget {
  const _DisputeBody({
    required this.dispute,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final Dispute dispute;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (statusLabel, statusTone) = disputeStatusView(l10n, dispute.status);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: McStatusBadge(
                  label: statusLabel,
                  icon: disputeStatusIcon(dispute.status),
                  tone: statusTone,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              McCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.disputeReason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(dispute.reason, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              if (dispute.decision != null) ...[
                const SizedBox(height: AppSpacing.md),
                _DecisionCard(decision: dispute.decision!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.disputeThread,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (dispute.messages.isEmpty)
                Text(
                  l10n.disputeNoMessages,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral,
                  ),
                )
              else
                for (final message in dispute.messages) ...[
                  _MessageBubble(message: message),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
        if (dispute.status.isClosed)
          _ClosedBanner(text: l10n.disputeClosed)
        else
          _ReplyBar(
            controller: controller,
            sending: sending,
            onSend: onSend,
          ),
      ],
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision});

  final ModerationDecision decision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return McCard(
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.disputeDecision,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.neutral),
          ),
          const SizedBox(height: 2),
          Text(decision.reason, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Bulle d'un message. Les messages de l'exploitation sont alignes a gauche et
/// teintes ; ceux de l'utilisateur a droite. La couleur ne porte jamais seule
/// l'origine : le libelle d'auteur la double (EXI-T09).
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final DisputeMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fromOps = message.fromOperations;
    final label = fromOps ? message.authorLabel : l10n.disputeAuthorYou;

    return Align(
      alignment: fromOps ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: fromOps
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadii.sheetAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fromOps ? AppColors.info : AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(message.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AppColors.neutral),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.disputeReplyHint,
                  isDense: true,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadii.componentAll,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: l10n.disputeSend,
            ),
          ],
        ),
      ),
    );
  }
}
