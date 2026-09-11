import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Persistance et transmission des constats.
///
/// Deux exigences dictent l'ordre des operations :
///
///  - **EXI-CC05** : les deux constats sont integralement realisables hors
///    ligne. L'ecriture locale precede donc toujours l'envoi.
///  - **EXI-CC46** : un constat hors ligne n'est effacable qu'apres accuse de
///    reception du serveur. Le repository ne supprime jamais un constat non
///    accuse, meme si l'envoi echoue de facon repetee — c'est la contrepartie
///    d'EXI-S05, qui interdit l'abandon automatique.
class CustodyRepository {
  CustodyRepository({
    required this._client,
    required this._db,
    required this._vault,
    required this._queue,
  });

  final ApiClient _client;
  final AppDatabase _db;
  final CustodyVault _vault;
  final SyncQueue _queue;

  static const String _prefix = 'custody/';

  String _key(String reportId) => '$_prefix$reportId';

  /// Enregistre un constat scelle, puis tente de le transmettre.
  ///
  /// Retourne le constat tel qu'il doit etre affiche : confirme par le serveur
  /// si l'envoi a abouti, local et en attente sinon.
  Future<CustodyReport> submit(CustodyReport sealed) async {
    if (!sealed.isSealed) {
      throw StateError('Un constat doit etre scelle avant transmission');
    }

    await _persist(sealed, acknowledged: false);

    // Le chemin est calcule hors du `try` : il sert aussi bien a l'envoi qu'au
    // depot en file si celui-ci echoue.
    final path = sealed.stage == CustodyStage.pickup
        ? ApiEndpoints.custodyPickup(sealed.deliveryId)
        : ApiEndpoints.custodyHandover(sealed.deliveryId);

    try {
      final json = await _client.post<Map<String, dynamic>>(
        path,
        body: sealed.toJson(),
        // La cle d'idempotence est l'empreinte elle-meme : rejouer le meme
        // constat ne peut produire qu'un seul enregistrement, et deux constats
        // differents ne peuvent pas se confondre (EXI-S01).
        idempotencyKey: sealed.hash,
        category: DataCategory.photos,
      );

      // EXI-CC45 : l'horodatage retenu est celui du serveur a la reception.
      // L'horodatage local reste conserve a titre indicatif, et l'ecart est
      // journalise — deux telephones mal regles ne doivent pas raconter deux
      // histoires de la meme course.
      final serverTime = DateTime.tryParse('${json['serverTimestamp']}');
      if (serverTime != null) {
        final drift = serverTime.difference(sealed.capturedAt).inSeconds;
        if (drift.abs() > 120) {
          AppLogger.instance.warn(
            'custody_clock_drift',
            data: {'seconds': drift},
          );
        }
      }

      final acknowledged = _withServerTime(sealed, serverTime);
      await _persist(acknowledged, acknowledged: true);
      await _purgePhotos(acknowledged);
      return acknowledged;
    } on Failure catch (failure) {
      AppLogger.instance.info(
        'custody_queued',
        data: {'reason': failure.runtimeType.toString()},
      );

      // Priorite la plus haute (EXI-S02) et drapeau « jamais abandonner »
      // (EXI-S05), pose par la priorite elle-meme. La cle d'idempotence est
      // l'empreinte : elle est recalculable, si bien qu'un constat depose deux
      // fois ne produira jamais qu'une ligne dans la file et qu'un
      // enregistrement cote serveur.
      await _queue.enqueue(
        method: 'POST',
        path: path,
        idempotencyKey: sealed.hash!,
        body: sealed.toJson(),
        priority: SyncPriority.custody,
      );

      return sealed;
    }
  }

