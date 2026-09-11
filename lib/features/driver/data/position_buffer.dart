import 'package:drift/drift.dart' hide Column;

import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';

/// Tampon de positions du livreur (EXI-L10, EXI-S03).
///
/// Les positions ne partent pas une par une. A quinze secondes d'intervalle sur
/// une journee de huit heures, cela ferait pres de deux mille requetes : autant
/// d'en-tetes, de poignees de main TLS et de reveils radio, pour une charge
/// utile de quelques octets chacune. Sur un forfait malgache (§4.4), le cout du
/// transport depasserait de loin celui de la donnee transportee.
///
/// Elles sont donc accumulees localement et envoyees par lots de cinquante —
/// plafond impose par le serveur, qui refuse au-dela (EXI-B06).
class PositionBuffer {
  PositionBuffer({required this.db, required this.queue, AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;

  final AppDatabase db;
  final SyncQueue queue;
  final AppLogger _logger;

  /// Taille du lot. Le serveur refuse au-dela (EXI-B06, EXI-S03).
  static const int batchSize = 50;

  /// Enregistre une position et declenche un envoi lorsque le lot est plein.
  Future<void> record(DriverPing ping, {String? deliveryId}) async {
    await db
        .into(db.bufferedPositions)
        .insert(
          BufferedPositionsCompanion.insert(
            deliveryId: Value(deliveryId),
            latitude: ping.point.latitude,
            longitude: ping.point.longitude,
            speedKmh: Value(ping.speedKmh),
            accuracyMeters: Value(ping.accuracyMeters),
            recordedAt: ping.at,
          ),
        );

    if (await pendingCount() >= batchSize) await flush();
  }

  Future<int> pendingCount() async {
    final query = db.selectOnly(db.bufferedPositions)
      ..addColumns([db.bufferedPositions.id.count()]);
    final row = await query.getSingle();
    return row.read(db.bufferedPositions.id.count()) ?? 0;
  }

  /// Depose les positions accumulees dans la file, par lots de cinquante.
  ///
  /// Les points sont retires du tampon **et** deposes en file dans la meme
  /// transaction : sans cela, une coupure entre les deux perdrait le lot, ou le
  /// dupliquerait. Le tampon ne conserve que ce qui n'a pas encore ete confie a
  /// la file ; a partir de la, c'est la file qui garantit l'acheminement.
  ///
  /// Retourne le nombre de lots deposes.
  Future<int> flush({int? maxBatches}) async {
    var batches = 0;

    while (maxBatches == null || batches < maxBatches) {
      final rows =
          await (db.select(db.bufferedPositions)
                ..orderBy([(t) => OrderingTerm(expression: t.recordedAt)])
                ..limit(batchSize))
              .get();

      if (rows.isEmpty) break;

      final points = rows.map(_toJson).toList();
      // La cle d'idempotence est derivee des bornes du lot : rejouer le meme
      // lot ne peut pas dupliquer la trace cote serveur (EXI-S01).
      final key =
          'ping_${rows.first.recordedAt.toUtc().toIso8601String()}_'
          '${rows.last.recordedAt.toUtc().toIso8601String()}_${rows.length}';

      await db.transaction(() async {
        await queue.enqueue(
          method: 'POST',
          path: ApiEndpoints.trackingBatch,
          idempotencyKey: key,
          body: {'points': points},
          priority: SyncPriority.position,
        );

        await (db.delete(
          db.bufferedPositions,
        )..where((t) => t.id.isIn(rows.map((r) => r.id).toList()))).go();
      });

      batches++;
      _logger.info('positions_batched', data: {'points': rows.length});

      if (rows.length < batchSize) break;
    }

    return batches;
  }

  /// Vide le tampon sans rien transmettre.
  ///
  /// Utilise a la deconnexion : les positions d'un livreur qui quitte son
  /// service ne doivent pas partir sous l'identite du suivant (EXI-SEC10).
  Future<void> discard() async => db.delete(db.bufferedPositions).go();

  Map<String, dynamic> _toJson(BufferedPosition row) => {
    'point': GeoPoint(row.latitude, row.longitude).toJson(),
    'at': row.recordedAt.toUtc().toIso8601String(),
    if (row.speedKmh != null) 'speedKmh': row.speedKmh,
    if (row.accuracyMeters != null) 'accuracy': row.accuracyMeters,
    if (row.deliveryId != null) 'deliveryId': row.deliveryId,
  };
}
