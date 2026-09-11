import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';

/// Persistance de la file de synchronisation (§10.2).
///
/// La file est une **table**, pas une liste en memoire. Un livreur qui tue
/// l'application dans un tunnel doit retrouver ses constats en attente au
/// redemarrage : c'est la seule lecture compatible avec EXI-S05, qui interdit
/// d'abandonner une preuve.
class SyncQueue {
  SyncQueue(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Depose un element, ou le retrouve s'il y est deja.
  ///
  /// Le dedoublonnage se fait sur la cle d'idempotence : deposer deux fois le
  /// meme constat — parce que l'ecran a ete rejoue, parce que l'utilisateur a
  /// reappuye — ne doit produire qu'une seule ligne. Sans cela, la file
  /// grossirait de doublons que le serveur rejetterait un a un, en consommant
  /// le forfait a chaque passage.
  Future<SyncItem> enqueue({
    required String method,
    required String path,
    required String idempotencyKey,
    Map<String, dynamic>? body,
    SyncPriority priority = SyncPriority.transition,

    DateTime? now,
  }) async {
    final existing = await byIdempotencyKey(idempotencyKey);
    if (existing != null) return existing;

    final item = SyncItem(
      id: _uuid.v4(),
      idempotencyKey: idempotencyKey,
      method: method,
      path: path,
      payload: body == null ? '' : jsonEncode(body),
      priority: priority,
      status: SyncItemStatus.pending,
      attempts: 0,
      createdAt: now ?? DateTime.now(),
      neverAbandon: priority.neverAbandon,
    );

    await _db.into(_db.syncQueueItems).insert(_toCompanion(item));
    return item;
  }

  /// Elements exigibles maintenant, dans l'ordre impose par EXI-S02.
  ///
  /// Priorite d'abord, anciennete ensuite : a priorite egale, le plus vieux
  /// part le premier, sans quoi un element malchanceux resterait indefiniment
  /// derriere les nouveaux arrivants.
  Future<List<SyncItem>> due({DateTime? now, int limit = 20}) async {
    final at = now ?? DateTime.now();

    final query = _db.select(_db.syncQueueItems)
      ..where(
        (t) => t.status.isNotIn([
          SyncItemStatus.abandoned.wireName,
          SyncItemStatus.inFlight.wireName,
        ]),
      )
      ..where(
        (t) =>
            t.nextAttemptAt.isNull() |
            t.nextAttemptAt.isSmallerOrEqualValue(at),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority),
        (t) => OrderingTerm(expression: t.createdAt),
      ])
      ..limit(limit);

