import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/storage/secure_store.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';

/// Verrouillage du telephone : ce que l'utilisateur utilise deja pour ouvrir
/// son telephone — code, schema, empreinte ou visage.
///
/// Il remplace le SMS a l'entree par numero. L'invite est celle du systeme :
/// l'application ne voit jamais le code ni l'empreinte, elle apprend seulement
/// que le proprietaire du telephone vient de le deverrouiller.
class DeviceLock {
  DeviceLock(this._auth);

  final LocalAuthentication _auth;

  /// Vrai si le telephone a un verrouillage configure (code, schema,
  /// empreinte, visage). Sans lui, l'entree passe par un mot de passe.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (error) {
      AppLogger.instance.warn('device_lock_unavailable', error: error);
      return false;
    }
  }

  /// Demande le verrouillage du telephone. Rend vrai si l'utilisateur l'a
  /// passe, faux s'il a annule ou echoue.
  ///
  /// `biometricOnly: false` : le code ou le schema valent autant que
  /// l'empreinte. Beaucoup de telephones d'entree de gamme n'ont pas de
  /// capteur, et c'est le moyen que l'utilisateur connait deja.
  Future<bool> confirm({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on Object catch (error) {
      AppLogger.instance.warn('device_lock_failed', error: error);
      return false;
    }
  }
}

final deviceLockProvider = Provider<DeviceLock>(
  (ref) => DeviceLock(ref.watch(localAuthProvider)),
);

/// Cles d'appareil, une par numero, gardees dans le stockage securise
/// (Keystore Android). Elles ne servent qu'apres le verrouillage du telephone.
class DeviceKeyStore {
  DeviceKeyStore(this._store, {Random? random})
    : _random = random ?? Random.secure();

  final SecureStore _store;
  final Random _random;

  String _key(String phoneE164) => '${SecureStore.deviceKeyPrefix}$phoneE164';

  Future<String?> secretFor(String phoneE164) => _store.read(_key(phoneE164));

  /// Cree (ou remplace) la cle de ce telephone pour ce numero : 32 octets
  /// aleatoires, en base64url.
  Future<String> createFor(String phoneE164) async {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final secret = base64UrlEncode(bytes);
    await _store.write(_key(phoneE164), secret);
    return secret;
  }

  Future<void> forget(String phoneE164) => _store.delete(_key(phoneE164));
}

final deviceKeyStoreProvider = Provider<DeviceKeyStore>(
  (ref) => DeviceKeyStore(ref.watch(secureStoreProvider)),
);
