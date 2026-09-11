import 'dart:math';

import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';

/// Routes simulees du paiement adosse a MajiPay (§11.2).
///
/// Le simulateur tient deux choses que le mobile ne doit jamais tenir : les
/// **soldes** et les **jetons**. C'est ce qui rend le contrat verifiable avant
/// que le vrai MajiPay n'existe (EXI-MP12), et surtout ce qui permet de
/// verifier que le mobile ne peut pas debiter tout seul.
///
/// Trois refus font l'essentiel de la valeur de ce simulateur :
///
///  - un jeton faux ou perime n'apparie rien ;
///  - une confirmation venant d'ailleurs que du payeur est rejetee ;
///  - une intention deja capturee n'est jamais debitee deux fois (EXI-MP06).
class PaymentMockModule extends MockModule {
  PaymentMockModule({Random? random}) : _random = random ?? Random(1789);

  final Random _random;

  /// Soldes MajiPay, par utilisateur. Le client demarre avec de quoi payer
  /// quelques courses, le livreur avec ses recettes du jour.
  final Map<String, int> _balances = {'client': 42000, 'driver': 18500};

  final Map<String, Map<String, dynamic>> _intents = {};

  /// Cles d'idempotence deja honorees, avec la reponse servie (EXI-MP06).
  final Map<String, Map<String, dynamic>> _captured = {};

  /// Intentions deja creees, par cle d'idempotence.
  ///
  /// Sans ce registre, deux appuis sur « encaisser » produiraient deux codes
  /// encaissables pour la meme course : le premier scanne debiterait, et le
  /// second resterait en circulation, pret a debiter une seconde fois.
  final Map<String, String> _intentsByKey = {};

  int _sequence = 0;

  @override
  void register(MockBackend backend) {
    backend.get('/payments/balance', _balance);
    // Avant `/payments/{id}` : sinon « history » serait pris pour un id.
    backend.get('/payments/history', _history);
    backend.post('/payments/intent', _createIntent);
    backend.get('/payments/{id}', _read);
    backend.post('/payments/{id}/claim', _claim);
    backend.post('/payments/{id}/confirm', _confirm);
    backend.post('/payments/{id}/cash', _cash);
  }

  @override
  Future<void> reset() async {
    _intents.clear();
    _captured.clear();
    _intentsByKey.clear();
    _sequence = 0;
    _balances
      ..['client'] = 42000
      ..['driver'] = 18500;
  }

  String _role(MockRequest req) =>
      req.query['role'] ?? '${req.json['role'] ?? 'client'}';

