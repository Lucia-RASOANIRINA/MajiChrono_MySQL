import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Restitution d'une erreur a l'utilisateur (regle 9.3.4, §15.2.4).
///
/// Deux garanties : jamais de message technique, et toujours une action
/// possible. La cause reelle part au journal, pas a l'ecran.
class McErrorView extends StatelessWidget {
  const McErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure is NetworkFailure
                  ? Icons.cloud_off_outlined
                  : Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.errorTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              failure.localizedMessage(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (failure.isRetryable && onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
