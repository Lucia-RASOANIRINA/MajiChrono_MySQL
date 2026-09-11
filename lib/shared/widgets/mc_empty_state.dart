import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Etat vide (§15.2.3 : aucun etat vide muet).
///
/// Un ecran vide explique la situation **et** propose une action. Le composant
/// impose donc un titre et un message ; l'action reste facultative uniquement
/// lorsqu'aucune action n'est possible pour ce role.
class McEmptyState extends StatelessWidget {
  const McEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Defile plutot que de deborder : le composant est utilise dans des cartes
    // de hauteur fixe et sur des ecrans de 320 dp (EXI-P09), ou un message un
    // peu long suffit a faire sortir le contenu de son cadre.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
