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
import 'package:majichrono/features/driver/data/mock/driver_mock_module.dart';

/// Dossier KYC cote livreur, a travers la pile reelle (client + transport
/// simule). On protege la porte : le dossier ne se soumet que **complet**, et
/// l'avancement suit les pieces deposees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient client;

  Future<void> build() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final deliveryModule = DeliveryMockModule(random: Random(3));
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(deliveryModule)
      ..register(
        DriverMockModule(
          deliveries: () => deliveryModule.store,
          random: Random(3),
        ),
      );

    client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(backend: backend, random: Random(3)),
    );
  }

  setUp(build);

  const kinds = [
    'cin_front',
    'cin_back',
    'licence',
    'selfie',
    'registration',
    'vehicle',
    'plate',
  ];

  // PNG 1x1.
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  Future<Map<String, dynamic>> status() =>
      client.get<Map<String, dynamic>>(ApiEndpoints.kycStatus);

  Future<void> upload(String kind) => client.post<Map<String, dynamic>>(
    ApiEndpoints.kycDocument(kind),
    body: {'imageBase64': png, 'contentType': 'image/png'},
  );

  test('l avancement suit les pieces deposees', () async {
    await upload('cin_front');
    await upload('selfie');
    final s = await status();
    expect((s['uploaded'] as List).toSet(), {'cin_front', 'selfie'});
    expect(s['missing'] as List, contains('licence'));
  });

  test('un dossier incomplet ne se soumet pas', () async {
    await upload('cin_front');
    await expectLater(
      client.post<Map<String, dynamic>>(ApiEndpoints.kycSubmit),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('un dossier complet passe en verification', () async {
    for (final kind in kinds) {
      await upload(kind);
    }
    final s = await status();
    expect((s['uploaded'] as List).length, 7);

    final result = await client.post<Map<String, dynamic>>(
      ApiEndpoints.kycSubmit,
    );
    expect(result['status'], 'submitted');
  });
}
