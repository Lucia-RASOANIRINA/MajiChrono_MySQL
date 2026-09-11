import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/support/presentation/providers/dispute_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Ouvre la feuille de creation d'un litige pour une course (§13).
///
/// A la reussite, on remplace la feuille par le detail du litige : l'utilisateur
/// arrive directement sur le dossier qu'il vient d'ouvrir, pret a dialoguer.
Future<void> showOpenDisputeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String deliveryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _OpenDisputeSheet(deliveryId: deliveryId),
    ),
  );
}

class _OpenDisputeSheet extends ConsumerStatefulWidget {
  const _OpenDisputeSheet({required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<_OpenDisputeSheet> createState() => _OpenDisputeSheetState();
}

class _OpenDisputeSheetState extends ConsumerState<_OpenDisputeSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final reason = _controller.text.trim();
    // Meme seuil que le serveur : un litige qui tranche entre deux versions se
    // justifie, un motif d'un mot ne suffit pas.
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.disputeReasonTooShort)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final dispute = await ref
          .read(disputeActionsProvider)
          .open(deliveryId: widget.deliveryId, reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.disputeOpened)),
      );
      unawaited(context.push(AppRoutes.dispute(dispute.id)));
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.disputeOpenTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.disputeOpenHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.disputeReasonLabel,
                hintText: l10n.disputeReasonHint,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.componentAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.disputeOpenAction),
            ),
          ],
        ),
      ),
    );
  }
}
