import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/profile/presentation/avatar_image.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/shared/widgets/mc_patterns.dart';

/// Ecran de profil, partage par l'expediteur et l'exploitation.
///
/// Les deux profils voient la meme chose : qui je suis, comment on me joint,
/// comment mon telephone est protege, et comment je pars. Ce qui differe d'un
/// role a l'autre — la note pour un livreur, le dossier KYC — est porte par les
/// ecrans du role, pas par celui-ci.
///
/// Le livreur, lui, a son propre ecran : son profil est domine par l'etat de son
/// dossier (EXI-L02), qui n'a pas d'equivalent chez les autres.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: auth.when(
        loading: () => const Center(child: McLoader()),
        error: (_, _) => Center(child: Text(l10n.errorUnknown)),
        data: (state) => switch (state) {
          AuthAuthenticated(:final account) => _Body(account: account),
          AuthLocked(:final account) => _Body(account: account),
          // Sans session, le routeur a deja renvoye ailleurs : cet etat n'est
          // atteignable qu'une image avant la redirection.
          _ => const Center(child: McLoader()),
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // L'adresse du compte, ou celle qui attend d'y etre rattachee — la seconde
    // n'existe qu'entre la verification de la boite mail et la confirmation du
    // numero, et il serait deroutant de ne rien montrer pendant ce temps-la.
    final linkedEmail = account.email ?? ref.watch(pendingEmailLinkProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(
          account: account,
          roleLabel: _roleLabel(l10n, account.role),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Section(title: l10n.profileAccount),
              _Tile(
                icon: Icons.badge_outlined,
                title: _roleLabel(l10n, account.role),
                subtitle: l10n.profileMemberSince(_month(account.createdAt)),
              ),
              _Tile(
                icon: Icons.alternate_email,
                title: linkedEmail ?? l10n.profileEmailNone,
                subtitle: linkedEmail == null ? null : l10n.profileEmailLinked,
              ),
              _Tile(
                icon: Icons.edit_outlined,
                title: l10n.profileEdit,
                subtitle: l10n.profilePersonalInfo,
                onTap: () => context.push(AppRoutes.profileEdit),
              ),

              const SizedBox(height: AppSpacing.lg),
              _Section(title: l10n.profileSecurity),
              FutureBuilder<bool>(
                future: ref.read(authRepositoryProvider).hasPin(),
                builder: (context, snapshot) {
                  final hasPin = snapshot.data ?? false;
                  return _Tile(
                    icon: hasPin
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    title: hasPin ? l10n.profilePinOn : l10n.profilePinOff,
                    subtitle: hasPin
                        ? l10n.profilePinChange
                        : l10n.profilePinSet,
                    onTap: () => context.push(AppRoutes.authPin),
                  );
                },
              ),
              _Tile(
                icon: Icons.password_outlined,
                title: l10n.passwordManage,
                onTap: () => context.push(AppRoutes.passwordChange),
              ),
              _Tile(
                icon: Icons.settings_outlined,
                title: l10n.settingsTitle,
                onTap: () => context.push(AppRoutes.settings),
              ),

              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context, ref),
                icon: const Icon(Icons.logout),
                label: Text(l10n.authSignOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
    UserRole.client => l10n.roleClient,
    UserRole.driver => l10n.roleDriver,
    UserRole.admin => l10n.roleAdmin,
  };

  /// Mois et annee suffisent : le jour exact d'inscription n'apprend rien, et
  /// une date complete invite a la comparer a celle du voisin.
  String _month(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authSignOut),
        // La deconnexion efface les donnees locales (EXI-SEC10). Sur un parcours
        // hors ligne, cela peut emporter des constats pas encore synchronises :
        // l'utilisateur doit le savoir avant, pas apres.
        content: Text(l10n.authSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.authSignOut),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// En-tete de profil : un bandeau bleu de la charte, avatar centre, nom et
/// role. Il reprend le langage des dashboards (bleu + trame technique) pour que
/// le profil appartienne visiblement a la meme application.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account, required this.roleLabel});

  final UserAccount account;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final initial = account.displayName.isEmpty
        ? '?'
        : account.displayName.substring(0, 1).toUpperCase();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: AppRadii.sheet),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.primary),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: TechPatternPainter(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: AppSizes.avatarLg / 2,
                        backgroundColor: Colors.white,
                        foregroundImage: avatarImage(account.avatarUrl),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    account.displayName.isEmpty
                        ? roleLabel
                        : account.displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // Numero complet : c'est son telephone. Le masque (EXI-T10)
                    // protege l'autre partie, pas soi-meme. Un compte cree par
                    // e-mail seul n'en a pas encore : on affiche l'adresse a
                    // la place.
                    '$roleLabel · ${account.phone?.displayNational ?? account.email ?? l10n.profilePhoneNone}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  if (account.rating != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          account.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (account.role == UserRole.driver) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 17),
                          SizedBox(width: 6),
                          Text(
                            'Profil verifie',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xs),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
        ),
      ),
    );
  }
}

/// Carte de reglage dans le langage du home : surface arrondie a 20, bordure
/// discrete, icone posee dans un carre teinte de la couleur de marque.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? const Color(0xFF60A5FA) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.10 : 0.04,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.16 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
