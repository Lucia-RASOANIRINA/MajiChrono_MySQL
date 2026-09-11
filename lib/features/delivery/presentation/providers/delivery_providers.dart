import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/delivery/data/datasources/delivery_local_data_source.dart';
import 'package:majichrono/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/domain/repositories/delivery_repository.dart';

final deliveryLocalDataSourceProvider = Provider<DeliveryLocalDataSource>(
  (ref) => DeliveryLocalDataSource(ref.watch(appDatabaseProvider)),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepositoryImpl(
    client: ref.watch(apiClientProvider),
    local: ref.watch(deliveryLocalDataSourceProvider),
    queue: ref.watch(syncQueueProvider),
  ),
);

/// Grille tarifaire appliquee.
///
/// Provisoire tant que la decision DO-3 du §19.2 n'est pas arbitree. Isolee
/// dans un provider pour qu'une grille servie par le serveur la remplace sans
/// toucher aux ecrans.
final tariffGridProvider = Provider<TariffGrid>(
  (ref) => TariffGrid.provisional,
);

final addressBookProvider = StreamProvider<List<SavedAddress>>(
  (ref) => ref.watch(deliveryRepositoryProvider).watchAddressBook(),
);

final deliveriesProvider = StreamProvider<List<Delivery>>((ref) async* {
  final repository = ref.watch(deliveryRepositoryProvider);
  // Hydrate le cache a chaque ouverture de session : l'accueil ne doit pas
  // rester vide simplement parce que la course a ete creee sur un autre appareil.
  try {
    await repository.refreshDeliveries();
  } catch (_) {
    // Le cache local reste la source d'affichage hors connexion.
  }
  yield* repository.watchDeliveries();
});

/// Courses en cours, pour l'accueil expediteur.
final activeDeliveriesProvider = Provider<List<Delivery>>((ref) {
  final all = ref.watch(deliveriesProvider).valueOrNull ?? const <Delivery>[];
  return all.where((d) => d.status.isActive).toList();
});
