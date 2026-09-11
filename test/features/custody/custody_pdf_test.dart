import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/features/custody/data/services/custody_pdf.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Export PDF du constat (EXI-CC32).
///
/// Le PDF n'est pas la preuve : la preuve est l'empreinte que le serveur
/// recalcule. Mais c'est le document qu'on tend a une assurance ou qu'on joint a
/// une reclamation, et il ne vaut rien s'il n'y porte pas l'empreinte.
void main() {
  late Directory temp;

  const labels = CustodyPdfLabels(
    title: 'Constat contradictoire',
    pickup: 'Prise en charge',
    handover: 'Remise',
    seal: 'Numero de scelle',
    sealCheck: 'Etat du scelle',
    weight: 'Poids confirme',
    condition: 'Etat du colis',
    photos: 'Photos',
    signatures: 'Signatures',
    outcome: 'Issue de la remise',
    reason: 'Motif ecrit',
    thirdPartyName: 'Nom du tiers',
    thirdPartyRelation: 'Lien avec le destinataire',
    otp: 'Code du destinataire',
    hash: 'Empreinte SHA-256',
    previousHash: 'Empreinte precedente',
    sealedAt: 'Scelle le',
    serverTime: 'Recu par le serveur le',
    pending: 'Non transmis',
    notice: 'Document genere par MajiChrono.',
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('majichrono_pdf');
  });
  tearDown(() async => temp.delete(recursive: true));

  Address address(String landmark) => Address(
    point: const GeoPoint(-18.9010, 47.5490),
    district: 'Analakely',
    landmark: landmark,
    contactPhone: MalagasyPhone.tryParse('0341234567')!,
  );

  Delivery delivery() => Delivery(
    id: 'dlv_77',
    status: DeliveryStatus.delivered,
    kind: DeliveryKind.standard,
    pickup: address('Face a la pharmacie'),
    dropoff: address('Portail bleu, apres le pont'),
    package: const PackageDeclaration(weight: WeightCategory.from2to5),
    slot: const PickupSlot.immediate(),
    paymentMethod: PaymentMethod.cash,
    createdAt: DateTime(2026, 8, 14, 10),
  );

  CustodyPhoto photo(PhotoAngle angle) => CustodyPhoto(
    angle: angle,
    localPath: '${temp.path}/${angle.wireName}.jpg',
    takenAt: DateTime(2026, 8, 14, 10, 30),
    sizeBytes: 170 * 1024,
    sha256: 'sha_${angle.wireName}',
    point: const GeoPoint(-18.9010, 47.5490),
  );

  VectorSignature signature(String label) => VectorSignature(
    strokes: const [
      [
        SignaturePoint(5, 5, 0.5, 0),
        SignaturePoint(40, 20, 0.6, 180),
        SignaturePoint(70, 8, 0.4, 320),
      ],
      [SignaturePoint(75, 30, 0.5, 500), SignaturePoint(95, 12, 0.5, 640)],
    ],
    signedAt: DateTime(2026, 8, 14, 10, 31),
    signerLabel: label,
  );

  CustodyReport report({
    CustodyStage stage = CustodyStage.handover,
    HandoverOutcome? outcome = HandoverOutcome.withReserves,
  }) => CustodyReport(
    id: 'cst_1',
    deliveryId: 'dlv_77',
    stage: stage,
    photos: PhotoAngle.values.map(photo).toList(),
    grid: const ConditionGrid({ConditionCriterion.impactMark}),
    sealNumber: 'SC-4821',
    weight: WeightCategory.from2to5,
    signatures: [signature('destinataire'), signature('livreur')],
    capturedAt: DateTime(2026, 8, 14, 10, 32),
    point: const GeoPoint(-18.9010, 47.5490),
    sealCheck: stage == CustodyStage.handover ? SealCheck.intact : null,
    outcome: stage == CustodyStage.handover ? outcome : null,
    reserveReason: 'Coin du carton enfonce a l ouverture',
    otpVerified: true,
  ).seal(previousHash: 'a' * 64);

  test('le document porte l empreinte et le chainage', () async {
    final sealed = report();
    final bytes = await const CustodyPdf().build(
      report: sealed,
      delivery: delivery(),
      labels: labels,
    );

    expect(bytes, isNotEmpty);
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');

    // Relu sans compression, le document doit contenir l'empreinte en clair :
    // c'est elle qui permet a un tiers de confronter le papier a ce que le
    // serveur detient. Un PDF qui ne la porterait pas ne serait qu'une image.
    final readable = utf8.decode(
      await const CustodyPdf().build(
        report: sealed,
        delivery: delivery(),
        labels: labels,
        compress: false,
      ),
      allowMalformed: true,
    );

    // Le flux PDF pose chaque mot separement : on cherche des jetons entiers,
    // pas des phrases.
    expect(readable, contains(sealed.hash));
    expect(readable, contains('a' * 64), reason: 'le chainage doit apparaitre');
    expect(readable, contains('SC-4821'));
    expect(readable, contains('dlv_77'));
    expect(readable, contains('transmis'), reason: 'constat non accuse');
  });

  test('une photo absente du disque ne fait pas echouer l export', () async {
    // Un livreur peut avoir nettoye son stockage, ou l'export etre relance
    // depuis un autre appareil. Un constat partiellement illisible reste plus
    // utile qu'aucun document.
    final bytes = await const CustodyPdf().build(
      report: report(),
      delivery: delivery(),
      labels: labels,
    );

    expect(bytes, isNotEmpty);
  });

  test('un constat de prise en charge s exporte sans issue de remise', () async {
    final bytes = await const CustodyPdf().build(
      report: report(stage: CustodyStage.pickup),
      delivery: delivery(),
      labels: labels,
    );

    expect(bytes, isNotEmpty);
  });

  test('un constat non transmis est exportable et le dit', () async {
    // EXI-CC05 : hors ligne, le constat existe deja. L'export doit fonctionner
    // avant l'accuse de reception, sinon le PDF ne servirait qu'une fois le
    // reseau revenu — c'est-a-dire jamais au moment ou l'on en a besoin.
    final sealed = report();
    expect(sealed.serverTimestamp, isNull);

    final bytes = await const CustodyPdf().build(
      report: sealed,
      delivery: delivery(),
      labels: labels,
    );

    expect(bytes, isNotEmpty);
  });

  test('les photos presentes sur disque sont integrees', () async {
    // Un JPEG minimal valide suffit : ce qu'on verifie, c'est que le rendu lit
    // le fichier et grossit d'autant, pas la qualite de l'image.
    final jpeg = base64Decode(
      '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
      'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
      'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
    );
    for (final angle in PhotoAngle.values) {
      await File('${temp.path}/${angle.wireName}.jpg').writeAsBytes(jpeg);
    }

    final withPhotos = await const CustodyPdf().build(
      report: report(),
      delivery: delivery(),
      labels: labels,
    );

    for (final angle in PhotoAngle.values) {
      await File('${temp.path}/${angle.wireName}.jpg').delete();
    }
    final withoutPhotos = await const CustodyPdf().build(
      report: report(),
      delivery: delivery(),
      labels: labels,
    );

    expect(withPhotos.length, greaterThan(withoutPhotos.length));
  });
}