  Future<void> _persist(
    CustodyReport report, {
    required bool acknowledged,
  }) async {
    // EXI-CC46 : le constat est chiffre sur disque tant qu'il n'est pas accuse.
    // Il contient des photos, des positions, des numeros et deux signatures ;
    // sur le telephone personnel d'un livreur, le laisser en clair reviendrait
    // a publier la preuve avant qu'elle ne soit protegee.
    final envelope = await _vault.encryptJson({
      'report': report.toJson(),
      // Les chemins de fichiers sont ranges **a cote** du constat, jamais
      // dedans : ils sont propres a l'appareil, et les inclure dans le
      // corps canonique changerait l'empreinte d'un telephone a l'autre.
      // Le serveur recalcule cette empreinte (EXI-B05) ; elle doit donc
      // ne dependre que du contenu, pas de l'endroit ou il est range.
      // La cle est l'empreinte de la photo, pas son angle : une remise
      // peut porter deux photos du meme angle (scelle rompu, piece
      // d'identite d'un tiers), et indexer par angle en perdrait une.
      'paths': {
        for (final photo in report.photos) photo.sha256: photo.localPath,
      },
      'acknowledged': acknowledged,
    });

    await _db
        .into(_db.cachedDocuments)
        .insertOnConflictUpdate(
          CachedDocumentsCompanion.insert(
            key: _key(report.id),
            body: envelope,
            fetchedAt: DateTime.now(),
          ),
        );
  }

  /// Efface les photos une fois le constat accuse par le serveur (EXI-S07).
  ///
  /// L'ordre compte : la purge n'intervient **qu'apres** l'accuse de reception.
  /// Effacer avant reviendrait a detruire la seule copie d'une preuve sur la foi
  /// d'un envoi qui peut encore echouer. Un telephone d'entree de gamme dispose
  /// de quelques gigaoctets ; garder indefiniment quatre a six photos par course
  /// finirait par saturer le stockage et faire echouer la course suivante — mais
  /// c'est la deuxieme preoccupation, pas la premiere.
  ///
  /// Les metadonnees, elles, restent : empreinte, horodatage, position, taille.
  /// Ce qui permet de verifier a posteriori qu'une image produite par le serveur
  /// est bien celle qui a ete scellee.
  Future<void> _purgePhotos(CustodyReport report) async {
    var freed = 0;

    for (final photo in report.photos) {
      if (photo.localPath.isEmpty) continue;
      final file = File(photo.localPath);
      if (!file.existsSync()) continue;

      try {
        await file.delete();
        freed += photo.sizeBytes;
      } on FileSystemException catch (error) {
        // Un fichier verrouille n'est pas un echec de transmission : le constat
        // est accuse, la place se liberera au prochain passage.
        AppLogger.instance.warn(
          'custody_purge_failed',
          data: {'reason': error.osError?.message ?? 'io'},
        );
      }
    }

    if (freed > 0) {
      AppLogger.instance.info('custody_photos_purged', data: {'bytes': freed});
    }
  }

  /// Repose le constat avec l'horodatage serveur, **sans rien perdre**.
  ///
  /// Toute champ omis ici disparait de la copie conservee localement, et
  /// l'empreinte recalculee a la relecture ne correspond plus a celle qui a ete
  /// scellee : la chaine se declare rompue alors que rien n'a ete falsifie.
  /// C'est exactement ce qui est arrive quand les issues de remise (EXI-CC26 a
  /// CC29) ont ete ajoutees sans toucher a cette methode.
  CustodyReport _withServerTime(CustodyReport report, DateTime? serverTime) =>
      CustodyReport(
        id: report.id,
        deliveryId: report.deliveryId,
        stage: report.stage,
        photos: report.photos,
        grid: report.grid,
        sealNumber: report.sealNumber,
        weight: report.weight,
        signatures: report.signatures,
        capturedAt: report.capturedAt,
        point: report.point,
        sealCheck: report.sealCheck,
        outcome: report.outcome,
        thirdPartyName: report.thirdPartyName,
        thirdPartyRelation: report.thirdPartyRelation,
        reserveReason: report.reserveReason,
        otpVerified: report.otpVerified,
        previousHash: report.previousHash,
        hash: report.hash,
        serverTimestamp: serverTime?.toLocal(),
        sealedAt: report.sealedAt,
      );

