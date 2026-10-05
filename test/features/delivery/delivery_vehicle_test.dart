import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/auth/presentation/widgets/malagasy_phone_formatter.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_vehicle.dart';
import 'package:majichrono/features/delivery/domain/entities/majunga_places.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';

MockRequest _req(String method, String path, [Map<String, dynamic>? body]) =>
    MockRequest(
      method: method,
      path: path,
      query: const {},
      headers: const {},
      body: body ?? <String, dynamic>{},
    );

TextEditingValue _type(String text, {int? cursor}) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

PriceEstimate _quote(DeliveryVehicle vehicle, double km) =>
    vehicle.tariff.estimate(
      straightLineKm: km,
      kind: DeliveryKind.standard,
      weight: WeightCategory.upTo2,
      slot: const PickupSlot.immediate(),
    );

void main() {
  group('saisie du numero', () {
    const formatter = MalagasyPhoneFormatter();

    test('les espaces se posent seuls : 34 12 345 67', () {
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _type('341234567'),
      );
      expect(out.text, '34 12 345 67');
      expect(out.selection.baseOffset, out.text.length);
    });

    test('un numero colle en 034, +261 ou 00261 est ramene aux 9 chiffres', () {
      for (final pasted in [
        '034 12 345 67',
        '+261 34 12 345 67',
        '00261341234567',
        '0341234567',
      ]) {
        expect(
          formatter
              .formatEditUpdate(TextEditingValue.empty, _type(pasted))
              .text,
          '34 12 345 67',
          reason: pasted,
        );
      }
    });

    test('le retour arriere juste apres un espace efface le chiffre', () {
      const before = TextEditingValue(
        text: '34 1',
        selection: TextSelection.collapsed(offset: 3),
      );
      final out = formatter.formatEditUpdate(before, _type('341', cursor: 2));
      expect(out.text, '31');
      expect(out.selection.baseOffset, 1);
    });

    test('au-dela de neuf chiffres, la saisie est tronquee', () {
      expect(
        formatter
            .formatEditUpdate(TextEditingValue.empty, _type('3412345678999'))
            .text,
        '34 12 345 67',
      );
    });
  });

  group('vehicule selon la taille du colis', () {
    test('une moto ne porte pas plus de 15 kg', () {
      expect(DeliveryVehicle.moto.canCarry(WeightCategory.from5to15), isTrue);
      expect(DeliveryVehicle.moto.canCarry(WeightCategory.over15), isFalse);
      for (final v in DeliveryVehicle.values.skip(1)) {
        expect(v.canCarry(WeightCategory.over15), isTrue, reason: v.name);
      }
    });

    test('le vehicule propose est le moins cher qui convient', () {
      expect(
        DeliveryVehicle.suggestedFor(WeightCategory.upTo2),
        DeliveryVehicle.moto,
      );
      expect(
        DeliveryVehicle.suggestedFor(WeightCategory.over15),
        DeliveryVehicle.tricycle,
      );
    });

    test('la moto garde la grille publique historique', () {
      final moto = _quote(DeliveryVehicle.moto, 3);
      final legacy = TariffGrid.provisional.estimate(
        straightLineKm: 3,
        kind: DeliveryKind.standard,
        weight: WeightCategory.upTo2,
        slot: const PickupSlot.immediate(),
      );
      expect(moto.totalAriary, legacy.totalAriary);
    });

    test('le prix monte avec la taille du vehicule', () {
      final prices = [
        for (final v in DeliveryVehicle.values) _quote(v, 3).totalAriary,
      ];
      expect(prices, orderedEquals([...prices]..sort()));
      expect(prices.toSet(), hasLength(4));
    });

    test('meme formule que le serveur (DeliveryFare) : 3 km en moto', () {
      // 2 000 + 3 x 800 = 4 400 Ar.
      expect(_quote(DeliveryVehicle.moto, 3).totalAriary, 4400);
      // Camionnette : 15 000 + 3 x 2 500 = 22 500 Ar.
      expect(_quote(DeliveryVehicle.van, 3).totalAriary, 22500);
    });

    test('le vehicule voyage avec la course', () {
      final json = {
        'id': 'd1',
        'status': 'en_attente',
        'pickup': {
          'point': {'lat': -15.71, 'lng': 46.3285},
          'district': 'Mahabibo',
          'landmark': 'Bazary Be',
          'contactPhone': '+261341234567',
        },
        'dropoff': {
          'point': {'lat': -15.7224, 'lng': 46.3108},
          'district': 'Bord de mer',
          'landmark': 'Le Baobab',
          'contactPhone': '+261341234567',
        },
        'vehicle': 'tricycle',
      };
      final delivery = Delivery.fromJson(json)!;
      expect(delivery.vehicle, DeliveryVehicle.tricycle);
      expect(delivery.toJson()['vehicle'], 'tricycle');
    });
  });

  test('les lieux connus sont tous dans la zone desservie de Majunga', () {
    for (final place in MajungaZone.places) {
      expect(MajungaZone.contains(place.point), isTrue, reason: place.name);
    }
    expect(MajungaZone.search('bazar').single.id, 'bazary_be');
  });

  test('inscription puis connexion par numero, sans SMS', () async {
    final backend = MockBackend()..register(AuthMockModule());
    const phone = '+261341112233';
    const password = 'majunga2026';

    Future<int> call(String path, String pwd) async => (await backend.handle(
      _req('POST', path, {'phone': phone, 'password': pwd}),
    )).statusCode;

    expect(await call('/auth/phone/login', password), 404);
    expect(await call('/auth/phone/register', password), 201);
    expect(await call('/auth/phone/register', password), 409);
    expect(await call('/auth/phone/login', 'mauvais'), 401);
    expect(await call('/auth/phone/login', password), 200);
  });
}
