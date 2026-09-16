// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get profileEdit => 'Modifier le profil';

  @override
  String get profilePersonalInfo => 'Informations personnelles';

  @override
  String get profilePhoto => 'Photo de profil';

  @override
  String get profilePhotoFromGallery => 'Choisir dans la galerie';

  @override
  String get profilePhotoFromCamera => 'Prendre une photo';

  @override
  String get profilePhotoRemove => 'Retirer la photo';

  @override
  String get profileName => 'Nom affiche';

  @override
  String get profileFirstName => 'Prenom';

  @override
  String get profileLastName => 'Nom';

  @override
  String get addressBookTitle => 'Mes adresses';

  @override
  String get addressBookManage => 'Mes adresses';

  @override
  String get addressAdd => 'Ajouter une adresse';

  @override
  String get addressEditTitle => 'Modifier l\'adresse';

  @override
  String get addressLabelField => 'Nom (ex. Maison, Boutique)';

  @override
  String get addressKindLabel => 'Type';

  @override
  String get addressKindHome => 'Domicile';

  @override
  String get addressKindWork => 'Travail';

  @override
  String get addressKindFavorite => 'Favori';

  @override
  String get addressKindOther => 'Autre';

  @override
  String get addressEmpty => 'Aucune adresse enregistree';

  @override
  String get addressEmptyHelp =>
      'Ajoutez vos adresses habituelles pour aller plus vite.';

  @override
  String get addressSaved => 'Adresse enregistree';

  @override
  String get addressDeleted => 'Adresse supprimee';

  @override
  String get addressNeedPoint => 'Placez d\'abord l\'adresse sur la carte';

  @override
  String get addressPickSaved => 'Choisir dans mes adresses';

  @override
  String get helpCenterTitle => 'Aide et support';

  @override
  String get helpCenterManage => 'Aide et support';

  @override
  String get helpContactTitle => 'Contacter le support';

  @override
  String get helpContactHelp => 'Notre equipe repond aux heures ouvrees.';

  @override
  String get helpCall => 'Appeler';

  @override
  String get helpEmail => 'Ecrire';

  @override
  String get helpReportProblem => 'Signaler un probleme';

  @override
  String get helpReportProblemHelp =>
      'Un souci avec une course ? Ecrivez-nous en indiquant son numero.';

  @override
  String get helpReportSubject => 'MajiChrono — signalement';

  @override
  String get helpFaqTitle => 'Questions frequentes';

  @override
  String get helpFaqQ1 => 'Comment creer une livraison ?';

  @override
  String get helpFaqA1 =>
      'Depuis l\'accueil, touchez « Nouvelle livraison » : choisissez le depart et la destination, decrivez le colis, puis confirmez.';

  @override
  String get helpFaqQ2 => 'Comment suivre ma livraison ?';

  @override
  String get helpFaqA2 =>
      'Ouvrez la course dans « Mes courses » : vous y voyez le statut en temps reel, la position du livreur et l\'heure d\'arrivee estimee.';

  @override
  String get helpFaqQ3 => 'Comment payer ?';

  @override
  String get helpFaqA3 =>
      'Par MajiPay (code QR) ou en especes a la remise. Le detail du tarif s\'affiche avant de confirmer.';

  @override
  String get helpFaqQ4 => 'Puis-je annuler une course ?';

  @override
  String get helpFaqA4 =>
      'Oui, tant que le livreur n\'a pas encore pris le colis en charge.';

  @override
  String get helpFaqQ5 => 'Comment enregistrer mes adresses ?';

  @override
  String get helpFaqA5 =>
      'Dans Reglages, Mes adresses : ajoutez votre domicile, votre travail et vos favoris pour aller plus vite.';

  @override
  String get helpFaqQ6 => 'Un livreur est-il fiable ?';

  @override
  String get helpFaqA6 =>
      'Chaque livreur passe une verification d\'identite (KYC) avant de pouvoir accepter des courses, et vous pouvez le noter apres la livraison.';

  @override
  String get disputesTitle => 'Mes litiges';

  @override
  String get disputesManage => 'Litiges et reclamations';

  @override
  String get disputesEmpty => 'Aucun litige';

  @override
  String get disputesEmptyHelp =>
      'Un probleme avec une course ? Ouvrez un litige depuis son suivi.';

  @override
  String get disputeOpenTitle => 'Ouvrir un litige';

  @override
  String get disputeOpenHelp =>
      'Decrivez le probleme rencontre. Notre equipe instruit le dossier avec le livreur.';

  @override
  String get disputeReasonLabel => 'Motif du litige';

  @override
  String get disputeReasonHint => 'Ex : colis abime a la reception';

  @override
  String get disputeOpenAction => 'Ouvrir le litige';

  @override
  String get disputeOpened => 'Litige ouvert';

  @override
  String get disputeReportButton => 'Signaler un litige';

  @override
  String get disputeStatusOpen => 'Ouvert';

  @override
  String get disputeStatusInvestigating => 'En instruction';

  @override
  String get disputeStatusResolved => 'Resolu';

  @override
  String get disputeStatusRejected => 'Rejete';

  @override
  String get disputeReason => 'Motif';

  @override
  String get disputeThread => 'Echanges';

  @override
  String get disputeNoMessages => 'Aucun echange pour l\'instant.';

  @override
  String get disputeReplyHint => 'Ecrire un message';

  @override
  String get disputeSend => 'Envoyer';

  @override
  String get disputeClosed => 'Ce litige est clos.';

  @override
  String get disputeDecision => 'Decision';

  @override
  String get disputeAuthorYou => 'Vous';

  @override
  String disputeOpenedOn(String date) {
    return 'Ouvert le $date';
  }

  @override
  String get disputeReasonTooShort =>
      'Detaillez un peu plus (10 caracteres minimum).';

  @override
  String get cancelDelivery => 'Annuler la course';

  @override
  String get cancelSheetTitle => 'Annuler la course ?';

  @override
  String get cancelSheetHelp =>
      'Choisissez un motif. Des frais peuvent s\'appliquer si un livreur est deja en route.';

  @override
  String get cancelReasonMind => 'J\'ai change d\'avis';

  @override
  String get cancelReasonWrongAddress => 'Erreur d\'adresse';

  @override
  String get cancelReasonTooLong => 'Attente trop longue';

  @override
  String get cancelReasonOther => 'Autre raison';

  @override
  String get cancelConfirm => 'Confirmer l\'annulation';

  @override
  String get cancelKeep => 'Garder la course';

  @override
  String get cancelDone => 'Course annulee';

  @override
  String cancelDoneWithFee(int fee) {
    return 'Course annulee — frais retenus : $fee Ar';
  }

  @override
  String get profileNameEmpty => 'Le nom ne peut pas etre vide';

  @override
  String get sessionsTitle => 'Appareils connectes';

  @override
  String get sessionsManage => 'Appareils connectes';

  @override
  String get sessionsEmpty => 'Aucune session active';

  @override
  String get sessionCurrent => 'Cet appareil';

  @override
  String get sessionRevoke => 'Deconnecter';

  @override
  String get sessionRevoked => 'Appareil deconnecte';

  @override
  String get sessionUnknownDevice => 'Appareil';

  @override
  String sessionSince(String date) {
    return 'Connecte le $date';
  }

  @override
  String get profilePhoneLabel => 'Numero de telephone';

  @override
  String get profileEmailLabel => 'Adresse e-mail';

  @override
  String get profileChange => 'Changer';

  @override
  String get profileAdd => 'Ajouter';

  @override
  String get profilePhoneNone => 'Non renseigne';

  @override
  String get phoneVerificationUnavailable =>
      'La verification par SMS n\'est pas encore disponible. Reessayez plus tard.';

  @override
  String get profileSaved => 'Profil mis a jour';

  @override
  String get passwordTitle => 'Mot de passe';

  @override
  String get passwordManage => 'Mot de passe';

  @override
  String get passwordChangeTitle => 'Changer le mot de passe';

  @override
  String get passwordSetTitle => 'Definir un mot de passe';

  @override
  String get passwordCurrent => 'Mot de passe actuel';

  @override
  String get passwordNew => 'Nouveau mot de passe';

  @override
  String get passwordConfirm => 'Confirmer le mot de passe';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get passwordTooShort => '8 caracteres minimum';

  @override
  String get passwordChanged => 'Mot de passe mis a jour';

  @override
  String get passwordWrongCurrent => 'Mot de passe actuel incorrect';

  @override
  String get passwordForgot => 'Mot de passe oublie ?';

  @override
  String get passwordForgotTitle => 'Mot de passe oublie';

  @override
  String get passwordForgotHelp =>
      'Entrez votre adresse e-mail : un code vous sera envoye pour reposer votre mot de passe.';

  @override
  String get passwordReset => 'Reinitialiser le mot de passe';

  @override
  String get codeEnterTitle => 'Entrez le code';

  @override
  String codeSentToEmail(String dest) {
    return 'Un code a ete envoye a $dest.';
  }

  @override
  String codeSentToPhone(String dest) {
    return 'Un code a ete envoye au $dest.';
  }

  @override
  String get emailChangeTitle => 'Changer d\'adresse e-mail';

  @override
  String get emailNew => 'Nouvelle adresse e-mail';

  @override
  String get emailInvalid => 'Adresse e-mail invalide';

  @override
  String get phoneChangeTitle => 'Changer de numero';

  @override
  String get phoneNew => 'Nouveau numero';

  @override
  String get phoneInvalid => 'Numero malgache invalide';

  @override
  String get changeSaved => 'Modification enregistree';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonVerify => 'Verifier';

  @override
  String get commonNext => 'Continuer';

  @override
  String get appName => 'MajiChrono';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonRetry => 'Reessayer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonSeeAll => 'Tout voir';

  @override
  String get notifChannelCoursesName => 'Courses';

  @override
  String get notifChannelCoursesDesc =>
      'Acceptation, arrivee du livreur, remise du colis';

  @override
  String get notifChannelPaymentName => 'Paiement';

  @override
  String get notifChannelPaymentDesc => 'Resultat de vos paiements';

  @override
  String get notifChannelIncidentsName => 'Incidents';

  @override
  String get notifChannelIncidentsDesc => 'Problemes signales sur une course';

  @override
  String get notifChannelCommercialName => 'Offres';

  @override
  String get notifChannelCommercialDesc => 'Nouveautes et promotions';

  @override
  String get notifSettingsCommercial => 'Recevoir les offres commerciales';

  @override
  String get notifTestButton => 'Tester une notification';

  @override
  String get langFrench => 'Francais';

  @override
  String get langMalagasy => 'Malagasy';

  @override
  String get settingsTitle => 'Reglages';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsTheme => 'Apparence';

  @override
  String get themeSystem => 'Systeme';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get networkOnline => 'En ligne';

  @override
  String networkOfflinePending(int count) {
    return 'Hors ligne — $count element(s) en attente';
  }

  @override
  String get networkOfflineNoPending => 'Hors ligne';

  @override
  String get networkConnecting => 'Connexion au serveur...';

  @override
  String get networkSyncing => 'Synchronisation en cours...';

  @override
  String get welcomeTagline =>
      'Délivrer la confiance, partout, instantanément.';

  @override
  String get welcomeStart => 'Commencer';

  @override
  String get welcomeTrustNote => 'Chaque etape, securisee.';

  @override
  String get welcomePillarSpeed => 'Rapidité';

  @override
  String get welcomePillarSender => 'expéditeur';

  @override
  String get welcomePillarDriver => 'livreur';

  @override
  String get welcomePillarTrust => 'Confiance MajiChrono';

  @override
  String get authPhoneTitle => 'Votre numero';

  @override
  String get authPhoneSubtitle =>
      'Nous vous envoyons un code par SMS pour verifier ce numero.';

  @override
  String get authPhoneLabel => 'Numero de telephone';

  @override
  String get authPhoneHint => '034 12 345 67';

  @override
  String get authPhoneInvalid => 'Numero malgache invalide';

  @override
  String get authPhoneUnknownOperator =>
      'Prefixe inconnu. Utilisez un numero Orange (032), Airtel (033), Telma (034, 038) ou un fixe Telma (020).';

  @override
  String get authPhoneNoSms =>
      'Une ligne fixe ne recoit pas de SMS. Passez par l\'entree e-mail.';

  @override
  String authPhoneOperator(String operator) {
    return 'Operateur reconnu : $operator';
  }

  @override
  String get authOtpTitle => 'Code de verification';

  @override
  String authOtpSentTo(String phone) {
    return 'Code envoye au $phone';
  }

  @override
  String authOtpExpiresIn(String time) {
    return 'Expire dans $time';
  }

  @override
  String get authOtpExpired => 'Code expire. Demandez-en un nouveau.';

  @override
  String get authOtpResend => 'Renvoyer le code';

  @override
  String authOtpInvalid(int count) {
    return 'Code incorrect. Il reste $count tentative(s).';
  }

  @override
  String get authOtpLocked => 'Trop de tentatives. Demandez un nouveau code.';

  @override
  String authOtpSimulated(String code) {
    return 'Code simule : $code';
  }

  @override
  String get authOrSeparator => 'ou';

  @override
  String get authChoiceTitle => 'Comment voulez-vous continuer ?';

  @override
  String get authChoiceSubtitle => 'Les deux menent au meme compte.';

  @override
  String get authChoiceOneAccount => 'Un compte, deux voies';

  @override
  String get authChoicePhone => 'Avec mon numero';

  @override
  String get authChoicePhoneNote =>
      'Code par SMS. Le numero reste la cle de votre compte.';

  @override
  String get authChoiceEmail => 'Avec une adresse e-mail';

  @override
  String get authChoiceEmailNote =>
      'Google, Facebook, Twitter ou mot de passe.';

  @override
  String get authSignInTitle => 'Connexion a votre compte';

  @override
  String get authSignUpTitle => 'Creer votre compte';

  @override
  String get authFieldEmail => 'E-mail';

  @override
  String get authFieldPassword => 'Mot de passe';

  @override
  String get authFieldPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignUp => 'S\'inscrire';

  @override
  String get authOrSignInWith => '- Ou se connecter avec -';

  @override
  String get authOrSignUpWith => '- Ou s\'inscrire avec -';

  @override
  String get authNoAccount => 'Pas encore de compte ?';

  @override
  String get authAlreadyAccount => 'J\'ai déjà un compte';

  @override
  String get authHaveAccount => 'Deja un compte ?';

  @override
  String get authPasswordTooShort => 'Au moins 8 caracteres';

  @override
  String get authPasswordMismatch => 'Les deux mots de passe different';

  @override
  String get authBadCredentials => 'E-mail ou mot de passe incorrect';

  @override
  String get authEmailTaken => 'Cette adresse a deja un compte';

  @override
  String get authBannerFast => 'Livraison rapide';

  @override
  String get authFooterTrustTitle => 'Confiance MajiChrono';

  @override
  String get authFooterTrustNote => 'Chaque etape, securisee.';

  @override
  String get authFooterSpeedTitle => 'Rapidite MajiChrono';

  @override
  String get authFooterSpeedNote => 'L\'efficacite a chaque seconde.';

  @override
  String get authSocialFacebook => 'Facebook';

  @override
  String get authSocialTwitter => 'Twitter';

  @override
  String get authSocialGoogle => 'Google';

  @override
  String get authGoogleContinue => 'Continuer avec Google';

  @override
  String get authGoogleSheetTitle => 'Choisissez un compte';

  @override
  String get authGoogleSheetSubtitle =>
      'Nous envoyons un code de verification dans cette boite mail.';

  @override
  String get authGoogleOtherAccount => 'Une autre adresse';

  @override
  String get authGoogleOtherAccountLabel => 'Adresse e-mail';

  @override
  String get authGoogleEmailInvalid => 'Adresse e-mail invalide';

  @override
  String get authEmailCodeTitle => 'Code par e-mail';

  @override
  String authEmailCodeSentTo(String email) {
    return 'Code envoye a $email';
  }

  @override
  String get authEmailCodeHint => 'Regardez aussi le dossier indesirables.';

  @override
  String get authEmailUnlinkedTitle => 'Adresse verifiee';

  @override
  String authEmailUnlinkedBody(String email) {
    return 'Aucun compte MajiChrono n\'est encore rattache a $email. Creez votre compte avec cette adresse, ou continuez avec votre numero si vous preferez rattacher un compte existant.';
  }

  @override
  String get authEmailRegisterAction => 'Creer mon compte avec cet e-mail';

  @override
  String get authEmailUnlinkedAction => 'Continuer avec mon numero';

  @override
  String get authEmailLinked => 'Adresse rattachee a votre compte';

  @override
  String get authProfileTitle => 'Votre profil';

  @override
  String get authProfileSubtitle =>
      'Ce choix est definitif : il determine l\'application que vous utilisez.';

  @override
  String get authProfileName => 'Votre nom';

  @override
  String get authProfileNameHint => 'Nom vu par les autres';

  @override
  String get authProfileNameRequired => 'Indiquez votre nom';

  @override
  String get authProfileAdminNote =>
      'Le profil exploitation est attribue par MajiChrono, il ne se choisit pas ici.';

  @override
  String get authPinTitle => 'Creez un code a 4 chiffres';

  @override
  String get authPinSubtitle =>
      'Il protege votre compte a la reouverture de l\'application.';

  @override
  String get authPinConfirmTitle => 'Confirmez votre code';

  @override
  String get authPinMismatch => 'Les deux codes ne correspondent pas';

  @override
  String get authPinLater => 'Plus tard';

  @override
  String get authPinSaved => 'Code enregistre';

  @override
  String get authLockTitle => 'Application verrouillee';

  @override
  String get authLockSubtitle => 'Saisissez votre code pour continuer';

  @override
  String get authLockBiometrics => 'Utiliser la biometrie';

  @override
  String get authBiometricsReason => 'Deverrouiller MajiChrono';

  @override
  String get authLockWrongPin => 'Code incorrect';

  @override
  String get authSignOut => 'Se deconnecter';

  @override
  String get authSignOutConfirm =>
      'Se deconnecter effacera les donnees de cet appareil. Continuer ?';

  @override
  String authWelcome(String name) {
    return 'Bonjour $name';
  }

  @override
  String get roleChooseTitle => 'Je suis';

  @override
  String get roleClient => 'Expediteur';

  @override
  String get roleClientDesc => 'J\'envoie un colis ou je commande une course';

  @override
  String get roleDriver => 'Livreur';

  @override
  String get roleDriverDesc => 'Je realise des courses';

  @override
  String get roleAdmin => 'Exploitation';

  @override
  String get roleAdminDesc => 'Je supervise la flotte et les litiges';

  @override
  String get navHome => 'Accueil';

  @override
  String get navDeliveries => 'Courses';

  @override
  String get navTracking => 'Suivi';

  @override
  String get navEarnings => 'Gains';

  @override
  String get navProfile => 'Profil';

  @override
  String get profileAccount => 'Mon compte';

  @override
  String get profileSecurity => 'Securite';

  @override
  String get profilePinOn => 'Code de verrouillage actif';

  @override
  String get profilePinOff => 'Aucun code de verrouillage';

  @override
  String get profilePinSet => 'Definir un code';

  @override
  String get profilePinChange => 'Changer le code';

  @override
  String get profileEmailLinked => 'Adresse rattachee';

  @override
  String get profileEmailNone => 'Aucune adresse rattachee';

  @override
  String profileMemberSince(String date) {
    return 'Membre depuis $date';
  }

  @override
  String get profileRatingLabel => 'Note';

  @override
  String get driverDeliveriesEmpty => 'Aucune course pour l instant';

  @override
  String get driverDeliveriesEmptyNote =>
      'Les courses acceptees apparaissent ici, meme hors ligne.';

  @override
  String get driverDeliveriesActive => 'En cours';

  @override
  String get driverDeliveriesDone => 'Terminees';

  @override
  String get navFleet => 'Flotte';

  @override
  String get navDisputes => 'Litiges';

  @override
  String get navKyc => 'KYC';

  @override
  String get navDashboard => 'Tableau';

  @override
  String get clientHomeTitle => 'Accueil expediteur';

  @override
  String get clientNewDelivery => 'Nouvelle course';

  @override
  String get driverHomeTitle => 'Accueil livreur';

  @override
  String get adminHomeTitle => 'Supervision';

  @override
  String get newDeliveryTitle => 'Nouvelle course';

  @override
  String get stepAddresses => 'Adresses';

  @override
  String get stepPackage => 'Colis';

  @override
  String get stepOptions => 'Options';

  @override
  String get stepReview => 'Recapitulatif';

  @override
  String get addrPickupTitle => 'Adresse de depart';

  @override
  String get addrDropoffTitle => 'Adresse d\'arrivee';

  @override
  String get addrDistrict => 'Quartier';

  @override
  String get addrDistrictHint => 'Ambohipo';

  @override
  String get addrLandmark => 'Point de repere';

  @override
  String get addrLandmarkHint => 'Apres l\'epicerie Tsiky, portail vert';

  @override
  String get addrLandmarkHelp =>
      'C\'est ce qui permet au livreur de vous trouver.';

  @override
  String get addrContactPhone => 'Telephone sur place';

  @override
  String get addrContactName => 'Nom du contact';

  @override
  String get addrStreet => 'Rue et numero';

  @override
  String get addrOptional => 'facultatif';

  @override
  String get addrRequired => 'Champ obligatoire';

  @override
  String get addrSaveToBook => 'Enregistrer dans mes adresses';

  @override
  String get addrLabel => 'Nom de l\'adresse';

  @override
  String get addrLabelHint => 'Maison, Boutique';

  @override
  String get addrBookTitle => 'Mes adresses';

  @override
  String get addrBookEmpty => 'Aucune adresse enregistree';

  @override
  String get addrBookEmptyHelp =>
      'Les adresses enregistrees ici se reutilisent en un geste.';

  @override
  String get addrPickFromBook => 'Choisir dans mes adresses';

  @override
  String get addrNew => 'Saisir une nouvelle adresse';

  @override
  String get addrDelete => 'Supprimer';

  @override
  String get pkgTitle => 'Le colis';

  @override
  String get pkgWeight => 'Poids';

  @override
  String get pkgWeightLt2 => 'Moins de 2 kg';

  @override
  String get pkgWeight2to5 => '2 a 5 kg';

  @override
  String get pkgWeight5to15 => '5 a 15 kg';

  @override
  String get pkgWeightGt15 => 'Plus de 15 kg';

  @override
  String get pkgValue => 'Valeur declaree';

  @override
  String get pkgDescription => 'Description';

  @override
  String get pkgDimensions => 'Dimensions (cm)';

  @override
  String get pkgLength => 'Long.';

  @override
  String get pkgWidth => 'Larg.';

  @override
  String get pkgHeight => 'Haut.';

  @override
  String get pkgAddPhoto => 'Ajouter une photo du colis';

  @override
  String get pkgPhotoLater =>
      'La photo du colis sera demandee au module 5, avec la chaine photo.';

  @override
  String get kindTitle => 'Type de course';

  @override
  String get kindStandard => 'Colis standard';

  @override
  String get kindDocument => 'Document';

  @override
  String get kindFragile => 'Fragile';

  @override
  String get kindFood => 'Alimentaire';

  @override
  String get kindShopping => 'Achat pour compte';

  @override
  String get kindShoppingSoon => 'Disponible au module 9';

  @override
  String get slotTitle => 'Quand ?';

  @override
  String get slotImmediate => 'Immediat';

  @override
  String get slotScheduled => 'Programme';

  @override
  String get slotPickDate => 'Choisir la date';

  @override
  String slotRange(int start, int end) {
    return '${start}h - ${end}h';
  }

  @override
  String get paymentTitle => 'Paiement';

  @override
  String get paymentCash => 'Especes a la livraison';

  @override
  String get paymentMajipay => 'MajiPay';

  @override
  String get paymentMajipaySoon => 'Disponible au module 7';

  @override
  String get estimateTitle => 'Estimation du prix';

  @override
  String get estimateTotal => 'Total';

  @override
  String get estimateProvisional =>
      'Tarif provisoire : la grille definitive n\'est pas encore arretee.';

  @override
  String get priceBase => 'Prise en charge';

  @override
  String get priceDistance => 'Distance';

  @override
  String get priceWeight => 'Poids';

  @override
  String get priceKind => 'Majoration type de course';

  @override
  String get priceSchedule => 'Creneau programme';

  @override
  String get priceInsurance => 'Assurance';

  @override
  String get confirmDelivery => 'Confirmer la course';

  @override
  String get deliveryCreated => 'Course creee';

  @override
  String get deliveryQueued =>
      'Course enregistree. Elle partira des le retour du reseau.';

  @override
  String get deliveriesTitle => 'Mes courses';

  @override
  String get deliveryPendingSync => 'En attente d\'envoi';

  @override
  String get deliveryCancel => 'Annuler la course';

  @override
  String get deliveryCancelConfirm =>
      'Annuler cette course ? Des frais peuvent s\'appliquer.';

  @override
  String deliveryDistance(String km) {
    return '$km km';
  }

  @override
  String get histSearchHint => 'Rechercher une course';

  @override
  String get histFilterAll => 'Toutes';

  @override
  String get histFilterActive => 'En cours';

  @override
  String get histFilterDone => 'Terminees';

  @override
  String get histFilterCancelled => 'Annulees';

  @override
  String get histPeriodAll => 'Toute periode';

  @override
  String get histPeriod7 => '7 jours';

  @override
  String get histPeriod30 => '30 jours';

  @override
  String get histNoMatch => 'Aucune course ne correspond';

  @override
  String get histNoMatchHelp => 'Modifiez la recherche ou les filtres.';

  @override
  String histResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
      zero: 'Aucune course',
    );
    return '$_temp0';
  }

  @override
  String get custodyPickupTitle => 'Constat de prise en charge';

  @override
  String get custodyHandoverTitle => 'Constat de remise';

  @override
  String get custodyStepPhotos => 'Photos';

  @override
  String get custodyStepCondition => 'Etat';

  @override
  String get custodyStepSeal => 'Scelle';

  @override
  String get custodyStepSignatures => 'Signatures';

  @override
  String get custodyEngagement =>
      'Je certifie remettre ou prendre en charge ce colis dans l\'etat constate ci-dessus.';

  @override
  String get custodySignHere => 'Signez ici';

  @override
  String get custodyClearSignature => 'Effacer';

  @override
  String get custodySignerSender => 'Expediteur';

  @override
  String get custodySignerDriver => 'Livreur';

  @override
  String get custodySignerRecipient => 'Destinataire';

  @override
  String get custodyPhotoTop => 'Dessus';

  @override
  String get custodyPhotoBottom => 'Dessous';

  @override
  String get custodyPhotoSide1 => 'Cote 1';

  @override
  String get custodyPhotoSide2 => 'Cote 2';

  @override
  String get custodyPhotoGuide =>
      'Cadrez le colis dans le gabarit, puis declenchez.';

  @override
  String get custodyPhotoInAppOnly =>
      'Photo prise dans l\'application uniquement.';

  @override
  String get custodyPhotoRetake => 'Reprendre';

  @override
  String get custodyConditionTitle => 'Etat du colis';

  @override
  String get custodyConditionHelp =>
      'Cochez ce que vous constatez. Toute anomalie exige une photo et un commentaire.';

  @override
  String get conditionPackagingIntact => 'Emballage intact';

  @override
  String get conditionImpactMark => 'Trace de choc';

  @override
  String get conditionMoistureMark => 'Trace d\'humidite';

  @override
  String get conditionAlreadyOpened => 'Emballage deja ouvert';

  @override
  String get conditionOriginalTape => 'Scotch d\'origine present';

  @override
  String get conditionCrushedCorners => 'Angles ecrases';

  @override
  String get custodyAnomalyNote => 'Precisez l\'anomalie';

  @override
  String get custodySealNumber => 'Numero de scelle';

  @override
  String get custodySealHint => 'SC-4821';

  @override
  String get custodySealScan => 'Scanner le scelle';

  @override
  String get custodySealScanHelp =>
      'Cadrez le code-barres du scelle. Vous pourrez corriger le numero.';

  @override
  String get custodySealCheck => 'Etat du scelle';

  @override
  String get sealIntact => 'Intact';

  @override
  String get sealBroken => 'Rompu';

  @override
  String get sealAbsent => 'Absent';

  @override
  String get custodySealIncident => 'Un incident sera ouvert automatiquement.';

  @override
  String get custodyWeightConfirm => 'Poids confirme';

  @override
  String get custodyOutcomeTitle => 'Issue de la remise';

  @override
  String get custodyOutcomeHelp =>
      'Dites ce qui s\'est reellement passe. Chaque issue a ses obligations.';

  @override
  String get outcomeDelivered => 'Remis au destinataire';

  @override
  String get outcomeWithReserves => 'Remis sous reserves';

  @override
  String get outcomeRefused => 'Refuse par le destinataire';

  @override
  String get outcomeThirdParty => 'Remis a un tiers';

  @override
  String get outcomeNoSignature => 'Remis sans signature';

  @override
  String get custodyOutcomeReason => 'Motif ecrit';

  @override
  String get custodyOutcomeReasonHelp =>
      'Ce motif sera lu tel quel en cas de litige.';

  @override
  String get custodyReservesNotice => 'Un litige sera ouvert automatiquement.';

  @override
  String get custodyRefusedNotice => 'Le colis repart en retour expediteur.';

  @override
  String get custodyNoSignatureNotice =>
      'L\'exploitation sera alertee. La photo du colis remis est obligatoire.';

  @override
  String get custodyThirdPartyName => 'Nom du tiers';

  @override
  String get custodyThirdPartyRelation => 'Lien avec le destinataire';

  @override
  String get custodyThirdPartyRelationHint => 'Gardien, voisin, collegue...';

  @override
  String get custodyExtraPhotoSeal => 'Photo du scelle';

  @override
  String get custodyExtraPhotoId => 'Photo de la piece d\'identite';

  @override
  String get custodyExtraPhotoHandover => 'Photo du colis remis';

  @override
  String get custodyExtraPhotoMissing => 'Photo supplementaire requise';

  @override
  String get custodyExportPdf => 'Exporter en PDF';

  @override
  String get custodyExportPdfDone => 'Constat exporte';

  @override
  String get custodyExportPdfFailed => 'Export impossible';

  @override
  String get custodyPdfTitle => 'Constat contradictoire';

  @override
  String get custodyPdfHash => 'Empreinte SHA-256';

  @override
  String get custodyPdfPreviousHash => 'Empreinte precedente';

  @override
  String get custodyPdfSealedAt => 'Scelle le';

  @override
  String get custodyPdfServerTime => 'Recu par le serveur le';

  @override
  String get custodyPdfPending => 'Non transmis';

  @override
  String get custodyPdfNotice =>
      'Document genere par MajiChrono. Toute alteration rompt l\'empreinte.';

  @override
  String get custodyOtpTitle => 'Code du destinataire';

  @override
  String get custodyOtpHelp => 'Un code a ete envoye au destinataire par SMS.';

  @override
  String get custodyIncomplete => 'Constat incomplet';

  @override
  String get custodyValidate => 'Valider le constat';

  @override
  String get custodySealed => 'Constat scelle';

  @override
  String get custodySealedHelp =>
      'Il ne peut plus etre modifie. Toute precision sera un ajout distinct.';

  @override
  String get custodyComparatorTitle => 'Comparateur';

  @override
  String get custodyBefore => 'Prise en charge';

  @override
  String get custodyAfter => 'Remise';

  @override
  String get custodyNoDiff => 'Aucun ecart constate';

  @override
  String get custodyAppeared => 'Apparu a la remise';

  @override
  String get custodyDisappeared => 'Disparu en cours de route';

  @override
  String get custodyChainIntact => 'Chaine de preuve intacte';

  @override
  String get custodyChainBroken => 'Chaine de preuve rompue';

  @override
  String get custodyChainHelp =>
      'L\'empreinte de la remise integre celle de la prise en charge.';

  @override
  String get emergencyButton => 'Urgence';

  @override
  String get emergencyTitle => 'Alerte d\'urgence';

  @override
  String get emergencyHelp =>
      'L\'exploitation est prevenue immediatement, avec votre derniere position connue.';

  @override
  String get emergencySend => 'Envoyer l\'alerte';

  @override
  String get emergencyKindOptional => 'Preciser (facultatif)';

  @override
  String get emergencyAccident => 'Accident';

  @override
  String get emergencyAggression => 'Agression';

  @override
  String get emergencyBreakdown => 'Panne';

  @override
  String get emergencyMedical => 'Malaise';

  @override
  String get emergencyUnspecified => 'Non precise';

  @override
  String get emergencySent => 'Alerte envoyee';

  @override
  String get emergencyCallbackSoon =>
      'On vous rappelle tout de suite. Mettez-vous en securite.';

  @override
  String get emergencyAcknowledgePending =>
      'L\'exploitation a ete prevenue. Restez joignable.';

  @override
  String get economyTitle => 'Mode economie';

  @override
  String get economyHelp =>
      'Differe les photos jusqu\'a une connexion non facturee et n\'ouvre plus de nouvelles tuiles de carte.';

  @override
  String get economyProofNever =>
      'Les constats partent toujours en entier, meme en mode economie.';

  @override
  String get economyDeferPhotos => 'Differer les photos hors constat';

  @override
  String get economyBlockTiles => 'Ne pas telecharger de nouvelles tuiles';

  @override
  String get economyReduceCadence => 'Espacer l\'envoi des positions';

  @override
  String get shoppingTitle => 'Achat pour compte';

  @override
  String get shoppingHelp =>
      'Le livreur avance l\'argent et vous remet le ticket de caisse.';

  @override
  String get shoppingAddItem => 'Ajouter un article';

  @override
  String get shoppingItemLabel => 'Article';

  @override
  String get shoppingItemQuantity => 'Quantite';

  @override
  String get shoppingItemPrice => 'Prix unitaire estime';

  @override
  String get shoppingSubstitutable => 'Remplacable si indisponible';

  @override
  String get shoppingStoreHint => 'Magasin suggere (facultatif)';

  @override
  String get shoppingCap => 'Plafond de depense';

  @override
  String get shoppingCapHelp =>
      'Le livreur n\'achete pas au-dela. C\'est sa seule protection : il avance son propre argent.';

  @override
  String get shoppingCapTooLow => 'Le plafond est inferieur a votre estimation';

  @override
  String shoppingCapOutOfRange(String min, String max) {
    return 'Plafond entre $min et $max';
  }

  @override
  String get shoppingEstimated => 'Estimation des articles';

  @override
  String get shoppingEmpty => 'Aucun article';

  @override
  String get shoppingActualTotal => 'Montant paye (ticket)';

  @override
  String get shoppingReceipt => 'Ticket de caisse';

  @override
  String get shoppingReceiptMissing =>
      'Photo obligatoire pour le remboursement';

  @override
  String get shoppingReceiptTaken => 'Ticket photographie';

  @override
  String shoppingOverCap(String amount) {
    return 'Au-dela du plafond. Remboursement : $amount';
  }

  @override
  String get payerTitle => 'Qui paie';

  @override
  String get payerSender => 'Moi (port paye)';

  @override
  String get payerRecipient => 'Le destinataire (port du)';

  @override
  String get payerRecipientNotice =>
      'Prevenez votre destinataire du montant : sans cela il refusera le colis.';

  @override
  String get relayTitle => 'Point relais';

  @override
  String get relayHelp =>
      'Le colis attend en boutique. Utile si votre destinataire n\'est pas chez lui en journee.';

  @override
  String get relayNone => 'Livraison a l\'adresse';

  @override
  String get relayHours => 'Horaires';

  @override
  String relayStorage(int days) {
    return 'Garde $days jours';
  }

  @override
  String get relayTooHeavy => 'Colis trop lourd pour ce relais';

  @override
  String relayDistance(String km) {
    return 'a $km km';
  }

  @override
  String get relayPickupCodeTitle => 'Code de retrait';

  @override
  String get relayPickupCodeHelp =>
      'Le destinataire presente ce code au relais pour recuperer le colis.';

  @override
  String get commonCopy => 'Copier';

  @override
  String get groupTitle => 'Courses groupees';

  @override
  String get groupHelp =>
      'Deux a trois courses sur le meme axe. Les retraits d\'abord, les remises ensuite.';

  @override
  String groupSaved(String km) {
    return '$km km economises';
  }

  @override
  String get groupAdd => 'Grouper avec celle-ci';

  @override
  String get groupNotViable => 'Cette course fait trop devier votre trajet';

  @override
  String get groupStopPickup => 'Retrait';

  @override
  String get groupStopDropoff => 'Remise';

  @override
  String get adminReasonLabel => 'Motif de la decision';

  @override
  String adminReasonMissing(int count) {
    return 'Encore $count caracteres. Un motif sert a expliquer, pas a remplir un champ.';
  }

  @override
  String get adminReasonOk =>
      'Ce motif sera relu tel quel en cas de contestation.';

  @override
  String get adminReasonRecorded =>
      'La decision est enregistree avec son motif et son auteur.';

  @override
  String get adminDashboardTitle => 'Tableau de bord';

  @override
  String get adminActiveDeliveries => 'Courses en cours';

  @override
  String get adminOnlineDrivers => 'Livreurs en ligne';

  @override
  String get adminTotalClients => 'Clients';

  @override
  String get adminTotalDrivers => 'Livreurs';

  @override
  String get adminStatsTitle => 'Statistiques & rapports';

  @override
  String get adminStatsManage => 'Statistiques & rapports';

  @override
  String get statTotalDeliveries => 'Livraisons';

  @override
  String get statSuccessRate => 'Taux de reussite';

  @override
  String get statCancellationRate => 'Taux d\'annulation';

  @override
  String get statRevenue => 'Chiffre d\'affaires';

  @override
  String get statDriverEarnings => 'Revenus livreurs';

  @override
  String get statAvgTime => 'Temps moyen';

  @override
  String statMinutes(int min) {
    return '$min min';
  }

  @override
  String get statIncidents => 'Incidents';

  @override
  String get statDisputes => 'Litiges';

  @override
  String get statVolumes => 'Volumes';

  @override
  String get statRates => 'Taux & qualite';

  @override
  String get statTopZones => 'Zones les plus actives';

  @override
  String get statPeakHours => 'Heures de pointe';

  @override
  String get statDriverPerformance => 'Performance des livreurs';

  @override
  String get statNoData => 'Pas encore de donnees';

  @override
  String statDeliveries(int count) {
    return '$count courses';
  }

  @override
  String get adminUsersTitle => 'Utilisateurs';

  @override
  String get adminUsersManage => 'Gerer les utilisateurs';

  @override
  String get adminUsersSearch => 'Rechercher un nom ou un numero';

  @override
  String get adminUsersEmpty => 'Aucun utilisateur';

  @override
  String get adminUsersTabClients => 'Clients';

  @override
  String get adminUsersTabDrivers => 'Livreurs';

  @override
  String get adminUserSuspended => 'Suspendu';

  @override
  String get adminUserActive => 'Actif';

  @override
  String get adminOpenIncidents => 'Incidents ouverts';

  @override
  String get adminOpenDisputes => 'Litiges ouverts';

  @override
  String get adminPendingKyc => 'Dossiers a valider';

  @override
  String get adminRevenueToday => 'Encaisse aujourd\'hui';

  @override
  String get adminByStatus => 'Repartition des courses';

  @override
  String get adminFleetTitle => 'Flotte';

  @override
  String get adminFleetAll => 'Tous';

  @override
  String get adminFleetAvailable => 'Disponible';

  @override
  String get adminFleetBusy => 'En course';

  @override
  String get adminFleetOffline => 'Hors service';

  @override
  String get adminFleetSuspended => 'Suspendu';

  @override
  String get adminFleetEmpty => 'Aucun livreur dans ce filtre';

  @override
  String get adminFleetStale => 'Position ancienne';

  @override
  String get adminFleetMapUnavailable => 'Carte indisponible hors ligne';

  @override
  String get adminSuspend => 'Suspendre le compte';

  @override
  String get adminReinstate => 'Reintegrer le compte';

  @override
  String get adminSuspendHelp =>
      'Le livreur ne recevra plus de courses tant que la suspension dure.';

  @override
  String get adminReinstateHelp =>
      'Le livreur pourra de nouveau se mettre en ligne.';

  @override
  String adminSuspendedSince(String reason) {
    return 'Suspendu : $reason';
  }

  @override
  String get adminKycTitle => 'Dossiers a valider';

  @override
  String get adminKycEmpty => 'Aucun dossier en attente';

  @override
  String get adminKycIncomplete => 'Dossier incomplet';

  @override
  String get adminKycComplete => 'Dossier complet';

  @override
  String adminKycMissingDocs(int count) {
    return '$count piece(s) manquante(s)';
  }

  @override
  String get adminKycApprove => 'Valider le dossier';

  @override
  String get adminKycReject => 'Refuser le dossier';

  @override
  String get adminKycThreadButton => 'Messages du livreur';

  @override
  String get adminKycThreadTitle => 'Suivi du dossier';

  @override
  String get adminKycReplyHint => 'Repondre au livreur';

  @override
  String get adminKycThreadEmpty => 'Aucun message du livreur';

  @override
  String get adminKycApproveHelp =>
      'Le livreur entrera dans la flotte, hors service jusqu\'a ce qu\'il se mette en ligne.';

  @override
  String get adminKycRejectHelp =>
      'Le motif sera transmis au livreur pour qu\'il puisse corriger son dossier.';

  @override
  String adminKycSubmittedAt(String age) {
    return 'Depose $age';
  }

  @override
  String get adminDeliveriesTitle => 'Courses';

  @override
  String get adminDeliveriesEmpty => 'Aucune course ne correspond';

  @override
  String get adminFilterStatus => 'Statut';

  @override
  String get adminFilterSearch => 'Quartier, repere, livreur...';

  @override
  String get adminFilterClear => 'Effacer les filtres';

  @override
  String get adminReassign => 'Reaffecter';

  @override
  String get adminReassignTitle => 'Reaffecter la course';

  @override
  String get adminReassignHelp =>
      'Seuls les livreurs disponibles peuvent recevoir une course.';

  @override
  String get adminReassignPick => 'Choisir un livreur';

  @override
  String get adminReassignNone => 'Aucun livreur disponible';

  @override
  String get adminDisputesTitle => 'Litiges';

  @override
  String get adminDisputesEmpty => 'Aucun litige ouvert';

  @override
  String get adminDisputeOpen => 'Ouvert';

  @override
  String get adminDisputeInvestigating => 'En instruction';

  @override
  String get adminDisputeResolved => 'Tranche en faveur du client';

  @override
  String get adminDisputeRejected => 'Litige ecarte';

  @override
  String get adminDisputeReason => 'Motif d\'ouverture';

  @override
  String get adminDisputeReply => 'Repondre';

  @override
  String get adminDisputeMessage => 'Votre message';

  @override
  String get adminDisputeResolve => 'Trancher en faveur du client';

  @override
  String get adminDisputeDismiss => 'Ecarter le litige';

  @override
  String get adminDisputeResolveHelp =>
      'La course sera reglee au benefice du client.';

  @override
  String get adminDisputeDismissHelp => 'Le litige sera clos sans suite.';

  @override
  String get adminDisputeClosed =>
      'Litige clos. Aucune reponse n\'est plus possible.';

  @override
  String adminDisputeDecidedBy(String author) {
    return 'Decide par $author';
  }

  @override
  String get adminOpenComparator => 'Ouvrir le comparateur';

  @override
  String get adminActionDone => 'Decision enregistree';

  @override
  String get payTitle => 'Paiement';

  @override
  String get payBalance => 'Solde MajiPay';

  @override
  String get payBalanceUnavailable => 'Solde indisponible';

  @override
  String get payAmount => 'Montant a regler';

  @override
  String get payCollect => 'Encaisser';

  @override
  String get payCollectHelp =>
      'Presentez ce code au client. Il confirmera sur son telephone.';

  @override
  String get payOffer => 'Payer';

  @override
  String get payOfferHelp =>
      'Le livreur scanne ce code. Vous avez deja confirme le montant.';

  @override
  String get payScan => 'Scanner un code';

  @override
  String get payScanHelp => 'Cadrez le code affiche sur l\'autre telephone.';

  @override
  String get payScanInvalid =>
      'Ce code n\'est pas un code de paiement MajiChrono';

  @override
  String get payScanPermission => 'Autorisez l\'appareil photo pour scanner';

  @override
  String get payShowQr => 'Afficher mon code';

  @override
  String payQrExpires(int minutes) {
    return 'Code valable $minutes min';
  }

  @override
  String get payQrExpired => 'Code expire';

  @override
  String get payQrRenew => 'Generer un nouveau code';

  @override
  String get payWaiting => 'En attente du scan...';

  @override
  String get payConfirmTitle => 'Confirmer le paiement';

  @override
  String get payConfirmTo => 'Beneficiaire';

  @override
  String get payConfirmPin => 'Saisissez votre code pour confirmer';

  @override
  String payConfirmAction(String amount) {
    return 'Confirmer $amount';
  }

  @override
  String get payConfirmNever =>
      'Scanner ne suffit pas : personne ne peut debiter votre compte sans ce code.';

  @override
  String get payWrongPin => 'Code incorrect';

  @override
  String get payCaptured => 'Paiement effectue';

  @override
  String get payReceived => 'Paiement recu';

  @override
  String get payFailedInsufficient => 'Solde MajiPay insuffisant';

  @override
  String get payFailedExpired => 'Le code a expire';

  @override
  String get payFailedDeclined => 'Paiement refuse';

  @override
  String get payFailedUnavailable => 'MajiPay est indisponible';

  @override
  String get payCashFallback => 'Regler en especes';

  @override
  String get payCashHelp =>
      'La course n\'est jamais bloquee par un probleme de paiement.';

  @override
  String get payCashDone => 'Regle en especes';

  @override
  String get payReceiptTitle => 'Recu';

  @override
  String get payReceiptRef => 'Reference';

  @override
  String get payReceiptShare => 'Partager le recu';

  @override
  String get payMethodMajipay => 'MajiPay';

  @override
  String get payMethodCash => 'Especes';

  @override
  String get walletTitle => 'Mon portefeuille';

  @override
  String get walletBalanceLabel => 'Solde disponible';

  @override
  String get walletHistoryTitle => 'Historique des paiements';

  @override
  String get walletHistoryEmpty => 'Aucun paiement pour le moment';

  @override
  String get walletHistoryEmptyHelp => 'Vos reglages MajiPay apparaitront ici.';

  @override
  String get walletOutgoing => 'Paiement envoye';

  @override
  String get walletIncoming => 'Paiement recu';

  @override
  String get walletStatusPending => 'En cours';

  @override
  String get walletStatusCaptured => 'Regle';

  @override
  String get walletStatusFailed => 'Echoue';

  @override
  String get walletStatusCash => 'Regle en especes';

  @override
  String get walletRefund => 'Remboursement';

  @override
  String get walletRefundNote =>
      'En cas de course annulee apres paiement, le remboursement est traite par MajiPay sous 72 h. Contactez l\'assistance si besoin.';

  @override
  String get walletViewReceipt => 'Voir le recu';

  @override
  String get syncPendingTitle => 'Elements en attente';

  @override
  String get syncPendingEmpty => 'Tout est transmis';

  @override
  String get syncPendingEmptyHelp =>
      'Rien n\'attend d\'etre envoye au serveur.';

  @override
  String get syncPendingHelp =>
      'Ces elements partiront des le retour du reseau. Les constats passent en premier.';

  @override
  String get syncRetry => 'Relancer';

  @override
  String get syncRetryAll => 'Tout relancer';

  @override
  String get syncItemCustody => 'Constat';

  @override
  String get syncItemTransition => 'Course';

  @override
  String get syncItemPosition => 'Positions';

  @override
  String get syncItemRating => 'Notation';

  @override
  String get syncCauseNone => 'En attente d\'une fenetre reseau';

  @override
  String get syncCauseNetwork => 'Reseau indisponible';

  @override
  String get syncCauseServer => 'Le serveur n\'a pas repondu';

  @override
  String get syncCauseConflict => 'Le serveur a un autre etat';

  @override
  String get syncCauseRejected => 'Refuse par le serveur';

  @override
  String get syncCauseExhausted => 'Tentatives epuisees';

  @override
  String get syncNeverAbandon => 'Preuve : jamais abandonnee';

  @override
  String syncAttempts(int count) {
    return '$count tentatives';
  }

  @override
  String get syncAgeNow => 'a l\'instant';

  @override
  String syncAgeMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String syncAgeHours(int count) {
    return 'il y a $count h';
  }

  @override
  String syncAgeDays(int count) {
    return 'il y a $count j';
  }

  @override
  String get syncConflictNotice =>
      'Le serveur a impose son etat. Vos donnees ont ete mises a jour.';

  @override
  String get syncRetryQueued => 'Relance demandee';

  @override
  String get traitFragile => 'Fragile';

  @override
  String get traitHeavy => 'Lourd';

  @override
  String get traitValuable => 'Precieux';

  @override
  String get traitFood => 'Alimentaire';

  @override
  String get traitDocument => 'Document';

  @override
  String get traitShopping => 'Achat';

  @override
  String get driverOnline => 'En ligne';

  @override
  String get driverOffline => 'Hors service';

  @override
  String get driverOnlineHelp =>
      'Vous recevez des courses tant que vous etes en ligne.';

  @override
  String get driverOfflineHelp => 'Aucune course ne vous sera proposee.';

  @override
  String get driverAvailable => 'Courses disponibles';

  @override
  String get driverNoOffers => 'Aucune course pour l\'instant';

  @override
  String get driverNoOffersHelp =>
      'Restez en ligne : les courses arrivent au fil de la journee.';

  @override
  String get driverOfflineEmpty => 'Passez en ligne pour recevoir des courses';

  @override
  String driverPickupDistance(String km) {
    return '$km km a vide';
  }

  @override
  String get driverEarning => 'Gain estime';

  @override
  String get driverAccept => 'Accepter';

  @override
  String driverAcceptIn(int seconds) {
    return 'Accepter ($seconds s)';
  }

  @override
  String get dashAvailable => 'Disponibles';

  @override
  String get dashActive => 'En cours';

  @override
  String get dashDoneToday => 'Terminees';

  @override
  String get dashBalance => 'Solde';

  @override
  String get driverRefuse => 'Ignorer';

  @override
  String get driverDetails => 'Details de la course';

  @override
  String driverEta(int min) {
    return '~$min min';
  }

  @override
  String get driverEtaLabel => 'Temps estime';

  @override
  String get driverPackageType => 'Type de colis';

  @override
  String get driverAlreadyTaken => 'Course deja prise par un autre livreur';

  @override
  String get driverActiveDelivery => 'Course en cours';

  @override
  String get driverNavigate => 'Ouvrir l\'itineraire';

  @override
  String get driverCall => 'Appeler le contact';

  @override
  String get driverStepArrivedPickup => 'Je suis au depart';

  @override
  String get driverStepPickedUp => 'Colis pris en charge';

  @override
  String get driverStepArrivedDestination => 'Je suis a destination';

  @override
  String get driverStepDelivered => 'Colis remis';

  @override
  String get driverCustodyRequired =>
      'Un constat sera demande a cette etape (module 5).';

  @override
  String get driverIncident => 'Signaler un incident';

  @override
  String get incidentSenderAbsent => 'Expediteur absent';

  @override
  String get incidentRecipientAbsent => 'Destinataire absent';

  @override
  String get incidentAddressIncorrect => 'Adresse incorrecte';

  @override
  String get incidentPackageDamaged => 'Colis endommage';

  @override
  String get incidentPackageRefused => 'Colis refuse';

  @override
  String get incidentAccident => 'Accident';

  @override
  String get incidentGpsProblem => 'Probleme GPS';

  @override
  String get incidentVehicleProblem => 'Probleme de vehicule';

  @override
  String get incidentPaymentProblem => 'Probleme de paiement';

  @override
  String get incidentOther => 'Autre incident';

  @override
  String get outcomeWaitThenReturn =>
      'Attendre 10 minutes, puis retour expediteur';

  @override
  String get outcomeContactSupport => 'L\'exploitation vous rappelle';

  @override
  String get outcomeReturnToSender => 'Colis renvoye a l\'expediteur';

  @override
  String get outcomeReassign => 'La course sera reaffectee';

  @override
  String get outcomeDocumentThenContinue => 'Documentez, la course continue';

  @override
  String get incidentDetailTitle => 'Detail de l\'incident';

  @override
  String get incidentDescriptionLabel => 'Description (facultatif)';

  @override
  String get incidentDescriptionHint => 'Ce que vous avez constate';

  @override
  String get incidentAddPhoto => 'Ajouter une photo';

  @override
  String get incidentPhotoAdded => 'Photo ajoutee';

  @override
  String get incidentGpsAttached => 'Position jointe';

  @override
  String get incidentSubmit => 'Envoyer le signalement';

  @override
  String get incidentReported => 'Incident signale';

  @override
  String get incidentHistoryTitle => 'Incidents signales';

  @override
  String get incidentResolutionOpen => 'En cours de traitement';

  @override
  String get incidentResolutionResolved => 'Traite';

  @override
  String get earningsTitle => 'Mes gains';

  @override
  String get earningsToday => 'Aujourd\'hui';

  @override
  String get earningsWeek => 'Cette semaine';

  @override
  String get earningsMonth => 'Ce mois-ci';

  @override
  String earningsCount(int count) {
    return '$count course(s)';
  }

  @override
  String get earningsEmpty => 'Aucun gain enregistre';

  @override
  String get earningsCommission => 'Montants nets, commission deduite.';

  @override
  String get withdrawTitle => 'Retrait';

  @override
  String get withdrawAvailable => 'Solde MajiPay disponible';

  @override
  String get withdrawAction => 'Retirer';

  @override
  String get withdrawAmountLabel => 'Montant a retirer (Ar)';

  @override
  String get withdrawDestinationLabel => 'Vers (Mobile Money, compte)';

  @override
  String get withdrawConfirm => 'Confirmer le retrait';

  @override
  String withdrawSuccess(String ref) {
    return 'Retrait effectue. Reference $ref';
  }

  @override
  String get withdrawInsufficient => 'Solde insuffisant pour ce retrait';

  @override
  String get withdrawInvalidAmount => 'Montant invalide';

  @override
  String get notifCenterTitle => 'Notifications';

  @override
  String get notifCenterEmpty => 'Aucune notification pour le moment';

  @override
  String get notifCenterMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notifCenterClear => 'Effacer l\'historique';

  @override
  String get rateCta => 'Noter le livreur';

  @override
  String get rateTitle => 'Noter le livreur';

  @override
  String get rateOverall => 'Note globale';

  @override
  String get ratePunctuality => 'Ponctualite';

  @override
  String get rateService => 'Qualite du service';

  @override
  String get rateComment => 'Commentaire (optionnel)';

  @override
  String get rateSubmit => 'Envoyer l\'evaluation';

  @override
  String get rateThanks => 'Merci pour votre evaluation';

  @override
  String get rateAlready => 'Vous avez deja note cette course';

  @override
  String get notifEventAcceptedTitle => 'Course acceptee';

  @override
  String get notifEventAcceptedBody =>
      'Un livreur a pris votre course en charge.';

  @override
  String get notifEventPickedUpTitle => 'Colis recupere';

  @override
  String get notifEventPickedUpBody => 'Le livreur a recupere votre colis.';

  @override
  String get notifEventInTransitTitle => 'Colis en route';

  @override
  String get notifEventInTransitBody =>
      'Votre colis est en cours de livraison.';

  @override
  String get notifEventArrivedTitle => 'Livreur arrive';

  @override
  String get notifEventArrivedBody => 'Le livreur est arrive a destination.';

  @override
  String get notifEventDeliveredTitle => 'Livraison terminee';

  @override
  String get notifEventDeliveredBody => 'Votre colis a ete remis.';

  @override
  String get notifEventCancelledTitle => 'Course annulee';

  @override
  String get notifEventCancelledBody => 'La course a ete annulee.';

  @override
  String get notifEventPaidTitle => 'Paiement recu';

  @override
  String get notifEventPaidBody => 'Le paiement a ete regle avec succes.';

  @override
  String get kycTitle => 'Mon dossier';

  @override
  String get kycStatusDraft => 'Dossier a completer';

  @override
  String get kycStatusSubmitted => 'Dossier transmis';

  @override
  String get kycStatusUnderReview => 'En cours de verification';

  @override
  String get kycStatusApproved => 'Dossier valide';

  @override
  String get kycStatusRejected => 'Dossier refuse';

  @override
  String get kycBlocking =>
      'Vous ne pouvez pas prendre de course tant que le dossier n\'est pas valide.';

  @override
  String get kycDocCinFront => 'CIN recto';

  @override
  String get kycDocCinBack => 'CIN verso';

  @override
  String get kycDocLicence => 'Permis de conduire';

  @override
  String get kycDocSelfie => 'Photo du visage';

  @override
  String get kycDocRegistration => 'Carte grise';

  @override
  String get kycDocVehicle => 'Photo du vehicule';

  @override
  String get kycDocPlate => 'Photo de la plaque';

  @override
  String get kycCaptureLater =>
      'La prise de vue des pieces arrive au module 5.';

  @override
  String get kycSubmit => 'Transmettre le dossier';

  @override
  String get kycSubmitted => 'Dossier transmis pour verification';

  @override
  String get kycUnderReviewHelp =>
      'Votre dossier est en cours de verification.';

  @override
  String kycProgress(int done, int total) {
    return '$done pieces sur $total fournies';
  }

  @override
  String get vehicleTitle => 'Mon vehicule';

  @override
  String get vehicleManage => 'Informations du vehicule';

  @override
  String get vehicleManageHelp => 'Type, marque, modele, plaque et assurance.';

  @override
  String get vehicleType => 'Type de vehicule';

  @override
  String get vehicleTypeMoto => 'Moto';

  @override
  String get vehicleTypeBicycle => 'Velo';

  @override
  String get vehicleTypeCar => 'Voiture';

  @override
  String get vehicleTypeTricycle => 'Tricycle';

  @override
  String get vehicleBrand => 'Marque';

  @override
  String get vehicleModel => 'Modele';

  @override
  String get vehiclePlate => 'Immatriculation';

  @override
  String get vehicleInsurance => 'Echeance d\'assurance (AAAA-MM-JJ)';

  @override
  String get vehicleSave => 'Enregistrer';

  @override
  String get vehicleSaved => 'Vehicule enregistre';

  @override
  String get vehicleValidationPending => 'En attente de validation';

  @override
  String get vehicleValidationValidated => 'Vehicule valide';

  @override
  String get vehicleValidationRejected => 'Vehicule refuse';

  @override
  String get vehicleRevalidateNote =>
      'Toute modification remet la fiche en attente de validation.';

  @override
  String get kycInactiveTitle => 'Compte pas encore actif';

  @override
  String get kycInactiveMessage =>
      'Votre dossier est en cours de validation. Vous pourrez accepter des courses une fois qu\'il sera valide.';

  @override
  String get kycInactiveContact => 'Suivre mon dossier';

  @override
  String get kycInactiveClose => 'Compris';

  @override
  String get kycFollowupTitle => 'Suivi de mon dossier';

  @override
  String get kycFollowupManage => 'Contacter l\'exploitation';

  @override
  String get kycFollowupHelp =>
      'Une question sur la validation de votre dossier ? Ecrivez a l\'exploitation, elle vous repond ici.';

  @override
  String get kycFollowupHint => 'Votre message a l\'exploitation';

  @override
  String get kycFollowupEmpty => 'Aucun message pour l\'instant';

  @override
  String get kycFollowupSent => 'Message envoye';

  @override
  String get kycFollowupAdmin => 'Exploitation';

  @override
  String get kycFollowupYou => 'Vous';

  @override
  String get pickLocationTitle => 'Placer le point';

  @override
  String get pickLocationAction => 'Placer sur la carte';

  @override
  String get pickLocationSet => 'Point place';

  @override
  String get pickLocationHelp =>
      'Le point GPS approche le livreur ; le point de repere fait le reste.';

  @override
  String get trackingTitle => 'Suivi de la course';

  @override
  String get trackingTimeline => 'Etapes';

  @override
  String get trackingDriver => 'Votre livreur';

  @override
  String trackingEta(int minutes) {
    return 'Arrivee estimee dans $minutes min';
  }

  @override
  String get trackingShare => 'Partager le suivi';

  @override
  String trackingShareMessage(String url) {
    return 'Suivez votre colis MajiChrono : $url';
  }

  @override
  String get trackingCall => 'Appeler';

  @override
  String get trackingCallMasked => 'Numero masque des deux cotes';

  @override
  String trackingRating(String rating) {
    return '$rating / 5';
  }

  @override
  String get trackingPublicTitle => 'Suivi du colis';

  @override
  String get trackingPublicExpired => 'Ce lien de suivi n\'est plus valable.';

  @override
  String get trackingNoDriverYet =>
      'Aucun livreur n\'a encore accepte la course.';

  @override
  String get mapUnavailable =>
      'Carte indisponible hors ligne. Les points restent affiches.';

  @override
  String get linkCopied => 'Lien copie';

  @override
  String get statusPending => 'En attente d\'un livreur';

  @override
  String get statusAccepted => 'Livreur en route';

  @override
  String get statusAtPickup => 'Livreur au depart';

  @override
  String get statusPickedUp => 'Colis pris en charge';

  @override
  String get statusInTransit => 'En transit';

  @override
  String get statusAtDestination => 'Livreur arrive';

  @override
  String get statusDelivered => 'Livree';

  @override
  String get statusDeliveredWithReserves => 'Livree avec reserves';

  @override
  String get statusRefused => 'Refusee';

  @override
  String get statusReturning => 'Retour expediteur';

  @override
  String get statusPaid => 'Payee';

  @override
  String get statusDisputed => 'Litige';

  @override
  String get statusCancelled => 'Annulee';

  @override
  String get statusClosed => 'Cloturee';

  @override
  String get statusDraft => 'Brouillon';

  @override
  String get emptyTitle => 'Rien a afficher';

  @override
  String get emptyDeliveries => 'Aucune course pour l\'instant';

  @override
  String get emptyDeliveriesAction => 'Creer une course';

  @override
  String get errorTitle => 'Une action est necessaire';

  @override
  String get errorNetwork =>
      'Le reseau est indisponible. L\'action est enregistree et partira des le retour du reseau.';

  @override
  String get errorTimeout => 'Le serveur met trop de temps a repondre.';

  @override
  String get errorServer => 'Le service est momentanement indisponible.';

  @override
  String get errorUnauthorized => 'Votre session a expire. Reconnectez-vous.';

  @override
  String get errorConflict => 'Cette operation a deja ete traitee.';

  @override
  String get errorUpdateRequired =>
      'Une mise a jour de l\'application est necessaire.';

  @override
  String get errorStorage => 'L\'appareil ne peut pas enregistrer les donnees.';

  @override
  String get errorUnknown => 'Une erreur est survenue. Reessayez.';

  @override
  String get devPanelTitle => 'Panneau developpeur';

  @override
  String get devNetworkProfile => 'Profil reseau simule';

  @override
  String get devProfile4g => '4G';

  @override
  String get devProfile3g => '3G';

  @override
  String get devProfile2g => '2G / EDGE';

  @override
  String get devProfileOffline => 'Hors ligne (mode avion)';

  @override
  String get devFailureRate => 'Taux d\'echec injecte';

  @override
  String get devApiMode => 'Mode API';

  @override
  String get devDataUsed => 'Donnees consommees';

  @override
  String get devResetMock => 'Reinitialiser les donnees simulees';

  @override
  String get socleProbe => 'Sonde applicative';

  @override
  String get socleSyncQueue => 'File de synchronisation';

  @override
  String get settingsSwitchProfile => 'Changer de profil';

  @override
  String get dataUsageTitle => 'Ma consommation';

  @override
  String get dataUsageThisMonth => 'Ce mois-ci';

  @override
  String get dataBudgetReference => 'Budget mensuel de reference : 25 Mo';

  @override
  String get dataCatApi => 'Echanges applicatifs';

  @override
  String get dataCatPhotos => 'Photos et constats';

  @override
  String get dataCatMaps => 'Cartes';

  @override
  String get dataCatTracking => 'Suivi de position';

  @override
  String get dataCatPayment => 'Paiement';

  @override
  String get dataCatOther => 'Autres';

  @override
  String bytesKb(String value) {
    return '$value Ko';
  }

  @override
  String bytesMb(String value) {
    return '$value Mo';
  }

  @override
  String get shellModuleWip => 'Module en cours de construction';

  @override
  String shellModuleWipDesc(String module) {
    return 'Cet ecran sera livre au module $module.';
  }

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesEmpty => 'Aucune conversation';

  @override
  String get messagesEmptyHelp =>
      'Vos discussions avec les livreurs (ou expediteurs) apparaitront ici, des qu\'une course est acceptee.';

  @override
  String messagesYouPrefix(String message) {
    return 'Vous : $message';
  }

  @override
  String get chatTitle => 'Discussion';

  @override
  String get chatInputHint => 'Votre message';

  @override
  String get chatSendError => 'Message non envoye, reessayez';

  @override
  String get chatUnavailable => 'Discussion indisponible pour le moment';

  @override
  String get chatUnavailableHint =>
      'Verifiez le reseau, la relecture reprendra seule.';

  @override
  String get chatEmpty => 'Demarrez la conversation';

  @override
  String get chatEmptyHint => 'Coordonnez le retrait et la remise du colis.';

  @override
  String get chatToday => 'Aujourd\'hui';

  @override
  String get chatYesterday => 'Hier';

  @override
  String get chatRead => 'Lu';

  @override
  String get chatSent => 'Envoye';

  @override
  String get chatCall => 'Appeler';
}
