import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/network/network_status.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Vrai quand le bandeau occupe reellement la bande systeme.
///
/// La coquille en a besoin : elle retire la marge haute des ecrans enfants en
/// supposant que le bandeau l'a consommee. Quand il se tait, il ne consomme
/// rien, et cette marge doit revenir aux ecrans — sinon leur titre passe sous
/// l'heure et la batterie.
final networkBannerVisibleProvider = Provider<bool>((ref) {
  final value = ref.watch(networkStatusProvider).valueOrNull;
  final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
  return _bannerTrulyOffline(value) || pending > 0;
});

/// Vrai seulement quand l'appareil n'a **aucune** interface reseau et qu'une
/// sonde a deja tranche. On distingue ainsi une vraie coupure (a annoncer) du
/// simple reveil du serveur (connecte, mais pas encore de reponse) : ce dernier
/// reste silencieux — pas de bandeau « Connexion au serveur ».
bool _bannerTrulyOffline(NetworkStatus? value) {
  if (value == null || value.isOnline) return false;
  final firstProbePending = value.lastProbeAt == null;
  final hasTransport = value.transport != NetworkTransport.none;
  return !firstProbePending && !hasTransport;
}

/// Bandeau permanent d'etat reseau (EXI-T06).
///
/// Regle d'interaction §15.2.5 : le mode hors ligne est visible en permanence,
/// jamais decouvert au moment d'un echec. Le bandeau n'est donc pas une
/// notification transitoire mais une bande fixe en haut de chaque ecran.
class McNetworkBanner extends ConsumerWidget {
  const McNetworkBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(networkStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    final value = status.valueOrNull;
    final pendingCount = pending.valueOrNull ?? 0;

    // Le bandeau ne parle que pour deux choses : une **vraie** coupure reseau,
    // ou des elements en attente de synchronisation. Tout le reste — en ligne au
    // repos, ou serveur en cours de reveil (connecte mais pas encore de reponse)
    // — reste silencieux. En particulier, on n'affiche plus « Connexion au
    // serveur » : le reveil d'un hebergement mutualise est invisible, l'utilisateur
    // n'a rien a faire sinon patienter quelques secondes.
    final trulyOffline = _bannerTrulyOffline(value);
    if (!trulyOffline && pendingCount == 0) return const _SilentBanner();

    final String label;
    final Color background;
    final IconData icon;

    if (trulyOffline) {
      background = AppColors.offline;
      icon = Icons.cloud_off_outlined;
      label = pendingCount > 0
          ? l10n.networkOfflinePending(pendingCount)
          : l10n.networkOfflineNoPending;
    } else {
      // Des elements attendent encore d'etre transmis : information utile, a la
      // couleur de la marque, jamais le vert.
      background = AppColors.primary;
      icon = Icons.cloud_upload_outlined;
      label = l10n.networkOfflinePending(pendingCount);
    }

    // Le fond deborde volontairement sous la barre d'etat : le bandeau occupe
    // la bande systeme au lieu de s'y glisser dessous. L'etat reseau reste ainsi
    // lisible en permanence (§15.2.5) sans voler une ligne au contenu, ce qui
    // compte sur les ecrans de 320 dp du parc d'entree de gamme (§4.4).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: background,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.curve,
        color: background,
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSizes.bannerHeight,
            child: Semantics(
              liveRegion: true,
              label: label,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      // Le bandeau vit au-dessus du Navigator, donc hors de
                      // tout Material : sans `decoration: none`, le texte
                      // herite du style de secours de Flutter et s'affiche
                      // souligne en jaune.
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau muet : rien a annoncer, donc rien a l'ecran.
///
/// Il ne prend aucune hauteur, mais garde la main sur la barre d'etat pour que
/// ses icones restent lisibles quel que soit le fond de l'ecran en dessous.
class _SilentBanner extends StatelessWidget {
  const _SilentBanner();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      // Hauteur nulle : l'ecran occupe toute la fenetre et peint lui-meme sous
      // la barre d'etat, comme sur les maquettes ou le bleu monte jusqu'en haut.
      // La coquille lui rend sa marge haute (voir [networkBannerVisibleProvider]).
      child: const SizedBox.shrink(),
    );
  }
}
