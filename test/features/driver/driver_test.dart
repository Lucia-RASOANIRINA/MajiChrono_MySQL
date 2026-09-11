import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/driver/data/mock/driver_mock_module.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';

/// Module 4 — parcours livreur.
///
/// Les tests portent sur ce qui, s'il cassait, laisserait un livreur bloque au
/// milieu d'une course : la file d'attente, l'acceptation concurrente, et la
/// validation des transitions **cote serveur** (EXI-B02).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient client;
  late DeliveryMockModule deliveryModule;

  Future<void> build() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    deliveryModule = DeliveryMockModule(random: Random(11));
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(deliveryModule)
      ..register(
        DriverMockModule(
          deliveries: () => deliveryModule.store,
          random: Random(11),
          // Ces tests portent sur l'acceptation et la progression : le livreur
          // est deja valide, sinon l'acceptation serait refusee (EXI-L01), ce
          // qui est teste ailleurs.
          kycStatus: 'approved',
        ),
      );

    client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(backend: backend, random: Random(11)),
    );
  }

  setUp(build);

  Future<List<AvailableDelivery>> offers() async {
    final json = await client.get<Map<String, dynamic>>(
      ApiEndpoints.deliveriesAvailable,
    );
    return (json['items'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(AvailableDelivery.fromJson)
        .whereType<AvailableDelivery>()
        .toList();
  }

  Future<Delivery> accept(String id) async {
    final json =
        await client.post<Map<String, dynamic>>('/deliveries/$id/accept');
    return Delivery.fromJson(json)!;
  }

  Future<Delivery> advance(String id, DeliveryStatus status) async {
    final json = await client.post<Map<String, dynamic>>(
      '/deliveries/$id/status',
      body: {'status': status.wireName},
    );
    return Delivery.fromJson(json)!;
  }

  group('file des courses disponibles (EXI-L04)', () {
    test('la file est triee par distance a vide croissante', () async {
      final items = await offers();

      expect(items, isNotEmpty);
      for (var i = 1; i < items.length; i++) {
        expect(
          items[i].pickupDistanceKm,
          greaterThanOrEqualTo(items[i - 1].pickupDistanceKm),
        );
      }
    });

    test('chaque course affiche un gain net, commission deduite', () async {
      final offer = (await offers()).first;

      expect(offer.estimatedEarningAriary, greaterThan(0));
      expect(
        offer.estimatedEarningAriary,
        lessThan(offer.delivery.priceAriary ?? 1 << 30),
        reason: 'le gain doit etre inferieur au prix paye par le client',
      );
    });

    test('le rendement tient compte de la distance a vide', () async {
      final offer = (await offers()).first;

      // Un livreur choisit au rendement reel, pas au montant affiche : une
      // course bien payee a huit kilometres a vide peut valoir moins qu'une
      // course modeste au coin de la rue.
      expect(offer.totalDistanceKm, greaterThan(offer.delivery.distanceKm));
      expect(offer.earningPerKm, greaterThan(0));
    });

    test('la file reste stable entre deux consultations', () async {
      final first = await offers();
      final second = await offers();

      expect(
        second.map((o) => o.delivery.id),
        first.map((o) => o.delivery.id),
        reason: 'une file qui change a chaque appel serait irrecettable',
      );
    });
  });

  group('acceptation (EXI-L05)', () {
    test('accepter retire la course de la file et l affecte au livreur',
        () async {
      final offer = (await offers()).first;

      final accepted = await accept(offer.delivery.id);

      expect(accepted.status, DeliveryStatus.accepted);
      expect(accepted.driverId, isNotNull);
      expect(
        (await offers()).map((o) => o.delivery.id),
        isNot(contains(offer.delivery.id)),
      );
    });

    test('une course deja prise remonte un conflit, pas une panne', () async {
      // C'est un cas normal de la course a l'acceptation entre livreurs :
      // l'interface doit le dire sans dramatiser.
      final offer = (await offers()).first;
      await accept(offer.delivery.id);

      await expectLater(
        accept(offer.delivery.id),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('progression (EXI-L08, EXI-B02)', () {
    test('la sequence nominale aboutit a la livraison', () async {
      final offer = (await offers()).first;
      final id = offer.delivery.id;
      await accept(id);

      expect((await advance(id, DeliveryStatus.atPickup)).status,
          DeliveryStatus.atPickup);
      expect((await advance(id, DeliveryStatus.pickedUp)).status,
          DeliveryStatus.pickedUp);
      expect((await advance(id, DeliveryStatus.atDestination)).status,
          DeliveryStatus.atDestination);
      expect((await advance(id, DeliveryStatus.delivered)).status,
          DeliveryStatus.delivered);
    });

    test('une transition qui saute une etape est refusee par le serveur',
        () async {
      // Le mobile propose, le serveur dispose (§8.3). Si le simulateur
      // acceptait tout, l'application donnerait l'illusion de fonctionner et le
      // defaut n'apparaitrait qu'au branchement du vrai backend.
      final offer = (await offers()).first;
      await accept(offer.delivery.id);

      await expectLater(
        advance(offer.delivery.id, DeliveryStatus.delivered),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.currentState,
            'currentState',
            DeliveryStatus.accepted.wireName,
          ),
        ),
      );
    });

    test('la livraison alimente les gains du jour (EXI-L12)', () async {
      final offer = (await offers()).first;
      final id = offer.delivery.id;
      await accept(id);
      await advance(id, DeliveryStatus.atPickup);
      await advance(id, DeliveryStatus.pickedUp);
      await advance(id, DeliveryStatus.atDestination);
      await advance(id, DeliveryStatus.delivered);

      final json =
          await client.get<Map<String, dynamic>>('/drivers/earnings');
      final earnings = EarningsSummary.fromJson(json);

      expect(earnings.todayCount, 1);
      expect(earnings.todayAriary, offer.estimatedEarningAriary);
      expect(earnings.entries.single.deliveryId, id);
    });
  });

  group('actions du livreur', () {
    test('les etapes de constat sont identifiees (EXI-CC03)', () {
      // Le drapeau existe des maintenant pour que le module 5 n'ait qu'a
      // intercaler l'ecran de constat, sans toucher a la progression.
      expect(DriverAction.pickedUp.requiresCustodyReport, isTrue);
      expect(DriverAction.delivered.requiresCustodyReport, isTrue);
      expect(DriverAction.arrivedAtPickup.requiresCustodyReport, isFalse);
    });

    test('l action suivante decoule du statut courant', () {
      expect(DriverAction.nextFor(DeliveryStatus.accepted),
          DriverAction.arrivedAtPickup);
      expect(DriverAction.nextFor(DeliveryStatus.atDestination),
          DriverAction.delivered);
      // Rien n'est attendu du livreur sur une course livree.
      expect(DriverAction.nextFor(DeliveryStatus.delivered), isNull);
    });

    test('chaque incident porte une consequence definie (EXI-L14)', () {
      for (final type in IncidentType.values) {
        expect(type.outcome, isNotNull);
      }
      expect(
        IncidentType.recipientAbsent.outcome,
        IncidentOutcome.waitThenReturn,
      );
    });
  });

  group('cadence d emission de position (EXI-L11)', () {
    test('15 s en mouvement, 60 s a l arret', () {
      expect(PingCadence.forSpeed(25), PingCadence.moving);
      expect(PingCadence.forSpeed(0), PingCadence.stopped);
      expect(PingCadence.forSpeed(null), PingCadence.stopped);
    });

    test('un deplacement a pied compte comme un mouvement', () {
      expect(PingCadence.forSpeed(5), PingCadence.moving);
    });
  });

  group('lot de positions (EXI-B06)', () {
    test('un lot de plus de 50 points est refuse', () async {
      await expectLater(
        client.post<Map<String, dynamic>>(
          ApiEndpoints.trackingBatch,
          body: {'points': List.filled(51, {'lat': -18.9, 'lng': 47.5})},
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un lot de 50 points est accepte', () async {
      final json = await client.post<Map<String, dynamic>>(
        ApiEndpoints.trackingBatch,
        body: {'points': List.filled(50, {'lat': -18.9, 'lng': 47.5})},
      );
      expect(json['accepted'], 50);
    });
  });
}
