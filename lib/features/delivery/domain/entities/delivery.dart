import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';

/// Nature de la course (EXI-C06).
enum DeliveryKind {
  standard('standard'),
  document('document'),
  fragile('fragile'),
  food('food'),

  /// Achat pour compte (differenciant D5, repris de Glovo) : le livreur achete
  /// et avance les fonds. Livre au module 9, declare ici pour que le type de
  /// course soit complet des la creation.
  shopping('shopping');

  const DeliveryKind(this.wireName);

  final String wireName;

  static DeliveryKind fromWire(String? value) => DeliveryKind.values.firstWhere(
    (k) => k.wireName == value,
    orElse: () => DeliveryKind.standard,
  );

  /// Une course fragile ou alimentaire majore le prix : elle impose au livreur
  /// une conduite plus lente et un soin particulier.
  double get priceMultiplier => switch (this) {
    DeliveryKind.fragile => 1.20,
    DeliveryKind.food => 1.10,
    _ => 1,
  };
}

/// Categorie de poids declaree (EXI-C08).
///
/// Des categories, et non un poids exact : personne ne pese son colis avant de
/// l'envoyer. Une fourchette est une information honnete, un chiffre au gramme
/// serait une fiction.
enum WeightCategory {
  upTo2('lt_2', 0, 2),
  from2to5('2_5', 2, 5),
  from5to15('5_15', 5, 15),
  over15('gt_15', 15, 30);

  const WeightCategory(this.wireName, this.minKg, this.maxKg);

  final String wireName;
  final double minKg;
  final double maxKg;

  static WeightCategory fromWire(String? value) =>
      WeightCategory.values.firstWhere(
        (w) => w.wireName == value,
        orElse: () => WeightCategory.upTo2,
      );

  /// Supplement lie a la manutention et a l'encombrement sur une moto.
  int get surchargeAriary => switch (this) {
    WeightCategory.upTo2 => 0,
    WeightCategory.from2to5 => 1000,
    WeightCategory.from5to15 => 3000,
    WeightCategory.over15 => 8000,
  };
}

/// Declaration du colis (EXI-C08).
class PackageDeclaration {
  const PackageDeclaration({
    required this.weight,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.declaredValueAriary,
    this.description,
    this.photoId,
  });

  final WeightCategory weight;
  final int? lengthCm;
  final int? widthCm;
  final int? heightCm;

  /// Valeur declaree, base de l'option assurance (EXI-C12).
  final int? declaredValueAriary;

  final String? description;

  /// Photo du colis (EXI-C09). Capture livree au module 5 avec la chaine photo.
  final String? photoId;

  Map<String, dynamic> toJson() => {
    'weight': weight.wireName,
    if (lengthCm != null) 'lengthCm': lengthCm,
    if (widthCm != null) 'widthCm': widthCm,
    if (heightCm != null) 'heightCm': heightCm,
    if (declaredValueAriary != null) 'declaredValue': declaredValueAriary,
    if (description != null) 'description': description,
    if (photoId != null) 'photoId': photoId,
  };

  static PackageDeclaration fromJson(Map<String, dynamic> json) =>
      PackageDeclaration(
        weight: WeightCategory.fromWire(json['weight'] as String?),
        lengthCm: (json['lengthCm'] as num?)?.toInt(),
        widthCm: (json['widthCm'] as num?)?.toInt(),
        heightCm: (json['heightCm'] as num?)?.toInt(),
        declaredValueAriary: (json['declaredValue'] as num?)?.toInt(),
        description: json['description'] as String?,
        photoId: json['photoId'] as String?,
      );
}

/// Creneau de retrait (EXI-C11) : immediat, ou date avec tranche de deux heures.
class PickupSlot {
  const PickupSlot.immediate() : scheduledDate = null, startHour = null;

  const PickupSlot.scheduled({required DateTime date, required int hour})
    : scheduledDate = date,
      startHour = hour;

  final DateTime? scheduledDate;
  final int? startHour;

  bool get isImmediate => scheduledDate == null;

  /// Tranche de deux heures (EXI-C11).
  int? get endHour => startHour == null ? null : startHour! + 2;

  Map<String, dynamic> toJson() => {
    'immediate': isImmediate,
    if (scheduledDate != null)
      'date': scheduledDate!.toIso8601String().split('T').first,
    if (startHour != null) 'startHour': startHour,
  };

  static PickupSlot fromJson(Map<String, dynamic>? json) {
    if (json == null || json['immediate'] == true) {
      return const PickupSlot.immediate();
    }
    final date = DateTime.tryParse('${json['date']}');
    final hour = (json['startHour'] as num?)?.toInt();
    if (date == null || hour == null) return const PickupSlot.immediate();
    return PickupSlot.scheduled(date: date, hour: hour);
  }
}

/// Mode de paiement (EXI-C40).
///
/// L'espece est le mode par defaut, et ce n'est pas un pis-aller : elle reste
/// la norme de confiance a Madagascar (§4.2). Le cahier des charges est
/// explicite sur ce point — jamais un « mode degrade honteux ».
enum PaymentMethod {
  cash('cash'),
  majipay('majipay');

  const PaymentMethod(this.wireName);

  final String wireName;

  static PaymentMethod fromWire(String? value) => PaymentMethod.values
      .firstWhere((p) => p.wireName == value, orElse: () => PaymentMethod.cash);
}

