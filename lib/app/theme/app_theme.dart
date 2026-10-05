import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Construction des themes clair et sombre a partir des jetons (§15.1).
///
/// Refonte : les couleurs de la charte MajiChrono (bleu profond, ambre) sur
/// des formes modernisees — action principale en pilule bleue, cartes plates
/// arrondies a 24 dp, champs pleins sans contour au repos. Un ecran reste
/// lisible au premier coup d'oeil : l'action a toucher est la seule pilule
/// pleine.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.lightScheme);
  static ThemeData dark() => _build(AppColors.darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    // Fond ardoise : les cartes blanches arrondies s'en detachent, ce qu'un
    // fond presque blanc ne permettait pas.
    final background = isLight
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final cardColor = isLight ? Colors.white : const Color(0xFF1E293B);
    final fieldColor = isLight
        ? AppColors.lightSurfaceAlt
        : AppColors.darkSurfaceAlt;

    // Echelle typographique a 6 niveaux, base 16 sp, jamais moins de 14 sp
    // (§15.1). Titres serres : plus de mots par ligne sur un ecran de 5 pouces.
    final text = base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: -0.2,
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
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    // Pilule bleue de la charte : l'action principale, partout la meme.
    final primaryAction = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(AppSizes.primaryActionHeight),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      ),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? fieldColor : scheme.primary,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onSurfaceVariant
            : scheme.onPrimary,
      ),
      overlayColor: WidgetStatePropertyAll(
        scheme.onPrimary.withValues(alpha: 0.10),
      ),
    );

    return base.copyWith(
      // Transitions d'ecran : un fondu, et rien d'autre. Sur un telephone
      // d'entree de gamme, glisser et zoomer se joue a saccades ; un fondu de
      // meme duree parait instantane.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      iconTheme: IconThemeData(color: scheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        scrolledUnderElevation: AppElevation.flat,
        centerTitle: false,
        toolbarHeight: AppSizes.appBarHeight,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardAll,
          side: BorderSide(
            color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryAction),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryAction),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.primaryActionHeight),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: AppElevation.floating,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.componentAll,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
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
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        actionTextColor: AppColors.accent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.componentAll,
        ),
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: cardColor,
        selectedColor: scheme.primary,
        secondaryLabelStyle: text.bodyMedium?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: scheme.onPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : fieldColor,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

/// Fondu simple entre deux ecrans.
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
