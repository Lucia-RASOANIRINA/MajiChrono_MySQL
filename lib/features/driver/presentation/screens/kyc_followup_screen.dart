import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Suivi de dossier KYC : le livreur ecrit a l'exploitation pour savoir ou en
/// est sa validation, et lit ses reponses. Un fil rattache a son compte, pas a
/// une course — un dossier n'est pas une livraison.
class KycFollowupScreen extends ConsumerStatefulWidget {
  const KycFollowupScreen({super.key});

  @override
  ConsumerState<KycFollowupScreen> createState() => _KycFollowupScreenState();
}

class _KycFollowupScreenState extends ConsumerState<KycFollowupScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(driverActionsProvider).sendKycMessage(text);
      _controller.clear();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final thread = ref.watch(kycThreadProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kycFollowupTitle)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.kycFollowupHelp,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: thread.when(
              loading: () => const McSkeletonList(),
              error: (_, _) => McEmptyState(
                icon: Icons.forum_outlined,
                title: l10n.kycFollowupEmpty,
                message: l10n.errorNetwork,
              ),
              data: (messages) => messages.isEmpty
                  ? McEmptyState(
                      icon: Icons.forum_outlined,
                      title: l10n.kycFollowupEmpty,
                      message: l10n.kycFollowupHelp,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (final message in messages) ...[
                          _Bubble(message: message),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.kycFollowupHint,
                        isDense: true,
                        border: const OutlineInputBorder(
                          borderRadius: AppRadii.componentAll,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final KycMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fromAdmin = message.fromAdmin;

    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: fromAdmin
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadii.sheetAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromAdmin ? l10n.kycFollowupAdmin : l10n.kycFollowupYou,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fromAdmin ? AppColors.info : AppColors.primary,
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
