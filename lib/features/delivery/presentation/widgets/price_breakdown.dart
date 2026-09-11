import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Ventilation du prix affichee avant confirmation (EXI-C10).
///
/// L'exigence porte sur la ventilation, pas seulement sur le total. C'est ce
/// qui distingue MajiChrono d'un prix annonce au telephone : l'expediteur voit
/// d'ou vient chaque ariary, et une contestation devient instruisible.
class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({required this.estimate, super.key});

  final PriceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String label(PriceLineKind kind) => switch (kind) {
      PriceLineKind.base => l10n.priceBase,
      PriceLineKind.distance => l10n.priceDistance,
      PriceLineKind.weight => l10n.priceWeight,
      PriceLineKind.kindSurcharge => l10n.priceKind,
      PriceLineKind.schedule => l10n.priceSchedule,
      PriceLineKind.insurance => l10n.priceInsurance,
    };

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in estimate.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.detail == null
                            ? label(line.kind)
                            : '${label(line.kind)} · ${line.detail}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      formatAriary(line.amountAriary),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.estimateTotal,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatAriary(estimate.totalAriary),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (estimate.isProvisional) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      // Annoncer un prix ferme issu d'une grille non arbitree
                      // (DO-3) serait promettre un montant que l'exploitation ne
                      // tiendra pas. On le dit plutot que de le taire.
                      l10n.estimateProvisional,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
