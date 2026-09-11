import 'dart:convert';
import 'dart:math';

import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Routes simulees des courses (§12.2).
///
/// Contrairement au simulateur d'authentification, celui-ci **tient un etat** :
/// une course creee doit se retrouver dans la liste, changer de statut, et etre
/// annulable. L'etat vit en memoire — il se perd au redemarrage du processus,
/// ce qui est acceptable : le cache local de l'application, lui, persiste, et
/// c'est justement ce que la recette hors ligne doit verifier.
class DeliveryMockModule extends MockModule {
  DeliveryMockModule({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, Map<String, dynamic>> _deliveries = {};

  /// Cles d'idempotence deja traitees (EXI-B01).
  ///
  /// Sans ce registre, une reprise apres coupure creerait une seconde course
  /// identique — le defaut que le scenario §16.2-3 cherche precisement.
  final Map<String, String> _idempotency = {};

  /// Registre des courses, partage avec le module de suivi : le suivi porte sur
  /// les memes courses, il n'en tient pas une seconde copie qui divergerait.
  Map<String, Map<String, dynamic>> get store => _deliveries;

  @override
  void register(MockBackend backend) {
    backend.post(ApiEndpoints.deliveries, _create);
    backend.get(ApiEndpoints.deliveries, _list);
    backend.get('/deliveries/{id}', _detail);
    backend.post('/deliveries/{id}/cancel', _cancel);
    backend.post('/deliveries/{id}/incidents', _reportIncident);
    backend.get('/deliveries/{id}/incidents', _listIncidents);
    backend.post('/deliveries/estimate', _estimate);
    backend.post(ApiEndpoints.media, _mediaUpload);
    backend.get('/media/{id}', _mediaGet);
  }

  @override
  Future<void> reset() async {
    _deliveries.clear();
    _idempotency.clear();
    _incidents.clear();
  }

  Future<MockResponse> _create(MockRequest req, Map<String, String> _) async {
    final key = req.idempotencyKey;
    if (key != null && _idempotency.containsKey(key)) {
      // Meme requete rejouee : on renvoie la course deja creee, sans en creer
      // une seconde. Le client ne peut pas distinguer ce cas d'un succes, et
      // c'est exactement le but (EXI-S01).
      return MockResponse.ok(_deliveries[_idempotency[key]]);
    }

    final body = req.json;
    final id = 'dlv_${_random.nextInt(1 << 32)}';
    final now = DateTime.now();

    final delivery = <String, dynamic>{
      ...body,
      'id': id,
      'status': DeliveryStatus.pending.wireName,
      'createdAt': now.toUtc().toIso8601String(),
      'price': body['price'] ?? _price(body),
      'trackingToken': 'trk_${_random.nextInt(1 << 32)}',
      // Code de retrait au relais (§7) : genere seulement si un relais est
      // choisi, comme le fait le serveur reel.
      if (body['relayPointId'] != null)
        'relayPickupCode': _random.nextInt(1000000).toString().padLeft(6, '0'),
    };

    _deliveries[id] = delivery;
    if (key != null) _idempotency[key] = id;

    return MockResponse.created(delivery);
  }

  Future<MockResponse> _list(MockRequest req, Map<String, String> _) async {
    final items = _deliveries.values.toList()
      ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return MockResponse.ok({'items': items});
  }

  Future<MockResponse> _detail(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final delivery = _deliveries[params['id']];
    if (delivery == null) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }
    return MockResponse.ok(delivery);
  }

  Future<MockResponse> _cancel(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final delivery = _deliveries[params['id']];
    if (delivery == null) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }

    final status = DeliveryStatus.fromWire(delivery['status'] as String?);
    if (!status.isCancellableByClient) {
      // EXI-B02 : une transition illegale retourne 409 avec l'etat courant, que
      // le client affichera plutot que de laisser l'utilisateur reessayer.
      return MockResponse.error(
        409,
        'illegal_transition',
        'La course ne peut plus etre annulee',
        details: {'currentState': status.wireName},
      );
    }

    // Frais retenus seulement si un livreur etait deja engage (course acceptee).
    final fee = status == DeliveryStatus.accepted
        ? (((delivery['price'] as num?)?.toInt() ?? 5000) * 0.20)
              .round()
              .clamp(1000, 1 << 30)
        : 0;

    delivery['status'] = DeliveryStatus.cancelled.wireName;
    delivery['cancelReason'] = req.json['reason'];
    delivery['cancelFee'] = fee;
    return MockResponse.ok(delivery);
  }

  /// Incidents declares, par course (§19). L'etat vit en memoire comme le reste.
  final Map<String, List<Map<String, dynamic>>> _incidents = {};

  static const Set<String> _incidentKinds = {
    'sender_absent',
    'recipient_absent',
    'address_incorrect',
    'package_damaged',
    'package_refused',
    'accident',
    'gps_problem',
    'vehicle_problem',
    'payment_problem',
    'other',
  };

  Future<MockResponse> _reportIncident(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final id = params['id'];
    if (!_deliveries.containsKey(id)) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }
    final kind = '${req.json['kind'] ?? ''}';
    if (!_incidentKinds.contains(kind)) {
      return MockResponse.error(422, 'invalid_kind', 'Type inconnu');
    }
    final incident = <String, dynamic>{
      'id': 'inc_${_random.nextInt(1 << 32)}',
      'deliveryId': id,
      'kind': kind,
      'description': req.json['description'],
      'photoId': req.json['photoId'],
      'lat': req.json['lat'],
      'lng': req.json['lng'],
      'resolution': 'open',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    (_incidents[id!] ??= []).add(incident);
    return MockResponse.created(incident);
  }

  Future<MockResponse> _listIncidents(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final id = params['id'];
    if (!_deliveries.containsKey(id)) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }
    final items = [...(_incidents[id] ?? const [])]
      ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return MockResponse.ok({'items': items});
  }

  Future<MockResponse> _estimate(MockRequest req, Map<String, String> _) async {
    final body = req.json;
    return MockResponse.ok({'price': _price(body), 'provisional': true});
  }

  int _mediaSeq = 0;

  // PNG 1x1 : le simulateur ne conserve pas l'image, il en rend une valide.
  static const String _placeholderPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  Future<MockResponse> _mediaUpload(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final id = 'med_${_mediaSeq++}';
    return MockResponse.created({'id': id, 'url': '/media/$id'});
  }

  Future<MockResponse> _mediaGet(MockRequest req, Map<String, String> _) async =>
      MockResponse(
        200,
        base64Decode(_placeholderPng),
        headers: const {
          'content-type': ['image/png'],
        },
      );

  /// Reproduit la grille provisoire pour que le prix serveur et le prix local
  /// coincident tant que DO-3 n'est pas arbitre.
  int _price(Map<String, dynamic> body) {
    final pickup = GeoPoint.fromJson(
      (body['pickup'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    );
    final dropoff = GeoPoint.fromJson(
      (body['dropoff'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    );
    if (pickup == null || dropoff == null) {
      return TariffGrid.provisional.minimumAriary;
    }

    final estimate = TariffGrid.provisional.estimate(
      straightLineKm: pickup.distanceKmTo(dropoff),
      kind: DeliveryKind.fromWire(body['kind'] as String?),
      weight: WeightCategory.fromWire(
        (body['package'] as Map<String, dynamic>?)?['weight'] as String?,
      ),
      slot: PickupSlot.fromJson(body['slot'] as Map<String, dynamic>?),
    );
    return estimate.totalAriary;
  }
}
