import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';

/// Carnet d'adresses simule (EXI-C05).
///
/// Etat en memoire, propre au processus : suffisant pour recetter le carnet
/// (ajout, modification, suppression, unicite du domicile/travail) sans base.
class AddressesMockModule extends MockModule {
  final List<Map<String, dynamic>> _addresses = [];
  int _seq = 0;

  static const Set<String> _kinds = {'home', 'work', 'favorite', 'other'};
  static const Set<String> _uniqueKinds = {'home', 'work'};

  @override
  void register(MockBackend backend) {
    backend.get(ApiEndpoints.addresses, _list);
    backend.post(ApiEndpoints.addresses, _create);
    backend.patch('/addresses/{id}', _update);
    backend.delete('/addresses/{id}', _delete);
  }

  @override
  Future<void> reset() async {
    _addresses.clear();
    _seq = 0;
  }

  void _demote(String kind, String keepId) {
    if (!_uniqueKinds.contains(kind)) return;
    for (final entry in _addresses) {
      if (entry['kind'] == kind && entry['id'] != keepId) {
        entry['kind'] = 'other';
      }
    }
  }

  Future<MockResponse> _list(MockRequest req, Map<String, String> _) async {
    final items = [..._addresses]
      ..sort((a, b) => (b['useCount'] as int).compareTo(a['useCount'] as int));
    return MockResponse.ok({'items': items});
  }

  Future<MockResponse> _create(MockRequest req, Map<String, String> _) async {
    final kind = '${req.json['kind'] ?? 'other'}';
    if (!_kinds.contains(kind)) {
      return MockResponse.error(422, 'invalid_kind', 'Type d\'adresse inconnu');
    }
    final entry = <String, dynamic>{
      'id': 'adr_${_seq++}',
      'kind': kind,
      'label': '${req.json['label'] ?? ''}',
      'address': req.json['address'],
      'useCount': 0,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _addresses.add(entry);
    _demote(kind, entry['id'] as String);
    return MockResponse.created(entry);
  }

  Future<MockResponse> _update(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final kind = '${req.json['kind'] ?? 'other'}';
    if (!_kinds.contains(kind)) {
      return MockResponse.error(422, 'invalid_kind', 'Type d\'adresse inconnu');
    }
    final entry = _addresses.firstWhere(
      (a) => a['id'] == params['id'],
      orElse: () => {},
    );
    if (entry.isEmpty) {
      return MockResponse.error(404, 'not_found', 'Adresse inconnue');
    }
    entry['label'] = '${req.json['label'] ?? ''}';
    entry['kind'] = kind;
    entry['address'] = req.json['address'];
    _demote(kind, entry['id'] as String);
    return MockResponse.ok(entry);
  }

  Future<MockResponse> _delete(
    MockRequest req,
    Map<String, String> params,
  ) async {
    _addresses.removeWhere((a) => a['id'] == params['id']);
    return MockResponse.noContent();
  }
}
