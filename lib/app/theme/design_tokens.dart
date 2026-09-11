import 'package:flutter/material.dart';

/// Jetons du design system (§15.1).
///
/// Toute valeur d'espacement, de rayon, d'elevation ou de duree utilisee dans
/// l'interface vient d'ici. Aucune constante magique dans les ecrans.
class AppSpacing {
  const AppSpacing._();

  /// Grille de 4 dp (§15.1).
  static const double unit = 4;

  static const double xs = unit; // 4
  static const double sm = unit * 2; // 8
  static const double md = unit * 3; // 12
  static const double lg = unit * 4; // 16
  static const double xl = unit * 6; // 24
  static const double xxl = unit * 8; // 32
  static const double xxxl = unit * 12; // 48

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

class AppRadii {
  const AppRadii._();

  /// 8 dp pour les composants, 16 dp pour les feuilles et cartes (§15.1).
  static const Radius component = Radius.circular(8);
  static const Radius sheet = Radius.circular(16);

  static const BorderRadius componentAll = BorderRadius.all(component);
  static const BorderRadius sheetAll = BorderRadius.all(sheet);
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: sheet,
    topRight: sheet,
  );
}

/// Trois niveaux d'elevation au maximum (§15.1).
class AppElevation {
  const AppElevation._();

  static const double flat = 0;
  static const double raised = 1;
  static const double floating = 3;
  static const double overlay = 6;
}

class AppMotion {
  const AppMotion._();

  /// 150 a 250 ms, courbe standard (§15.1).
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);
  static const Curve curve = Curves.easeInOutCubic;
}

/// Contraintes d'accessibilite (EXI-T09) et de gestuelle livreur (§15.3).
class AppSizes {
  const AppSizes._();

  /// Cible tactile minimale : 48 dp (EXI-T09).
  static const double minTouchTarget = 48;

  /// Bouton de progression livreur : pleine largeur, 64 dp (§15.3).
  static const double driverActionHeight = 64;

  static const double appBarHeight = 56;
  static const double bannerHeight = 32;
  static const double avatarSm = 32;
  static const double avatarMd = 48;
  static const double avatarLg = 72;
}
