import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/features/onboarding/presentation/welcome_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/admin_deliveries_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/disputes_screen.dart'
    hide DisputeDetailScreen;
import 'package:majichrono/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/admin_stats_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/fleet_screen.dart';
import 'package:majichrono/features/admin/presentation/screens/kyc_queue_screen.dart';
import 'package:majichrono/app/shell/role_shell.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/screens/lock_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/auth_choice_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/email_code_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/otp_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/phone_input_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:majichrono/features/auth/presentation/screens/profile_choice_screen.dart';
import 'package:majichrono/features/delivery/presentation/screens/address_book_screen.dart';
import 'package:majichrono/features/delivery/presentation/screens/create_delivery_screen.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/active_delivery_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/driver_deliveries_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/earnings_screen.dart';
import 'package:majichrono/features/profile/presentation/profile_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/kyc_screen.dart';
import 'package:majichrono/features/home/presentation/socle_home_screen.dart';
import 'package:majichrono/features/tracking/presentation/screens/public_tracking_screen.dart';
import 'package:majichrono/features/tracking/presentation/screens/tracking_screen.dart';
import 'package:majichrono/features/settings/presentation/data_usage_screen.dart';
import 'package:majichrono/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:majichrono/features/settings/presentation/pending_sync_screen.dart';
import 'package:majichrono/features/chat/presentation/chat_screen.dart';
import 'package:majichrono/features/profile/presentation/change_password_screen.dart';
import 'package:majichrono/features/profile/presentation/edit_profile_screen.dart';
import 'package:majichrono/features/profile/presentation/forgot_password_screen.dart';
import 'package:majichrono/features/profile/presentation/sessions_screen.dart';
import 'package:majichrono/features/settings/presentation/settings_screen.dart';
import 'package:majichrono/features/support/presentation/help_center_screen.dart';
import 'package:majichrono/features/payment/presentation/screens/wallet_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/vehicle_screen.dart';
import 'package:majichrono/features/driver/presentation/screens/kyc_followup_screen.dart';
import 'package:majichrono/features/chat/presentation/messages_screen.dart';
import 'package:majichrono/features/support/presentation/screens/disputes_list_screen.dart';
import 'package:majichrono/features/support/presentation/screens/dispute_detail_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Duree minimale d'affichage de l'ecran d'attente.
///
/// Un plancher court, mais non nul : sans lui, l'ecran de chargement de marque —
/// le nom et la barre qui se remplit — passerait si vite qu'on ne le verrait
/// jamais, et le premier affichage de l'application sauterait directement au
/// contenu. Ce plancher laisse la barre de chargement s'afficher le temps d'un
/// battement, puis rend la main. La valeur se change ici, en un seul endroit.
const splashMinimumHold = Duration(milliseconds: 1200);

final splashHoldProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(splashMinimumHold);
});

