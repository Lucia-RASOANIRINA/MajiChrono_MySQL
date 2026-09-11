/// Chemins de navigation.
///
/// Ils sont declares en constantes parce qu'ils servent aussi de cibles aux
/// liens profonds des notifications (EXI-N04) et au lien de suivi public
/// partage par SMS (EXI-C24) : une chaine litterale dispersee dans le code
/// deviendrait vite un lien mort.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';

  /// Premier ecran vu par un nouvel utilisateur : la promesse et les quatre
  /// piliers en mouvement, avant toute demande d'identite.
  static const String welcome = '/welcome';

  // --- Authentification (module 1) --------------------------------------

  /// Choix de la porte d'entree : numero ou adresse e-mail.
  static const String authChoice = '/auth/choice';
  static const String authSignIn = '/auth/signin';
  static const String authSignUp = '/auth/signup';
  static const String authPhone = '/auth/phone';
  static const String authPhoneSignUp = '/auth/phone/signup';
  static const String authOtp = '/auth/otp';

  /// Code recu par e-mail, apres « Continuer avec Google ».
  static const String authEmailCode = '/auth/email';
  static const String authProfile = '/auth/profile';
  static const String authPin = '/auth/pin';
  static const String authLock = '/auth/lock';

  /// « Mot de passe oublie », accessible depuis l'entree par mot de passe.
  static const String authForgotPassword = '/auth/forgot';

  /// Edition des informations personnelles (nom, photo, e-mail, numero).
  static const String profileEdit = '/profile/edit';

  /// Changement (ou pose) du mot de passe du compte connecte.
  static const String passwordChange = '/profile/password';

  /// Appareils connectes : liste et revocation des sessions actives.
  static const String sessions = '/profile/sessions';

  /// Carnet d'adresses du compte (domicile, travail, favoris).
  static const String addressBook = '/addresses';

  /// Centre d'aide : FAQ et contact du support.
  static const String helpCenter = '/help';

  /// Portefeuille client : solde MajiPay et historique des paiements (§11).
  static const String wallet = '/wallet';

  /// Espace « Messages » : la boite de reception des conversations.
  static const String messages = '/messages';
  static const String clientMessages = '/client/messages';

  /// Litiges de l'utilisateur : liste et detail (§13, assistance).
  static const String disputes = '/support/disputes';
  static String dispute(String id) => '/support/disputes/$id';

  /// Vrai pour toute route du parcours d'authentification.
  /// L'accueil compte comme une etape du parcours d'entree : un visiteur non
  /// identifie doit pouvoir y rester sans etre renvoye sur la saisie du numero.
  static bool isAuthRoute(String location) =>
      location.startsWith('/auth') || location == welcome;

  static const String settings = '/settings';
  static const String dataUsage = '/settings/data';

  /// Centre de notifications : l'historique des notifications recues (EXI-N06).
  static const String notifications = '/notifications';

  /// Discussion d'une course (expediteur <-> livreur). Ouverte a l'acceptation,
  /// accessible depuis le suivi cote client et la course active cote livreur.
  static String chat(String deliveryId) => '/chat/$deliveryId';

  /// Elements en attente de synchronisation (EXI-S06).
  static const String pendingSync = '/settings/sync';

  // --- Client ----------------------------------------------------------
  static const String clientHome = '/client';
  static const String clientDeliveries = '/client/deliveries';
  static const String clientProfile = '/client/profile';
  static const String clientNewDelivery = '/client/new';
  static String clientTracking(String id) => '/client/track/$id';

  // --- Livreur ---------------------------------------------------------
  static const String driverHome = '/driver';
  static const String driverDeliveries = '/driver/deliveries';
  static const String driverEarnings = '/driver/earnings';

  /// Fiche vehicule structuree du livreur (§22).
  static const String driverVehicle = '/driver/vehicle-info';

  /// Fil de suivi du dossier KYC (livreur <-> exploitation).
  static const String kycFollowup = '/driver/kyc-followup';
  static const String driverProfile = '/driver/profile';
  static String driverActive(String id) => '/driver/active/$id';

  // --- Administration --------------------------------------------------
  static const String adminHome = '/admin';
  static const String adminFleet = '/admin/fleet';
  static const String adminDisputes = '/admin/disputes';
  static const String adminProfile = '/admin/profile';

  /// Ecrans atteints depuis le tableau de bord plutot que par un onglet : la
  /// barre inferieure en compte deja quatre, et au-dela les libelles ne tiennent
  /// plus sur un ecran de 320 dp (§15.1).
  static const String adminKyc = '/admin/kyc';
  static const String adminDeliveries = '/admin/deliveries';

  /// Gestion des utilisateurs (clients + livreurs) : liste, recherche,
  /// suspension/reactivation.
  static const String adminUsers = '/admin/users';

  /// Statistiques & rapports d'exploitation.
  static const String adminStats = '/admin/statistics';
  static String adminDispute(String id) => '/admin/disputes/$id';

  // --- Liens profonds --------------------------------------------------
  static const String publicTrack = '/track/:token';
  static String publicTrackFor(String token) => '/track/$token';
}
