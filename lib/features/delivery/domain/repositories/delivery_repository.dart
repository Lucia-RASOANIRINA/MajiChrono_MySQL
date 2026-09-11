import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Brouillon de course, tel que le construit l'assistant de creation.
class DeliveryDraft {
  const DeliveryDraft({
    required this.pickup,
    required this.dropoff,
    required this.kind,
    required this.package,
    required this.slot,
    required this.paymentMethod,
    this.insuredValueAriary,
    this.payer = Payer.sender,
    this.shopping,
    this.relayPointId,
  });

  final Address pickup;
  final Address dropoff;
  final DeliveryKind kind;
  final PackageDeclaration package;
  final PickupSlot slot;
  final PaymentMethod paymentMethod;
  final int? insuredValueAriary;

  /// Qui paie (EXI-C42), liste de courses (EXI-C07), relais de remise (D6).
  final Payer payer;
  final ShoppingOrder? shopping;
  final String? relayPointId;
}

abstract interface class DeliveryRepository {
  // --- Carnet d'adresses (EXI-C05) -------------------------------------

  /// Flux du carnet, servi par la base locale : il reste disponible hors ligne.
  Stream<List<SavedAddress>> watchAddressBook();

  /// Recharge le carnet depuis le serveur (source de verite) vers le cache
  /// local, puis rend la liste. Le flux [watchAddressBook] s'en trouve rafraichi.
  Future<List<SavedAddress>> fetchAddresses();

  /// Cree ([id] nul) ou met a jour une entree du carnet, cote serveur puis en
  /// cache. Rend l'entree telle que le serveur l'a enregistree.
  Future<SavedAddress> saveAddress({
    String? id,
    required String label,
    required AddressKind kind,
    required Address address,
  });

  Future<void> deleteAddress(String id);

  /// Enregistre l'usage d'une adresse, pour faire remonter les plus frequentes.
  Future<void> touchAddress(String id);

  // --- Courses ----------------------------------------------------------

  /// Cree une course.
  ///
  /// Ecriture locale d'abord, puis mise en file (EXI-C13) : la course existe
  /// pour l'utilisateur des la confirmation, meme sans reseau.
  Future<Delivery> createDelivery(DeliveryDraft draft);

  /// Flux des courses de l'utilisateur, servi par la base locale (EXI-C33).
  Stream<List<Delivery>> watchDeliveries();

  /// Rafraichit depuis le serveur et met a jour le cache local.
  Future<void> refreshDeliveries();

  Future<Delivery?> deliveryById(String id);

  /// Annulation avant prise en charge (EXI-C26).
  /// Annule une course avant sa prise en charge (EXI-C26). Rend les frais
  /// eventuellement retenus (0 si aucun livreur n'etait encore engage).
  Future<int> cancelDelivery(String id, {String? reason});

  /// Televerse la photo du colis (EXI-C09) et rend son identifiant, a joindre a
  /// la declaration de course.
  Future<String> uploadPackagePhoto({
    required List<int> bytes,
    required String contentType,
  });
}
