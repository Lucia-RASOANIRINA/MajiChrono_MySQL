import 'dart:async';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/network_status.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';

/// Resultat d'un passage de l'ordonnanceur, utile aux tests et au journal.
class SyncRun {
  const SyncRun({
    required this.sent,
    required this.failed,
    required this.abandoned,
    required this.conflicts,
  });

  final int sent;
  final int failed;
  final int abandoned;

  /// Elements pour lesquels le serveur a impose son etat (EXI-S04).
  final List<SyncItem> conflicts;

  static const SyncRun empty = SyncRun(
    sent: 0,
    failed: 0,
    abandoned: 0,
    conflicts: [],
  );

  bool get didSomething => sent + failed + abandoned > 0;
}

/// Vidange de la file (§10.2).
///
/// L'ordonnanceur ne decide de rien : il applique l'ordre de priorite
/// (EXI-S02), la reprise exponentielle (§10.2) et la regle du jamais-abandonner
/// (EXI-S05). Tout ce qu'il ajoute, c'est le moment — il se declenche au retour
/// du reseau plutot qu'a intervalle fixe, parce qu'un reveil toutes les
/// trente secondes en zone blanche viderait la batterie sans rien transmettre.
class SyncScheduler {
  SyncScheduler({
    required this._queue,
    required this._client,
    required this._networkStatus,
    this._backoff = const SyncBackoff(),
    this._heartbeat = const Duration(minutes: 2),
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final SyncQueue _queue;
  final ApiClient _client;
  final Stream<NetworkStatus> _networkStatus;
  final SyncBackoff _backoff;
  final AppLogger _logger;
  final Duration _heartbeat;

  StreamSubscription<NetworkStatus>? _subscription;
  Timer? _timer;
  bool _draining = false;
  bool _online = false;

  final StreamController<SyncRun> _runs = StreamController<SyncRun>.broadcast();

  /// Comptes rendus de passage, consommes par l'interface pour signaler un
  /// conflit a l'utilisateur (EXI-S04).
  Stream<SyncRun> get runs => _runs.stream;

  Future<void> start() async {
    // Les elements restes « en vol » a la fermeture precedente repartent : la
    // cle d'idempotence rend le rejeu sans danger (EXI-S01).
    await _queue.recoverInFlight();

    _subscription = _networkStatus.listen((status) {
      final wasOffline = !_online;
      _online = status.isOnline;
      // Le retour du reseau est le signal utile. Le declenchement au
      // changement, plutot qu'a la minute, est ce qui rend la file quasiment
      // gratuite en zone blanche.
      if (_online && wasOffline) unawaited(drain());
    });

    // Un battement lent couvre le cas ou le reseau n'a jamais varie mais ou un
    // element est arrive entre-temps, ou dont le delai de reprise vient
    // d'echoir.
    _timer = Timer.periodic(_heartbeat, (_) {
      if (_online) unawaited(drain());
    });

    unawaited(drain());
  }

  /// Vide la file, dans l'ordre, jusqu'a ce qu'il n'y ait plus rien d'exigible.
  ///
  /// Un seul passage a la fois : deux vidanges concurrentes enverraient deux
  /// fois le meme element. Le serveur les dedoublonnerait grace a la cle
  /// d'idempotence, mais le forfait du livreur, lui, serait bien debite deux
  /// fois (§4.4).
  Future<SyncRun> drain({DateTime? now}) async {
    if (_draining) return SyncRun.empty;
    _draining = true;

    var sent = 0;
    var failed = 0;
    var abandoned = 0;
    final conflicts = <SyncItem>[];

    try {
      final items = await _queue.due(now: now);
      for (final item in items) {
        final outcome = await _send(item, now: now);
        switch (outcome) {
          case _Outcome.sent:
            sent++;
          case _Outcome.failed:
            failed++;
          case _Outcome.abandoned:
            abandoned++;
          case _Outcome.conflict:
            abandoned++;
            conflicts.add(item);
          case _Outcome.offline:
            // Inutile d'essayer les suivants : le reseau est tombe pendant la
            // vidange. On rend la main, le prochain retour rallumera tout.
            failed++;
            final run = SyncRun(
              sent: sent,
              failed: failed,
              abandoned: abandoned,
              conflicts: conflicts,
            );
            _runs.add(run);
            return run;
        }
      }
    } finally {
      _draining = false;
    }

    final run = SyncRun(
      sent: sent,
      failed: failed,
      abandoned: abandoned,
      conflicts: conflicts,
    );
    if (run.didSomething) {
      _logger.info(
        'sync_drain',
        data: {'sent': sent, 'failed': failed, 'abandoned': abandoned},
      );
      _runs.add(run);
    }
    return run;
  }

  Future<_Outcome> _send(SyncItem item, {DateTime? now}) async {
    await _queue.markInFlight(item.id);

    try {
      await _client.post<Object?>(
        item.path,
        body: item.body,
        // La cle est celle posee a la mise en file, jamais une nouvelle : c'est
        // toute la difference entre une reprise et un doublon (EXI-S01).
        idempotencyKey: item.idempotencyKey,
        category: _categoryFor(item.priority),
      );

      await _queue.remove(item.id);
      return _Outcome.sent;
    } on Failure catch (failure) {
      final cause = _causeOf(failure);

      await _queue.markFailure(
        item,
        cause: cause,
        retryable: failure.isRetryable,
        retryIn: _backoff.delayFor(item.attempts + 1),
        now: now,
      );

      if (failure is ConflictFailure) {
        // EXI-S04 : le serveur fait foi. On ne rejoue pas, on informe.
        _logger.warn(
          'sync_conflict',
          data: {'path': item.path, 'state': failure.currentState},
        );
        return _Outcome.conflict;
      }

      if (failure is NetworkFailure || failure is TimeoutFailure) {
        return _Outcome.offline;
      }

      final stopped =
          !failure.isRetryable ||
          SyncBackoff.isExhausted(
            attempts: item.attempts + 1,
            neverAbandon: item.neverAbandon,
          );
      return stopped && !item.neverAbandon
          ? _Outcome.abandoned
          : _Outcome.failed;
    }
  }

  /// Le compteur de donnees doit imputer chaque octet a la bonne rubrique
  /// (EXI-T07) : un livreur qui voit « 12 Mo » veut savoir si ce sont ses
  /// photos ou ses positions.
  DataCategory _categoryFor(SyncPriority priority) => switch (priority) {
    SyncPriority.custody => DataCategory.photos,
    SyncPriority.position => DataCategory.tracking,
    _ => DataCategory.api,
  };

  SyncFailureCause _causeOf(Failure failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() => SyncFailureCause.network,
    ConflictFailure() => SyncFailureCause.conflict,
    ValidationFailure() ||
    UnauthorizedFailure() ||
    UpdateRequiredFailure() => SyncFailureCause.rejected,
    _ => SyncFailureCause.server,
  };

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    await _runs.close();
  }
}

enum _Outcome { sent, failed, abandoned, conflict, offline }
