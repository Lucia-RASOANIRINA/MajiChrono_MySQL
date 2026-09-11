import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';

/// Groupage de courses sur un meme axe (EXI-L06, differenciant D7).
///
/// Le groupage n'est pas « accepter plusieurs courses » : c'est accepter
/// plusieurs courses **dont les trajets se recouvrent**. Deux colis qui partent
/// dans des directions opposees ne se groupent pas — ils s'additionnent, et le
/// livreur perd sur les deux.
///
/// La regle de recevabilite est donc geometrique, et elle est verifiee ici
/// plutot que laissee au jugement d'un livreur qui accepte a la volee, en
/// trente secondes, sous la pluie.
class DeliveryGroup {
  const DeliveryGroup({required this.deliveries});

  final List<Delivery> deliveries;

  /// Deux a trois courses (EXI-L06).
  ///
  /// Le plafond n'est pas arbitraire : au-dela de trois, l'ordre des arrets
  /// devient un probleme d'optimisation que personne ne resout de tete, et le
  /// risque d'intervertir deux colis grimpe. Trois tient dans un top-case et
  /// dans une memoire.
  static const int minSize = 2;
  static const int maxSize = 3;

  /// Detour maximal tolere, en kilometres.
  ///
  /// Compare au trajet le plus long du groupe : au-dela, ce n'est plus un
  /// groupage, c'est une seconde course deguisee.
  static const double maxDetourKm = 3;

  int get size => deliveries.length;

  bool get hasAcceptableSize => size >= minSize && size <= maxSize;

  /// Somme des gains estimes.
  int get totalPriceAriary =>
      deliveries.fold(0, (sum, d) => sum + (d.priceAriary ?? 0));

  /// Distance cumulee si les courses etaient faites separement.
  double get separateDistanceKm =>
      deliveries.fold(0, (sum, d) => sum + d.distanceKm);

  /// Distance du parcours groupe : tous les retraits, puis toutes les remises.
  ///
  /// L'ordre n'est pas une optimisation fine — c'est le seul qui garantisse
  /// qu'aucun colis n'est livre avant d'avoir ete pris.
  double get groupedDistanceKm {
    if (deliveries.isEmpty) return 0;

    final stops = <GeoPoint>[
      ...deliveries.map((d) => d.pickup.point),
      ...deliveries.map((d) => d.dropoff.point),
    ];

    var total = 0.0;
    for (var i = 0; i < stops.length - 1; i++) {
      total += stops[i].distanceKmTo(stops[i + 1]);
    }
    return total;
  }

  /// Kilometres economises par rapport a deux courses separees.
  ///
  /// C'est le seul chiffre qui interesse le livreur : le gain a l'heure, pas le
  /// gain a la course.
  double get savedKm => separateDistanceKm - groupedDistanceKm;

  /// Detour impose au trajet le plus long du groupe.
  double get detourKm {
    if (deliveries.isEmpty) return 0;
    final longest = deliveries
        .map((d) => d.distanceKm)
        .reduce((a, b) => a > b ? a : b);
    return groupedDistanceKm - longest;
  }

  /// Le groupe est-il recevable ?
  ///
  /// Trois conditions, toutes necessaires : la taille, un detour raisonnable,
  /// et un gain reel. Un groupage qui ne fait pas gagner de kilometres n'a
  /// aucune raison d'exister — il ajoute seulement du risque d'erreur.
  bool get isViable =>
      hasAcceptableSize && detourKm <= maxDetourKm && savedKm > 0;

  /// Ordre des arrets a presenter au livreur.
  ///
  /// Tous les retraits d'abord, puis toutes les remises. Un livreur qui livre
  /// avant d'avoir tout pris devra revenir, et l'interet du groupage disparait.
  List<GroupStop> get stops => [
    for (final delivery in deliveries)
      GroupStop(
        deliveryId: delivery.id,
        kind: GroupStopKind.pickup,
        point: delivery.pickup.point,
        label: delivery.pickup.landmark,
        district: delivery.pickup.district,
      ),
    for (final delivery in deliveries)
      GroupStop(
        deliveryId: delivery.id,
        kind: GroupStopKind.dropoff,
        point: delivery.dropoff.point,
        label: delivery.dropoff.landmark,
        district: delivery.dropoff.district,
      ),
  ];

  /// Peut-on ajouter cette course au groupe ?
  bool accepts(Delivery candidate) {
    if (size >= maxSize) return false;
    if (deliveries.any((d) => d.id == candidate.id)) return false;

    final enlarged = DeliveryGroup(deliveries: [...deliveries, candidate]);
    return enlarged.detourKm <= maxDetourKm && enlarged.savedKm > 0;
  }
}

enum GroupStopKind {
  pickup('pickup'),
  dropoff('dropoff');

  const GroupStopKind(this.wireName);

  final String wireName;
}

/// Un arret du parcours groupe.
class GroupStop {
  const GroupStop({
    required this.deliveryId,
    required this.kind,
    required this.point,
    required this.label,
    required this.district,
  });

  final String deliveryId;
  final GroupStopKind kind;
  final GeoPoint point;
  final String label;
  final String district;
}
