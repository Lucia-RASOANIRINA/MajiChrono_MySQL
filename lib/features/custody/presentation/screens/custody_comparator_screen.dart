import 'dart:io';

import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/custody_export.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';

/// Comparateur des deux constats (EXI-CC30, differenciant D11).
///
/// L'ecran est accessible a l'expediteur, au livreur **et** a l'administrateur
/// (EXI-CC31) : jamais a une seule partie. Un comparateur reserve a
/// l'exploitation ne serait pas une preuve contradictoire, ce serait un dossier.
///
/// La presentation suit l'usage : les photos en vis-a-vis angle par angle, puis
/// les ecarts de grille surlignes, puis l'etat de la chaine. C'est l'ordre dans
/// lequel on instruit un litige — on regarde, on constate, on verifie que rien
/// n'a ete retouche.
class CustodyComparatorScreen extends StatelessWidget {
  const CustodyComparatorScreen({
    required this.chain,
    required this.delivery,
    super.key,
  });

  final CustodyChain chain;

  /// La course sert d'en-tete au PDF exporte (EXI-CC32).
  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pickup = chain.pickup;
    final handover = chain.handover;

    if (pickup == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.custodyComparatorTitle)),
        body: McEmptyState(
          icon: Icons.fact_check_outlined,
          title: l10n.custodyComparatorTitle,
          message: l10n.custodyIncomplete,
        ),
      );
    }

    final diff = chain.diff;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.custodyComparatorTitle),
        actions: [
          // EXI-CC32 : l'export est offert aux trois profils qui voient le
          // comparateur (EXI-CC31). Reserver le PDF a l'exploitation reviendrait
          // a garder la preuve d'un cote de la table.
          PopupMenuButton<CustodyReport>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.custodyExportPdf,
            onSelected: (report) =>
                exportCustodyPdf(context, report: report, delivery: delivery),
            itemBuilder: (_) => [
              PopupMenuItem(value: pickup, child: Text(l10n.custodyBefore)),
              if (handover != null)
                PopupMenuItem(value: handover, child: Text(l10n.custodyAfter)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ChainBanner(intact: chain.isIntact),
          const SizedBox(height: AppSpacing.lg),
          // Vis-a-vis angle par angle (EXI-CC21) : deux photos prises sous le
          // meme gabarit se comparent, deux photos libres se discutent.
          for (final angle in PhotoAngle.values) ...[
            _AnglePair(
              angle: angle,
              before: _photoFor(pickup, angle),
              after: handover == null ? null : _photoFor(handover, angle),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(l10n.custodyConditionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (diff == null || diff.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                title: Text(l10n.custodyNoDiff),
              ),
            )
          else
            _DiffCard(diff: diff),
        ],
      ),
    );
  }

  CustodyPhoto? _photoFor(CustodyReport report, PhotoAngle angle) {
    final matches = report.photos.where((p) => p.angle == angle);
    return matches.isEmpty ? null : matches.first;
  }
}

/// Etat de la chaine de preuve (EXI-CC44).
class _ChainBanner extends StatelessWidget {
  const _ChainBanner({required this.intact});

  final bool intact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = intact ? AppColors.success : AppColors.danger;

    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          children: [
            Icon(
              intact ? Icons.verified_outlined : Icons.gpp_bad_outlined,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intact ? l10n.custodyChainIntact : l10n.custodyChainBroken,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.custodyChainHelp,
                    style: theme.textTheme.bodyMedium,
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

/// Une paire avant / apres pour un angle donne.
class _AnglePair extends StatelessWidget {
  const _AnglePair({required this.angle, required this.before, this.after});

  final PhotoAngle angle;
  final CustodyPhoto? before;
  final CustodyPhoto? after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final label = switch (angle) {
      PhotoAngle.top => l10n.custodyPhotoTop,
      PhotoAngle.bottom => l10n.custodyPhotoBottom,
      PhotoAngle.side1 => l10n.custodyPhotoSide1,
      PhotoAngle.side2 => l10n.custodyPhotoSide2,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Side(caption: l10n.custodyBefore, photo: before),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _Side(caption: l10n.custodyAfter, photo: after),
            ),
          ],
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.caption, required this.photo});

  final String caption;
  final CustodyPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = photo == null ? null : File(photo!.localPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: AppRadii.componentAll,
            child: file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          caption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (photo != null)
          Text(
            '${photo!.takenAt.hour.toString().padLeft(2, '0')}:'
            '${photo!.takenAt.minute.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Ecarts de grille, surlignes (EXI-CC30).
class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.diff});

  final ConditionDiff diff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String label(ConditionCriterion c) => switch (c) {
      ConditionCriterion.packagingIntact => l10n.conditionPackagingIntact,
      ConditionCriterion.impactMark => l10n.conditionImpactMark,
      ConditionCriterion.moistureMark => l10n.conditionMoistureMark,
      ConditionCriterion.alreadyOpened => l10n.conditionAlreadyOpened,
      ConditionCriterion.originalTapePresent => l10n.conditionOriginalTape,
      ConditionCriterion.crushedCorners => l10n.conditionCrushedCorners,
    };

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diff.appeared.isNotEmpty) ...[
              Text(l10n.custodyAppeared, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final c in diff.appeared)
                _Row(
                  label: label(c),
                  // Une anomalie apparue engage la responsabilite : elle est
                  // signalee en rouge, un critere rassurant disparu en ambre.
                  color: c.positive ? AppColors.warning : AppColors.danger,
                  icon: Icons.add_circle_outline,
                ),
            ],
            if (diff.disappeared.isNotEmpty) ...[
              if (diff.appeared.isNotEmpty)
                const Divider(height: AppSpacing.xl),
              Text(l10n.custodyDisappeared, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final c in diff.disappeared)
                _Row(
                  label: label(c),
                  color: AppColors.warning,
                  icon: Icons.remove_circle_outline,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
