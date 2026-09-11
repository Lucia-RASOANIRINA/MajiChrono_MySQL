import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_primary_action.dart';
import 'package:majichrono/core/map/tile_source.dart';

/// Placement du point GPS d'une adresse sur la carte (EXI-C01).
///
/// Le geste retenu est **la carte qui bouge sous un viseur fixe**, et non un
/// marqueur qu'on fait glisser. La difference compte sur un ecran de 5 pouces
/// tenu d'une main : le doigt ne masque jamais le point qu'il vise, et le
/// reperage se fait sur le fond de carte, pas sur le marqueur.
///
/// Le point GPS ne remplace pas le point de repere (§4.3) : il le complete. Le
/// GPS depose le livreur a cinquante metres, le repere lui fait franchir les
/// cinquante derniers.
class PickLocationScreen extends ConsumerStatefulWidget {
  const PickLocationScreen({required this.initial, super.key});

  final GeoPoint initial;

  @override
  ConsumerState<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends ConsumerState<PickLocationScreen> {
  late final MapController _controller = MapController();
  late GeoPoint _selected = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tiles = ref.watch(tileProviderProvider);
    final tileConfig = TileConfig.forBuild();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickLocationTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                tiles.when(
                  loading: () => const Center(child: McLoader()),
                  error: (_, _) => Center(child: Text(l10n.mapUnavailable)),
                  data: (tileProvider) => FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _selected.latitude,
                        _selected.longitude,
                      ),
                      initialZoom: 15,
                      onPositionChanged: (position, _) => setState(
                        () => _selected = GeoPoint(
                          position.center.latitude,
                          position.center.longitude,
                        ),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: tileConfig.urlTemplate,
                        tileProvider: tileProvider,
                        userAgentPackageName: 'mg.majichrono',
                      ),
                    ],
                  ),
                ),
                // Viseur fixe, legerement remonte pour que la pointe designe le
                // centre exact de la carte.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.place,
                      size: 44,
                      color: AppColors.danger,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.my_location,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _selected.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          McPrimaryAction(
            label: l10n.commonConfirm,
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}
