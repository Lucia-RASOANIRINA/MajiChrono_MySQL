import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/payment/data/payment_repository.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(client: ref.watch(apiClientProvider)),
);

/// Solde MajiPay du role courant.
///
/// `autoDispose` a dessein : un solde n'a de sens qu'a l'instant ou on le
/// regarde. Le conserver entre deux visites afficherait un montant perime au
/// moment precis ou il compte.
final majiPayBalanceProvider = FutureProvider.autoDispose
    .family<MajiPayBalance?, UserRole>(
      (ref, role) => ref.watch(paymentRepositoryProvider).balance(role),
    );

/// Journal des paiements du compte courant (§11, EXI-C39).
///
/// `autoDispose` : le journal se relit a chaque ouverture de l'ecran, on ne
/// garde pas en memoire une liste qui aura vieilli d'ici la prochaine visite.
final paymentHistoryProvider = FutureProvider.autoDispose
    .family<List<PaymentHistoryEntry>, int>(
      (ref, limit) => ref.watch(paymentRepositoryProvider).history(limit: limit),
    );

/// Suivi d'une intention jusqu'a son etat final (EXI-MP05).
///
/// Le sondage est **plafonne a 120 secondes** et sa cadence suit le profil
/// reseau : en 2G, interroger le serveur toutes les deux secondes couterait du
/// forfait pour une reponse qui n'a pas eu le temps de changer (§4.4). Il
/// s'arrete des qu'un etat final est atteint.
final paymentStatusProvider = StreamProvider.autoDispose
    .family<PaymentIntent, String>((ref, intentId) {
      final repository = ref.watch(paymentRepositoryProvider);
      final controller = StreamController<PaymentIntent>();

      const deadline = Duration(seconds: 120);
      final startedAt = DateTime.now();
      Timer? timer;

      Future<void> poll() async {
        try {
          final intent = await repository.status(intentId);
          if (controller.isClosed) return;
          controller.add(intent);

          if (intent.status.isFinal) {
            timer?.cancel();
            await controller.close();
          }
        } on Object {
          // Une lecture ratee n'interrompt pas le suivi : le reseau malgache coupe
          // par a-coups, et abandonner au premier echec laisserait l'utilisateur
          // devant un ecran figé alors que le paiement aboutit peut-etre.
        }

        if (DateTime.now().difference(startedAt) > deadline) {
          timer?.cancel();
          if (!controller.isClosed) await controller.close();
        }
      }

      final interval =
          ref
              .watch(networkStatusProvider)
              .valueOrNull
              ?.profile
              .trackingRefreshInterval ??
          const Duration(seconds: 10);

      timer = Timer.periodic(interval, (_) => poll());
      unawaited(poll());

      ref.onDispose(() {
        timer?.cancel();
        if (!controller.isClosed) controller.close();
      });

      return controller.stream;
    });

final paymentActionsProvider = Provider<PaymentActions>(
  (ref) => PaymentActions(ref),
);

class PaymentActions {
  PaymentActions(this._ref);

  final Ref _ref;

  PaymentRepository get _repository => _ref.read(paymentRepositoryProvider);

  /// Demande d'encaissement presentee par le livreur.
  Future<PaymentIntent> requestCollection({
    required String deliveryId,
    required int amountAriary,
  }) => _repository.createIntent(
    deliveryId: deliveryId,
    amountAriary: amountAriary,
    direction: PaymentDirection.collect,
    role: UserRole.driver,
  );

  /// Offre de paiement presentee par le client.
  ///
  /// Le code de l'utilisateur est verifie **avant** la creation : c'est ce qui
  /// rend l'offre pre-autorisee, et donc encaissable par un simple scan du
  /// livreur sans que l'invariant soit rompu.
  Future<PaymentIntent?> offerPayment({
    required String deliveryId,
    required int amountAriary,
    required String pin,
  }) async {
    if (!await _verifyPin(pin)) return null;

    return _repository.createIntent(
      deliveryId: deliveryId,
      amountAriary: amountAriary,
      direction: PaymentDirection.offer,
      role: UserRole.client,
    );
  }

  /// Apparie les deux appareils a partir d'un code scanne.
  Future<PaymentIntent> claim(ScannedPayment scanned) =>
      _repository.claim(scanned);

  /// Confirmation par le payeur, apres verification de son code.
  ///
  /// Retourne `null` si le code est faux. Le serveur n'est pas sollicite dans
  /// ce cas : inutile de lui faire porter une tentative qui n'a pas franchi la
  /// porte de l'appareil.
  Future<PaymentIntent?> confirm({
    required String intentId,
    required String pin,
  }) async {
    if (!await _verifyPin(pin)) return null;
    return _repository.confirm(intentId);
  }

  Future<PaymentIntent> fallbackToCash(String intentId) =>
      _repository.fallbackToCash(intentId);

  /// Retrait du solde MajiPay du livreur vers un moyen externe (EXI-MP09).
  ///
  /// Le processus est conduit ici ; la sortie d'argent se fait chez MajiPay. On
  /// rend le solde restant, que l'ecran relit pour se remettre a jour.
  Future<WithdrawReceipt> withdraw({
    required int amountAriary,
    String destination = '',
  }) => _repository.withdraw(
    amountAriary: amountAriary,
    destination: destination,
  );

  Future<bool> _verifyPin(String pin) =>
      _ref.read(authRepositoryProvider).verifyPin(pin);
}
