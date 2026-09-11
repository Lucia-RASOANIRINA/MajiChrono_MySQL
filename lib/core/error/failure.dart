/// Hierarchie d'erreurs typees (regle 9.3.4 du CDC).
///
/// Aucune couche superieure ne manipule d'exception brute : le socle reseau et
/// le socle stockage traduisent tout en [Failure]. La presentation ne fait que
/// choisir la cle de traduction correspondante.
library;

sealed class Failure implements Exception {
  const Failure({this.cause, this.stackTrace, this.details});

  /// Exception d'origine, jamais affichee a l'utilisateur (regle 9.3.4).
  final Object? cause;
  final StackTrace? stackTrace;
  final Map<String, Object?>? details;

  /// Cle ARB utilisee par la presentation.
  String get messageKey;

  /// Une action de reprise a-t-elle un sens ?
  bool get isRetryable;

  @override
  String toString() => '$runtimeType(${details ?? {}})';
}

/// Pas de reseau exploitable. L'action a ete mise en file (§10.2).
class NetworkFailure extends Failure {
  const NetworkFailure({super.cause, super.stackTrace, super.details});

  @override
  String get messageKey => 'errorNetwork';
  @override
  bool get isRetryable => true;
}

/// Le serveur n'a pas repondu dans le delai imparti.
class TimeoutFailure extends Failure {
  const TimeoutFailure({super.cause, super.stackTrace, super.details});

  @override
  String get messageKey => 'errorTimeout';
  @override
  bool get isRetryable => true;
}

/// 5xx.
class ServerFailure extends Failure {
  const ServerFailure({
    required this.statusCode,
    this.code,
    super.cause,
    super.stackTrace,
    super.details,
  });

  final int statusCode;

  /// Code metier renvoye par le backend (§12.1).
  final String? code;

  @override
  String get messageKey => 'errorServer';
  @override
  bool get isRetryable => true;
}

/// 401 / 403 : session invalide ou droits insuffisants.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    this.code,
    super.cause,
    super.stackTrace,
    super.details,
  });

  /// Code metier renvoye par le backend (ex. `kyc_not_approved`), quand le refus
  /// n'est pas une simple perte de session mais un droit conditionnel a montrer
  /// specifiquement.
  final String? code;

  @override
  String get messageKey => 'errorUnauthorized';
  @override
  bool get isRetryable => false;
}

/// 409 : transition illegale ou requete deja traitee (EXI-B02, EXI-S01).
class ConflictFailure extends Failure {
  const ConflictFailure({
    this.currentState,
    super.cause,
    super.stackTrace,
    super.details,
  });

  /// Etat courant renvoye par le serveur, qui fait foi (EXI-S04).
  final String? currentState;

  @override
  String get messageKey => 'errorConflict';
  @override
  bool get isRetryable => false;
}

/// 400 / 422 : la saisie est refusee, champ par champ.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required this.fieldErrors,
    super.cause,
    super.stackTrace,
    super.details,
  });

  final Map<String, String> fieldErrors;

  @override
  String get messageKey => 'errorUnknown';
  @override
  bool get isRetryable => false;
}

/// 426 : le serveur impose une mise a jour de l'application (EXI-B08).
class UpdateRequiredFailure extends Failure {
  const UpdateRequiredFailure({
    this.minVersion,
    super.cause,
    super.stackTrace,
    super.details,
  });

  final String? minVersion;

  @override
  String get messageKey => 'errorUpdateRequired';
  @override
  bool get isRetryable => false;
}

/// Base locale, systeme de fichiers, stockage sature.
class StorageFailure extends Failure {
  const StorageFailure({super.cause, super.stackTrace, super.details});

  @override
  String get messageKey => 'errorStorage';
  @override
  bool get isRetryable => false;
}

/// Filet de securite : tout ce qui n'a pas ete classe.
class UnknownFailure extends Failure {
  const UnknownFailure({super.cause, super.stackTrace, super.details});

  @override
  String get messageKey => 'errorUnknown';
  @override
  bool get isRetryable => true;
}
