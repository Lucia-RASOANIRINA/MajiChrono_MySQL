import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/repositories/auth_repository.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';

/// Contrôleur de session.
///
/// Il porte l'etat global d'authentification, dont dependent les redirections
/// du routeur. Les ecrans de saisie (numero, OTP, PIN) ont leurs propres
/// contrôleurs locaux : ce qui remonte ici, c'est le resultat, pas la saisie.
class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async => _restore();

  /// Relit la session persistee au demarrage.
  ///
  /// Trois exigences se croisent ici. La session doit survivre au redemarrage
  /// (EXI-T03). L'application doit s'ouvrir **sans reseau** (EXI-P07), donc on
  /// se contente du compte en cache si le serveur est injoignable. Et si un code
  /// PIN est pose, on ouvre verrouille (EXI-T04) plutot que d'exposer les
  /// donnees a quiconque ramasse le telephone.
  Future<AuthState> _restore() async {
    final session = await _repository.currentSession();
    if (session == null) return const AuthUnauthenticated();

    if (session.isRefreshExpired) {
      await _repository.signOut();
      return const AuthUnauthenticated();
    }

    final cached = await _repository.cachedAccount();

    if (cached != null && await _repository.hasPin()) {
      return AuthLocked(
        cached,
        biometricsAvailable: await _biometricsAvailable(),
      );
    }

    if (cached != null) return AuthAuthenticated(cached);

    // Pas de compte en cache : il faut le serveur.
    try {
      final result = await _repository.fetchAccount();
      return switch (result) {
        AccountReady(:final account) => AuthAuthenticated(account),
        AccountProfilePending(:final phone) => AuthProfilePending(phone),
      };
    } on UnauthorizedFailure {
      await _repository.signOut();
      return const AuthUnauthenticated();
    } on Failure {
      // Reseau indisponible et rien en cache : on ne peut rien affirmer.
      return const AuthUnauthenticated();
    }
  }

  // --- Parcours de connexion --------------------------------------------

  /// Applique le resultat d'une verification OTP reussie.
  Future<void> onOtpVerified(OtpVerification verification) async {
    // Une adresse verifiee par le parcours Google attend peut-etre d'etre
    // rattachee. C'est le seul moment ou les deux preuves coexistent : la boite
    // mail vient d'etre prouvee, le numero vient de l'etre. Le rattachement se
    // fait ici, ou nulle part.
    final pending = ref.read(pendingEmailLinkProvider);
    if (pending != null) {
      try {
        await _repository.linkEmail(pending);
      } on Failure {
        // Le rattachement est un confort pour la prochaine entree, pas une
        // condition de connexion : s'il echoue, la session s'ouvre quand meme et
        // l'utilisateur reprendra son numero la prochaine fois.
      }
      ref.read(pendingEmailLinkProvider.notifier).state = null;
    }

    state = AsyncData(switch (verification.account) {
      AccountReady(:final account) => AuthAuthenticated(account),
      AccountProfilePending(:final phone) => AuthProfilePending(phone),
    });
  }

  /// Pose le profil choisi a l'inscription (EXI-T02).
  Future<void> chooseProfile({
    required UserRole role,
    required String firstName,
    required String lastName,
  }) async {
    final account = await _repository.chooseProfile(
      role: role,
      firstName: firstName,
      lastName: lastName,
    );
    state = AsyncData(AuthAuthenticated(account));
  }

  /// Adopte un compte fraichement modifie (nom, photo, e-mail, numero) pour que
  /// l'interface se remette a jour sans rejouer la session. On conserve l'etat
  /// courant — connecte ou verrouille — en n'en changeant que le compte porte.
  void applyAccount(UserAccount account) {
    final current = state.valueOrNull;
    state = AsyncData(switch (current) {
      AuthLocked(:final biometricsAvailable) => AuthLocked(
        account,
        biometricsAvailable: biometricsAvailable,
      ),
      _ => AuthAuthenticated(account),
    });
  }

  // --- Verrouillage (EXI-T04, EXI-SEC07) ---------------------------------

  /// Verrouille l'application si un code PIN est pose.
  ///
  /// Sans code, verrouiller enfermerait l'utilisateur dehors : on ne fait rien.
  Future<void> lock() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    if (!await _repository.hasPin()) return;

    state = AsyncData(
      AuthLocked(
        current.account,
        biometricsAvailable: await _biometricsAvailable(),
      ),
    );
  }

  Future<bool> unlockWithPin(String pin) async {
    final current = state.valueOrNull;
    if (current is! AuthLocked) return false;

    final ok = await _repository.verifyPin(pin);
    if (ok) {
      state = AsyncData(AuthAuthenticated(current.account));
      return true;
    }

    // Le compteur de tentatives a pu detruire le verrou : dans ce cas la seule
    // sortie est une reconnexion complete par OTP.
    if (!await _repository.hasPin()) {
      await signOut();
    }
    return false;
  }

  /// [reason] est le texte affiche par le systeme dans l'invite biometrique.
  /// Il vient de la couche presentation, seule a connaitre la langue courante :
  /// une invite systeme en francais sur une application en malgache serait
  /// exactement le genre de defaut que le critere d'acceptation n° 7 vise.
  Future<bool> unlockWithBiometrics({required String reason}) async {
    final current = state.valueOrNull;
    if (current is! AuthLocked) return false;

    try {
      final ok = await ref
          .read(localAuthProvider)
          .authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          );
      if (!ok) return false;
      state = AsyncData(AuthAuthenticated(current.account));
      return true;
    } catch (error, stack) {
      AppLogger.instance.warn('biometrics_failed', error: error);
      assert(() {
        AppLogger.instance.debug('$stack');
        return true;
      }());
      return false;
    }
  }

  Future<void> setPin(String pin) => _repository.setPin(pin);

  Future<bool> hasPin() => _repository.hasPin();

  // --- Sortie -------------------------------------------------------------

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncData(AuthUnauthenticated());
  }

  Future<bool> _biometricsAvailable() async {
    try {
      final auth = ref.read(localAuthProvider);
      return await auth.canCheckBiometrics && await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }
}
