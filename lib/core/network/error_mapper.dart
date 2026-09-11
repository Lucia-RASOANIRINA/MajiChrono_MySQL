import 'package:dio/dio.dart';
import 'package:majichrono/core/error/failure.dart';

/// Traduit toute exception de transport en [Failure] typee (regle 9.3.4).
///
/// C'est la frontiere du socle : au-dessus de cette fonction, plus aucune
/// couche ne connait Dio.
Failure mapDioException(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;

  if (error is! DioException) {
    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  final response = error.response;
  final details = <String, Object?>{
    'path': error.requestOptions.path,
    'method': error.requestOptions.method,
  };

  // Volontairement en chaine de conditions plutot qu'en `switch` exhaustif :
  // `DioExceptionType` gagne des valeurs d'une version de Dio a l'autre, et une
  // nouvelle valeur ne doit pas casser la compilation du socle.
  const timeouts = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  };
  const transportFailures = {
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
    DioExceptionType.badCertificate,
  };

  if (timeouts.contains(error.type)) {
    return TimeoutFailure(
      cause: error,
      stackTrace: stackTrace,
      details: details,
    );
  }
  if (transportFailures.contains(error.type) ||
      (error.type != DioExceptionType.badResponse && response == null)) {
    return NetworkFailure(
      cause: error,
      stackTrace: stackTrace,
      details: details,
    );
  }

  final status = response?.statusCode ?? 0;
  final payload = _errorPayload(response?.data);
  final code = payload['code'] as String?;
  final apiDetails = payload['details'] as Map<String, dynamic>?;

  return switch (status) {
    400 || 422 => ValidationFailure(
      fieldErrors: _fieldErrors(apiDetails),
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
    401 || 403 => UnauthorizedFailure(
      code: code,
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
    409 => ConflictFailure(
      currentState: apiDetails?['currentState'] as String?,
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
    426 => UpdateRequiredFailure(
      minVersion: apiDetails?['minAppVersion'] as String?,
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
    >= 500 => ServerFailure(
      statusCode: status,
      code: code,
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
    _ => ServerFailure(
      statusCode: status,
      code: code,
      cause: error,
      stackTrace: stackTrace,
      details: details,
    ),
  };
}

Map<String, dynamic> _errorPayload(Object? data) {
  if (data is Map && data['error'] is Map) {
    return Map<String, dynamic>.from(data['error'] as Map);
  }
  return const {};
}

Map<String, String> _fieldErrors(Map<String, dynamic>? details) {
  final fields = details?['fields'];
  if (fields is Map) {
    return fields.map((key, value) => MapEntry('$key', '$value'));
  }
  return const {};
}
