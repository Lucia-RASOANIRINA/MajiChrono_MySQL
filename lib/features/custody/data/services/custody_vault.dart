import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:majichrono/core/storage/secure_store.dart';

/// Chiffrement au repos des constats non transmis (EXI-CC46, EXI-SEC04).
///
/// Un constat qui attend le reseau contient des photos de colis, des positions
/// GPS, des numeros de telephone et deux signatures manuscrites. Sur le
/// telephone d'un livreur — appareil personnel, souvent partage, parfois vole
/// (§4.4, EXI-L13) — le laisser en clair reviendrait a publier la preuve avant
/// qu'elle ne soit protegee.
///
/// La cle est tiree une seule fois et rangee dans le Keystore Android
/// (EXI-SEC03). Elle ne quitte jamais l'appareil : le serveur recoit le constat
/// en clair sur un canal TLS, pas la cle. Effacer les donnees locales
/// (EXI-SEC10) detruit la cle, donc rend illisible ce qui resterait sur disque.
class CustodyVault {
  CustodyVault(this._store, {Random? random})
    : _random = random ?? Random.secure();

  final SecureStore _store;
  final Random _random;

  Key? _cached;

  /// Cle AES-256, creee a la premiere utilisation.
  Future<Key> _key() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = await _store.read(SecureStore.keyDbPassphrase);
    if (stored != null) {
      return _cached = Key.fromBase64(stored);
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final key = Key(Uint8List.fromList(bytes));
    await _store.write(SecureStore.keyDbPassphrase, key.base64);
    return _cached = key;
  }

  /// Chiffre un contenu JSON.
  ///
  /// Le vecteur d'initialisation est tire a chaque appel et range **avec** le
  /// chiffre : deux constats identiques ne doivent pas produire deux cryptogrammes
  /// identiques, sinon leur comparaison revelerait qu'ils le sont.
  Future<String> encryptJson(Map<String, dynamic> payload) async {
    final key = await _key();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonEncode(payload), iv: iv);

    return jsonEncode({'iv': iv.base64, 'data': encrypted.base64});
  }

  /// Dechiffre un contenu produit par [encryptJson].
  ///
  /// Retourne `null` si le contenu est illisible — cle changee, donnees
  /// tronquees. On prefere perdre l'affichage d'un constat que faire tomber
  /// l'application sur une exception de dechiffrement.
  ///
  /// Le filet attrape `Object` et non `Exception` : une cle qui ne correspond
  /// plus fait remonter un `ArgumentError` depuis le depadding AES, qui est une
  /// *erreur* et non une exception. Ne pas l'attraper ferait tomber l'ecran des
  /// preuves au moment precis ou l'on cherche a le consulter.
  Future<Map<String, dynamic>?> decryptJson(String envelope) async {
    try {
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      final iv = IV.fromBase64('${decoded['iv']}');
      final encrypter = Encrypter(AES(await _key(), mode: AESMode.cbc));
      final plain = encrypter.decrypt64('${decoded['data']}', iv: iv);
      return jsonDecode(plain) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  /// Vrai lorsque le contenu est une enveloppe chiffree.
  ///
  /// Permet de relire les constats ecrits avant l'arrivee du chiffrement, sans
  /// les perdre : une migration qui detruirait des preuves serait pire que le
  /// defaut qu'elle corrige.
  static bool isEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> &&
          decoded.containsKey('iv') &&
          decoded.containsKey('data');
    } on FormatException {
      return false;
    }
  }
}
