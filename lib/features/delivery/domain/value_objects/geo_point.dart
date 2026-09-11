import 'dart:math' as math;

/// Point geographique.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Centre d'Antananarivo, utilise comme repli quand aucune position n'est
  /// disponible — phase 1 du deploiement (§2.1).
  static const GeoPoint antananarivo = GeoPoint(-18.8792, 47.5079);

  bool get isInMadagascar =>
      latitude >= -26 &&
      latitude <= -11 &&
      longitude >= 43 &&
      longitude <= 51.5;

  static const double _earthRadiusKm = 6371;

  /// Distance a vol d'oiseau, en kilometres.
  double distanceKmTo(GeoPoint other) {
    double toRad(double deg) => deg * math.pi / 180;

    final dLat = toRad(other.latitude - latitude);
    final dLon = toRad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(latitude)) *
            math.cos(toRad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  static GeoPoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
}
