import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/driver/domain/entities/delivery_group.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Parcours groupe (EXI-L06, differenciant D7).
///
/// L'ecran ne propose **aucun choix d'ordre**. Les retraits viennent tous
/// avant les remises, et c'est affiche comme une consigne, pas comme une
/// suggestion : un livreur qui livre avant d'avoir tout pris devra revenir, et
/// l'interet du groupage disparait.
///
/// Le seul chiffre mis en avant est le gain en kilometres. C'est le seul qui
/// interesse le livreur — le gain a l'heure, pas le gain a la course.
class GroupedRouteScreen extends ConsumerWidget {
  const GroupedRouteScreen({required this.group, super.key});

  final DeliveryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stops = group.stops;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: AppColors.success.withValues(alpha: 0.10),
            child: Padding(
              padding: AppSpacing.card,
              child: Row(
                children: [
                  const Icon(Icons.route_outlined, color: AppColors.success),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.groupSaved(group.savedKm.toStringAsFixed(1)),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          formatAriary(group.totalPriceAriary),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.groupHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < stops.length; i++)
            _StopTile(stop: stops[i], index: i + 1, total: stops.length),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.index,
    required this.total,
  });

  final GroupStop stop;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isPickup = stop.kind == GroupStopKind.pickup;
    // Couleur **et** libelle : la couleur seule serait illisible en plein
    // soleil, et confondre un retrait avec une remise coute un aller-retour.
    final tone = isPickup ? AppColors.primary : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tone,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPickup ? l10n.groupStopPickup : l10n.groupStopDropoff,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(stop.label, style: theme.textTheme.bodyLarge),
                  Text(
                    stop.district,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
