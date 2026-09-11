import 'dart:io';
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
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/custody/data/custody_repository.dart';
import 'package:majichrono/features/custody/data/mock/custody_mock_module.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

import '../../helpers/fake_secure_store.dart';

/// Constat hors ligne : depot en file (EXI-S02, EXI-S05) et purge des photos
/// une fois l'accuse recu (EXI-S07).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustodyRepository repository;
  late AppDatabase db;
  late SyncQueue queue;
  late Directory photos;

  Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(CustodyMockModule());

    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db);
    photos = await Directory.systemTemp.createTemp('majichrono_photos');

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
      queue: queue,
    );
  }

  setUp(build);
  tearDown(() async {
    await db.close();
    if (photos.existsSync()) await photos.delete(recursive: true);
  });

  Future<CustodyPhoto> photo(PhotoAngle angle) async {
    final file = File('${photos.path}/${angle.wireName}.jpg');
    await file.writeAsBytes(List.filled(1024, 7));
    return CustodyPhoto(
      angle: angle,
      localPath: file.path,
      takenAt: DateTime(2026, 8, 14, 10, 30),
      sizeBytes: 1024,
      sha256: 'sha_${angle.wireName}',
      point: const GeoPoint(-18.9010, 47.5490),
    );
  }

  VectorSignature sig(String label) => VectorSignature(
    strokes: const [
      [SignaturePoint(5, 5, 0.5, 0), SignaturePoint(40, 20, 0.6, 180)],
    ],
    signedAt: DateTime(2026, 8, 14, 10, 31),
    signerLabel: label,
  );

  Future<CustodyReport> draft(CustodyStage stage) async => CustodyReport(
    id: 'cst_${stage.wireName}',
    deliveryId: 'dlv_77',
    stage: stage,
    photos: [for (final a in PhotoAngle.values) await photo(a)],
    grid: const ConditionGrid({ConditionCriterion.packagingIntact}),
    sealNumber: 'SC-4821',
    weight: WeightCategory.from2to5,
    signatures: [sig('expediteur'), sig('livreur')],
    capturedAt: DateTime(2026, 8, 14, 10, 32),
    point: const GeoPoint(-18.9010, 47.5490),
    sealCheck: stage == CustodyStage.handover ? SealCheck.intact : null,
    outcome: stage == CustodyStage.handover ? HandoverOutcome.delivered : null,
    otpVerified: stage == CustodyStage.handover,
  );

  group('depot en file (EXI-S02, EXI-S05)', () {
    test('hors ligne, le constat rejoint la file en priorite haute', () async {
      await build(profile: NetworkProfile.offline);
      final sealed = (await draft(CustodyStage.pickup)).seal();

      await repository.submit(sealed);

      final items = await queue.due();
      expect(items, hasLength(1));
      expect(items.single.priority, SyncPriority.custody);
      // EXI-S05 : le drapeau est pose des le depot, pas apres coup.
      expect(items.single.neverAbandon, isTrue);
    });

    test('la cle deposee est l empreinte du constat (EXI-S01)', () async {
      // Elle est recalculable a partir du contenu : deux depots du meme constat
      // ne peuvent produire qu'une ligne, et deux constats differents ne
      // peuvent pas se confondre.
      await build(profile: NetworkProfile.offline);
      final sealed = (await draft(CustodyStage.pickup)).seal();

      await repository.submit(sealed);
      await repository.submit(sealed);

      expect(await queue.due(), hasLength(1));
      expect((await queue.due()).single.idempotencyKey, sealed.hash);
    });

    test('en ligne, rien n est depose', () async {
      final sealed = (await draft(CustodyStage.pickup)).seal();

      final accepted = await repository.submit(sealed);

      expect(accepted.serverTimestamp, isNotNull);
      expect(await queue.due(), isEmpty);
    });
  });

  group('purge des photos (EXI-S07)', () {
    test('les photos sont effacees une fois le constat accuse', () async {
      final sealed = (await draft(CustodyStage.pickup)).seal();
      for (final p in sealed.photos) {
        expect(File(p.localPath).existsSync(), isTrue);
      }

      await repository.submit(sealed);

      for (final p in sealed.photos) {
        expect(
          File(p.localPath).existsSync(),
          isFalse,
          reason: 'la photo doit etre liberee apres accuse',
        );
      }
    });

    test('les metadonnees survivent a la purge', () async {
      // Empreinte, horodatage, position et taille restent : c'est ce qui permet
      // de verifier qu'une image servie par le serveur est bien celle qui a ete
      // scellee.
      final sealed = (await draft(CustodyStage.pickup)).seal();
      await repository.submit(sealed);

      final chain = await repository.chainFor('dlv_77');
      expect(chain.pickup, isNotNull);
      expect(chain.pickup!.photos, hasLength(PhotoAngle.values.length));
      expect(chain.pickup!.photos.first.sha256, isNotEmpty);
      expect(chain.pickup!.hash, sealed.hash);
    });

    test('hors ligne, les photos sont conservees', () async {
      // Effacer avant l'accuse reviendrait a detruire la seule copie d'une
      // preuve sur la foi d'un envoi qui peut encore echouer.
      await build(profile: NetworkProfile.offline);
      final sealed = (await draft(CustodyStage.pickup)).seal();

      await repository.submit(sealed);

      for (final p in sealed.photos) {
        expect(File(p.localPath).existsSync(), isTrue);
      }
    });

    test('un constat accuse reste verifiable a la relecture', () async {
      // Regression : `_withServerTime` reconstruisait le constat champ par
      // champ et **perdait** l'issue de remise. L'empreinte recalculee a la
      // relecture ne correspondait plus a celle qui avait ete scellee, et la
      // chaine se declarait rompue alors que rien n'avait ete falsifie.
      final pickup = await repository.submit(
        (await draft(CustodyStage.pickup)).seal(),
      );
      final handover = await repository.submit(
        (await draft(CustodyStage.handover)).seal(previousHash: pickup.hash),
      );

      expect(handover.outcome, HandoverOutcome.delivered);

      final chain = await repository.chainFor('dlv_77');
      expect(chain.handover!.outcome, HandoverOutcome.delivered);
      expect(chain.handover!.verifyIntegrity(), isTrue);
      expect(chain.isIntact, isTrue);
    });

    test('un constat refuse par le serveur garde ses photos', () async {
      // Le serveur recalcule l'empreinte et refuse ce constat falsifie
      // (EXI-B05) : sans accuse, pas de purge.
      final sealed = (await draft(CustodyStage.pickup)).seal();
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

      await repository.submit(tampered);

      for (final p in sealed.photos) {
        expect(File(p.localPath).existsSync(), isTrue);
      }
    });
  });
}
