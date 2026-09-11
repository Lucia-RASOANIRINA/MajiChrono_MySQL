import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';

/// Compte Google detecte sur l'appareil.
///
/// « Indice » et non « identite » : la presence d'un compte dans le systeme ne
/// prouve rien. Elle epargne seulement une saisie d'adresse. La preuve, c'est le
/// code recu dans la boite mail — l'appareil propose, la boite dispose.
class GoogleAccountHint {
  const GoogleAccountHint({
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String email;
  final String? displayName;
  final String? avatarUrl;

  /// Ce qu'on montre dans la liste : le nom si l'appareil le connait, sinon la
  /// partie locale de l'adresse. Jamais une chaine vide.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  /// Initiale d'avatar, quand l'appareil ne fournit pas de photo.
  String get initial => label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
}

/// Defi envoye dans une boite mail.
///
/// Volontairement distinct d'[OtpChallenge] : les deux portent un code a six
/// chiffres, mais pas la meme promesse. Le defi telephonique **cree** un compte
/// ; le defi e-mail ne fait que **retrouver** un compte deja cree. Les fusionner
/// dans une seule classe obligerait chaque ecran a tester laquelle des deux
/// destinations est renseignee, et laisserait passer un jour la construction
/// d'un compte sans numero.
class EmailChallenge {
  const EmailChallenge({
    required this.challengeId,
    required this.email,
    required this.expiresAt,
    required this.attemptsLeft,
    this.debugCode,
  });

  final String challengeId;
  final String email;
  final DateTime expiresAt;
  final int attemptsLeft;

  /// Renseigne par le backend simule uniquement, comme pour l'OTP telephonique.
  final String? debugCode;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  EmailChallenge copyWith({int? attemptsLeft}) => EmailChallenge(
    challengeId: challengeId,
    email: email,
    expiresAt: expiresAt,
    attemptsLeft: attemptsLeft ?? this.attemptsLeft,
    debugCode: debugCode,
  );
}

/// Issue d'une verification par e-mail.
///
/// Deux cas seulement, et ils ne se ressemblent pas : ou l'adresse est rattachee
/// a un compte — on ouvre la session sans SMS — ou elle ne l'est pas, et il faut
/// alors passer par le numero de telephone. C'est une union, pas un booleen :
/// [EmailUnlinked] n'a pas de session a offrir, et le type l'interdit.
sealed class EmailVerification {
  const EmailVerification();
}

/// L'adresse etait rattachee : la session est ouverte, le parcours continue
/// exactement comme apres un OTP telephonique.
class EmailLinked extends EmailVerification {
  const EmailLinked(this.verification);

  final OtpVerification verification;
}

/// L'adresse est valide — le code est arrive et a ete saisi — mais aucun compte
/// MajiChrono ne s'y rattache.
///
/// On ne cree pas de compte ici. A Madagascar, un livreur appelle son client et
/// un client appelle son livreur : un compte sans numero de telephone serait un
/// compte avec lequel on ne peut pas livrer. L'adresse verifiee est conservee
/// pour etre rattachee au compte des que le numero sera confirme.
class EmailUnlinked extends EmailVerification {
  const EmailUnlinked(this.email);

  final String email;
}
