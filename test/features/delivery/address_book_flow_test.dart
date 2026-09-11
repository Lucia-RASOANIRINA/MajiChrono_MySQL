import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/features/delivery/data/mock/addresses_mock_module.dart';

/// Carnet d'adresses, a travers la pile reelle (client + transport simule).
/// On protege les invariants du contrat : un seul domicile, et le CRUD complet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient client;

  Future<void> build() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackend()
      ..register(CoreMockModule())
      ..register(AddressesMockModule());
    client = ApiClient(
      config: AppConfig.fromEnvironment(),
      dataMeter: DataMeter(prefs),
      mockBackend: backend,
      mockAdapter: MockHttpAdapter(backend: backend, random: Random(5)),
    );
  }

  setUp(build);

  const address = {
    'point': {'lat': -18.9, 'lng': 47.5},
    'district': 'Analakely',
    'landmark': 'Face a l escalier',
    'contactPhone': '+261340000009',
  };

  Future<Map<String, dynamic>> create(String kind, String label) => client
      .post<Map<String, dynamic>>(
        ApiEndpoints.addresses,
        body: {'kind': kind, 'label': label, 'address': address},
      );

  Future<List<dynamic>> list() async {
    final json = await client.get<Map<String, dynamic>>(ApiEndpoints.addresses);
    return json['items'] as List<dynamic>;
  }

  test('cree, liste, modifie et supprime', () async {
    final created = await create('other', 'Bureau');
    expect((await list()).length, 1);

    final id = created['id'] as String;
    final updated = await client.patch<Map<String, dynamic>>(
      ApiEndpoints.address(id),
      body: {'kind': 'work', 'label': 'Travail', 'address': address},
    );
    expect(updated['kind'], 'work');

    await client.delete<void>(ApiEndpoints.address(id));
    expect(await list(), isEmpty);
  });

  test('un seul domicile : le nouveau retrograde l ancien', () async {
    await create('home', 'Ancienne');
    await create('home', 'Nouvelle');
    final items = await list();
    final homes = items.where((a) => a['kind'] == 'home').toList();
    expect(homes.length, 1);
    expect(homes.first['label'], 'Nouvelle');
  });
}
