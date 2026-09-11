import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regle 9.3.5 du cahier des charges : **aucune chaine litterale dans le code
/// d'interface**, tout texte affiche vient des fichiers ARB.
///
/// La regle n'est pas cosmetique. Une chaine ecrite en dur ne casse rien : elle
/// reste simplement en francais quand l'utilisateur bascule en malgache, au
/// milieu d'un ecran par ailleurs traduit. C'est exactement ce qui s'est produit
/// sur l'ecran d'accueil du socle, ou « Sonde applicative » et « File de
/// synchronisation » sont restees francaises apres la bascule — un defaut
/// invisible en revue de code et visible seulement a l'ecran, en malgache.
/// Ce test le fait remonter des la proposition de fusion (§16.3).
void main() {
  /// Le panneau developpeur n'est pas compile en production (`enableDevPanel`)
  /// et ne s'adresse qu'a l'equipe : il est hors perimetre de la regle.
  const allowlist = {'lib/features/settings/presentation/dev_panel_screen.dart'};

  /// `Text('...')` avec au moins quatre lettres consecutives : assez pour
  /// attraper un libelle, assez peu pour laisser passer un separateur ou une
  /// unite (« · », « % »).
  ///
  /// Le `$` est exclu du motif : une chaine interpolee est presque toujours
  /// **assemblee a partir de traductions** — `Text('${l10n.a} ${l10n.b}')` —
  /// et la signaler produirait un bruit qui ferait desactiver le test. La
  /// contrepartie assumee est qu'un libelle en dur contenant une interpolation
  /// echappe au controle ; c'est un cas rare, et la relecture le voit.
  final literalText = RegExp(r'''Text\(\s*(['"])[^'"$]*[A-Za-zÀ-ÿ]{4}''');

  test('aucune chaine litterale dans les widgets de l interface', () {
    final offenders = <String>[];

    for (final directory in ['lib/app', 'lib/features', 'lib/shared']) {
      final dir = Directory(directory);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final relative = entity.path.replaceAll(r'\', '/');
        if (allowlist.any(relative.endsWith)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literalText.hasMatch(lines[i])) {
            offenders.add('$relative:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Ces libelles doivent passer par les fichiers ARB (regle 9.3.5) :\n'
          '${offenders.join('\n')}',
    );
  });
}
