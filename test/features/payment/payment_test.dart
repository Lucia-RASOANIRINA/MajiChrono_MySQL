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
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/payment/data/mock/payment_mock_module.dart';
import 'package:majichrono/features/payment/data/payment_repository.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';

/// Paiement adosse aux soldes MajiPay, conduit dans MajiChrono (§11.2).
///
/// Le controle central de ce module tient en une phrase : **scanner n'autorise
/// jamais un debit**. Le scan apparie deux appareils ; celui qui paie confirme
/// sur le sien. Sans ce controle, quiconque scanne un code affiche par un tiers
/// pourrait se servir sur son compte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PaymentRepository repository;
  late PaymentMockModule payments;

  Future<void> build({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    payments = PaymentMockModule(random: Random(4));
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(payments);

    repository = PaymentRepository(
      client: ApiClient(
        config: AppConfig.fromEnvironment(),
        dataMeter: DataMeter(prefs),
        mockBackend: backend,
        mockAdapter: MockHttpAdapter(
          backend: backend,
          profile: profile,
          random: Random(11),
        ),
      ),
    );
  }

  setUp(build);

  Future<PaymentIntent> intent({
    PaymentDirection direction = PaymentDirection.collect,
    int amount = 7500,
    UserRole role = UserRole.driver,
  }) => repository.createIntent(
    deliveryId: 'dlv_77',
    amountAriary: amount,
    direction: direction,
    role: role,
  );

  ScannedPayment scanOf(PaymentIntent i) =>
      PaymentQr.parse(i.qrPayload)!;

  group('contenu du code QR', () {
    test('il ne porte que l identifiant et le jeton', () async {
      // Ni montant, ni nom, ni numero de compte : un code photographie a
      // distance ne doit rien reveler.
      final created = await intent(amount: 7500);

      expect(created.qrPayload, contains(created.id));
      expect(created.qrPayload, isNot(contains('7500')));
      expect(created.qrPayload, isNot(contains('Client')));
      expect(created.qrPayload, isNot(contains('MP ')));
    });

    test('un code etranger n est pas accepte', () async {
      // Une etiquette de colis, un code Wi-Fi, une publicite : un scanneur qui
      // accepterait n'importe quoi enverrait des identifiants inconnus au
      // serveur.
      expect(PaymentQr.parse('WIFI:S:Tsiky;T:WPA;P:motdepasse;;'), isNull);
      expect(PaymentQr.parse('https://exemple.mg/pay?i=1&t=2'), isNull);
      expect(PaymentQr.parse('majichrono://autre?i=1&t=2'), isNull);
      expect(PaymentQr.parse('majichrono://pay?i=pay_1'), isNull, reason: 'jeton absent');
      expect(PaymentQr.parse(''), isNull);
      expect(PaymentQr.parse(null), isNull);
    });

    test('un code MajiChrono valide est reconnu', () async {
      final created = await intent();
      final scanned = PaymentQr.parse(created.qrPayload);

      expect(scanned, isNotNull);
      expect(scanned!.intentId, created.id);
      expect(scanned.token, isNotEmpty);
    });
  });

  group('demande d encaissement : le livreur presente, le client scanne', () {
    test('le scan seul ne debite rien', () async {
      // C'est la regle qui protege tout le module. L'appariement revele le
      // montant au payeur ; il ne prend pas son argent.
      final created = await intent(direction: PaymentDirection.collect);
      final before = await repository.balance(UserRole.client);

      final claimed = await repository.claim(scanOf(created));

      expect(claimed.status, PaymentStatus.claimed);
      expect(claimed.status.settles, isFalse);

      final after = await repository.balance(UserRole.client);
      expect(after!.availableAriary, before!.availableAriary);
    });

    test('la confirmation du payeur deplace l argent', () async {
      final created = await intent(amount: 7500);
      final clientBefore = (await repository.balance(UserRole.client))!;
      final driverBefore = (await repository.balance(UserRole.driver))!;

      await repository.claim(scanOf(created));
      final settled = await repository.confirm(created.id);

      expect(settled.status, PaymentStatus.captured);
      expect(settled.receiptRef, isNotNull);

      final clientAfter = (await repository.balance(UserRole.client))!;
      final driverAfter = (await repository.balance(UserRole.driver))!;
      expect(clientAfter.availableAriary, clientBefore.availableAriary - 7500);
      expect(driverAfter.availableAriary, driverBefore.availableAriary + 7500);
    });

    test('un jeton faux n apparie rien', () async {
      final created = await intent();

      await expectLater(
        repository.claim(
          ScannedPayment(intentId: created.id, token: 'faux'),
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('offre de paiement : le client presente, le livreur scanne', () {
    test('le scan encaisse, parce que le payeur a deja consenti', () async {
      // Le client a saisi son code avant d'afficher le sien : l'accord est
      // anterieur au scan, l'invariant tient toujours.
      final created = await intent(
        direction: PaymentDirection.offer,
        amount: 5000,
        role: UserRole.client,
      );
      expect(created.direction.payerPreAuthorized, isTrue);

      final settled = await repository.claim(scanOf(created));

      expect(settled.status, PaymentStatus.captured);
    });

    test('une offre superieure au solde est refusee des la creation', () async {
      // Afficher un code que personne ne pourra encaisser ferait perdre du
      // temps aux deux parties devant la porte.
      await expectLater(
        intent(
          direction: PaymentDirection.offer,
          amount: 999999,
          role: UserRole.client,
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('idempotence stricte (EXI-MP06)', () {
    test('deux confirmations ne produisent qu un debit', () async {
      final created = await intent(amount: 7500);
      final before = (await repository.balance(UserRole.client))!;

      await repository.claim(scanOf(created));
      await repository.confirm(created.id);
      await repository.confirm(created.id);

      final after = (await repository.balance(UserRole.client))!;
      expect(after.availableAriary, before.availableAriary - 7500);
    });

    test('rescanner une intention reglee ne redebite pas', () async {
      final created = await intent(
        direction: PaymentDirection.offer,
        role: UserRole.client,
        amount: 5000,
      );
      await repository.claim(scanOf(created));
      final after = (await repository.balance(UserRole.client))!;

      final again = await repository.claim(scanOf(created));

      expect(again.status, PaymentStatus.captured);
      expect(
        (await repository.balance(UserRole.client))!.availableAriary,
        after.availableAriary,
      );
    });

    test('deux appuis sur encaisser ne creent qu une intention', () async {
      // La cle est derivee de la course et du sens : un second code
      // encaissable pour la meme course serait un doublon en circulation.
      final first = await intent();
      final second = await intent();

      expect(second.id, first.id);
    });
  });

  group('solde insuffisant et repli especes (EXI-MP08, EXI-C43)', () {
    test('une confirmation au-dela du solde echoue sans debiter', () async {
      final created = await intent(amount: 999999);
      final before = (await repository.balance(UserRole.client))!;

      await repository.claim(scanOf(created));
      await expectLater(
        repository.confirm(created.id),
        throwsA(isA<Failure>()),
      );

      expect(
        (await repository.balance(UserRole.client))!.availableAriary,
        before.availableAriary,
      );
    });

    test('le repli especes reste possible apres l echec', () async {
      // Une course bloquee parce qu'un solde est insuffisant serait un colis
      // immobilise pour une raison qui ne regarde ni le livreur ni le
      // destinataire.
      final created = await intent(amount: 999999);
      await repository.claim(scanOf(created));
      await expectLater(repository.confirm(created.id), throwsA(isA<Failure>()));

      final cash = await repository.fallbackToCash(created.id);

      expect(cash.status, PaymentStatus.cash);
      expect(cash.status.settles, isTrue, reason: 'la course peut avancer');
      expect(cash.receiptRef, isNotNull);
    });

    test('le repli especes est refuse apres un encaissement MajiPay', () async {
      // Sinon la course serait reglee deux fois : une en monnaie, une en
      // solde.
      final created = await intent(amount: 5000);
      await repository.claim(scanOf(created));
      await repository.confirm(created.id);

      await expectLater(
        repository.fallbackToCash(created.id),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('les especes restent disponibles sans avoir rien tente', () async {
      final created = await intent();

      final cash = await repository.fallbackToCash(created.id);
      expect(cash.status, PaymentStatus.cash);
    });
  });

  group('hors ligne', () {
    test('aucune intention ne peut etre creee sans reseau', () async {
      // Le paiement par solde exige que le serveur arbitre. C'est precisement
      // pour cela que le repli especes existe.
      await build(profile: NetworkProfile.offline);

      await expectLater(intent(), throwsA(isA<Failure>()));
    });
  });

  group('etats', () {
    test('un etat final arrete le sondage (EXI-MP05)', () {
      expect(PaymentStatus.pending.isFinal, isFalse);
      expect(PaymentStatus.claimed.isFinal, isFalse);
      expect(PaymentStatus.captured.isFinal, isTrue);
      expect(PaymentStatus.failed.isFinal, isTrue);
      expect(PaymentStatus.cash.isFinal, isTrue);
    });

    test('seuls la capture et les especes reglent la course', () {
      expect(PaymentStatus.captured.settles, isTrue);
      expect(PaymentStatus.cash.settles, isTrue);
      expect(PaymentStatus.claimed.settles, isFalse);
      expect(PaymentStatus.failed.settles, isFalse);
    });

    test('tout echec ouvre la voie aux especes', () {
      expect(PaymentFailure.insufficientFunds.suggestsCash, isTrue);
      expect(PaymentFailure.expired.suggestsCash, isTrue);
      expect(PaymentFailure.declined.suggestsCash, isTrue);
      expect(PaymentFailure.none.suggestsCash, isFalse);
    });
  });

  group('confidentialite (EXI-MP11)', () {
    test('le solde ne montre qu une reference masquee', () async {
      final balance = await repository.balance(UserRole.client);

      expect(balance!.accountRef, contains('**'));
      expect(balance.accountRef, isNot(matches(RegExp(r'\d{6,}'))));
    });

    test('la lecture d une intention ne rend jamais le jeton', () async {
      // Il n'est servi qu'une fois, a la creation, et seulement a celui qui
      // presente le code.
      final created = await intent();

      final read = await repository.status(created.id);
      expect(read.token, isNull);
      expect(created.token, isNotNull);
    });
  });
}
