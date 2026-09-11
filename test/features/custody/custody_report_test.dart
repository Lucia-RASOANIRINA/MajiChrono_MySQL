import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Module 5 — chaine de responsabilite (§7.3).
///
/// C'est le coeur differenciant du produit : la preuve opposable qu'aucun
/// concurrent local ne fournit (§3.3). Ces tests portent sur ce qui rend cette
/// preuve defendable — l'empreinte, le chainage, et le fait qu'un constat
/// incomplet ne puisse pas laisser progresser la course.
void main() {
  CustodyPhoto photo(
    PhotoAngle angle, {
    String? note,
    int size = 180 * 1024,
  }) =>
      CustodyPhoto(
        angle: angle,
        localPath: '/tmp/${angle.wireName}.jpg',
        takenAt: DateTime(2026, 8, 14, 10, 30),
        sizeBytes: size,
        sha256: 'sha_${angle.wireName}',
        point: const GeoPoint(-18.9010, 47.5490),
        anomalyNote: note,
      );

  VectorSignature signature(String label) => VectorSignature(
        strokes: [
          [
            const SignaturePoint(10, 20, 0.5, 0),
            const SignaturePoint(30, 25, 0.7, 120),
            const SignaturePoint(50, 18, 0.4, 260),
          ],
        ],
        signedAt: DateTime(2026, 8, 14, 10, 31),
        signerLabel: label,
      );

  CustodyReport report({
    CustodyStage stage = CustodyStage.pickup,
    List<PhotoAngle> angles = PhotoAngle.values,
    Set<ConditionCriterion> checked = const {},
    String seal = 'SC-4821',
    int signatures = 2,
    SealCheck? sealCheck,
    bool otpVerified = false,
    String? anomalyNote,
    List<CustodyPhoto>? extraPhotos,
    HandoverOutcome? outcome,
    String? reserveReason,
    String? thirdPartyName,
    String? thirdPartyRelation,
  }) =>
      CustodyReport(
        id: 'cst_1',
        deliveryId: 'dlv_1',
        stage: stage,
        photos: [
          ...angles.map((a) => photo(a, note: anomalyNote)),
          ...?extraPhotos,
        ],
        grid: ConditionGrid(checked),
        sealNumber: seal,
        weight: WeightCategory.from2to5,
        signatures: List.generate(
          signatures,
          (i) => signature(i == 0 ? 'expediteur' : 'livreur'),
        ),
        capturedAt: DateTime(2026, 8, 14, 10, 32),
        point: const GeoPoint(-18.9010, 47.5490),
        sealCheck: sealCheck,
        outcome: outcome,
        reserveReason: reserveReason,
        thirdPartyName: thirdPartyName,
        thirdPartyRelation: thirdPartyRelation,
        otpVerified: otpVerified,
      );

  group('completude du constat (EXI-CC02, EXI-CC03)', () {
    test('un constat de prise en charge complet est valide', () {
      expect(report().isComplete, isTrue);
    });

    test('il manque un angle : le constat est incomplet (EXI-CC10)', () {
      // Quatre angles au minimum. Sans eux, la comparaison de la remise
      // n'aurait rien a comparer.
      expect(
        report(angles: const [PhotoAngle.top, PhotoAngle.bottom]).isComplete,
        isFalse,
      );
    });

    test('sans numero de scelle, le constat est incomplet (EXI-CC14)', () {
      expect(report(seal: '   ').isComplete, isFalse);
    });

    test('une seule signature ne suffit pas (EXI-CC16, EXI-CC17)', () {
      // Le constat est **contradictoire** : la contre-signature du livreur
      // n'est pas une formalite, c'est ce qui engage les deux parties.
      expect(report(signatures: 1).isComplete, isFalse);
    });

    test('une anomalie cochee sans commentaire bloque le constat (EXI-CC13)', () {
      final withAnomaly = report(checked: {ConditionCriterion.impactMark});
      expect(withAnomaly.grid.hasAnomaly, isTrue);
      expect(withAnomaly.isComplete, isFalse);
    });

    test('la meme anomalie documentee laisse passer le constat', () {
      final documented = report(
        checked: {ConditionCriterion.impactMark},
        anomalyNote: 'Choc sur l angle superieur droit',
      );
      expect(documented.isComplete, isTrue);
    });

    test('cocher un critere rassurant n exige aucune photo dediee', () {
      // « Emballage intact » n'est pas une anomalie : l'exiger documente
      // ferait cocher n'importe quoi pour avancer.
      final positive = report(
        checked: {
          ConditionCriterion.packagingIntact,
          ConditionCriterion.originalTapePresent,
        },
      );
      expect(positive.grid.hasAnomaly, isFalse);
      expect(positive.isComplete, isTrue);
    });
  });

  group('constat de remise (EXI-CC22, EXI-CC24)', () {
    CustodyReport handover({
      SealCheck? sealCheck = SealCheck.intact,
      bool otp = true,
      List<CustodyPhoto>? extra,
      HandoverOutcome outcome = HandoverOutcome.delivered,
      int signatures = 2,
      String? reason,
      String? thirdPartyName,
      String? thirdPartyRelation,
    }) =>
        report(
          stage: CustodyStage.handover,
          sealCheck: sealCheck,
          otpVerified: otp,
          extraPhotos: extra,
          outcome: outcome,
          signatures: signatures,
          reserveReason: reason,
          thirdPartyName: thirdPartyName,
          thirdPartyRelation: thirdPartyRelation,
        );

    test('une remise complete est valide', () {
      expect(handover().isComplete, isTrue);
    });

    test('sans verification du scelle, la remise est incomplete', () {
      expect(handover(sealCheck: null).isComplete, isFalse);
    });

    test('sans code OTP, la remise est incomplete', () {
      // EXI-CC24 : signature **et** OTP. C'est la double preuve d'identite du
      // destinataire qui donne sa valeur au faisceau.
      expect(handover(otp: false).isComplete, isFalse);
    });

    test('un scelle rompu exige une photo supplementaire', () {
      expect(handover(sealCheck: SealCheck.broken).isComplete, isFalse);

      final documented = handover(
        sealCheck: SealCheck.broken,
        extra: [photo(PhotoAngle.top, note: 'Scelle rompu')],
      );
      expect(documented.isComplete, isTrue);
    });

    test('un scelle rompu ou absent declenche un incident', () {
      expect(SealCheck.broken.requiresIncident, isTrue);
      expect(SealCheck.absent.requiresIncident, isTrue);
      expect(SealCheck.intact.requiresIncident, isFalse);
    });

    test('une issue de remise doit etre choisie explicitement', () {
      // Une remise sans issue renseignee ne dit pas ce qui s'est passe. Aucun
      // defaut implicite : « livre » doit etre affirme, jamais suppose.
      expect(handover(outcome: HandoverOutcome.delivered).isComplete, isTrue);
      expect(
        report(
          stage: CustodyStage.handover,
          sealCheck: SealCheck.intact,
          otpVerified: true,
        ).isComplete,
        isFalse,
      );
    });
  });

  group('issues de remise (EXI-CC26 a EXI-CC29)', () {
    CustodyReport handover({
      required HandoverOutcome outcome,
      bool otp = true,
      int signatures = 2,
      List<CustodyPhoto>? extra,
      String? reason,
      String? thirdPartyName,
      String? thirdPartyRelation,
    }) => report(
      stage: CustodyStage.handover,
      sealCheck: SealCheck.intact,
      otpVerified: otp,
      outcome: outcome,
      signatures: signatures,
      extraPhotos: extra,
      reserveReason: reason,
      thirdPartyName: thirdPartyName,
      thirdPartyRelation: thirdPartyRelation,
    );

    test('une remise sous reserves exige un motif (EXI-CC26)', () {
      expect(handover(outcome: HandoverOutcome.withReserves).isComplete, isFalse);
      expect(
        handover(
          outcome: HandoverOutcome.withReserves,
          reason: 'Coin du carton enfonce a l ouverture',
        ).isComplete,
        isTrue,
      );
    });

    test('une remise sous reserves ouvre un litige (EXI-CC26)', () {
      expect(HandoverOutcome.withReserves.opensDispute, isTrue);
      expect(HandoverOutcome.delivered.opensDispute, isFalse);
    });

    test('un refus exige motif et photo, mais pas d OTP (EXI-CC27)', () {
      // Un destinataire qui refuse le colis ne confirmera pas la remise par un
      // code : exiger l'OTP rendrait le refus impossible a consigner.
      expect(HandoverOutcome.refused.requiresOtp, isFalse);

      expect(
        handover(outcome: HandoverOutcome.refused, otp: false).isComplete,
        isFalse,
      );
      expect(
        handover(
          outcome: HandoverOutcome.refused,
          otp: false,
          reason: 'Le destinataire refuse : commande annulee de son cote',
          extra: [photo(PhotoAngle.top, note: 'Colis refuse, scelle intact')],
        ).isComplete,
        isTrue,
      );
    });

    test('un refus renvoie le colis, il ne le livre pas', () {
      expect(HandoverOutcome.refused.resultingStatus, isNot(DeliveryStatus.delivered));
    });

    test('une remise a un tiers identifie le tiers (EXI-CC28)', () {
      final idPhoto = [photo(PhotoAngle.top, note: 'Piece d identite du tiers')];

      // Le nom seul ne suffit pas : c'est le **lien** avec le destinataire qui
      // rend la remise opposable en cas de contestation.
      expect(
        handover(
          outcome: HandoverOutcome.thirdParty,
          otp: false,
          extra: idPhoto,
          thirdPartyName: 'Rakoto Andrianina',
        ).isComplete,
        isFalse,
      );

      // La piece d'identite photographiee n'est pas optionnelle non plus.
      expect(
        handover(
          outcome: HandoverOutcome.thirdParty,
          otp: false,
          thirdPartyName: 'Rakoto Andrianina',
          thirdPartyRelation: 'Gardien de l immeuble',
        ).isComplete,
        isFalse,
      );

      expect(
        handover(
          outcome: HandoverOutcome.thirdParty,
          otp: false,
          extra: idPhoto,
          thirdPartyName: 'Rakoto Andrianina',
          thirdPartyRelation: 'Gardien de l immeuble',
        ).isComplete,
        isTrue,
      );
    });

    test('une remise sans signature se paie d une photo (EXI-CC29)', () {
      expect(HandoverOutcome.noSignature.requiresRecipientSignature, isFalse);

      // Une seule signature — celle du livreur — mais motif et photo obligatoires.
      expect(
        handover(
          outcome: HandoverOutcome.noSignature,
          otp: false,
          signatures: 1,
        ).isComplete,
        isFalse,
      );
      expect(
        handover(
          outcome: HandoverOutcome.noSignature,
          otp: false,
          signatures: 1,
          reason: 'Destinataire presse, refuse de signer',
          extra: [photo(PhotoAngle.top, note: 'Colis remis en main propre')],
        ).isComplete,
        isTrue,
      );
    });

    test('une remise nominale n exige ni motif ni photo supplementaire', () {
      expect(HandoverOutcome.delivered.requiresReason, isFalse);
      expect(HandoverOutcome.delivered.requiresExtraPhoto, isFalse);
      expect(HandoverOutcome.delivered.requiresOtp, isTrue);
    });

    test('l issue entre dans l empreinte du constat (EXI-CC43)', () {
      // Sinon deux constats racontant des remises differentes porteraient la
      // meme empreinte, et le scellement ne protegerait pas le recit.
      final delivered = handover(outcome: HandoverOutcome.delivered);
      final reserved = handover(
        outcome: HandoverOutcome.withReserves,
        reason: 'Coin du carton enfonce a l ouverture',
      );
      expect(delivered.computeHash(), isNot(reserved.computeHash()));
    });
  });

  group('empreinte et scellement (EXI-CC43, EXI-CC04)', () {
    test('l empreinte est deterministe', () {
      expect(report().computeHash(), report().computeHash());
    });

    test('l ordre des photos ne change pas l empreinte', () {
      // Le corps canonique trie les photos : deux serialisations du meme
      // constat doivent donner la meme empreinte, sinon le serveur rejetterait
      // un constat pourtant intact (EXI-B05).
      final ordered = report();
      final shuffled = report(
        angles: const [
          PhotoAngle.side2,
          PhotoAngle.top,
          PhotoAngle.side1,
          PhotoAngle.bottom,
        ],
      );
      expect(shuffled.computeHash(), ordered.computeHash());
    });

    test('modifier le moindre element change l empreinte', () {
      final original = report().computeHash();
      expect(report(seal: 'SC-9999').computeHash(), isNot(original));
      expect(
        report(checked: {ConditionCriterion.impactMark}).computeHash(),
        isNot(original),
      );
    });

    test('sceller pose l empreinte et l horodatage', () {
      final sealed = report().seal();

      expect(sealed.isSealed, isTrue);
      expect(sealed.hash, isNotNull);
      expect(sealed.verifyIntegrity(), isTrue);
    });

    test('une alteration apres scellement est detectable', () {
      final sealed = report().seal();

      // On reconstruit le meme constat avec un scelle different, en gardant
      // l'empreinte d'origine : c'est exactement ce que ferait une falsification.
      final tampered = report(seal: 'SC-0000').copyWithHash(sealed.hash!);

      expect(tampered.verifyIntegrity(), isFalse);
    });
  });

  group('chainage des deux constats (EXI-CC44)', () {
    test('la remise integre l empreinte de la prise en charge', () {
      final pickup = report().seal();
      final handover = report(
        stage: CustodyStage.handover,
        sealCheck: SealCheck.intact,
        otpVerified: true,
      ).seal(previousHash: pickup.hash);

      expect(handover.previousHash, pickup.hash);

      final chain = CustodyChain(pickup: pickup, handover: handover);
      expect(chain.isIntact, isTrue);
    });

    test('alterer la prise en charge rompt la chaine', () {
      final pickup = report().seal();
      final handover = report(
        stage: CustodyStage.handover,
        sealCheck: SealCheck.intact,
        otpVerified: true,
      ).seal(previousHash: pickup.hash);

      // Le constat de depart est modifie apres coup : son empreinte ne
      // correspond plus, et la chaine s'en apercoit.
      final tampered = report(seal: 'SC-0000').copyWithHash(pickup.hash!);

      expect(
        CustodyChain(pickup: tampered, handover: handover).isIntact,
        isFalse,
      );
    });

    test('une remise qui reference une autre prise en charge rompt la chaine', () {
      final pickup = report().seal();
      final handover = report(
        stage: CustodyStage.handover,
        sealCheck: SealCheck.intact,
        otpVerified: true,
      ).seal(previousHash: 'empreinte_etrangere');

      expect(
        CustodyChain(pickup: pickup, handover: handover).isIntact,
        isFalse,
      );
    });
  });

  group('comparaison des grilles (EXI-CC30, D11)', () {
    test('aucun ecart quand l etat est identique', () {
      final grid = ConditionGrid({ConditionCriterion.packagingIntact});
      expect(grid.diff(grid).isEmpty, isTrue);
    });

    test('une anomalie apparue en transport est isolee', () {
      // C'est le cas qui tranche le litige : le colis est parti intact et
      // arrive marque.
      final atPickup = ConditionGrid({ConditionCriterion.packagingIntact});
      final atHandover = ConditionGrid({
        ConditionCriterion.packagingIntact,
        ConditionCriterion.crushedCorners,
      });

      final diff = atPickup.diff(atHandover);
      expect(diff.appeared, {ConditionCriterion.crushedCorners});
      expect(diff.disappeared, isEmpty);
      expect(diff.hasNewAnomaly, isTrue);
    });

    test('un critere rassurant disparu ne compte pas comme anomalie nouvelle', () {
      final atPickup = ConditionGrid({ConditionCriterion.originalTapePresent});
      const atHandover = ConditionGrid({});

      final diff = atPickup.diff(atHandover);
      expect(diff.disappeared, {ConditionCriterion.originalTapePresent});
      expect(diff.hasNewAnomaly, isFalse);
      expect(diff.isEmpty, isFalse);
    });
  });

  group('budget de poids (EXI-CC42)', () {
    test('un constat de quatre photos compressees tient dans 1,2 Mo', () {
      final r = report();
      expect(r.totalBytes, lessThanOrEqualTo(CustodyReport.maxBytes));
      expect(r.fitsBudget, isTrue);
    });

    test('des photos non compressees font sauter le budget', () {
      final heavy = CustodyReport(
        id: 'cst_2',
        deliveryId: 'dlv_1',
        stage: CustodyStage.pickup,
        photos: PhotoAngle.values
            .map((a) => photo(a, size: 900 * 1024))
            .toList(),
        grid: const ConditionGrid({}),
        sealNumber: 'SC-1',
        weight: WeightCategory.upTo2,
        signatures: [signature('a'), signature('b')],
        capturedAt: DateTime(2026, 8, 14),
        point: GeoPoint.antananarivo,
      );
      expect(heavy.fitsBudget, isFalse);
    });
  });

  group('signature vectorielle (EXI-CC40)', () {
    test('le vecteur conserve les points, la pression et le temps', () {
      final s = signature('expediteur');

      expect(s.pointCount, 3);
      expect(s.duration, const Duration(milliseconds: 260));
      // Ce que le PNG seul ne dirait pas : la signature a ete tracee en
      // 260 ms, information utile a l'instruction d'un litige.
      expect(s.toJson()['strokes'], isNotEmpty);
    });
  });
}
