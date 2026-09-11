import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

/// Contrat d'authentification vu par le domaine.
///
/// Aucune mention de HTTP, de jeton stocke ou de Keystore : le domaine sait
/// qu'il existe une session, pas ou elle est rangee (§8.1).
abstract interface class AuthRepository {
  /// Demande l'envoi d'un code OTP (EXI-T01).
  Future<OtpChallenge> requestOtp(MalagasyPhone phone);

  Future<PhoneLoginResult> loginWithPhone({
    required MalagasyPhone phone,
    String? password,
  });

  /// Verifie un code. Leve une [ValidationFailure] si le code est faux, en
  /// indiquant le nombre de tentatives restantes.
  Future<OtpVerification> verifyOtp({
    required String challengeId,
    required String code,
  });

  /// Envoie un code a six chiffres dans une boite mail.
  ///
  /// La reponse ne dit **pas** si l'adresse est connue : le savoir avant d'avoir
  /// prouve la possession de la boite permettrait d'enumerer les comptes.
  Future<EmailChallenge> requestEmailCode(String email);

  /// Verifie un code recu par e-mail. Ouvre la session si l'adresse est
  /// rattachee a un compte, sinon renvoie [EmailUnlinked].
  Future<EmailVerification> verifyEmailCode({
    required String challengeId,
    required String code,
  });

  /// Rattache une adresse deja verifiee au compte de la session en cours, pour
  /// que la prochaine entree se fasse par Google sans repasser par le SMS.
  Future<void> linkEmail(String email);

  /// Connexion par couple e-mail / mot de passe.
  ///
  /// Meme issue que le code par e-mail : session ouverte si l'adresse porte un
  /// compte, renvoi vers le numero sinon.
  Future<EmailVerification> signInWithPassword({
    required String email,
    required String password,
  });

  /// Inscription par couple e-mail / mot de passe.
  ///
  /// Ne rend **jamais** [EmailLinked] : un compte neuf n'a pas encore de
  /// numero, et sans numero il n'y a pas de compte. Le mot de passe est
  /// enregistre, puis le parcours enchaine sur la confirmation du numero.
  Future<EmailVerification> signUpWithPassword({
    required String email,
    required String password,
  });

  /// Change le mot de passe du compte connecte. [currentPassword] est requis si
  /// le compte en a deja un ; il est absent pour un compte entre par numero qui
  /// s'en pose un pour la premiere fois.
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  /// « Mot de passe oublie » : repose le mot de passe apres un code recu par
  /// e-mail. Le defi vient de [requestEmailCode].
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  });

  /// Demande un code a une **nouvelle** adresse e-mail, en vue de la rattacher
  /// au compte connecte.
  Future<EmailChallenge> requestEmailChange(String email);

  /// Confirme le changement d'adresse et rend le compte a jour.
  Future<UserAccount> confirmEmailChange({
    required String challengeId,
    required String code,
  });

  /// Demande un SMS a un **nouveau** numero, en vue d'en faire la cle du compte.
  Future<OtpChallenge> requestPhoneChange(MalagasyPhone phone);

  /// Confirme le changement de numero et rend le compte a jour.
  Future<UserAccount> confirmPhoneChange({
    required String challengeId,
    required String code,
  });

  /// Pose (ou remplace) la photo de profil. Rend le compte a jour, `avatarUrl`
  /// pointant sur la nouvelle image.
  Future<UserAccount> uploadAvatar({
    required List<int> bytes,
    required String contentType,
  });

  /// Retire la photo de profil.
  Future<UserAccount> deleteAvatar();

  /// Pose le profil d'un compte tout juste cree (EXI-T02) : role, prenom, nom.
  ///
  /// Le role administrateur est refuse par le serveur : il n'est attribue que
  /// cote serveur, jamais revendique par le mobile.
  Future<UserAccount> chooseProfile({
    required UserRole role,
    required String firstName,
    required String lastName,
  });

  /// Met a jour le prenom et le nom du compte connecte ; le serveur en recompose
  /// le nom d'usage.
  Future<UserAccount> updateName({String? firstName, String? lastName});

  /// Liste les sessions actives (un appareil = une session).
  Future<List<SessionInfo>> listSessions();

  /// Revoque une session a distance : l'appareil vise ne pourra plus se
  /// rafraichir.
  Future<void> revokeSession(String id);

  /// Session persistee, ou `null` si l'utilisateur n'est pas connecte.
  Future<AuthSession?> currentSession();

  /// Compte en cache, disponible hors ligne — le profil ne change pas souvent,
  /// et l'application doit s'ouvrir sans reseau (EXI-P07).
  Future<UserAccount?> cachedAccount();

  /// Recharge le compte depuis le serveur.
  Future<AccountResult> fetchAccount();

  /// Echange le jeton de rafraichissement contre un nouveau couple (EXI-T03).
  Future<AuthSession> refresh();

  /// Deconnexion : revoque cote serveur si possible, puis efface tout (EXI-SEC10).
  Future<void> signOut();

  // --- Verrouillage local (EXI-T04) ------------------------------------

  Future<bool> hasPin();

  /// Enregistre l'empreinte salee du code PIN. Le code lui-meme n'est jamais
  /// ecrit nulle part.
  Future<void> setPin(String pin);

  Future<bool> verifyPin(String pin);

  Future<void> clearPin();
}
