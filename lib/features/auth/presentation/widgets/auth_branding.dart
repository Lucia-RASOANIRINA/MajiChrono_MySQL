import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Fournisseur d'identite propose a cote du mot de passe.
///
/// Les trois sont traites de la meme facon : ils ne servent qu'a **designer une
/// adresse**, jamais a ouvrir une session par eux-memes. La session s'ouvre au
/// code recu dans la boite mail. C'est ce qui permet de les livrer tous les
/// trois sans dependre de trois SDK differents, et ce qui fera que le jour ou
/// les vrais SDK arriveront, seul le port de detection changera.
enum SocialProvider {
  google,
  facebook,
  twitter;

  String label(AppLocalizations l10n) => switch (this) {
    SocialProvider.google => l10n.authSocialGoogle,
    SocialProvider.facebook => l10n.authSocialFacebook,
    SocialProvider.twitter => l10n.authSocialTwitter,
  };
}

/// Bandeau superieur des ecrans d'identite, repris de la maquette.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.two_wheeler, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.authBannerFast,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pied de page a deux lignes de la maquette : une promesse, une precision.
class AuthFooterBadge extends StatelessWidget {
  const AuthFooterBadge({
    required this.icon,
    required this.title,
    required this.note,
    super.key,
  });

  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rangee des trois entrees sociales, en pastilles carrees comme la maquette.
class SocialRow extends StatelessWidget {
  const SocialRow({required this.onPick, this.busy = false, super.key});

  final void Function(SocialProvider provider) onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final provider in SocialProvider.values) ...[
          _SocialButton(
            provider: provider,
            label: provider.label(l10n),
            onPressed: busy ? null : () => onPick(provider),
          ),
          if (provider != SocialProvider.values.last)
            const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.label,
    required this.onPressed,
  });

  final SocialProvider provider;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        // 96 x 56 : au-dela de la cible tactile minimale de 48 dp, parce que
        // ces boutons sont touches gants aux mains sur une moto a l'arret.
        width: 96,
        height: AppSizes.minTouchTarget + 8,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.componentAll),
          ),
          child: SocialMark(provider: provider),
        ),
      ),
    );
  }
}

/// Marque d'un fournisseur.
///
/// Aucun logo officiel n'est reproduit : ceux de Google, Meta et X sont des
/// marques deposees dont l'usage impose l'asset fourni par leur proprietaire,
/// jamais un dessin approchant. Les assets officiels seront poses en meme temps
/// que les identifiants OAuth correspondants, dans le meme lot. D'ici la, une
/// marque neutre aux couleurs du fournisseur annonce l'origine du bouton sans
/// pretendre etre la sienne.
class SocialMark extends StatelessWidget {
  const SocialMark({required this.provider, this.size = 22, super.key});

  final SocialProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) => switch (provider) {
    SocialProvider.google => SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleMarkPainter()),
    ),
    SocialProvider.facebook => Icon(
      Icons.facebook,
      size: size + 4,
      color: const Color(0xFF1877F2),
    ),
    SocialProvider.twitter => Icon(
      Icons.alternate_email,
      size: size + 2,
      color: const Color(0xFF1D9BF0),
    ),
  };
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const List<Color> _sectors = [
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.18;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    const sweep = 1.4;
    for (var i = 0; i < _sectors.length; i++) {
      paint.color = _sectors[i];
      canvas.drawArc(rect, -1.4 + i * 1.5708, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}

/// Coquille commune des ecrans d'identite.
///
/// Elle apporte trois choses que chaque ecran refaisait a sa facon : le panneau
/// bleu, un titre pose au meme endroit, et **une fleche de retour**.
///
/// Cette fleche n'est pas un ornement. Depuis le choix de la porte d'entree, un
/// utilisateur qui touche « avec mon numero » puis se ravise n'avait aucun moyen
/// de revenir : le geste systeme fonctionnait, le bouton n'existait pas. Sur un
/// telephone d'entree de gamme sans navigation gestuelle, c'etait une impasse.
class McAuthScaffold extends StatelessWidget {
  const McAuthScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.footer,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Retour personnalise. Par defaut, on depile ; si la pile est vide — cas
  /// d'une arrivee par lien profond — on renvoie au choix plutot que de laisser
  /// un bouton inerte.
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.primary),
          ),
          SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: AppSizes.minTouchTarget,
                    child: Row(
                      children: [
                        if (showBack)
                          IconButton(
                            onPressed: onBack ?? () => _goBack(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                          ),
                      ],
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Icon(
                      Icons.delivery_dining_rounded,
                      size: 52,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // Le contenu vit sur une feuille claire arrondie : le contraste
                  // avec le fond sombre delimite ou l'on saisit, ce qu'un ecran
                  // entierement bleu ne faisait pas.
                  Expanded(
                    child: _RiseIn(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl,
                          0,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  ?footer,
                ],
              ),
          ),
        ],
      ),
    );
  }

  static void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // Pile vide : on ne laisse pas un bouton sans effet.
    GoRouter.of(context).go(AppRoutes.authChoice);
  }
}

/// Entree par le bas de la feuille de saisie.
///
/// Trois cent cinquante millisecondes, une seule fois, sans boucle. La feuille
/// monte et se revele : le mouvement dit d'ou vient l'ecran, ce qui rend le
/// retour en arriere evident sans qu'aucun texte ne l'explique.
///
/// L'animation est retiree quand le systeme demande la suppression des effets
/// (EXI-T09) — elle est un confort, jamais un passage oblige.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child});

  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}
