import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage des secrets (EXI-SEC03) : Keystore Android / Keychain iOS.
///
/// Les jetons ne passent jamais par `shared_preferences`.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String keyAccessToken = 'auth.access_token';
  static const String keyRefreshToken = 'auth.refresh_token';
  static const String keyAccessExpiry = 'auth.access_expiry';
  static const String keyPinHash = 'auth.pin_hash';
  static const String keyPinSalt = 'auth.pin_salt';
  static const String keyDbPassphrase = 'storage.db_passphrase';

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Effacement complet a la deconnexion (EXI-SEC10).
  Future<void> wipe() => _storage.deleteAll();
}
