import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/services/device_google_accounts.dart';

/// Comptes Google simules, actifs en mode `mock` uniquement.
///
/// La detection reelle passe par `google_sign_in`, qui exige un identifiant
/// client OAuth declare dans la console Google Cloud pour l'empreinte SHA-1 de
/// la cle de signature. Cet identifiant **n'existe pas encore** pour
/// MajiChrono : tant qu'il n'est pas cree, aucun appel reel ne peut aboutir, et
/// ecrire le code d'integration reviendrait a livrer un bouton qui echoue.
///
/// Ce qui est livre a la place, c'est le **parcours complet** — detection,
/// choix du compte, code recu dans la boite mail, rattachement — derriere le
/// port [DeviceGoogleAccounts]. Le jour ou l'identifiant existe, une seule
/// classe change ; ni les ecrans, ni le repository, ni le domaine ne bougent.
class SimulatedGoogleAccounts implements DeviceGoogleAccounts {
  const SimulatedGoogleAccounts();

  /// Adresses de recette. Les deux premieres sont rattachees aux comptes
  /// pre-inscrits du simulateur : elles ouvrent une session sans SMS. La
  /// troisieme ne l'est pas, et sert a derouler le cas « adresse verifiee, mais
  /// compte inconnu », qui est le plus interessant des deux.
  static const List<GoogleAccountHint> accounts = [
    GoogleAccountHint(
      email: 'hery.rakoto@gmail.com',
      displayName: 'Hery Rakoto',
    ),
    GoogleAccountHint(
      email: 'naina.andria@gmail.com',
      displayName: 'Naina Andria',
    ),
    GoogleAccountHint(email: 'visiteur.tana@gmail.com'),
  ];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<GoogleAccountHint>> detect() async {
    // Une latence courte, mais non nulle : la liste arrive apres un aller-retour
    // avec le systeme, et l'ecran doit savoir montrer une attente. Sans elle, le
    // cas « detection lente » ne serait jamais teste a la main.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return accounts;
  }
}
