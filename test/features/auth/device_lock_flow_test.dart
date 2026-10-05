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
import 'package:majichrono/features/auth/data/device_lock.dart';
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

import '../../helpers/fake_secure_store.dart';

/// Entree par numero **sans SMS** : le verrouillage du telephone (code,
/// schema, empreinte, visage) libere une cle d'appareil que le serveur
/// reconnait.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepositoryImpl repository;
  late FakeSecureStore store;
  late DeviceKeyStore keys;
  late String? pushedToken;
  final phone = MalagasyPhone.tryParse('034 11 122 33')!;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(AuthMockModule(random: Random(5)));
    final client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(
        backend: backend,
        profile: NetworkProfile.fourG,
        random: Random(5),
      ),
      accessTokenProvider: () => pushedToken,
    );
    pushedToken = null;
    store = FakeSecureStore();
    keys = DeviceKeyStore(store, random: Random(5));
    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(client),
      local: AuthLocalDataSource(store, random: Random(5)),
      onAccessTokenChanged: (token) => pushedToken = token,
    );
  });

  test(
    'inscription puis connexion par la cle, sans SMS ni mot de passe',
    () async {
      final secret = await keys.createFor(phone.e164);
      expect(secret.length, greaterThanOrEqualTo(40));

      final created = await repository.registerWithPhone(
        phone: phone,
        deviceSecret: secret,
      );
      expect(created.session.accessToken, isNotEmpty);

      // La deconnexion efface la session, pas la cle de ce telephone.
      await store.wipe();
      expect(await keys.secretFor(phone.e164), secret);

      final result = await repository.loginWithPhone(
        phone: phone,
        deviceSecret: secret,
      );
      expect(result, isA<PhonePasswordVerified>());
    },
  );

  test('un autre telephone est refuse avec un code explicite', () async {
    await repository.registerWithPhone(
      phone: phone,
      deviceSecret: await keys.createFor(phone.e164),
    );

    await expectLater(
      repository.loginWithPhone(phone: phone, deviceSecret: 'x' * 43),
      throwsA(
        isA<UnauthorizedFailure>().having(
          (f) => f.code,
          'code',
          'device_not_recognized',
        ),
      ),
    );
  });

  test(
    'un nouveau telephone se lie apres le mot de passe de secours',
    () async {
      await repository.registerWithPhone(
        phone: phone,
        password: 'majunga2026',
        deviceSecret: await keys.createFor(phone.e164),
      );

      final login = await repository.loginWithPhone(
        phone: phone,
        password: 'majunga2026',
      );
      expect(login, isA<PhonePasswordVerified>());

      final newKey = 'n' * 43;
      await repository.enrollDevice(newKey);
      expect(
        await repository.loginWithPhone(phone: phone, deviceSecret: newKey),
        isA<PhonePasswordVerified>(),
      );
    },
  );

  test('il faut au moins une preuve pour creer le compte', () async {
    await expectLater(
      repository.registerWithPhone(phone: phone),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
