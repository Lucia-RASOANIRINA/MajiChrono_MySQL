/// Points d'entree du backend, tels qu'imposes par le §12.2 du cahier des charges.
///
/// Cette classe est l'unique source de verite des chemins. Le transport simule
/// (`MockHttpAdapter`) et le transport reel consomment strictement les memes
/// constantes : passer de `mock` a `live` ne change aucune URL.
class ApiEndpoints {
  const ApiEndpoints._();

  // --- Socle -----------------------------------------------------------
  static const String health = '/health';

  // --- Authentification ------------------------------------------------
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';
  static const String phoneLogin = '/auth/phone/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  /// Sessions actives du compte (un appareil = une session) : liste, et
  /// révocation à distance d'un appareil donné.
  static const String sessions = '/auth/sessions';
  static String session(String family) => '/auth/sessions/$family';

  /// Entree acceleree par adresse e-mail (compagnon du bouton « Continuer avec
  /// Google »). Le code part dans la boite mail, jamais par SMS : c'est
  /// justement l'interet du parcours pour qui n'a pas de reseau GSM au moment ou
  /// il se connecte, mais du Wi-Fi.
  static const String emailRequest = '/auth/email/request';
  static const String emailVerify = '/auth/email/verify';

  /// Cree un compte sans numero, a partir du defi deja prouve par
  /// [emailVerify] quand aucun compte n'existait pour l'adresse.
  static const String emailRegister = '/auth/email/register';

  /// Rattache une adresse deja verifiee au compte de la session en cours.
  static const String emailLink = '/auth/email/link';

  /// Entree par mot de passe, pour qui prefere un couple e-mail/mot de passe a
  /// un code recu a chaque connexion.
  static const String passwordSignIn = '/auth/password/signin';
  static const String passwordSignUp = '/auth/password/signup';

  /// Change le mot de passe du compte connecte (ancien + nouveau), ou le pose
  /// pour un compte entre par numero qui n'en avait pas.
  static const String passwordChange = '/auth/password/change';

  /// « Mot de passe oublie » : repose le mot de passe apres un code recu par
  /// e-mail (via [emailRequest]).
  static const String passwordReset = '/auth/password/reset';

  /// Changement d'adresse e-mail du compte connecte, en deux temps : un code
  /// part a la **nouvelle** adresse, puis on la rattache.
  static const String emailChangeRequest = '/auth/email/change/request';
  static const String emailChangeVerify = '/auth/email/change/verify';

  /// Changement de numero du compte connecte, verifie par SMS a la nouvelle
  /// ligne avant de deplacer la cle du compte.
  static const String phoneChangeRequest = '/auth/phone/change/request';
  static const String phoneChangeVerify = '/auth/phone/change/verify';

  // --- Profil ----------------------------------------------------------
  static const String me = '/me';

  /// Photo de profil : POST pour poser/remplacer, DELETE pour retirer. L'image
  /// est ensuite servie par l'URL portee par `avatarUrl` du compte.
  static const String meAvatar = '/me/avatar';

  // --- Courses ---------------------------------------------------------
  static const String deliveries = '/deliveries';
  static String delivery(String id) => '/deliveries/$id';
  static String deliveryCancel(String id) => '/deliveries/$id/cancel';

  // --- Livreur ---------------------------------------------------------
  static const String deliveriesAvailable = '/deliveries/available';
  static const String driverStatus = '/driver/status';
  static String deliveryAccept(String id) => '/deliveries/$id/accept';
  static String deliveryStatus(String id) => '/deliveries/$id/status';

  /// Incidents declares sur une course (EXI-L14, §19).
  static String deliveryIncidents(String id) => '/deliveries/$id/incidents';

  // --- Constats (§7.3) -------------------------------------------------
  static String custodyPickup(String id) => '/deliveries/$id/custody/pickup';
  static String custodyHandover(String id) =>
      '/deliveries/$id/custody/handover';
  static String custody(String id) => '/deliveries/$id/custody';

  // --- Pieces jointes --------------------------------------------------
  static const String uploads = '/uploads';

  // --- Discussion course (expediteur <-> livreur) ----------------------
  /// Boite de reception : la liste des conversations (espace « Messages »).
  static const String conversations = '/conversations';

  /// Messages d'une course. S'ouvre a l'acceptation ; seuls l'expediteur et le
  /// livreur assigne y ont acces.
  static String deliveryMessages(String id) => '/deliveries/$id/messages';

  /// Accuse de lecture : marque comme lus les messages recus de la course.
  static String deliveryMessagesRead(String id) =>
      '/deliveries/$id/messages/read';

  // --- Suivi -----------------------------------------------------------
  static const String trackingPing = '/tracking/ping';
  static const String trackingBatch = '/tracking/batch';
  static String deliveryTrace(String id) => '/deliveries/$id/trace';

