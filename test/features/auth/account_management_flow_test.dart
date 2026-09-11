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
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

import '../../helpers/fake_secure_store.dart';

/// Gestion du compte cote application, a travers la pile reelle (client Dio,
/// intercepteurs, transport simule) : mot de passe, changement d'e-mail et de
/// numero, photo. On verifie que le mobile enchaine correctement les deux temps
/// (demande de code puis confirmation) et adopte le compte a jour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepositoryImpl repository;
  late FakeSecureStore store;
  String? pushedToken;

  Future<void> setUpRepository() async {
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
        profile: NetworkProfile.fourG,
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
    client.attachRefreshHandler(
      () async => (await repository.refresh()).accessToken,
    );
  }

  setUp(setUpRepository);

  // Compte de recette pre-inscrit : role client + adresse rattachee + mot de
  // passe `majichrono`.
  const seededPhone = '+261340000001';
  const seededEmail = 'hery.rakoto@gmail.com';

  Future<void> signIn(String number) async {
    final phone = MalagasyPhone.tryParse(number)!;
    final challenge = await repository.requestOtp(phone);
    await repository.verifyOtp(
      challengeId: challenge.challengeId,
      code: challenge.debugCode!,
    );
  }

  group('mot de passe', () {
    test('le change avec l ancien correct', () async {
      await signIn(seededPhone);
      await repository.changePassword(
        currentPassword: 'majichrono',
        newPassword: 'nouveau123',
      );
      // Le nouveau mot de passe ouvre une session.
      final outcome = await repository.signInWithPassword(
        email: seededEmail,
        password: 'nouveau123',
      );
      expect(outcome, isA<EmailLinked>());
    });

    test('refuse un ancien mot de passe faux', () async {
      await signIn(seededPhone);
      await expectLater(
        repository.changePassword(
          currentPassword: 'faux',
          newPassword: 'nouveau123',
        ),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });

    test('oublie : repose le mot de passe via le code e-mail', () async {
      final challenge = await repository.requestEmailCode(seededEmail);
      await repository.resetPassword(
        challengeId: challenge.challengeId,
        code: challenge.debugCode!,
        newPassword: 'repose123',
      );
      final outcome = await repository.signInWithPassword(
        email: seededEmail,
        password: 'repose123',
      );
      expect(outcome, isA<EmailLinked>());
    });
  });

  group('changement de contact', () {
    test('l adresse e-mail apres verification du code', () async {
      await signIn(seededPhone);
      final challenge = await repository.requestEmailChange('neuf@example.com');
      final account = await repository.confirmEmailChange(
        challengeId: challenge.challengeId,
        code: challenge.debugCode!,
      );
      expect(account.email, 'neuf@example.com');
    });

    test('le numero apres verification du SMS', () async {
      await signIn(seededPhone);
      final challenge = await repository.requestPhoneChange(
        MalagasyPhone.tryParse('+261340009999')!,
      );
      final account = await repository.confirmPhoneChange(
        challengeId: challenge.challengeId,
        code: challenge.debugCode!,
      );
      expect(account.phone.e164, '+261340009999');
    });
  });

  group('photo de profil', () {
    test('pose puis retire la photo', () async {
      await signIn(seededPhone);
      final withPhoto = await repository.uploadAvatar(
        bytes: const [1, 2, 3, 4],
        contentType: 'image/png',
      );
      expect(withPhoto.avatarUrl, isNotNull);
      expect(withPhoto.avatarUrl!.startsWith('data:image/png'), isTrue);

      final without = await repository.deleteAvatar();
      expect(without.avatarUrl, isNull);
    });
  });

  group('nom et prenom', () {
    test('met a jour prenom et nom, et recompose le nom d usage', () async {
      await signIn(seededPhone);
      final account = await repository.updateName(
        firstName: 'Rina',
        lastName: 'Rakoto',
      );
      expect(account.firstName, 'Rina');
      expect(account.lastName, 'Rakoto');
      expect(account.displayName, 'Rina Rakoto');
    });
  });

  group('sessions actives', () {
    test('liste les appareils, marque le courant et en revoque un', () async {
      await signIn(seededPhone); // premiere session
      await signIn(seededPhone); // seconde session, devient la courante

      final sessions = await repository.listSessions();
      expect(sessions.length, 2);
      expect(sessions.where((s) => s.isCurrent).length, 1);

      final other = sessions.firstWhere((s) => !s.isCurrent);
      await repository.revokeSession(other.id);

      final after = await repository.listSessions();
      expect(after.length, 1);
      expect(after.first.isCurrent, isTrue);
    });
  });
}
