import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Une course proposee au livreur (EXI-L04).
class AvailableDelivery {
  const AvailableDelivery({
    required this.delivery,
    required this.pickupDistanceKm,
    required this.estimatedEarningAriary,
  });

  final Delivery delivery;

  /// Distance a parcourir **a vide** jusqu'au point de retrait.
  ///
  /// L'exigence EXI-L04 la reclame explicitement, et pour une raison
  /// economique : c'est du carburant que le livreur avance sans etre paye. Une
  /// course bien payee a huit kilometres a vide peut valoir moins qu'une course
  /// modeste au coin de la rue, et lui seul peut en juger.
  final double pickupDistanceKm;

  /// Gain net estime pour le livreur, apres commission.
  final int estimatedEarningAriary;

  double get totalDistanceKm => pickupDistanceKm + delivery.distanceKm;

  /// Rendement en ariary par kilometre reellement parcouru, tout compris.
  double get earningPerKm =>
      totalDistanceKm <= 0 ? 0 : estimatedEarningAriary / totalDistanceKm;

  static AvailableDelivery? fromJson(Map<String, dynamic> json) {
    final delivery = Delivery.fromJson(
      json['delivery'] as Map<String, dynamic>,
    );
    if (delivery == null) return null;
    return AvailableDelivery(
      delivery: delivery,
      pickupDistanceKm: (json['pickupDistanceKm'] as num?)?.toDouble() ?? 0,
      estimatedEarningAriary: (json['estimatedEarning'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Gains du livreur (EXI-L12).
class EarningsSummary {
  const EarningsSummary({
    required this.todayAriary,
    required this.weekAriary,
    required this.monthAriary,
    required this.todayCount,
    required this.entries,
  });

  final int todayAriary;
  final int weekAriary;
  final int monthAriary;
  final int todayCount;

  /// Detail par course : l'exigence demande le detail, pas seulement les
  /// totaux. Un livreur qui conteste un montant doit pouvoir pointer la course.
  final List<EarningEntry> entries;

  static EarningsSummary fromJson(Map<String, dynamic> json) => EarningsSummary(
    todayAriary: (json['today'] as num?)?.toInt() ?? 0,
    weekAriary: (json['week'] as num?)?.toInt() ?? 0,
    monthAriary: (json['month'] as num?)?.toInt() ?? 0,
    todayCount: (json['todayCount'] as num?)?.toInt() ?? 0,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(EarningEntry.fromJson)
        .whereType<EarningEntry>()
        .toList(),
  );
}

class EarningEntry {
  const EarningEntry({
    required this.deliveryId,
    required this.amountAriary,
    required this.at,
    required this.label,
  });

  final String deliveryId;
  final int amountAriary;
  final DateTime at;
  final String label;

  static EarningEntry? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;
    return EarningEntry(
      deliveryId: '${json['deliveryId']}',
      amountAriary: (json['amount'] as num?)?.toInt() ?? 0,
      at: at.toLocal(),
      label: '${json['label'] ?? ''}',
    );
  }
}

/// Nature d'un incident signale par le livreur (EXI-L14).
///
/// Chaque incident porte **sa consequence**, et non seulement son libelle :
/// l'exigence demande que la suite soit definie. Un livreur qui signale une
/// absence doit savoir immediatement ce qui se passe ensuite, sinon il reste
/// planté devant un portail sans instruction.
enum IncidentType {
  senderAbsent('sender_absent', IncidentOutcome.waitThenReturn),
  recipientAbsent('recipient_absent', IncidentOutcome.waitThenReturn),
  addressIncorrect('address_incorrect', IncidentOutcome.contactSupport),
  packageDamaged('package_damaged', IncidentOutcome.documentThenContinue),
  packageRefused('package_refused', IncidentOutcome.returnToSender),
  accident('accident', IncidentOutcome.contactSupport),
  gpsProblem('gps_problem', IncidentOutcome.documentThenContinue),
  vehicleProblem('vehicle_problem', IncidentOutcome.reassign),
  paymentProblem('payment_problem', IncidentOutcome.contactSupport),
  other('other', IncidentOutcome.contactSupport);

  const IncidentType(this.wireName, this.outcome);

  final String wireName;
  final IncidentOutcome outcome;

  static IncidentType fromWire(String? value) => IncidentType.values.firstWhere(
    (t) => t.wireName == value,
    orElse: () => IncidentType.other,
  );
}

enum IncidentOutcome {
  waitThenReturn,
  contactSupport,
  returnToSender,
  reassign,

  /// L'incident est documente (photo, description) mais la course continue :
  /// un colis legerement abime ou un GPS capricieux ne l'arrete pas.
  documentThenContinue,
}

/// Statut de resolution d'un incident (§19).
enum IncidentResolution {
  open('open'),
  resolved('resolved');

  const IncidentResolution(this.wireName);

  final String wireName;

  static IncidentResolution fromWire(String? value) =>
      IncidentResolution.values.firstWhere(
        (r) => r.wireName == value,
        orElse: () => IncidentResolution.open,
      );
}

/// Un incident tel qu'il a ete declare et conserve (§19).
class DeliveryIncident {
  const DeliveryIncident({
    required this.id,
    required this.type,
    required this.resolution,
    required this.createdAt,
    this.description,
    this.photoId,
  });

  final String id;
  final IncidentType type;
  final IncidentResolution resolution;
  final DateTime createdAt;
  final String? description;
  final String? photoId;

  static DeliveryIncident? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    if (id == null) return null;
    return DeliveryIncident(
      id: id,
      type: IncidentType.fromWire(json['kind'] as String?),
      resolution: IncidentResolution.fromWire(json['resolution'] as String?),
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
          DateTime.now(),
      description: json['description'] as String?,
      photoId: json['photoId'] as String?,
    );
  }
}

/// Transition de statut demandee par le livreur (EXI-L08).
///
/// La progression suit strictement la machine a etats du §8.3, et le mobile ne
/// fait que **proposer** : le serveur valide. L'enumeration existe pour que
/// l'ecran n'ait qu'un seul bouton a afficher, avec le libelle de l'etape
/// suivante et rien d'autre.
enum DriverAction {
  arrivedAtPickup(DeliveryStatus.accepted, DeliveryStatus.atPickup),
  pickedUp(DeliveryStatus.atPickup, DeliveryStatus.pickedUp),
  arrivedAtDestination(DeliveryStatus.pickedUp, DeliveryStatus.atDestination),
  delivered(DeliveryStatus.atDestination, DeliveryStatus.delivered);

  const DriverAction(this.from, this.to);

  final DeliveryStatus from;
  final DeliveryStatus to;

  /// Action suivante pour un statut donne, ou `null` si rien n'est attendu du
  /// livreur a ce stade.
  static DriverAction? nextFor(DeliveryStatus status) {
    for (final action in DriverAction.values) {
      if (action.from == status) return action;
    }
    return null;
  }

  /// Vrai lorsque l'etape exige un constat contradictoire (§7.3).
  ///
  /// EXI-CC03 : le statut **ne peut pas progresser** tant que le constat n'est
  /// pas complet. Le drapeau est pose des maintenant pour que le module 5
  /// n'ait qu'a intercaler l'ecran de constat, sans toucher a la progression.
  bool get requiresCustodyReport =>
      this == DriverAction.pickedUp || this == DriverAction.delivered;
}

/// Position emise par le livreur (EXI-L09, EXI-L11).
class DriverPing {
  const DriverPing({
    required this.point,
    required this.at,
    this.speedKmh,
    this.accuracyMeters,
  });

  final GeoPoint point;
  final DateTime at;
  final double? speedKmh;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() => {
    'point': point.toJson(),
    'at': at.toUtc().toIso8601String(),
    if (speedKmh != null) 'speedKmh': speedKmh,
    if (accuracyMeters != null) 'accuracy': accuracyMeters,
  };
}

/// Cadence d'emission de position (EXI-L11).
///
/// 15 s en mouvement, 60 s a l'arret, suspendue au-dela de 10 min d'immobilite.
/// Les trois seuils repondent au meme probleme : la batterie et le forfait du
/// livreur (§4.4). Emettre a cadence fixe viderait l'un et l'autre pour
/// retransmettre cinquante fois la meme position d'un scooter a l'arret.
class PingCadence {
  const PingCadence._();

  static const Duration moving = Duration(seconds: 15);
  static const Duration stopped = Duration(seconds: 60);
  static const Duration suspendAfter = Duration(minutes: 10);

  /// Seuil de vitesse au-dela duquel on considere le livreur en mouvement.
  static const double movingSpeedKmh = 3;

  static Duration forSpeed(double? speedKmh) =>
      (speedKmh ?? 0) >= movingSpeedKmh ? moving : stopped;
}

/// Type de vehicule d'un livreur (§22).
enum VehicleType {
  moto('moto'),
  bicycle('bicycle'),
  car('car'),
  tricycle('tricycle');

  const VehicleType(this.wireName);

  final String wireName;

  static VehicleType fromWire(String? value) => VehicleType.values.firstWhere(
    (t) => t.wireName == value,
    orElse: () => VehicleType.moto,
  );
}

/// Statut de validation d'une fiche vehicule, calque sur le KYC (§22).
enum VehicleValidation {
  pending('pending'),
  validated('validated'),
  rejected('rejected');

  const VehicleValidation(this.wireName);

  final String wireName;

  static VehicleValidation fromWire(String? value) =>
      VehicleValidation.values.firstWhere(
        (v) => v.wireName == value,
        orElse: () => VehicleValidation.pending,
      );
}

/// Fiche vehicule structuree du livreur (§22).
///
/// Complementaire des pieces KYC : ici les informations (type, marque, modele,
/// plaque, assurance), la ou le dossier KYC porte les documents. `type` nul
/// signale une fiche encore vierge.
class Vehicle {
  const Vehicle({
    required this.type,
    required this.validation,
    this.brand,
    this.model,
    this.plate,
    this.insuranceExpiry,
  });

  final VehicleType? type;
  final VehicleValidation validation;
  final String? brand;
  final String? model;
  final String? plate;
  final String? insuranceExpiry;

  bool get isEmpty => type == null;

  static Vehicle fromJson(Map<String, dynamic> json) => Vehicle(
    type: json['type'] == null
        ? null
        : VehicleType.fromWire(json['type'] as String?),
    validation: VehicleValidation.fromWire(json['validation'] as String?),
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    plate: json['plate'] as String?,
    insuranceExpiry: json['insuranceExpiry'] as String?,
  );
}

/// Un message du fil de suivi de dossier KYC (livreur <-> exploitation).
class KycMessage {
  const KycMessage({
    required this.id,
    required this.fromAdmin,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final bool fromAdmin;
  final String body;
  final DateTime createdAt;

  static KycMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    return KycMessage(
      id: id,
      fromAdmin: json['fromAdmin'] == true,
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
          DateTime.now(),
    );
  }
}
