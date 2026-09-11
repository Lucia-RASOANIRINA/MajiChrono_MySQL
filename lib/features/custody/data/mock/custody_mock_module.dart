import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';

/// Routes simulees des constats (§12.2).
///
/// Le simulateur **recalcule l'empreinte** et rejette toute incoherence, comme
/// l'impose EXI-B05. C'est le controle le plus important du module : si le
/// serveur acceptait un constat dont l'empreinte ne correspond pas au contenu,
/// toute la chaine de preuve deviendrait declarative. Un client qui casserait
/// la serialisation canonique s'en apercevrait ici, et non le jour d'un litige.
class CustodyMockModule extends MockModule {
  CustodyMockModule();

  /// Constats acceptes, par course puis par etape.
  final Map<String, Map<String, Map<String, dynamic>>> _reports = {};

  @override
  void register(MockBackend backend) {
    backend.post('/deliveries/{id}/custody/pickup', _accept);
    backend.post('/deliveries/{id}/custody/handover', _accept);
    backend.get('/deliveries/{id}/custody', _list);
  }

  @override
  Future<void> reset() async => _reports.clear();

  Future<MockResponse> _accept(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final deliveryId = params['id']!;
    final body = req.json;
    final stage = '${body['stage']}';
    final claimed = body['hash'] as String?;

    if (claimed == null) {
      return MockResponse.error(422, 'missing_hash', 'Empreinte absente');
    }

    // Recalcul sur le corps canonique, hors champs d'enveloppe.
    final canonical = Map<String, dynamic>.from(body)
      ..remove('id')
      ..remove('hash')
      ..remove('sealedAt')
      ..remove('serverTimestamp');

    final recomputed = sha256
        .convert(utf8.encode(jsonEncode(canonical)))
        .toString();

    if (recomputed != claimed) {
      return MockResponse.error(
        422,
        'hash_mismatch',
        'Empreinte incoherente avec le contenu',
        details: {'expected': recomputed},
      );
    }

    // EXI-CC44 : la remise doit chainer sur la prise en charge enregistree.
    if (stage == 'handover') {
      final pickup = _reports[deliveryId]?['pickup'];
      if (pickup == null) {
        return MockResponse.error(
          409,
          'missing_pickup',
          'Aucun constat de prise en charge',
        );
      }
      if (body['previousHash'] != pickup['hash']) {
        return MockResponse.error(
          422,
          'chain_broken',
          'Le constat de remise ne chaine pas sur la prise en charge',
        );
      }
    }

    // EXI-CC04 : un constat scelle ne se rejoue pas. Une seconde soumission de
    // la meme etape avec une empreinte differente est un rejet, pas une mise a
    // jour — « toute precision ulterieure est un ajout distinct ».
    final existing = _reports[deliveryId]?[stage];
    if (existing != null && existing['hash'] != claimed) {
      return MockResponse.error(
        409,
        'already_sealed',
        'Un constat scelle existe deja pour cette etape',
      );
    }

    final serverTimestamp = DateTime.now().toUtc().toIso8601String();
    final stored = {...body, 'serverTimestamp': serverTimestamp};

    _reports.putIfAbsent(deliveryId, () => {})[stage] = stored;

    return MockResponse.created(stored);
  }

  Future<MockResponse> _list(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final reports = _reports[params['id']];
    if (reports == null) {
      return MockResponse.ok({'pickup': null, 'handover': null});
    }
    return MockResponse.ok({
      'pickup': reports['pickup'],
      'handover': reports['handover'],
    });
  }
}
