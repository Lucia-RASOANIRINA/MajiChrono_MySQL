import 'package:majichrono/features/auth/domain/entities/google_entities.dart';

/// Acces aux comptes Google presents sur l'appareil.
///
/// L'entree par Google n'est proposee **qu'aux telephones qui la portent
/// vraiment**. Sur un appareil sans services Google — courant sur le parc vise,
/// ou l'entree de gamme et les ROM alternatives sont majoritaires — afficher un
/// bouton qui echouerait au premier appui vaut moins que ne rien afficher.
/// D'ou [isAvailable] : la question est posee avant de dessiner, pas apres.
abstract interface class DeviceGoogleAccounts {
  /// Vrai si l'appareil expose des comptes Google exploitables.
  Future<bool> isAvailable();

  /// Comptes detectes, dans l'ordre ou le systeme les donne.
  ///
  /// Retourne une liste vide plutot que de lever : « aucun compte » est une
  /// reponse normale, pas une panne. Une liste vide fait disparaitre l'option,
  /// comme [isAvailable] a faux.
  Future<List<GoogleAccountHint>> detect();
}

/// Implementation neutre : aucun compte, option masquee.
///
/// C'est le comportement retenu tant que l'identifiant client OAuth de
/// MajiChrono n'existe pas (voir [DeviceGoogleAccounts] et le README) : plutot
/// qu'un bouton qui promet ce qu'il ne peut pas tenir, l'ecran n'en montre
/// aucun, et le parcours telephonique reste le seul chemin.
class NoGoogleAccounts implements DeviceGoogleAccounts {
  const NoGoogleAccounts();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<GoogleAccountHint>> detect() async => const [];
}
