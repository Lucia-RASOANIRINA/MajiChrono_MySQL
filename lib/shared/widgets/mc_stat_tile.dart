import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';

/// Tuile de statistique : une valeur en gros, son libelle, une icone teintee.
///
/// C'est la brique des tableaux de bord — gains du jour, courses en cours,
/// note moyenne. La valeur domine (echelle `headlineMedium`), le libelle la
/// nomme en dessous ; l'icone, dans une pastille a la couleur donnee, ancre le
/// sens sans crier. Posee dans une [McCard], elle se range dans une grille ou
/// une ligne sans retouche.
///
/// Valeur et libelle arrivent deja formates et traduits.
class McStatTile extends StatelessWidget {
  const McStatTile({
    required this.value,
    required this.label,
    required this.icon,
    this.tint,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final IconData icon;

  /// Teinte de l'icone et de sa pastille. Par defaut, la couleur primaire.
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tint ?? theme.colorScheme.primary;

    return McCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadii.componentAll,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
