import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';

/// Raccourci d'accueil : une icone teintee et un libelle, dans une carte
/// touchable. Range en grille, il donne l'acces direct aux gestes frequents
/// (nouvelle course, suivi...) sans passer par un menu.
///
/// Le libelle arrive deja traduit.
class McQuickAction extends StatelessWidget {
  const McQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tint ?? theme.colorScheme.primary;

    return McCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
