import 'dart:async';
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
import 'package:majichrono/core/network/network_status.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/core/sync/sync_scheduler.dart';

/// Vidange de la file : ce qui part, ce qui reste, et ce que le serveur impose.
///
/// L'ordonnanceur traverse la vraie pile reseau — intercepteurs, cle
/// d'idempotence, compteur de donnees. Seul l'octet sur le fil est simule.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncQueue queue;
  late MockBackend backend;
  late SyncScheduler scheduler;
  late StreamController<NetworkStatus> network;

  /// Cles d'idempotence effectivement recues par le serveur.
  late List<String?> seenKeys;

  final t0 = DateTime(2026, 8, 17, 8);

  Future<void> build({
    NetworkProfile profile = NetworkProfile.fourG,
    void Function(MockBackend backend)? routes,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    seenKeys = [];
    backend = MockBackend()..register(CoreMockModule());
    backend.post('/ok', (req, _) async {
      seenKeys.add(req.idempotencyKey);
      return MockResponse.created({'ok': true});
    });
    backend.post('/conflit', (req, _) async => MockResponse.error(
      409,
      'conflict',
      'Deja livree',
      details: {'currentState': 'livree'},
    ));
    backend.post(
      '/refus',
      (req, _) async => MockResponse.error(422, 'invalid', 'Champ manquant'),
    );
    backend.post(
      '/panne',
      (req, _) async => MockResponse.error(500, 'server_error', 'Boom'),
    );
    routes?.call(backend);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db);
    network = StreamController<NetworkStatus>.broadcast();

    scheduler = SyncScheduler(
      queue: queue,
      client: ApiClient(
        config: AppConfig.fromEnvironment(),
        dataMeter: DataMeter(prefs),
        mockBackend: backend,
        mockAdapter: MockHttpAdapter(
          backend: backend,
          profile: profile,
          random: Random(7),
        ),
      ),
      networkStatus: network.stream,
      backoff: SyncBackoff(random: Random(3)),
    );
  }

  setUp(build);
  tearDown(() async {
    await scheduler.dispose();
    await network.close();
    await db.close();
  });

  Future<SyncItem> put(
    String path, {
    required String key,
    SyncPriority priority = SyncPriority.transition,
  }) => queue.enqueue(
    method: 'POST',
    path: path,
    idempotencyKey: key,
    body: {'k': key},
    priority: priority,
    now: t0,
  );

  test('un element accepte quitte la file', () async {
    await put('/ok', key: 'a');

    final run = await scheduler.drain(now: t0);

    expect(run.sent, 1);
    expect(await queue.byIdempotencyKey('a'), isNull);
  });

  test('la cle d idempotence posee en file est celle qui part (EXI-S01)', () async {
    // C'est toute la difference entre une reprise et un doublon : un envoi
    // coupe avant la reponse, rejoue sous une nouvelle cle, creerait deux
    // courses ou deux constats.
    await put('/ok', key: 'cle-stable');

    await scheduler.drain(now: t0);

    expect(seenKeys, ['cle-stable']);
  });

  test('la file part dans l ordre des priorites (EXI-S02)', () async {
    await put('/ok', key: 'note', priority: SyncPriority.rating);
    await put('/ok', key: 'constat', priority: SyncPriority.custody);
    await put('/ok', key: 'statut', priority: SyncPriority.transition);

    await scheduler.drain(now: t0);

    expect(seenKeys, ['constat', 'statut', 'note']);
  });

  test('hors ligne, rien ne part et rien ne se perd', () async {
    await build(profile: NetworkProfile.offline);
    await put('/ok', key: 'a');
    await put('/ok', key: 'b', priority: SyncPriority.custody);

    final run = await scheduler.drain(now: t0);

    expect(run.sent, 0);
    expect(seenKeys, isEmpty);

    // Les deux elements sont toujours la. Le constat est celui qui a ete
    // essaye — il passe avant tout le reste (EXI-S02) — et sa tentative est
    // comptee avec la bonne cause.
    final custody = await queue.byIdempotencyKey('b');
    expect(custody, isNotNull);
    expect(custody!.attempts, 1);
    expect(custody.cause, SyncFailureCause.network);

    expect(await queue.byIdempotencyKey('a'), isNotNull);
  });

  test('une coupure interrompt la vidange au lieu de la poursuivre', () async {
    // Insister element par element sur un reseau tombe ne ferait qu'ajouter
    // des tentatives inutiles au compteur de chacun.
    await build(profile: NetworkProfile.offline);
    for (final key in ['a', 'b', 'c']) {
      await put('/ok', key: key);
    }

    await scheduler.drain(now: t0);

    final attempts = <int>[];
    for (final key in ['a', 'b', 'c']) {
      attempts.add((await queue.byIdempotencyKey(key))!.attempts);
    }
    expect(attempts, [1, 0, 0]);
  });

  test('un conflit impose l etat du serveur et n est pas rejoue (EXI-S04)', () async {
    await put('/conflit', key: 'c');

    final run = await scheduler.drain(now: t0);

    expect(run.conflicts, hasLength(1));
    expect(run.conflicts.single.idempotencyKey, 'c');

    final stored = await queue.byIdempotencyKey('c');
    expect(stored!.status, SyncItemStatus.abandoned);
    expect(stored.cause, SyncFailureCause.conflict);

    // Un second passage ne le retente pas : le serveur fait foi.
    await scheduler.drain(now: t0.add(const Duration(days: 1)));
    expect((await queue.byIdempotencyKey('c'))!.attempts, 1);
  });

  test('un refus de validation sort l element de la file', () async {
    await put('/refus', key: 'r');

    await scheduler.drain(now: t0);

    final stored = await queue.byIdempotencyKey('r');
    expect(stored!.status, SyncItemStatus.abandoned);
    expect(stored.cause, SyncFailureCause.rejected);
  });

  test('une panne serveur est rejouable, avec un delai', () async {
    await put('/panne', key: 'p');

    await scheduler.drain(now: t0);

    final stored = await queue.byIdempotencyKey('p');
    expect(stored!.status, SyncItemStatus.failed);
    expect(stored.cause, SyncFailureCause.server);
    expect(stored.nextAttemptAt, isNotNull);
    expect(stored.nextAttemptAt!.isAfter(t0), isTrue);
  });

  test('un constat refuse reste dans la file (EXI-S05)', () async {
    // Meme un refus definitif ne fait pas disparaitre une preuve : elle change
    // seulement d'etat visible, pour qu'un humain tranche.
    await put('/refus', key: 'cst', priority: SyncPriority.custody);

    await scheduler.drain(now: t0);

    final stored = await queue.byIdempotencyKey('cst');
    expect(stored, isNotNull);
    expect(stored!.status, isNot(SyncItemStatus.abandoned));
  });

  test('deux vidanges simultanees n envoient pas deux fois', () async {
    // Le serveur dedoublonnerait grace a la cle, mais le forfait du livreur,
    // lui, serait bien debite deux fois (§4.4).
    await put('/ok', key: 'a');

    final results = await Future.wait([
      scheduler.drain(now: t0),
      scheduler.drain(now: t0),
    ]);

    expect(results.map((r) => r.sent).reduce((a, b) => a + b), 1);
    expect(seenKeys, hasLength(1));
  });

  test('le retour du reseau declenche une vidange', () async {
    await put('/ok', key: 'a');
    await scheduler.start();

    // Hors ligne d'abord, pour que la transition soit une vraie transition.
    network.add(_status(online: false));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    network.add(_status(online: true));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(await queue.byIdempotencyKey('a'), isNull);
  });
}

NetworkStatus _status({required bool online}) => NetworkStatus(
  reachable: online,
  profile: online ? NetworkProfile.fourG : NetworkProfile.offline,
  transport: online ? NetworkTransport.mobile : NetworkTransport.none,
  rttMs: online ? 90 : null,
  lastProbeAt: DateTime(2026, 8, 17),
);
