import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Position du client pour pre-remplir le depart d'une course.
///
/// Dernier point connu d'abord (instantane, sans GPS chaud), puis un fix frais
/// borne a huit secondes. Rend `null` si la permission est refusee ou le
/// service coupe : l'ecran retombe alors sur le centre de Majunga et laisse
/// choisir le depart sur la carte — jamais d'attente sans issue.
final currentPositionProvider = FutureProvider.autoDispose<GeoPoint?>((
  ref,
) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return GeoPoint(last.latitude, last.longitude);

    final fresh = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return GeoPoint(fresh.latitude, fresh.longitude);
  } on Object {
    return null;
  }
});
