import 'dart:convert';

import 'package:majichrono/core/network/api_endpoints.dart';

/// Requete normalisee remise a un gestionnaire simule.
class MockRequest {
  MockRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Object? body;

  Map<String, dynamic> get json => body is Map<String, dynamic>
      ? body! as Map<String, dynamic>
      : <String, dynamic>{};

  String? get idempotencyKey => headers['idempotency-key'];
  String? get bearer {
    final auth = headers['authorization'];
    if (auth == null || !auth.toLowerCase().startsWith('bearer ')) return null;
    return auth.substring(7);
  }

  String get language => headers['accept-language'] ?? 'fr';
}

/// Reponse normalisee produite par un gestionnaire simule.
class MockResponse {
  MockResponse(this.statusCode, this.body, {this.headers = const {}});

  factory MockResponse.ok(Object? body) => MockResponse(200, body);
  factory MockResponse.created(Object? body) => MockResponse(201, body);
  factory MockResponse.noContent() => MockResponse(204, null);

  /// Format d'erreur impose par le §12.1.
  factory MockResponse.error(
    int status,
    String code,
    String message, {
    Map<String, dynamic>? details,
  }) => MockResponse(status, {
    'error': {'code': code, 'message': message, 'details': ?details},
  });

  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;

  List<int> get bytes {
    final b = body;
    if (b == null) return const <int>[];
    // Corps deja binaire (une image servie telle quelle) : on ne le re-encode
    // pas en JSON, on le rend octet pour octet.
    if (b is List<int>) return b;
    return utf8.encode(jsonEncode(b));
  }
}

typedef MockHandler =
    Future<MockResponse> Function(
      MockRequest request,
      Map<String, String> pathParams,
    );

/// Une route simulee : methode + gabarit de chemin (`/deliveries/{id}/accept`).
class MockRoute {
  MockRoute(this.method, this.template, this.handler)
    : _segments = template.split('/').where((s) => s.isNotEmpty).toList();

  final String method;
  final String template;
  final MockHandler handler;
  final List<String> _segments;

  /// Retourne les parametres de chemin si la route correspond, sinon `null`.
  Map<String, String>? match(String method, String path) {
    if (method.toUpperCase() != this.method.toUpperCase()) return null;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != _segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      if (segment.startsWith('{') && segment.endsWith('}')) {
        params[segment.substring(1, segment.length - 1)] = parts[i];
      } else if (segment != parts[i]) {
        return null;
      }
    }
    return params;
  }
}

/// Registre des routes simulees.
///
/// Chaque module d'application enregistre ici ses propres routes via un
/// [MockModule]. Le socle (module 0) n'expose que `/health`.
class MockBackend {
  MockBackend();

  final List<MockRoute> _routes = [];
  final List<MockModule> _modules = [];

  void register(MockModule module) {
    _modules.add(module);
    module.register(this);
  }

  void get(String template, MockHandler handler) =>
      _routes.add(MockRoute('GET', template, handler));
  void post(String template, MockHandler handler) =>
      _routes.add(MockRoute('POST', template, handler));
  void patch(String template, MockHandler handler) =>
      _routes.add(MockRoute('PATCH', template, handler));
  void delete(String template, MockHandler handler) =>
      _routes.add(MockRoute('DELETE', template, handler));

  Future<MockResponse> handle(MockRequest request) async {
    // Le routage suit la **specificite**, pas l'ordre d'enregistrement : une
    // route entierement litterale l'emporte sur une route parametree.
    //
    // Sans cette regle, `/deliveries/available` (EXI-L04) est capture par
    // `/deliveries/{id}` — les deux figurent au §12.2 — et le livreur recoit un
    // 404 « course inconnue » au lieu de sa file d'attente. Le defaut ne depend
    // alors que de l'ordre dans lequel les modules se sont enregistres, ce qui
    // est exactement le genre de fragilite qu'un routeur doit supprimer.
    final matches = <(MockRoute, Map<String, String>)>[];
    for (final route in _routes) {
      final params = route.match(request.method, request.path);
      if (params != null) matches.add((route, params));
    }

    if (matches.isNotEmpty) {
      matches.sort((a, b) => a.$2.length.compareTo(b.$2.length));
      final (route, params) = matches.first;
      return route.handler(request, params);
    }
    return MockResponse.error(
      404,
      'not_found',
      'Aucune route simulee pour ${request.method} ${request.path}',
    );
  }

  Future<void> reset() async {
    for (final module in _modules) {
      await module.reset();
    }
  }

  List<String> get registeredRoutes =>
      _routes.map((r) => '${r.method} ${r.template}').toList();
}

/// Un module de routes simulees. Un module d'application = un [MockModule].
abstract class MockModule {
  void register(MockBackend backend);
  Future<void> reset() async {}
}

/// Module 0 : sonde de sante uniquement.
class CoreMockModule extends MockModule {
  @override
  void register(MockBackend backend) {
    backend.get(ApiEndpoints.health, (req, params) async {
      return MockResponse.ok({
        'status': 'ok',
        'apiVersion': 2,
        'minAppVersion': '1.0.0',
        'serverTime': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }
}
