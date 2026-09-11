import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:majichrono/features/custody/data/services/custody_pdf.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Export PDF d'un constat scelle (EXI-CC32).
///
/// Le partage passe par la feuille systeme : sur un telephone malgache d'entree
/// de gamme, le constat part le plus souvent par WhatsApp ou Bluetooth, pas par
/// courriel. Imposer un canal reviendrait a rendre l'export inutilisable la ou
/// il sert le plus.
Future<void> exportCustodyPdf(
  BuildContext context, {
  required CustodyReport report,
  required Delivery delivery,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  String criterion(ConditionCriterion c) => switch (c) {
    ConditionCriterion.packagingIntact => l10n.conditionPackagingIntact,
    ConditionCriterion.impactMark => l10n.conditionImpactMark,
    ConditionCriterion.moistureMark => l10n.conditionMoistureMark,
    ConditionCriterion.alreadyOpened => l10n.conditionAlreadyOpened,
    ConditionCriterion.originalTapePresent => l10n.conditionOriginalTape,
    ConditionCriterion.crushedCorners => l10n.conditionCrushedCorners,
  };

  String outcome(HandoverOutcome o) => switch (o) {
    HandoverOutcome.delivered => l10n.outcomeDelivered,
    HandoverOutcome.withReserves => l10n.outcomeWithReserves,
    HandoverOutcome.refused => l10n.outcomeRefused,
    HandoverOutcome.thirdParty => l10n.outcomeThirdParty,
    HandoverOutcome.noSignature => l10n.outcomeNoSignature,
  };

  String seal(SealCheck s) => switch (s) {
    SealCheck.intact => l10n.sealIntact,
    SealCheck.broken => l10n.sealBroken,
    SealCheck.absent => l10n.sealAbsent,
  };

  try {
    final bytes = await const CustodyPdf().build(
      report: report,
      delivery: delivery,
      labels: CustodyPdf.labelsFrom(l10n),
      conditionLabels: {
        for (final c in ConditionCriterion.values) c.wireName: criterion(c),
      },
      outcomeLabels: {
        for (final o in HandoverOutcome.values) o.wireName: outcome(o),
      },
      sealLabels: {for (final s in SealCheck.values) s.wireName: seal(s)},
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'constat_${delivery.id}_${report.stage.wireName}.pdf',
    );

    messenger.showSnackBar(SnackBar(content: Text(l10n.custodyExportPdfDone)));
  } on Object {
    // Un export rate ne doit pas faire tomber l'ecran : la preuve est deja
    // scellee et transmise, le PDF n'en est que la restitution.
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.custodyExportPdfFailed)),
    );
  }
}
