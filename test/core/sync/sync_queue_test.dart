import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';

/// File de synchronisation : ordre, reprise, et la regle qui prime sur toutes
/// les autres — une preuve ne s'abandonne pas (EXI-S05).
void main() {
  late AppDatabase db;
  late SyncQueue queue;

  final t0 = DateTime(2026, 8, 17, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db);
  });
  tearDown(() async => db.close());

  Future<SyncItem> put(
    SyncPriority priority, {
    required String key,
    DateTime? at,
  }) => queue.enqueue(
    method: 'POST',
    path: '/x/$key',
    idempotencyKey: key,
    body: {'k': key},
    priority: priority,
    now: at ?? t0,
  );

  group('ordre de passage (EXI-S02)', () {
    test('les constats passent avant tout le reste', () async {
      // Depose dans l'ordre inverse de la priorite, pour que seul le tri
      // puisse produire le bon resultat.
      await put(SyncPriority.rating, key: 'note');
      await put(SyncPriority.position, key: 'pos');
      await put(SyncPriority.transition, key: 'statut');
      await put(SyncPriority.custody, key: 'constat');

      final due = await queue.due(now: t0);

      expect(
        due.map((i) => i.idempotencyKey),
        ['constat', 'statut', 'pos', 'note'],
      );
    });

    test('a priorite egale, le plus ancien part le premier', () async {
      // Sans ce second critere, un element malchanceux resterait indefiniment
      // derriere les nouveaux arrivants.
      await put(SyncPriority.transition, key: 'recent', at: t0);
      await put(
        SyncPriority.transition,
        key: 'ancien',
        at: t0.subtract(const Duration(hours: 3)),
      );

      final due = await queue.due(now: t0);
      expect(due.first.idempotencyKey, 'ancien');
    });
  });

  group('depot (EXI-S01)', () {
    test('deposer deux fois la meme cle ne cree qu une ligne', () async {
      final first = await put(SyncPriority.custody, key: 'cst_1');
      final second = await put(SyncPriority.custody, key: 'cst_1');

      expect(second.id, first.id);
      expect(await queue.due(now: t0), hasLength(1));
    });

    test('le corps est restitue tel quel', () async {
      await put(SyncPriority.transition, key: 'abc');
      final item = (await queue.due(now: t0)).single;

      expect(item.body, {'k': 'abc'});
      expect(item.method, 'POST');
      expect(item.path, '/x/abc');
    });

    test('un constat porte le drapeau jamais-abandonner (EXI-S05)', () async {
      final custody = await put(SyncPriority.custody, key: 'cst');
      final other = await put(SyncPriority.transition, key: 'trs');

      expect(custody.neverAbandon, isTrue);
      expect(other.neverAbandon, isFalse);
    });
  });

  group('reprise', () {
    test('un element en echec attend son tour', () async {
      final item = await put(SyncPriority.transition, key: 'a');

      await queue.markFailure(
        item,
        cause: SyncFailureCause.network,
        retryable: true,
        retryIn: const Duration(minutes: 10),
        now: t0,
      );

      expect(await queue.due(now: t0), isEmpty);
      expect(
        await queue.due(now: t0.add(const Duration(minutes: 11))),
        hasLength(1),
      );
    });

    test('un refus definitif sort l element de la file', () async {
      // Rejouer un conflit a l'identique produirait le meme refus, en debitant
      // le forfait a chaque passage.
      final item = await put(SyncPriority.transition, key: 'a');

      await queue.markFailure(
        item,
        cause: SyncFailureCause.conflict,
        retryable: false,
        now: t0,
      );

      expect(await queue.due(now: t0.add(const Duration(days: 1))), isEmpty);

      final stored = await queue.byIdempotencyKey('a');
      expect(stored!.status, SyncItemStatus.abandoned);
      expect(stored.cause, SyncFailureCause.conflict);
    });

    test('quinze echecs epuisent un element ordinaire (§10.2)', () async {
      var item = await put(SyncPriority.transition, key: 'a');

      for (var i = 0; i < SyncBackoff.maxAttempts; i++) {
        await queue.markFailure(
          item,
          cause: SyncFailureCause.network,
          retryable: true,
          now: t0,
        );
        item = (await queue.byIdempotencyKey('a'))!;
      }

      expect(item.attempts, SyncBackoff.maxAttempts);
      expect(item.status, SyncItemStatus.abandoned);
      expect(item.cause, SyncFailureCause.exhausted);
    });

    test('un constat survit a cinquante echecs (EXI-S05)', () async {
      // C'est la contradiction assumee avec le plafond du §10.2 : abandonner
      // une preuve parce que le reseau a ete mauvais serait exactement le
      // defaut que la chaine de responsabilite rend impossible.
      var item = await put(SyncPriority.custody, key: 'cst');

      for (var i = 0; i < 50; i++) {
        await queue.markFailure(
          item,
          cause: SyncFailureCause.network,
          retryable: true,
          now: t0,
        );
        item = (await queue.byIdempotencyKey('cst'))!;
      }

      expect(item.attempts, 50);
      expect(item.status, isNot(SyncItemStatus.abandoned));
      expect(await queue.due(now: t0.add(const Duration(days: 2))), hasLength(1));
    });

    test('un constat refuse par le serveur reste en file', () async {
      // Meme un refus definitif ne le fait pas disparaitre : un humain doit
      // trancher, pas l'ordonnanceur.
      final item = await put(SyncPriority.custody, key: 'cst');

      await queue.markFailure(
        item,
        cause: SyncFailureCause.rejected,
        retryable: false,
        now: t0,
      );

      final stored = await queue.byIdempotencyKey('cst');
      expect(stored!.status, isNot(SyncItemStatus.abandoned));
      expect(stored.cause, SyncFailureCause.rejected);
    });
  });

  group('relance manuelle (EXI-S06)', () {
    test('elle remet un element abandonne en jeu', () async {
      final item = await put(SyncPriority.transition, key: 'a');
      await queue.markFailure(
        item,
        cause: SyncFailureCause.server,
        retryable: false,
        now: t0,
      );
      expect(await queue.due(now: t0), isEmpty);

      // L'utilisateur qui appuie sait quelque chose que la machine ignore : il
      // a retrouve du reseau, ou corrige la cause.
      await queue.retryNow(item.id);

      final revived = (await queue.due(now: t0)).single;
      expect(revived.attempts, 0);
      expect(revived.status, SyncItemStatus.pending);
      expect(revived.cause, SyncFailureCause.none);
    });

    test('tout relancer remet la file entiere en jeu', () async {
      for (final key in ['a', 'b', 'c']) {
        final item = await put(SyncPriority.transition, key: key);
        await queue.markFailure(
          item,
          cause: SyncFailureCause.server,
          retryable: false,
          now: t0,
        );
      }

      await queue.retryAll();
      expect(await queue.due(now: t0), hasLength(3));
    });
  });

  group('reprise apres fermeture brutale', () {
    test('un element reste en vol repart', () async {
      // Sans cela, une fermeture pendant l'envoi laisserait une ligne bloquee
      // pour toujours. La cle d'idempotence rend le rejeu sans danger.
      final item = await put(SyncPriority.custody, key: 'cst');
      await queue.markInFlight(item.id);
      expect(await queue.due(now: t0), isEmpty);

      await queue.recoverInFlight();
      expect(await queue.due(now: t0), hasLength(1));
    });
  });

  group('politique de reprise', () {
    test('le delai croit et se plafonne a trente minutes', () async {
      const backoff = SyncBackoff();

      expect(backoff.delayFor(0), Duration.zero);
      expect(backoff.delayFor(1), lessThan(backoff.delayFor(4)));
      expect(backoff.delayFor(4), lessThan(backoff.delayFor(8)));
      // Au-dela, doubler encore n'apporterait rien : un livreur qui rentre en
      // zone couverte veut que sa file reparte dans la demi-heure.
      expect(backoff.delayFor(30), lessThanOrEqualTo(SyncBackoff.ceiling * 1.2));
    });
  });
}
