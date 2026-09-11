import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/driver/data/position_buffer.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';

/// Tampon de positions (EXI-L10, EXI-S03).
///
/// Ce que ces tests protegent, c'est le forfait du livreur : deux mille
/// requetes par journee de travail couteraient plus cher en transport qu'en
/// donnee transportee (§4.4).
void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late PositionBuffer buffer;

  final t0 = DateTime(2026, 8, 17, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db);
    buffer = PositionBuffer(db: db, queue: queue);
  });
  tearDown(() async => db.close());

  Future<void> record(int count, {String? deliveryId}) async {
    for (var i = 0; i < count; i++) {
      await buffer.record(
        DriverPing(
          point: GeoPoint(-18.90 + i * 0.0001, 47.54 + i * 0.0001),
          at: t0.add(Duration(seconds: 15 * i)),
          speedKmh: 22,
          accuracyMeters: 8,
        ),
        deliveryId: deliveryId,
      );
    }
  }

  test('les positions s accumulent sans partir une par une', () async {
    await record(10);

    expect(await buffer.pendingCount(), 10);
    // Rien en file : dix positions ne justifient pas dix requetes.
    expect(await queue.due(now: t0), isEmpty);
  });

  test('le cinquantieme point declenche un lot (EXI-S03)', () async {
    await record(PositionBuffer.batchSize);

    final items = await queue.due(now: t0);
    expect(items, hasLength(1));
    expect(await buffer.pendingCount(), 0);

    final points = items.single.body!['points'] as List<dynamic>;
    expect(points, hasLength(PositionBuffer.batchSize));
  });

  test('un lot ne depasse jamais cinquante points', () async {
    // Le serveur refuse au-dela (EXI-B06) : un lot de 51 serait rejete en bloc,
    // et la trace de la tournee y perdrait cinquante et un points d'un coup.
    await record(120);
    await buffer.flush();

    final items = await queue.due(now: t0, limit: 100);
    for (final item in items) {
      expect(
        (item.body!['points'] as List<dynamic>).length,
        lessThanOrEqualTo(PositionBuffer.batchSize),
      );
    }
    expect(await buffer.pendingCount(), 0);
  });

  test('les positions partent en derniere priorite (EXI-S02)', () async {
    await record(PositionBuffer.batchSize);

    final item = (await queue.due(now: t0)).single;
    expect(item.priority, SyncPriority.position);
    // Une position perdue est un point de trace ; un constat perdu est une
    // preuve. Le drapeau jamais-abandonner ne s'applique donc pas ici.
    expect(item.neverAbandon, isFalse);
  });

  test('les points gardent l horodatage de la mesure', () async {
    // Et non celui de l'envoi : c'est le moment ou le livreur etait la.
    await record(PositionBuffer.batchSize);

    final points =
        (await queue.due(now: t0)).single.body!['points'] as List<dynamic>;
    final first = points.first as Map<String, dynamic>;

    expect(first['at'], t0.toUtc().toIso8601String());
    expect(first['speedKmh'], 22);
    expect((first['point'] as Map<String, dynamic>)['lat'], closeTo(-18.90, 0.001));
  });

  test('la course est jointe au point quand il y en a une', () async {
    await record(PositionBuffer.batchSize, deliveryId: 'dlv_77');

    final points =
        (await queue.due(now: t0)).single.body!['points'] as List<dynamic>;
    expect((points.first as Map<String, dynamic>)['deliveryId'], 'dlv_77');
  });

  test('une vidange partielle envoie ce qui existe', () async {
    // Fin de tournee : le reliquat ne doit pas attendre le cinquantieme point
    // d'une journee qui ne viendra pas.
    await record(7);

    expect(await buffer.flush(), 1);
    expect(await buffer.pendingCount(), 0);
    expect(await queue.due(now: t0), hasLength(1));
  });

  test('une vidange a vide ne depose rien', () async {
    expect(await buffer.flush(), 0);
    expect(await queue.due(now: t0), isEmpty);
  });

  test('rejouer le meme lot ne le duplique pas (EXI-S01)', () async {
    // La cle est derivee des bornes du lot : un depot repete se replie sur la
    // ligne existante.
    await record(PositionBuffer.batchSize);
    final key = (await queue.due(now: t0)).single.idempotencyKey;

    await queue.enqueue(
      method: 'POST',
      path: '/tracking/batch',
      idempotencyKey: key,
      body: const {'points': []},
      priority: SyncPriority.position,
    );

    expect(await queue.due(now: t0), hasLength(1));
  });

  test('la deconnexion jette le tampon sans le transmettre', () async {
    // Les positions d'un livreur qui quitte son service ne doivent pas partir
    // sous l'identite du suivant (EXI-SEC10).
    await record(20);

    await buffer.discard();

    expect(await buffer.pendingCount(), 0);
    expect(await queue.due(now: t0), isEmpty);
  });
}
