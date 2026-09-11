import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/settings/economy_mode.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/driver/domain/entities/delivery_group.dart';
import 'package:majichrono/features/driver/domain/entities/emergency.dart';

/// Differenciants concurrentiels (§5, module 9).
///
/// Chaque groupe protege une regle qui existe parce que quelqu'un, sur le
/// terrain, avance de l'argent, fait un detour, ou appuie sur un bouton au bord
/// d'une route.
void main() {
  final now = DateTime(2026, 8, 17, 11);

  Address address(double lat, double lng, {String district = 'Analakely'}) =>
      Address(
        point: GeoPoint(lat, lng),
        district: district,
        landmark: 'Face a la pharmacie',
        contactPhone: MalagasyPhone.tryParse('0341234567')!,
      );

  Delivery delivery({
    required String id,
    required Address pickup,
    required Address dropoff,
    int price = 8000,
  }) => Delivery(
    id: id,
    status: DeliveryStatus.pending,
    kind: DeliveryKind.standard,
    pickup: pickup,
    dropoff: dropoff,
    package: const PackageDeclaration(weight: WeightCategory.upTo2),
    slot: const PickupSlot.immediate(),
    paymentMethod: PaymentMethod.cash,
    createdAt: now,
    priceAriary: price,
  );

  group('achat pour compte (EXI-C07, D5)', () {
    ShoppingOrder order({
      int cap = 50000,
      List<ShoppingItem>? items,
      int? actual,
    }) => ShoppingOrder(
      capAriary: cap,
      actualTotalAriary: actual,
      items: items ??
          const [
            ShoppingItem(label: 'Riz 5 kg', quantity: 1, estimatedUnitAriary: 12000),
            ShoppingItem(label: 'Huile 1 L', quantity: 2, estimatedUnitAriary: 9000),
          ],
    );

    test('l estimation additionne quantites et prix unitaires', () {
      expect(order().estimatedTotalAriary, 12000 + 2 * 9000);
    });

    test('un plafond hors bornes est refuse', () {
      // Le plafond borne ce qu'on fait avancer au livreur sur son propre
      // argent : trop bas il est inutile, trop haut il n'est plus une
      // protection.
      expect(order(cap: 100).isCapAcceptable, isFalse);
      expect(order(cap: 999999).isCapAcceptable, isFalse);
      expect(order(cap: ShoppingOrder.minCapAriary).isCapAcceptable, isTrue);
      expect(order(cap: ShoppingOrder.maxCapAriary).isCapAcceptable, isTrue);
    });

    test('un plafond inferieur a l estimation est signale', () {
      // Presque toujours une erreur de saisie. Mieux vaut le dire avant l'envoi
      // que laisser le livreur le decouvrir devant la caisse.
      expect(order(cap: 10000).capCoversEstimate, isFalse);
      expect(order(cap: 50000).capCoversEstimate, isTrue);
    });

    test('une liste vide ou mal formee n est pas complete', () {
      expect(order(items: const []).isComplete, isFalse);
      expect(
        order(items: const [ShoppingItem(label: '  ', quantity: 1)]).isComplete,
        isFalse,
      );
      expect(
        order(items: const [ShoppingItem(label: 'Riz', quantity: 0)]).isComplete,
        isFalse,
      );
    });

    test('le remboursement est plafonne', () {
      // Ce qui a ete depense au-dela du plafond n'engage pas l'expediteur :
      // c'est precisement ce que le plafond signifie.
      expect(order(cap: 50000, actual: 42000).reimbursableAriary, 42000);
      expect(order(cap: 50000, actual: 61000).reimbursableAriary, 50000);
      expect(order(cap: 50000).reimbursableAriary, 0, reason: 'ticket absent');
    });

    test('un depassement de plafond est detectable', () {
      // Le cas doit rester impossible — le livreur s'arrete au plafond — mais
      // s'il survient, il vaut mieux qu'il soit visible que silencieux.
      expect(order(cap: 50000, actual: 61000).exceedsCap, isTrue);
      expect(order(cap: 50000, actual: 42000).exceedsCap, isFalse);
    });

    test('l ecart entre estime et reel est annonce, pas absorbe', () {
      expect(order(actual: 33000).variance, 33000 - 30000);
      expect(order(actual: 27000).variance, -3000);
      expect(order().variance, isNull);
    });

    test('la substitution se decide article par article', () {
      // Accepter un autre riz n'engage pas a accepter un autre medicament.
      const items = [
        ShoppingItem(label: 'Riz 5 kg', quantity: 1, substitutable: true),
        ShoppingItem(label: 'Paracetamol', quantity: 1),
      ];

      expect(items.first.substitutable, isTrue);
      expect(items.last.substitutable, isFalse);
    });

    test('le tour de serialisation conserve tout', () {
      final restored = ShoppingOrder.fromJson(
        order(cap: 50000, actual: 42000).toJson(),
      );

      expect(restored!.capAriary, 50000);
      expect(restored.actualTotalAriary, 42000);
      expect(restored.items, hasLength(2));
      expect(restored.estimatedTotalAriary, 30000);
    });
  });

  group('payeur designable et port du (EXI-C42)', () {
    test('le port du se regle a la remise', () {
      expect(Payer.recipient.paysOnDelivery, isTrue);
      expect(Payer.sender.paysOnDelivery, isFalse);
    });

    test('le port du exige que le destinataire ait ete prevenu', () {
      // Un destinataire qui decouvre un prix sur le pas de sa porte refuse le
      // colis, et c'est le livreur qui perd sa course.
      expect(Payer.recipient.requiresRecipientNotice, isTrue);
      expect(Payer.sender.requiresRecipientNotice, isFalse);
    });

    test('un payeur inconnu retombe sur l expediteur', () {
      expect(Payer.fromWire('inconnu'), Payer.sender);
      expect(Payer.fromWire(null), Payer.sender);
      expect(Payer.fromWire('recipient'), Payer.recipient);
    });
  });

  group('points relais (D6)', () {
    RelayPoint relay({
      bool dropoff = true,
      double maxKg = 15,
    }) => RelayPoint(
      id: 'rel_1',
      name: 'Epicerie Tsiky',
      district: 'Ambohipo',
      landmark: 'Portail vert, apres le pont',
      point: const GeoPoint(-18.90, 47.54),
      openingHours: 'Lun-Sam 7h-19h',
      acceptsDropoff: dropoff,
      maxWeightKg: maxKg,
    );

    test('un relais refuse ce qui ne tient pas derriere son comptoir', () {
      // Un relais est une boutique, pas un entrepot.
      expect(relay().canAccept(10), isTrue);
      expect(relay().canAccept(22), isFalse);
      expect(relay(maxKg: 5).canAccept(10), isFalse);
    });

    test('un relais qui n accepte pas les depots les refuse tous', () {
      expect(relay(dropoff: false).canAccept(1), isFalse);
    });

    test('le relais porte un point de repere, comme toute adresse', () {
      // Meme registre que les adresses composites (D3) : un relais qu'on ne
      // trouve pas ne sert a rien.
      expect(relay().landmark, isNotEmpty);
      expect(relay().openingHours, isNotEmpty);
    });

    test('le tour de serialisation conserve les capacites', () {
      final restored = RelayPoint.fromJson(relay(maxKg: 8).toJson());

      expect(restored!.maxWeightKg, 8);
      expect(restored.storageDays, 3);
      expect(restored.landmark, 'Portail vert, apres le pont');
    });
  });

  group('bouton d urgence (EXI-L13, D10)', () {
    test('une alerte part sans position ni nature', () {
      // Attendre un point GPS couterait les secondes qui comptent, et sous un
      // pont il ne viendra jamais.
      final alert = EmergencyAlert(
        id: 'sos_1',
        raisedAt: now,
        kind: EmergencyKind.unspecified,
      );

      expect(alert.point, isNull);
      expect(alert.toJson()['kind'], 'unspecified');
      expect(alert.toJson()['raisedAt'], isNotNull);
    });

    test('agression, accident et malaise appellent un rappel immediat', () {
      // Une panne peut attendre quelques minutes ; le reste, non.
      expect(EmergencyKind.aggression.needsImmediateCallback, isTrue);
      expect(EmergencyKind.accident.needsImmediateCallback, isTrue);
      expect(EmergencyKind.medical.needsImmediateCallback, isTrue);
      expect(EmergencyKind.breakdown.needsImmediateCallback, isFalse);
    });

    test('une alerte sans accuse au bout de deux minutes est signalee', () {
      // Plutot que de laisser le livreur croire que quelqu'un l'a vue.
      final alert = EmergencyAlert(
        id: 'sos_1',
        raisedAt: now,
        kind: EmergencyKind.accident,
      );

      expect(alert.isUnacknowledgedAt(now.add(const Duration(seconds: 30))), isFalse);
      expect(alert.isUnacknowledgedAt(now.add(const Duration(minutes: 3))), isTrue);
    });

    test('un accuse de reception arrete le signalement', () {
      final alert = EmergencyAlert(
        id: 'sos_1',
        raisedAt: now,
        kind: EmergencyKind.accident,
      ).acknowledgedAtTime(now.add(const Duration(seconds: 40)));

      expect(alert.isAcknowledged, isTrue);
      expect(alert.isUnacknowledgedAt(now.add(const Duration(hours: 1))), isFalse);
    });

    test('le niveau de batterie voyage avec l alerte', () {
      // Une alerte partie a 3 % dit a l'exploitation qu'il ne faut pas compter
      // rappeler.
      final alert = EmergencyAlert(
        id: 'sos_1',
        raisedAt: now,
        kind: EmergencyKind.breakdown,
        batteryPercent: 3,
      );

      expect(alert.toJson()['battery'], 3);
      expect(EmergencyAlert.fromJson(alert.toJson())!.batteryPercent, 3);
    });
  });

  group('groupage (EXI-L06, D7)', () {
    // Deux courses sur le meme axe est-ouest, retraits et remises proches.
    final onAxis = [
      delivery(
        id: 'a',
        pickup: address(-18.900, 47.520),
        dropoff: address(-18.900, 47.560),
      ),
      delivery(
        id: 'b',
        pickup: address(-18.901, 47.522),
        dropoff: address(-18.901, 47.558),
      ),
    ];

    // Deux courses qui partent dans des directions opposees.
    final opposite = [
      delivery(
        id: 'a',
        pickup: address(-18.900, 47.520),
        dropoff: address(-18.900, 47.560),
      ),
      delivery(
        id: 'c',
        pickup: address(-18.960, 47.480),
        dropoff: address(-18.830, 47.620),
      ),
    ];

    test('deux courses sur un meme axe font gagner des kilometres', () {
      final group = DeliveryGroup(deliveries: onAxis);

      expect(group.savedKm, greaterThan(0));
      expect(group.isViable, isTrue);
    });

    test('deux courses opposees ne se groupent pas', () {
      // Elles s'additionnent au lieu de se recouvrir, et le livreur perd sur
      // les deux.
      final group = DeliveryGroup(deliveries: opposite);

      expect(group.detourKm, greaterThan(DeliveryGroup.maxDetourKm));
      expect(group.isViable, isFalse);
    });

    test('un groupe de une ou de quatre courses est irrecevable', () {
      expect(
        DeliveryGroup(deliveries: [onAxis.first]).hasAcceptableSize,
        isFalse,
      );
      expect(
        DeliveryGroup(
          deliveries: [...onAxis, onAxis.first, onAxis.last],
        ).hasAcceptableSize,
        isFalse,
      );
    });

    test('les retraits precedent toutes les remises', () {
      // Un livreur qui livre avant d'avoir tout pris devra revenir, et
      // l'interet du groupage disparait.
      final stops = DeliveryGroup(deliveries: onAxis).stops;

      final firstDropoff =
          stops.indexWhere((s) => s.kind == GroupStopKind.dropoff);
      final lastPickup =
          stops.lastIndexWhere((s) => s.kind == GroupStopKind.pickup);

      expect(lastPickup, lessThan(firstDropoff));
      expect(stops, hasLength(4));
    });

    test('le gain total est la somme des courses', () {
      expect(DeliveryGroup(deliveries: onAxis).totalPriceAriary, 16000);
    });

    test('un groupe plein n accepte plus rien', () {
      final full = DeliveryGroup(deliveries: [...onAxis, onAxis.first]);
      expect(full.accepts(onAxis.last), isFalse);
    });

    test('une course deja dans le groupe n est pas ajoutee deux fois', () {
      final group = DeliveryGroup(deliveries: [onAxis.first]);
      expect(group.accepts(onAxis.first), isFalse);
    });

    test('une course hors axe est refusee a l ajout', () {
      final group = DeliveryGroup(deliveries: [opposite.first]);
      expect(group.accepts(opposite.last), isFalse);
    });
  });

  group('mode economie (EXI-T08)', () {
    const off = EconomySettings();
    const on = EconomySettings(enabled: true);

    test('une preuve part toujours, mode economie ou non', () {
      // Une preuve amoindrie pour economiser deux cents kilo-octets ne serait
      // plus une preuve.
      expect(
        on.allowsUpload(isProof: true, isMetered: true, sizeBytes: 900000),
        isTrue,
      );
    });

    test('desactive, le mode ne bloque rien', () {
      expect(
        off.allowsUpload(isProof: false, isMetered: true, sizeBytes: 900000),
        isTrue,
      );
    });

    test('active, une grosse charge attend une connexion non facturee', () {
      expect(
        on.allowsUpload(isProof: false, isMetered: true, sizeBytes: 900000),
        isFalse,
      );
      expect(
        on.allowsUpload(isProof: false, isMetered: false, sizeBytes: 900000),
        isTrue,
      );
    });

    test('une petite charge ne vaut pas une file d attente', () {
      expect(
        on.allowsUpload(
          isProof: false,
          isMetered: true,
          sizeBytes: EconomySettings.smallPayloadBytes,
        ),
        isTrue,
      );
    });

    test('le tour de serialisation conserve les reglages', () {
      const settings = EconomySettings(
        enabled: true,
        deferPhotosToWifi: false,
      );
      final restored = EconomySettings.fromJson(settings.toJson());

      expect(restored.enabled, isTrue);
      expect(restored.deferPhotosToWifi, isFalse);
      expect(restored.blockOnDemandTiles, isTrue);
    });
  });
}
