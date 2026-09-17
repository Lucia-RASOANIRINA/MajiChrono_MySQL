import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';
import 'app_localizations_mg.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('mg'),
  ];

  /// No description provided for @profileEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get profileEdit;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get profilePersonalInfo;

  /// No description provided for @profilePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get profilePhoto;

  /// No description provided for @profilePhotoFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get profilePhotoFromGallery;

  /// No description provided for @profilePhotoFromCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get profilePhotoFromCamera;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get profilePhotoRemove;

  /// No description provided for @profileName.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiche'**
  String get profileName;

  /// No description provided for @profileFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prenom'**
  String get profileFirstName;

  /// No description provided for @profileLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get profileLastName;

  /// No description provided for @addressBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes adresses'**
  String get addressBookTitle;

  /// No description provided for @addressBookManage.
  ///
  /// In fr, this message translates to:
  /// **'Mes adresses'**
  String get addressBookManage;

  /// No description provided for @addressAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une adresse'**
  String get addressAdd;

  /// No description provided for @addressEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'adresse'**
  String get addressEditTitle;

  /// No description provided for @addressLabelField.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex. Maison, Boutique)'**
  String get addressLabelField;

  /// No description provided for @addressKindLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get addressKindLabel;

  /// No description provided for @addressKindHome.
  ///
  /// In fr, this message translates to:
  /// **'Domicile'**
  String get addressKindHome;

  /// No description provided for @addressKindWork.
  ///
  /// In fr, this message translates to:
  /// **'Travail'**
  String get addressKindWork;

  /// No description provided for @addressKindFavorite.
  ///
  /// In fr, this message translates to:
  /// **'Favori'**
  String get addressKindFavorite;

  /// No description provided for @addressKindOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get addressKindOther;

  /// No description provided for @addressEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse enregistree'**
  String get addressEmpty;

  /// No description provided for @addressEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos adresses habituelles pour aller plus vite.'**
  String get addressEmptyHelp;

  /// No description provided for @addressSaved.
  ///
  /// In fr, this message translates to:
  /// **'Adresse enregistree'**
  String get addressSaved;

  /// No description provided for @addressDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Adresse supprimee'**
  String get addressDeleted;

  /// No description provided for @addressNeedPoint.
  ///
  /// In fr, this message translates to:
  /// **'Placez d\'abord l\'adresse sur la carte'**
  String get addressNeedPoint;

  /// No description provided for @addressPickSaved.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans mes adresses'**
  String get addressPickSaved;

  /// No description provided for @helpCenterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide et support'**
  String get helpCenterTitle;

  /// No description provided for @helpCenterManage.
  ///
  /// In fr, this message translates to:
  /// **'Aide et support'**
  String get helpCenterManage;

  /// No description provided for @helpContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get helpContactTitle;

  /// No description provided for @helpContactHelp.
  ///
  /// In fr, this message translates to:
  /// **'Notre equipe repond aux heures ouvrees.'**
  String get helpContactHelp;

  /// No description provided for @helpCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get helpCall;

  /// No description provided for @helpEmail.
  ///
  /// In fr, this message translates to:
  /// **'Ecrire'**
  String get helpEmail;

  /// No description provided for @helpReportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un probleme'**
  String get helpReportProblem;

  /// No description provided for @helpReportProblemHelp.
  ///
  /// In fr, this message translates to:
  /// **'Un souci avec une course ? Ecrivez-nous en indiquant son numero.'**
  String get helpReportProblemHelp;

  /// No description provided for @helpReportSubject.
  ///
  /// In fr, this message translates to:
  /// **'MajiChrono — signalement'**
  String get helpReportSubject;

  /// No description provided for @helpFaqTitle.
  ///
  /// In fr, this message translates to:
  /// **'Questions frequentes'**
  String get helpFaqTitle;

  /// No description provided for @helpFaqQ1.
  ///
  /// In fr, this message translates to:
  /// **'Comment creer une livraison ?'**
  String get helpFaqQ1;

  /// No description provided for @helpFaqA1.
  ///
  /// In fr, this message translates to:
  /// **'Depuis l\'accueil, touchez « Nouvelle livraison » : choisissez le depart et la destination, decrivez le colis, puis confirmez.'**
  String get helpFaqA1;

  /// No description provided for @helpFaqQ2.
  ///
  /// In fr, this message translates to:
  /// **'Comment suivre ma livraison ?'**
  String get helpFaqQ2;

  /// No description provided for @helpFaqA2.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez la course dans « Mes courses » : vous y voyez le statut en temps reel, la position du livreur et l\'heure d\'arrivee estimee.'**
  String get helpFaqA2;

  /// No description provided for @helpFaqQ3.
  ///
  /// In fr, this message translates to:
  /// **'Comment payer ?'**
  String get helpFaqQ3;

  /// No description provided for @helpFaqA3.
  ///
  /// In fr, this message translates to:
  /// **'Par MajiPay (code QR) ou en especes a la remise. Le detail du tarif s\'affiche avant de confirmer.'**
  String get helpFaqA3;

  /// No description provided for @helpFaqQ4.
  ///
  /// In fr, this message translates to:
  /// **'Puis-je annuler une course ?'**
  String get helpFaqQ4;

  /// No description provided for @helpFaqA4.
  ///
  /// In fr, this message translates to:
  /// **'Oui, tant que le livreur n\'a pas encore pris le colis en charge.'**
  String get helpFaqA4;

  /// No description provided for @helpFaqQ5.
  ///
  /// In fr, this message translates to:
  /// **'Comment enregistrer mes adresses ?'**
  String get helpFaqQ5;

  /// No description provided for @helpFaqA5.
  ///
  /// In fr, this message translates to:
  /// **'Dans Reglages, Mes adresses : ajoutez votre domicile, votre travail et vos favoris pour aller plus vite.'**
  String get helpFaqA5;

  /// No description provided for @helpFaqQ6.
  ///
  /// In fr, this message translates to:
  /// **'Un livreur est-il fiable ?'**
  String get helpFaqQ6;

  /// No description provided for @helpFaqA6.
  ///
  /// In fr, this message translates to:
  /// **'Chaque livreur passe une verification d\'identite (KYC) avant de pouvoir accepter des courses, et vous pouvez le noter apres la livraison.'**
  String get helpFaqA6;

  /// No description provided for @disputesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes litiges'**
  String get disputesTitle;

  /// No description provided for @disputesManage.
  ///
  /// In fr, this message translates to:
  /// **'Litiges et reclamations'**
  String get disputesManage;

  /// No description provided for @disputesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun litige'**
  String get disputesEmpty;

  /// No description provided for @disputesEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Un probleme avec une course ? Ouvrez un litige depuis son suivi.'**
  String get disputesEmptyHelp;

  /// No description provided for @disputeOpenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir un litige'**
  String get disputeOpenTitle;

  /// No description provided for @disputeOpenHelp.
  ///
  /// In fr, this message translates to:
  /// **'Decrivez le probleme rencontre. Notre equipe instruit le dossier avec le livreur.'**
  String get disputeOpenHelp;

  /// No description provided for @disputeReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif du litige'**
  String get disputeReasonLabel;

  /// No description provided for @disputeReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : colis abime a la reception'**
  String get disputeReasonHint;

  /// No description provided for @disputeOpenAction.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le litige'**
  String get disputeOpenAction;

  /// No description provided for @disputeOpened.
  ///
  /// In fr, this message translates to:
  /// **'Litige ouvert'**
  String get disputeOpened;

  /// No description provided for @disputeReportButton.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un litige'**
  String get disputeReportButton;

  /// No description provided for @disputeStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get disputeStatusOpen;

  /// No description provided for @disputeStatusInvestigating.
  ///
  /// In fr, this message translates to:
  /// **'En instruction'**
  String get disputeStatusInvestigating;

  /// No description provided for @disputeStatusResolved.
  ///
  /// In fr, this message translates to:
  /// **'Resolu'**
  String get disputeStatusResolved;

  /// No description provided for @disputeStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejete'**
  String get disputeStatusRejected;

  /// No description provided for @disputeReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get disputeReason;

  /// No description provided for @disputeThread.
  ///
  /// In fr, this message translates to:
  /// **'Echanges'**
  String get disputeThread;

  /// No description provided for @disputeNoMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun echange pour l\'instant.'**
  String get disputeNoMessages;

  /// No description provided for @disputeReplyHint.
  ///
  /// In fr, this message translates to:
  /// **'Ecrire un message'**
  String get disputeReplyHint;

  /// No description provided for @disputeSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get disputeSend;

  /// No description provided for @disputeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Ce litige est clos.'**
  String get disputeClosed;

  /// No description provided for @disputeDecision.
  ///
  /// In fr, this message translates to:
  /// **'Decision'**
  String get disputeDecision;

  /// No description provided for @disputeAuthorYou.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get disputeAuthorYou;

  /// No description provided for @disputeOpenedOn.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert le {date}'**
  String disputeOpenedOn(String date);

  /// No description provided for @disputeReasonTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Detaillez un peu plus (10 caracteres minimum).'**
  String get disputeReasonTooShort;

  /// No description provided for @cancelDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la course'**
  String get cancelDelivery;

  /// No description provided for @cancelSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la course ?'**
  String get cancelSheetTitle;

  /// No description provided for @cancelSheetHelp.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un motif. Des frais peuvent s\'appliquer si un livreur est deja en route.'**
  String get cancelSheetHelp;

  /// No description provided for @cancelReasonMind.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai change d\'avis'**
  String get cancelReasonMind;

  /// No description provided for @cancelReasonWrongAddress.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'adresse'**
  String get cancelReasonWrongAddress;

  /// No description provided for @cancelReasonTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Attente trop longue'**
  String get cancelReasonTooLong;

  /// No description provided for @cancelReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre raison'**
  String get cancelReasonOther;

  /// No description provided for @cancelConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'annulation'**
  String get cancelConfirm;

  /// No description provided for @cancelKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder la course'**
  String get cancelKeep;

  /// No description provided for @cancelDone.
  ///
  /// In fr, this message translates to:
  /// **'Course annulee'**
  String get cancelDone;

  /// No description provided for @cancelDoneWithFee.
  ///
  /// In fr, this message translates to:
  /// **'Course annulee — frais retenus : {fee} Ar'**
  String cancelDoneWithFee(int fee);

  /// No description provided for @profileNameEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne peut pas etre vide'**
  String get profileNameEmpty;

  /// No description provided for @sessionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectes'**
  String get sessionsTitle;

  /// No description provided for @sessionsManage.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectes'**
  String get sessionsManage;

  /// No description provided for @sessionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune session active'**
  String get sessionsEmpty;

  /// No description provided for @sessionCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil'**
  String get sessionCurrent;

  /// No description provided for @sessionRevoke.
  ///
  /// In fr, this message translates to:
  /// **'Deconnecter'**
  String get sessionRevoke;

  /// No description provided for @sessionRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Appareil deconnecte'**
  String get sessionRevoked;

  /// No description provided for @sessionUnknownDevice.
  ///
  /// In fr, this message translates to:
  /// **'Appareil'**
  String get sessionUnknownDevice;

  /// No description provided for @sessionSince.
  ///
  /// In fr, this message translates to:
  /// **'Connecte le {date}'**
  String sessionSince(String date);

  /// No description provided for @profilePhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numero de telephone'**
  String get profilePhoneLabel;

  /// No description provided for @profileEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get profileEmailLabel;

  /// No description provided for @profileChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get profileChange;

  /// No description provided for @profileAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get profileAdd;

  /// No description provided for @profilePhoneNone.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigne'**
  String get profilePhoneNone;

  /// No description provided for @phoneVerificationUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La verification par SMS n\'est pas encore disponible. Reessayez plus tard.'**
  String get phoneVerificationUnavailable;

  /// No description provided for @profileSaved.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis a jour'**
  String get profileSaved;

  /// No description provided for @passwordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordTitle;

  /// No description provided for @passwordManage.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordManage;

  /// No description provided for @passwordChangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get passwordChangeTitle;

  /// No description provided for @passwordSetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Definir un mot de passe'**
  String get passwordSetTitle;

  /// No description provided for @passwordCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel'**
  String get passwordCurrent;

  /// No description provided for @passwordNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get passwordNew;

  /// No description provided for @passwordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get passwordConfirm;

  /// No description provided for @passwordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordMismatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'8 caracteres minimum'**
  String get passwordTooShort;

  /// No description provided for @passwordChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe mis a jour'**
  String get passwordChanged;

  /// No description provided for @passwordWrongCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel incorrect'**
  String get passwordWrongCurrent;

  /// No description provided for @passwordForgot.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublie ?'**
  String get passwordForgot;

  /// No description provided for @passwordForgotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublie'**
  String get passwordForgotTitle;

  /// No description provided for @passwordForgotHelp.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre adresse e-mail : un code vous sera envoye pour reposer votre mot de passe.'**
  String get passwordForgotHelp;

  /// No description provided for @passwordReset.
  ///
  /// In fr, this message translates to:
  /// **'Reinitialiser le mot de passe'**
  String get passwordReset;

  /// No description provided for @codeEnterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code'**
  String get codeEnterTitle;

  /// No description provided for @codeSentToEmail.
  ///
  /// In fr, this message translates to:
  /// **'Un code a ete envoye a {dest}.'**
  String codeSentToEmail(String dest);

  /// No description provided for @codeSentToPhone.
  ///
  /// In fr, this message translates to:
  /// **'Un code a ete envoye au {dest}.'**
  String codeSentToPhone(String dest);

  /// No description provided for @emailChangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'adresse e-mail'**
  String get emailChangeTitle;

  /// No description provided for @emailNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle adresse e-mail'**
  String get emailNew;

  /// No description provided for @emailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide'**
  String get emailInvalid;

  /// No description provided for @phoneChangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer de numero'**
  String get phoneChangeTitle;

  /// No description provided for @phoneNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau numero'**
  String get phoneNew;

  /// No description provided for @phoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numero malgache invalide'**
  String get phoneInvalid;

  /// No description provided for @changeSaved.
  ///
  /// In fr, this message translates to:
  /// **'Modification enregistree'**
  String get changeSaved;

  /// No description provided for @commonSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get commonSend;

  /// No description provided for @commonVerify.
  ///
  /// In fr, this message translates to:
  /// **'Verifier'**
  String get commonVerify;

  /// No description provided for @commonNext.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonNext;

  /// Nom du produit
  ///
  /// In fr, this message translates to:
  /// **'MajiChrono'**
  String get appName;

  /// No description provided for @commonContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Reessayer'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get commonSearch;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get commonLoading;

  /// No description provided for @commonSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get commonSeeAll;

  /// No description provided for @notifChannelCoursesName.
  ///
  /// In fr, this message translates to:
  /// **'Courses'**
  String get notifChannelCoursesName;

  /// No description provided for @notifChannelCoursesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Acceptation, arrivee du livreur, remise du colis'**
  String get notifChannelCoursesDesc;

  /// No description provided for @notifChannelPaymentName.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get notifChannelPaymentName;

  /// No description provided for @notifChannelPaymentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Resultat de vos paiements'**
  String get notifChannelPaymentDesc;

  /// No description provided for @notifChannelIncidentsName.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get notifChannelIncidentsName;

  /// No description provided for @notifChannelIncidentsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Problemes signales sur une course'**
  String get notifChannelIncidentsDesc;

  /// No description provided for @notifChannelCommercialName.
  ///
  /// In fr, this message translates to:
  /// **'Offres'**
  String get notifChannelCommercialName;

  /// No description provided for @notifChannelCommercialDesc.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautes et promotions'**
  String get notifChannelCommercialDesc;

  /// No description provided for @notifSettingsCommercial.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir les offres commerciales'**
  String get notifSettingsCommercial;

  /// No description provided for @notifTestButton.
  ///
  /// In fr, this message translates to:
  /// **'Tester une notification'**
  String get notifTestButton;

  /// No description provided for @langFrench.
  ///
  /// In fr, this message translates to:
  /// **'Francais'**
  String get langFrench;

  /// No description provided for @langMalagasy.
  ///
  /// In fr, this message translates to:
  /// **'Malagasy'**
  String get langMalagasy;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reglages'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Systeme'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @networkOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get networkOnline;

  /// Bandeau reseau EXI-T06
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — {count} element(s) en attente'**
  String networkOfflinePending(int count);

  /// No description provided for @networkOfflineNoPending.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get networkOfflineNoPending;

  /// No description provided for @networkConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur...'**
  String get networkConnecting;

  /// No description provided for @networkSyncing.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation en cours...'**
  String get networkSyncing;

  /// No description provided for @welcomeTagline.
  ///
  /// In fr, this message translates to:
  /// **'Délivrer la confiance, partout, instantanément.'**
  String get welcomeTagline;

  /// No description provided for @welcomeStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get welcomeStart;

  /// No description provided for @welcomeTrustNote.
  ///
  /// In fr, this message translates to:
  /// **'Chaque etape, securisee.'**
  String get welcomeTrustNote;

  /// No description provided for @welcomePillarSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Rapidité'**
  String get welcomePillarSpeed;

  /// No description provided for @welcomePillarSender.
  ///
  /// In fr, this message translates to:
  /// **'expéditeur'**
  String get welcomePillarSender;

  /// No description provided for @welcomePillarDriver.
  ///
  /// In fr, this message translates to:
  /// **'livreur'**
  String get welcomePillarDriver;

  /// No description provided for @welcomePillarTrust.
  ///
  /// In fr, this message translates to:
  /// **'Confiance MajiChrono'**
  String get welcomePillarTrust;

  /// No description provided for @authPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre numero'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous vous envoyons un code par SMS pour verifier ce numero.'**
  String get authPhoneSubtitle;

  /// No description provided for @authPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numero de telephone'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'034 12 345 67'**
  String get authPhoneHint;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numero malgache invalide'**
  String get authPhoneInvalid;

  /// No description provided for @authPhoneUnknownOperator.
  ///
  /// In fr, this message translates to:
  /// **'Prefixe inconnu. Utilisez un numero Orange (032), Airtel (033), Telma (034, 038) ou un fixe Telma (020).'**
  String get authPhoneUnknownOperator;

  /// No description provided for @authPhoneNoSms.
  ///
  /// In fr, this message translates to:
  /// **'Une ligne fixe ne recoit pas de SMS. Passez par l\'entree e-mail.'**
  String get authPhoneNoSms;

  /// No description provided for @authPhoneOperator.
  ///
  /// In fr, this message translates to:
  /// **'Operateur reconnu : {operator}'**
  String authPhoneOperator(String operator);

  /// No description provided for @authOtpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de verification'**
  String get authOtpTitle;

  /// No description provided for @authOtpSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoye au {phone}'**
  String authOtpSentTo(String phone);

  /// No description provided for @authOtpExpiresIn.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {time}'**
  String authOtpExpiresIn(String time);

  /// No description provided for @authOtpExpired.
  ///
  /// In fr, this message translates to:
  /// **'Code expire. Demandez-en un nouveau.'**
  String get authOtpExpired;

  /// No description provided for @authOtpResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authOtpResend;

  /// No description provided for @authOtpInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect. Il reste {count} tentative(s).'**
  String authOtpInvalid(int count);

  /// No description provided for @authOtpLocked.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Demandez un nouveau code.'**
  String get authOtpLocked;

  /// No description provided for @authOtpSimulated.
  ///
  /// In fr, this message translates to:
  /// **'Code simule : {code}'**
  String authOtpSimulated(String code);

  /// No description provided for @authOrSeparator.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get authOrSeparator;

  /// No description provided for @authChoiceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comment voulez-vous continuer ?'**
  String get authChoiceTitle;

  /// No description provided for @authChoiceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les deux menent au meme compte.'**
  String get authChoiceSubtitle;

  /// No description provided for @authChoiceOneAccount.
  ///
  /// In fr, this message translates to:
  /// **'Un compte, deux voies'**
  String get authChoiceOneAccount;

  /// No description provided for @authChoicePhone.
  ///
  /// In fr, this message translates to:
  /// **'Avec mon numero'**
  String get authChoicePhone;

  /// No description provided for @authChoicePhoneNote.
  ///
  /// In fr, this message translates to:
  /// **'Code par SMS. Le numero reste la cle de votre compte.'**
  String get authChoicePhoneNote;

  /// No description provided for @authChoiceEmail.
  ///
  /// In fr, this message translates to:
  /// **'Avec une adresse e-mail'**
  String get authChoiceEmail;

  /// No description provided for @authChoiceEmailNote.
  ///
  /// In fr, this message translates to:
  /// **'Google, Facebook, Twitter ou mot de passe.'**
  String get authChoiceEmailNote;

  /// No description provided for @authSmsUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Verification par SMS indisponible'**
  String get authSmsUnavailableTitle;

  /// No description provided for @authSmsUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'envoi de SMS n\'est pas encore disponible. Inscrivez-vous avec votre adresse e-mail : le code de verification vous sera envoye par e-mail.'**
  String get authSmsUnavailableMessage;

  /// No description provided for @authSmsUnavailableAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec mon e-mail'**
  String get authSmsUnavailableAction;

  /// No description provided for @authSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion a votre compte'**
  String get authSignInTitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Creer votre compte'**
  String get authSignUpTitle;

  /// No description provided for @authFieldEmail.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get authFieldEmail;

  /// No description provided for @authFieldPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authFieldPassword;

  /// No description provided for @authFieldPasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authFieldPasswordConfirm;

  /// No description provided for @authSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get authSignUp;

  /// No description provided for @authOrSignInWith.
  ///
  /// In fr, this message translates to:
  /// **'- Ou se connecter avec -'**
  String get authOrSignInWith;

  /// No description provided for @authOrSignUpWith.
  ///
  /// In fr, this message translates to:
  /// **'- Ou s\'inscrire avec -'**
  String get authOrSignUpWith;

  /// No description provided for @authNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get authNoAccount;

  /// No description provided for @authAlreadyAccount.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get authAlreadyAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Deja un compte ?'**
  String get authHaveAccount;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 8 caracteres'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe different'**
  String get authPasswordMismatch;

  /// No description provided for @authBadCredentials.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou mot de passe incorrect'**
  String get authBadCredentials;

  /// No description provided for @authEmailTaken.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse a deja un compte'**
  String get authEmailTaken;

  /// No description provided for @authBannerFast.
  ///
  /// In fr, this message translates to:
  /// **'Livraison rapide'**
  String get authBannerFast;

  /// No description provided for @authFooterTrustTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confiance MajiChrono'**
  String get authFooterTrustTitle;

  /// No description provided for @authFooterTrustNote.
  ///
  /// In fr, this message translates to:
  /// **'Chaque etape, securisee.'**
  String get authFooterTrustNote;

  /// No description provided for @authFooterSpeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rapidite MajiChrono'**
  String get authFooterSpeedTitle;

  /// No description provided for @authFooterSpeedNote.
  ///
  /// In fr, this message translates to:
  /// **'L\'efficacite a chaque seconde.'**
  String get authFooterSpeedNote;

  /// No description provided for @authSocialFacebook.
  ///
  /// In fr, this message translates to:
  /// **'Facebook'**
  String get authSocialFacebook;

  /// No description provided for @authSocialTwitter.
  ///
  /// In fr, this message translates to:
  /// **'Twitter'**
  String get authSocialTwitter;

  /// No description provided for @authSocialGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Google'**
  String get authSocialGoogle;

  /// No description provided for @authGoogleContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authGoogleContinue;

  /// No description provided for @authGoogleSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un compte'**
  String get authGoogleSheetTitle;

  /// No description provided for @authGoogleSheetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous envoyons un code de verification dans cette boite mail.'**
  String get authGoogleSheetSubtitle;

  /// No description provided for @authGoogleOtherAccount.
  ///
  /// In fr, this message translates to:
  /// **'Une autre adresse'**
  String get authGoogleOtherAccount;

  /// No description provided for @authGoogleOtherAccountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authGoogleOtherAccountLabel;

  /// No description provided for @authGoogleEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide'**
  String get authGoogleEmailInvalid;

  /// No description provided for @authEmailCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code par e-mail'**
  String get authEmailCodeTitle;

  /// No description provided for @authEmailCodeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoye a {email}'**
  String authEmailCodeSentTo(String email);

  /// No description provided for @authEmailCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Regardez aussi le dossier indesirables.'**
  String get authEmailCodeHint;

  /// No description provided for @authEmailUnlinkedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse verifiee'**
  String get authEmailUnlinkedTitle;

  /// No description provided for @authEmailUnlinkedBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte MajiChrono n\'est encore rattache a {email}. Creez votre compte avec cette adresse, ou continuez avec votre numero si vous preferez rattacher un compte existant.'**
  String authEmailUnlinkedBody(String email);

  /// No description provided for @authEmailRegisterAction.
  ///
  /// In fr, this message translates to:
  /// **'Creer mon compte avec cet e-mail'**
  String get authEmailRegisterAction;

  /// No description provided for @authEmailUnlinkedAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec mon numero'**
  String get authEmailUnlinkedAction;

  /// No description provided for @authEmailCreatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé avec succès'**
  String get authEmailCreatedTitle;

  /// No description provided for @authEmailCreatedBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse e-mail est vérifiée. Vous pouvez ajouter un numéro de téléphone maintenant ou continuer sans numéro.'**
  String get authEmailCreatedBody;

  /// No description provided for @authEmailAddPhoneAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un numéro'**
  String get authEmailAddPhoneAction;

  /// No description provided for @authEmailContinueAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authEmailContinueAction;

  /// No description provided for @authEmailLinked.
  ///
  /// In fr, this message translates to:
  /// **'Adresse rattachee a votre compte'**
  String get authEmailLinked;

  /// No description provided for @authProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get authProfileTitle;

  /// No description provided for @authProfileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce choix est definitif : il determine l\'application que vous utilisez.'**
  String get authProfileSubtitle;

  /// No description provided for @authProfileName.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom'**
  String get authProfileName;

  /// No description provided for @authProfileNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom vu par les autres'**
  String get authProfileNameHint;

  /// No description provided for @authProfileNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre nom'**
  String get authProfileNameRequired;

  /// No description provided for @authProfileAdminNote.
  ///
  /// In fr, this message translates to:
  /// **'Le profil exploitation est attribue par MajiChrono, il ne se choisit pas ici.'**
  String get authProfileAdminNote;

  /// No description provided for @authPinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Creez un code a 4 chiffres'**
  String get authPinTitle;

  /// No description provided for @authPinSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Il protege votre compte a la reouverture de l\'application.'**
  String get authPinSubtitle;

  /// No description provided for @authPinConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre code'**
  String get authPinConfirmTitle;

  /// No description provided for @authPinMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux codes ne correspondent pas'**
  String get authPinMismatch;

  /// No description provided for @authPinLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get authPinLater;

  /// No description provided for @authPinSaved.
  ///
  /// In fr, this message translates to:
  /// **'Code enregistre'**
  String get authPinSaved;

  /// No description provided for @authLockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Application verrouillee'**
  String get authLockTitle;

  /// No description provided for @authLockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre code pour continuer'**
  String get authLockSubtitle;

  /// No description provided for @authLockBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser la biometrie'**
  String get authLockBiometrics;

  /// No description provided for @authBiometricsReason.
  ///
  /// In fr, this message translates to:
  /// **'Deverrouiller MajiChrono'**
  String get authBiometricsReason;

  /// No description provided for @authLockWrongPin.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get authLockWrongPin;

  /// No description provided for @authSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se deconnecter'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Se deconnecter effacera les donnees de cet appareil. Continuer ?'**
  String get authSignOutConfirm;

  /// No description provided for @authWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String authWelcome(String name);

  /// No description provided for @roleChooseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Je suis'**
  String get roleChooseTitle;

  /// No description provided for @roleClient.
  ///
  /// In fr, this message translates to:
  /// **'Expediteur'**
  String get roleClient;

  /// No description provided for @roleClientDesc.
  ///
  /// In fr, this message translates to:
  /// **'J\'envoie un colis ou je commande une course'**
  String get roleClientDesc;

  /// No description provided for @roleDriver.
  ///
  /// In fr, this message translates to:
  /// **'Livreur'**
  String get roleDriver;

  /// No description provided for @roleDriverDesc.
  ///
  /// In fr, this message translates to:
  /// **'Je realise des courses'**
  String get roleDriverDesc;

  /// No description provided for @roleAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Exploitation'**
  String get roleAdmin;

  /// No description provided for @roleAdminDesc.
  ///
  /// In fr, this message translates to:
  /// **'Je supervise la flotte et les litiges'**
  String get roleAdminDesc;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'Courses'**
  String get navDeliveries;

  /// No description provided for @navTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get navTracking;

  /// No description provided for @navEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Gains'**
  String get navEarnings;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @profileAccount.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get profileAccount;

  /// No description provided for @profileSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Securite'**
  String get profileSecurity;

  /// No description provided for @profilePinOn.
  ///
  /// In fr, this message translates to:
  /// **'Code de verrouillage actif'**
  String get profilePinOn;

  /// No description provided for @profilePinOff.
  ///
  /// In fr, this message translates to:
  /// **'Aucun code de verrouillage'**
  String get profilePinOff;

  /// No description provided for @profilePinSet.
  ///
  /// In fr, this message translates to:
  /// **'Definir un code'**
  String get profilePinSet;

  /// No description provided for @profilePinChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer le code'**
  String get profilePinChange;

  /// No description provided for @profileEmailLinked.
  ///
  /// In fr, this message translates to:
  /// **'Adresse rattachee'**
  String get profileEmailLinked;

  /// No description provided for @profileEmailNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse rattachee'**
  String get profileEmailNone;

  /// No description provided for @profileMemberSince.
  ///
  /// In fr, this message translates to:
  /// **'Membre depuis {date}'**
  String profileMemberSince(String date);

  /// No description provided for @profileRatingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get profileRatingLabel;

  /// No description provided for @driverDeliveriesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course pour l instant'**
  String get driverDeliveriesEmpty;

  /// No description provided for @driverDeliveriesEmptyNote.
  ///
  /// In fr, this message translates to:
  /// **'Les courses acceptees apparaissent ici, meme hors ligne.'**
  String get driverDeliveriesEmptyNote;

  /// No description provided for @driverDeliveriesActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get driverDeliveriesActive;

  /// No description provided for @driverDeliveriesDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminees'**
  String get driverDeliveriesDone;

  /// No description provided for @navFleet.
  ///
  /// In fr, this message translates to:
  /// **'Flotte'**
  String get navFleet;

  /// No description provided for @navDisputes.
  ///
  /// In fr, this message translates to:
  /// **'Litiges'**
  String get navDisputes;

  /// No description provided for @navKyc.
  ///
  /// In fr, this message translates to:
  /// **'KYC'**
  String get navKyc;

  /// Libelle de barre de navigation : doit tenir sur une ligne a 320 dp de large avec 4 destinations (EXI-P09). Le titre complet reste dans la barre de titre.
  ///
  /// In fr, this message translates to:
  /// **'Tableau'**
  String get navDashboard;

  /// No description provided for @clientHomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accueil expediteur'**
  String get clientHomeTitle;

  /// No description provided for @clientNewDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle course'**
  String get clientNewDelivery;

  /// No description provided for @driverHomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accueil livreur'**
  String get driverHomeTitle;

  /// No description provided for @adminHomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supervision'**
  String get adminHomeTitle;

  /// No description provided for @newDeliveryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle course'**
  String get newDeliveryTitle;

  /// No description provided for @stepAddresses.
  ///
  /// In fr, this message translates to:
  /// **'Adresses'**
  String get stepAddresses;

  /// No description provided for @stepPackage.
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get stepPackage;

  /// No description provided for @stepOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get stepOptions;

  /// No description provided for @stepReview.
  ///
  /// In fr, this message translates to:
  /// **'Recapitulatif'**
  String get stepReview;

  /// No description provided for @addrPickupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de depart'**
  String get addrPickupTitle;

  /// No description provided for @addrDropoffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse d\'arrivee'**
  String get addrDropoffTitle;

  /// No description provided for @addrDistrict.
  ///
  /// In fr, this message translates to:
  /// **'Quartier'**
  String get addrDistrict;

  /// No description provided for @addrDistrictHint.
  ///
  /// In fr, this message translates to:
  /// **'Ambohipo'**
  String get addrDistrictHint;

  /// No description provided for @addrLandmark.
  ///
  /// In fr, this message translates to:
  /// **'Point de repere'**
  String get addrLandmark;

  /// No description provided for @addrLandmarkHint.
  ///
  /// In fr, this message translates to:
  /// **'Apres l\'epicerie Tsiky, portail vert'**
  String get addrLandmarkHint;

  /// No description provided for @addrLandmarkHelp.
  ///
  /// In fr, this message translates to:
  /// **'C\'est ce qui permet au livreur de vous trouver.'**
  String get addrLandmarkHelp;

  /// No description provided for @addrContactPhone.
  ///
  /// In fr, this message translates to:
  /// **'Telephone sur place'**
  String get addrContactPhone;

  /// No description provided for @addrContactName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du contact'**
  String get addrContactName;

  /// No description provided for @addrStreet.
  ///
  /// In fr, this message translates to:
  /// **'Rue et numero'**
  String get addrStreet;

  /// No description provided for @addrOptional.
  ///
  /// In fr, this message translates to:
  /// **'facultatif'**
  String get addrOptional;

  /// No description provided for @addrRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ obligatoire'**
  String get addrRequired;

  /// No description provided for @addrSaveToBook.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans mes adresses'**
  String get addrSaveToBook;

  /// No description provided for @addrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'adresse'**
  String get addrLabel;

  /// No description provided for @addrLabelHint.
  ///
  /// In fr, this message translates to:
  /// **'Maison, Boutique'**
  String get addrLabelHint;

  /// No description provided for @addrBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes adresses'**
  String get addrBookTitle;

  /// No description provided for @addrBookEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse enregistree'**
  String get addrBookEmpty;

  /// No description provided for @addrBookEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Les adresses enregistrees ici se reutilisent en un geste.'**
  String get addrBookEmptyHelp;

  /// No description provided for @addrPickFromBook.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans mes adresses'**
  String get addrPickFromBook;

  /// No description provided for @addrNew.
  ///
  /// In fr, this message translates to:
  /// **'Saisir une nouvelle adresse'**
  String get addrNew;

  /// No description provided for @addrDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get addrDelete;

  /// No description provided for @pkgTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le colis'**
  String get pkgTitle;

  /// No description provided for @pkgWeight.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get pkgWeight;

  /// No description provided for @pkgWeightLt2.
  ///
  /// In fr, this message translates to:
  /// **'Moins de 2 kg'**
  String get pkgWeightLt2;

  /// No description provided for @pkgWeight2to5.
  ///
  /// In fr, this message translates to:
  /// **'2 a 5 kg'**
  String get pkgWeight2to5;

  /// No description provided for @pkgWeight5to15.
  ///
  /// In fr, this message translates to:
  /// **'5 a 15 kg'**
  String get pkgWeight5to15;

  /// No description provided for @pkgWeightGt15.
  ///
  /// In fr, this message translates to:
  /// **'Plus de 15 kg'**
  String get pkgWeightGt15;

  /// No description provided for @pkgValue.
  ///
  /// In fr, this message translates to:
  /// **'Valeur declaree'**
  String get pkgValue;

  /// No description provided for @pkgDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get pkgDescription;

  /// No description provided for @pkgDimensions.
  ///
  /// In fr, this message translates to:
  /// **'Dimensions (cm)'**
  String get pkgDimensions;

  /// No description provided for @pkgLength.
  ///
  /// In fr, this message translates to:
  /// **'Long.'**
  String get pkgLength;

  /// No description provided for @pkgWidth.
  ///
  /// In fr, this message translates to:
  /// **'Larg.'**
  String get pkgWidth;

  /// No description provided for @pkgHeight.
  ///
  /// In fr, this message translates to:
  /// **'Haut.'**
  String get pkgHeight;

  /// No description provided for @pkgAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo du colis'**
  String get pkgAddPhoto;

  /// No description provided for @pkgPhotoLater.
  ///
  /// In fr, this message translates to:
  /// **'La photo du colis sera demandee au module 5, avec la chaine photo.'**
  String get pkgPhotoLater;

  /// No description provided for @kindTitle.
  ///
  /// In fr, this message translates to:
  /// **'Type de course'**
  String get kindTitle;

  /// No description provided for @kindStandard.
  ///
  /// In fr, this message translates to:
  /// **'Colis standard'**
  String get kindStandard;

  /// No description provided for @kindDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get kindDocument;

  /// No description provided for @kindFragile.
  ///
  /// In fr, this message translates to:
  /// **'Fragile'**
  String get kindFragile;

  /// No description provided for @kindFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentaire'**
  String get kindFood;

  /// No description provided for @kindShopping.
  ///
  /// In fr, this message translates to:
  /// **'Achat pour compte'**
  String get kindShopping;

  /// No description provided for @kindShoppingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Disponible au module 9'**
  String get kindShoppingSoon;

  /// No description provided for @slotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quand ?'**
  String get slotTitle;

  /// No description provided for @slotImmediate.
  ///
  /// In fr, this message translates to:
  /// **'Immediat'**
  String get slotImmediate;

  /// No description provided for @slotScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programme'**
  String get slotScheduled;

  /// No description provided for @slotPickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date'**
  String get slotPickDate;

  /// No description provided for @slotRange.
  ///
  /// In fr, this message translates to:
  /// **'{start}h - {end}h'**
  String slotRange(int start, int end);

  /// No description provided for @paymentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get paymentTitle;

  /// No description provided for @paymentCash.
  ///
  /// In fr, this message translates to:
  /// **'Especes a la livraison'**
  String get paymentCash;

  /// No description provided for @paymentMajipay.
  ///
  /// In fr, this message translates to:
  /// **'MajiPay'**
  String get paymentMajipay;

  /// No description provided for @paymentMajipaySoon.
  ///
  /// In fr, this message translates to:
  /// **'Disponible au module 7'**
  String get paymentMajipaySoon;

  /// No description provided for @estimateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Estimation du prix'**
  String get estimateTitle;

  /// No description provided for @estimateTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get estimateTotal;

  /// No description provided for @estimateProvisional.
  ///
  /// In fr, this message translates to:
  /// **'Tarif provisoire : la grille definitive n\'est pas encore arretee.'**
  String get estimateProvisional;

  /// No description provided for @priceBase.
  ///
  /// In fr, this message translates to:
  /// **'Prise en charge'**
  String get priceBase;

  /// No description provided for @priceDistance.
  ///
  /// In fr, this message translates to:
  /// **'Distance'**
  String get priceDistance;

  /// No description provided for @priceWeight.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get priceWeight;

  /// No description provided for @priceKind.
  ///
  /// In fr, this message translates to:
  /// **'Majoration type de course'**
  String get priceKind;

  /// No description provided for @priceSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Creneau programme'**
  String get priceSchedule;

  /// No description provided for @priceInsurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get priceInsurance;

  /// No description provided for @confirmDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la course'**
  String get confirmDelivery;

  /// No description provided for @deliveryCreated.
  ///
  /// In fr, this message translates to:
  /// **'Course creee'**
  String get deliveryCreated;

  /// No description provided for @deliveryQueued.
  ///
  /// In fr, this message translates to:
  /// **'Course enregistree. Elle partira des le retour du reseau.'**
  String get deliveryQueued;

  /// No description provided for @deliveriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes courses'**
  String get deliveriesTitle;

  /// No description provided for @deliveryPendingSync.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get deliveryPendingSync;

  /// No description provided for @deliveryCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la course'**
  String get deliveryCancel;

  /// No description provided for @deliveryCancelConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette course ? Des frais peuvent s\'appliquer.'**
  String get deliveryCancelConfirm;

  /// No description provided for @deliveryDistance.
  ///
  /// In fr, this message translates to:
  /// **'{km} km'**
  String deliveryDistance(String km);

  /// No description provided for @histSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une course'**
  String get histSearchHint;

  /// No description provided for @histFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get histFilterAll;

  /// No description provided for @histFilterActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get histFilterActive;

  /// No description provided for @histFilterDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminees'**
  String get histFilterDone;

  /// No description provided for @histFilterCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulees'**
  String get histFilterCancelled;

  /// No description provided for @histPeriodAll.
  ///
  /// In fr, this message translates to:
  /// **'Toute periode'**
  String get histPeriodAll;

  /// No description provided for @histPeriod7.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get histPeriod7;

  /// No description provided for @histPeriod30.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get histPeriod30;

  /// No description provided for @histNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course ne correspond'**
  String get histNoMatch;

  /// No description provided for @histNoMatchHelp.
  ///
  /// In fr, this message translates to:
  /// **'Modifiez la recherche ou les filtres.'**
  String get histNoMatchHelp;

  /// No description provided for @histResultCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune course} =1{1 course} other{{count} courses}}'**
  String histResultCount(int count);

  /// No description provided for @custodyPickupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Constat de prise en charge'**
  String get custodyPickupTitle;

  /// No description provided for @custodyHandoverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Constat de remise'**
  String get custodyHandoverTitle;

  /// No description provided for @custodyStepPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get custodyStepPhotos;

  /// No description provided for @custodyStepCondition.
  ///
  /// In fr, this message translates to:
  /// **'Etat'**
  String get custodyStepCondition;

  /// No description provided for @custodyStepSeal.
  ///
  /// In fr, this message translates to:
  /// **'Scelle'**
  String get custodyStepSeal;

  /// No description provided for @custodyStepSignatures.
  ///
  /// In fr, this message translates to:
  /// **'Signatures'**
  String get custodyStepSignatures;

  /// No description provided for @custodyEngagement.
  ///
  /// In fr, this message translates to:
  /// **'Je certifie remettre ou prendre en charge ce colis dans l\'etat constate ci-dessus.'**
  String get custodyEngagement;

  /// No description provided for @custodySignHere.
  ///
  /// In fr, this message translates to:
  /// **'Signez ici'**
  String get custodySignHere;

  /// No description provided for @custodyClearSignature.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get custodyClearSignature;

  /// No description provided for @custodySignerSender.
  ///
  /// In fr, this message translates to:
  /// **'Expediteur'**
  String get custodySignerSender;

  /// No description provided for @custodySignerDriver.
  ///
  /// In fr, this message translates to:
  /// **'Livreur'**
  String get custodySignerDriver;

  /// No description provided for @custodySignerRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire'**
  String get custodySignerRecipient;

  /// No description provided for @custodyPhotoTop.
  ///
  /// In fr, this message translates to:
  /// **'Dessus'**
  String get custodyPhotoTop;

  /// No description provided for @custodyPhotoBottom.
  ///
  /// In fr, this message translates to:
  /// **'Dessous'**
  String get custodyPhotoBottom;

  /// No description provided for @custodyPhotoSide1.
  ///
  /// In fr, this message translates to:
  /// **'Cote 1'**
  String get custodyPhotoSide1;

  /// No description provided for @custodyPhotoSide2.
  ///
  /// In fr, this message translates to:
  /// **'Cote 2'**
  String get custodyPhotoSide2;

  /// No description provided for @custodyPhotoGuide.
  ///
  /// In fr, this message translates to:
  /// **'Cadrez le colis dans le gabarit, puis declenchez.'**
  String get custodyPhotoGuide;

  /// No description provided for @custodyPhotoInAppOnly.
  ///
  /// In fr, this message translates to:
  /// **'Photo prise dans l\'application uniquement.'**
  String get custodyPhotoInAppOnly;

  /// No description provided for @custodyPhotoRetake.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get custodyPhotoRetake;

  /// No description provided for @custodyConditionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Etat du colis'**
  String get custodyConditionTitle;

  /// No description provided for @custodyConditionHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cochez ce que vous constatez. Toute anomalie exige une photo et un commentaire.'**
  String get custodyConditionHelp;

  /// No description provided for @conditionPackagingIntact.
  ///
  /// In fr, this message translates to:
  /// **'Emballage intact'**
  String get conditionPackagingIntact;

  /// No description provided for @conditionImpactMark.
  ///
  /// In fr, this message translates to:
  /// **'Trace de choc'**
  String get conditionImpactMark;

  /// No description provided for @conditionMoistureMark.
  ///
  /// In fr, this message translates to:
  /// **'Trace d\'humidite'**
  String get conditionMoistureMark;

  /// No description provided for @conditionAlreadyOpened.
  ///
  /// In fr, this message translates to:
  /// **'Emballage deja ouvert'**
  String get conditionAlreadyOpened;

  /// No description provided for @conditionOriginalTape.
  ///
  /// In fr, this message translates to:
  /// **'Scotch d\'origine present'**
  String get conditionOriginalTape;

  /// No description provided for @conditionCrushedCorners.
  ///
  /// In fr, this message translates to:
  /// **'Angles ecrases'**
  String get conditionCrushedCorners;

  /// No description provided for @custodyAnomalyNote.
  ///
  /// In fr, this message translates to:
  /// **'Precisez l\'anomalie'**
  String get custodyAnomalyNote;

  /// No description provided for @custodySealNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numero de scelle'**
  String get custodySealNumber;

  /// No description provided for @custodySealHint.
  ///
  /// In fr, this message translates to:
  /// **'SC-4821'**
  String get custodySealHint;

  /// No description provided for @custodySealScan.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le scelle'**
  String get custodySealScan;

  /// No description provided for @custodySealScanHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cadrez le code-barres du scelle. Vous pourrez corriger le numero.'**
  String get custodySealScanHelp;

  /// No description provided for @custodySealCheck.
  ///
  /// In fr, this message translates to:
  /// **'Etat du scelle'**
  String get custodySealCheck;

  /// No description provided for @sealIntact.
  ///
  /// In fr, this message translates to:
  /// **'Intact'**
  String get sealIntact;

  /// No description provided for @sealBroken.
  ///
  /// In fr, this message translates to:
  /// **'Rompu'**
  String get sealBroken;

  /// No description provided for @sealAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get sealAbsent;

  /// No description provided for @custodySealIncident.
  ///
  /// In fr, this message translates to:
  /// **'Un incident sera ouvert automatiquement.'**
  String get custodySealIncident;

  /// No description provided for @custodyWeightConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Poids confirme'**
  String get custodyWeightConfirm;

  /// No description provided for @custodyOutcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Issue de la remise'**
  String get custodyOutcomeTitle;

  /// No description provided for @custodyOutcomeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Dites ce qui s\'est reellement passe. Chaque issue a ses obligations.'**
  String get custodyOutcomeHelp;

  /// No description provided for @outcomeDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Remis au destinataire'**
  String get outcomeDelivered;

  /// No description provided for @outcomeWithReserves.
  ///
  /// In fr, this message translates to:
  /// **'Remis sous reserves'**
  String get outcomeWithReserves;

  /// No description provided for @outcomeRefused.
  ///
  /// In fr, this message translates to:
  /// **'Refuse par le destinataire'**
  String get outcomeRefused;

  /// No description provided for @outcomeThirdParty.
  ///
  /// In fr, this message translates to:
  /// **'Remis a un tiers'**
  String get outcomeThirdParty;

  /// No description provided for @outcomeNoSignature.
  ///
  /// In fr, this message translates to:
  /// **'Remis sans signature'**
  String get outcomeNoSignature;

  /// No description provided for @custodyOutcomeReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif ecrit'**
  String get custodyOutcomeReason;

  /// No description provided for @custodyOutcomeReasonHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ce motif sera lu tel quel en cas de litige.'**
  String get custodyOutcomeReasonHelp;

  /// No description provided for @custodyReservesNotice.
  ///
  /// In fr, this message translates to:
  /// **'Un litige sera ouvert automatiquement.'**
  String get custodyReservesNotice;

  /// No description provided for @custodyRefusedNotice.
  ///
  /// In fr, this message translates to:
  /// **'Le colis repart en retour expediteur.'**
  String get custodyRefusedNotice;

  /// No description provided for @custodyNoSignatureNotice.
  ///
  /// In fr, this message translates to:
  /// **'L\'exploitation sera alertee. La photo du colis remis est obligatoire.'**
  String get custodyNoSignatureNotice;

  /// No description provided for @custodyThirdPartyName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du tiers'**
  String get custodyThirdPartyName;

  /// No description provided for @custodyThirdPartyRelation.
  ///
  /// In fr, this message translates to:
  /// **'Lien avec le destinataire'**
  String get custodyThirdPartyRelation;

  /// No description provided for @custodyThirdPartyRelationHint.
  ///
  /// In fr, this message translates to:
  /// **'Gardien, voisin, collegue...'**
  String get custodyThirdPartyRelationHint;

  /// No description provided for @custodyExtraPhotoSeal.
  ///
  /// In fr, this message translates to:
  /// **'Photo du scelle'**
  String get custodyExtraPhotoSeal;

  /// No description provided for @custodyExtraPhotoId.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la piece d\'identite'**
  String get custodyExtraPhotoId;

  /// No description provided for @custodyExtraPhotoHandover.
  ///
  /// In fr, this message translates to:
  /// **'Photo du colis remis'**
  String get custodyExtraPhotoHandover;

  /// No description provided for @custodyExtraPhotoMissing.
  ///
  /// In fr, this message translates to:
  /// **'Photo supplementaire requise'**
  String get custodyExtraPhotoMissing;

  /// No description provided for @custodyExportPdf.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF'**
  String get custodyExportPdf;

  /// No description provided for @custodyExportPdfDone.
  ///
  /// In fr, this message translates to:
  /// **'Constat exporte'**
  String get custodyExportPdfDone;

  /// No description provided for @custodyExportPdfFailed.
  ///
  /// In fr, this message translates to:
  /// **'Export impossible'**
  String get custodyExportPdfFailed;

  /// No description provided for @custodyPdfTitle.
  ///
  /// In fr, this message translates to:
  /// **'Constat contradictoire'**
  String get custodyPdfTitle;

  /// No description provided for @custodyPdfHash.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte SHA-256'**
  String get custodyPdfHash;

  /// No description provided for @custodyPdfPreviousHash.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte precedente'**
  String get custodyPdfPreviousHash;

  /// No description provided for @custodyPdfSealedAt.
  ///
  /// In fr, this message translates to:
  /// **'Scelle le'**
  String get custodyPdfSealedAt;

  /// No description provided for @custodyPdfServerTime.
  ///
  /// In fr, this message translates to:
  /// **'Recu par le serveur le'**
  String get custodyPdfServerTime;

  /// No description provided for @custodyPdfPending.
  ///
  /// In fr, this message translates to:
  /// **'Non transmis'**
  String get custodyPdfPending;

  /// No description provided for @custodyPdfNotice.
  ///
  /// In fr, this message translates to:
  /// **'Document genere par MajiChrono. Toute alteration rompt l\'empreinte.'**
  String get custodyPdfNotice;

  /// No description provided for @custodyOtpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code du destinataire'**
  String get custodyOtpTitle;

  /// No description provided for @custodyOtpHelp.
  ///
  /// In fr, this message translates to:
  /// **'Un code a ete envoye au destinataire par SMS.'**
  String get custodyOtpHelp;

  /// No description provided for @custodyIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Constat incomplet'**
  String get custodyIncomplete;

  /// No description provided for @custodyValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider le constat'**
  String get custodyValidate;

  /// No description provided for @custodySealed.
  ///
  /// In fr, this message translates to:
  /// **'Constat scelle'**
  String get custodySealed;

  /// No description provided for @custodySealedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Il ne peut plus etre modifie. Toute precision sera un ajout distinct.'**
  String get custodySealedHelp;

  /// No description provided for @custodyComparatorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comparateur'**
  String get custodyComparatorTitle;

  /// No description provided for @custodyBefore.
  ///
  /// In fr, this message translates to:
  /// **'Prise en charge'**
  String get custodyBefore;

  /// No description provided for @custodyAfter.
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get custodyAfter;

  /// No description provided for @custodyNoDiff.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ecart constate'**
  String get custodyNoDiff;

  /// No description provided for @custodyAppeared.
  ///
  /// In fr, this message translates to:
  /// **'Apparu a la remise'**
  String get custodyAppeared;

  /// No description provided for @custodyDisappeared.
  ///
  /// In fr, this message translates to:
  /// **'Disparu en cours de route'**
  String get custodyDisappeared;

  /// No description provided for @custodyChainIntact.
  ///
  /// In fr, this message translates to:
  /// **'Chaine de preuve intacte'**
  String get custodyChainIntact;

  /// No description provided for @custodyChainBroken.
  ///
  /// In fr, this message translates to:
  /// **'Chaine de preuve rompue'**
  String get custodyChainBroken;

  /// No description provided for @custodyChainHelp.
  ///
  /// In fr, this message translates to:
  /// **'L\'empreinte de la remise integre celle de la prise en charge.'**
  String get custodyChainHelp;

  /// No description provided for @emergencyButton.
  ///
  /// In fr, this message translates to:
  /// **'Urgence'**
  String get emergencyButton;

  /// No description provided for @emergencyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte d\'urgence'**
  String get emergencyTitle;

  /// No description provided for @emergencyHelp.
  ///
  /// In fr, this message translates to:
  /// **'L\'exploitation est prevenue immediatement, avec votre derniere position connue.'**
  String get emergencyHelp;

  /// No description provided for @emergencySend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l\'alerte'**
  String get emergencySend;

  /// No description provided for @emergencyKindOptional.
  ///
  /// In fr, this message translates to:
  /// **'Preciser (facultatif)'**
  String get emergencyKindOptional;

  /// No description provided for @emergencyAccident.
  ///
  /// In fr, this message translates to:
  /// **'Accident'**
  String get emergencyAccident;

  /// No description provided for @emergencyAggression.
  ///
  /// In fr, this message translates to:
  /// **'Agression'**
  String get emergencyAggression;

  /// No description provided for @emergencyBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Panne'**
  String get emergencyBreakdown;

  /// No description provided for @emergencyMedical.
  ///
  /// In fr, this message translates to:
  /// **'Malaise'**
  String get emergencyMedical;

  /// No description provided for @emergencyUnspecified.
  ///
  /// In fr, this message translates to:
  /// **'Non precise'**
  String get emergencyUnspecified;

  /// No description provided for @emergencySent.
  ///
  /// In fr, this message translates to:
  /// **'Alerte envoyee'**
  String get emergencySent;

  /// No description provided for @emergencyCallbackSoon.
  ///
  /// In fr, this message translates to:
  /// **'On vous rappelle tout de suite. Mettez-vous en securite.'**
  String get emergencyCallbackSoon;

  /// No description provided for @emergencyAcknowledgePending.
  ///
  /// In fr, this message translates to:
  /// **'L\'exploitation a ete prevenue. Restez joignable.'**
  String get emergencyAcknowledgePending;

  /// No description provided for @economyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode economie'**
  String get economyTitle;

  /// No description provided for @economyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Differe les photos jusqu\'a une connexion non facturee et n\'ouvre plus de nouvelles tuiles de carte.'**
  String get economyHelp;

  /// No description provided for @economyProofNever.
  ///
  /// In fr, this message translates to:
  /// **'Les constats partent toujours en entier, meme en mode economie.'**
  String get economyProofNever;

  /// No description provided for @economyDeferPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Differer les photos hors constat'**
  String get economyDeferPhotos;

  /// No description provided for @economyBlockTiles.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas telecharger de nouvelles tuiles'**
  String get economyBlockTiles;

  /// No description provided for @economyReduceCadence.
  ///
  /// In fr, this message translates to:
  /// **'Espacer l\'envoi des positions'**
  String get economyReduceCadence;

  /// No description provided for @shoppingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Achat pour compte'**
  String get shoppingTitle;

  /// No description provided for @shoppingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur avance l\'argent et vous remet le ticket de caisse.'**
  String get shoppingHelp;

  /// No description provided for @shoppingAddItem.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get shoppingAddItem;

  /// No description provided for @shoppingItemLabel.
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get shoppingItemLabel;

  /// No description provided for @shoppingItemQuantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantite'**
  String get shoppingItemQuantity;

  /// No description provided for @shoppingItemPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix unitaire estime'**
  String get shoppingItemPrice;

  /// No description provided for @shoppingSubstitutable.
  ///
  /// In fr, this message translates to:
  /// **'Remplacable si indisponible'**
  String get shoppingSubstitutable;

  /// No description provided for @shoppingStoreHint.
  ///
  /// In fr, this message translates to:
  /// **'Magasin suggere (facultatif)'**
  String get shoppingStoreHint;

  /// No description provided for @shoppingCap.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de depense'**
  String get shoppingCap;

  /// No description provided for @shoppingCapHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur n\'achete pas au-dela. C\'est sa seule protection : il avance son propre argent.'**
  String get shoppingCapHelp;

  /// No description provided for @shoppingCapTooLow.
  ///
  /// In fr, this message translates to:
  /// **'Le plafond est inferieur a votre estimation'**
  String get shoppingCapTooLow;

  /// No description provided for @shoppingCapOutOfRange.
  ///
  /// In fr, this message translates to:
  /// **'Plafond entre {min} et {max}'**
  String shoppingCapOutOfRange(String min, String max);

  /// No description provided for @shoppingEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Estimation des articles'**
  String get shoppingEstimated;

  /// No description provided for @shoppingEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article'**
  String get shoppingEmpty;

  /// No description provided for @shoppingActualTotal.
  ///
  /// In fr, this message translates to:
  /// **'Montant paye (ticket)'**
  String get shoppingActualTotal;

  /// No description provided for @shoppingReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Ticket de caisse'**
  String get shoppingReceipt;

  /// No description provided for @shoppingReceiptMissing.
  ///
  /// In fr, this message translates to:
  /// **'Photo obligatoire pour le remboursement'**
  String get shoppingReceiptMissing;

  /// No description provided for @shoppingReceiptTaken.
  ///
  /// In fr, this message translates to:
  /// **'Ticket photographie'**
  String get shoppingReceiptTaken;

  /// No description provided for @shoppingOverCap.
  ///
  /// In fr, this message translates to:
  /// **'Au-dela du plafond. Remboursement : {amount}'**
  String shoppingOverCap(String amount);

  /// No description provided for @payerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui paie'**
  String get payerTitle;

  /// No description provided for @payerSender.
  ///
  /// In fr, this message translates to:
  /// **'Moi (port paye)'**
  String get payerSender;

  /// No description provided for @payerRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire (port du)'**
  String get payerRecipient;

  /// No description provided for @payerRecipientNotice.
  ///
  /// In fr, this message translates to:
  /// **'Prevenez votre destinataire du montant : sans cela il refusera le colis.'**
  String get payerRecipientNotice;

  /// No description provided for @relayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Point relais'**
  String get relayTitle;

  /// No description provided for @relayHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le colis attend en boutique. Utile si votre destinataire n\'est pas chez lui en journee.'**
  String get relayHelp;

  /// No description provided for @relayNone.
  ///
  /// In fr, this message translates to:
  /// **'Livraison a l\'adresse'**
  String get relayNone;

  /// No description provided for @relayHours.
  ///
  /// In fr, this message translates to:
  /// **'Horaires'**
  String get relayHours;

  /// No description provided for @relayStorage.
  ///
  /// In fr, this message translates to:
  /// **'Garde {days} jours'**
  String relayStorage(int days);

  /// No description provided for @relayTooHeavy.
  ///
  /// In fr, this message translates to:
  /// **'Colis trop lourd pour ce relais'**
  String get relayTooHeavy;

  /// No description provided for @relayDistance.
  ///
  /// In fr, this message translates to:
  /// **'a {km} km'**
  String relayDistance(String km);

  /// No description provided for @relayPickupCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de retrait'**
  String get relayPickupCodeTitle;

  /// No description provided for @relayPickupCodeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le destinataire presente ce code au relais pour recuperer le colis.'**
  String get relayPickupCodeHelp;

  /// No description provided for @commonCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get commonCopy;

  /// No description provided for @groupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Courses groupees'**
  String get groupTitle;

  /// No description provided for @groupHelp.
  ///
  /// In fr, this message translates to:
  /// **'Deux a trois courses sur le meme axe. Les retraits d\'abord, les remises ensuite.'**
  String get groupHelp;

  /// No description provided for @groupSaved.
  ///
  /// In fr, this message translates to:
  /// **'{km} km economises'**
  String groupSaved(String km);

  /// No description provided for @groupAdd.
  ///
  /// In fr, this message translates to:
  /// **'Grouper avec celle-ci'**
  String get groupAdd;

  /// No description provided for @groupNotViable.
  ///
  /// In fr, this message translates to:
  /// **'Cette course fait trop devier votre trajet'**
  String get groupNotViable;

  /// No description provided for @groupStopPickup.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get groupStopPickup;

  /// No description provided for @groupStopDropoff.
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get groupStopDropoff;

  /// No description provided for @adminReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif de la decision'**
  String get adminReasonLabel;

  /// No description provided for @adminReasonMissing.
  ///
  /// In fr, this message translates to:
  /// **'Encore {count} caracteres. Un motif sert a expliquer, pas a remplir un champ.'**
  String adminReasonMissing(int count);

  /// No description provided for @adminReasonOk.
  ///
  /// In fr, this message translates to:
  /// **'Ce motif sera relu tel quel en cas de contestation.'**
  String get adminReasonOk;

  /// No description provided for @adminReasonRecorded.
  ///
  /// In fr, this message translates to:
  /// **'La decision est enregistree avec son motif et son auteur.'**
  String get adminReasonRecorded;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get adminDashboardTitle;

  /// No description provided for @adminActiveDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'Courses en cours'**
  String get adminActiveDeliveries;

  /// No description provided for @adminOnlineDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Livreurs en ligne'**
  String get adminOnlineDrivers;

  /// No description provided for @adminTotalClients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get adminTotalClients;

  /// No description provided for @adminTotalDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Livreurs'**
  String get adminTotalDrivers;

  /// No description provided for @adminStatsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques & rapports'**
  String get adminStatsTitle;

  /// No description provided for @adminStatsManage.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques & rapports'**
  String get adminStatsManage;

  /// No description provided for @statTotalDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'Livraisons'**
  String get statTotalDeliveries;

  /// No description provided for @statSuccessRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de reussite'**
  String get statSuccessRate;

  /// No description provided for @statCancellationRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'annulation'**
  String get statCancellationRate;

  /// No description provided for @statRevenue.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre d\'affaires'**
  String get statRevenue;

  /// No description provided for @statDriverEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Revenus livreurs'**
  String get statDriverEarnings;

  /// No description provided for @statAvgTime.
  ///
  /// In fr, this message translates to:
  /// **'Temps moyen'**
  String get statAvgTime;

  /// No description provided for @statMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{min} min'**
  String statMinutes(int min);

  /// No description provided for @statIncidents.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get statIncidents;

  /// No description provided for @statDisputes.
  ///
  /// In fr, this message translates to:
  /// **'Litiges'**
  String get statDisputes;

  /// No description provided for @statVolumes.
  ///
  /// In fr, this message translates to:
  /// **'Volumes'**
  String get statVolumes;

  /// No description provided for @statRates.
  ///
  /// In fr, this message translates to:
  /// **'Taux & qualite'**
  String get statRates;

  /// No description provided for @statTopZones.
  ///
  /// In fr, this message translates to:
  /// **'Zones les plus actives'**
  String get statTopZones;

  /// No description provided for @statPeakHours.
  ///
  /// In fr, this message translates to:
  /// **'Heures de pointe'**
  String get statPeakHours;

  /// No description provided for @statDriverPerformance.
  ///
  /// In fr, this message translates to:
  /// **'Performance des livreurs'**
  String get statDriverPerformance;

  /// No description provided for @statNoData.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de donnees'**
  String get statNoData;

  /// No description provided for @statDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'{count} courses'**
  String statDeliveries(int count);

  /// No description provided for @adminUsersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get adminUsersTitle;

  /// No description provided for @adminUsersManage.
  ///
  /// In fr, this message translates to:
  /// **'Gerer les utilisateurs'**
  String get adminUsersManage;

  /// No description provided for @adminUsersSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un nom ou un numero'**
  String get adminUsersSearch;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur'**
  String get adminUsersEmpty;

  /// No description provided for @adminUsersTabClients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get adminUsersTabClients;

  /// No description provided for @adminUsersTabDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Livreurs'**
  String get adminUsersTabDrivers;

  /// No description provided for @adminUserSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get adminUserSuspended;

  /// No description provided for @adminUserActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get adminUserActive;

  /// No description provided for @adminOpenIncidents.
  ///
  /// In fr, this message translates to:
  /// **'Incidents ouverts'**
  String get adminOpenIncidents;

  /// No description provided for @adminOpenDisputes.
  ///
  /// In fr, this message translates to:
  /// **'Litiges ouverts'**
  String get adminOpenDisputes;

  /// No description provided for @adminPendingKyc.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers a valider'**
  String get adminPendingKyc;

  /// No description provided for @adminRevenueToday.
  ///
  /// In fr, this message translates to:
  /// **'Encaisse aujourd\'hui'**
  String get adminRevenueToday;

  /// No description provided for @adminByStatus.
  ///
  /// In fr, this message translates to:
  /// **'Repartition des courses'**
  String get adminByStatus;

  /// No description provided for @adminFleetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Flotte'**
  String get adminFleetTitle;

  /// No description provided for @adminFleetAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get adminFleetAll;

  /// No description provided for @adminFleetAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get adminFleetAvailable;

  /// No description provided for @adminFleetBusy.
  ///
  /// In fr, this message translates to:
  /// **'En course'**
  String get adminFleetBusy;

  /// No description provided for @adminFleetOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get adminFleetOffline;

  /// No description provided for @adminFleetSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get adminFleetSuspended;

  /// No description provided for @adminFleetEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livreur dans ce filtre'**
  String get adminFleetEmpty;

  /// No description provided for @adminFleetStale.
  ///
  /// In fr, this message translates to:
  /// **'Position ancienne'**
  String get adminFleetStale;

  /// No description provided for @adminFleetMapUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Carte indisponible hors ligne'**
  String get adminFleetMapUnavailable;

  /// No description provided for @adminSuspend.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre le compte'**
  String get adminSuspend;

  /// No description provided for @adminReinstate.
  ///
  /// In fr, this message translates to:
  /// **'Reintegrer le compte'**
  String get adminReinstate;

  /// No description provided for @adminSuspendHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur ne recevra plus de courses tant que la suspension dure.'**
  String get adminSuspendHelp;

  /// No description provided for @adminReinstateHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur pourra de nouveau se mettre en ligne.'**
  String get adminReinstateHelp;

  /// No description provided for @adminSuspendedSince.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu : {reason}'**
  String adminSuspendedSince(String reason);

  /// No description provided for @adminKycTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers a valider'**
  String get adminKycTitle;

  /// No description provided for @adminKycEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier en attente'**
  String get adminKycEmpty;

  /// No description provided for @adminKycIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Dossier incomplet'**
  String get adminKycIncomplete;

  /// No description provided for @adminKycComplete.
  ///
  /// In fr, this message translates to:
  /// **'Dossier complet'**
  String get adminKycComplete;

  /// No description provided for @adminKycMissingDocs.
  ///
  /// In fr, this message translates to:
  /// **'{count} piece(s) manquante(s)'**
  String adminKycMissingDocs(int count);

  /// No description provided for @adminKycApprove.
  ///
  /// In fr, this message translates to:
  /// **'Valider le dossier'**
  String get adminKycApprove;

  /// No description provided for @adminKycReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser le dossier'**
  String get adminKycReject;

  /// No description provided for @adminKycThreadButton.
  ///
  /// In fr, this message translates to:
  /// **'Messages du livreur'**
  String get adminKycThreadButton;

  /// No description provided for @adminKycThreadTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi du dossier'**
  String get adminKycThreadTitle;

  /// No description provided for @adminKycReplyHint.
  ///
  /// In fr, this message translates to:
  /// **'Repondre au livreur'**
  String get adminKycReplyHint;

  /// No description provided for @adminKycThreadEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message du livreur'**
  String get adminKycThreadEmpty;

  /// No description provided for @adminKycApproveHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur entrera dans la flotte, hors service jusqu\'a ce qu\'il se mette en ligne.'**
  String get adminKycApproveHelp;

  /// No description provided for @adminKycRejectHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le motif sera transmis au livreur pour qu\'il puisse corriger son dossier.'**
  String get adminKycRejectHelp;

  /// No description provided for @adminKycSubmittedAt.
  ///
  /// In fr, this message translates to:
  /// **'Depose {age}'**
  String adminKycSubmittedAt(String age);

  /// No description provided for @adminDeliveriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Courses'**
  String get adminDeliveriesTitle;

  /// No description provided for @adminDeliveriesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course ne correspond'**
  String get adminDeliveriesEmpty;

  /// No description provided for @adminFilterStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get adminFilterStatus;

  /// No description provided for @adminFilterSearch.
  ///
  /// In fr, this message translates to:
  /// **'Quartier, repere, livreur...'**
  String get adminFilterSearch;

  /// No description provided for @adminFilterClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get adminFilterClear;

  /// No description provided for @adminReassign.
  ///
  /// In fr, this message translates to:
  /// **'Reaffecter'**
  String get adminReassign;

  /// No description provided for @adminReassignTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reaffecter la course'**
  String get adminReassignTitle;

  /// No description provided for @adminReassignHelp.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les livreurs disponibles peuvent recevoir une course.'**
  String get adminReassignHelp;

  /// No description provided for @adminReassignPick.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un livreur'**
  String get adminReassignPick;

  /// No description provided for @adminReassignNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livreur disponible'**
  String get adminReassignNone;

  /// No description provided for @adminDisputesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Litiges'**
  String get adminDisputesTitle;

  /// No description provided for @adminDisputesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun litige ouvert'**
  String get adminDisputesEmpty;

  /// No description provided for @adminDisputeOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get adminDisputeOpen;

  /// No description provided for @adminDisputeInvestigating.
  ///
  /// In fr, this message translates to:
  /// **'En instruction'**
  String get adminDisputeInvestigating;

  /// No description provided for @adminDisputeResolved.
  ///
  /// In fr, this message translates to:
  /// **'Tranche en faveur du client'**
  String get adminDisputeResolved;

  /// No description provided for @adminDisputeRejected.
  ///
  /// In fr, this message translates to:
  /// **'Litige ecarte'**
  String get adminDisputeRejected;

  /// No description provided for @adminDisputeReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif d\'ouverture'**
  String get adminDisputeReason;

  /// No description provided for @adminDisputeReply.
  ///
  /// In fr, this message translates to:
  /// **'Repondre'**
  String get adminDisputeReply;

  /// No description provided for @adminDisputeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre message'**
  String get adminDisputeMessage;

  /// No description provided for @adminDisputeResolve.
  ///
  /// In fr, this message translates to:
  /// **'Trancher en faveur du client'**
  String get adminDisputeResolve;

  /// No description provided for @adminDisputeDismiss.
  ///
  /// In fr, this message translates to:
  /// **'Ecarter le litige'**
  String get adminDisputeDismiss;

  /// No description provided for @adminDisputeResolveHelp.
  ///
  /// In fr, this message translates to:
  /// **'La course sera reglee au benefice du client.'**
  String get adminDisputeResolveHelp;

  /// No description provided for @adminDisputeDismissHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le litige sera clos sans suite.'**
  String get adminDisputeDismissHelp;

  /// No description provided for @adminDisputeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Litige clos. Aucune reponse n\'est plus possible.'**
  String get adminDisputeClosed;

  /// No description provided for @adminDisputeDecidedBy.
  ///
  /// In fr, this message translates to:
  /// **'Decide par {author}'**
  String adminDisputeDecidedBy(String author);

  /// No description provided for @adminOpenComparator.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le comparateur'**
  String get adminOpenComparator;

  /// No description provided for @adminActionDone.
  ///
  /// In fr, this message translates to:
  /// **'Decision enregistree'**
  String get adminActionDone;

  /// No description provided for @payTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get payTitle;

  /// No description provided for @payBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde MajiPay'**
  String get payBalance;

  /// No description provided for @payBalanceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Solde indisponible'**
  String get payBalanceUnavailable;

  /// No description provided for @payAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant a regler'**
  String get payAmount;

  /// No description provided for @payCollect.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser'**
  String get payCollect;

  /// No description provided for @payCollectHelp.
  ///
  /// In fr, this message translates to:
  /// **'Presentez ce code au client. Il confirmera sur son telephone.'**
  String get payCollectHelp;

  /// No description provided for @payOffer.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get payOffer;

  /// No description provided for @payOfferHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur scanne ce code. Vous avez deja confirme le montant.'**
  String get payOfferHelp;

  /// No description provided for @payScan.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code'**
  String get payScan;

  /// No description provided for @payScanHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cadrez le code affiche sur l\'autre telephone.'**
  String get payScanHelp;

  /// No description provided for @payScanInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ce code n\'est pas un code de paiement MajiChrono'**
  String get payScanInvalid;

  /// No description provided for @payScanPermission.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez l\'appareil photo pour scanner'**
  String get payScanPermission;

  /// No description provided for @payShowQr.
  ///
  /// In fr, this message translates to:
  /// **'Afficher mon code'**
  String get payShowQr;

  /// No description provided for @payQrExpires.
  ///
  /// In fr, this message translates to:
  /// **'Code valable {minutes} min'**
  String payQrExpires(int minutes);

  /// No description provided for @payQrExpired.
  ///
  /// In fr, this message translates to:
  /// **'Code expire'**
  String get payQrExpired;

  /// No description provided for @payQrRenew.
  ///
  /// In fr, this message translates to:
  /// **'Generer un nouveau code'**
  String get payQrRenew;

  /// No description provided for @payWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente du scan...'**
  String get payWaiting;

  /// No description provided for @payConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le paiement'**
  String get payConfirmTitle;

  /// No description provided for @payConfirmTo.
  ///
  /// In fr, this message translates to:
  /// **'Beneficiaire'**
  String get payConfirmTo;

  /// No description provided for @payConfirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre code pour confirmer'**
  String get payConfirmPin;

  /// No description provided for @payConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer {amount}'**
  String payConfirmAction(String amount);

  /// No description provided for @payConfirmNever.
  ///
  /// In fr, this message translates to:
  /// **'Scanner ne suffit pas : personne ne peut debiter votre compte sans ce code.'**
  String get payConfirmNever;

  /// No description provided for @payWrongPin.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get payWrongPin;

  /// No description provided for @payCaptured.
  ///
  /// In fr, this message translates to:
  /// **'Paiement effectue'**
  String get payCaptured;

  /// No description provided for @payReceived.
  ///
  /// In fr, this message translates to:
  /// **'Paiement recu'**
  String get payReceived;

  /// No description provided for @payFailedInsufficient.
  ///
  /// In fr, this message translates to:
  /// **'Solde MajiPay insuffisant'**
  String get payFailedInsufficient;

  /// No description provided for @payFailedExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le code a expire'**
  String get payFailedExpired;

  /// No description provided for @payFailedDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Paiement refuse'**
  String get payFailedDeclined;

  /// No description provided for @payFailedUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'MajiPay est indisponible'**
  String get payFailedUnavailable;

  /// No description provided for @payCashFallback.
  ///
  /// In fr, this message translates to:
  /// **'Regler en especes'**
  String get payCashFallback;

  /// No description provided for @payCashHelp.
  ///
  /// In fr, this message translates to:
  /// **'La course n\'est jamais bloquee par un probleme de paiement.'**
  String get payCashHelp;

  /// No description provided for @payCashDone.
  ///
  /// In fr, this message translates to:
  /// **'Regle en especes'**
  String get payCashDone;

  /// No description provided for @payReceiptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recu'**
  String get payReceiptTitle;

  /// No description provided for @payReceiptRef.
  ///
  /// In fr, this message translates to:
  /// **'Reference'**
  String get payReceiptRef;

  /// No description provided for @payReceiptShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager le recu'**
  String get payReceiptShare;

  /// No description provided for @payMethodMajipay.
  ///
  /// In fr, this message translates to:
  /// **'MajiPay'**
  String get payMethodMajipay;

  /// No description provided for @payMethodCash.
  ///
  /// In fr, this message translates to:
  /// **'Especes'**
  String get payMethodCash;

  /// No description provided for @walletTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon portefeuille'**
  String get walletTitle;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Solde disponible'**
  String get walletBalanceLabel;

  /// No description provided for @walletHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des paiements'**
  String get walletHistoryTitle;

  /// No description provided for @walletHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement pour le moment'**
  String get walletHistoryEmpty;

  /// No description provided for @walletHistoryEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vos reglages MajiPay apparaitront ici.'**
  String get walletHistoryEmptyHelp;

  /// No description provided for @walletOutgoing.
  ///
  /// In fr, this message translates to:
  /// **'Paiement envoye'**
  String get walletOutgoing;

  /// No description provided for @walletIncoming.
  ///
  /// In fr, this message translates to:
  /// **'Paiement recu'**
  String get walletIncoming;

  /// No description provided for @walletStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get walletStatusPending;

  /// No description provided for @walletStatusCaptured.
  ///
  /// In fr, this message translates to:
  /// **'Regle'**
  String get walletStatusCaptured;

  /// No description provided for @walletStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Echoue'**
  String get walletStatusFailed;

  /// No description provided for @walletStatusCash.
  ///
  /// In fr, this message translates to:
  /// **'Regle en especes'**
  String get walletStatusCash;

  /// No description provided for @walletRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get walletRefund;

  /// No description provided for @walletRefundNote.
  ///
  /// In fr, this message translates to:
  /// **'En cas de course annulee apres paiement, le remboursement est traite par MajiPay sous 72 h. Contactez l\'assistance si besoin.'**
  String get walletRefundNote;

  /// No description provided for @walletViewReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Voir le recu'**
  String get walletViewReceipt;

  /// No description provided for @syncPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Elements en attente'**
  String get syncPendingTitle;

  /// No description provided for @syncPendingEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Tout est transmis'**
  String get syncPendingEmpty;

  /// No description provided for @syncPendingEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'attend d\'etre envoye au serveur.'**
  String get syncPendingEmptyHelp;

  /// No description provided for @syncPendingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ces elements partiront des le retour du reseau. Les constats passent en premier.'**
  String get syncPendingHelp;

  /// No description provided for @syncRetry.
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get syncRetry;

  /// No description provided for @syncRetryAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout relancer'**
  String get syncRetryAll;

  /// No description provided for @syncItemCustody.
  ///
  /// In fr, this message translates to:
  /// **'Constat'**
  String get syncItemCustody;

  /// No description provided for @syncItemTransition.
  ///
  /// In fr, this message translates to:
  /// **'Course'**
  String get syncItemTransition;

  /// No description provided for @syncItemPosition.
  ///
  /// In fr, this message translates to:
  /// **'Positions'**
  String get syncItemPosition;

  /// No description provided for @syncItemRating.
  ///
  /// In fr, this message translates to:
  /// **'Notation'**
  String get syncItemRating;

  /// No description provided for @syncCauseNone.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'une fenetre reseau'**
  String get syncCauseNone;

  /// No description provided for @syncCauseNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Reseau indisponible'**
  String get syncCauseNetwork;

  /// No description provided for @syncCauseServer.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas repondu'**
  String get syncCauseServer;

  /// No description provided for @syncCauseConflict.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a un autre etat'**
  String get syncCauseConflict;

  /// No description provided for @syncCauseRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refuse par le serveur'**
  String get syncCauseRejected;

  /// No description provided for @syncCauseExhausted.
  ///
  /// In fr, this message translates to:
  /// **'Tentatives epuisees'**
  String get syncCauseExhausted;

  /// No description provided for @syncNeverAbandon.
  ///
  /// In fr, this message translates to:
  /// **'Preuve : jamais abandonnee'**
  String get syncNeverAbandon;

  /// No description provided for @syncAttempts.
  ///
  /// In fr, this message translates to:
  /// **'{count} tentatives'**
  String syncAttempts(int count);

  /// No description provided for @syncAgeNow.
  ///
  /// In fr, this message translates to:
  /// **'a l\'instant'**
  String get syncAgeNow;

  /// No description provided for @syncAgeMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String syncAgeMinutes(int count);

  /// No description provided for @syncAgeHours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} h'**
  String syncAgeHours(int count);

  /// No description provided for @syncAgeDays.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} j'**
  String syncAgeDays(int count);

  /// No description provided for @syncConflictNotice.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a impose son etat. Vos donnees ont ete mises a jour.'**
  String get syncConflictNotice;

  /// No description provided for @syncRetryQueued.
  ///
  /// In fr, this message translates to:
  /// **'Relance demandee'**
  String get syncRetryQueued;

  /// No description provided for @traitFragile.
  ///
  /// In fr, this message translates to:
  /// **'Fragile'**
  String get traitFragile;

  /// No description provided for @traitHeavy.
  ///
  /// In fr, this message translates to:
  /// **'Lourd'**
  String get traitHeavy;

  /// No description provided for @traitValuable.
  ///
  /// In fr, this message translates to:
  /// **'Precieux'**
  String get traitValuable;

  /// No description provided for @traitFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentaire'**
  String get traitFood;

  /// No description provided for @traitDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get traitDocument;

  /// No description provided for @traitShopping.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get traitShopping;

  /// No description provided for @driverOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get driverOnline;

  /// No description provided for @driverOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get driverOffline;

  /// No description provided for @driverOnlineHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vous recevez des courses tant que vous etes en ligne.'**
  String get driverOnlineHelp;

  /// No description provided for @driverOfflineHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course ne vous sera proposee.'**
  String get driverOfflineHelp;

  /// No description provided for @driverAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Courses disponibles'**
  String get driverAvailable;

  /// No description provided for @driverNoOffers.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course pour l\'instant'**
  String get driverNoOffers;

  /// No description provided for @driverNoOffersHelp.
  ///
  /// In fr, this message translates to:
  /// **'Restez en ligne : les courses arrivent au fil de la journee.'**
  String get driverNoOffersHelp;

  /// No description provided for @driverOfflineEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Passez en ligne pour recevoir des courses'**
  String get driverOfflineEmpty;

  /// No description provided for @driverPickupDistance.
  ///
  /// In fr, this message translates to:
  /// **'{km} km a vide'**
  String driverPickupDistance(String km);

  /// No description provided for @driverEarning.
  ///
  /// In fr, this message translates to:
  /// **'Gain estime'**
  String get driverEarning;

  /// No description provided for @driverAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get driverAccept;

  /// No description provided for @driverAcceptIn.
  ///
  /// In fr, this message translates to:
  /// **'Accepter ({seconds} s)'**
  String driverAcceptIn(int seconds);

  /// No description provided for @dashAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponibles'**
  String get dashAvailable;

  /// No description provided for @dashActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get dashActive;

  /// No description provided for @dashDoneToday.
  ///
  /// In fr, this message translates to:
  /// **'Terminees'**
  String get dashDoneToday;

  /// No description provided for @dashBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get dashBalance;

  /// No description provided for @driverRefuse.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get driverRefuse;

  /// No description provided for @driverDetails.
  ///
  /// In fr, this message translates to:
  /// **'Details de la course'**
  String get driverDetails;

  /// No description provided for @driverEta.
  ///
  /// In fr, this message translates to:
  /// **'~{min} min'**
  String driverEta(int min);

  /// No description provided for @driverEtaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Temps estime'**
  String get driverEtaLabel;

  /// No description provided for @driverPackageType.
  ///
  /// In fr, this message translates to:
  /// **'Type de colis'**
  String get driverPackageType;

  /// No description provided for @driverAlreadyTaken.
  ///
  /// In fr, this message translates to:
  /// **'Course deja prise par un autre livreur'**
  String get driverAlreadyTaken;

  /// No description provided for @driverActiveDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Course en cours'**
  String get driverActiveDelivery;

  /// No description provided for @driverNavigate.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir l\'itineraire'**
  String get driverNavigate;

  /// No description provided for @driverCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler le contact'**
  String get driverCall;

  /// No description provided for @driverStepArrivedPickup.
  ///
  /// In fr, this message translates to:
  /// **'Je suis au depart'**
  String get driverStepArrivedPickup;

  /// No description provided for @driverStepPickedUp.
  ///
  /// In fr, this message translates to:
  /// **'Colis pris en charge'**
  String get driverStepPickedUp;

  /// No description provided for @driverStepArrivedDestination.
  ///
  /// In fr, this message translates to:
  /// **'Je suis a destination'**
  String get driverStepArrivedDestination;

  /// No description provided for @driverStepDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Colis remis'**
  String get driverStepDelivered;

  /// No description provided for @driverCustodyRequired.
  ///
  /// In fr, this message translates to:
  /// **'Un constat sera demande a cette etape (module 5).'**
  String get driverCustodyRequired;

  /// No description provided for @driverIncident.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incident'**
  String get driverIncident;

  /// No description provided for @incidentSenderAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Expediteur absent'**
  String get incidentSenderAbsent;

  /// No description provided for @incidentRecipientAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire absent'**
  String get incidentRecipientAbsent;

  /// No description provided for @incidentAddressIncorrect.
  ///
  /// In fr, this message translates to:
  /// **'Adresse incorrecte'**
  String get incidentAddressIncorrect;

  /// No description provided for @incidentPackageDamaged.
  ///
  /// In fr, this message translates to:
  /// **'Colis endommage'**
  String get incidentPackageDamaged;

  /// No description provided for @incidentPackageRefused.
  ///
  /// In fr, this message translates to:
  /// **'Colis refuse'**
  String get incidentPackageRefused;

  /// No description provided for @incidentAccident.
  ///
  /// In fr, this message translates to:
  /// **'Accident'**
  String get incidentAccident;

  /// No description provided for @incidentGpsProblem.
  ///
  /// In fr, this message translates to:
  /// **'Probleme GPS'**
  String get incidentGpsProblem;

  /// No description provided for @incidentVehicleProblem.
  ///
  /// In fr, this message translates to:
  /// **'Probleme de vehicule'**
  String get incidentVehicleProblem;

  /// No description provided for @incidentPaymentProblem.
  ///
  /// In fr, this message translates to:
  /// **'Probleme de paiement'**
  String get incidentPaymentProblem;

  /// No description provided for @incidentOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre incident'**
  String get incidentOther;

  /// No description provided for @outcomeWaitThenReturn.
  ///
  /// In fr, this message translates to:
  /// **'Attendre 10 minutes, puis retour expediteur'**
  String get outcomeWaitThenReturn;

  /// No description provided for @outcomeContactSupport.
  ///
  /// In fr, this message translates to:
  /// **'L\'exploitation vous rappelle'**
  String get outcomeContactSupport;

  /// No description provided for @outcomeReturnToSender.
  ///
  /// In fr, this message translates to:
  /// **'Colis renvoye a l\'expediteur'**
  String get outcomeReturnToSender;

  /// No description provided for @outcomeReassign.
  ///
  /// In fr, this message translates to:
  /// **'La course sera reaffectee'**
  String get outcomeReassign;

  /// No description provided for @outcomeDocumentThenContinue.
  ///
  /// In fr, this message translates to:
  /// **'Documentez, la course continue'**
  String get outcomeDocumentThenContinue;

  /// No description provided for @incidentDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Detail de l\'incident'**
  String get incidentDetailTitle;

  /// No description provided for @incidentDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get incidentDescriptionLabel;

  /// No description provided for @incidentDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous avez constate'**
  String get incidentDescriptionHint;

  /// No description provided for @incidentAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get incidentAddPhoto;

  /// No description provided for @incidentPhotoAdded.
  ///
  /// In fr, this message translates to:
  /// **'Photo ajoutee'**
  String get incidentPhotoAdded;

  /// No description provided for @incidentGpsAttached.
  ///
  /// In fr, this message translates to:
  /// **'Position jointe'**
  String get incidentGpsAttached;

  /// No description provided for @incidentSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get incidentSubmit;

  /// No description provided for @incidentReported.
  ///
  /// In fr, this message translates to:
  /// **'Incident signale'**
  String get incidentReported;

  /// No description provided for @incidentHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents signales'**
  String get incidentHistoryTitle;

  /// No description provided for @incidentResolutionOpen.
  ///
  /// In fr, this message translates to:
  /// **'En cours de traitement'**
  String get incidentResolutionOpen;

  /// No description provided for @incidentResolutionResolved.
  ///
  /// In fr, this message translates to:
  /// **'Traite'**
  String get incidentResolutionResolved;

  /// No description provided for @earningsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes gains'**
  String get earningsTitle;

  /// No description provided for @earningsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get earningsToday;

  /// No description provided for @earningsWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get earningsWeek;

  /// No description provided for @earningsMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get earningsMonth;

  /// No description provided for @earningsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} course(s)'**
  String earningsCount(int count);

  /// No description provided for @earningsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun gain enregistre'**
  String get earningsEmpty;

  /// No description provided for @earningsCommission.
  ///
  /// In fr, this message translates to:
  /// **'Montants nets, commission deduite.'**
  String get earningsCommission;

  /// No description provided for @withdrawTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get withdrawTitle;

  /// No description provided for @withdrawAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Solde MajiPay disponible'**
  String get withdrawAvailable;

  /// No description provided for @withdrawAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get withdrawAction;

  /// No description provided for @withdrawAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant a retirer (Ar)'**
  String get withdrawAmountLabel;

  /// No description provided for @withdrawDestinationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vers (Mobile Money, compte)'**
  String get withdrawDestinationLabel;

  /// No description provided for @withdrawConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retrait'**
  String get withdrawConfirm;

  /// No description provided for @withdrawSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Retrait effectue. Reference {ref}'**
  String withdrawSuccess(String ref);

  /// No description provided for @withdrawInsufficient.
  ///
  /// In fr, this message translates to:
  /// **'Solde insuffisant pour ce retrait'**
  String get withdrawInsufficient;

  /// No description provided for @withdrawInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide'**
  String get withdrawInvalidAmount;

  /// No description provided for @notifCenterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifCenterTitle;

  /// No description provided for @notifCenterEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification pour le moment'**
  String get notifCenterEmpty;

  /// No description provided for @notifCenterMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notifCenterMarkAllRead;

  /// No description provided for @notifCenterClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique'**
  String get notifCenterClear;

  /// No description provided for @rateCta.
  ///
  /// In fr, this message translates to:
  /// **'Noter le livreur'**
  String get rateCta;

  /// No description provided for @rateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Noter le livreur'**
  String get rateTitle;

  /// No description provided for @rateOverall.
  ///
  /// In fr, this message translates to:
  /// **'Note globale'**
  String get rateOverall;

  /// No description provided for @ratePunctuality.
  ///
  /// In fr, this message translates to:
  /// **'Ponctualite'**
  String get ratePunctuality;

  /// No description provided for @rateService.
  ///
  /// In fr, this message translates to:
  /// **'Qualite du service'**
  String get rateService;

  /// No description provided for @rateComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (optionnel)'**
  String get rateComment;

  /// No description provided for @rateSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l\'evaluation'**
  String get rateSubmit;

  /// No description provided for @rateThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre evaluation'**
  String get rateThanks;

  /// No description provided for @rateAlready.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez deja note cette course'**
  String get rateAlready;

  /// No description provided for @notifEventAcceptedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Course acceptee'**
  String get notifEventAcceptedTitle;

  /// No description provided for @notifEventAcceptedBody.
  ///
  /// In fr, this message translates to:
  /// **'Un livreur a pris votre course en charge.'**
  String get notifEventAcceptedBody;

  /// No description provided for @notifEventPickedUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Colis recupere'**
  String get notifEventPickedUpTitle;

  /// No description provided for @notifEventPickedUpBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur a recupere votre colis.'**
  String get notifEventPickedUpBody;

  /// No description provided for @notifEventInTransitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Colis en route'**
  String get notifEventInTransitTitle;

  /// No description provided for @notifEventInTransitBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre colis est en cours de livraison.'**
  String get notifEventInTransitBody;

  /// No description provided for @notifEventArrivedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livreur arrive'**
  String get notifEventArrivedTitle;

  /// No description provided for @notifEventArrivedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le livreur est arrive a destination.'**
  String get notifEventArrivedBody;

  /// No description provided for @notifEventDeliveredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison terminee'**
  String get notifEventDeliveredTitle;

  /// No description provided for @notifEventDeliveredBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre colis a ete remis.'**
  String get notifEventDeliveredBody;

  /// No description provided for @notifEventCancelledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Course annulee'**
  String get notifEventCancelledTitle;

  /// No description provided for @notifEventCancelledBody.
  ///
  /// In fr, this message translates to:
  /// **'La course a ete annulee.'**
  String get notifEventCancelledBody;

  /// No description provided for @notifEventPaidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement recu'**
  String get notifEventPaidTitle;

  /// No description provided for @notifEventPaidBody.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement a ete regle avec succes.'**
  String get notifEventPaidBody;

  /// No description provided for @kycTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon dossier'**
  String get kycTitle;

  /// No description provided for @kycStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Dossier a completer'**
  String get kycStatusDraft;

  /// No description provided for @kycStatusSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Dossier transmis'**
  String get kycStatusSubmitted;

  /// No description provided for @kycStatusUnderReview.
  ///
  /// In fr, this message translates to:
  /// **'En cours de verification'**
  String get kycStatusUnderReview;

  /// No description provided for @kycStatusApproved.
  ///
  /// In fr, this message translates to:
  /// **'Dossier valide'**
  String get kycStatusApproved;

  /// No description provided for @kycStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Dossier refuse'**
  String get kycStatusRejected;

  /// No description provided for @kycBlocking.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas prendre de course tant que le dossier n\'est pas valide.'**
  String get kycBlocking;

  /// No description provided for @kycDocCinFront.
  ///
  /// In fr, this message translates to:
  /// **'CIN recto'**
  String get kycDocCinFront;

  /// No description provided for @kycDocCinBack.
  ///
  /// In fr, this message translates to:
  /// **'CIN verso'**
  String get kycDocCinBack;

  /// No description provided for @kycDocLicence.
  ///
  /// In fr, this message translates to:
  /// **'Permis de conduire'**
  String get kycDocLicence;

  /// No description provided for @kycDocSelfie.
  ///
  /// In fr, this message translates to:
  /// **'Photo du visage'**
  String get kycDocSelfie;

  /// No description provided for @kycDocRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Carte grise'**
  String get kycDocRegistration;

  /// No description provided for @kycDocVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Photo du vehicule'**
  String get kycDocVehicle;

  /// No description provided for @kycDocPlate.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la plaque'**
  String get kycDocPlate;

  /// No description provided for @kycCaptureLater.
  ///
  /// In fr, this message translates to:
  /// **'La prise de vue des pieces arrive au module 5.'**
  String get kycCaptureLater;

  /// No description provided for @kycSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Transmettre le dossier'**
  String get kycSubmit;

  /// No description provided for @kycSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Dossier transmis pour verification'**
  String get kycSubmitted;

  /// No description provided for @kycUnderReviewHelp.
  ///
  /// In fr, this message translates to:
  /// **'Votre dossier est en cours de verification.'**
  String get kycUnderReviewHelp;

  /// No description provided for @kycProgress.
  ///
  /// In fr, this message translates to:
  /// **'{done} pieces sur {total} fournies'**
  String kycProgress(int done, int total);

  /// No description provided for @vehicleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon vehicule'**
  String get vehicleTitle;

  /// No description provided for @vehicleManage.
  ///
  /// In fr, this message translates to:
  /// **'Informations du vehicule'**
  String get vehicleManage;

  /// No description provided for @vehicleManageHelp.
  ///
  /// In fr, this message translates to:
  /// **'Type, marque, modele, plaque et assurance.'**
  String get vehicleManageHelp;

  /// No description provided for @vehicleType.
  ///
  /// In fr, this message translates to:
  /// **'Type de vehicule'**
  String get vehicleType;

  /// No description provided for @vehicleTypeMoto.
  ///
  /// In fr, this message translates to:
  /// **'Moto'**
  String get vehicleTypeMoto;

  /// No description provided for @vehicleTypeBicycle.
  ///
  /// In fr, this message translates to:
  /// **'Velo'**
  String get vehicleTypeBicycle;

  /// No description provided for @vehicleTypeCar.
  ///
  /// In fr, this message translates to:
  /// **'Voiture'**
  String get vehicleTypeCar;

  /// No description provided for @vehicleTypeTricycle.
  ///
  /// In fr, this message translates to:
  /// **'Tricycle'**
  String get vehicleTypeTricycle;

  /// No description provided for @vehicleBrand.
  ///
  /// In fr, this message translates to:
  /// **'Marque'**
  String get vehicleBrand;

  /// No description provided for @vehicleModel.
  ///
  /// In fr, this message translates to:
  /// **'Modele'**
  String get vehicleModel;

  /// No description provided for @vehiclePlate.
  ///
  /// In fr, this message translates to:
  /// **'Immatriculation'**
  String get vehiclePlate;

  /// No description provided for @vehicleInsurance.
  ///
  /// In fr, this message translates to:
  /// **'Echeance d\'assurance (AAAA-MM-JJ)'**
  String get vehicleInsurance;

  /// No description provided for @vehicleSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get vehicleSave;

  /// No description provided for @vehicleSaved.
  ///
  /// In fr, this message translates to:
  /// **'Vehicule enregistre'**
  String get vehicleSaved;

  /// No description provided for @vehicleValidationPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente de validation'**
  String get vehicleValidationPending;

  /// No description provided for @vehicleValidationValidated.
  ///
  /// In fr, this message translates to:
  /// **'Vehicule valide'**
  String get vehicleValidationValidated;

  /// No description provided for @vehicleValidationRejected.
  ///
  /// In fr, this message translates to:
  /// **'Vehicule refuse'**
  String get vehicleValidationRejected;

  /// No description provided for @vehicleRevalidateNote.
  ///
  /// In fr, this message translates to:
  /// **'Toute modification remet la fiche en attente de validation.'**
  String get vehicleRevalidateNote;

  /// No description provided for @kycInactiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte pas encore actif'**
  String get kycInactiveTitle;

  /// No description provided for @kycInactiveMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre dossier est en cours de validation. Vous pourrez accepter des courses une fois qu\'il sera valide.'**
  String get kycInactiveMessage;

  /// No description provided for @kycInactiveContact.
  ///
  /// In fr, this message translates to:
  /// **'Suivre mon dossier'**
  String get kycInactiveContact;

  /// No description provided for @kycInactiveClose.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get kycInactiveClose;

  /// No description provided for @kycFollowupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de mon dossier'**
  String get kycFollowupTitle;

  /// No description provided for @kycFollowupManage.
  ///
  /// In fr, this message translates to:
  /// **'Contacter l\'exploitation'**
  String get kycFollowupManage;

  /// No description provided for @kycFollowupHelp.
  ///
  /// In fr, this message translates to:
  /// **'Une question sur la validation de votre dossier ? Ecrivez a l\'exploitation, elle vous repond ici.'**
  String get kycFollowupHelp;

  /// No description provided for @kycFollowupHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre message a l\'exploitation'**
  String get kycFollowupHint;

  /// No description provided for @kycFollowupEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour l\'instant'**
  String get kycFollowupEmpty;

  /// No description provided for @kycFollowupSent.
  ///
  /// In fr, this message translates to:
  /// **'Message envoye'**
  String get kycFollowupSent;

  /// No description provided for @kycFollowupAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Exploitation'**
  String get kycFollowupAdmin;

  /// No description provided for @kycFollowupYou.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get kycFollowupYou;

  /// No description provided for @pickLocationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Placer le point'**
  String get pickLocationTitle;

  /// No description provided for @pickLocationAction.
  ///
  /// In fr, this message translates to:
  /// **'Placer sur la carte'**
  String get pickLocationAction;

  /// No description provided for @pickLocationSet.
  ///
  /// In fr, this message translates to:
  /// **'Point place'**
  String get pickLocationSet;

  /// No description provided for @pickLocationHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le point GPS approche le livreur ; le point de repere fait le reste.'**
  String get pickLocationHelp;

  /// No description provided for @trackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de la course'**
  String get trackingTitle;

  /// No description provided for @trackingTimeline.
  ///
  /// In fr, this message translates to:
  /// **'Etapes'**
  String get trackingTimeline;

  /// No description provided for @trackingDriver.
  ///
  /// In fr, this message translates to:
  /// **'Votre livreur'**
  String get trackingDriver;

  /// No description provided for @trackingEta.
  ///
  /// In fr, this message translates to:
  /// **'Arrivee estimee dans {minutes} min'**
  String trackingEta(int minutes);

  /// No description provided for @trackingShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager le suivi'**
  String get trackingShare;

  /// No description provided for @trackingCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien de suivi'**
  String get trackingCopyLink;

  /// No description provided for @trackingParcelCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de suivi du colis : {code}'**
  String trackingParcelCode(String code);

  /// No description provided for @trackingShareMessage.
  ///
  /// In fr, this message translates to:
  /// **'Suivez votre colis MajiChrono : {url}'**
  String trackingShareMessage(String url);

  /// No description provided for @trackingCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get trackingCall;

  /// No description provided for @trackingCallMasked.
  ///
  /// In fr, this message translates to:
  /// **'Numero masque des deux cotes'**
  String get trackingCallMasked;

  /// No description provided for @trackingRating.
  ///
  /// In fr, this message translates to:
  /// **'{rating} / 5'**
  String trackingRating(String rating);

  /// No description provided for @trackingPublicTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi du colis'**
  String get trackingPublicTitle;

  /// No description provided for @trackingPublicExpired.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien de suivi n\'est plus valable.'**
  String get trackingPublicExpired;

  /// No description provided for @trackingNoDriverYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livreur n\'a encore accepte la course.'**
  String get trackingNoDriverYet;

  /// No description provided for @mapUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Carte indisponible hors ligne. Les points restent affiches.'**
  String get mapUnavailable;

  /// No description provided for @linkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copie'**
  String get linkCopied;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'un livreur'**
  String get statusPending;

  /// No description provided for @statusAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Livreur en route'**
  String get statusAccepted;

  /// No description provided for @statusAtPickup.
  ///
  /// In fr, this message translates to:
  /// **'Livreur au depart'**
  String get statusAtPickup;

  /// No description provided for @statusPickedUp.
  ///
  /// In fr, this message translates to:
  /// **'Colis pris en charge'**
  String get statusPickedUp;

  /// No description provided for @statusInTransit.
  ///
  /// In fr, this message translates to:
  /// **'En transit'**
  String get statusInTransit;

  /// No description provided for @statusAtDestination.
  ///
  /// In fr, this message translates to:
  /// **'Livreur arrive'**
  String get statusAtDestination;

  /// No description provided for @statusDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livree'**
  String get statusDelivered;

  /// No description provided for @statusDeliveredWithReserves.
  ///
  /// In fr, this message translates to:
  /// **'Livree avec reserves'**
  String get statusDeliveredWithReserves;

  /// No description provided for @statusRefused.
  ///
  /// In fr, this message translates to:
  /// **'Refusee'**
  String get statusRefused;

  /// No description provided for @statusReturning.
  ///
  /// In fr, this message translates to:
  /// **'Retour expediteur'**
  String get statusReturning;

  /// No description provided for @statusPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payee'**
  String get statusPaid;

  /// No description provided for @statusDisputed.
  ///
  /// In fr, this message translates to:
  /// **'Litige'**
  String get statusDisputed;

  /// No description provided for @statusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulee'**
  String get statusCancelled;

  /// No description provided for @statusClosed.
  ///
  /// In fr, this message translates to:
  /// **'Cloturee'**
  String get statusClosed;

  /// No description provided for @statusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get statusDraft;

  /// No description provided for @emptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien a afficher'**
  String get emptyTitle;

  /// No description provided for @emptyDeliveries.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course pour l\'instant'**
  String get emptyDeliveries;

  /// No description provided for @emptyDeliveriesAction.
  ///
  /// In fr, this message translates to:
  /// **'Creer une course'**
  String get emptyDeliveriesAction;

  /// No description provided for @errorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une action est necessaire'**
  String get errorTitle;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Le reseau est indisponible. L\'action est enregistree et partira des le retour du reseau.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met trop de temps a repondre.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In fr, this message translates to:
  /// **'Le service est momentanement indisponible.'**
  String get errorServer;

  /// No description provided for @errorUnauthorized.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expire. Reconnectez-vous.'**
  String get errorUnauthorized;

  /// No description provided for @errorConflict.
  ///
  /// In fr, this message translates to:
  /// **'Cette operation a deja ete traitee.'**
  String get errorConflict;

  /// No description provided for @errorUpdateRequired.
  ///
  /// In fr, this message translates to:
  /// **'Une mise a jour de l\'application est necessaire.'**
  String get errorUpdateRequired;

  /// No description provided for @errorStorage.
  ///
  /// In fr, this message translates to:
  /// **'L\'appareil ne peut pas enregistrer les donnees.'**
  String get errorStorage;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Reessayez.'**
  String get errorUnknown;

  /// No description provided for @devPanelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Panneau developpeur'**
  String get devPanelTitle;

  /// No description provided for @devNetworkProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil reseau simule'**
  String get devNetworkProfile;

  /// No description provided for @devProfile4g.
  ///
  /// In fr, this message translates to:
  /// **'4G'**
  String get devProfile4g;

  /// No description provided for @devProfile3g.
  ///
  /// In fr, this message translates to:
  /// **'3G'**
  String get devProfile3g;

  /// No description provided for @devProfile2g.
  ///
  /// In fr, this message translates to:
  /// **'2G / EDGE'**
  String get devProfile2g;

  /// No description provided for @devProfileOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne (mode avion)'**
  String get devProfileOffline;

  /// No description provided for @devFailureRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'echec injecte'**
  String get devFailureRate;

  /// No description provided for @devApiMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode API'**
  String get devApiMode;

  /// No description provided for @devDataUsed.
  ///
  /// In fr, this message translates to:
  /// **'Donnees consommees'**
  String get devDataUsed;

  /// No description provided for @devResetMock.
  ///
  /// In fr, this message translates to:
  /// **'Reinitialiser les donnees simulees'**
  String get devResetMock;

  /// No description provided for @socleProbe.
  ///
  /// In fr, this message translates to:
  /// **'Sonde applicative'**
  String get socleProbe;

  /// No description provided for @socleSyncQueue.
  ///
  /// In fr, this message translates to:
  /// **'File de synchronisation'**
  String get socleSyncQueue;

  /// No description provided for @settingsSwitchProfile.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil'**
  String get settingsSwitchProfile;

  /// No description provided for @dataUsageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma consommation'**
  String get dataUsageTitle;

  /// No description provided for @dataUsageThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get dataUsageThisMonth;

  /// No description provided for @dataBudgetReference.
  ///
  /// In fr, this message translates to:
  /// **'Budget mensuel de reference : 25 Mo'**
  String get dataBudgetReference;

  /// No description provided for @dataCatApi.
  ///
  /// In fr, this message translates to:
  /// **'Echanges applicatifs'**
  String get dataCatApi;

  /// No description provided for @dataCatPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos et constats'**
  String get dataCatPhotos;

  /// No description provided for @dataCatMaps.
  ///
  /// In fr, this message translates to:
  /// **'Cartes'**
  String get dataCatMaps;

  /// No description provided for @dataCatTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de position'**
  String get dataCatTracking;

  /// No description provided for @dataCatPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get dataCatPayment;

  /// No description provided for @dataCatOther.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get dataCatOther;

  /// No description provided for @bytesKb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Ko'**
  String bytesKb(String value);

  /// No description provided for @bytesMb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Mo'**
  String bytesMb(String value);

  /// No description provided for @shellModuleWip.
  ///
  /// In fr, this message translates to:
  /// **'Module en cours de construction'**
  String get shellModuleWip;

  /// No description provided for @shellModuleWipDesc.
  ///
  /// In fr, this message translates to:
  /// **'Cet ecran sera livre au module {module}.'**
  String shellModuleWipDesc(String module);

  /// No description provided for @messagesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation'**
  String get messagesEmpty;

  /// No description provided for @messagesEmptyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vos discussions avec les livreurs (ou expediteurs) apparaitront ici, des qu\'une course est acceptee.'**
  String get messagesEmptyHelp;

  /// No description provided for @messagesYouPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Vous : {message}'**
  String messagesYouPrefix(String message);

  /// No description provided for @chatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get chatTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre message'**
  String get chatInputHint;

  /// No description provided for @chatSendError.
  ///
  /// In fr, this message translates to:
  /// **'Message non envoye, reessayez'**
  String get chatSendError;

  /// No description provided for @chatUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Discussion indisponible pour le moment'**
  String get chatUnavailable;

  /// No description provided for @chatUnavailableHint.
  ///
  /// In fr, this message translates to:
  /// **'Verifiez le reseau, la relecture reprendra seule.'**
  String get chatUnavailableHint;

  /// No description provided for @chatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Demarrez la conversation'**
  String get chatEmpty;

  /// No description provided for @chatEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnez le retrait et la remise du colis.'**
  String get chatEmptyHint;

  /// No description provided for @chatToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get chatYesterday;

  /// No description provided for @chatRead.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get chatRead;

  /// No description provided for @chatSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoye'**
  String get chatSent;

  /// No description provided for @chatCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get chatCall;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr', 'mg'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
    case 'mg':
      return AppLocalizationsMg();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
