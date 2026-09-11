import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/simulated_google_accounts.dart';
import 'package:majichrono/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/repositories/auth_repository.dart';
import 'package:majichrono/features/auth/domain/services/device_google_accounts.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_controller.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';

final localAuthProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(apiClientProvider)),
);

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSource(ref.watch(secureStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);

  final repository = AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
    onAccessTokenChanged: (token) =>
        ref.read(accessTokenProvider.notifier).state = token,
  );

  // Bouclage differe : le client a besoin du repository pour rafraichir, et le
  // repository a besoin du client pour appeler `/auth/refresh`.
  client.attachRefreshHandler(() async {
    final session = await repository.refresh();
    return session.accessToken;
  });

  return repository;
});

/// Source des comptes Google de l'appareil.
///
/// En mode `mock`, la source simulee deroule le parcours complet. En mode
/// `live`, elle est neutre — aucun compte, donc aucun bouton — tant que
/// l'identifiant client OAuth de MajiChrono n'est pas cree. **C'est ici, et
/// nulle part ailleurs, qu'on branchera `google_sign_in` le jour venu.**
final deviceGoogleAccountsProvider = Provider<DeviceGoogleAccounts>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.isMock
      ? const SimulatedGoogleAccounts()
      : const NoGoogleAccounts();
});

/// Comptes detectes, ou liste vide.
///
/// L'ecran de saisie du numero l'observe pour decider s'il dessine le bouton
/// Google. Tant que la detection n'a pas repondu, il n'affiche rien : un bouton
/// qui apparait en retard est moins genant qu'un bouton qui disparait.
final googleAccountHintsProvider = FutureProvider<List<GoogleAccountHint>>((
  ref,
) async {
  final source = ref.watch(deviceGoogleAccountsProvider);
  if (!await source.isAvailable()) return const [];
  return source.detect();
});

/// Adresse verifiee qui attend un numero pour etre rattachee.
///
/// Elle nait quand un code e-mail est valide sans qu'aucun compte n'y soit
/// rattache, et meurt des que la session s'ouvre par le numero. En memoire
/// seulement : une adresse verifiee il y a trois jours n'a plus rien prouve.
final pendingEmailLinkProvider = StateProvider<String?>((ref) => null);

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Profil actif, derive du compte authentifie.
///
/// Au module 0 il etait choisi a la main et persiste en preferences. Il est
/// desormais une **consequence** de la session : un profil ne peut plus etre
/// change en vidant une preference locale, ce qui aurait donne acces aux ecrans
/// d'un autre role sans que le serveur n'en sache rien.
final activeRoleProvider = Provider<UserRole?>((ref) {
  final auth = ref.watch(authControllerProvider).valueOrNull;
  return switch (auth) {
    AuthAuthenticated(:final account) => account.role,
    AuthLocked(:final account) => account.role,
    _ => null,
  };
});
