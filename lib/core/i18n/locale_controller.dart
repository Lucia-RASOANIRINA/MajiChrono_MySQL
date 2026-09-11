import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/storage/prefs_store.dart';

/// Langues supportees (§2.1) : francais et malgache.
class AppLocales {
  const AppLocales._();

  static const Locale french = Locale('fr');
  static const Locale malagasy = Locale('mg');

  static const List<Locale> supported = [french, malagasy];

  static Locale fromCode(String? code) => code == 'mg' ? malagasy : french;
}

/// Bascule francais <-> malgache a chaud, sans redemarrage (EXI-T05).
///
/// L'exigence porte aussi sur les notifications : le code de langue est donc
/// pousse dans [activeLanguageCodeProvider], que le client HTTP envoie en
/// `Accept-Language` a chaque requete. Le serveur traduit ainsi les messages
/// distants dans la langue courante du compte, y compris application fermee.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref
        .watch(prefsStoreProvider)
        .getString(PrefsStore.keyLocale);
    final locale = AppLocales.fromCode(stored ?? _deviceLanguage());
    // Synchronisation immediate de l'en-tete HTTP.
    Future.microtask(
      () => ref.read(activeLanguageCodeProvider.notifier).state =
          locale.languageCode,
    );
    return locale;
  }

  Future<void> set(Locale locale) async {
    if (locale == state) return;
    state = locale;
    ref.read(activeLanguageCodeProvider.notifier).state = locale.languageCode;
    await ref
        .read(prefsStoreProvider)
        .setString(PrefsStore.keyLocale, locale.languageCode);
  }

  Future<void> toggle() =>
      set(state.languageCode == 'fr' ? AppLocales.malagasy : AppLocales.french);

  /// A la premiere ouverture, on suit la langue de l'appareil si elle fait
  /// partie des langues supportees — le malgache est la langue d'usage (§4.5).
  String _deviceLanguage() {
    final device = PlatformDispatcher.instance.locale.languageCode;
    return device == 'mg' ? 'mg' : 'fr';
  }
}
