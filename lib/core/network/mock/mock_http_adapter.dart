import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/network_profile.dart';

/// Transport simule.
///
/// Le choix d'implementer un [HttpClientAdapter] plutot qu'un intercepteur est
/// deliberé : toute la pile Dio reelle — intercepteurs d'authentification,
/// d'idempotence, de reprise, compteur de donnees — est traversee a
/// l'identique. Seul l'octet qui part sur le reseau est remplace. Le passage de
/// `mock` a `live` ne modifie donc aucune ligne des couches superieures.
///
/// L'adaptateur simule egalement le reseau malgache (§4.1) : latence par
/// profil, temps de transfert proportionnel au corps, coupures injectees.
/// C'est ce qui rend jouables les scenarios de recette du §16.2.
class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter({
    required this.backend,
    this.profile = NetworkProfile.fourG,
    double failureRate = 0,
    Random? random,
  }) : _failureRate = failureRate.clamp(0, 1),
       _random = random ?? Random();

  final MockBackend backend;
  final Random _random;

  /// Profil applique aux prochaines requetes, pilote par le panneau developpeur.
  NetworkProfile profile;

  double _failureRate;

  double get failureRate => _failureRate;

  /// Borne a [0, 1] : un taux hors bornes rendrait la simulation incoherente.
  set failureRate(double value) => _failureRate = value.clamp(0, 1);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 1. Coupure totale : on rejoue exactement ce que produit un vrai socket mort.
    if (!profile.isOnline) {
      await _sleep(150);
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Reseau simule indisponible',
      );
    }

    // 2. Latence d'aller-retour du profil.
    await _sleep(_latencyMs());

    // 3. Echec injecte (reseau instable, scenario §16.2-3).
    if (_failureRate > 0 && _random.nextDouble() < _failureRate) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Coupure simulee en cours de requete',
      );
    }

    final request = MockRequest(
      method: options.method,
      path: _pathOf(options),
      query: options.queryParameters.map(
        (key, value) => MapEntry(key, '$value'),
      ),
      headers: {
        for (final entry in options.headers.entries)
          entry.key.toLowerCase(): '${entry.value}',
      },
      body: await _decodeBody(options, requestStream),
    );

    final MockResponse response;
    try {
      response = await backend.handle(request);
    } catch (error, stack) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {
            'code': 'mock_handler_crash',
            'message': '$error',
            'details': {'stack': '$stack'},
          },
        }),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 4. Temps de transfert du corps, proportionnel au debit du profil.
    final bytes = response.bytes;
    await _sleep(_transferMs(bytes.length));

    return ResponseBody.fromBytes(
      bytes,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['${bytes.length}'],
        ...response.headers,
      },
    );
  }

  String _pathOf(RequestOptions options) {
    final uri = options.uri;
    var path = uri.path;
    // Retire le prefixe de version present dans l'URL de base (`/v2`).
    final base = Uri.parse(options.baseUrl).path;
    if (base.isNotEmpty && base != '/' && path.startsWith(base)) {
      path = path.substring(base.length);
    }
    return path.isEmpty ? '/' : path;
  }

  Future<Object?> _decodeBody(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    if (requestStream == null) return null;
    final chunks = <int>[];
    await for (final chunk in requestStream) {
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) return null;
    final raw = utf8.decode(chunks, allowMalformed: true);
    final contentType = '${options.headers[Headers.contentTypeHeader] ?? ''}';
    if (contentType.contains('json')) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  int _latencyMs() {
    final span = profile.maxLatencyMs - profile.minLatencyMs;
    return profile.minLatencyMs + (span <= 0 ? 0 : _random.nextInt(span));
  }

  int _transferMs(int bytes) {
    if (profile.kbps <= 0 || bytes <= 0) return 0;
    return (bytes * 8 / (profile.kbps * 1000) * 1000).round();
  }

  Future<void> _sleep(int ms) => ms <= 0
      ? Future<void>.value()
      : Future<void>.delayed(Duration(milliseconds: ms));

  @override
  void close({bool force = false}) {}
}
