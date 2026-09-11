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
import 'package:majichrono/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/simulated_google_accounts.dart';
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/services/device_google_accounts.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

import '../../helpers/fake_secure_store.dart';

/// Entree acceleree par Google et code envoye par e-mail.
///
/// Ce que ces tests protegent tient en une phrase : **une adresse ne cree jamais
/// un compte**. Elle en ouvre un qui existe deja, ou elle renvoie vers le
/// numero. Un jour ou l'autre, quelqu'un trouvera plus simple d'ouvrir une
/// session directement apres le code e-mail — ces tests sont la pour que cette
/// simplification casse bruyamment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepositoryImpl repository;
  late String? pushedToken;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(AuthMockModule(random: Random(11)));

    final client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(
        backend: backend,
        profile: NetworkProfile.fourG,
        random: Random(11),
      ),
      accessTokenProvider: () => pushedToken,
    );

    pushedToken = null;
    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(client),
      local: AuthLocalDataSource(FakeSecureStore(), random: Random(11)),
      onAccessTokenChanged: (token) => pushedToken = token,
    );
  });

  Future<EmailVerification> enterWith(String email) async {
    final challenge = await repository.requestEmailCode(email);
    expect(challenge.debugCode, isNotNull);
    return repository.verifyEmailCode(
      challengeId: challenge.challengeId,
      code: challenge.debugCode!,
    );
  }

  group('detection des comptes', () {
    test('la source simulee propose des comptes exploitables', () async {
      const source = SimulatedGoogleAccounts();

      expect(await source.isAvailable(), isTrue);
      expect(await source.detect(), isNotEmpty);
    });

    test('la source neutre ne propose rien, donc aucun bouton', () async {
      // C'est le comportement du mode `live` tant que l'identifiant client OAuth
      // n'existe pas. L'ecran doit alors ne montrer que le numero.
      const source = NoGoogleAccounts();

      expect(await source.isAvailable(), isFalse);
      expect(await source.detect(), isEmpty);
    });

    test('un compte sans nom se presente par la partie locale de l adresse', () {
      const hint = GoogleAccountHint(email: 'visiteur.tana@gmail.com');

      expect(hint.label, 'visiteur.tana');
      expect(hint.initial, 'V');
    });
  });

  group('code par e-mail', () {
    test('une adresse invalide est refusee avant tout envoi', () async {
      await expectLater(
        repository.requestEmailCode('pas-une-adresse'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('la demande ne revele pas si l adresse est connue', () async {
      // Deux adresses, l'une rattachee et l'autre non : les deux reponses doivent
      // etre indiscernables, sinon ce point d'entree devient un moyen d'enumerer
      // les comptes.
      final known = await repository.requestEmailCode('hery.rakoto@gmail.com');
      final unknown = await repository.requestEmailCode('inconnu@gmail.com');

      expect(known.attemptsLeft, unknown.attemptsLeft);
      expect(known.debugCode!.length, unknown.debugCode!.length);
      expect(known.challengeId, isNot(unknown.challengeId));
    });

    test('un code faux consomme une tentative, puis brule le defi', () async {
      final challenge = await repository.requestEmailCode(
        'hery.rakoto@gmail.com',
      );

      Future<void> attempt() => repository.verifyEmailCode(
        challengeId: challenge.challengeId,
        code: '000000',
      );

      // Le simulateur tire un code a six chiffres : le risque que « 000000 »
      // soit le bon existe, mais la graine est fixee et le code ne l'est pas.
      expect(challenge.debugCode, isNot('000000'));

      await expectLater(attempt(), throwsA(isA<ValidationFailure>()));
      await expectLater(attempt(), throwsA(isA<ValidationFailure>()));
      await expectLater(attempt(), throwsA(isA<ValidationFailure>()));

      // Le defi n'existe plus : le bon code lui-meme ne l'ouvre plus.
      await expectLater(
        repository.verifyEmailCode(
          challengeId: challenge.challengeId,
          code: challenge.debugCode!,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un defi ne sert qu une fois', () async {
      final challenge = await repository.requestEmailCode(
        'hery.rakoto@gmail.com',
      );
      await repository.verifyEmailCode(
        challengeId: challenge.challengeId,
        code: challenge.debugCode!,
      );

      await expectLater(
        repository.verifyEmailCode(
          challengeId: challenge.challengeId,
          code: challenge.debugCode!,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('issue de la verification', () {
    test('une adresse rattachee ouvre la session sans SMS', () async {
      final result = await enterWith('hery.rakoto@gmail.com');

      expect(result, isA<EmailLinked>());
      final verification = (result as EmailLinked).verification;
      expect(verification.account, isA<AccountReady>());
      expect(
        (verification.account as AccountReady).account.phone.e164,
        '+261340000001',
        reason: 'la session ouverte est bien celle du compte rattache',
      );
      // Le jeton a ete pousse vers le client : la session est utilisable tout de
      // suite, exactement comme apres un OTP telephonique.
      expect(pushedToken, verification.session.accessToken);
    });

    test('une adresse inconnue ne cree aucun compte et n ouvre aucune session',
        () async {
      final result = await enterWith('visiteur.tana@gmail.com');

      expect(result, isA<EmailUnlinked>());
      expect((result as EmailUnlinked).email, 'visiteur.tana@gmail.com');
      expect(
        pushedToken,
        isNull,
        reason: 'aucun jeton ne doit circuler pour une adresse sans compte',
      );
      expect(await repository.currentSession(), isNull);
      expect(await repository.cachedAccount(), isNull);
    });
  });

  group('rattachement', () {
    test('une adresse verifiee se rattache au compte ouvert par le numero',
        () async {
      // Le parcours complet du nouvel utilisateur : l'adresse est prouvee mais
      // inconnue, il confirme son numero, et l'adresse est rattachee. La fois
      // suivante, le meme e-mail ouvre directement la session.
      expect(await enterWith('visiteur.tana@gmail.com'), isA<EmailUnlinked>());

      final phone = MalagasyPhone.tryParse('0341234567')!;
      final otp = await repository.requestOtp(phone);
      await repository.verifyOtp(
        challengeId: otp.challengeId,
        code: otp.debugCode!,
      );

      await repository.linkEmail('visiteur.tana@gmail.com');

      final second = await enterWith('visiteur.tana@gmail.com');
      expect(second, isA<EmailLinked>());
      expect(
        ((second as EmailLinked).verification.account as AccountProfilePending)
            .phone
            .e164,
        phone.e164,
      );
    });

    test('une adresse deja prise par un autre compte est refusee', () async {
      // Sinon un meme e-mail ouvrirait deux identites, et le prochain code recu
      // ne dirait plus laquelle.
      final phone = MalagasyPhone.tryParse('0341234567')!;
      final otp = await repository.requestOtp(phone);
      await repository.verifyOtp(
        challengeId: otp.challengeId,
        code: otp.debugCode!,
      );

      await expectLater(
        repository.linkEmail('hery.rakoto@gmail.com'),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('le rattachement exige une session', () async {
      await expectLater(
        repository.linkEmail('visiteur.tana@gmail.com'),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });
  });

  group('mot de passe', () {
    // Meme invariant que le reste du lot : une adresse ne cree jamais un
    // compte. L'inscription enregistre un mot de passe et rien d'autre ; le
    // compte n'existe qu'une fois le numero confirme.

    test('un compte pre-inscrit se connecte par mot de passe', () async {
      final result = await repository.signInWithPassword(
        email: 'hery.rakoto@gmail.com',
        password: AuthMockModule.seededPassword,
      );

      expect(result, isA<EmailLinked>());
      expect(pushedToken, isNotNull);

      // Le compte porte son adresse : sans elle, l'ecran de profil afficherait
      // « aucune adresse rattachee » a quelqu'un qui vient d'entrer par cette
      // adresse.
      final account =
          ((result as EmailLinked).verification.account as AccountReady).account;
      expect(account.email, 'hery.rakoto@gmail.com');
    });

    test('un mot de passe faux et une adresse inconnue echouent pareil',
        () async {
      // Repondre differemment dirait quelles adresses portent un compte.
      Future<Object?> outcome(String email, String password) async {
        try {
          await repository.signInWithPassword(email: email, password: password);
          return null;
        } on Failure catch (error) {
          return error.runtimeType;
        }
      }

      expect(
        await outcome('hery.rakoto@gmail.com', 'mauvais-mot-de-passe'),
        await outcome('personne@gmail.com', 'peu-importe'),
      );
      expect(pushedToken, isNull);
    });

    test('l inscription n ouvre aucune session', () async {
      final result = await repository.signUpWithPassword(
        email: 'nouveau@gmail.com',
        password: 'motdepasse123',
      );

      expect(result, isA<EmailUnlinked>());
      expect(pushedToken, isNull);
      expect(await repository.currentSession(), isNull);
    });

    test('un mot de passe trop court est refuse', () async {
      await expectLater(
        repository.signUpWithPassword(
          email: 'court@gmail.com',
          password: 'abc',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('une adresse deja inscrite est refusee', () async {
      await expectLater(
        repository.signUpWithPassword(
          email: 'hery.rakoto@gmail.com',
          password: 'motdepasse123',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('inscription puis numero : la connexion suivante ouvre la session',
        () async {
      await repository.signUpWithPassword(
        email: 'nouveau@gmail.com',
        password: 'motdepasse123',
      );

      final phone = MalagasyPhone.tryParse('0341234567')!;
      final otp = await repository.requestOtp(phone);
      await repository.verifyOtp(
        challengeId: otp.challengeId,
        code: otp.debugCode!,
      );
      await repository.linkEmail('nouveau@gmail.com');

      final second = await repository.signInWithPassword(
        email: 'nouveau@gmail.com',
        password: 'motdepasse123',
      );
      expect(second, isA<EmailLinked>());
    });
  });
}
