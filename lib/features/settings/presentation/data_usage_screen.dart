import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Ecran « Ma consommation » (EXI-T07, differenciant D8).
///
/// Aucun concurrent local ne montre a l'utilisateur ce qu'il depense de son
/// forfait. A Madagascar, ou la data s'achete par petits paquets (§4.4), c'est
/// un argument de confiance direct — d'ou la ventilation par usage plutot
/// qu'un total unique.
class DataUsageScreen extends ConsumerWidget {
  const DataUsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meter = ref.watch(dataMeterProvider);

    String labelOf(DataCategory category) => switch (category) {
      DataCategory.api => l10n.dataCatApi,
      DataCategory.photos => l10n.dataCatPhotos,
      DataCategory.maps => l10n.dataCatMaps,
      DataCategory.tracking => l10n.dataCatTracking,
      DataCategory.payment => l10n.dataCatPayment,
      DataCategory.other => l10n.dataCatOther,
    };

    IconData iconOf(DataCategory category) => switch (category) {
      DataCategory.api => Icons.swap_vert,
      DataCategory.photos => Icons.photo_camera_outlined,
      DataCategory.maps => Icons.map_outlined,
      DataCategory.tracking => Icons.my_location_outlined,
      DataCategory.payment => Icons.account_balance_wallet_outlined,
      DataCategory.other => Icons.more_horiz,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataUsageTitle)),
      // Le compteur est un ChangeNotifier : l'ecran se met a jour a chaque
      // echange reseau, sans sondage.
      body: ListenableBuilder(
        listenable: meter,
        builder: (context, _) {
          final breakdown = meter.breakdown;
          final total = meter.total;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dataUsageThisMonth,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DataMeter.format(total),
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Budget EXI-P06 : moins de 25 Mo par mois pour un client ordinaire.
                      LinearProgressIndicator(
                        value: (total / (25 * 1024 * 1024)).clamp(0, 1),
                        minHeight: 8,
                        borderRadius: AppRadii.componentAll,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.dataBudgetReference,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Column(
                  children: [
                    for (final entry in breakdown.entries) ...[
                      ListTile(
                        leading: Icon(iconOf(entry.key)),
                        title: Text(labelOf(entry.key)),
                        trailing: Text(
                          DataMeter.format(entry.value),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (entry.key != breakdown.keys.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
