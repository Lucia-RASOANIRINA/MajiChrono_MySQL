import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/map/cached_tile_provider.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/tracking/domain/entities/tracking.dart';

/// Fournisseur de tuiles cartographiques, cree une seule fois.
final tileProviderProvider = FutureProvider<CachedTileProvider>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return CachedTileProvider(
    cacheDirectory: Directory(p.join(dir.path, 'map_tiles')),
    dataMeter: ref.watch(dataMeterProvider),
  );
});

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
