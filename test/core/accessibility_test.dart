import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Accessibilite (EXI-T09).
///
/// Les exigences ne sont pas cosmetiques : l'application est utilisee **en
/// plein soleil, d'une main, moto a l'arret**. Un contraste insuffisant ou une
/// cible trop petite ne degrade pas l'experience — elle rend l'application
/// inutilisable dans les conditions ou elle sert.
///
/// Ces tests verifient ce qui se verifie sans appareil : les ratios de
/// contraste et les dimensions du systeme de design. Le rendu reel avec
/// TalkBack demande une recette sur appareil, qui reste a faire.
void main() {
  /// Luminance relative, formule WCAG 2.1.
  double luminance(Color c) {
    double channel(double v) {
      final s = v;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  /// Ratio de contraste entre deux couleurs, de 1 (identiques) a 21.
  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  group('contraste AA (EXI-T09)', () {
    // WCAG AA : 4,5:1 pour le texte courant, 3:1 pour le texte large et les
    // elements d'interface.
    const textAA = 4.5;
    const largeAA = 3.0;

    test('le texte sur fond clair depasse le seuil AA', () {
      expect(
        contrast(AppColors.lightOnSurface, AppColors.lightSurface),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('le texte sur fond sombre depasse le seuil AA', () {
      expect(
        contrast(AppColors.darkOnSurface, AppColors.darkSurface),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('le blanc sur les couleurs d action est lisible', () {
      // Ce sont les boutons qu'un livreur touche a bout de bras, en plein
      // soleil : le seuil « texte large » est le minimum acceptable.
      for (final tone in [
        AppColors.primary,
        AppColors.danger,
        AppColors.accentDark,
      ]) {
        expect(
          contrast(const Color(0xFFFFFFFF), tone),
          greaterThanOrEqualTo(largeAA),
          reason: 'blanc sur $tone',
        );
      }
    });

    test('les couleurs de statut se distinguent du fond', () {
      // Elles ne portent jamais l'information seules — un libelle les double
      // toujours — mais elles doivent rester visibles.
      for (final tone in [
        AppColors.success,
        AppColors.danger,
        AppColors.warning,
        AppColors.info,
      ]) {
        expect(
          contrast(tone, AppColors.lightSurface),
          greaterThan(1.5),
          reason: '$tone sur fond clair',
        );
      }
    });
  });

  group('cibles tactiles (EXI-T09)', () {
    test('la cible minimale atteint 48 dp', () {
      // Recommandation Material et exigence du cahier des charges. En dessous,
      // une main gantee ou mouillee rate le bouton.
      expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(48));
    });

    test('le bouton d action livreur est nettement plus grand', () {
      // §15.3 : un seul bouton, pleine largeur, 64 dp. Il se touche sans
      // regarder.
      expect(AppSizes.driverActionHeight, greaterThanOrEqualTo(64));
      expect(
        AppSizes.driverActionHeight,
        greaterThan(AppSizes.minTouchTarget),
      );
    });

    test('les espacements laissent respirer les cibles voisines', () {
      // Deux boutons colles se touchent l'un pour l'autre.
      expect(AppSpacing.sm, greaterThanOrEqualTo(8));
      expect(AppSpacing.md, greaterThan(AppSpacing.sm));
      expect(AppSpacing.lg, greaterThan(AppSpacing.md));
    });
  });
}
