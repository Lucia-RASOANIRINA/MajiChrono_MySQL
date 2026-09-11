import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Libelles integres de Flutter pour le malgache.
///
/// Flutter ne fournit **aucune** traduction malgache pour `MaterialLocalizations`
/// ni `CupertinoLocalizations`. Sans ces delegues, une application en malgache
/// afficherait en anglais tout ce que le framework rend lui-meme : le selecteur
/// de date du creneau programme (EXI-C11), le menu de selection de texte, les
/// libelles d'accessibilite du bouton retour lus par TalkBack (EXI-T09), les
/// boutons des boites de dialogue. Le critere d'acceptation n° 7 du §18 — une
/// application **integralement** traduite en francais et en malgache — ne serait
/// pas tenu, et le defaut ne se verrait qu'a l'usage, sur un ecran secondaire.
///
/// Le repli retenu est le **francais**, pas l'anglais : c'est la langue
/// administrative de Madagascar (§4.5), donc celle que comprend un utilisateur
/// malgachophone confronte a un libelle non traduit. Les conventions de date et
/// de nombre francaises correspondent en outre a l'usage local.
///
/// Ces delegues doivent etre declares **avant** les delegues globaux dans
/// `localizationsDelegates`, faute de quoi ces derniers prendraient la main.
class MgMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MgMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'mg';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('fr'));

  @override
  bool shouldReload(MgMaterialLocalizationsDelegate old) => false;
}

class MgCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const MgCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'mg';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('fr'));

  @override
  bool shouldReload(MgCupertinoLocalizationsDelegate old) => false;
}

class MgWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const MgWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'mg';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('fr'));

  @override
  bool shouldReload(MgWidgetsLocalizationsDelegate old) => false;
}
