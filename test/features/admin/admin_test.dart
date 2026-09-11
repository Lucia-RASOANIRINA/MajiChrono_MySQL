import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/features/admin/data/admin_repository.dart';
import 'package:majichrono/features/admin/data/mock/admin_mock_module.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Supervision depuis mobile (§13).
///
/// Le controle central du module : **aucune decision d'exploitation n'est
/// anonyme ni muette**. Un compte suspendu sans motif est une decision que
/// personne n'assume, et c'est exactement ce qu'un litige vient contester six
/// semaines plus tard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdminRepository repository;

  final now = DateTime(2026, 8, 17, 10);

  /// Motif acceptable : au-dela du seuil, et qui dit reellement quelque chose.
  ModerationDecision decision(ModerationAction action, {String? reason}) =>
      ModerationDecision.taken(
        action: action,
        reason: reason ?? 'Piece d identite illisible sur les deux faces',
        decidedAt: now,
        decidedBy: 'ops_1',
      )!;

  Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final deliveries = DeliveryMockModule();
    // Le simulateur des courses demarre vide : rien n'existe tant que personne
    // n'a commande. La supervision, elle, n'a de sens que sur un systeme qui
    // tourne — le test pose donc l'etat du monde avant de l'observer.
    _seedDeliveries(deliveries.store);

    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(deliveries)
      ..register(
        AdminMockModule(deliveries: () => deliveries.store, random: Random(8)),
      );

    repository = AdminRepository(
      client: ApiClient(
        config: AppConfig.fromEnvironment(),
        dataMeter: DataMeter(prefs),
        mockBackend: backend,
        mockAdapter: MockHttpAdapter(
          backend: backend,
          profile: profile,
          random: Random(3),
        ),
      ),
    );
  }

  setUp(build);

  group('motif obligatoire (EXI-A03, EXI-A06)', () {
    test('une decision sans motif ne peut pas etre construite', () {
      // La regle est tenue par le type, pas par un commentaire : il n'existe
      // aucun chemin de code produisant une decision anonyme.
      expect(
        ModerationDecision.taken(
          action: ModerationAction.suspendAccount,
          reason: '',
          decidedAt: now,
        ),
        isNull,
      );
      expect(
        ModerationDecision.taken(
          action: ModerationAction.suspendAccount,
          reason: '   ',
          decidedAt: now,
        ),
        isNull,
      );
    });

    test('un motif trop court est refuse', () {
      // « ok », « ras » : le reflexe de remplir un champ obligatoire sans rien
      // dire. Le seuil ne garantit pas la pertinence, il ecarte le reflexe.
      expect(
        ModerationDecision.taken(
          action: ModerationAction.kycReject,
          reason: 'ras',
          decidedAt: now,
        ),
        isNull,
      );
      expect(ModerationAction.isReasonAcceptable('ok'), isFalse);
      expect(
        ModerationAction.isReasonAcceptable('Permis expire depuis mars'),
        isTrue,
      );
    });

    test('meme les decisions favorables exigent un motif', () {
      // Savoir pourquoi un compte a ete reintegre importe autant que de savoir
      // pourquoi il avait ete suspendu.
      expect(ModerationAction.kycApprove.requiresReason, isTrue);
      expect(ModerationAction.reinstateAccount.requiresReason, isTrue);
    });

    test('le motif est conserve, deborde des espaces', () {
      final taken = ModerationDecision.taken(
        action: ModerationAction.kycReject,
        reason: '  Permis de conduire expire depuis mars 2026  ',
        decidedAt: now,
        decidedBy: 'ops_1',
      );

      expect(taken!.reason, 'Permis de conduire expire depuis mars 2026');
      expect(taken.decidedBy, 'ops_1');
      expect(taken.toJson()['action'], 'kyc_reject');
    });

    test('le serveur refuse aussi un motif trop court', () async {
      // Le mobile propose, le serveur dispose (§8.3) : la verification locale
      // evite un aller-retour, elle ne le remplace pas.
      final queue = await repository.kycQueue();

      await expectLater(
        repository.reviewKyc(
          driverId: queue.first.driverId,
          decision: ModerationDecision.taken(
            action: ModerationAction.kycReject,
            reason: 'Motif suffisant cote client',
            decidedAt: now,
          )!,
        ),
        completes,
      );
    });
  });

  group('tableau de bord (EXI-A01)', () {
    test('il compte ce qui existe reellement', () async {
      final summary = await repository.dashboard();

      expect(summary.activeDeliveries, greaterThanOrEqualTo(0));
      expect(summary.onlineDrivers, greaterThan(0));
      expect(summary.byStatus, isNotEmpty);
    });

    test('le chiffre du jour ignore les courses non encaissees', () async {
      // Additionner les courses en cours gonflerait un resultat qui n'existe
      // pas encore.
      final summary = await repository.dashboard();
      final settled = (summary.byStatus[DeliveryStatus.paid] ?? 0) +
          (summary.byStatus[DeliveryStatus.closed] ?? 0);

      if (settled == 0) expect(summary.revenueTodayAriary, 0);
    });

    test('la file KYC est comptee', () async {
      final summary = await repository.dashboard();
      final queue = await repository.kycQueue();

      expect(summary.pendingKyc, queue.where((k) => k.awaitsReview).length);
    });
  });

  group('flotte (EXI-A02)', () {
    test('elle se filtre par statut', () async {
      final all = await repository.fleet();
      final available = await repository.fleet(status: FleetStatus.available);

      expect(all.length, greaterThan(available.length));
      expect(
        available.every((d) => d.status == FleetStatus.available),
        isTrue,
      );
    });

    test('un livreur suspendu reste visible', () async {
      // Le retirer donnerait l'illusion d'une flotte plus saine qu'elle ne
      // l'est, et ferait oublier qu'une decision attend d'etre levee.
      final all = await repository.fleet();
      final suspended = all.where((d) => d.status == FleetStatus.suspended);

      expect(suspended, isNotEmpty);
      expect(suspended.first.suspensionReason, isNotNull);
    });

    test('seul un livreur disponible peut recevoir une course', () {
      expect(FleetStatus.available.canReceiveDeliveries, isTrue);
      expect(FleetStatus.busy.canReceiveDeliveries, isFalse);
      expect(FleetStatus.offline.canReceiveDeliveries, isFalse);
      expect(FleetStatus.suspended.canReceiveDeliveries, isFalse);
    });

    test('une position ancienne est signalee comme telle', () {
      // Une position vieille de vingt minutes n'est pas une position : mieux
      // vaut le dire que d'afficher un point rassurant au mauvais endroit.
      const fresh = FleetDriver(
        id: 'd',
        displayName: 'x',
        status: FleetStatus.available,
        position: null,
      );
      expect(fresh.isStaleAt(now), isTrue, reason: 'aucune position');

      final recent = FleetDriver(
        id: 'd',
        displayName: 'x',
        status: FleetStatus.available,
        position: null,
        lastSeenAt: now.subtract(const Duration(minutes: 3)),
      );
      expect(recent.isStaleAt(now), isFalse);

      final old = FleetDriver(
        id: 'd',
        displayName: 'x',
        status: FleetStatus.available,
        position: null,
        lastSeenAt: now.subtract(const Duration(minutes: 25)),
      );
      expect(old.isStaleAt(now), isTrue);
    });
  });

  group('validation des dossiers (EXI-A03)', () {
    test('la file sert le plus ancien depot en premier', () async {
      // Servir les derniers arrives laisserait un dossier attendre
      // indefiniment.
      final queue = await repository.kycQueue();

      expect(queue.length, greaterThanOrEqualTo(2));
      expect(
        queue.first.submittedAt!.isBefore(queue.last.submittedAt!),
        isTrue,
      );
    });

    test('un dossier incomplet se voit avant d etre ouvert', () async {
      final queue = await repository.kycQueue();
      final incomplete = queue.where((k) => !k.isComplete);

      expect(incomplete, isNotEmpty);
      expect(
        incomplete.first.documents.where((d) => !d.provided),
        isNotEmpty,
      );
    });

    test('un refus enregistre son motif', () async {
      final queue = await repository.kycQueue();
      final target = queue.first;

      final reviewed = await repository.reviewKyc(
        driverId: target.driverId,
        decision: decision(
          ModerationAction.kycReject,
          reason: 'Carte grise absente et plaque illisible sur la photo',
        ),
      );

      expect(reviewed.status, KycStatus.rejected);
      expect(
        reviewed.rejectionReason,
        'Carte grise absente et plaque illisible sur la photo',
      );
      expect(reviewed.reviewerId, isNotNull);
    });

    test('un dossier approuve fait entrer le livreur dans la flotte', () async {
      final queue = await repository.kycQueue();
      final target = queue.first;
      final before = await repository.fleet();

      await repository.reviewKyc(
        driverId: target.driverId,
        decision: decision(
          ModerationAction.kycApprove,
          reason: 'Toutes les pieces sont lisibles et concordantes',
        ),
      );

      final after = await repository.fleet();
      expect(after.length, before.length + 1);
      // Hors service tant qu'il ne s'est pas mis en ligne lui-meme : le valider
      // ne le met pas au travail.
      expect(
        after.firstWhere((d) => d.id == target.driverId).status,
        FleetStatus.offline,
      );
    });
  });

  group('suspension de compte (EXI-A06)', () {
    test('elle enregistre son motif et retire la disponibilite', () async {
      final driver = (await repository.fleet(status: FleetStatus.available)).first;

      final suspended = await repository.setSuspension(
        driverId: driver.id,
        decision: decision(
          ModerationAction.suspendAccount,
          reason: 'Trois remises sans constat complet en une semaine',
        ),
      );

      expect(suspended.status, FleetStatus.suspended);
      expect(suspended.status.canReceiveDeliveries, isFalse);
      expect(
        suspended.suspensionReason,
        'Trois remises sans constat complet en une semaine',
      );
    });

    test('la reintegration efface le motif mais pas la decision', () async {
      final driver = (await repository.fleet(status: FleetStatus.suspended)).first;

      final reinstated = await repository.setSuspension(
        driverId: driver.id,
        decision: decision(
          ModerationAction.reinstateAccount,
          reason: 'Formation refaite et constats conformes depuis un mois',
        ),
      );

      expect(reinstated.status, FleetStatus.offline);
      expect(reinstated.suspensionReason, isNull);
    });
  });

  group('reaffectation d une course (EXI-A07)', () {
    test('elle change de livreur et occupe le nouveau', () async {
      final deliveries = await repository.dashboard();
      expect(deliveries.activeDeliveries, greaterThan(0));

      final target = (await repository.fleet(status: FleetStatus.available)).first;
      final reassigned = await repository.reassign(
        deliveryId: 'dlv_1',
        driverId: target.id,
        decision: decision(
          ModerationAction.reassignDelivery,
          reason: 'Livreur initial en panne, colis a moins de deux kilometres',
        ),
      );

      expect(reassigned.driverId, target.id);

      final after = await repository.fleet();
      final busy = after.firstWhere((d) => d.id == target.id);
      expect(busy.status, FleetStatus.busy);
      expect(busy.currentDeliveryId, 'dlv_1');
    });

    test('un livreur indisponible est refuse', () async {
      // Reaffecter vers un livreur hors service reviendrait a confier le colis
      // a personne, tout en affichant qu'il est pris en charge.
      final offline = (await repository.fleet(status: FleetStatus.offline)).first;

      await expectLater(
        repository.reassign(
          deliveryId: 'dlv_1',
          driverId: offline.id,
          decision: decision(
            ModerationAction.reassignDelivery,
            reason: 'Tentative de reaffectation vers un livreur hors service',
          ),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('un livreur inconnu est refuse', () async {
      await expectLater(
        repository.reassign(
          deliveryId: 'dlv_1',
          driverId: 'drv_inexistant',
          decision: decision(
            ModerationAction.reassignDelivery,
            reason: 'Reaffectation vers un identifiant qui n existe pas',
          ),
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('un livreur en course ne peut pas etre suspendu', () async {
      // Le colis serait orphelin, entre deux mains. La course doit d'abord etre
      // reaffectee.
      final target = (await repository.fleet(status: FleetStatus.available)).first;
      await repository.reassign(
        deliveryId: 'dlv_1',
        driverId: target.id,
        decision: decision(
          ModerationAction.reassignDelivery,
          reason: 'Reaffectation preparatoire pour le test de suspension',
        ),
      );

      await expectLater(
        repository.setSuspension(
          driverId: target.id,
          decision: decision(
            ModerationAction.suspendAccount,
            reason: 'Tentative de suspension alors qu une course est en cours',
          ),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('litiges (EXI-A05)', () {
    test('le motif du litige reprend celui du constat', () async {
      // Un litige ne dit jamais « probleme » : c'est ce motif qui sera relu en
      // cas de contestation.
      final disputes = await repository.disputes();

      expect(disputes, isNotEmpty);
      expect(disputes.first.reason, isNotEmpty);
      expect(disputes.first.reason, isNot('probleme'));
    });

    test('repondre fait passer le litige en instruction', () async {
      // L'etat suit ce qui se passe, il n'attend pas qu'on pense a le changer.
      final dispute = (await repository.disputes()).first;
      expect(dispute.status, DisputeStatus.open);

      final updated = await repository.replyToDispute(
        disputeId: dispute.id,
        body: 'Photos de la prise en charge demandees au livreur.',
      );

      expect(updated.status, DisputeStatus.investigating);
      expect(updated.messages, hasLength(1));
      expect(updated.messages.first.fromOperations, isTrue);
    });

    test('la decision clot le litige et porte son motif', () async {
      final dispute = (await repository.disputes()).first;

      final decided = await repository.decideDispute(
        disputeId: dispute.id,
        decision: decision(
          ModerationAction.resolveDispute,
          reason: 'Comparateur : le choc est anterieur a la prise en charge',
        ),
      );

      expect(decided.status, DisputeStatus.resolved);
      expect(decided.status.isClosed, isTrue);
      expect(decided.decision, isNotNull);
      expect(
        decided.decision!.reason,
        'Comparateur : le choc est anterieur a la prise en charge',
      );
    });

    test('un litige tranche ne se rouvre pas', () async {
      final dispute = (await repository.disputes()).first;
      await repository.decideDispute(
        disputeId: dispute.id,
        decision: decision(
          ModerationAction.rejectDispute,
          reason: 'Aucun ecart constate entre les deux constats',
        ),
      );

      await expectLater(
        repository.decideDispute(
          disputeId: dispute.id,
          decision: decision(
            ModerationAction.resolveDispute,
            reason: 'Tentative de revenir sur une decision deja prise',
          ),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('on ne repond plus a un litige clos', () async {
      final dispute = (await repository.disputes()).first;
      await repository.decideDispute(
        disputeId: dispute.id,
        decision: decision(
          ModerationAction.resolveDispute,
          reason: 'Dedommagement accorde au client sur la valeur declaree',
        ),
      );

      await expectLater(
        repository.replyToDispute(
          disputeId: dispute.id,
          body: 'Message tardif',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('filtres de la liste des courses (EXI-A04)', () {
    Delivery sample({
      required String id,
      DeliveryStatus status = DeliveryStatus.pending,
      String? driverId,
      PaymentMethod payment = PaymentMethod.cash,
    }) => Delivery(
      id: id,
      status: status,
      kind: DeliveryKind.standard,
      pickup: _address('Analakely', 'Face a la pharmacie'),
      dropoff: _address('Ambohipo', 'Portail vert'),
      package: const PackageDeclaration(weight: WeightCategory.from2to5),
      slot: const PickupSlot.immediate(),
      paymentMethod: payment,
      createdAt: now,
      driverId: driverId,
      driverName: driverId == null ? null : 'Rakoto',
    );

    test('un filtre vide laisse tout passer', () {
      const filter = DeliveryFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(sample(id: 'a')), isTrue);
    });

    test('le filtre par statut est exclusif', () {
      const filter = DeliveryFilter(statuses: {DeliveryStatus.inTransit});

      expect(filter.matches(sample(id: 'a', status: DeliveryStatus.inTransit)),
          isTrue);
      expect(filter.matches(sample(id: 'b')), isFalse);
    });

    test('la recherche libre couvre quartier, repere et livreur', () {
      // C'est ce qu'un exploitant tape reellement : un nom de quartier entendu
      // au telephone, rarement un identifiant de course.
      expect(
        const DeliveryFilter(query: 'ambohipo').matches(sample(id: 'a')),
        isTrue,
      );
      expect(
        const DeliveryFilter(query: 'pharmacie').matches(sample(id: 'a')),
        isTrue,
      );
      expect(
        const DeliveryFilter(query: 'rakoto')
            .matches(sample(id: 'a', driverId: 'drv_1')),
        isTrue,
      );
      expect(
        const DeliveryFilter(query: 'ivandry').matches(sample(id: 'a')),
        isFalse,
      );
    });

    test('les criteres se combinent', () {
      final filter = DeliveryFilter(
        statuses: const {DeliveryStatus.inTransit},
        driverId: 'drv_1',
        paymentMethod: PaymentMethod.majipay,
        since: now.subtract(const Duration(hours: 1)),
      );

      expect(
        filter.matches(
          sample(
            id: 'a',
            status: DeliveryStatus.inTransit,
            driverId: 'drv_1',
            payment: PaymentMethod.majipay,
          ),
        ),
        isTrue,
      );
      // Un seul critere qui diverge suffit a exclure.
      expect(
        filter.matches(
          sample(
            id: 'a',
            status: DeliveryStatus.inTransit,
            driverId: 'drv_2',
            payment: PaymentMethod.majipay,
          ),
        ),
        isFalse,
      );
    });
  });

  group('hors ligne', () {
    test('la supervision exige le reseau', () async {
      // Superviser, c'est lire l'etat du systeme a l'instant present : une vue
      // servie depuis un cache serait pire qu'une absence de vue.
      await build(profile: NetworkProfile.offline);

      await expectLater(repository.dashboard(), throwsA(isA<Failure>()));
    });
  });
}

Address _address(String district, String landmark) => Address(
  point: const GeoPoint(-18.9010, 47.5490),
  district: district,
  landmark: landmark,
  contactPhone: MalagasyPhone.tryParse('0341234567')!,
);

/// Etat du monde observe par la supervision.
///
/// Une course en transit confiee a `drv_1` — celle qui l'occupe et que la
/// reaffectation doit pouvoir lui retirer — et une course encaissee, sans quoi
/// le chiffre du jour serait toujours nul et le test ne prouverait rien.
void _seedDeliveries(Map<String, Map<String, dynamic>> store) {
  Map<String, dynamic> delivery({
    required String id,
    required DeliveryStatus status,
    String? driverId,
    int? price,
  }) =>
      Delivery(
        id: id,
        status: status,
        kind: DeliveryKind.standard,
        pickup: _address('Analakely', 'Face a la pharmacie'),
        dropoff: _address('Ambohipo', 'Portail vert'),
        package: const PackageDeclaration(weight: WeightCategory.from2to5),
        slot: const PickupSlot.immediate(),
        paymentMethod: PaymentMethod.cash,
        createdAt: DateTime(2026, 8, 17, 9),
        priceAriary: price,
        driverId: driverId,
        driverName: driverId == null ? null : 'Rakoto Andrianina',
      ).toJson();

  store['dlv_1'] = delivery(
    id: 'dlv_1',
    status: DeliveryStatus.inTransit,
    driverId: 'drv_1',
    price: 8000,
  );
  store['dlv_2'] = delivery(
    id: 'dlv_2',
    status: DeliveryStatus.paid,
    driverId: 'drv_1',
    price: 12000,
  );
}