/// Machine a etats d'une course (§8.3).
///
/// Les transitions sont validees cote serveur : le mobile propose, le serveur
/// dispose. L'enumeration sert a l'affichage et au filtrage local.
enum DeliveryStatus {
  draft('brouillon'),
  pending('en_attente'),
  accepted('acceptee'),
  atPickup('au_depart'),
  pickedUp('prise_en_charge'),
  inTransit('en_transit'),
  atDestination('a_destination'),
  delivered('livree'),
  deliveredWithReserves('livree_avec_reserves'),
  refused('refusee'),
  returning('retour_expediteur'),
  paid('payee'),
  disputed('litige'),
  cancelled('annulee'),
  closed('cloturee');

  const DeliveryStatus(this.wireName);

  final String wireName;

  static DeliveryStatus fromWire(String? value) =>
      DeliveryStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => DeliveryStatus.pending,
      );

  /// L'annulation par l'expediteur n'est possible qu'avant prise en charge
  /// (EXI-C26).
  bool get isCancellableByClient =>
      this == DeliveryStatus.pending || this == DeliveryStatus.accepted;

  bool get isTerminal =>
      this == DeliveryStatus.closed ||
      this == DeliveryStatus.cancelled ||
      this == DeliveryStatus.paid;

  bool get isActive => !isTerminal;
}

/// Une course.
class Delivery {
  const Delivery({
    required this.id,
    required this.status,
    required this.kind,
    required this.pickup,
    required this.dropoff,
    required this.package,
    required this.slot,
    required this.paymentMethod,
    required this.createdAt,
    this.priceAriary,
    this.driverId,
    this.driverName,
    this.trackingToken,
    this.pendingSync = false,
    this.payer = Payer.sender,
    this.shopping,
    this.relayPointId,
    this.relayPickupCode,
  });

  final String id;
  final DeliveryStatus status;
  final DeliveryKind kind;
  final Address pickup;
  final Address dropoff;
  final PackageDeclaration package;
  final PickupSlot slot;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final int? priceAriary;
  final String? driverId;
  final String? driverName;

  /// Jeton du lien de suivi public partageable par SMS (EXI-C24, D9).
  final String? trackingToken;

  /// Vrai tant que la course n'a pas ete confirmee par le serveur (EXI-C13).
  ///
  /// L'interface doit le montrer : une course creee dans un tunnel existe pour
  /// l'utilisateur, mais aucun livreur ne l'a encore vue.
  final bool pendingSync;

  /// Qui paie la course (EXI-C42). Port paye par defaut.
  final Payer payer;

  /// Liste de courses, lorsque le type est l'achat pour compte (EXI-C07).
  final ShoppingOrder? shopping;

  /// Point relais de remise, lorsqu'il en est designe un (differenciant D6).
  final String? relayPointId;

  /// Code de retrait a presenter au relais (§7). Genere par le serveur quand un
  /// relais est choisi ; le destinataire s'en sert pour recuperer le colis.
  final String? relayPickupCode;

  double get distanceKm => pickup.point.distanceKmTo(dropoff.point);

  Delivery copyWith({
    DeliveryStatus? status,
    int? priceAriary,
    String? driverId,
    String? driverName,
    String? trackingToken,
    bool? pendingSync,
    ShoppingOrder? shopping,
  }) => Delivery(
    id: id,
    status: status ?? this.status,
    kind: kind,
    pickup: pickup,
    dropoff: dropoff,
    package: package,
    slot: slot,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    priceAriary: priceAriary ?? this.priceAriary,
    driverId: driverId ?? this.driverId,
    driverName: driverName ?? this.driverName,
    trackingToken: trackingToken ?? this.trackingToken,
    pendingSync: pendingSync ?? this.pendingSync,
    payer: payer,
    shopping: shopping ?? this.shopping,
    relayPointId: relayPointId,
    relayPickupCode: relayPickupCode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.wireName,
    'kind': kind.wireName,
    'pickup': pickup.toJson(),
    'dropoff': dropoff.toJson(),
    'package': package.toJson(),
    'slot': slot.toJson(),
    'paymentMethod': paymentMethod.wireName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (priceAriary != null) 'price': priceAriary,
    if (driverId != null) 'driverId': driverId,
    if (driverName != null) 'driverName': driverName,
    if (trackingToken != null) 'trackingToken': trackingToken,
    'payer': payer.wireName,
    if (shopping != null) 'shopping': shopping!.toJson(),
    if (relayPointId != null) 'relayPointId': relayPointId,
    if (relayPickupCode != null) 'relayPickupCode': relayPickupCode,
  };

  static Delivery? fromJson(Map<String, dynamic> json) {
    final pickup = Address.fromJson(json['pickup'] as Map<String, dynamic>?);
    final dropoff = Address.fromJson(json['dropoff'] as Map<String, dynamic>?);
    if (pickup == null || dropoff == null) return null;

    return Delivery(
      id: '${json['id']}',
      status: DeliveryStatus.fromWire(json['status'] as String?),
      kind: DeliveryKind.fromWire(json['kind'] as String?),
      pickup: pickup,
      dropoff: dropoff,
      package: PackageDeclaration.fromJson(
        (json['package'] as Map<String, dynamic>?) ?? {},
      ),
      slot: PickupSlot.fromJson(json['slot'] as Map<String, dynamic>?),
      paymentMethod: PaymentMethod.fromWire(json['paymentMethod'] as String?),
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
          DateTime.now(),
      priceAriary: (json['price'] as num?)?.toInt(),
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      trackingToken: json['trackingToken'] as String?,
      payer: Payer.fromWire(json['payer'] as String?),
      shopping: ShoppingOrder.fromJson(
        json['shopping'] as Map<String, dynamic>?,
      ),
      relayPointId: json['relayPointId'] as String?,
      relayPickupCode: json['relayPickupCode'] as String?,
    );
  }
}
