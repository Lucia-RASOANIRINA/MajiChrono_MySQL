import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';

/// Fiche livreur : photo (ou initiales), nom, note, vehicule et plaque.
///
/// La meme fiche cote client (« qui va me livrer »), cote admin (liste de la
/// flotte) et en pied de course. La photo tombe sur les initiales quand elle
/// manque — frequent hors ligne — plutot que sur un carre vide.
///
/// Les libelles (vehicule, plaque) arrivent traduits ; la note est un nombre,
/// formate ici a une decimale, langue-neutre.
class McDriverCard extends StatelessWidget {
  const McDriverCard({
    required this.name,
    this.photo,
    this.rating,
    this.vehicle,
    this.plate,
    this.trailing,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final String name;
  final ImageProvider? photo;

  /// Note sur 5. Absente (nouveau livreur), l'etoile n'est pas montree.
  final double? rating;
  final String? vehicle;
  final String? plate;

  /// Widget de droite : un bouton d'appel, une puce de statut...
  final Widget? trailing;
  final VoidCallback? onTap;

  /// En version compacte (pied de course), retire la carte englobante : la
  /// fiche s'insere alors dans une carte deja posee.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final row = _row(context);
    if (compact) return row;
    return McCard(onTap: onTap, child: row);
  }

  Widget _row(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final subtitleParts = <String>[
      if (vehicle != null && vehicle!.isNotEmpty) vehicle!,
      if (plate != null && plate!.isNotEmpty) plate!,
    ];

    return Row(
      children: [
        _Avatar(name: name, photo: photo),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (rating != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photo});

  final String name;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Les jetons d'avatar sont des diametres ; CircleAvatar veut un rayon.
    const radius = AppSizes.avatarMd / 2;
    if (photo != null) {
      return CircleAvatar(radius: radius, backgroundImage: photo);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.substring(0, 1).toUpperCase());
    return letters.join();
  }
}
