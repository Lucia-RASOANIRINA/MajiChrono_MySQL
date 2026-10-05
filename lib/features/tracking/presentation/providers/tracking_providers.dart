import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/map/cached_tile_provider.dart';
import 'package:majichrono/core/map/tile_source.dart';
import 'package:majichrono/core/settings/economy_providers.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/tracking/domain/entities/tracking.dart';

/// Fournisseur de tuiles cartographiques.
///
/// Le cache est **range par source** : une tuile d'un fournisseur n'est jamais
/// resservie pour un autre. C'est ce qui purge les images « API KEY REQUIRED »
/// que CARTO renvoyait en production, enregistrees comme de vraies tuiles.
/// Les fichiers de l'ancien rangement (a plat, toutes sources melees) sont
/// supprimes au premier lancement.
///
/// Le mode economie, s'il bloque les tuiles a la demande (EXI-T08), restreint
/// la carte a ce qui est deja en cache.
final tileProviderProvider = FutureProvider<CachedTileProvider>((ref) async {
  final economy = ref.watch(economySettingsProvider);
  final dir = await getApplicationSupportDirectory();
  final root = Directory(p.join(dir.path, 'map_tiles'));
  await _purgeLegacyTiles(root);
  return CachedTileProvider(
    cacheDirectory: Directory(
      p.join(root.path, TileConfig.forBuild().source.name),
    ),
    dataMeter: ref.watch(dataMeterProvider),
    offlineOnly: economy.enabled && economy.blockOnDemandTiles,
  );
});

Future<void> _purgeLegacyTiles(Directory root) async {
  try {
    if (!root.existsSync()) return;
    for (final entity in root.listSync()) {
      if (entity is File) await entity.delete();
    }
  } on FileSystemException {
    // Un fichier qui resiste n'empeche pas la carte de s'afficher.
  }
}

/// Suivi d'une course, rafraichi a cadence adaptative (EXI-C20).
///
/// L'exigence chiffre la cadence : 10 s en 4G, 45 s en 2G. Elle n'est pas
/// arbitraire — en 2G un aller-retour prend deja plus de deux secondes (§4.1),
/// et interroger toutes les dix secondes reviendrait a saturer le lien pour
/// une information qui, a cette vitesse, n'a pas eu le temps de changer. La
/// cadence est donc derivee du **profil reseau mesure par la sonde**, pas d'une
/// constante.
final trackingProvider = StreamProvider.family<TrackingSnapshot, String>((
  ref,
  deliveryId,
) {
  final client = ref.watch(apiClientProvider);
  final controller = StreamController<TrackingSnapshot>();
  Timer? timer;

  Future<void> poll() async {
    try {
      final json = await client.get<Map<String, dynamic>>(
        ApiEndpoints.deliveryTrace(deliveryId),
        category: DataCategory.tracking,
      );
      final snapshot = TrackingSnapshot.fromJson(json);
      if (snapshot != null && !controller.isClosed) controller.add(snapshot);
    } on Failure {
      // Hors ligne, on garde la derniere position connue plutot que d'effacer
      // la carte : une position d'il y a deux minutes reste une information.
    }
  }

  void schedule() {
    timer?.cancel();
    final status = ref.read(networkStatusProvider).valueOrNull;
    final profile = status?.profile ?? NetworkProfile.threeG;
    timer = Timer.periodic(profile.trackingRefreshInterval, (_) => poll());
  }

  // Une mesure reseau qui change reprogramme la cadence : passer de la 4G a la
  // 2G en descendant une vallee doit ralentir le suivi, pas le laisser marteler.
  ref.listen(networkStatusProvider, (_, _) => schedule());

  unawaited(poll());
  schedule();

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Suivi public, sans session (EXI-C24, D9).
final publicTrackingProvider = FutureProvider.family<PublicTracking?, String>((
  ref,
  token,
) async {
  final json = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(
        ApiEndpoints.publicTrack(token),
        category: DataCategory.tracking,
      );
  return PublicTracking.fromJson(json);
});
