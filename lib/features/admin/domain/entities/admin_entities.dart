/// Supervision depuis mobile (§13, EXI-A01 a EXI-A07).
///
/// Une regle traverse tout ce fichier : **aucune action d'exploitation n'est
/// anonyme ni muette**. Refus de dossier, suspension de compte, reaffectation,
/// decision de litige — chacune porte un motif obligatoire et l'identite de qui
/// l'a prise. Un compte suspendu sans trace est une decision que personne
/// n'assume, et c'est exactement ce qu'un litige vient contester six semaines
/// plus tard.
///
/// Le type [ModerationDecision] rend cette regle impossible a contourner : il
/// n'existe pas de facon d'en construire un sans motif.
library;

import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Chiffres du jour (EXI-A01).
class DashboardSummary {
  const DashboardSummary({
    required this.activeDeliveries,
    required this.onlineDrivers,
    required this.openIncidents,
    required this.openDisputes,
    required this.pendingKyc,
    required this.revenueTodayAriary,
    required this.byStatus,
    this.totalClients = 0,
    this.totalDrivers = 0,
  });

  final int activeDeliveries;
  final int onlineDrivers;
  final int openIncidents;
  final int openDisputes;
  final int pendingKyc;
  final int revenueTodayAriary;

  /// Effectifs du reseau : combien de clients, combien de livreurs inscrits.
  final int totalClients;
  final int totalDrivers;

  /// Repartition des courses par statut, pour montrer **ou** ca bloque.
  ///
  /// Un total de courses actives ne dit rien : vingt courses en attente
  /// d'acceptation et vingt courses en transit decrivent deux journees
  /// opposees, l'une ou il manque des livreurs, l'autre ou tout roule.
  final Map<DeliveryStatus, int> byStatus;

