/// Alerte d'urgence du livreur (EXI-L13, differenciant D10).
///
/// **Ce n'est pas un incident.** Un incident se signale, se motive, se met en
/// file et attend son tour derriere les constats. Une urgence part tout de
/// suite, sans saisie, sans choix de motif, sans confirmation modale — et
/// laisse une trace locale meme si le reseau ne repond pas.
///
/// « Accessible en deux appuis » se lit litteralement : un appui pour ouvrir,
/// un appui pour envoyer. Rien entre les deux. Chaque champ supplementaire
/// serait une seconde de plus pour quelqu'un qui vient de se faire arreter au
/// bord d'une route.
///
/// Le deuxieme appui n'est pas une confirmation de politesse : il existe parce
/// qu'un bouton d'urgence a un seul appui se declenche dans une poche.
library;

import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Nature de l'urgence.
///
/// Quatre choix, pas davantage : au-dela, la liste se lit au lieu de se
/// pointer. Ils sont pre-selectionnables mais **jamais obligatoires** — une
/// alerte sans nature part quand meme.
enum EmergencyKind {
  accident('accident'),
  aggression('aggression'),
  breakdown('breakdown'),
  medical('medical'),

  /// Envoi sans qualification : le livreur a appuye deux fois, c'est tout ce
  /// qu'on sait, et c'est deja l'essentiel.
  unspecified('unspecified');

  const EmergencyKind(this.wireName);

  final String wireName;

  static EmergencyKind fromWire(String? value) =>
      EmergencyKind.values.firstWhere(
        (k) => k.wireName == value,
        orElse: () => EmergencyKind.unspecified,
      );

  /// L'exploitation doit-elle rappeler immediatement ?
  ///
  /// Une panne peut attendre quelques minutes ; une agression ou un accident,
  /// non. La distinction pilote l'ordre d'affichage cote supervision.
  bool get needsImmediateCallback =>
      this == EmergencyKind.accident ||
      this == EmergencyKind.aggression ||
      this == EmergencyKind.medical;
}

/// Une alerte, telle qu'elle part et telle qu'elle est conservee.
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.raisedAt,
    required this.kind,
    this.point,
    this.deliveryId,
    this.batteryPercent,
    this.acknowledgedAt,
  });

  final String id;
  final DateTime raisedAt;
  final EmergencyKind kind;

  /// Derniere position connue. **Facultative** : attendre un point GPS avant
  /// d'envoyer l'alerte couterait les secondes qui comptent, et sous un pont ou
  /// dans un parking le point ne viendra jamais.
  final GeoPoint? point;

  final String? deliveryId;

  /// Niveau de batterie a l'envoi.
  ///
  /// Ce n'est pas une curiosite : une alerte partie a 3 % dit a l'exploitation
  /// que le telephone va s'eteindre et qu'il ne faut pas compter rappeler.
  final int? batteryPercent;

  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;

  /// Delai avant lequel l'exploitation doit avoir accuse reception.
  ///
  /// Passe ce delai sans accuse, l'application le dit au livreur plutot que de
  /// le laisser croire que quelqu'un l'a vu.
  static const Duration acknowledgementTarget = Duration(minutes: 2);

  bool isUnacknowledgedAt(DateTime now) =>
      !isAcknowledged && now.difference(raisedAt) > acknowledgementTarget;

  EmergencyAlert acknowledgedAtTime(DateTime at) => EmergencyAlert(
    id: id,
    raisedAt: raisedAt,
    kind: kind,
    point: point,
    deliveryId: deliveryId,
    batteryPercent: batteryPercent,
    acknowledgedAt: at,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'raisedAt': raisedAt.toUtc().toIso8601String(),
    'kind': kind.wireName,
    if (point != null) 'point': point!.toJson(),
    if (deliveryId != null) 'deliveryId': deliveryId,
    if (batteryPercent != null) 'battery': batteryPercent,
  };

  static EmergencyAlert? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    if (id == null) return null;

    return EmergencyAlert(
      id: id,
      raisedAt:
          DateTime.tryParse('${json['raisedAt']}')?.toLocal() ?? DateTime.now(),
      kind: EmergencyKind.fromWire(json['kind'] as String?),
      point: GeoPoint.fromJson(json['point'] as Map<String, dynamic>?),
      deliveryId: json['deliveryId'] as String?,
      batteryPercent: (json['battery'] as num?)?.toInt(),
      acknowledgedAt: DateTime.tryParse('${json['acknowledgedAt']}')?.toLocal(),
    );
  }
}
