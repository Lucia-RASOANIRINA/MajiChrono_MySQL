import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:majichrono/core/map/map_attribution.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/core/map/tile_source.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';

/// Fond de carte plein ecran de l'accueil et de la demande de course.
///
/// Les tuiles viennent du cache disque d'abord (§9.2). Sans tuile — premier
/// lancement hors ligne —, la carte reste un aplat neutre sur lequel les
/// reperes demeurent lisibles : l'ecran ne se bloque jamais sur la carte.
class CityMap extends ConsumerWidget {
  const CityMap({
    required this.center,
    this.me,
    this.pickup,
    this.dropoff,
    this.controller,
    this.zoom = 14.5,
    this.attributionAlignment = Alignment.bottomRight,
    this.attributionPadding = EdgeInsets.zero,
    super.key,
  });

  /// Placement de la mention du fournisseur de tuiles, a deplacer quand une
  /// feuille recouvre le bas de la carte.
  final Alignment attributionAlignment;
  final EdgeInsets attributionPadding;

  final GeoPoint center;
  final GeoPoint? me;
  final GeoPoint? pickup;
  final GeoPoint? dropoff;
  final MapController? controller;
  final double zoom;

  static LatLng _ll(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileState = ref.watch(tileProviderProvider);
    final tiles = tileState.valueOrNull;
    final config = TileConfig.forBuild();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFE8EDF2),
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: _ll(center),
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          // Cache disque indisponible (stockage plein, dossier refuse) : la
          // carte se charge quand meme, directement depuis le reseau.
          if (tiles == null && tileState.hasError)
            TileLayer(
              urlTemplate: config.urlTemplate,
              userAgentPackageName: 'mg.majichrono',
            ),
          if (tiles != null)
            TileLayer(
              urlTemplate: config.urlTemplate,
              tileProvider: tiles,
              userAgentPackageName: 'mg.majichrono',
              errorImage: null,
            ),
          MapAttribution(
            alignment: attributionAlignment,
            padding: attributionPadding,
          ),
          if (pickup != null && dropoff != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [_ll(pickup!), _ll(dropoff!)],
                  strokeWidth: 4,
                  color: AppColors.primary,
                  pattern: StrokePattern.dashed(segments: const [10, 8]),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (me != null)
                Marker(
                  point: _ll(me!),
                  width: 28,
                  height: 28,
                  child: const _MeDot(),
                ),
              if (pickup != null)
                Marker(
                  point: _ll(pickup!),
                  width: 36,
                  height: 36,
                  child: const _Pin(
                    color: AppColors.success,
                    icon: Icons.circle,
                  ),
                ),
              if (dropoff != null)
                Marker(
                  point: _ll(dropoff!),
                  width: 36,
                  height: 36,
                  child: const _Pin(
                    color: AppColors.accent,
                    icon: Icons.flag_rounded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primaryLight.withValues(alpha: 0.25),
    ),
    alignment: Alignment.center,
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
    ),
  );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary,
      border: Border.all(color: color, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
    ),
    child: Icon(icon, size: 14, color: color),
  );
}
