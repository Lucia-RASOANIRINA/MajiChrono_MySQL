import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Adresse composite (EXI-C02, differenciant D3).
///
/// C'est l'objet le plus specifique du produit. A Madagascar il n'existe pas
/// d'adressage postal fiable (§4.3) : une adresse reelle s'enonce
/// « Ambohipo, apres l'epicerie Tsiky, portail vert, appeler en arrivant ».
///
/// La consequence est inscrite dans le type lui-meme : **le point de repere et
/// le telephone sont obligatoires, la rue et le numero sont facultatifs**.
/// C'est exactement l'inverse d'un modele d'adresse occidental, et c'est
/// volontaire — un livreur qui cherche une maison se sert du repere, pas d'un
/// numero de rue qui n'est souvent affiche nulle part.
class Address {
  const Address({
    required this.point,
    required this.district,
    required this.landmark,
    required this.contactPhone,
    this.contactName,
    this.street,
    this.facadePhotoId,
    this.voiceNoteId,
  });

  /// Point GPS. Obligatoire : c'est lui qui permet le calcul de distance et la
  /// diffusion aux livreurs proches.
  final GeoPoint point;

  /// Quartier, ou fokontany. Obligatoire.
  final String district;

  /// Point de repere textuel. **Obligatoire** — c'est lui qui fait trouver
  /// l'adresse quand le GPS depose le livreur a cinquante metres.
  final String landmark;

  /// Telephone du contact sur place. **Obligatoire** : « appeler en arrivant »
  /// fait partie de l'adresse a Madagascar, ce n'est pas une option.
  final MalagasyPhone contactPhone;

  final String? contactName;

  /// Rue et numero : facultatifs, par construction.
  final String? street;

  /// Photo de facade (EXI-C03) et note vocale d'itineraire (EXI-C04).
  /// Les identifiants sont portes des maintenant ; la capture arrive au module 5
  /// avec le reste de la chaine photo.
  final String? facadePhotoId;
  final String? voiceNoteId;

  /// Une adresse est utilisable des lors que ses champs obligatoires sont la.
  bool get isComplete =>
      district.trim().isNotEmpty && landmark.trim().isNotEmpty;

  /// Resume affiche dans une liste : le repere d'abord, car c'est l'information
  /// qui identifie le lieu pour un Malgache.
  String get summary {
    final parts = [landmark.trim(), district.trim()].where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }

  Address copyWith({
    GeoPoint? point,
    String? district,
    String? landmark,
    MalagasyPhone? contactPhone,
    String? contactName,
    String? street,
  }) => Address(
    point: point ?? this.point,
    district: district ?? this.district,
    landmark: landmark ?? this.landmark,
    contactPhone: contactPhone ?? this.contactPhone,
    contactName: contactName ?? this.contactName,
    street: street ?? this.street,
    facadePhotoId: facadePhotoId,
    voiceNoteId: voiceNoteId,
  );

  Map<String, dynamic> toJson() => {
    'point': point.toJson(),
    'district': district,
    'landmark': landmark,
    'contactPhone': contactPhone.e164,
    if (contactName != null) 'contactName': contactName,
    if (street != null) 'street': street,
    if (facadePhotoId != null) 'facadePhotoId': facadePhotoId,
    if (voiceNoteId != null) 'voiceNoteId': voiceNoteId,
  };

  static Address? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final point = GeoPoint.fromJson(json['point'] as Map<String, dynamic>?);
    final phone = MalagasyPhone.tryParse('${json['contactPhone']}');
    if (point == null || phone == null) return null;

    return Address(
      point: point,
      district: '${json['district'] ?? ''}',
      landmark: '${json['landmark'] ?? ''}',
      contactPhone: phone,
      contactName: json['contactName'] as String?,
      street: json['street'] as String?,
      facadePhotoId: json['facadePhotoId'] as String?,
      voiceNoteId: json['voiceNoteId'] as String?,
    );
  }
}

/// Entree du carnet d'adresses (EXI-C05).
/// Nature d'une adresse enregistree : un domicile et un lieu de travail uniques,
/// des favoris et des adresses libres.
enum AddressKind {
  home('home'),
  work('work'),
  favorite('favorite'),
  other('other');

  const AddressKind(this.wireName);

  final String wireName;

  static AddressKind fromWire(String? value) {
    for (final kind in AddressKind.values) {
      if (kind.wireName == value) return kind;
    }
    return AddressKind.other;
  }
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.kind = AddressKind.other,
    this.useCount = 0,
    this.lastUsedAt,
  });

  final String id;

  /// Nom donne par l'utilisateur : « Maison », « Boutique ».
  final String label;

  final AddressKind kind;

  final Address address;

  /// Sert au tri : les adresses les plus utilisees remontent, ce qui evite de
  /// faire defiler un carnet a chaque envoi.
  final int useCount;
  final DateTime? lastUsedAt;

  SavedAddress copyWith({
    String? label,
    AddressKind? kind,
    Address? address,
    int? useCount,
    DateTime? lastUsedAt,
  }) => SavedAddress(
    id: id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    address: address ?? this.address,
    useCount: useCount ?? this.useCount,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  /// Depuis la reponse serveur `{id, kind, label, address, useCount}`.
  static SavedAddress? fromJson(Map<String, dynamic> json) {
    final address = Address.fromJson(json['address'] as Map<String, dynamic>?);
    if (address == null) return null;
    return SavedAddress(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      kind: AddressKind.fromWire(json['kind'] as String?),
      address: address,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
    );
  }
}
