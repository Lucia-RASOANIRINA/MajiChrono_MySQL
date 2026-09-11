import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

/// Etat d'authentification de l'application.
///
/// Union scellee plutot qu'un objet a champs nullables : le routeur decide de
/// la redirection par filtrage exhaustif, et le compilateur refuse d'oublier un
/// cas quand un etat nouveau apparait — par exemple le verrouillage automatique
/// ajoute pour EXI-SEC07.
sealed class AuthState {
  const AuthState();

  /// Vrai des que des jetons valides existent, verrouille ou non.
  bool get hasSession => switch (this) {
    AuthAuthenticated() || AuthProfilePending() || AuthLocked() => true,
    AuthUnknown() || AuthUnauthenticated() => false,
  };
}

/// Etat initial, le temps de relire la session persistee.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Session ouverte, profil pas encore choisi (EXI-T02).
class AuthProfilePending extends AuthState {
  const AuthProfilePending(this.phone);

  final MalagasyPhone phone;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.account);

  final UserAccount account;
}

/// Session valide mais application verrouillee (EXI-SEC07, EXI-T04).
///
/// L'etat conserve le compte : l'ecran de verrouillage peut donc saluer
/// l'utilisateur par son nom et, une fois deverrouille, rendre la main sans
/// aucun appel reseau — ce qui compte hors couverture.
class AuthLocked extends AuthState {
  const AuthLocked(this.account, {this.biometricsAvailable = false});

  final UserAccount account;
  final bool biometricsAvailable;
}
