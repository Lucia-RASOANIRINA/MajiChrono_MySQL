import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/router/app_router.dart';
import 'package:majichrono/app/theme/app_scroll_behavior.dart';
import 'package:majichrono/app/theme/app_theme.dart';
import 'package:majichrono/core/i18n/locale_controller.dart';
import 'package:majichrono/core/i18n/mg_material_localizations.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/sync/sync_gate.dart';
import 'package:majichrono/features/auth/presentation/widgets/inactivity_lock.dart';
import 'package:majichrono/features/notifications/presentation/delivery_notifications_listener.dart';
import 'package:majichrono/features/notifications/presentation/notification_initializer.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_network_banner.dart';

class MajiChronoApp extends ConsumerWidget {
  const MajiChronoApp({super.key});

  /// Messager racine : la file de synchronisation signale ses conflits
  /// (EXI-S04) sans savoir quel ecran est affiche.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      routerConfig: router,
      // La langue vient du controleur, pas du systeme : la bascule est a chaud
      // et sans redemarrage (EXI-T05).
      locale: locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // Les delegues malgaches passent avant les delegues globaux : Flutter
        // ne traduit pas le malgache, et sans eux les libelles integres du
        // framework tomberaient en anglais (voir mg_material_localizations.dart).
        MgMaterialLocalizationsDelegate(),
        MgWidgetsLocalizationsDelegate(),
        MgCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Supprime le rebond elastique de fin de liste (voir AppScrollBehavior).
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          // Plafonne la mise a l'echelle du texte : au-dela, le bouton de
          // progression livreur (§15.3) cesse de tenir sur un ecran de 320 dp.
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.4,
            ),
          ),
          child: Builder(
            builder: (inner) => NotificationInitializer(
              child: DeliveryNotificationsListener(
                child: SyncGate(
                messengerKey: messengerKey,
                child: InactivityLock(
                  child: Column(
                    children: [
                      // Le bandeau reseau est pose **au-dessus du Navigator**, et non
                      // dans la coquille de role. C'est ce qui rend EXI-T06 tenable au
                      // sens litteral : il survit a tout ecran empile — reglages,
                      // constat, paiement — alors qu'un bandeau porte par la coquille
                      // disparaitrait des le premier `push`. Or c'est precisement
                      // pendant un constat ou un paiement que savoir si le reseau est
                      // tombe change le comportement de l'utilisateur (§15.2.5).
                      const McNetworkBanner(),
                      Expanded(
                        // Le bandeau a deja consomme l'encoche ; sans cela chaque
                        // Scaffold enfant reappliquerait la meme marge. Mais quand
                        // il se tait il ne consomme rien : la marge doit alors
                        // revenir a l'ecran, qui peint lui-meme sous la barre
                        // d'etat.
                        child: Consumer(
                          builder: (context, ref, _) =>
                              MediaQuery.removePadding(
                                context: inner,
                                removeTop: ref.watch(
                                  networkBannerVisibleProvider,
                                ),
                                child: child ?? const SizedBox.shrink(),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }
}