  Future<MockResponse> _balance(MockRequest req, Map<String, String> _) async {
    final role = _role(req);
    return MockResponse.ok({
      'available': _balances[role] ?? 0,
      // Reference masquee : le numero complet n'a aucune raison de transiter
      // (EXI-MP11).
      'accountRef': 'MP ** ** ${role == 'driver' ? '7734' : '4821'}',
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Journal des paiements (§11, EXI-C39).
  ///
  /// Le simulateur ne distingue qu'un client et un livreur : le client est
  /// toujours payeur, le livreur toujours beneficiaire. On rend donc toutes les
  /// intentions connues, les plus recentes d'abord, avec le `role` attendu.
  Future<MockResponse> _history(MockRequest req, Map<String, String> _) async {
    final role = _role(req);
    final items = _intents.values.map(_public).toList()
      ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    final withRole = items
        .map((it) => {...it, 'role': role == 'driver' ? 'payee' : 'payer'})
        .toList();
    return MockResponse.ok({'items': withRole});
  }

  Future<MockResponse> _createIntent(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final body = req.json;
    final amount = (body['amount'] as num?)?.toInt() ?? 0;
    final deliveryId = '${body['deliveryId'] ?? ''}';
    final direction = PaymentDirection.fromWire(body['direction'] as String?);

    if (amount <= 0) {
      return MockResponse.error(422, 'invalid_amount', 'Montant invalide');
    }

    // EXI-MP06 : la meme cle rend la meme intention, jeton compris. Le
    // demandeur retrouve son code au lieu d'en obtenir un second.
    final key = req.idempotencyKey;
    final existingId = key == null ? null : _intentsByKey[key];
    if (existingId != null) {
      final existing = _intents[existingId];
      if (existing != null) {
        _expireIfNeeded(existing);
        return MockResponse.created({
          ..._public(existing),
          'token': existing['_token'],
        });
      }
    }

    // Une offre est pre-autorisee par le client : le solde est verifie des la
    // creation, pour ne pas afficher un code que personne ne pourra encaisser.
    if (direction.payerPreAuthorized && (_balances['client'] ?? 0) < amount) {
      return MockResponse.error(
        422,
        'insufficient_funds',
        'Solde MajiPay insuffisant',
        details: {'failure': PaymentFailure.insufficientFunds.wireName},
      );
    }

    final id = 'pay_${++_sequence}';
    final now = DateTime.now();
    final token = List.generate(
      16,
      (_) => '0123456789abcdef'[_random.nextInt(16)],
    ).join();

    final intent = <String, dynamic>{
      'id': id,
      'deliveryId': deliveryId,
      'amount': amount,
      'direction': direction.wireName,
      'status': PaymentStatus.pending.wireName,
      'createdAt': now.toUtc().toIso8601String(),
      'expiresAt': now.add(PaymentQr.lifetime).toUtc().toIso8601String(),
      'payerLabel': 'Client',
      'payeeLabel': 'Livreur',
      '_token': token,
    };
    _intents[id] = intent;
    if (key != null) _intentsByKey[key] = id;

    // Le jeton n'est servi qu'a la creation, et uniquement a celui qui presente
    // le code.
    return MockResponse.created({..._public(intent), 'token': token});
  }

  Future<MockResponse> _read(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final intent = _intents[params['id']];
    if (intent == null) {
      return MockResponse.error(404, 'not_found', 'Intention inconnue');
    }
    _expireIfNeeded(intent);
    return MockResponse.ok(_public(intent));
  }

  /// Appariement des deux appareils.
  ///
  /// Le scan **n'autorise rien par lui-meme**. Pour une demande d'encaissement,
  /// l'appariement se contente de reveler le montant au payeur, qui devra
  /// confirmer. Pour une offre, le payeur ayant deja donne son accord, la
  /// capture suit immediatement.
  Future<MockResponse> _claim(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final intent = _intents[params['id']];
    if (intent == null) {
      return MockResponse.error(404, 'not_found', 'Intention inconnue');
    }

    // Le jeton est la seule preuve que le scanneur avait le code sous les yeux.
    if ('${req.json['token']}' != intent['_token']) {
      return MockResponse.error(403, 'bad_token', 'Code invalide');
    }

    if (_expireIfNeeded(intent)) {
      return MockResponse.error(
        410,
        'expired',
        'Code expire',
        details: {'failure': PaymentFailure.expired.wireName},
      );
    }

    final status = PaymentStatus.fromWire(intent['status'] as String?);
    if (status.isFinal) {
      // Rejouer un scan sur une intention deja reglee ne redebite rien : on
      // rend l'etat tel quel (EXI-MP06).
      return MockResponse.ok(_public(intent));
    }

    final direction = PaymentDirection.fromWire(intent['direction'] as String?);
    intent['status'] = PaymentStatus.claimed.wireName;

    if (direction.payerPreAuthorized) {
      return _settle(intent, idempotencyKey: req.idempotencyKey);
    }

    return MockResponse.ok(_public(intent));
  }

  /// Confirmation par le payeur (EXI-MP02).
  ///
  /// C'est ici, et nulle part ailleurs, que l'argent bouge pour une demande
  /// d'encaissement. Le role est verifie : une confirmation qui ne vient pas du
  /// payeur est refusee, sans quoi le beneficiaire pourrait se payer lui-meme.
  Future<MockResponse> _confirm(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final intent = _intents[params['id']];
    if (intent == null) {
      return MockResponse.error(404, 'not_found', 'Intention inconnue');
    }

    if (_role(req) != 'client') {
      return MockResponse.error(
        403,
        'not_payer',
        'Seul le payeur peut confirmer',
      );
    }

    if (_expireIfNeeded(intent)) {
      return MockResponse.error(
        410,
        'expired',
        'Code expire',
        details: {'failure': PaymentFailure.expired.wireName},
      );
    }

    return _settle(intent, idempotencyKey: req.idempotencyKey);
  }

  /// Repli especes (EXI-MP08, EXI-C43).
  ///
  /// Toujours accepte, y compris apres un echec MajiPay : la course ne doit
  /// jamais rester bloquee sur un probleme de paiement.
  Future<MockResponse> _cash(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final intent = _intents[params['id']];
    if (intent == null) {
      return MockResponse.error(404, 'not_found', 'Intention inconnue');
    }

    if (PaymentStatus.fromWire(intent['status'] as String?) ==
        PaymentStatus.captured) {
      return MockResponse.error(
        409,
        'already_captured',
        'Deja regle par MajiPay',
        details: {'currentState': PaymentStatus.captured.wireName},
      );
    }

    intent['status'] = PaymentStatus.cash.wireName;
    intent['capturedAt'] = DateTime.now().toUtc().toIso8601String();
    intent['receiptRef'] = 'ESP-${intent['id']}';
    return MockResponse.ok(_public(intent));
  }

  /// Mouvement effectif, avec idempotence stricte (EXI-MP06).
  MockResponse _settle(
    Map<String, dynamic> intent, {
    required String? idempotencyKey,
  }) {
    // Deux debits pour une meme intention seraient la faute la plus grave de ce
    // module : on repond la meme chose a la meme cle, sans retoucher aux soldes.
    if (idempotencyKey != null && _captured.containsKey(idempotencyKey)) {
      return MockResponse.ok(_captured[idempotencyKey]!);
    }

    if (PaymentStatus.fromWire(intent['status'] as String?) ==
        PaymentStatus.captured) {
      return MockResponse.ok(_public(intent));
    }

    final amount = (intent['amount'] as num).toInt();
    if ((_balances['client'] ?? 0) < amount) {
      intent['status'] = PaymentStatus.failed.wireName;
      intent['failure'] = PaymentFailure.insufficientFunds.wireName;
      return MockResponse.error(
        422,
        'insufficient_funds',
        'Solde MajiPay insuffisant',
        details: {'failure': PaymentFailure.insufficientFunds.wireName},
      );
    }

    _balances['client'] = (_balances['client'] ?? 0) - amount;
    _balances['driver'] = (_balances['driver'] ?? 0) + amount;

    intent['status'] = PaymentStatus.captured.wireName;
    intent['capturedAt'] = DateTime.now().toUtc().toIso8601String();
    intent['receiptRef'] = 'MP-${intent['id']}';

    final body = _public(intent);
    if (idempotencyKey != null) _captured[idempotencyKey] = body;
    return MockResponse.ok(body);
  }

  bool _expireIfNeeded(Map<String, dynamic> intent) {
    final status = PaymentStatus.fromWire(intent['status'] as String?);
    if (status.isFinal) return false;

    final expiresAt = DateTime.tryParse('${intent['expiresAt']}');
    if (expiresAt == null || DateTime.now().toUtc().isBefore(expiresAt)) {
      return false;
    }

    intent['status'] = PaymentStatus.failed.wireName;
    intent['failure'] = PaymentFailure.expired.wireName;
    return true;
  }

  /// Vue publique : tout sauf le jeton, qui ne sort qu'une fois, a la creation.
  Map<String, dynamic> _public(Map<String, dynamic> intent) =>
      Map<String, dynamic>.from(intent)..remove('_token');
}
