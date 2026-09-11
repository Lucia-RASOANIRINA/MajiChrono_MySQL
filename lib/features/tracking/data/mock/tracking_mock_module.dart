import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Routes simulees du suivi (§12.2).
///
/// Le simulateur fait **avancer un livreur** le long du trajet, en fonction du
/// temps ecoule depuis l'acceptation. Ce n'est pas un ornement : sans mouvement,
/// on ne peut verifier ni le rafraichissement adaptatif d'EXI-C20, ni la frise
/// chronologique, ni le fait qu'une carte hors ligne continue d'afficher une
/// position. C'est ce qui rend le module 3 recettable sans flotte reelle.
class TrackingMockModule extends MockModule {
  TrackingMockModule({required this.deliveries});

  /// Acces aux courses tenues par le module de livraison : le suivi porte sur
  /// elles, il ne tient pas son propre registre.
  final Map<String, Map<String, dynamic>> Function() deliveries;

  /// Instant d'acceptation par course, qui sert d'origine des temps.
  final Map<String, DateTime> _acceptedAt = {};

  /// Duree simulee d'une course, du depart a la remise.
  static const Duration courseDuration = Duration(minutes: 4);

  @override
  void register(MockBackend backend) {
    backend.get('/deliveries/{id}/trace', _trace);
    backend.get('/public/track/{token}', _publicTrack);
  }

  @override
  Future<void> reset() async => _acceptedAt.clear();

  /// Progression de 0 a 1 le long du trajet.
  double _progress(String id) {
    final started = _acceptedAt.putIfAbsent(id, DateTime.now);
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    return (elapsed / courseDuration.inMilliseconds).clamp(0, 1).toDouble();
  }

  /// Statut deduit de la progression, selon la machine a etats du §8.3.
  DeliveryStatus _statusFor(double progress) => switch (progress) {
    < 0.1 => DeliveryStatus.accepted,
    < 0.25 => DeliveryStatus.atPickup,
    < 0.35 => DeliveryStatus.pickedUp,
    < 0.85 => DeliveryStatus.inTransit,
    < 1 => DeliveryStatus.atDestination,
    _ => DeliveryStatus.delivered,
  };

  GeoPoint _interpolate(GeoPoint from, GeoPoint to, double t) => GeoPoint(
    from.latitude + (to.latitude - from.latitude) * t,
    from.longitude + (to.longitude - from.longitude) * t,
  );

  Future<MockResponse> _trace(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final id = params['id']!;
    final delivery = deliveries()[id];
    if (delivery == null) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }

    final pickup = GeoPoint.fromJson(
      (delivery['pickup'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    )!;
    final dropoff = GeoPoint.fromJson(
      (delivery['dropoff'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    )!;

    final progress = _progress(id);
    final status = _statusFor(progress);

    // Le livreur rejoint d'abord le point de depart, puis suit le trajet.
    final position = progress < 0.25
        ? _interpolate(
            GeoPoint(pickup.latitude + 0.012, pickup.longitude - 0.010),
            pickup,
            progress / 0.25,
          )
        : _interpolate(pickup, dropoff, ((progress - 0.25) / 0.75).clamp(0, 1));

    // Trace deja parcourue, echantillonnee.
    final trace = <Map<String, dynamic>>[];
    for (var t = 0.25; t <= progress; t += 0.05) {
      trace.add(
        _interpolate(pickup, dropoff, ((t - 0.25) / 0.75).clamp(0, 1)).toJson(),
      );
    }

    delivery['status'] = status.wireName;

    final started = _acceptedAt[id]!;
    final remaining = courseDuration.inMinutes * (1 - progress);

    return MockResponse.ok({
      'deliveryId': id,
      'status': status.wireName,
      'driverPosition': position.toJson(),
      'trace': trace,
      'etaMinutes': remaining.ceil(),
      'trackingToken': delivery['trackingToken'],
      'driver': {
        'id': 'drv_001',
        'displayName': 'Naina Andria',
        // Masque des la source : le serveur ne transmet jamais le numero
        // complet a l'autre partie (EXI-B07).
        'maskedPhone': '+261 ** ** *** 02',
        'rating': 4.6,
        'plate': '1234 TBB',
        'vehicleModel': 'Honda 125',
      },
      'timeline': _timeline(started, progress),
    });
  }

  List<Map<String, dynamic>> _timeline(DateTime started, double progress) {
    const steps = <(double, DeliveryStatus)>[
      (0, DeliveryStatus.pending),
      (0.02, DeliveryStatus.accepted),
      (0.1, DeliveryStatus.atPickup),
      (0.25, DeliveryStatus.pickedUp),
      (0.35, DeliveryStatus.inTransit),
      (0.85, DeliveryStatus.atDestination),
      (1, DeliveryStatus.delivered),
    ];

    return [
      for (final (threshold, status) in steps)
        if (progress >= threshold)
          {
            'status': status.wireName,
            'at': started
                .add(courseDuration * threshold)
                .toUtc()
                .toIso8601String(),
          },
    ];
  }

  /// Suivi public : accessible sans session, volontairement pauvre (EXI-C24).
  Future<MockResponse> _publicTrack(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final token = params['token'];
    final entry = deliveries().entries.where(
      (e) => e.value['trackingToken'] == token,
    );
    if (entry.isEmpty) {
      return MockResponse.error(404, 'not_found', 'Lien de suivi inconnu');
    }

    final id = entry.first.key;
    final delivery = entry.first.value;
    final progress = _progress(id);
    final status = _statusFor(progress);

    final pickup = GeoPoint.fromJson(
      (delivery['pickup'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    )!;
    final dropoff = GeoPoint.fromJson(
      (delivery['dropoff'] as Map<String, dynamic>?)?['point']
          as Map<String, dynamic>?,
    )!;

    return MockResponse.ok({
      'status': status.wireName,
      'destinationLandmark':
          (delivery['dropoff'] as Map<String, dynamic>)['landmark'],
      // Prenom seul : le destinataire n'a pas besoin de l'identite complete du
      // livreur pour l'attendre.
      'driverFirstName': 'Naina',
      'driverPosition': _interpolate(
        pickup,
        dropoff,
        ((progress - 0.25) / 0.75).clamp(0, 1),
      ).toJson(),
      'etaMinutes': (courseDuration.inMinutes * (1 - progress)).ceil(),
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 24))
          .toUtc()
          .toIso8601String(),
    });
  }
}
