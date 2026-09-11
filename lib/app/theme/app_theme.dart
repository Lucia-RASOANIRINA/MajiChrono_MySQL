import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Construction des themes clair et sombre a partir des jetons (§15.1).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.lightScheme);
  static ThemeData dark() => _build(AppColors.darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    // Echelle typographique a 6 niveaux, base 16 sp, jamais moins de 14 sp (§15.1).
    final text = base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          labelLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      // Transitions d'ecran : un fondu, et rien d'autre.
      //
      // Le defaut de Material 3 fait glisser **et** zoomer la page entrante,
      // sur trois cents millisecondes. Sur un telephone d'entree de gamme, ce
      // mouvement se joue a saccades et se lit comme une lenteur, alors qu'un
      // fondu de meme duree parait instantane : l'oeil n'a rien a suivre. C'est
      // le meme raisonnement que pour l'accueil — ce qui bouge retient
      // l'attention, et l'attention est ici du temps percu.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
        },
      ),
      // Fond ardoise repris du home de l'expediteur : les cartes blanches
      // arrondies s'en detachent, ce qu'un fond presque blanc ne permettait
      // pas. Le meme choix vaut pour tous les ecrans, hors espace d'identite
      // qui pose son propre fond bleu.
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF0F172A),
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        // La barre se fond dans le fond ardoise plutot que de poser une bande
        // blanche : c'est le langage du home, ou l'en-tete et le contenu
        // partagent la meme surface.
        backgroundColor: isLight
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        scrolledUnderElevation: AppElevation.flat,
        centerTitle: false,
        toolbarHeight: AppSizes.appBarHeight,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      // Cartes dans le langage du home : rayon 20, une bordure discrete au lieu
      // d'une ombre portee, surface franche. Un composant partout coherent —
      // accueil, profil, reglages, supervision — sans retoucher chaque ecran.
      cardTheme: CardThemeData(
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.componentAll,
          ),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.componentAll,
          ),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.lightSurfaceAlt
            : AppColors.darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.componentAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: AppElevation.raised,
        backgroundColor: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Iconographie systematiquement doublee d'un libelle (§15.1).
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.componentAll,
        ),
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.componentAll,
        ),
        labelStyle: text.bodyMedium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

/// Fondu simple entre deux ecrans.
///
/// La courbe demarre vite et finit doucement : la page entrante est deja
/// lisible a mi-parcours, ce qui raccourcit l'attente ressentie sans raccourcir
/// l'animation — la raccourcir davantage produirait un a-coup.
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    child: child,
  );
}
