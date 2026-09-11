import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/core/map/tile_source.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Carte de la flotte (EXI-A02).
///
/// Frere de `DeliveryMap` plutot que generalisation : les deux cartes ne
/// montrent pas la meme chose. Le suivi affiche un trajet — depart, arrivee,
/// livreur — avec un cadrage centre sur ce trajet. La supervision affiche une
/// population, sans depart ni arrivee, et son cadrage doit englober tout le
/// monde. Fusionner les deux aurait produit un widget a options mutuellement
/// exclusives, plus difficile a lire que deux widgets courts.
///
/// Ce qui est partage l'est reellement : le fournisseur de tuiles en cache
/// (§9.2), la politique de degradation hors ligne, et l'aspect des reperes.
class FleetMap extends ConsumerWidget {
  const FleetMap({
    required this.drivers,
    required this.now,
    this.onSelect,
    this.height = 300,
    super.key,
  });

  final List<FleetDriver> drivers;

  /// Instant de reference, calcule une seule fois par l'ecran.
  ///
  /// La carte et la liste doivent s'accorder sur l'anciennete d'une position :
  /// deux appels a `DateTime.now()` a quelques millisecondes d'ecart peuvent
  /// tomber de part et d'autre du seuil, et afficher un repere plein sous une
  /// ligne qui annonce « position ancienne ».
  final DateTime now;
  final void Function(FleetDriver driver)? onSelect;
  final double height;

  /// Couleur du repere. Elle double le libelle de statut affiche dans la liste
  /// en dessous, elle ne le remplace pas (EXI-T09).
  Color _toneFor(FleetStatus status) => switch (status) {
    FleetStatus.available => AppColors.success,
    FleetStatus.busy => AppColors.primary,
    FleetStatus.offline => AppColors.offline,
    FleetStatus.suspended => AppColors.danger,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tiles = ref.watch(tileProviderProvider);
    final tileConfig = TileConfig.forBuild();

    // Seuls les livreurs localises se placent. Un livreur hors service n'a pas
    // de position, et lui en inventer une serait pire que de ne pas l'afficher.
    final located = drivers.where((d) => d.position != null).toList();

    if (located.isEmpty) {
      return SizedBox(
        height: height,
        child: _MapNotice(message: l10n.adminFleetEmpty),
      );
    }

    final points = located
        .map((d) => LatLng(d.position!.latitude, d.position!.longitude))
        .toList();

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: AppRadii.sheetAll,
        child: tiles.when(
          loading: () => const ColoredBox(
            color: AppColors.lightSurfaceAlt,
            child: Center(child: McLoader()),
          ),
          error: (_, _) => _MapNotice(message: l10n.adminFleetMapUnavailable),
          data: (tileProvider) => FlutterMap(
            options: MapOptions(
              // Le cadrage englobe toute la flotte : centrer sur un seul
              // livreur laisserait les autres hors de l'ecran, et une carte de
              // supervision qui cache la moitie de la flotte ne supervise rien.
              initialCameraFit: CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
                maxZoom: 15,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileConfig.urlTemplate,
                tileProvider: tileProvider,
                userAgentPackageName: 'mg.majichrono',
                // Les tuiles absentes restent transparentes : le fond se
                // degrade, les reperes restent lisibles.
                errorImage: null,
              ),
              MarkerLayer(
                markers: [
                  for (final driver in located)
                    Marker(
                      point: LatLng(
                        driver.position!.latitude,
                        driver.position!.longitude,
                      ),
                      width: 44,
                      height: 44,
                      child: _FleetMarker(
                        driver: driver,
                        now: now,
                        tone: _toneFor(driver.status),
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(driver),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetMarker extends StatelessWidget {
  const _FleetMarker({
    required this.driver,
    required this.tone,
    required this.now,
    this.onTap,
  });

  final FleetDriver driver;
  final DateTime now;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Une position ancienne s'affiche en creux : elle dit « il etait la »
    // plutot que « il est la ». Afficher un repere plein au mauvais endroit
    // enverrait un exploitant chercher quelqu'un qui n'y est plus.
    final stale = driver.isStaleAt(now);

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: stale ? Colors.white : tone,
          shape: BoxShape.circle,
          border: Border.all(color: tone, width: 2),
        ),
        child: Icon(
          Icons.two_wheeler,
          size: 20,
          color: stale ? tone : Colors.white,
        ),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.lightSurfaceAlt,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
