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
import 'package:majichrono/core/network/network_profile.dart';

/// Le transport simule est la fondation de toute la recette hors ligne du
/// §16.2. S'il ment sur l'etat du reseau, les scenarios 1, 3 et 7 ne prouvent
/// rien. Ces tests verifient qu'il se comporte comme un vrai socle reseau.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ApiClient> buildClient({
    NetworkProfile profile = NetworkProfile.fourG,
    double failureRate = 0,
    int randomSeed = 42,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()..register(CoreMockModule());
    return ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      // Le seed fige l'aleatoire : un test de coupure reste reproductible.
      mockAdapter: MockHttpAdapter(
        backend: backend,
        profile: profile,
        failureRate: failureRate,
        random: Random(randomSeed),
      ),
    );
  }

  test('hors ligne : aucune requete n aboutit et l erreur est typee', () async {
    final client = await buildClient(profile: NetworkProfile.offline);

    await expectLater(
      client.get<Map<String, dynamic>>(ApiEndpoints.health),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('en ligne : la route de sante repond et la sonde mesure un RTT', () async {
    final client = await buildClient();

    final body = await client.get<Map<String, dynamic>>(ApiEndpoints.health);
    expect(body['status'], 'ok');
    expect(await client.probe(), isNotNull);
  });

  test('hors ligne : la sonde retourne null, pas une exception', () async {
    final client = await buildClient(profile: NetworkProfile.offline);
    expect(await client.probe(), isNull);
  });

  test('2G : la latence simulee depasse largement celle de la 4G', () async {
    final fast = await buildClient();
    final slow = await buildClient(profile: NetworkProfile.twoG);

    final fastRtt = await fast.probe();
    final slowRtt = await slow.probe();

    expect(slowRtt!, greaterThan(fastRtt!));
    // Le profil mesure doit etre qualifie 2G, ce qui pilote la cadence de suivi
    // a 45 s (EXI-C20).
    expect(NetworkProfile.fromRttMs(slowRtt), NetworkProfile.twoG);
  });

  test('route inconnue : 404 au format d erreur du §12.1', () async {
    final client = await buildClient();

    await expectLater(
      client.get<Map<String, dynamic>>('/inexistant'),
      throwsA(
        isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('taux d echec injecte a 100 % : toute requete coupe', () async {
    final client = await buildClient(failureRate: 1);

    await expectLater(
      client.get<Map<String, dynamic>>(ApiEndpoints.health),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('le compteur de donnees enregistre les octets echanges (EXI-T07)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final meter = DataMeter(prefs);
    final backend = MockBackend()..register(CoreMockModule());
    final client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: meter,
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(backend: backend),
    );

    expect(meter.total, 0);
    await client.get<Map<String, dynamic>>(ApiEndpoints.health);
    expect(meter.totalFor(DataCategory.api), greaterThan(0));
  });
}
