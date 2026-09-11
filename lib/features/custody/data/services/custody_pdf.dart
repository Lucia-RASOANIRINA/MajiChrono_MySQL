import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Export PDF d'un constat scelle (EXI-CC32).
///
/// Le PDF n'est pas la preuve — la preuve est l'empreinte SHA-256 recalculee
/// par le serveur (EXI-B05). Le PDF en est la **restitution lisible** : ce qu'on
/// imprime, joint a un courrier, ou tend a une assurance. Il porte donc
/// l'empreinte en clair, pour qu'un tiers puisse confronter le document a ce que
/// le serveur detient.
///
/// Tout est rendu hors ligne, a partir des fichiers locaux : un livreur en zone
/// blanche doit pouvoir remettre le constat sur-le-champ.
class CustodyPdf {
  const CustodyPdf();

  /// Etiquettes traduites, injectees plutot que lues depuis un contexte : le
  /// rendu ne doit dependre d'aucun widget vivant.
  static CustodyPdfLabels labelsFrom(AppLocalizations l10n) => CustodyPdfLabels(
    title: l10n.custodyPdfTitle,
    pickup: l10n.custodyBefore,
    handover: l10n.custodyAfter,
    seal: l10n.custodySealNumber,
    sealCheck: l10n.custodySealCheck,
    weight: l10n.custodyWeightConfirm,
    condition: l10n.custodyConditionTitle,
    photos: l10n.custodyStepPhotos,
    signatures: l10n.custodyStepSignatures,
    outcome: l10n.custodyOutcomeTitle,
    reason: l10n.custodyOutcomeReason,
    thirdPartyName: l10n.custodyThirdPartyName,
    thirdPartyRelation: l10n.custodyThirdPartyRelation,
    otp: l10n.custodyOtpTitle,
    hash: l10n.custodyPdfHash,
    previousHash: l10n.custodyPdfPreviousHash,
    sealedAt: l10n.custodyPdfSealedAt,
    serverTime: l10n.custodyPdfServerTime,
    pending: l10n.custodyPdfPending,
    notice: l10n.custodyPdfNotice,
  );

