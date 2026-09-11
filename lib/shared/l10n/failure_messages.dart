import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Pont entre la hierarchie d'erreurs du socle et les fichiers ARB.
///
/// La couche domaine ne connait que des [Failure] ; c'est ici, et nulle part
/// ailleurs, qu'une erreur devient une phrase (regle 9.3.5).
extension FailureL10n on Failure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    ServerFailure() => l10n.errorServer,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ConflictFailure() => l10n.errorConflict,
    UpdateRequiredFailure() => l10n.errorUpdateRequired,
    StorageFailure() => l10n.errorStorage,
    ValidationFailure() => l10n.errorUnknown,
    UnknownFailure() => l10n.errorUnknown,
  };
}