  static DashboardSummary fromJson(Map<String, dynamic> json) {
    final raw = json['byStatus'] as Map<String, dynamic>? ?? const {};
    return DashboardSummary(
      activeDeliveries: (json['activeDeliveries'] as num?)?.toInt() ?? 0,
      onlineDrivers: (json['onlineDrivers'] as num?)?.toInt() ?? 0,
      openIncidents: (json['openIncidents'] as num?)?.toInt() ?? 0,
      openDisputes: (json['openDisputes'] as num?)?.toInt() ?? 0,
      pendingKyc: (json['pendingKyc'] as num?)?.toInt() ?? 0,
      revenueTodayAriary: (json['revenueToday'] as num?)?.toInt() ?? 0,
      totalClients: (json['totalClients'] as num?)?.toInt() ?? 0,
      totalDrivers: (json['totalDrivers'] as num?)?.toInt() ?? 0,
      byStatus: {
        for (final entry in raw.entries)
          DeliveryStatus.fromWire(entry.key):
              (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }
}

/// Disponibilite d'un livreur, telle que l'exploitation la voit (EXI-A02).
enum FleetStatus {
  /// En ligne et sans course : c'est la reserve mobilisable.
  available('available'),

  /// En ligne avec une course en cours.
  busy('busy'),

  /// Hors service.
  offline('offline'),

  /// Compte suspendu par l'exploitation (EXI-A06).
  suspended('suspended');

  const FleetStatus(this.wireName);

  final String wireName;

  static FleetStatus fromWire(String? value) => FleetStatus.values.firstWhere(
    (s) => s.wireName == value,
    orElse: () => FleetStatus.offline,
  );

  /// Un livreur suspendu reste visible sur la carte : le retirer donnerait
  /// l'illusion d'une flotte plus saine qu'elle ne l'est, et ferait oublier
  /// qu'une decision attend d'etre levee.
  bool get canReceiveDeliveries => this == FleetStatus.available;
}

/// Un livreur vu depuis l'exploitation.
///
/// Ce n'est volontairement pas la meme chose que le `DriverInfo` montre a
/// l'expediteur : celui-ci ne voit ni la position exacte, ni le statut de
/// compte, ni le motif d'une suspension.
class FleetDriver {
  const FleetDriver({
    required this.id,
    required this.displayName,
    required this.status,
    required this.position,
    this.currentDeliveryId,
    this.plate,
    this.rating,
    this.lastSeenAt,
    this.suspensionReason,
  });

  final String id;
  final String displayName;
  final FleetStatus status;
  final GeoPoint? position;
  final String? currentDeliveryId;
  final String? plate;
  final double? rating;

  /// Derniere position recue. Une position vieille de vingt minutes n'est pas
  /// une position : l'ecran doit pouvoir le dire plutot que d'afficher un point
  /// rassurant au mauvais endroit.
  final DateTime? lastSeenAt;

  final String? suspensionReason;

  bool isStaleAt(DateTime now, {Duration after = const Duration(minutes: 10)}) {
    final seen = lastSeenAt;
    return seen == null || now.difference(seen) > after;
  }

  static FleetDriver? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    if (id == null) return null;

    return FleetDriver(
      id: id,
      displayName: '${json['displayName'] ?? ''}',
      status: FleetStatus.fromWire(json['status'] as String?),
      position: GeoPoint.fromJson(json['position'] as Map<String, dynamic>?),
      currentDeliveryId: json['currentDeliveryId'] as String?,
      plate: json['plate'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      lastSeenAt: DateTime.tryParse('${json['lastSeenAt']}')?.toLocal(),
      suspensionReason: json['suspensionReason'] as String?,
    );
  }
}

/// Dossier de validation d'un livreur (EXI-A03).
class KycApplication {
  const KycApplication({
    required this.driverId,
    required this.displayName,
    required this.status,
    required this.documents,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.reviewerId,
  });

  final String driverId;
  final String displayName;
  final KycStatus status;

  /// Pieces fournies, par code. La visionneuse affiche ce qui existe et signale
  /// ce qui manque : un dossier incomplet doit se voir avant d'etre ouvert.
  final List<KycDocument> documents;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Motif de refus. Obligatoire des lors que le statut est `rejected` : un
  /// livreur refuse sans explication ne peut pas corriger son dossier, et
  /// reviendra en deposer un identique.
  final String? rejectionReason;

  final String? reviewerId;

  bool get isComplete => documents.every((d) => d.provided);

  /// Attend une decision humaine.
  bool get awaitsReview =>
      status == KycStatus.submitted || status == KycStatus.underReview;

  static KycApplication? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['driverId'] as String?;
    if (id == null) return null;

    return KycApplication(
      driverId: id,
      displayName: '${json['displayName'] ?? ''}',
      status: KycStatus.fromWire(json['status'] as String?) ?? KycStatus.draft,
      documents: (json['documents'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(KycDocument.fromJson)
          .whereType<KycDocument>()
          .toList(),
      submittedAt: DateTime.tryParse('${json['submittedAt']}')?.toLocal(),
      reviewedAt: DateTime.tryParse('${json['reviewedAt']}')?.toLocal(),
      rejectionReason: json['rejectionReason'] as String?,
      reviewerId: json['reviewerId'] as String?,
    );
  }
}

/// Une piece du dossier.
class KycDocument {
  const KycDocument({
    required this.code,
    required this.provided,
    this.uploadId,
    this.url,
  });

  final String code;
  final bool provided;
  final String? uploadId;

  /// Chemin de lecture de l'image (jeton exige), quand la piece est fournie.
  final String? url;

  static KycDocument? fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    if (code == null) return null;
    return KycDocument(
      code: code,
      provided: json['provided'] == true,
      uploadId: json['uploadId'] as String?,
      url: json['url'] as String?,
    );
  }
}

/// Etat d'un litige (EXI-A05).
enum DisputeStatus {
  open('open'),
  investigating('investigating'),
  resolved('resolved'),
  rejected('rejected');

  const DisputeStatus(this.wireName);

  final String wireName;

  static DisputeStatus fromWire(String? value) => DisputeStatus.values
      .firstWhere((s) => s.wireName == value, orElse: () => DisputeStatus.open);

  bool get isClosed =>
      this == DisputeStatus.resolved || this == DisputeStatus.rejected;
}

/// Litige ouvert sur une course.
///
/// Il nait le plus souvent d'une remise sous reserves (EXI-CC26), et c'est le
/// comparateur des deux constats qui l'instruit — pas une vue d'exploitation
/// enrichie. L'exigence EXI-CC31 impose que les trois profils voient la meme
/// chose : une vue reservee a l'exploitation ne serait plus une preuve
/// contradictoire, ce serait un dossier a charge.
class Dispute {
  const Dispute({
    required this.id,
    required this.deliveryId,
    required this.status,
    required this.openedAt,
    required this.reason,
    this.messages = const [],
    this.decision,
    this.openedBy,
  });

  final String id;
  final String deliveryId;
  final DisputeStatus status;
  final DateTime openedAt;

  /// Motif d'ouverture, repris tel quel du constat lorsqu'il vient d'une remise
  /// sous reserves.
  final String reason;

  final List<DisputeMessage> messages;

  /// Decision finale, avec son motif. Absente tant que le litige est ouvert.
  final ModerationDecision? decision;

  final String? openedBy;

  Duration ageAt(DateTime now) => now.difference(openedAt);

  static Dispute? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    if (id == null) return null;

    return Dispute(
      id: id,
      deliveryId: '${json['deliveryId'] ?? ''}',
      status: DisputeStatus.fromWire(json['status'] as String?),
      openedAt:
          DateTime.tryParse('${json['openedAt']}')?.toLocal() ?? DateTime.now(),
      reason: '${json['reason'] ?? ''}',
      messages: (json['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DisputeMessage.fromJson)
          .whereType<DisputeMessage>()
          .toList(),
      decision: ModerationDecision.fromJson(
        json['decision'] as Map<String, dynamic>?,
      ),
      openedBy: json['openedBy'] as String?,
    );
  }
}

/// Un echange dans le fil d'un litige.
class DisputeMessage {
  const DisputeMessage({
    required this.id,
    required this.authorLabel,
    required this.body,
    required this.sentAt,
    this.fromOperations = false,
  });

  final String id;
  final String authorLabel;
  final String body;
  final DateTime sentAt;
  final bool fromOperations;

  static DisputeMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    return DisputeMessage(
      id: id,
      authorLabel: '${json['authorLabel'] ?? ''}',
      body: '${json['body'] ?? ''}',
      sentAt:
          DateTime.tryParse('${json['sentAt']}')?.toLocal() ?? DateTime.now(),
      fromOperations: json['fromOperations'] == true,
    );
  }
}

/// Nature d'une decision d'exploitation.
enum ModerationAction {
  kycApprove('kyc_approve'),
  kycReject('kyc_reject'),
  suspendAccount('suspend_account'),
  reinstateAccount('reinstate_account'),
  reassignDelivery('reassign_delivery'),
  resolveDispute('resolve_dispute'),
  rejectDispute('reject_dispute');

  const ModerationAction(this.wireName);

  final String wireName;

  /// Toutes les actions exigent un motif, sans exception.
  ///
  /// Y compris les favorables : approuver un dossier ou reintegrer un compte
  /// sont aussi des decisions, et savoir **pourquoi** un compte a ete
  /// reintegre importe autant que de savoir pourquoi il avait ete suspendu.
  bool get requiresReason => true;

  /// Longueur minimale du motif.
  ///
  /// Un champ obligatoire se remplit avec « ok » ou « ras » quand rien ne s'y
  /// oppose. Le seuil ne garantit pas la pertinence, mais il ecarte le reflexe.
  static const int minReasonLength = 10;

  static bool isReasonAcceptable(String? reason) =>
      (reason ?? '').trim().length >= minReasonLength;
}

/// Decision d'exploitation, indissociable de son motif et de son auteur.
///
/// Le constructeur est **prive** et passe par [ModerationDecision.taken], qui
/// refuse un motif trop court. Il n'existe donc aucun chemin de code produisant
/// une decision anonyme ou vide — la regle n'est pas rappelee par un
/// commentaire, elle est tenue par le type.
class ModerationDecision {
  const ModerationDecision._({
    required this.action,
    required this.reason,
    required this.decidedAt,
    this.decidedBy,
  });

  /// Construit une decision, ou retourne `null` si le motif ne tient pas.
  static ModerationDecision? taken({
    required ModerationAction action,
    required String reason,
    required DateTime decidedAt,
    String? decidedBy,
  }) {
    if (!ModerationAction.isReasonAcceptable(reason)) return null;
    return ModerationDecision._(
      action: action,
      reason: reason.trim(),
      decidedAt: decidedAt,
      decidedBy: decidedBy,
    );
  }

  final ModerationAction action;
  final String reason;
  final DateTime decidedAt;
  final String? decidedBy;

  Map<String, dynamic> toJson() => {
    'action': action.wireName,
    'reason': reason,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
    if (decidedBy != null) 'decidedBy': decidedBy,
  };

  static ModerationDecision? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final action = ModerationAction.values.firstWhere(
      (a) => a.wireName == json['action'],
      orElse: () => ModerationAction.resolveDispute,
    );
    return ModerationDecision.taken(
      action: action,
      reason: '${json['reason'] ?? ''}',
      decidedAt:
          DateTime.tryParse('${json['decidedAt']}')?.toLocal() ??
          DateTime.now(),
      decidedBy: json['decidedBy'] as String?,
    );
  }
}

/// Critere de filtrage de la liste des courses (EXI-A04).
class DeliveryFilter {
  const DeliveryFilter({
    this.statuses = const {},
    this.driverId,
    this.query,
    this.since,
    this.paymentMethod,
  });

  final Set<DeliveryStatus> statuses;
  final String? driverId;

  /// Recherche libre sur l'identifiant, le quartier ou le point de repere.
  final String? query;

  final DateTime? since;
  final PaymentMethod? paymentMethod;

  bool get isEmpty =>
      statuses.isEmpty &&
      driverId == null &&
      (query ?? '').isEmpty &&
      since == null &&
      paymentMethod == null;

  DeliveryFilter copyWith({
    Set<DeliveryStatus>? statuses,
    String? driverId,
    String? query,
    DateTime? since,
    PaymentMethod? paymentMethod,
    bool clearDriver = false,
    bool clearPayment = false,
  }) => DeliveryFilter(
    statuses: statuses ?? this.statuses,
    driverId: clearDriver ? null : (driverId ?? this.driverId),
    query: query ?? this.query,
    since: since ?? this.since,
    paymentMethod: clearPayment ? null : (paymentMethod ?? this.paymentMethod),
  );

  /// Applique le filtre localement.
  ///
  /// Le filtrage se fait **cote mobile** sur la page recue : l'exploitation
  /// travaille sur quelques dizaines de courses a la fois, et un aller-retour
  /// reseau a chaque case cochee rendrait les filtres inutilisables sur le
  /// terrain (§4.4).
  bool matches(Delivery delivery) {
    if (statuses.isNotEmpty && !statuses.contains(delivery.status)) {
      return false;
    }
    if (driverId != null && delivery.driverId != driverId) return false;
    if (paymentMethod != null && delivery.paymentMethod != paymentMethod) {
      return false;
    }
    if (since != null && delivery.createdAt.isBefore(since!)) return false;

    final needle = (query ?? '').trim().toLowerCase();
    if (needle.isEmpty) return true;

    return delivery.id.toLowerCase().contains(needle) ||
        delivery.pickup.district.toLowerCase().contains(needle) ||
        delivery.dropoff.district.toLowerCase().contains(needle) ||
        delivery.pickup.landmark.toLowerCase().contains(needle) ||
        delivery.dropoff.landmark.toLowerCase().contains(needle) ||
        (delivery.driverName ?? '').toLowerCase().contains(needle);
  }
}

/// Un message du fil de suivi de dossier KYC, vu par l'exploitation.
class KycThreadMessage {
  const KycThreadMessage({
    required this.id,
    required this.fromAdmin,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final bool fromAdmin;
  final String body;
  final DateTime createdAt;

  static KycThreadMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    return KycThreadMessage(
      id: id,
      fromAdmin: json['fromAdmin'] == true,
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Un compte vu depuis la gestion des utilisateurs (clients + livreurs).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.suspended,
    this.kycStatus,
    this.rating,
  });

  final String id;
  final String displayName;
  final String phone;

  /// « client » ou « driver ».
  final String role;
  final bool suspended;
  final String? kycStatus;
  final double? rating;

  bool get isDriver => role == 'driver';

  static AdminUser? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    return AdminUser(
      id: id,
      displayName: '${json['displayName'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      role: '${json['role'] ?? ''}',
      suspended: json['suspended'] == true,
      kycStatus: json['kycStatus'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

/// Une paire libelle/valeur pour les histogrammes (zones, heures, livreurs).
class StatBar {
  const StatBar({required this.label, required this.value, this.sub});

  final String label;
  final int value;

  /// Complement facultatif (note d'un livreur, par exemple).
  final String? sub;
}

/// Rapport d'activite de l'exploitation (§13, EXI-A08).
class AdminStats {
  const AdminStats({
    required this.totalDeliveries,
    required this.delivered,
    required this.cancelled,
    required this.successRate,
    required this.cancellationRate,
    required this.revenueAriary,
    required this.driverEarningsAriary,
    required this.totalClients,
    required this.totalDrivers,
    required this.avgDeliveryMinutes,
    required this.incidents,
    required this.disputes,
    required this.topZones,
    required this.peakHours,
    required this.driverPerformance,
  });

  final int totalDeliveries;
  final int delivered;
  final int cancelled;

  /// Fractions entre 0 et 1.
  final double successRate;
  final double cancellationRate;

  final int revenueAriary;
  final int driverEarningsAriary;
  final int totalClients;
  final int totalDrivers;
  final int avgDeliveryMinutes;
  final int incidents;
  final int disputes;

  final List<StatBar> topZones;

  /// 24 valeurs, une par heure du jour.
  final List<StatBar> peakHours;
  final List<StatBar> driverPerformance;

  static AdminStats fromJson(Map<String, dynamic> json) {
    List<StatBar> bars(String key, String labelKey, String valueKey) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (m) => StatBar(
                label: '${m[labelKey] ?? ''}',
                value: (m[valueKey] as num?)?.toInt() ?? 0,
                sub: m['rating'] == null
                    ? null
                    : (m['rating'] as num).toStringAsFixed(1),
              ),
            )
            .toList();

    return AdminStats(
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0,
      revenueAriary: (json['revenueAriary'] as num?)?.toInt() ?? 0,
      driverEarningsAriary: (json['driverEarningsAriary'] as num?)?.toInt() ?? 0,
      totalClients: (json['totalClients'] as num?)?.toInt() ?? 0,
      totalDrivers: (json['totalDrivers'] as num?)?.toInt() ?? 0,
      avgDeliveryMinutes: (json['avgDeliveryMinutes'] as num?)?.toInt() ?? 0,
      incidents: (json['incidents'] as num?)?.toInt() ?? 0,
      disputes: (json['disputes'] as num?)?.toInt() ?? 0,
      topZones: bars('topZones', 'zone', 'count'),
      peakHours:
          (json['peakHours'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (m) => StatBar(
                  label: '${(m['hour'] as num?)?.toInt() ?? 0}h',
                  value: (m['count'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(),
      driverPerformance: bars('driverPerformance', 'displayName', 'delivered'),
    );
  }
}
