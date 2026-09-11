import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Routes simulees des differenciants (§5).
///
/// Deux surfaces seulement, mais elles portent chacune une regle :
///
///  - une alerte d'urgence est **toujours acceptee**, meme incomplete. Le
///    serveur qui refuserait une alerte pour cause de champ manquant serait le
///    pire interlocuteur possible pour quelqu'un au bord d'une route ;
///  - un point relais annonce ce qu'il refuse, plutot que de laisser
///    l'expediteur le decouvrir a la remise.
class DifferentiatorsMockModule extends MockModule {
  DifferentiatorsMockModule();

  final List<Map<String, dynamic>> _alerts = [];

  int _sequence = 0;

  @override
  void register(MockBackend backend) {
    backend.post('/drivers/emergency', _raise);
    backend.get('/drivers/emergency', _list);
    backend.get('/relay-points', _relayPoints);
  }

  @override
  Future<void> reset() async {
    _alerts.clear();
    _sequence = 0;
  }

  /// Une alerte est acceptee telle qu'elle arrive.
  ///
  /// Aucun champ n'est obligatoire hormis l'identifiant : ni position, ni
  /// nature, ni course. C'est le seul point de l'API ou l'absence de donnee ne
  /// justifie jamais un refus.
  Future<MockResponse> _raise(MockRequest req, Map<String, String> _) async {
    final id = '${req.json['id'] ?? 'sos_${++_sequence}'}';

    // Idempotence : rejouer la meme alerte depuis la file ne cree pas un
    // second appel a l'aide.
    final existing = _alerts.where((a) => a['id'] == id).firstOrNull;
    if (existing != null) return MockResponse.ok(existing);

    final alert = <String, dynamic>{
      ...req.json,
      'id': id,
      'receivedAt': DateTime.now().toUtc().toIso8601String(),
      // L'exploitation accuse reception immediatement dans le simulateur : le
      // livreur doit voir que quelqu'un a vu.
      'acknowledgedAt': DateTime.now().toUtc().toIso8601String(),
    };
    _alerts.add(alert);

    return MockResponse.created(alert);
  }

  Future<MockResponse> _list(MockRequest req, Map<String, String> _) async {
    final unacknowledged = req.query['unacknowledged'] == 'true';
    return MockResponse.ok({
      'items': _alerts
          .where((a) => !unacknowledged || a['acknowledgedAt'] == null)
          .toList(),
    });
  }

  /// Reseau de points relais partenaires (differenciant D6).
  ///
  /// Des boutiques de quartier, avec leurs vraies contraintes : horaires,
  /// poids maximal, duree de garde. Un relais qui accepterait tout ne serait
  /// pas un relais, ce serait un entrepot.
  Future<MockResponse> _relayPoints(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final district = req.query['district'];
    final lat = double.tryParse('${req.query['lat']}');
    final lng = double.tryParse('${req.query['lng']}');

    const points = [
      {
        'id': 'rel_1',
        'name': 'Epicerie Tsiky',
        'district': 'Ambohipo',
        'landmark': 'Portail vert, apres le pont',
        'point': {'lat': -18.9105, 'lng': 47.5570},
        'openingHours': 'Lun-Sam 7h-19h',
        'phone': '+261340000011',
        'acceptsDropoff': true,
        'acceptsPickup': true,
        'maxWeightKg': 15.0,
        'storageDays': 3,
      },
      {
        'id': 'rel_2',
        'name': 'Quincaillerie Rary',
        'district': 'Analakely',
        'landmark': 'Face a l escalier, boutique bleue',
        'point': {'lat': -18.9080, 'lng': 47.5250},
        'openingHours': 'Lun-Ven 8h-18h',
        'phone': '+261320000022',
        'acceptsDropoff': true,
        'acceptsPickup': true,
        // Une quincaillerie a de la place : elle prend plus lourd.
        'maxWeightKg': 30.0,
        'storageDays': 5,
      },
      {
        'id': 'rel_3',
        'name': 'Kiosque Ivandry',
        'district': 'Ivandry',
        'landmark': 'Derriere la station, mur blanc',
        'point': {'lat': -18.8760, 'lng': 47.5310},
        'openingHours': 'Tous les jours 6h-20h',
        'acceptsDropoff': false,
        'acceptsPickup': true,
        'maxWeightKg': 5.0,
        'storageDays': 2,
      },
    ];

    List<Map<String, dynamic>> items = district == null
        ? points.map((p) => {...p}).toList()
        : points
              .where((p) => p['district'] == district)
              .map((p) => {...p})
              .toList();

    // Position fournie : on enrichit chaque relais de sa distance et on remonte
    // les plus proches, comme le fait le serveur reel (§7).
    if (lat != null && lng != null) {
      final origin = GeoPoint(lat, lng);
      items = items.map((p) {
        final point = GeoPoint.fromJson(p['point'] as Map<String, dynamic>?);
        final distance = point == null ? null : origin.distanceKmTo(point);
        return {
          ...p,
          if (distance != null)
            'distanceKm': double.parse(distance.toStringAsFixed(2)),
        };
      }).toList()
        ..sort((a, b) {
          final da = (a['distanceKm'] as num?)?.toDouble() ?? double.infinity;
          final db = (b['distanceKm'] as num?)?.toDouble() ?? double.infinity;
          return da.compareTo(db);
        });
    }

    return MockResponse.ok({'items': items});
  }
}
