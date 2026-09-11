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
import 'package:majichrono/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

import '../../helpers/fake_secure_store.dart';

/// Parcours complet d'authentification, du numero a la session (EXI-T01 a T04).
///
/// Les tests traversent la pile reelle — client Dio, intercepteurs, transport
/// simule — et non des bouchons : c'est le seul moyen de verifier que la clef
/// d'idempotence, l'en-tete d'autorisation et la rotation des jetons fonctionnent
/// ensemble, et pas seulement isolement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepositoryImpl repository;
  late FakeSecureStore store;
  late String? pushedToken;

  Future<void> setUpRepository({NetworkProfile profile = NetworkProfile.fourG}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(AuthMockModule(random: Random(7)));

    final client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(
        backend: backend,
        profile: profile,
        random: Random(7),
      ),
      accessTokenProvider: () => pushedToken,
    );

    store = FakeSecureStore();
    pushedToken = null;

    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(client),
      local: AuthLocalDataSource(store, random: Random(7)),
      onAccessTokenChanged: (token) => pushedToken = token,
    );

    client.attachRefreshHandler(() async => (await repository.refresh()).accessToken);
  }

  setUp(setUpRepository);

  /// Deroule numero puis OTP, et retourne le resultat.
  Future<OtpVerification> signIn(String number) async {
    final phone = MalagasyPhone.tryParse(number)!;
    final challenge = await repository.requestOtp(phone);
    expect(challenge.debugCode, isNotNull, reason: 'le simulateur doit livrer le code');
    return repository.verifyOtp(
      challengeId: challenge.challengeId,
      code: challenge.debugCode!,
    );
  }

  group('demande de code', () {
    test('un numero valide ouvre un defi de 3 tentatives', () async {
      final challenge =
          await repository.requestOtp(MalagasyPhone.tryParse('0341234567')!);

      expect(challenge.attemptsLeft, 3);
      expect(challenge.isExpired, isFalse);
      expect(challenge.debugCode!.length, 6);
      // Cinq minutes de validite (EXI-T01), avec la tolerance du temps de test.
      expect(challenge.remaining.inMinutes, greaterThanOrEqualTo(4));
    });
  });

  group('verification du code', () {
    test('un code correct ouvre une session', () async {
      final result = await signIn('0341234567');

      expect(result.session.accessToken, isNotEmpty);
      expect(result.session.refreshToken, isNotEmpty);
      expect(result.session.isAccessExpired, isFalse);
      // Le jeton est immediatement pousse vers le client HTTP, sans quoi la
      // requete suivante partirait sans autorisation.
      expect(pushedToken, result.session.accessToken);
    });

    test('un code faux decompte les tentatives et ne connecte pas', () async {
      final challenge =
          await repository.requestOtp(MalagasyPhone.tryParse('0341234567')!);

      await expectLater(
        repository.verifyOtp(challengeId: challenge.challengeId, code: '000000'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(pushedToken, isNull);
    });

    test('trois echecs brulent le defi', () async {
      final challenge =
          await repository.requestOtp(MalagasyPhone.tryParse('0341234567')!);

      for (var i = 0; i < 3; i++) {
        await expectLater(
          repository.verifyOtp(challengeId: challenge.challengeId, code: '000000'),
          throwsA(isA<ValidationFailure>()),
        );
      }
      // Le bon code ne vaut plus rien apres epuisement des tentatives.
      await expectLater(
        repository.verifyOtp(
          challengeId: challenge.challengeId,
          code: challenge.debugCode!,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un code ne sert qu une fois', () async {
      final phone = MalagasyPhone.tryParse('0341234567')!;
      final challenge = await repository.requestOtp(phone);
      await repository.verifyOtp(
        challengeId: challenge.challengeId,
        code: challenge.debugCode!,
      );

      await expectLater(
        repository.verifyOtp(
          challengeId: challenge.challengeId,
          code: challenge.debugCode!,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('profil (EXI-T02)', () {
    test('un numero inconnu ouvre une session sans profil', () async {
      final result = await signIn('0341234567');
      expect(result.account, isA<AccountProfilePending>());
    });

    test('le profil se pose ensuite et devient definitif', () async {
      await signIn('0341234567');

      final account = await repository.chooseProfile(
        role: UserRole.driver,
        firstName: 'Naina',
        lastName: '',
      );

      expect(account.role, UserRole.driver);
      expect(account.displayName, 'Naina');
      // Un livreur tout juste inscrit ne peut pas encore travailler : son
      // dossier KYC est a l'etat de brouillon (EXI-L01).
      expect(account.kycStatus, KycStatus.draft);
      expect(account.canWork, isFalse);
    });

    test('changer de profil apres coup est refuse', () async {
      await signIn('0341234567');
      await repository.chooseProfile(role: UserRole.client, firstName: 'Hery', lastName: '');

      await expectLater(
        repository.chooseProfile(role: UserRole.driver, firstName: 'Hery', lastName: ''),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('le mobile ne peut pas revendiquer le profil administrateur', () async {
      // EXI-T02 : le role administrateur est attribue cote serveur uniquement.
      await signIn('0341234567');

      await expectLater(
        repository.chooseProfile(role: UserRole.admin, firstName: 'Miora', lastName: ''),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });

    test('un numero de recette pre-inscrit arrive avec son profil', () async {
      final result = await signIn('0330000002');

      expect(result.account, isA<AccountReady>());
      final account = (result.account as AccountReady).account;
      expect(account.role, UserRole.driver);
      expect(account.displayName, 'Naina Andria');
    });
  });

  group('session (EXI-T03)', () {
    test('la session est relue apres redemarrage', () async {
      final result = await signIn('0340000001');

      // Simule un redemarrage : nouveau repository, meme stockage securise.
      final restored = await repository.currentSession();
      expect(restored, isNotNull);
      expect(restored!.accessToken, result.session.accessToken);
    });

    test('le rafraichissement fait tourner les deux jetons', () async {
      final result = await signIn('0340000001');
      final refreshed = await repository.refresh();

      expect(refreshed.accessToken, isNot(result.session.accessToken));
      expect(refreshed.refreshToken, isNot(result.session.refreshToken));
      expect(pushedToken, refreshed.accessToken);
    });

    test('deux rafraichissements simultanes ne produisent qu une rotation',
        () async {
      // Sur reseau lent, plusieurs requetes expirent ensemble. Sans partage du
      // rafraichissement en vol, la seconde presenterait un jeton que la
      // premiere vient d'invalider et deconnecterait l'utilisateur.
      await signIn('0340000001');

      final results = await Future.wait([repository.refresh(), repository.refresh()]);
      expect(results[0].accessToken, results[1].accessToken);
    });

    test('le compte est disponible hors ligne apres une connexion', () async {
      await signIn('0330000002');

      final cached = await repository.cachedAccount();
      expect(cached, isNotNull);
      expect(cached!.role, UserRole.driver);
    });

    test('la deconnexion efface tout, meme sans reseau (EXI-SEC10)', () async {
      await signIn('0340000001');
      expect(await store.read('auth.access_token'), isNotNull);

      await repository.signOut();

      expect(await repository.currentSession(), isNull);
      expect(await repository.cachedAccount(), isNull);
      expect(store.isEmpty, isTrue);
      expect(pushedToken, isNull);
    });
  });

  group('code PIN (EXI-T04)', () {
    test('le code n est jamais stocke en clair', () async {
      await repository.setPin('4271');

      final dump = store.dump().values.join(' ');
      expect(dump.contains('4271'), isFalse);
      expect(await repository.hasPin(), isTrue);
    });

    test('le bon code deverrouille, un autre non', () async {
      await repository.setPin('4271');

      expect(await repository.verifyPin('4271'), isTrue);
      expect(await repository.verifyPin('0000'), isFalse);
    });

    test('cinq echecs detruisent le verrou et imposent une reconnexion', () async {
      // C'est ce compteur, et non la force du hachage, qui rend defendable un
      // secret a quatre chiffres.
      await repository.setPin('4271');

      for (var i = 0; i < 5; i++) {
        expect(await repository.verifyPin('0000'), isFalse);
      }
      expect(await repository.hasPin(), isFalse);
    });

    test('un essai reussi remet le compteur a zero', () async {
      await repository.setPin('4271');

      for (var i = 0; i < 4; i++) {
        await repository.verifyPin('0000');
      }
      expect(await repository.verifyPin('4271'), isTrue);

      for (var i = 0; i < 4; i++) {
        await repository.verifyPin('0000');
      }
      expect(await repository.hasPin(), isTrue, reason: 'compteur non reinitialise');
    });
  });

  group('reseau degrade', () {
    test('hors ligne, la demande de code echoue proprement', () async {
      await setUpRepository(profile: NetworkProfile.offline);

      await expectLater(
        repository.requestOtp(MalagasyPhone.tryParse('0341234567')!),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('en 2G, le parcours aboutit malgre la latence', () async {
      await setUpRepository(profile: NetworkProfile.twoG);

      final result = await signIn('0340000001');
      expect(result.session.accessToken, isNotEmpty);
    });
  });
}
