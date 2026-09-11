import 'package:flutter/material.dart';

/// Palette MajiChrono.
///
/// Elle sera remplacee par les valeurs exactes de `BRAND.md` du projet existant
/// (§15.1) ; la structure des roles, elle, ne changera pas. Les couleurs de
/// statut sont deliberement doublees d'une icone partout dans l'interface, pour
/// rester lisibles en plein soleil et pour les daltonismes (EXI-T09).
class AppColors {
  const AppColors._();

  // --- Marque ----------------------------------------------------------
  /// Bleu profond : fiabilite, lisible sur ecran bas de gamme en exterieur.
  // Bleu profond de la charte MajiChrono. Il remplace le turquoise initial :
  // c'est la couleur des maquettes validees, et celle de l'icone de lanceur.
  static const Color primary = Color(0xFF1E2A78);
  static const Color primaryLight = Color(0xFF2F6BE4);
  static const Color primaryDark = Color(0xFF141C52);

  /// Ambre : action, urgence utile, contraste fort sur le bleu.
  static const Color accent = Color(0xFFF4A62A);
  static const Color accentDark = Color(0xFFC97E11);

  // --- Statuts ---------------------------------------------------------
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED8B00);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);
  static const Color neutral = Color(0xFF5F6B76);

  /// Hors ligne : gris ardoise, jamais rouge — le hors ligne est un mode
  /// nominal du produit (§4.1), pas une panne.
  static const Color offline = Color(0xFF455A64);

  // --- Surfaces claires ------------------------------------------------
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF2F5);
  static const Color lightOutline = Color(0xFFD3D9DF);
  static const Color lightOnSurface = Color(0xFF12181D);
  static const Color lightOnSurfaceMuted = Color(0xFF5B6670);

  // --- Surfaces sombres ------------------------------------------------
  static const Color darkBackground = Color(0xFF0E1418);
  static const Color darkSurface = Color(0xFF161E24);
  static const Color darkSurfaceAlt = Color(0xFF1F2A32);
  static const Color darkOutline = Color(0xFF33424C);
  static const Color darkOnSurface = Color(0xFFE8EDF1);
  static const Color darkOnSurfaceMuted = Color(0xFF9AA7B2);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCE3FA),
    onPrimaryContainer: primaryDark,
    secondary: accent,
    onSecondary: Color(0xFF3A2600),
    secondaryContainer: Color(0xFFFCE8C4),
    onSecondaryContainer: Color(0xFF4A3000),
    tertiary: info,
    onTertiary: Colors.white,
    error: danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFADBDB),
    onErrorContainer: Color(0xFF5F1414),
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceAlt,
    onSurfaceVariant: lightOnSurfaceMuted,
    outline: lightOutline,
    outlineVariant: Color(0xFFE4E9ED),
    shadow: Color(0x1A000000),
    scrim: Color(0x99000000),
    inverseSurface: darkSurface,
    onInverseSurface: darkOnSurface,
    inversePrimary: primaryLight,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6FB6D4),
    onPrimary: Color(0xFF00293C),
    primaryContainer: Color(0xFF0B4F6C),
    onPrimaryContainer: Color(0xFFD3E7F0),
    secondary: Color(0xFFF7BC5E),
    onSecondary: Color(0xFF3A2600),
    secondaryContainer: Color(0xFF6B4A00),
    onSecondaryContainer: Color(0xFFFCE8C4),
    tertiary: Color(0xFF7EC5F0),
    onTertiary: Color(0xFF00344C),
    error: Color(0xFFEF9A9A),
    onError: Color(0xFF5F1414),
    errorContainer: Color(0xFF8C2020),
    onErrorContainer: Color(0xFFFADBDB),
    surface: darkSurface,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceAlt,
    onSurfaceVariant: darkOnSurfaceMuted,
    outline: darkOutline,
    outlineVariant: Color(0xFF27343D),
    shadow: Color(0x66000000),
    scrim: Color(0xCC000000),
    inverseSurface: lightSurface,
    onInverseSurface: lightOnSurface,
    inversePrimary: primary,
  );
}
