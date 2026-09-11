import 'package:shared_preferences/shared_preferences.dart';

/// Preferences non sensibles (EXI-T05, EXI-T08, EXI-L03).
class PrefsStore {
  PrefsStore(this._prefs);

  static const String keyLocale = 'settings.locale';
  static const String keyThemeMode = 'settings.theme_mode';
  static const String keySavingMode = 'settings.saving_mode';
  static const String keyOnboarded = 'settings.onboarded';
  static const String keyActiveRole = 'session.active_role';

  /// Etat en ligne du livreur, persistant apres redemarrage (EXI-L03).
  static const String keyDriverOnline = 'driver.online';

  static const String keyDevNetworkProfile = 'dev.network_profile';
  static const String keyDevFailureRate = 'dev.failure_rate';

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(key) ?? fallback;
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Efface les preferences liees a la session, pas les reglages d'appareil
  /// (langue, theme) que l'utilisateur retrouve apres une deconnexion.
  Future<void> clearSession() async {
    await _prefs.remove(keyActiveRole);
    await _prefs.remove(keyDriverOnline);
  }
}
