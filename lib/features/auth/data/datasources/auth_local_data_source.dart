import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:majichrono/core/storage/secure_store.dart';

/// Persistance locale de la session et du verrou (EXI-SEC03, EXI-T04).
///
/// Tout passe par le Keystore Android / Keychain iOS : jetons, empreinte du
/// code PIN, et jusqu'au compte en cache, qui contient un numero de telephone.
class AuthLocalDataSource {
  AuthLocalDataSource(this._store, {Random? random})
    : _random = random ?? Random.secure();

  static const String _keyAccount = 'auth.account';
  static const String _keyPinAttempts = 'auth.pin_attempts';

  /// Iterations de derivation du code PIN.
  ///
  /// Un PIN a quatre chiffres n'offre que dix mille possibilites : aucune
  /// derivation, si couteuse soit-elle, ne le rend resistant a une attaque hors
  /// ligne menee sur un appareil deverrouille. La protection reelle vient
  /// d'ailleurs — le materiel de l'appareil, qui garde le sel hors de portee,
  /// et le compteur de tentatives ci-dessous. La derivation ne sert qu'a ce que
  /// le code ne soit jamais ecrit en clair, nulle part.
  static const int _pinIterations = 20000;

  /// Au-dela, le verrou local est detruit et une reconnexion complete par OTP
  /// est exigee. C'est ce compteur, pas la force du hachage, qui rend le PIN
  /// defendable.
  static const int maxPinAttempts = 5;

  final SecureStore _store;
  final Random _random;

  // --- Session ----------------------------------------------------------

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required DateTime refreshExpiresAt,
  }) async {
    await _store.write(SecureStore.keyAccessToken, accessToken);
    await _store.write(SecureStore.keyRefreshToken, refreshToken);
    await _store.write(
      SecureStore.keyAccessExpiry,
      jsonEncode({
        'access': accessExpiresAt.toIso8601String(),
        'refresh': refreshExpiresAt.toIso8601String(),
      }),
    );
  }

  Future<String?> readAccessToken() => _store.read(SecureStore.keyAccessToken);
  Future<String?> readRefreshToken() =>
      _store.read(SecureStore.keyRefreshToken);

  Future<({DateTime access, DateTime refresh})?> readExpiries() async {
    final raw = await _store.read(SecureStore.keyAccessExpiry);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        access: DateTime.parse(map['access'] as String),
        refresh: DateTime.parse(map['refresh'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  // --- Compte en cache ---------------------------------------------------

  Future<void> saveAccount(Map<String, dynamic> json) =>
      _store.write(_keyAccount, jsonEncode(json));

  Future<Map<String, dynamic>?> readAccount() async {
    final raw = await _store.read(_keyAccount);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // --- Code PIN ----------------------------------------------------------

  Future<bool> hasPin() async =>
      await _store.read(SecureStore.keyPinHash) != null;

  Future<void> setPin(String pin) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    await _store.write(SecureStore.keyPinSalt, base64.encode(salt));
    await _store.write(SecureStore.keyPinHash, _derive(pin, salt));
    await _store.write(_keyPinAttempts, '0');
  }

  /// Retourne le nombre de tentatives restantes, ou `null` si le code est bon.
  Future<int?> verifyPin(String pin) async {
    final saltRaw = await _store.read(SecureStore.keyPinSalt);
    final expected = await _store.read(SecureStore.keyPinHash);
    if (saltRaw == null || expected == null) return 0;

    final salt = base64.decode(saltRaw);
    if (_derive(pin, salt) == expected) {
      await _store.write(_keyPinAttempts, '0');
      return null;
    }

    final used = int.tryParse(await _store.read(_keyPinAttempts) ?? '0') ?? 0;
    final next = used + 1;
    await _store.write(_keyPinAttempts, '$next');

    final left = maxPinAttempts - next;
    if (left <= 0) await clearPin();
    return left < 0 ? 0 : left;
  }

  Future<void> clearPin() async {
    await _store.delete(SecureStore.keyPinHash);
    await _store.delete(SecureStore.keyPinSalt);
    await _store.delete(_keyPinAttempts);
  }

  /// Derivation iteree facon PBKDF2, en HMAC-SHA-256.
  String _derive(String pin, List<int> salt) {
    final hmac = Hmac(sha256, salt);
    var block = hmac.convert(utf8.encode(pin)).bytes;
    for (var i = 1; i < _pinIterations; i++) {
      block = hmac.convert(block).bytes;
    }
    return base64.encode(block);
  }

  // --- Deconnexion -------------------------------------------------------

  /// Effacement complet des donnees locales (EXI-SEC10).
  Future<void> wipe() => _store.wipe();
}
