import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Ton d'un statut, independamment du texte. Chaque ton se traduit en une paire
/// (fond teinte, encre) prise dans le schema, jamais en une couleur brute :
/// l'ecran choisit un *sens* (« ceci a reussi »), pas un vert.
enum McStatusTone { neutral, info, success, warning, danger, offline }

/// Pastille de statut : une icone **et** un libelle, toujours les deux.
///
/// C'est la regle d'accessibilite du projet (§15.1, EXI-T09) : une couleur ne
/// porte jamais seule une information. En plein soleil ou pour un daltonisme,
/// c'est l'icone et le mot qui restent lisibles, la teinte n'est qu'un renfort.
///
/// Le libelle arrive deja traduit : la pastille ne connait pas les langues,
/// elle ne fait que les afficher.
class McStatusBadge extends StatelessWidget {
  const McStatusBadge({
    required this.label,
    required this.icon,
    this.tone = McStatusTone.neutral,
    super.key,
  });

  final String label;
  final IconData icon;
  final McStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = _ink(scheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }

  /// Encre du ton. Sensible a la luminosite : les couleurs de statut pleines
  /// (pensees pour du blanc) tomberaient sous le contraste AA sur une surface
  /// sombre, donc en theme sombre on prend leur variante claire.
  Color _ink(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    switch (tone) {
      case McStatusTone.neutral:
        return scheme.onSurfaceVariant;
      case McStatusTone.info:
        return dark ? const Color(0xFF7EC5F0) : AppColors.info;
      case McStatusTone.success:
        return dark ? const Color(0xFF81C784) : AppColors.success;
      case McStatusTone.warning:
        return dark ? const Color(0xFFF7BC5E) : AppColors.warning;
      case McStatusTone.danger:
        // Le schema porte deja la bonne teinte d'erreur dans chaque mode.
        return scheme.error;
      case McStatusTone.offline:
        // Le hors ligne est un mode nominal, jamais une panne : ardoise, pas
        // rouge (§4.1).
        return dark ? AppColors.darkOnSurfaceMuted : AppColors.offline;
    }
  }
}