  /// Constats connus d'une course, lus localement (EXI-CC05).
  Future<CustodyChain> chainFor(String deliveryId) async {
    final rows = await (_db.select(
      _db.cachedDocuments,
    )..where((t) => t.key.like('$_prefix%'))).get();

    CustodyReport? pickup;
    CustodyReport? handover;

    for (final row in rows) {
      // Les enveloppes anterieures au chiffrement restent lisibles : une
      // migration qui detruirait des preuves serait pire que le defaut qu'elle
      // corrige.
      final decoded = CustodyVault.isEnvelope(row.body)
          ? await _vault.decryptJson(row.body)
          : jsonDecode(row.body) as Map<String, dynamic>;
      if (decoded == null) continue;

      final json = decoded['report'] as Map<String, dynamic>;
      if (json['deliveryId'] != deliveryId) continue;

      final paths = (decoded['paths'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, '$value'),
      );
      final report = _fromJson(json, paths);

      if (report.stage == CustodyStage.pickup) {
        pickup = report;
      } else {
        handover = report;
      }
    }

    return CustodyChain(pickup: pickup, handover: handover);
  }

  CustodyReport _fromJson(
    Map<String, dynamic> json,
    Map<String, String> paths,
  ) {
    final photos = (json['photos'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((p) {
          final angle = PhotoAngle.fromWire(p['angle'] as String?);
          if (angle == null) return null;
          final digest = '${p['sha256'] ?? ''}';
          return CustodyPhoto(
            angle: angle,
            // Les enregistrements anterieurs indexaient par angle : on les relit
            // plutot que de les perdre.
            localPath: paths[digest] ?? paths[angle.wireName] ?? '',
            takenAt:
                DateTime.tryParse('${p['takenAt']}')?.toLocal() ??
                DateTime.now(),
            sizeBytes: (p['sizeBytes'] as num?)?.toInt() ?? 0,
            sha256: digest,
            point: GeoPoint.fromJson(p['point'] as Map<String, dynamic>?),
            anomalyNote: p['anomalyNote'] as String?,
          );
        })
        .whereType<CustodyPhoto>()
        .toList();

    return CustodyReport(
      id: '${json['id']}',
      deliveryId: '${json['deliveryId']}',
      stage: CustodyStage.fromWire(json['stage'] as String?),
      photos: photos,
      grid: ConditionGrid.fromJson(json['grid'] as List<dynamic>?),
      sealNumber: '${json['sealNumber'] ?? ''}',
      weight: WeightCategory.fromWire(json['weight'] as String?),
      // Les signatures sont rechargees : le comparateur ne les affiche pas,
      // mais l'export PDF (EXI-CC32) en a besoin, et un constat exporte sans
      // les traces qui l'engagent ne vaudrait pas grand-chose.
      signatures: (json['signatures'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_signatureFromJson)
          .toList(),
      capturedAt:
          DateTime.tryParse('${json['capturedAt']}')?.toLocal() ??
          DateTime.now(),
      point:
          GeoPoint.fromJson(json['point'] as Map<String, dynamic>?) ??
          GeoPoint.antananarivo,
      sealCheck: SealCheck.fromWire(json['sealCheck'] as String?),
      outcome: HandoverOutcome.fromWire(json['outcome'] as String?),
      thirdPartyName: json['thirdPartyName'] as String?,
      thirdPartyRelation: json['thirdPartyRelation'] as String?,
      reserveReason: json['reserveReason'] as String?,
      otpVerified: json['otpVerified'] == true,
      previousHash: json['previousHash'] as String?,
      hash: json['hash'] as String?,
      sealedAt: DateTime.tryParse('${json['sealedAt']}')?.toLocal(),
    );
  }

  VectorSignature _signatureFromJson(Map<String, dynamic> json) =>
      VectorSignature(
        signerLabel: '${json['signerLabel'] ?? ''}',
        signedAt:
            DateTime.tryParse('${json['signedAt']}')?.toLocal() ??
            DateTime.now(),
        strokes: (json['strokes'] as List<dynamic>? ?? [])
            .whereType<List<dynamic>>()
            .map(
              (stroke) => stroke
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (p) => SignaturePoint(
                      (p['x'] as num?)?.toDouble() ?? 0,
                      (p['y'] as num?)?.toDouble() ?? 0,
                      (p['p'] as num?)?.toDouble() ?? 0,
                      (p['t'] as num?)?.toInt() ?? 0,
                    ),
                  )
                  .toList(),
            )
            .toList(),
      );
}