/// Routeur applicatif.
///
/// `go_router` est impose par le §9.1 : les liens profonds sont la seule facon
/// d'ouvrir l'ecran concerne depuis une notification (EXI-N04) et d'honorer le
/// lien de suivi public envoye par SMS (EXI-C24).
final routerProvider = Provider<GoRouter>((ref) {
  // Pont Riverpod -> Listenable : le routeur reevalue ses redirections quand la
  // session change, sans etre reconstruit (ce qui perdrait la pile de navigation).
  final refresh = ValueNotifier<Object?>(null);
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  // Le plancher d'affichage compte aussi comme un changement d'etat : sans cette
  // seconde ecoute, le routeur ne reevaluerait rien a son echeance et l'ecran
  // resterait sur la marque.
  ref.listen(splashHoldProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).valueOrNull;
      final location = state.matchedLocation;

      // Le suivi public est accessible sans compte : le destinataire
      // n'installe rien et n'a pas de session (EXI-C24).
      if (location.startsWith('/track/')) return null;

      // Plancher d'affichage de l'ecran d'attente. Nul aujourd'hui : le logo
      // est porte par l'ecran de demarrage du systeme, en amont.
      if (!ref.watch(splashHoldProvider).hasValue) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Toute la navigation decoule de l'etat de session, et de lui seul. Le
      // filtrage exhaustif garantit qu'un etat ajoute plus tard ne pourra pas
      // etre oublie ici.
      return switch (auth) {
        // Session en cours de relecture : on reste sur l'ecran d'attente.
        null ||
        AuthUnknown() => location == AppRoutes.splash ? null : AppRoutes.splash,

        AuthUnauthenticated() =>
          AppRoutes.isAuthRoute(location) ? null : AppRoutes.welcome,

        // Session ouverte, profil pas encore pose (EXI-T02).
        AuthProfilePending() =>
          location == AppRoutes.authProfile ? null : AppRoutes.authProfile,

        // Verrou local : rien d'autre n'est atteignable (EXI-T04, EXI-SEC07).
        AuthLocked() =>
          location == AppRoutes.authLock ? null : AppRoutes.authLock,

        AuthAuthenticated(:final account) => _redirectForRole(
          account.role,
          location,
        ),
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.authChoice,
        builder: (_, _) => const AuthChoiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.authSignIn,
        builder: (_, _) => const EmailAuthScreen(mode: EmailAuthMode.signIn),
      ),
      GoRoute(
        path: AppRoutes.authSignUp,
        builder: (_, _) => const EmailAuthScreen(mode: EmailAuthMode.signUp),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (_, _) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPhoneSignUp,
        builder: (_, _) => const PhoneInputScreen(isSignUp: true),
      ),
      GoRoute(
        path: AppRoutes.authOtp,
        // Le defi voyage dans `extra`. S'il manque — rebuild du routeur, retour
        // arriere, lien profond direct — on renvoie a la saisie du numero plutot
        // que de planter sur un cast nul.
        redirect: (context, state) =>
            state.extra is OtpChallenge ? null : AppRoutes.authPhone,
        builder: (context, state) =>
            OtpScreen(challenge: state.extra! as OtpChallenge),
      ),
      GoRoute(
        path: AppRoutes.authEmailCode,
        // Meme garde : sans le defi e-mail, on repart du choix d'entree au lieu
        // d'ouvrir un ecran de code qui n'a rien a verifier.
        redirect: (context, state) =>
            state.extra is EmailChallenge ? null : AppRoutes.authChoice,
        builder: (context, state) =>
            EmailCodeScreen(challenge: state.extra! as EmailChallenge),
      ),
      GoRoute(
        path: AppRoutes.authProfile,
        builder: (_, _) => const ProfileChoiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.authLock,
        builder: (context, state) {
          final auth = ProviderScope.containerOf(
            context,
          ).read(authControllerProvider).valueOrNull;
          return auth is AuthLocked
              ? LockScreen(state: auth)
              : const _SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.authPin,
        builder: (context, _) => PinSetupScreen(onDone: () => context.pop()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.authForgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordChange,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessions,
        builder: (_, _) => const SessionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressBook,
        builder: (_, _) => const AddressBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.helpCenter,
        builder: (_, _) => const HelpCenterScreen(),
      ),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletScreen()),
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, _) => const MessagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) =>
            AdminUsersScreen(initialRole: state.uri.queryParameters['role']),
      ),
      GoRoute(
        path: AppRoutes.adminStats,
        builder: (_, _) => const AdminStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverVehicle,
        builder: (_, _) => const VehicleScreen(),
      ),
      GoRoute(
        path: AppRoutes.kycFollowup,
        builder: (_, _) => const KycFollowupScreen(),
      ),
      GoRoute(
        path: AppRoutes.disputes,
        builder: (_, _) => const DisputesListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                DisputeDetailScreen(disputeId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.dataUsage,
        builder: (_, _) => const DataUsageScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingSync,
        builder: (_, _) => const PendingSyncScreen(),
      ),
      GoRoute(
        path: '/chat/:deliveryId',
        builder: (context, state) {
          // L'appelant transmet l'interlocuteur via `extra` : soit un simple
          // titre (compatibilite), soit un couple (titre, telephone) pour
          // offrir aussi l'appel direct.
          final extra = state.extra;
          final (title, phone) = switch (extra) {
            (String? t, String? p) => (t, p),
            final String t => (t, null),
            _ => (null, null),
          };
          return ChatScreen(
            deliveryId: state.pathParameters['deliveryId']!,
            title: title,
            phone: phone,
          );
        },
      ),
      // Ecrans de supervision atteints depuis le tableau de bord (EXI-A03,
      // EXI-A04) : la barre inferieure compte deja quatre onglets.
      GoRoute(
        path: AppRoutes.adminKyc,
        builder: (_, _) => const KycQueueScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDeliveries,
        builder: (_, _) => const AdminDeliveriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.publicTrack,
        builder: (context, state) =>
            PublicTrackingScreen(token: state.pathParameters['token'] ?? ''),
      ),
      _clientShell(),
      _driverShell(),
      _adminShell(),
    ],
  );
});

