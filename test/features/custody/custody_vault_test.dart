import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/storage/secure_store.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';

import '../../helpers/fake_secure_store.dart';

/// Chiffrement au repos des constats (EXI-CC46, EXI-SEC04).
///
/// Ce que ces tests protegent tient en une phrase : un constat qui attend le
/// reseau ne doit pas etre lisible par qui ouvre le stockage du telephone.
void main() {
  late FakeSecureStore store;
  late CustodyVault vault;

  setUp(() {
    store = FakeSecureStore();
    vault = CustodyVault(store, random: Random(11));
  });

  final payload = <String, dynamic>{
    'report': {
      'id': 'cst_1',
      'sealNumber': 'SC-4821',
      'point': {'lat': -18.9010, 'lng': 47.5490},
    },
    'acknowledged': false,
  };

  test('le contenu chiffre ne laisse rien lire en clair', () async {
    final envelope = await vault.encryptJson(payload);

    // Le numero de scelle et la position sont precisement ce qu'un tiers
    // chercherait : ils ne doivent apparaitre nulle part dans l'enveloppe.
    expect(envelope, isNot(contains('SC-4821')));
    expect(envelope, isNot(contains('47.5490')));
    expect(envelope, isNot(contains('cst_1')));
  });

  test('le tour complet restitue le contenu a l identique', () async {
    final restored = await vault.decryptJson(await vault.encryptJson(payload));

    expect(restored, isNotNull);
    expect(jsonEncode(restored), jsonEncode(payload));
  });

  test('deux chiffrements du meme contenu different', () async {
    // Sans vecteur d'initialisation tire a chaque appel, comparer deux
    // enveloppes revelerait que les constats sont identiques — donc, par
    // exemple, qu'un livreur a duplique un constat au lieu d'en faire un.
    final a = await vault.encryptJson(payload);
    final b = await vault.encryptJson(payload);

    expect(a, isNot(b));
    expect(jsonEncode(await vault.decryptJson(a)), jsonEncode(await vault.decryptJson(b)));
  });

  test('la cle vit dans le stockage securise, jamais dans la base', () async {
    expect(store.isEmpty, isTrue);
    await vault.encryptJson(payload);

    expect(store.dump().keys, contains(SecureStore.keyDbPassphrase));
    // 32 octets en base64 : une cle AES-256.
    expect(base64Decode(store.dump()[SecureStore.keyDbPassphrase]!), hasLength(32));
  });

  test('une cle effacee rend le contenu illisible sans faire tomber l app', () async {
    final envelope = await vault.encryptJson(payload);

    // EXI-SEC10 : l'effacement des donnees locales detruit la cle. Ce qui
    // resterait sur disque devient inexploitable, et la lecture retourne null
    // au lieu de propager une exception de dechiffrement.
    await store.wipe();
    final other = CustodyVault(store, random: Random(12));

    expect(await other.decryptJson(envelope), isNull);
  });

  test('un contenu anterieur au chiffrement reste reconnaissable', () async {
    // Une migration qui detruirait des preuves serait pire que le defaut
    // qu'elle corrige : le repository doit pouvoir distinguer les deux formes.
    expect(CustodyVault.isEnvelope(jsonEncode(payload)), isFalse);
    expect(CustodyVault.isEnvelope(await vault.encryptJson(payload)), isTrue);
    expect(CustodyVault.isEnvelope('pas du json'), isFalse);
  });
}
