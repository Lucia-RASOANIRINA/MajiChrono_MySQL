import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Qui paie la course (EXI-C42).
///
/// Le port du est une pratique courante a Madagascar : on envoie un colis et
/// c'est le destinataire qui regle a l'arrivee. La refuser obligerait
/// l'expediteur a avancer pour quelqu'un d'autre, ou a s'arranger hors de
/// l'application — c'est-a-dire sans trace.
enum Payer {
  /// Port paye : l'expediteur regle a la commande.
  sender('sender'),

  /// Port du : le destinataire regle a la remise.
  recipient('recipient');

  const Payer(this.wireName);

  final String wireName;

  static Payer fromWire(String? value) => Payer.values.firstWhere(
    (p) => p.wireName == value,
    orElse: () => Payer.sender,
  );

  /// Le reglement a-t-il lieu a la remise ?
  bool get paysOnDelivery => this == Payer.recipient;

  /// Le port du exige que le destinataire ait ete prevenu du montant.
  ///
  /// Un destinataire qui decouvre un prix sur le pas de sa porte refuse le
  /// colis, et c'est le livreur qui perd sa course. L'expediteur doit donc
  /// confirmer qu'il a informe son destinataire.
  bool get requiresRecipientNotice => this == Payer.recipient;
}

/// Point relais partenaire (differenciant D6).
///
/// Une boutique de quartier qui garde le colis. Le modele repond a un fait
/// simple : a Antananarivo, beaucoup de gens ne sont pas chez eux en journee, et
/// une remise ratee coute deux trajets au livreur.
class RelayPoint {
  const RelayPoint({
    required this.id,
    required this.name,
    required this.district,
    required this.landmark,
    required this.point,
    required this.openingHours,
    this.phone,
    this.acceptsDropoff = true,
    this.acceptsPickup = true,
    this.maxWeightKg = 15,
    this.storageDays = 3,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String district;

  /// Point de repere : le meme registre que les adresses composites (D3). Un
  /// relais qu'on ne trouve pas ne sert a rien.
  final String landmark;

  final GeoPoint point;

  /// Horaires en clair, tels qu'ils seront lus : « Lun-Sam 7h-19h ».
  final String openingHours;

  final String? phone;

  /// Le relais accepte-t-il les depots ? Les retraits ?
  ///
  /// Les deux sont distincts : une epicerie peut garder un colis pour un
  /// voisin sans vouloir gerer des depots toute la journee.
  final bool acceptsDropoff;
  final bool acceptsPickup;

  /// Un relais est une boutique, pas un entrepot : elle refuse ce qui ne tient
  /// pas derriere son comptoir.
  final double maxWeightKg;

  /// Duree de garde. Au-dela, le colis repart chez l'expediteur.
  final int storageDays;

  /// Distance depuis la position fournie a la requete, quand elle l'etait. Sert
  /// a trier et a afficher « le plus proche » ; absente si aucune position n'a
  /// ete donnee.
  final double? distanceKm;

  bool canAccept(double weightKg) => acceptsDropoff && weightKg <= maxWeightKg;

  static RelayPoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    final point = GeoPoint.fromJson(json['point'] as Map<String, dynamic>?);
    if (id == null || point == null) return null;

    return RelayPoint(
      id: id,
      name: '${json['name'] ?? ''}',
      district: '${json['district'] ?? ''}',
      landmark: '${json['landmark'] ?? ''}',
      point: point,
      openingHours: '${json['openingHours'] ?? ''}',
      phone: json['phone'] as String?,
      acceptsDropoff: json['acceptsDropoff'] != false,
      acceptsPickup: json['acceptsPickup'] != false,
      maxWeightKg: (json['maxWeightKg'] as num?)?.toDouble() ?? 15,
      storageDays: (json['storageDays'] as num?)?.toInt() ?? 3,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'district': district,
    'landmark': landmark,
    'point': point.toJson(),
    'openingHours': openingHours,
    if (phone != null) 'phone': phone,
    'acceptsDropoff': acceptsDropoff,
    'acceptsPickup': acceptsPickup,
    'maxWeightKg': maxWeightKg,
    'storageDays': storageDays,
  };
}
