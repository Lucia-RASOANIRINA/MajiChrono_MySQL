import 'package:flutter/material.dart';
import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Action principale d'un ecran (§15.2.1 : une seule, en bas, au pouce).
///
/// La variante [McPrimaryAction.driver] applique la contrainte §15.3 du bouton
/// de progression livreur : pleine largeur, 64 dp, libelle explicite de
/// l'action suivante — utilisable avec des gants, en plein soleil, d'une main.
class McPrimaryAction extends StatelessWidget {
  const McPrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = AppSizes.minTouchTarget,
    this.destructive = false,
    super.key,
  });

  const McPrimaryAction.driver({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
    super.key,
  }) : height = AppSizes.driverActionHeight;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = height >= AppSizes.driverActionHeight;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? scheme.error : null,
            foregroundColor: destructive ? scheme.onError : null,
            // Moins de marge verticale que le bouton standard : le libelle du
            // livreur peut tenir sur deux lignes sans etre rogne.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            // Le style part de la typographie du theme : meme police, meme
            // interlettrage que le reste de l'application.
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontSize: large ? 18 : 16,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          icon: busy
              ? McLoader.small(color: scheme.onSurfaceVariant)
              : Icon(icon ?? Icons.arrow_forward, size: large ? 26 : 22),
          // Deux lignes au plus : « Tonga eo amin'ny toerana aho » ne tient
          // pas sur une seule a 360 dp, et un libelle rogne ne se lit plus.
          label: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
