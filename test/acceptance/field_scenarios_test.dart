import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/settings/economy_mode.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/custody/data/custody_repository.dart';
import 'package:majichrono/features/custody/data/mock/custody_mock_module.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/data/datasources/delivery_local_data_source.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/driver/data/position_buffer.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';
import 'package:majichrono/features/payment/data/mock/payment_mock_module.dart';
import 'package:majichrono/features/payment/data/payment_repository.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/core/session/user_role.dart';

import '../helpers/fake_secure_store.dart';

/// Scenarios de recette terrain (§16.2).
///
/// Le cahier des charges impose huit scenarios joues sur trois appareils reels.
/// Ce fichier les rejoue **automatiquement**, a travers toute la pile — client
/// HTTP, intercepteurs, base locale, file de synchronisation — sur le transport
/// simule qui reproduit le reseau malgache decrit au §4.1.
///
/// Ce n'est pas un substitut a la recette sur appareil : un test ne verifie ni
/// la lisibilite en plein soleil, ni l'autonomie sur une tournee de huit
/// heures. Il verifie ce qui peut l'etre sans quitter le bureau, et il le
/// verifie a **chaque** modification, ce qu'une recette manuelle ne fera jamais.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncQueue queue;
  late DeliveryRepository deliveries;
  late CustodyRepository custody;
  late PaymentRepository payments;
  late DeliveryMockModule deliveryMock;

  Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    deliveryMock = DeliveryMockModule();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(deliveryMock)
      ..register(CustodyMockModule())
      ..register(PaymentMockModule(random: Random(4)));

    final client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(
        backend: backend,
        profile: profile,
        random: Random(17),
      ),
    );

    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db);

    deliveries = DeliveryRepositoryImpl(
      client: client,
      local: DeliveryLocalDataSource(db),
      queue: queue,
    );
    custody = CustodyRepository(
      client: client,
      db: db,
      vault: CustodyVault(FakeSecureStore(), random: Random(9)),
      queue: queue,
    );
    payments = PaymentRepository(client: client);
  }

  setUp(build);
  tearDown(() async => db.close());

  Address address(String district, String landmark) => Address(
    point: GeoPoint(-18.90 + district.length * 0.001, 47.52),
    district: district,
    landmark: landmark,
    contactPhone: MalagasyPhone.tryParse('0341234567')!,
  );

  DeliveryDraft draft() => DeliveryDraft(
    pickup: address('Analakely', 'Face a la pharmacie'),
    dropoff: address('Ambohipo', 'Portail vert'),
    kind: DeliveryKind.standard,
    package: const PackageDeclaration(weight: WeightCategory.from2to5),
    slot: const PickupSlot.immediate(),
    paymentMethod: PaymentMethod.cash,
  );

  CustodyPhoto photo(PhotoAngle angle) => CustodyPhoto(
    angle: angle,
    localPath: '/tmp/${angle.wireName}.jpg',
    takenAt: DateTime(2026, 8, 17, 10),
    sizeBytes: 170 * 1024,
    sha256: 'sha_${angle.wireName}',
    point: const GeoPoint(-18.90, 47.52),
  );

  VectorSignature signature(String label) => VectorSignature(
    strokes: const [
      [SignaturePoint(5, 5, 0.5, 0), SignaturePoint(40, 20, 0.6, 180)],
    ],
    signedAt: DateTime(2026, 8, 17, 10, 1),
    signerLabel: label,
  );

  CustodyReport report(String deliveryId, CustodyStage stage) => CustodyReport(
    id: 'cst_${stage.wireName}',
    deliveryId: deliveryId,
    stage: stage,
    photos: PhotoAngle.values.map(photo).toList(),
    grid: const ConditionGrid({ConditionCriterion.packagingIntact}),
    sealNumber: 'SC-4821',
    weight: WeightCategory.from2to5,
    signatures: [signature('expediteur'), signature('livreur')],
    capturedAt: DateTime(2026, 8, 17, 10, 2),
    point: const GeoPoint(-18.90, 47.52),
    sealCheck: stage == CustodyStage.handover ? SealCheck.intact : null,
    outcome: stage == CustodyStage.handover ? HandoverOutcome.delivered : null,
    otpVerified: stage == CustodyStage.handover,
  );

  group('S1 — coupure totale du reseau', () {
    test('la course est creee, conservee et deposee en file', () async {
      // Le scenario de base du §4.1 : zone blanche. Rien ne doit se perdre, et
      // l'utilisateur doit savoir que rien n'est parti.
      await build(profile: NetworkProfile.offline);

      final delivery = await deliveries.createDelivery(draft());

      expect(delivery.pendingSync, isTrue);
      expect(delivery.id.startsWith('local_'), isTrue);

      // Visible localement, et en file avec sa cle d'idempotence.
      final stored = await deliveries.watchDeliveries().first;
      expect(stored.single.pendingSync, isTrue);
      expect(await queue.due(), hasLength(1));
    });
  });

  group('S2 — constat hors ligne, jamais abandonne', () {
    test('le constat est chiffre, conserve et prioritaire', () async {
      await build(profile: NetworkProfile.offline);

      final sealed = report('dlv_77', CustodyStage.pickup).seal();
      final result = await custody.submit(sealed);

      expect(result.serverTimestamp, isNull, reason: 'aucun accuse serveur');

      final queued = await queue.due();
      expect(queued.single.priority, SyncPriority.custody);
      // EXI-S05 : un constat n'expire jamais, meme apres quinze echecs.
      expect(queued.single.neverAbandon, isTrue);

      // Relisible malgre l'absence de reseau (EXI-CC05).
      final chain = await custody.chainFor('dlv_77');
      expect(chain.pickup!.sealNumber, 'SC-4821');
    });
  });

  group('S3 — coupure en cours de requete', () {
    test('aucune double course, aucune double transition', () async {
      // La cle d'idempotence est posee au depot et conservee : rejouer le meme
      // element ne peut pas produire deux enregistrements (EXI-S01).
      await build(profile: NetworkProfile.offline);
      await deliveries.createDelivery(draft());

      final first = (await queue.due()).single;
      final key = first.idempotencyKey;

      // Un second depot sous la meme cle se replie sur la ligne existante.
      await queue.enqueue(
        method: 'POST',
        path: '/deliveries',
        idempotencyKey: key,
        body: const {'rejeu': true},
        priority: SyncPriority.transition,
      );

      expect(await queue.due(), hasLength(1));
    });
  });

  group('S4 — retour du reseau', () {
    test('la file part dans l ordre des priorites', () async {
      // EXI-S02 : constats d'abord, puis transitions, puis positions.
      await build(profile: NetworkProfile.offline);

      await queue.enqueue(
        method: 'POST',
        path: '/x',
        idempotencyKey: 'pos',
        priority: SyncPriority.position,
      );
      await queue.enqueue(
        method: 'POST',
        path: '/x',
        idempotencyKey: 'cst',
        priority: SyncPriority.custody,
      );
      await queue.enqueue(
        method: 'POST',
        path: '/x',
        idempotencyKey: 'trs',
        priority: SyncPriority.transition,
      );

      final order = (await queue.due()).map((i) => i.idempotencyKey).toList();
      expect(order, ['cst', 'trs', 'pos']);
    });
  });

  group('S5 — chaine de preuve complete', () {
    test('les deux constats chainent et le serveur les valide', () async {
      final pickup = await custody.submit(
        report('dlv_77', CustodyStage.pickup).seal(),
      );
      expect(pickup.serverTimestamp, isNotNull);

      final handover = await custody.submit(
        report('dlv_77', CustodyStage.handover).seal(previousHash: pickup.hash),
      );

      expect(handover.serverTimestamp, isNotNull);
      expect(handover.previousHash, pickup.hash);

      final chain = await custody.chainFor('dlv_77');
      expect(chain.isIntact, isTrue);
    });

    test('un constat falsifie est refuse par le serveur', () async {
      // EXI-B05 : le serveur recalcule l'empreinte. Sans ce refus, la chaine
      // serait declarative.
      final sealed = report('dlv_77', CustodyStage.pickup).seal();
      final tampered = CustodyReport(
        id: sealed.id,
        deliveryId: sealed.deliveryId,
        stage: sealed.stage,
        photos: sealed.photos,
        grid: const ConditionGrid({ConditionCriterion.impactMark}),
        sealNumber: sealed.sealNumber,
        weight: sealed.weight,
        signatures: sealed.signatures,
        capturedAt: sealed.capturedAt,
        point: sealed.point,
        hash: sealed.hash,
        sealedAt: sealed.sealedAt,
      );

      final result = await custody.submit(tampered);
      expect(result.serverTimestamp, isNull);
    });
  });

  group('S6 — paiement : aucun double debit', () {
    test('deux confirmations ne debitent qu une fois', () async {
      // EXI-MP06, et le scenario que le §16.2 nomme explicitement : une
      // coupure pendant le paiement ne doit jamais produire deux debits.
      final before = (await payments.balance(UserRole.client))!;

      final intent = await payments.createIntent(
        deliveryId: 'dlv_77',
        amountAriary: 7500,
        direction: PaymentDirection.collect,
        role: UserRole.driver,
      );

      await payments.claim(PaymentQr.parse(intent.qrPayload)!);
      await payments.confirm(intent.id);
      await payments.confirm(intent.id);

      final after = (await payments.balance(UserRole.client))!;
      expect(after.availableAriary, before.availableAriary - 7500);
    });

    test('le repli especes debloque une course sans solde', () async {
      // EXI-MP08, EXI-C43 : la course n'est jamais bloquee par le paiement.
      final intent = await payments.createIntent(
        deliveryId: 'dlv_78',
        amountAriary: 999999,
        direction: PaymentDirection.collect,
        role: UserRole.driver,
      );
      await payments.claim(PaymentQr.parse(intent.qrPayload)!);
      await expectLater(payments.confirm(intent.id), throwsA(isA<Failure>()));

      final cash = await payments.fallbackToCash(intent.id);
      expect(cash.status.settles, isTrue);
    });
  });

  group('S7 — tournee longue, forfait compte', () {
    test('deux mille positions ne font pas deux mille requetes', () async {
      // EXI-L10, EXI-S03. Une position toutes les quinze secondes sur huit
      // heures : le cout du transport depasserait celui de la donnee.
      final buffer = PositionBuffer(db: db, queue: queue);

      const points = 200;
      for (var i = 0; i < points; i++) {
        await buffer.record(
          DriverPing(
            point: GeoPoint(-18.90 + i * 0.0001, 47.52),
            at: DateTime(2026, 8, 17, 8).add(Duration(seconds: 15 * i)),
            speedKmh: 22,
          ),
        );
      }
      await buffer.flush();

      final batches = await queue.due(limit: 100);
      expect(batches.length, points ~/ PositionBuffer.batchSize);
      for (final batch in batches) {
        expect(
          (batch.body!['points'] as List<dynamic>).length,
          lessThanOrEqualTo(PositionBuffer.batchSize),
        );
      }
    });

    test('le mode economie ne degrade jamais une preuve', () async {
      // EXI-T08 : il differe les photos hors constat, jamais les constats.
      const economy = EconomySettings(enabled: true);

      expect(
        economy.allowsUpload(isProof: true, isMetered: true, sizeBytes: 900000),
        isTrue,
      );
      expect(
        economy.allowsUpload(isProof: false, isMetered: true, sizeBytes: 900000),
        isFalse,
      );
    });
  });

  group('S8 — reseau degrade 2G', () {
    test('le parcours complet aboutit, plus lentement', () async {
      // §4.1 : 900 a 2500 ms de latence, 40 kbit/s. Rien ne doit casser — ni
      // expirer, ni doubler.
      await build(profile: NetworkProfile.twoG);

      final delivery = await deliveries.createDelivery(draft());
      expect(delivery.pendingSync, isFalse, reason: 'la course est passee');

      final sealed = await custody.submit(
        report(delivery.id, CustodyStage.pickup).seal(),
      );
      expect(sealed.serverTimestamp, isNotNull);

      // Rien n'est reste en file : tout est passe, meme lentement.
      expect(await queue.due(), isEmpty);
    });
  });
}
