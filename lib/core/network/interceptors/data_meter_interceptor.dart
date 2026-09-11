import 'package:dio/dio.dart';
import 'package:majichrono/core/network/data_meter.dart';

/// Comptabilise les octets reellement echanges (EXI-T07, differenciant D8).
///
/// La categorie est portee par la requete via `options.extra['dataCategory']`;
/// a defaut, l'echange est impute a [DataCategory.api].
class DataMeterInterceptor extends Interceptor {
  DataMeterInterceptor(this._meter);

  static const String extraKey = 'dataCategory';

  final DataMeter _meter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_sentBytes'] =
        _sizeOf(options.data) + _headersSize(options.headers);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(response.requestOptions, response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response);
    handler.next(err);
  }

  void _record(RequestOptions options, Response<dynamic>? response) {
    final category =
        options.extra[extraKey] as DataCategory? ?? DataCategory.api;
    final sent = options.extra['_sentBytes'] as int? ?? 0;
    final receivedHeader = response?.headers.value(Headers.contentLengthHeader);
    final received =
        int.tryParse(receivedHeader ?? '') ?? _sizeOf(response?.data);
    _meter.record(category, sent: sent, received: received);
  }

  int _headersSize(Map<String, dynamic> headers) => headers.entries.fold(
    0,
    (sum, e) => sum + e.key.length + '${e.value}'.length + 4,
  );

  int _sizeOf(Object? data) {
    if (data == null) return 0;
    if (data is List<int>) return data.length;
    if (data is String) return data.length;
    return data.toString().length;
  }
}