  /// Construit le document. Retourne les octets, pas un fichier : l'appelant
  /// decide s'il partage, imprime ou enregistre.
  Future<Uint8List> build({
    required CustodyReport report,
    required Delivery delivery,
    required CustodyPdfLabels labels,
    Map<String, String> conditionLabels = const {},
    Map<String, String> outcomeLabels = const {},
    Map<String, String> sealLabels = const {},
    // Les flux d'un PDF sont compresses par defaut. Les tests le desactivent
    // pour pouvoir relire le texte imprime — notamment l'empreinte, qui est la
    // seule chose que ce document doit garantir.
    bool compress = true,
  }) async {
    final doc = pw.Document(title: labels.title, compress: compress);

    // Les photos sont chargees une fois pour toutes : une image absente ne doit
    // pas faire echouer l'export, seulement laisser un emplacement vide. Un
    // constat partiellement illisible reste plus utile qu'aucun document.
    final images = <String, pw.MemoryImage>{};
    for (final photo in report.photos) {
      final file = File(photo.localPath);
      if (!file.existsSync()) continue;
      images[photo.sha256] = pw.MemoryImage(await file.readAsBytes());
    }

    final stageLabel = report.stage == CustodyStage.pickup
        ? labels.pickup
        : labels.handover;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              labels.notice,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => [
          _header(labels, stageLabel, delivery, report),
          pw.SizedBox(height: 14),
          _facts(labels, report, delivery, sealLabels, outcomeLabels),
          pw.SizedBox(height: 14),
          _grid(labels, report, conditionLabels),
          pw.SizedBox(height: 14),
          _photos(labels, report, images),
          pw.SizedBox(height: 14),
          _signatures(labels, report),
          pw.SizedBox(height: 14),
          _fingerprint(labels, report),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(
    CustodyPdfLabels labels,
    String stageLabel,
    Delivery delivery,
    CustodyReport report,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MajiChrono',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                '${labels.title} - $stageLabel',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                delivery.id,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _dateTime(report.capturedAt),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.blue900, thickness: 1.2),
    ],
  );

  pw.Widget _facts(
    CustodyPdfLabels labels,
    CustodyReport report,
    Delivery delivery,
    Map<String, String> sealLabels,
    Map<String, String> outcomeLabels,
  ) {
    final rows = <List<String>>[
      [labels.seal, report.sealNumber],
      [labels.weight, report.weight.wireName],
      if (report.sealCheck != null)
        [
          labels.sealCheck,
          sealLabels[report.sealCheck!.wireName] ?? report.sealCheck!.wireName,
        ],
      if (report.outcome != null)
        [
          labels.outcome,
          outcomeLabels[report.outcome!.wireName] ?? report.outcome!.wireName,
        ],
      if ((report.reserveReason ?? '').isNotEmpty)
        [labels.reason, report.reserveReason!],
      if ((report.thirdPartyName ?? '').isNotEmpty)
        [labels.thirdPartyName, report.thirdPartyName!],
      if ((report.thirdPartyRelation ?? '').isNotEmpty)
        [labels.thirdPartyRelation, report.thirdPartyRelation!],
      if (report.stage == CustodyStage.handover)
        [labels.otp, report.otpVerified ? 'OK' : '-'],
      [
        'GPS',
        '${report.point.latitude.toStringAsFixed(5)}, '
            '${report.point.longitude.toStringAsFixed(5)}',
      ],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)},
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 9)),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _grid(
    CustodyPdfLabels labels,
    CustodyReport report,
    Map<String, String> conditionLabels,
  ) {
    final checked = report.grid.checked.toList()
      ..sort((a, b) => a.wireName.compareTo(b.wireName));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(labels.condition),
        if (checked.isEmpty)
          pw.Text('-', style: const pw.TextStyle(fontSize: 9))
        else
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in checked)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: c.positive ? PdfColors.green50 : PdfColors.red50,
                    border: pw.Border.all(
                      color: c.positive ? PdfColors.green700 : PdfColors.red700,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    conditionLabels[c.wireName] ?? c.wireName,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _photos(
    CustodyPdfLabels labels,
    CustodyReport report,
    Map<String, pw.MemoryImage> images,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(labels.photos),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final photo in report.photos)
            pw.Container(
              width: 120,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 90,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                    child: images[photo.sha256] == null
                        ? pw.Center(
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          )
                        : pw.Image(images[photo.sha256]!, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '${photo.angle.wireName} - ${_time(photo.takenAt)}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  // L'empreinte de chaque photo est imprimee : c'est ce qui
                  // permet de verifier qu'une image jointe au dossier est bien
                  // celle qui a ete scellee, et non une autre prise le meme jour.
                  pw.Text(
                    photo.sha256.substring(0, photo.sha256.length.clamp(0, 16)),
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if ((photo.anomalyNote ?? '').isNotEmpty)
                    pw.Text(
                      photo.anomalyNote!,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.red800,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  pw.Widget _signatures(CustodyPdfLabels labels, CustodyReport report) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(labels.signatures),
          pw.Row(
            children: [
              for (final signature in report.signatures)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          height: 70,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.grey400,
                              width: 0.5,
                            ),
                          ),
                          child: pw.CustomPaint(
                            size: const PdfPoint(160, 70),
                            painter: (canvas, size) =>
                                _drawSignature(canvas, size, signature),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          signature.signerLabel,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${_dateTime(signature.signedAt)} - '
                          '${signature.pointCount} pts / '
                          '${signature.duration.inMilliseconds} ms',
                          style: const pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  /// Retrace la signature a partir de son vecteur.
  ///
  /// La signature n'est pas stockee comme image : elle est rejouee ici. Le trace
  /// reste net a toute echelle, et surtout les points, la pression et les temps
  /// restent disponibles pour une expertise (EXI-CC40) — ce qu'une capture
  /// aplatie en pixels aurait detruit.
  void _drawSignature(
    dynamic canvas,
    PdfPoint size,
    VectorSignature signature,
  ) {
    final points = signature.strokes.expand((s) => s).toList();
    if (points.isEmpty) return;

    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    const pad = 5.0;
    final spanX = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;
    final scale = [
      (size.x - 2 * pad) / spanX,
      (size.y - 2 * pad) / spanY,
    ].reduce((a, b) => a < b ? a : b);

    canvas
      ..setStrokeColor(PdfColors.blueGrey900)
      ..setLineWidth(1.1);

    for (final stroke in signature.strokes) {
      if (stroke.isEmpty) continue;
      // L'axe vertical du PDF part du bas : sans ce retournement, toute
      // signature serait imprimee la tete en bas.
      double px(SignaturePoint p) => pad + (p.x - minX) * scale;
      double py(SignaturePoint p) => size.y - pad - (p.y - minY) * scale;

      canvas.moveTo(px(stroke.first), py(stroke.first));
      for (final point in stroke.skip(1)) {
        canvas.lineTo(px(point), py(point));
      }
      canvas.strokePath();
    }
  }

  pw.Widget _fingerprint(
    CustodyPdfLabels labels,
    CustodyReport report,
  ) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          labels.hash,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(report.hash ?? '-', style: const pw.TextStyle(fontSize: 8)),
        if (report.previousHash != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            labels.previousHash,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(report.previousHash!, style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          '${labels.sealedAt} ${_dateTime(report.sealedAt)}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          report.serverTimestamp == null
              ? labels.pending
              : '${labels.serverTime} ${_dateTime(report.serverTimestamp)}',
          style: pw.TextStyle(
            fontSize: 8,
            color: report.serverTimestamp == null
                ? PdfColors.orange800
                : PdfColors.green800,
          ),
        ),
      ],
    ),
  );

  pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _time(DateTime? d) =>
      d == null ? '-' : '${_two(d.hour)}:${_two(d.minute)}';

  static String _dateTime(DateTime? d) =>
      d == null ? '-' : '${_two(d.day)}/${_two(d.month)}/${d.year} ${_time(d)}';
}

/// Etiquettes du document, traduites en amont du rendu.
class CustodyPdfLabels {
  const CustodyPdfLabels({
    required this.title,
    required this.pickup,
    required this.handover,
    required this.seal,
    required this.sealCheck,
    required this.weight,
    required this.condition,
    required this.photos,
    required this.signatures,
    required this.outcome,
    required this.reason,
    required this.thirdPartyName,
    required this.thirdPartyRelation,
    required this.otp,
    required this.hash,
    required this.previousHash,
    required this.sealedAt,
    required this.serverTime,
    required this.pending,
    required this.notice,
  });

  final String title;
  final String pickup;
  final String handover;
  final String seal;
  final String sealCheck;
  final String weight;
  final String condition;
  final String photos;
  final String signatures;
  final String outcome;
  final String reason;
  final String thirdPartyName;
  final String thirdPartyRelation;
  final String otp;
  final String hash;
  final String previousHash;
  final String sealedAt;
  final String serverTime;
  final String pending;
  final String notice;
}
