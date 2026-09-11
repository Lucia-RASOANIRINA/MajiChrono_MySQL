import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/network/error_mapper.dart';

/// Regle 9.3.4 : toute erreur est typee, aucun message technique n'atteint
/// l'utilisateur. Ce test verrouille la traduction transport -> domaine.
void main() {
  final options = RequestOptions(path: '/deliveries');

  DioException badResponse(int status, Map<String, dynamic> body) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );

  test('coupure reseau -> NetworkFailure, reprise pertinente', () {
    final failure = mapDioException(
      DioException.connectionError(requestOptions: options, reason: 'down'),
    );
    expect(failure, isA<NetworkFailure>());
    expect(failure.isRetryable, isTrue);
  });

  test('delai depasse -> TimeoutFailure', () {
    final failure = mapDioException(
      DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(failure, isA<TimeoutFailure>());
  });

  test('401 -> UnauthorizedFailure, non rejouable', () {
    final failure = mapDioException(
      badResponse(401, {
        'error': {'code': 'token_expired', 'message': 'expire'},
      }),
    );
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.isRetryable, isFalse);
  });

  test('409 -> ConflictFailure et l etat serveur est conserve (EXI-S04)', () {
    final failure = mapDioException(
      badResponse(409, {
        'error': {
          'code': 'illegal_transition',
          'message': 'deja livree',
          'details': {'currentState': 'livree'},
        },
      }),
    );
    expect(failure, isA<ConflictFailure>());
    expect((failure as ConflictFailure).currentState, 'livree');
  });

  test('422 -> ValidationFailure champ par champ', () {
    final failure = mapDioException(
      badResponse(422, {
        'error': {
          'code': 'invalid',
          'message': 'saisie refusee',
          'details': {
            'fields': {'landmark': 'obligatoire'},
          },
        },
      }),
    );
    expect(failure, isA<ValidationFailure>());
    expect(
      (failure as ValidationFailure).fieldErrors['landmark'],
      'obligatoire',
    );
  });

  test('426 -> UpdateRequiredFailure avec la version minimale (EXI-B08)', () {
    final failure = mapDioException(
      badResponse(426, {
        'error': {
          'code': 'update_required',
          'message': 'mise a jour',
          'details': {'minAppVersion': '1.4.0'},
        },
      }),
    );
    expect(failure, isA<UpdateRequiredFailure>());
    expect((failure as UpdateRequiredFailure).minVersion, '1.4.0');
  });

  test('503 -> ServerFailure', () {
    final failure = mapDioException(
      badResponse(503, {
        'error': {'code': 'unavailable', 'message': 'indispo'},
      }),
    );
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 503);
  });

  test('une Failure deja typee traverse sans etre reemballee', () {
    const original = StorageFailure();
    expect(identical(mapDioException(original), original), isTrue);
  });
}
