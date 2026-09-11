import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Pose l'en-tete `Idempotency-Key` sur toute ecriture (§12.1, EXI-S01, EXI-B01).
///
/// Deux precautions :
///  - la cle est generee par le client, jamais par le serveur ;
///  - elle est **conservee a l'identique lors des reprises**, sans quoi une
///    reprise apres coupure produirait un second traitement — precisement ce
///    que l'exigence EXI-MP06 interdit pour un paiement.
class IdempotencyInterceptor extends Interceptor {
  IdempotencyInterceptor({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const String header = 'Idempotency-Key';
  static const String extraKey = 'idempotencyKey';

  static const Set<String> _writeMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_writeMethods.contains(options.method.toUpperCase())) {
      // Une cle deja posee (reprise depuis la file de synchronisation) prime.
      final existing =
          options.extra[extraKey] as String? ??
          options.headers[header] as String?;
      final key = existing ?? _uuid.v4();
      options.headers[header] = key;
      options.extra[extraKey] = key;
    }
    handler.next(options);
  }
}
