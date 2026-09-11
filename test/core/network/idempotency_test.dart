import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majichrono/core/network/interceptors/idempotency_interceptor.dart';

/// EXI-S01 / EXI-B01 / EXI-MP06.
///
/// Le point critique n'est pas qu'une cle soit posee, mais qu'elle **ne change
/// pas** entre deux tentatives. Une cle regeneree a chaque reprise produirait
/// exactement le double debit que le cahier des charges interdit.
void main() {
  late Dio dio;
  final captured = <RequestOptions>[];

  setUp(() {
    captured.clear();
    dio = Dio(BaseOptions(baseUrl: 'https://exemple.test'))
      ..interceptors.add(IdempotencyInterceptor())
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
          },
        ),
      );
  });

  test('une ecriture porte une cle d idempotence', () async {
    await dio.post<dynamic>('/deliveries', data: {'a': 1});

    final key = captured.single.headers[IdempotencyInterceptor.header];
    expect(key, isNotNull);
    expect('$key'.length, greaterThan(20));
  });

  test('une lecture n en porte pas', () async {
    await dio.get<dynamic>('/deliveries');
    expect(captured.single.headers.containsKey(IdempotencyInterceptor.header), isFalse);
  });

  test('deux ecritures distinctes portent deux cles differentes', () async {
    await dio.post<dynamic>('/deliveries', data: {'a': 1});
    await dio.post<dynamic>('/deliveries', data: {'a': 2});

    expect(
      captured[0].headers[IdempotencyInterceptor.header],
      isNot(captured[1].headers[IdempotencyInterceptor.header]),
    );
  });

  test('une reprise reutilise la cle d origine — aucun double traitement', () async {
    const rejouee = 'cle-figee-par-la-file-de-synchronisation';

    await dio.post<dynamic>(
      '/payments/intent',
      data: {'amount': 12000},
      options: Options(extra: {IdempotencyInterceptor.extraKey: rejouee}),
    );
    await dio.post<dynamic>(
      '/payments/intent',
      data: {'amount': 12000},
      options: Options(extra: {IdempotencyInterceptor.extraKey: rejouee}),
    );

    expect(captured[0].headers[IdempotencyInterceptor.header], rejouee);
    expect(captured[1].headers[IdempotencyInterceptor.header], rejouee);
  });
}
