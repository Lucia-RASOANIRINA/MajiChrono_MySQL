import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';

/// Conduite d'un paiement adosse aux soldes MajiPay (§11.2).
///
/// Le mobile ne detient jamais de secret durable : il demande au serveur de
/// creer une intention, recoit un identifiant et un jeton a usage unique, et
/// c'est tout (EXI-MP02). Les soldes sont **lus**, jamais recopies : MajiPay en
/// est la source de verite, et un solde mis en cache afficherait un montant
/// faux au moment de payer.
///
/// Aucune methode de cette classe ne journalise un montant, un solde, un jeton
/// ou une reference de compte (EXI-MP11). Les traces se limitent a l'etat
/// atteint, ce qui suffit a diagnostiquer sans exposer.
class PaymentRepository {
  PaymentRepository({required this._client});

  final ApiClient _client;

  /// Solde MajiPay du role courant.
  Future<MajiPayBalance?> balance(UserRole role) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentBalance,
      query: {'role': _roleName(role)},
      category: DataCategory.payment,
    );
    return MajiPayBalance.fromJson(json);
  }

  /// Journal des paiements du compte courant (§11, EXI-C39).
  ///
  /// Lecture seule : on liste les intentions ou le compte est partie prenante,
  /// les plus recentes d'abord. Une entree illisible est ecartee plutot que de
  /// faire tomber tout le journal.
  Future<List<PaymentHistoryEntry>> history({int limit = 50}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentHistory,
      query: {'limit': '$limit'},
      category: DataCategory.payment,
    );
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentHistoryEntry.fromJson)
        .whereType<PaymentHistoryEntry>()
        .toList();
    return items;
  }

  /// Cree l'intention et retourne le jeton a afficher (EXI-MP02).
  ///
  /// La cle d'idempotence est derivee de la course et du sens : reappuyer sur
  /// « encaisser » ne cree pas une seconde intention pour la meme course, donc
  /// pas un second code encaissable (EXI-MP06).
  Future<PaymentIntent> createIntent({
    required String deliveryId,
    required int amountAriary,
    required PaymentDirection direction,
    required UserRole role,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentIntent,
      body: {
        'deliveryId': deliveryId,
        'amount': amountAriary,
        'direction': direction.wireName,
        'role': _roleName(role),
      },
      idempotencyKey: 'intent_${deliveryId}_${direction.wireName}',
      category: DataCategory.payment,
    );

    final intent = PaymentIntent.fromJson(json);
    if (intent == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info(
      'payment_intent_created',
      data: {'direction': direction.wireName},
    );
    return intent;
  }

  /// Apparie les deux appareils a partir d'un code scanne.
  ///
  /// Pour une demande d'encaissement, l'appariement se contente de reveler le
  /// montant au payeur : rien n'est debite tant qu'il n'a pas confirme. Pour une
  /// offre, le payeur ayant deja donne son accord, le serveur regle dans la
  /// foulee.
  Future<PaymentIntent> claim(ScannedPayment scanned) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentClaim(scanned.intentId),
      body: {'token': scanned.token},
      idempotencyKey: 'claim_${scanned.intentId}',
      category: DataCategory.payment,
    );

    final intent = PaymentIntent.fromJson(json);
    if (intent == null) throw const ServerFailure(statusCode: 500);
    return intent;
  }

  /// Confirmation par le payeur, apres verification de son code sur son propre
  /// appareil.
  ///
  /// C'est le seul point ou l'argent bouge pour une demande d'encaissement. Le
  /// serveur revalide le role : un beneficiaire ne peut pas se payer lui-meme,
  /// meme si le mobile le lui demandait.
  Future<PaymentIntent> confirm(String intentId) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentConfirm(intentId),
      body: {'role': _roleName(UserRole.client)},
      // La cle porte l'intention, pas l'instant : deux appuis sur « confirmer »
      // ne peuvent pas produire deux debits (EXI-MP06).
      idempotencyKey: 'confirm_$intentId',
      category: DataCategory.payment,
    );

    final intent = PaymentIntent.fromJson(json);
    if (intent == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info(
      'payment_settled',
      data: {'status': intent.status.wireName},
    );
    return intent;
  }

  /// Etat courant, pour le sondage de repli (EXI-MP05).
  Future<PaymentIntent> status(String intentId) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.payment(intentId),
      category: DataCategory.payment,
    );
    final intent = PaymentIntent.fromJson(json);
    if (intent == null) throw const ServerFailure(statusCode: 500);
    return intent;
  }

  /// Bascule en especes (EXI-MP08, EXI-C43).
  ///
  /// Toujours disponible, y compris apres un echec MajiPay. Une course bloquee
  /// parce qu'un solde est insuffisant serait un colis immobilise pour une
  /// raison qui ne regarde ni le livreur ni le destinataire.
  Future<PaymentIntent> fallbackToCash(String intentId) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentCash(intentId),
      idempotencyKey: 'cash_$intentId',
      category: DataCategory.payment,
    );

    final intent = PaymentIntent.fromJson(json);
    if (intent == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info('payment_cash_fallback');
    return intent;
  }

  /// Retrait du solde MajiPay du livreur vers un moyen externe (EXI-MP09).
  ///
  /// Le processus est conduit ici ; la sortie d'argent, elle, se fait chez
  /// MajiPay. On ne fait que la declencher et lire le solde restant. La cle
  /// d'idempotence porte le moment du retrait : deux appuis sur « retirer » ne
  /// produisent pas deux sorties.
  Future<WithdrawReceipt> withdraw({
    required int amountAriary,
    String destination = '',
    String? idempotencyKey,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentWithdraw,
      body: {'amount': amountAriary, 'destination': destination},
      idempotencyKey: idempotencyKey ?? 'withdraw_${DateTime.now().millisecondsSinceEpoch}',
      category: DataCategory.payment,
    );

    AppLogger.instance.info('payment_withdraw');
    // Le serveur rend le recu et le solde restant : on ne relit rien de plus.
    final receipt = WithdrawReceipt.fromJson(json);
    if (receipt == null) throw const ServerFailure(statusCode: 500);
    return receipt;
  }

  String _roleName(UserRole role) =>
      role == UserRole.driver ? 'driver' : 'client';
}
