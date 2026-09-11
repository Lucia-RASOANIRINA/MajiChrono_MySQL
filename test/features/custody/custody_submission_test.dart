import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/custody/data/custody_repository.dart';
import 'package:majichrono/features/custody/data/mock/custody_mock_module.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

import '../../helpers/fake_secure_store.dart';

/// Transmission des constats.
///
/// Le controle decisif est cote serveur : il **recalcule** l'empreinte et
/// refuse toute incoherence (EXI-B05). Sans lui, la chaine de preuve serait
/// declarative — un client qui casserait la serialisation canonique ne s'en
/// apercevrait que le jour d'un litige.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustodyRepository repository;
  late AppDatabase db;

  Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(CustodyMockModule());

    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CustodyRepository(
      client: ApiClient(
        config: AppConfig.fromEnvironment(),
        dataMeter: DataMeter(prefs),
        mockBackend: backend,
        mockAdapter: MockHttpAdapter(
          backend: backend,
          profile: profile,
          random: Random(5),
        ),
      ),
      db: db,
      vault: CustodyVault(FakeSecureStore(), random: Random(9)),
      queue: SyncQueue(db),
    );
  }

  setUp(build);
  tearDown(() async => db.close());

  CustodyPhoto photo(PhotoAngle angle) => CustodyPhoto(
    angle: angle,
    localPath: '/data/app/${angle.wireName}.jpg',
    takenAt: DateTime(2026, 8, 14, 10, 30),
    sizeBytes: 170 * 1024,
    sha256: 'sha_${angle.wireName}',
    point: const GeoPoint(-18.9010, 47.5490),
  );

  VectorSignature sig(String label) => VectorSignature(
    strokes: const [
      [SignaturePoint(5, 5, 0.5, 0), SignaturePoint(40, 20, 0.6, 180)],
    ],
    signedAt: DateTime(2026, 8, 14, 10, 31),
    signerLabel: label,
  );

  CustodyReport draft(CustodyStage stage, {String id = 'cst'}) => CustodyReport(
    id: '${id}_${stage.wireName}',
    deliveryId: 'dlv_77',
    stage: stage,
    photos: PhotoAngle.values.map(photo).toList(),
    grid: const ConditionGrid({ConditionCriterion.packagingIntact}),
    sealNumber: 'SC-4821',
    weight: WeightCategory.from2to5,
    signatures: [sig('expediteur'), sig('livreur')],
    capturedAt: DateTime(2026, 8, 14, 10, 32),
    point: const GeoPoint(-18.9010, 47.5490),
    sealCheck: stage == CustodyStage.handover ? SealCheck.intact : null,
    otpVerified: stage == CustodyStage.handover,
  );

  test('un constat non scelle ne peut pas etre transmis (EXI-CC04)', () async {
    await expectLater(
      repository.submit(draft(CustodyStage.pickup)),
      throwsA(isA<StateError>()),
    );
  });

  test('le serveur accepte un constat dont l empreinte concorde', () async {
    final sealed = draft(CustodyStage.pickup).seal();

    final accepted = await repository.submit(sealed);

    expect(accepted.hash, sealed.hash);
    // EXI-CC45 : l'horodatage serveur est celui qui fait foi.
    expect(accepted.serverTimestamp, isNotNull);
  });

  test('le serveur refuse une empreinte incoherente (EXI-B05)', () async {
    // On scelle, puis on modifie le contenu en gardant l'empreinte : c'est
    // exactement ce que produirait une falsification cote client.
    final sealed = draft(CustodyStage.pickup).seal();
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

    // La transmission echoue, mais le constat reste enregistre localement :
    // on ne perd jamais une preuve parce que le reseau l'a refusee.
    final result = await repository.submit(tampered);
    expect(result.serverTimestamp, isNull);
  });

  test('la remise chaine sur la prise en charge (EXI-CC44)', () async {
    final pickup = await repository.submit(draft(CustodyStage.pickup).seal());
    final handover = draft(
      CustodyStage.handover,
    ).seal(previousHash: pickup.hash);

    final accepted = await repository.submit(handover);

    expect(accepted.serverTimestamp, isNotNull);
    expect(accepted.previousHash, pickup.hash);
  });

  test('une remise sans prise en charge est refusee', () async {
    final orphan = draft(CustodyStage.handover).seal(previousHash: 'inconnu');

    final result = await repository.submit(orphan);
    expect(result.serverTimestamp, isNull, reason: 'le serveur doit refuser');
  });

  test('hors ligne, le constat est conserve et relisible (EXI-CC05)', () async {
    await build(profile: NetworkProfile.offline);

    final sealed = draft(CustodyStage.pickup).seal();
    final result = await repository.submit(sealed);

    // Non accuse par le serveur, mais bien present localement : c'est la
    // condition meme d'un parcours livreur executable en zone blanche.
    expect(result.serverTimestamp, isNull);

    final chain = await repository.chainFor('dlv_77');
    expect(chain.pickup, isNotNull);
    expect(chain.pickup!.sealNumber, 'SC-4821');
    expect(chain.pickup!.photos, hasLength(PhotoAngle.values.length));
  });

  test('les chemins de fichiers ne changent pas l empreinte', () async {
    // Ils sont ranges hors du corps canonique : un constat transmis depuis deux
    // telephones differents doit produire la meme empreinte.
    final sealed = draft(CustodyStage.pickup).seal();
    await repository.submit(sealed);

    final chain = await repository.chainFor('dlv_77');
    expect(chain.pickup!.photos.first.localPath, isNotEmpty);
    expect(chain.pickup!.hash, sealed.hash);
  });
}
