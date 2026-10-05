import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';

/// Vehicule de livraison, choisi selon la taille du colis.
///
/// C'est lui qui decide **a qui** la demande est envoyee : une demande en
/// tricycle ne s'affiche qu'aux livreurs en tricycle. Les noms de transport
/// sont ceux de la fiche vehicule du livreur (`VehicleType`), pour que
/// l'appariement se fasse sans table de correspondance.
///
/// Chaque vehicule porte sa grille (prise en charge, prix au kilometre,
/// minimum). Le prix est **fixe** : calcule avant la commande, recalcule a
/// l'identique par le serveur, qui fait foi.
enum DeliveryVehicle {
  /// Petits colis et documents, jusqu'a 15 kg. Grille publique historique.
  moto('moto', baseAriary: 2000, perKmAriary: 800, minimumAriary: 2000),

  /// Bajaj : cartons, courses de marche, jusqu'a 30 kg.
  tricycle(
    'tricycle',
    baseAriary: 3000,
    perKmAriary: 1000,
    minimumAriary: 3000,
  ),

  /// Voiture : colis volumineux ou fragiles, a l'abri de la pluie.
  car('car', baseAriary: 5000, perKmAriary: 1200, minimumAriary: 5000),

  /// Camionnette : demenagement, marchandises, gros volumes.
  van('van', baseAriary: 15000, perKmAriary: 2500, minimumAriary: 15000);

  const DeliveryVehicle(
    this.wireName, {
    required this.baseAriary,
    required this.perKmAriary,
    required this.minimumAriary,
  });

  final String wireName;
  final int baseAriary;
  final int perKmAriary;
  final int minimumAriary;

  static DeliveryVehicle? fromWire(String? value) {
    for (final vehicle in DeliveryVehicle.values) {
      if (vehicle.wireName == value) return vehicle;
    }
    return null;
  }

  /// Une moto ne porte pas plus de 15 kg ; les autres vehicules portent tout.
  bool canCarry(WeightCategory weight) =>
      this != DeliveryVehicle.moto || weight != WeightCategory.over15;

  /// Vehicule propose d'office pour un poids : le moins cher qui convient.
  static DeliveryVehicle suggestedFor(WeightCategory weight) =>
      weight == WeightCategory.over15
      ? DeliveryVehicle.tricycle
      : DeliveryVehicle.moto;

  /// Grille de ce vehicule : la grille publique, avec sa propre prise en
  /// charge, son prix au kilometre et son minimum.
  TariffGrid get tariff => TariffGrid(
    baseAriary: baseAriary,
    perKmAriary: perKmAriary,
    minimumAriary: minimumAriary,
    detourFactor: TariffGrid.provisional.detourFactor,
    scheduledSurchargeAriary: TariffGrid.provisional.scheduledSurchargeAriary,
    insuranceRate: TariffGrid.provisional.insuranceRate,
  );
}
