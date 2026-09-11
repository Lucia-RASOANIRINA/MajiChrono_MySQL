import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Critere d'acceptation n° 7 du §18 : l'application est **integralement**
/// traduite en francais et en malgache.
///
/// Une cle oubliee dans `app_mg.arb` ne provoque aucune erreur de compilation :
/// Flutter retombe silencieusement sur le francais. Le defaut ne se verrait
/// donc qu'en recette terrain, chez un livreur malgachophone. Ce test le rend
/// visible des la proposition de fusion (§16.3).
void main() {
  Map<String, dynamic> readArb(String locale) {
    final file = File('lib/l10n/arb/app_$locale.arb');
    expect(file.existsSync(), isTrue, reason: 'ARB manquant : ${file.path}');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Les cles de metadonnees (`@cle`, `@@locale`) ne sont pas des traductions.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('aucune cle francaise ne manque en malgache', () {
    final fr = messageKeys(readArb('fr'));
    final mg = messageKeys(readArb('mg'));

    final missing = fr.difference(mg).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Cles non traduites en malgache : ${missing.join(', ')}',
    );
  });

  test('aucune cle malgache orpheline', () {
    final fr = messageKeys(readArb('fr'));
    final mg = messageKeys(readArb('mg'));

    final orphans = mg.difference(fr).toList()..sort();
    expect(
      orphans,
      isEmpty,
      reason: 'Cles absentes du modele francais : ${orphans.join(', ')}',
    );
  });

  test('aucune traduction vide', () {
    for (final locale in ['fr', 'mg']) {
      final arb = readArb(locale);
      for (final key in messageKeys(arb)) {
        expect(
          '${arb[key]}'.trim(),
          isNotEmpty,
          reason: 'Traduction vide : $key ($locale)',
        );
      }
    }
  });

  test('les parametres de chaque message sont identiques dans les deux langues', () {
    final fr = readArb('fr');
    final mg = readArb('mg');
    final placeholder = RegExp(r'\{(\w+)\}');

    for (final key in messageKeys(fr)) {
      final frParams =
          placeholder.allMatches('${fr[key]}').map((m) => m.group(1)).toSet();
      final mgParams =
          placeholder.allMatches('${mg[key]}').map((m) => m.group(1)).toSet();
      expect(
        mgParams,
        frParams,
        reason: 'Parametres divergents pour "$key" : $frParams vs $mgParams',
      );
    }
  });
}
