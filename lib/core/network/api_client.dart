import 'dart:io';

import 'package:dio/dio.dart';
import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/network/error_mapper.dart';
import 'package:majichrono/core/network/interceptors/auth_refresh_interceptor.dart';
import 'package:majichrono/core/network/interceptors/data_meter_interceptor.dart';
import 'package:majichrono/core/network/interceptors/idempotency_interceptor.dart';
import 'package:majichrono/core/network/interceptors/logging_interceptor.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/core/network/mock/mock_http_adapter.dart';
import 'package:majichrono/core/network/network_profile.dart';

/// Client HTTP unique de l'application.
///
/// Aucune couche superieure n'instancie de Dio : elles recoivent [ApiClient] et
/// n'obtiennent en retour que des donnees ou des [Failure].
class ApiClient {
  ApiClient({
    required AppConfig config,
    required DataMeter dataMeter,
    required MockBackend mockBackend,
    AppLogger? logger,
    String Function()? languageProvider,
    String? Function()? accessTokenProvider,
    // Injection d'un transport simule preconfigure (profil, aleatoire fige),
    // reservee aux tests : elle permet de rejouer un reseau donne a l'identique.
    MockHttpAdapter? mockAdapter,
  }) : _config = config,
       _mockBackend = mockBackend,
       _languageProvider = languageProvider ?? (() => 'fr'),
       _accessTokenProvider = accessTokenProvider ?? (() => null) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        // Genereux a dessein : un hebergement mutualise peut mettre du temps
        // a reveiller l'application apres une periode d'inactivite.
        connectTimeout: const Duration(seconds: 30),
        // En 2G un corps de constat met aussi plusieurs dizaines de secondes.
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 90),
        headers: {Headers.contentTypeHeader: Headers.jsonContentType},
        // Tous les statuts remontent : c'est `mapDioException` qui tranche.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    if (config.isMock || mockAdapter != null) {
      _mockAdapter = mockAdapter ?? MockHttpAdapter(backend: mockBackend);
      _dio.httpClientAdapter = _mockAdapter!;
    }

    _dio.interceptors.addAll([
      InterceptorsWrapper(onRequest: _decorateRequest),
      IdempotencyInterceptor(),
      DataMeterInterceptor(dataMeter),
      LoggingInterceptor(logger ?? AppLogger.instance),
    ]);
  }

  /// Branche le rattrapage de jeton expire (EXI-T03).
  ///
  /// Pose apres coup, et non dans le constructeur, parce que le rafraichissement
  /// est assure par le repository d'authentification, lequel a besoin de ce
  /// meme client pour appeler `/auth/refresh` : les brancher ensemble a la
  /// construction creerait un cycle.
  void attachRefreshHandler(Future<String?> Function() onRefresh) {
    _dio.interceptors.add(
      AuthRefreshInterceptor(onRefresh: onRefresh, dio: _dio),
    );
  }

  final AppConfig _config;
  final MockBackend _mockBackend;
  final String Function() _languageProvider;
  final String? Function() _accessTokenProvider;

  late final Dio _dio;
  MockHttpAdapter? _mockAdapter;

  Dio get dio => _dio;
  MockBackend get mockBackend => _mockBackend;

  /// Profil reseau simule, pilotable depuis le panneau developpeur (§16.2).
  NetworkProfile get simulatedProfile =>
      _mockAdapter?.profile ?? NetworkProfile.fourG;

  set simulatedProfile(NetworkProfile value) => _mockAdapter?.profile = value;

  double get simulatedFailureRate => _mockAdapter?.failureRate ?? 0;
  set simulatedFailureRate(double value) => _mockAdapter?.failureRate = value;

  void _decorateRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.headers['Accept-Language'] = _languageProvider();
    // Libelle d'appareil : sert a nommer la session dans la liste des appareils
    // connectes. Best-effort, sans dependance supplementaire — le systeme et sa
    // version suffisent a distinguer « cet appareil-ci » des autres.
    options.headers['X-Device'] = _deviceLabel;
    final token = _accessTokenProvider();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  static final String _deviceLabel = _computeDeviceLabel();

  static String _computeDeviceLabel() {
    try {
      final os = switch (Platform.operatingSystem) {
        'android' => 'Android',
        'ios' => 'iOS',
        'macos' => 'macOS',
        'windows' => 'Windows',
        'linux' => 'Linux',
        final other => other,
      };
      final version = Platform.operatingSystemVersion.trim();
      return version.isEmpty ? os : '$os - ${version.split(RegExp(r"[ (]")).first}';
    } catch (_) {
      return 'Appareil';
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    DataCategory category = DataCategory.api,
    CancelToken? cancelToken,
  }) => _run<T>(
    () => _dio.get<T>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
      options: Options(extra: {DataMeterInterceptor.extraKey: category}),
    ),
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    DataCategory category = DataCategory.api,
    CancelToken? cancelToken,
  }) => _run<T>(
    () => _dio.post<T>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
      options: Options(
        extra: {
          DataMeterInterceptor.extraKey: category,
          IdempotencyInterceptor.extraKey: ?idempotencyKey,
        },
      ),
    ),
  );

  Future<T> patch<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    DataCategory category = DataCategory.api,
  }) => _run<T>(
    () => _dio.patch<T>(
      path,
      data: body,
      options: Options(
        extra: {
          DataMeterInterceptor.extraKey: category,
          IdempotencyInterceptor.extraKey: ?idempotencyKey,
        },
      ),
    ),
  );

  Future<T> delete<T>(
    String path, {
    Object? body,
    DataCategory category = DataCategory.api,
  }) => _run<T>(
    () => _dio.delete<T>(
      path,
      data: body,
      options: Options(extra: {DataMeterInterceptor.extraKey: category}),
    ),
  );

  /// Recupere un corps binaire (une image servie par l'API, avec le jeton pose
  /// par l'intercepteur). Sert a afficher une piece KYC protegee, qu'une balise
  /// image ne saurait charger seule faute d'en-tete d'autorisation.
  Future<List<int>> getBytes(String path) => _run<List<int>>(
    () => _dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        extra: {DataMeterInterceptor.extraKey: DataCategory.api},
      ),
    ),
  );

  Future<T> _run<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } catch (error, stackTrace) {
      AppLogger.instance.warn('http_request_failed', error: error);
      throw mapDioException(error, stackTrace);
    }
  }

  /// Sonde applicative : le seul etat systeme ment (§9.2, `connectivity_plus`).
  ///
  /// Retourne le temps d'aller-retour mesure, ou `null` si le serveur est
  /// injoignable. C'est ce chiffre qui qualifie le profil reseau reel.
  Future<int?> probe() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final started = DateTime.now();
      try {
        await get<Map<String, dynamic>>('/health');
        return DateTime.now().difference(started).inMilliseconds;
      } on Failure {
        // The hosted API currently does not publish `/health`, but its
        // authentication route is available and returns 405 for a GET.
        try {
          final response = await _dio.get<Object?>(
            '/auth/login',
            options: Options(validateStatus: (status) => status != null && status < 500),
          );
          if (response.statusCode != null) {
            return DateTime.now().difference(started).inMilliseconds;
          }
        } on DioException {
          // Retry below; a connection error still means the API is offline.
        }
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    return null;
  }

  AppConfig get config => _config;
}
