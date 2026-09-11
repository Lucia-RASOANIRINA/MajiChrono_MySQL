import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:path/path.dart' as p;

/// Fournisseur de tuiles avec cache disque persistant.
///
/// C'est la piece qui rend la carte utilisable a Madagascar. Le §9.2 impose
/// la source raster configuree precisement parce que ses tuiles sont
/// **pre-telechargeables** :
/// une tuile deja vue reste affichable sans reseau, et le §10.1 accorde a ce
/// cache 150 Mo sur 30 jours glissants.
///
/// Trois consequences concretes :
///
///  - un livreur qui repasse dans un quartier deja parcouru garde sa carte,
///    meme en zone blanche ;
///  - les octets economises sont reels et comptes : chaque tuile telechargee
///    est imputee a la categorie « cartes » du compteur de donnees (EXI-T07),
///    ce qui rend le poste visible a l'utilisateur ;
///  - en mode economie (EXI-T08), le fournisseur peut refuser tout
///    telechargement et se contenter de ce qui est deja en cache.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({
    required this.cacheDirectory,
    required this.dataMeter,
    this.maxBytes = 150 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
    this.offlineOnly = false,
    HttpClient? httpClient,
  }) : _client = httpClient ?? HttpClient();

  final Directory cacheDirectory;
  final DataMeter dataMeter;

  /// Budget du cache (§10.1) : 150 Mo.
  final int maxBytes;

  /// Retention (§10.1) : 30 jours glissants.
  final Duration maxAge;

  /// Mode economie : aucune tuile n'est telechargee (EXI-T08).
  final bool offlineOnly;

  final HttpClient _client;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      url: getTileUrl(coordinates, options),
      file: File(
        p.join(
          cacheDirectory.path,
          '${coordinates.z}_${coordinates.x}_${coordinates.y}.png',
        ),
      ),
      provider: this,
    );
  }

  /// Les acces disque sont volontairement **asynchrones**, malgre la regle
  /// `avoid_slow_async_io` qui recommande les variantes synchrones.
  ///
  /// La regle vise le cas general, ou un `existsSync` evite le cout d'un saut
  /// dans la boucle d'evenements. Ici le compromis s'inverse : cette methode est
  /// appelee pour **chaque tuile** d'une carte qui defile, soit plusieurs
  /// dizaines de fois par seconde. Bloquer l'isolat d'interface autant de fois
  /// ferait tomber les 60 images par seconde exiges par EXI-P02, et se verrait
  /// immediatement sur les appareils a 2 Go de RAM du parc local (§4.4).
  // ignore_for_file: avoid_slow_async_io
  Future<Uint8List?> load(String url, File file) async {
    // 1. Cache valide : aucun octet ne part sur le reseau.
    if (await file.exists()) {
      final age = DateTime.now().difference(await file.lastModified());
      if (age < maxAge) return file.readAsBytes();
    }

    // 2. Mode economie : on prefere une tuile perimee a une requete (EXI-T08).
    if (offlineOnly) {
      return await file.exists() ? file.readAsBytes() : null;
    }

    try {
      final request = await _client.getUrl(Uri.parse(url));
      // Les fournisseurs de tuiles exigent un agent identifiant l'application.
      request.headers.set(HttpHeaders.userAgentHeader, 'MajiChrono/1.0 (mg)');
      final response = await request.close();
      if (response.statusCode != 200) return await _fallback(file);

      final bytes = await consolidateHttpClientResponseBytes(response);
      dataMeter.record(DataCategory.maps, received: bytes.length);

      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      unawaited(_enforceBudget());
      return bytes;
    } on Exception catch (error) {
      AppLogger.instance.debug('tile_fetch_failed', data: {'error': '$error'});
      // Hors ligne, une tuile perimee vaut infiniment mieux qu'un carre gris.
      return _fallback(file);
    }
  }

  Future<Uint8List?> _fallback(File file) async =>
      await file.exists() ? file.readAsBytes() : null;

  /// Applique le budget du §10.1 en supprimant les tuiles les plus anciennes.
  Future<void> _enforceBudget() async {
    try {
      if (!cacheDirectory.existsSync()) return;
      final files =
          cacheDirectory
              .listSync()
              .whereType<File>()
              .map((f) => (file: f, stat: f.statSync()))
              .toList()
            ..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

      var total = files.fold<int>(0, (sum, e) => sum + e.stat.size);
      final cutoff = DateTime.now().subtract(maxAge);

      for (final entry in files) {
        if (total <= maxBytes && entry.stat.modified.isAfter(cutoff)) break;
        total -= entry.stat.size;
        await entry.file.delete();
      }
    } on Exception catch (error) {
      AppLogger.instance.debug(
        'tile_cache_purge_failed',
        data: {'error': '$error'},
      );
    }
  }

  /// Taille actuelle du cache, affichee dans les reglages.
  Future<int> cacheSizeBytes() async {
    if (!cacheDirectory.existsSync()) return 0;
    return cacheDirectory.listSync().whereType<File>().fold<int>(
      0,
      (sum, f) => sum + f.lengthSync(),
    );
  }

  Future<void> clearCache() async {
    if (cacheDirectory.existsSync()) {
      await cacheDirectory.delete(recursive: true);
    }
  }
}

/// Image de tuile servie par le cache disque, puis par le reseau.
class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({
    required this.url,
    required this.file,
    required this.provider,
  });

  final String url;
  final File file;
  final CachedTileProvider provider;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await provider.load(url, file);
    if (bytes == null || bytes.isEmpty) {
      // Aucune tuile disponible : on rend un pixel transparent plutot que de
      // laisser l'exception remonter et casser le rendu de toute la carte.
      // La degradation visuelle est annoncee par l'ecran (§15.3).
      return decode(
        await ui.ImmutableBuffer.fromUint8List(_transparentPixelPng),
      );
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// PNG 1x1 entierement transparent.
final Uint8List _transparentPixelPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
