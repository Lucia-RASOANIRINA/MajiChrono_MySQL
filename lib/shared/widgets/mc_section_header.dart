import 'package:flutter/material.dart';

/// En-tete de section : un titre, un sous-titre facultatif, et une action
/// facultative a droite (« Tout voir »).
///
/// Regroupe ce qui, sinon, se refait a la main sur chaque ecran avec des
/// tailles et des espacements qui derivent. Le titre est aligne a gauche et
/// pose sur `titleMedium` ; l'action, quand elle existe, reste atteignable au
/// pouce (cible de 48 dp heritee du theme des boutons).
///
/// Les textes arrivent deja traduits — l'en-tete n'affiche que ce qu'on lui
/// donne.
class McSectionHeader extends StatelessWidget {
  const McSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Libelle de l'action de droite. Sans [onAction], il n'est pas affiche.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAction = actionLabel != null && onAction != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasAction)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
