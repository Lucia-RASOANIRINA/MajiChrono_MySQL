// `hide Column` : drift et Material exposent tous deux un type `Column`.
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/network_status.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/core/storage/prefs_store.dart';
import 'package:majichrono/core/storage/secure_store.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/core/sync/sync_scheduler.dart';
import 'package:majichrono/features/admin/data/mock/admin_mock_module.dart';
import 'package:majichrono/features/auth/data/mock/auth_mock_module.dart';
import 'package:majichrono/features/custody/data/mock/custody_mock_module.dart';
import 'package:majichrono/features/delivery/data/mock/addresses_mock_module.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/chat/data/chat_mock_module.dart';
import 'package:majichrono/features/delivery/data/mock/reviews_mock_module.dart';
import 'package:majichrono/features/driver/data/mock/differentiators_mock_module.dart';
import 'package:majichrono/features/driver/data/mock/driver_mock_module.dart';
import 'package:majichrono/features/payment/data/mock/payment_mock_module.dart';
import 'package:majichrono/features/tracking/data/mock/tracking_mock_module.dart';

/// Injection de dependances : Riverpod est le seul mecanisme (§9.1).
///
/// Les quatre providers ci-dessous n'ont pas de valeur par defaut : ils sont
/// surcharges au demarrage par `bootstrap()`, apres initialisation asynchrone.
/// Cela evite tout `FutureProvider` a la racine et garantit qu'aucun ecran ne
/// s'affiche avant que le socle ne soit pret.

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('Surcharge par bootstrap()'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Surcharge par bootstrap()'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Surcharge par bootstrap()'),
);

final dataMeterProvider = Provider<DataMeter>(
  (ref) => throw UnimplementedError('Surcharge par bootstrap()'),
);

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger.instance);

final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => PrefsStore(ref.watch(sharedPreferencesProvider)),
);

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Registre des routes simulees. Chaque module y ajoute les siennes.
final mockBackendProvider = Provider<MockBackend>((ref) {
  final deliveries = DeliveryMockModule();
  return MockBackend()
    ..register(CoreMockModule())
    ..register(AuthMockModule())
    ..register(deliveries)
    // Le suivi lit le registre du module de livraison plutot que d'en tenir
    // une copie : deux registres finiraient par diverger, et le suivi
    // afficherait un statut que la liste ne connait pas.
    ..register(TrackingMockModule(deliveries: () => deliveries.store))
    // En simulation, le livreur est deja valide : le parcours complet (accepter,
    // executer, constat, incident) doit se derouler sans exploitation en face
    // pour approuver le dossier. Le blocage a l'acceptation pour un dossier non
    // valide (EXI-L01) reste verifie cote serveur et en test.
    ..register(
      DriverMockModule(
        deliveries: () => deliveries.store,
        kycStatus: 'approved',
      ),
    )
    ..register(CustodyMockModule())
    ..register(PaymentMockModule())
    ..register(AddressesMockModule())
    ..register(ReviewsMockModule())
    ..register(ChatMockModule())
    ..register(AdminMockModule(deliveries: () => deliveries.store))
    ..register(DifferentiatorsMockModule());
});

/// Jeton d'acces courant. Alimente par le module 1 (authentification) ;
/// declare ici parce que le client HTTP en depend des le socle.
final accessTokenProvider = StateProvider<String?>((ref) => null);

/// Langue active, exposee separement du controleur pour eviter un cycle entre
/// le client HTTP (en-tete `Accept-Language`) et la couche presentation.
final activeLanguageCodeProvider = StateProvider<String>((ref) => 'fr');

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(appConfigProvider),
    dataMeter: ref.watch(dataMeterProvider),
    mockBackend: ref.watch(mockBackendProvider),
    logger: ref.watch(appLoggerProvider),
    languageProvider: () => ref.read(activeLanguageCodeProvider),
    accessTokenProvider: () => ref.read(accessTokenProvider),
  );
  return client;
});

final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService(apiClient: ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Etat reseau consomme par le bandeau permanent (EXI-T06).
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkStatusServiceProvider);
  // Demarrage differe : la premiere sonde ne doit pas retarder le premier
  // rendu (EXI-P01 : ecran interactif en moins de 2,5 s).
  Future<void>.delayed(
    const Duration(milliseconds: 300),
    () => service.start(),
  );
  return service.stream;
});

/// File de synchronisation (§10.2). Rien ne part sur le reseau sans y passer.
final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(ref.watch(appDatabaseProvider)),
);

/// Ordonnanceur de la file. Il se declenche au retour du reseau (EXI-S02).
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    queue: ref.watch(syncQueueProvider),
    client: ref.watch(apiClientProvider),
    // On passe le flux du service plutot que le provider : l'ordonnanceur ne
    // doit pas dependre du cycle de vie d'un widget.
    networkStatus: ref.watch(networkStatusServiceProvider).stream,
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Elements en attente, tries par priorite puis anciennete (EXI-S06).
final pendingItemsProvider = StreamProvider<List<SyncItem>>(
  (ref) => ref.watch(syncQueueProvider).watchOutstanding(),
);

/// Nombre d'elements en attente de synchronisation, affiche dans le bandeau.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.selectOnly(db.syncQueueItems)
    ..addColumns([db.syncQueueItems.id.count()])
    ..where(db.syncQueueItems.status.isNotIn(['abandoned']));
  return query
      .map((row) => row.read(db.syncQueueItems.id.count()) ?? 0)
      .watchSingle();
});

/// Mode d'apparence, persiste entre deux lancements.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .watch(prefsStoreProvider)
        .getString(PrefsStore.keyThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(prefsStoreProvider)
        .setString(PrefsStore.keyThemeMode, mode.name);
  }
}
