import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/shared/widgets/mc_patterns.dart';

/// Bandeau d'en-tete des tableaux de bord : une salutation, un statut de
/// connexion, et des actions a droite, poses sur le bleu de la charte.
///
/// Il remplace l'`AppBar` grise standard en haut de l'accueil de chaque profil.
/// Le bleu et la trame technique sont exactement ceux de l'ecran de choix de
/// connexion : en passant de l'un a l'autre, on reste dans la meme application.
/// Le bloc s'etend sous la barre de statut et s'arrondit en bas, de sorte que
/// le contenu de l'ecran semble glisser dessous.
///
/// Tous les libelles (salutation, statut) arrivent deja traduits ; le bandeau
/// ne connait pas les langues.
class McAppHeader extends StatelessWidget {
  const McAppHeader({
    required this.greeting,
    required this.statusLabel,
    required this.statusIcon,
    this.subtitle,
    this.statusOnline = true,
    this.actions = const [],
    super.key,
  });

  final String greeting;
  final String? subtitle;

  /// Statut reseau, deja traduit (« En ligne », « Hors ligne — 3 en attente »).
  final String statusLabel;
  final IconData statusIcon;

  /// A faux, le statut prend le ton hors-ligne (ardoise, jamais rouge).
  final bool statusOnline;

  /// Actions de droite : reglages, notifications... Cibles de 48 dp attendues.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: AppRadii.sheet),
      child: Stack(
        children: [
          // Aplat bleu de marque et trame legere, sans degrade.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: TechPatternPainter(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Puce de statut, en blanc sur le bleu. Un point de couleur
                  // (vert en ligne, ambre hors ligne) double l'icone, mais le
                  // texte reste blanc pour garder le contraste AA sur le fond.
                  _StatusPill(
                    label: statusLabel,
                    icon: statusIcon,
                    online: statusOnline,
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

/// Puce de statut reseau du bandeau : icone teintee, texte blanc, fond
/// translucide. Le vert / l'ambre ne portent jamais l'info seuls — l'icone et
/// le mot le font.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.online,
  });

  final String label;
  final IconData icon;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final dot = online ? const Color(0xFF81C784) : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: dot),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
