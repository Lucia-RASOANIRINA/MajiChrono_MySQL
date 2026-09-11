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
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/data/datasources/delivery_local_data_source.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Module 2 — creation de course.
///
/// La base locale est ouverte en memoire. Ces tests ne s'executent que la ou
/// `sqlite3` est disponible pour le poste ; ils sont ignores sinon, plutot que
/// de faire echouer toute la suite pour une raison d'environnement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Address address({required String district, required GeoPoint point}) => Address(
        point: point,
        district: district,
        landmark: 'Apres l epicerie Tsiky, portail vert',
        contactPhone: MalagasyPhone.tryParse('0341234567')!,
      );

  final pickup = address(district: 'Ambohipo', point: const GeoPoint(-18.9010, 47.5490));
  final dropoff = address(district: 'Analakely', point: const GeoPoint(-18.9100, 47.5250));

  DeliveryDraft draft({
    DeliveryKind kind = DeliveryKind.standard,
    WeightCategory weight = WeightCategory.upTo2,
    PickupSlot? slot,
  }) =>
      DeliveryDraft(
        pickup: pickup,
        dropoff: dropoff,
        kind: kind,
        package: PackageDeclaration(weight: weight),
        slot: slot ?? const PickupSlot.immediate(),
        paymentMethod: PaymentMethod.cash,
      );

  group('adresse composite (EXI-C02, D3)', () {
    test('le point de repere et le telephone sont structurellement obligatoires', () {
      // La contrainte est portee par le type : une adresse sans repere ne se
      // construit pas a moitie, elle est simplement incomplete.
      final incomplete = Address(
        point: GeoPoint.antananarivo,
        district: 'Ambohipo',
        landmark: '   ',
        contactPhone: MalagasyPhone.tryParse('0341234567')!,
      );
      expect(incomplete.isComplete, isFalse);
      expect(pickup.isComplete, isTrue);
    });

    test('la rue reste facultative', () {
      expect(pickup.street, isNull);
      expect(pickup.isComplete, isTrue);
    });

    test('le resume met le point de repere en premier', () {
      // C'est le repere qui identifie le lieu pour un Malgache (§4.3), pas le
      // quartier seul.
      expect(pickup.summary.startsWith('Apres l epicerie'), isTrue);
    });

    test('l adresse survit a un aller-retour JSON', () {
      final restored = Address.fromJson(pickup.toJson());
      expect(restored, isNotNull);
      expect(restored!.landmark, pickup.landmark);
      expect(restored.contactPhone, pickup.contactPhone);
    });
  });

  group('estimation de prix (EXI-C10)', () {
    const grid = TariffGrid.provisional;

    test('la ventilation comporte au moins la base et la distance', () {
      final estimate = grid.estimate(
        straightLineKm: 4,
        kind: DeliveryKind.standard,
        weight: WeightCategory.upTo2,
        slot: const PickupSlot.immediate(),
      );

      expect(
        estimate.lines.map((l) => l.kind),
        containsAll([PriceLineKind.base, PriceLineKind.distance]),
      );
      expect(estimate.isProvisional, isTrue);
    });

    test('le total est la somme des lignes, plancher applique', () {
      final estimate = grid.estimate(
        straightLineKm: 4,
        kind: DeliveryKind.standard,
        weight: WeightCategory.upTo2,
        slot: const PickupSlot.immediate(),
      );
      final sum = estimate.lines.fold<int>(0, (s, l) => s + l.amountAriary);
      expect(estimate.totalAriary, sum);
    });

    test('le tarif court respecte le forfait de base et la distance', () {
      final estimate = grid.estimate(
        straightLineKm: 0.1,
        kind: DeliveryKind.standard,
        weight: WeightCategory.upTo2,
        slot: const PickupSlot.immediate(),
      );
      expect(estimate.totalAriary, 2000 + (0.1 * 800).round());
    });

    test('la distance tarifee reste la distance calculee', () {
      // Les rues d'Antananarivo ne vont pas en ligne droite : sous-estimer la
      // distance reviendrait a sous-payer le livreur.
      final estimate = grid.estimate(
        straightLineKm: 10,
        kind: DeliveryKind.standard,
        weight: WeightCategory.upTo2,
        slot: const PickupSlot.immediate(),
      );
      expect(estimate.distanceKm, 10);
    });

    test('fragile, poids et creneau programme majorent le prix', () {
      int total({
        DeliveryKind kind = DeliveryKind.standard,
        WeightCategory weight = WeightCategory.upTo2,
        PickupSlot slot = const PickupSlot.immediate(),
      }) =>
          grid
              .estimate(
                straightLineKm: 8,
                kind: kind,
                weight: weight,
                slot: slot,
              )
              .totalAriary;

      final base = total();
      expect(total(kind: DeliveryKind.fragile), greaterThan(base));
      expect(total(weight: WeightCategory.from5to15), greaterThan(base));
      expect(
        total(slot: PickupSlot.scheduled(date: DateTime(2026, 9, 1), hour: 8)),
        greaterThan(base),
      );
    });

    test('les montants en ariary sont lisibles, sans decimale', () {
      // Le separateur est un espace insecable : un montant ne doit pas se
      // couper en fin de ligne. On l'ecrit en echappement, sans quoi le test
      // comparerait deux chaines visuellement identiques.
      const nb = thousandsSeparator;
      expect(formatAriary(12000), '12${nb}000${nb}Ar');
      expect(formatAriary(950), '950${nb}Ar');
      expect(formatAriary(1250000), '1${nb}250${nb}000${nb}Ar');
    });
  });

  group('creation de course', () {
    late AppDatabase db;
    late DeliveryRepositoryImpl repository;
    late MockBackend backend;

    Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      backend = MockBackend()
        ..register(CoreMockModule())
        ..register(DeliveryMockModule(random: Random(3)));

      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DeliveryRepositoryImpl(
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
        local: DeliveryLocalDataSource(db),
        queue: SyncQueue(db),
      );
    }

    tearDown(() async => db.close());

    test('en ligne : la course est confirmee par le serveur', () async {
      await build();

      final delivery = await repository.createDelivery(draft());

      expect(delivery.pendingSync, isFalse);
      expect(delivery.id.startsWith('dlv_'), isTrue);
      expect(delivery.status, DeliveryStatus.pending);
      expect(delivery.priceAriary, isNotNull);
      // Le lien de suivi public est attribue des la creation (EXI-C24).
      expect(delivery.trackingToken, isNotNull);
    });

    test('hors ligne : la course existe quand meme, marquee en attente (EXI-C13)',
        () async {
      await build(profile: NetworkProfile.offline);

      final delivery = await repository.createDelivery(draft());

      expect(delivery.pendingSync, isTrue);
      expect(delivery.id.startsWith('local_'), isTrue);

      // Et elle est bien lisible dans l'historique local, sans reseau.
      final stored = await repository.watchDeliveries().first;
      expect(stored, hasLength(1));
      expect(stored.single.pendingSync, isTrue);
    });

    test('la course creee hors ligne survit et reste distinguable', () async {
      await build(profile: NetworkProfile.offline);
      await repository.createDelivery(draft());

      final fromDb = await repository.watchDeliveries().first;
      expect(fromDb.single.pickup.landmark, pickup.landmark);
      expect(fromDb.single.dropoff.district, 'Analakely');
    });

    test('un rafraichissement n ecrase pas une course non transmise', () async {
      await build();
      // Une course confirmee, puis une course locale non transmise.
      await repository.createDelivery(draft());

      final localOnly = await DeliveryRepositoryImpl(
        client: ApiClient(
          config: AppConfig.fromEnvironment(),
          dataMeter: DataMeter(await SharedPreferences.getInstance()),
          mockBackend: backend,
          mockAdapter: MockHttpAdapter(
            backend: backend,
            profile: NetworkProfile.offline,
          ),
        ),
        local: DeliveryLocalDataSource(db),
        queue: SyncQueue(db),
      ).createDelivery(draft(kind: DeliveryKind.document));

      await repository.refreshDeliveries();

      final all = await repository.watchDeliveries().first;
      expect(all.any((d) => d.id == localOnly.id), isTrue,
          reason: 'la course non transmise a ete effacee par le serveur');
      expect(all, hasLength(2));
    });

    test('annuler une course en attente la passe au statut annulee (EXI-C26)',
        () async {
      await build();
      final delivery = await repository.createDelivery(draft());

      // Aucun livreur engage : l'annulation ne retient aucun frais.
      final fee = await repository.cancelDelivery(
        delivery.id,
        reason: 'Changement d avis',
      );
      expect(fee, 0);

      final updated = await repository.deliveryById(delivery.id);
      expect(updated!.status, DeliveryStatus.cancelled);
    });

    test('le carnet d adresses persiste et se relit hors ligne (EXI-C05)', () async {
      await build(profile: NetworkProfile.offline);

      await repository.saveAddress(label: 'Maison', kind: AddressKind.other, address: pickup);
      await repository.saveAddress(label: 'Boutique', kind: AddressKind.other, address: dropoff);

      final book = await repository.watchAddressBook().first;
      expect(book, hasLength(2));
      expect(book.map((e) => e.label), containsAll(['Maison', 'Boutique']));
    });

    test('les adresses les plus utilisees remontent en tete', () async {
      await build();
      final maison = await repository.saveAddress(label: 'Maison', kind: AddressKind.other, address: pickup);
      await repository.saveAddress(label: 'Boutique', kind: AddressKind.other, address: dropoff);

      await repository.touchAddress(maison.id);
      await repository.touchAddress(maison.id);

      final book = await repository.watchAddressBook().first;
      expect(book.first.label, 'Maison');
    });
  });
}