  // --- KYC -------------------------------------------------------------
  static const String kycSubmit = '/drivers/kyc';
  static const String kycStatus = '/drivers/kyc/status';

  /// Depot (POST) / retrait (DELETE) d'une piece du dossier KYC.
  static String kycDocument(String kind) => '/drivers/kyc/documents/$kind';

  /// Lecture d'une piece (jeton exige) — proprietaire ou exploitation.
  static String kycDocumentOf(String accountId, String kind) =>
      '/accounts/$accountId/kyc/$kind';

  /// Fiche vehicule structuree du livreur (§22).
  static const String driverVehicle = '/driver/vehicle';

  /// Fil de suivi du dossier KYC (livreur <-> exploitation).
  static const String kycMessages = '/drivers/kyc/messages';
  static String adminKycMessages(String driverId) =>
      '/admin/kyc/$driverId/messages';

  /// Pieces d'un livreur, cote exploitation, pour la revue du dossier.
  static String adminKycDocuments(String driverId) =>
      '/admin/kyc/$driverId/documents';

  // --- Paiement (§11.2) ------------------------------------------------
  static const String paymentBalance = '/payments/balance';
  static const String paymentHistory = '/payments/history';
  static const String paymentIntent = '/payments/intent';
  static String payment(String id) => '/payments/$id';

  /// Appariement des deux appareils par code QR. N'autorise aucun debit a lui
  /// seul : le payeur confirme toujours sur son propre appareil.
  static String paymentClaim(String id) => '/payments/$id/claim';
  static String paymentConfirm(String id) => '/payments/$id/confirm';
  static String paymentCash(String id) => '/payments/$id/cash';

  /// Retrait du solde MajiPay vers un moyen externe (Mobile Money, compte). Le
  /// processus vit dans l'app, la sortie d'argent se fait chez MajiPay.
  static const String paymentWithdraw = '/payments/withdraw';

  // --- Urgence livreur (EXI-L13, D10) ----------------------------------
  static const String emergency = '/drivers/emergency';

  // --- Carnet d'adresses (EXI-C05) -------------------------------------
  static const String addresses = '/addresses';
  static String address(String id) => '/addresses/$id';

  // --- Media (photo du colis, EXI-C09) ---------------------------------
  static const String media = '/media';
  static String mediaItem(String id) => '/media/$id';

  // --- Points relais (differenciant D6) ---------------------------------
  static const String relayPoints = '/relay-points';

  // --- Notations -------------------------------------------------------
  static const String reviews = '/reviews';

  /// Avis deja laisse par l'expediteur sur une course, s'il existe.
  static String reviewForDelivery(String id) => '/reviews/delivery/$id';

  // --- Litiges ---------------------------------------------------------
  static const String disputes = '/disputes';
  static String dispute(String id) => '/disputes/$id';
  static String disputeMessages(String id) => '/disputes/$id/messages';
  static String disputeFiles(String id) => '/disputes/$id/files';

  // --- Notifications et support ---------------------------------------
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String contact = '/contact';
  static const String adminContact = '/admin/contact';
  static String adminContactReply(String id) => '/admin/contact/$id/reply';
  static const String adminSystemAudit = '/admin/system/audit';
  static const String adminSettings = '/admin/settings';
  static String adminSetting(String key) => '/admin/settings/$key';

  /// Decision finale sur un litige (EXI-A05). Distincte des messages : clore un
  /// litige n'est pas y repondre.
  static String disputeDecision(String id) => '/disputes/$id/decision';

  // --- Suivi public (EXI-C24) ------------------------------------------
  static String publicTrack(String token) => '/public/track/$token';

  // --- Administration --------------------------------------------------
  static const String adminDashboard = '/admin/dashboard';
  static const String adminStats = '/admin/stats';
  static const String adminFleet = '/admin/fleet';
  static const String adminKyc = '/admin/kyc';
  static String adminKycReview(String id) => '/admin/kyc/$id/review';

  /// Suspension et reintegration d'un compte (EXI-A06).
  static String adminDriverSuspension(String id) =>
      '/admin/drivers/$id/suspension';

  /// Annuaire des comptes (clients + livreurs), cherchable.
  static const String adminUsers = '/admin/users';

  /// Suspension / reactivation d'un compte quelconque (client ou livreur).
  static String adminUserSuspension(String id) =>
      '/admin/users/$id/suspension';

  /// Reaffectation manuelle d'une course (EXI-A07).
  ///
  /// Route distincte de `/deliveries/{id}/status` a dessein : le graphe de
  /// transitions du livreur ne prevoit pas ce mouvement, et le faire passer par
  /// la meme porte reviendrait a donner au mobile un pouvoir qu'il ne doit pas
  /// avoir.
  static String adminDeliveryReassign(String id) =>
      '/admin/deliveries/$id/reassign';
}
