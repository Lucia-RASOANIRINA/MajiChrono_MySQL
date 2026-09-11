import 'package:dio/dio.dart';
import 'package:majichrono/core/logging/app_logger.dart';

/// Journalise les echanges reseau **expurges** (EXI-T10, EXI-MP11).
///
/// Ni corps, ni en-tetes sensibles : seuls la methode, le chemin, le statut et
/// la duree sont conserves. Le chemin lui-meme passe par l'expurgation, car il
/// peut porter un jeton (`/public/track/{jeton}`).
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_startedAt'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.info(
      'http',
      data: {
        'method': response.requestOptions.method,
        'path': AppLogger.redact(response.requestOptions.path),
        'status': response.statusCode,
        'ms': _elapsed(response.requestOptions),
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn(
      'http_error',
      data: {
        'method': err.requestOptions.method,
        'path': AppLogger.redact(err.requestOptions.path),
        'status': err.response?.statusCode,
        'type': err.type.name,
        'ms': _elapsed(err.requestOptions),
      },
      error: err.error,
    );
    handler.next(err);
  }

  int _elapsed(RequestOptions options) {
    final startedAt = options.extra['_startedAt'] as int?;
    if (startedAt == null) return -1;
    return DateTime.now().millisecondsSinceEpoch - startedAt;
  }
}
