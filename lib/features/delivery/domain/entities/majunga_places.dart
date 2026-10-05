import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Nature d'un lieu du catalogue, pour l'icone de la liste.
enum PlaceCategory {
  landmark,
  market,
  transport,
  health,
  education,
  beach,
  district,
}

/// Lieu connu de Majunga (Mahajanga).
///
/// A Majunga, on ne donne pas une adresse : on dit « a la Corniche », « au Bazary
/// Be », « a la gare routiere ». Le catalogue reprend ces reperes pour que la
/// destination se choisisse en deux lettres tapees, sans chercher un point sur
/// la carte.
///
/// Les coordonnees sont celles d'OpenStreetMap (service Nominatim), verifiees
/// le 2 octobre 2026 : le point de la carte tombe sur le lieu, et le repere
/// textuel fait le reste. Les lieux sans position fiable dans OpenStreetMap
/// (« le Baobab », Tanambao) ne figurent pas au catalogue : un repere mal place
/// enverrait le livreur au mauvais endroit.
class MajungaPlace {
  const MajungaPlace({
    required this.id,
    required this.name,
    required this.district,
    required this.point,
    required this.category,
  });

  final String id;
  final String name;
  final String district;
  final GeoPoint point;
  final PlaceCategory category;

  bool matches(String query) {
    final q = _fold(query.trim());
    if (q.isEmpty) return true;
    return _fold(name).contains(q) || _fold(district).contains(q);
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');
}

/// Zone desservie : Majunga et sa peripherie immediate.
class MajungaZone {
  const MajungaZone._();

  /// Centre-ville (place de l'Hotel de ville / Majunga Be).
  static const GeoPoint center = GeoPoint(-15.7167, 46.3167);

  /// Rayon desservi : la ville, l'aeroport d'Amborovy, le Cirque Rouge.
  static const double radiusKm = 25;

  static bool contains(GeoPoint point) =>
      point.distanceKmTo(center) <= radiusKm;

  static const List<MajungaPlace> places = [
    MajungaPlace(
      id: 'bazary_be',
      name: 'Bazary Be',
      district: 'Mahajanga Be',
      point: GeoPoint(-15.7234, 46.3109),
      category: PlaceCategory.market,
    ),
    MajungaPlace(
      id: 'marche_morafeno',
      name: 'Marché Morafeno',
      district: 'Mahabibo',
      point: GeoPoint(-15.7164, 46.3214),
      category: PlaceCategory.market,
    ),
    MajungaPlace(
      id: 'gare_routiere',
      name: 'Gare routière',
      district: 'Marovato Abattoir',
      point: GeoPoint(-15.7215, 46.3269),
      category: PlaceCategory.transport,
    ),
    MajungaPlace(
      id: 'port',
      name: 'Port de Mahajanga',
      district: 'Mahajanga Be',
      point: GeoPoint(-15.726, 46.309),
      category: PlaceCategory.transport,
    ),
    MajungaPlace(
      id: 'aeroport',
      name: 'Aéroport Amborovy',
      district: 'Amborovy',
      point: GeoPoint(-15.6669, 46.3503),
      category: PlaceCategory.transport,
    ),
    MajungaPlace(
      id: 'chu_androva',
      name: 'CHU Androva',
      district: 'Androva',
      point: GeoPoint(-15.717, 46.3053),
      category: PlaceCategory.health,
    ),
    MajungaPlace(
      id: 'universite',
      name: 'Université de Mahajanga',
      district: 'Ambondrona',
      point: GeoPoint(-15.7011, 46.3538),
      category: PlaceCategory.education,
    ),
    MajungaPlace(
      id: 'corniche',
      name: 'La Corniche',
      district: 'Corniche',
      point: GeoPoint(-15.7158, 46.3001),
      category: PlaceCategory.beach,
    ),
    MajungaPlace(
      id: 'grand_pavois',
      name: 'Plage du Grand Pavois',
      district: 'Amborovy',
      point: GeoPoint(-15.6372, 46.3439),
      category: PlaceCategory.beach,
    ),
    MajungaPlace(
      id: 'cirque_rouge',
      name: 'Cirque Rouge',
      district: 'Amborovy',
      point: GeoPoint(-15.6346, 46.3531),
      category: PlaceCategory.landmark,
    ),
    MajungaPlace(
      id: 'majunga_be',
      name: 'Majunga Be',
      district: 'Vieille ville',
      point: GeoPoint(-15.7235, 46.3105),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'mahabibo',
      name: 'Mahabibo',
      district: 'Mahabibo',
      point: GeoPoint(-15.7177, 46.3198),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'tsaramandroso',
      name: 'Tsaramandroso',
      district: 'Tsaramandroso',
      point: GeoPoint(-15.7108, 46.317),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'mangarivotra',
      name: 'Mangarivotra',
      district: 'Mangarivotra',
      point: GeoPoint(-15.7165, 46.3134),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'ambovoalanana',
      name: 'Ambovoalanana',
      district: 'Ambovoalanana',
      point: GeoPoint(-15.7192, 46.3187),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'ambalavola',
      name: 'Ambalavola',
      district: 'Ambalavola',
      point: GeoPoint(-15.713, 46.3231),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'antanimalandy',
      name: 'Antanimalandy',
      district: 'Antanimalandy',
      point: GeoPoint(-15.7096, 46.357),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'village_touristique',
      name: 'Village Touristique',
      district: 'Village Touristique',
      point: GeoPoint(-15.7068, 46.3061),
      category: PlaceCategory.district,
    ),
    MajungaPlace(
      id: 'androva',
      name: 'Androva',
      district: 'Androva',
      point: GeoPoint(-15.718, 46.3062),
      category: PlaceCategory.district,
    ),
  ];

  static List<MajungaPlace> search(String query) =>
      places.where((p) => p.matches(query)).toList();
}