StatefulShellRoute _clientShell() => StatefulShellRoute.indexedStack(
  builder: (context, state, shell) {
    final l10n = AppLocalizations.of(context);
    return RoleShell(
      navigationShell: shell,
      showNavigationBar: const [
        AppRoutes.clientHome,
        AppRoutes.clientDeliveries,
        AppRoutes.clientMessages,
        AppRoutes.clientProfile,
      ].contains(state.uri.path),
      destinations: [
        ShellDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: l10n.navHome,
        ),
        ShellDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: l10n.navDeliveries,
        ),
        ShellDestination(
          icon: Icons.chat_bubble_outline,
          selectedIcon: Icons.chat_bubble,
          label: l10n.messagesTitle,
        ),
        ShellDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: l10n.navProfile,
        ),
      ],
    );
  },
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.clientHome,
          builder: (_, _) => const SocleHomeScreen(role: UserRole.client),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const CreateDeliveryScreen(),
            ),
            GoRoute(
              path: 'track/:id',
              builder: (context, state) =>
                  TrackingScreen(deliveryId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.clientDeliveries,
          builder: (_, _) => const DeliveriesScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.clientMessages,
          builder: (_, _) => const MessagesScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.clientProfile,
          builder: (context, _) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

StatefulShellRoute _driverShell() => StatefulShellRoute.indexedStack(
  builder: (context, state, shell) {
    final l10n = AppLocalizations.of(context);
    return RoleShell(
      navigationShell: shell,
      showNavigationBar: const [
        AppRoutes.driverHome,
        AppRoutes.driverDeliveries,
        AppRoutes.driverEarnings,
        AppRoutes.driverProfile,
      ].contains(state.uri.path),
      destinations: [
        ShellDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: l10n.navHome,
        ),
        ShellDestination(
          icon: Icons.route_outlined,
          selectedIcon: Icons.route,
          label: l10n.navDeliveries,
        ),
        ShellDestination(
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments,
          label: l10n.navEarnings,
        ),
        ShellDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: l10n.navProfile,
        ),
      ],
    );
  },
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.driverHome,
          builder: (_, _) => const DriverHomeScreen(),
          routes: [
            GoRoute(
              path: 'active/:id',
              builder: (context, state) =>
                  ActiveDeliveryScreen(deliveryId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.driverDeliveries,
          builder: (context, _) => const DriverDeliveriesScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.driverEarnings,
          builder: (_, _) => const EarningsScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.driverProfile,
          builder: (_, _) => const KycScreen(),
        ),
      ],
    ),
  ],
);

StatefulShellRoute _adminShell() => StatefulShellRoute.indexedStack(
  builder: (context, state, shell) {
    final l10n = AppLocalizations.of(context);
    return RoleShell(
      navigationShell: shell,
      showNavigationBar: const [
        AppRoutes.adminHome,
        AppRoutes.adminFleet,
        AppRoutes.adminDisputes,
        AppRoutes.adminProfile,
      ].contains(state.uri.path),
      destinations: [
        ShellDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: l10n.navDashboard,
        ),
        ShellDestination(
          icon: Icons.map_outlined,
          selectedIcon: Icons.map,
          label: l10n.navFleet,
        ),
        ShellDestination(
          icon: Icons.gavel_outlined,
          selectedIcon: Icons.gavel,
          label: l10n.navDisputes,
        ),
        ShellDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: l10n.navProfile,
        ),
      ],
    );
  },
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminHome,
          builder: (_, _) => const AdminDashboardScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminFleet,
          builder: (_, _) => const FleetScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminDisputes,
          builder: (_, _) => const DisputesScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminProfile,
          builder: (context, _) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

/// Cloisonnement des profils : un client ne peut pas atteindre une route
/// livreur, meme par lien profond depuis une notification.
String? _redirectForRole(UserRole role, String location) {
  final home = switch (role) {
    UserRole.client => AppRoutes.clientHome,
    UserRole.driver => AppRoutes.driverHome,
    UserRole.admin => AppRoutes.adminHome,
  };

  // Le parcours d'authentification est termine : y revenir n'a plus de sens,
  // sauf pour la creation du code PIN, qui se fait session ouverte.
  if (location == AppRoutes.splash ||
      (AppRoutes.isAuthRoute(location) && location != AppRoutes.authPin)) {
    return home;
  }

  final isRoleRoute =
      location.startsWith('/client') ||
      location.startsWith('/driver') ||
      location.startsWith('/admin');
  if (isRoleRoute && !location.startsWith('/${role.wireName}')) return home;

  return null;
}

/// Ecran d'attente pendant la relecture de la session.
///
/// **Un simple aplat au bleu de la marque**, qui prolonge l'ecran de lancement
/// Android (le meme bleu, le meme livreur pose par le systeme) sans aucune
/// rupture. On n'y remet **pas** le livreur : le splash natif l'affiche deja, et
/// le redoubler cote Flutter donnait une seconde page — un livreur qui saute de
/// taille puis reapparait. Ici l'attente est invisible : l'ecran ne change pas
/// de couleur entre le splash systeme et l'accueil.
///
/// `Scaffold` et non un simple `ColoredBox` : la route est posee directement
/// sous le Navigator, sans contrainte de taille ; un `ColoredBox` y resterait
/// sans dimension et peindrait noir — erreur qui ne se voit qu'en release.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: AppColors.primary);
}
