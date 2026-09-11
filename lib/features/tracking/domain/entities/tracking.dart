import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Fiche livreur affichee a l'expediteur (EXI-C22).
class DriverInfo {
  const DriverInfo({
    required this.id,
    required this.displayName,
    required this.maskedPhone,
    this.rating,
    this.plate,
    this.vehicleModel,
    this.photoUrl,
  });

  final String id;
  final String displayName;

  /// **Toujours masque.** Le §12.2 impose au serveur de masquer les numeros
  /// dans toute reponse destinee a l'autre partie (EXI-B07) ; le type le rend
  /// visible pour qu'aucun ecran ne puisse afficher par megarde un numero
  /// complet. L'appel passe par un relais (EXI-C23), jamais par le vrai numero.
  final String maskedPhone;

  final double? rating;
  final String? plate;
  final String? vehicleModel;
  final String? photoUrl;

  static DriverInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return DriverInfo(
      id: '${json['id']}',
      displayName: '${json['displayName'] ?? ''}',
      maskedPhone: '${json['maskedPhone'] ?? ''}',
      rating: (json['rating'] as num?)?.toDouble(),
      plate: json['plate'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

/// Une etape de la frise chronologique (EXI-C21).
class TimelineEntry {
  const TimelineEntry({required this.status, required this.at, this.note});

  final DeliveryStatus status;

  /// Horodatage **serveur**. Le §7.3.5 pose le principe pour les constats
  /// (EXI-CC45) ; la frise suit la meme regle, sinon deux telephones mal
  /// regles raconteraient deux histoires differentes de la meme course.
  final DateTime at;

  final String? note;

  static TimelineEntry? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;
    return TimelineEntry(
      status: DeliveryStatus.fromWire(json['status'] as String?),
      at: at.toLocal(),
      note: json['note'] as String?,
    );
  }
}

/// Etat de suivi d'une course a un instant donne.
class TrackingSnapshot {
  const TrackingSnapshot({
    required this.deliveryId,
    required this.status,
    required this.timeline,
    this.driver,
    this.driverPosition,
    this.trace = const [],
    this.etaMinutes,
    this.trackingToken,
  });

  final String deliveryId;
  final DeliveryStatus status;
  final List<TimelineEntry> timeline;
  final DriverInfo? driver;

  /// Derniere position connue du livreur.
  final GeoPoint? driverPosition;

  /// Trace parcourue, pour dessiner le trajet deja effectue.
  final List<GeoPoint> trace;

  final int? etaMinutes;

  /// Jeton du lien de suivi public (EXI-C24, D9).
  final String? trackingToken;

  static TrackingSnapshot? fromJson(Map<String, dynamic> json) {
    final id = json['deliveryId'] as String?;
    if (id == null) return null;

    return TrackingSnapshot(
      deliveryId: id,
      status: DeliveryStatus.fromWire(json['status'] as String?),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TimelineEntry.fromJson)
          .whereType<TimelineEntry>()
          .toList(),
      driver: DriverInfo.fromJson(json['driver'] as Map<String, dynamic>?),
      driverPosition: GeoPoint.fromJson(
        json['driverPosition'] as Map<String, dynamic>?,
      ),
      trace: (json['trace'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GeoPoint.fromJson)
          .whereType<GeoPoint>()
          .toList(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      trackingToken: json['trackingToken'] as String?,
    );
  }
}

/// Vue publique, servie au destinataire qui n'a pas l'application (EXI-C24, D9).
///
/// Volontairement plus pauvre que [TrackingSnapshot] : ni numero de telephone,
/// ni identifiant de course, ni historique complet. Le lien circule par SMS et
/// peut etre transfere a n'importe qui ; il ne doit donc exposer que ce qui
/// permet d'attendre le livreur.
class PublicTracking {
  const PublicTracking({
    required this.status,
    required this.destinationLandmark,
    this.driverFirstName,
    this.driverPosition,
    this.etaMinutes,
    this.expiresAt,
  });

  final DeliveryStatus status;
  final String destinationLandmark;
  final String? driverFirstName;
  final GeoPoint? driverPosition;
  final int? etaMinutes;

  /// Le lien expire a la livraison + 24 h (EXI-C24).
  final DateTime? expiresAt;

  static PublicTracking? fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    if (status == null) return null;
    return PublicTracking(
      status: DeliveryStatus.fromWire(status),
      destinationLandmark: '${json['destinationLandmark'] ?? ''}',
      driverFirstName: json['driverFirstName'] as String?,
      driverPosition: GeoPoint.fromJson(
        json['driverPosition'] as Map<String, dynamic>?,
      ),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      expiresAt: DateTime.tryParse('${json['expiresAt']}')?.toLocal(),
    );
  }
}
