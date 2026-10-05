import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_vehicle.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Libelle, capacite et pictogramme d'un vehicule de livraison.
extension DeliveryVehicleVisuals on DeliveryVehicle {
  String label(AppLocalizations l10n) => switch (this) {
    DeliveryVehicle.moto => l10n.vehicleTypeMoto,
    DeliveryVehicle.tricycle => l10n.vehicleTypeTricycle,
    DeliveryVehicle.car => l10n.vehicleTypeCar,
    DeliveryVehicle.van => l10n.vehicleTypeVan,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    DeliveryVehicle.moto => l10n.vehicleMotoHint,
    DeliveryVehicle.tricycle => l10n.vehicleTricycleHint,
    DeliveryVehicle.car => l10n.vehicleCarHint,
    DeliveryVehicle.van => l10n.vehicleVanHint,
  };

  IconData get icon => switch (this) {
    DeliveryVehicle.moto => Icons.two_wheeler_rounded,
    DeliveryVehicle.tricycle => Icons.electric_rickshaw_rounded,
    DeliveryVehicle.car => Icons.directions_car_rounded,
    DeliveryVehicle.van => Icons.local_shipping_rounded,
  };
}

/// Choix du vehicule selon la taille du colis.
///
/// Chaque ligne annonce son **prix fixe** pour le trajet deja saisi : le client
/// compare et choisit en un geste, sans aller-retour jusqu'au recapitulatif.
/// Un vehicule incapable de porter le poids declare reste visible mais
/// desactive, avec la raison — le cacher laisserait croire qu'il n'existe pas.
class VehiclePicker extends StatelessWidget {
  const VehiclePicker({
    required this.selected,
    required this.weight,
    required this.prices,
    required this.onSelected,
    super.key,
  });

  final DeliveryVehicle selected;
  final WeightCategory weight;

  /// Prix fixe de chaque vehicule pour le trajet, quand il est connu.
  final Map<DeliveryVehicle, int> prices;
  final ValueChanged<DeliveryVehicle> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final vehicle in DeliveryVehicle.values) ...[
          _VehicleTile(
            vehicle: vehicle,
            selected: vehicle == selected,
            enabled: vehicle.canCarry(weight),
            price: prices[vehicle],
            reason: vehicle.canCarry(weight) ? null : l10n.vehicleTooHeavy,
            onTap: () => onSelected(vehicle),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.vehicleDispatchHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.enabled,
    required this.price,
    required this.reason,
    required this.onTap,
  });

  final DeliveryVehicle vehicle;
  final bool selected;
  final bool enabled;
  final int? price;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardAll,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadii.cardAll,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    vehicle.icon,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.label(l10n),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        reason ?? vehicle.hint(l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: reason != null
                              ? AppColors.danger
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null && enabled) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatAriary(price!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                ],
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
