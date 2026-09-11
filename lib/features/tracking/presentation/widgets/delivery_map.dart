import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/core/map/tile_source.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Carte de suivi.
///
/// Les tuiles viennent du cache disque en priorite (§9.2, §10.1). Quand elles
/// manquent — quartier jamais visite, hors ligne — la carte n'affiche pas un
/// rectangle gris muet : elle **annonce sa degradation** (§15.3) tout en
/// continuant a montrer les points, qui eux sont connus. Une position sur fond
/// vide reste utile ; un ecran vide sans explication ne l'est pas.
class DeliveryMap extends ConsumerWidget {
  const DeliveryMap({
    required this.pickup,
    required this.dropoff,
    this.driverPosition,
    this.trace = const [],
    this.height = 260,
    super.key,
  });

  final GeoPoint pickup;
  final GeoPoint dropoff;
  final GeoPoint? driverPosition;
  final List<GeoPoint> trace;
  final double height;

  LatLng _toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tiles = ref.watch(tileProviderProvider);
    final tileConfig = TileConfig.forBuild();

    final center =
        driverPosition ??
        GeoPoint(
          (pickup.latitude + dropoff.latitude) / 2,
          (pickup.longitude + dropoff.longitude) / 2,
        );

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: AppRadii.sheetAll,
        child: tiles.when(
          loading: () => const ColoredBox(
            color: AppColors.lightSurfaceAlt,
            child: Center(child: McLoader()),
          ),
          error: (_, _) => _MapUnavailable(message: l10n.mapUnavailable),
          data: (tileProvider) => FlutterMap(
            options: MapOptions(
              initialCenter: _toLatLng(center),
              initialZoom: 13.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileConfig.urlTemplate,
                tileProvider: tileProvider,
                userAgentPackageName: 'mg.majichrono',
                // Les tuiles absentes restent transparentes : le fond de carte
                // se degrade, les reperes restent lisibles.
                errorImage: null,
              ),
              if (trace.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trace.map(_toLatLng).toList(),
                      strokeWidth: 4,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  _marker(
                    _toLatLng(pickup),
                    Icons.trip_origin,
                    AppColors.primary,
                  ),
                  _marker(_toLatLng(dropoff), Icons.place, AppColors.danger),
                  if (driverPosition != null)
                    _marker(
                      _toLatLng(driverPosition!),
                      Icons.two_wheeler,
                      AppColors.accentDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
    point: point,
    width: 40,
    height: 40,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    ),
  );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