    return (await query.get()).map(_toItem).toList();
  }

  /// Tous les elements encore en attente, du plus urgent au plus ancien.
  Stream<List<SyncItem>> watchOutstanding() {
    final query = _db.select(_db.syncQueueItems)
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toItem).toList());
  }

  Future<SyncItem?> byIdempotencyKey(String key) async {
    final row =
        await (_db.select(_db.syncQueueItems)
              ..where((t) => t.idempotencyKey.equals(key))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toItem(row);
  }

  /// Marque un element comme parti, pour qu'un second passage de
  /// l'ordonnanceur ne le rejoue pas en parallele.
  Future<void> markInFlight(String id) async {
    await (_db.update(_db.syncQueueItems)..where((t) => t.id.equals(id))).write(
      SyncQueueItemsCompanion(status: Value(SyncItemStatus.inFlight.wireName)),
    );
  }

  /// Le serveur a accuse reception : l'element quitte la file.
  Future<void> remove(String id) async {
    await (_db.delete(_db.syncQueueItems)..where((t) => t.id.equals(id))).go();
  }

  /// Une tentative a echoue : compteur, cause et date de reprise.
  Future<void> markFailure(
    SyncItem item, {
    required SyncFailureCause cause,
    required bool retryable,
    Duration? retryIn,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final attempts = item.attempts + 1;

    final exhausted = SyncBackoff.isExhausted(
      attempts: attempts,
      neverAbandon: item.neverAbandon,
    );

    // Un refus definitif du serveur — conflit, validation — ne se rejoue pas :
    // le rejouer a l'identique produirait le meme refus, en consommant du
    // forfait a chaque passage. Sauf pour une preuve, qui reste dans la file
    // jusqu'a ce qu'un humain tranche (EXI-S05).
    final stop = (!retryable || exhausted) && !item.neverAbandon;

    await (_db.update(
      _db.syncQueueItems,
    )..where((t) => t.id.equals(item.id))).write(
      SyncQueueItemsCompanion(
        attempts: Value(attempts),
        status: Value(
          stop
              ? SyncItemStatus.abandoned.wireName
              : SyncItemStatus.failed.wireName,
        ),
        lastError: Value(
          exhausted && retryable
              ? SyncFailureCause.exhausted.wireName
              : cause.wireName,
        ),
        nextAttemptAt: Value(stop ? null : at.add(retryIn ?? Duration.zero)),
      ),
    );
  }

  /// Relance manuelle demandee par l'utilisateur (EXI-S06).
  ///
  /// Elle remet le compteur a zero : l'utilisateur qui appuie sait quelque
  /// chose que la machine ignore — il a retrouve du reseau, ou il a corrige la
  /// cause. Lui reservir immediatement « tentatives epuisees » serait lui
  /// opposer un mur.
  Future<void> retryNow(String id) async {
    await (_db.update(_db.syncQueueItems)..where((t) => t.id.equals(id))).write(
      SyncQueueItemsCompanion(
        status: Value(SyncItemStatus.pending.wireName),
        attempts: Value(0),
        nextAttemptAt: Value(null),
        lastError: Value(null),
      ),
    );
  }

  Future<void> retryAll() async {
    await _db
        .update(_db.syncQueueItems)
        .write(
          SyncQueueItemsCompanion(
            status: Value(SyncItemStatus.pending.wireName),
            attempts: Value(0),
            nextAttemptAt: Value(null),
            lastError: Value(null),
          ),
        );
  }

  /// Remet en attente les elements restes « en vol » a l'arret de
  /// l'application.
  ///
  /// Un envoi interrompu par une fermeture brutale laisserait sinon une ligne
  /// bloquee pour toujours. La cle d'idempotence garantit qu'un rejeu ne cree
  /// pas de doublon cote serveur (EXI-S01) : reprendre est sans danger, ne pas
  /// reprendre perdrait l'element.
  Future<void> recoverInFlight() async {
    await (_db.update(
      _db.syncQueueItems,
    )..where((t) => t.status.equals(SyncItemStatus.inFlight.wireName))).write(
      SyncQueueItemsCompanion(
        status: Value(SyncItemStatus.pending.wireName),
        nextAttemptAt: Value(null),
      ),
    );
  }

  SyncQueueItemsCompanion _toCompanion(SyncItem item) =>
      SyncQueueItemsCompanion.insert(
        id: item.id,
        idempotencyKey: item.idempotencyKey,
        method: item.method,
        path: item.path,
        payload: item.payload,
        priority: Value(item.priority.rank),
        status: Value(item.status.wireName),
        attempts: Value(item.attempts),
        createdAt: item.createdAt,
        nextAttemptAt: Value(item.nextAttemptAt),
        neverAbandon: Value(item.neverAbandon),
        lastError: Value(item.lastError),
      );

  SyncItem _toItem(SyncQueueItem row) => SyncItem(
    id: row.id,
    idempotencyKey: row.idempotencyKey,
    method: row.method,
    path: row.path,
    payload: row.payload,
    priority: SyncPriority.fromRank(row.priority),
    status: SyncItemStatus.fromWire(row.status),
    attempts: row.attempts,
    createdAt: row.createdAt,
    nextAttemptAt: row.nextAttemptAt,
    lastError: row.lastError,
    neverAbandon: row.neverAbandon,
  );
}
