import 'package:flutter/material.dart';

import 'package:majichrono/core/map/tile_source.dart';

/// Mention du fournisseur de tuiles, en bas a droite de chaque carte.
///
/// Elle n'est pas decorative : les licences d'OpenStreetMap et de ses
/// fournisseurs l'exigent, et une carte sans mention s'expose au retrait des
/// tuiles. Aucune carte de l'application ne l'affichait.
class MapAttribution extends StatelessWidget {
  const MapAttribution({
    this.alignment = Alignment.bottomRight,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Coin de la carte ou poser la mention.
  final Alignment alignment;

  /// Decalage, quand un element de l'ecran recouvre ce coin de la carte.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Composant maison plutot que `SimpleAttributionWidget`, qui ajoute
    // « flutter_map | » et un second « © » devant la mention.
    return Padding(
      padding: padding,
      child: Align(
        alignment: alignment,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.white.withValues(alpha: 0.8),
          child: Text(
            TileConfig.forBuild().attribution,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
