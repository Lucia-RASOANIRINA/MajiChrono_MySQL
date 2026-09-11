import 'package:dio/dio.dart';
import 'package:majichrono/core/network/api_endpoints.dart';

/// Rejoue une requete refusee pour cause de jeton expire (EXI-T03).
///
/// Le jeton d'acces ne vit que quinze minutes. Sans ce rattrapage, un livreur
/// qui laisse son telephone en poche entre deux courses verrait sa premiere
/// action echouer au retour, et devrait se reconnecter â€” inacceptable au milieu
/// d'un parcours ou chaque etape se valide en trois gestes (Â§15.2.2).
///
/// Trois garde-fous :
///  - une seule reprise par requete, marquee dans `extra`, pour ne jamais
///    boucler si le serveur refuse aussi le jeton renouvele ;
///  - la route de rafraichissement elle-meme est exclue, sous peine de recursion ;
///  - la reprise conserve la **cle d'idempotence d'origine** (posee par
///    `IdempotencyInterceptor` avant cet intercepteur), sans quoi rejouer une
///    ecriture apres expiration produirait un second traitement â€” exactement le
///    double debit qu'interdit EXI-MP06.
class AuthRefreshInterceptor extends QueuedInterceptor {
  AuthRefreshInterceptor({required this._onRefresh, required this._dio});

  static const String _retriedFlag = '_authRetried';

  final Future<String?> Function() _onRefresh;
  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final status = err.response?.statusCode;

    final isAuthRoute =
        options.path.contains(ApiEndpoints.refresh) ||
        options.path.contains(ApiEndpoints.otpVerify) ||
        options.path.contains(ApiEndpoints.otpRequest);

    if (status != 401 || isAuthRoute || options.extra[_retriedFlag] == true) {
      return handler.next(err);
    }

    final String? token;
    try {
      token = await _onRefresh();
    } catch (_) {
      // Le rafraichissement a echoue : l'erreur d'origine reste la bonne, elle
      // se traduira en UnauthorizedFailure et ramenera a l'ecran de connexion.
      return handler.next(err);
    }
    if (token == null) return handler.next(err);

    options.extra[_retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer $token';

    try {
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}
