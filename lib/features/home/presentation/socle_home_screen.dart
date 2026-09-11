import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/chat/presentation/chat_providers.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_center_provider.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

class SocleHomeScreen extends ConsumerWidget {
  const SocleHomeScreen({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(networkStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final online = status.valueOrNull?.isOnline ?? false;
    final deliveries = ref.watch(deliveriesProvider).valueOrNull ?? [];

    final fallbackTitle = switch (role) {
      UserRole.client => l10n.clientHomeTitle,
      UserRole.driver => l10n.driverHomeTitle,
      UserRole.admin => l10n.adminHomeTitle,
    };
    final name = _accountName(ref);
    final greeting = name != null ? l10n.authWelcome(name) : fallbackTitle;

    final statusLabel = online
        ? l10n.networkOnline
        : (pending > 0
              ? l10n.networkOfflinePending(pending)
              : l10n.networkOfflineNoPending);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Flottant Bleu
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverCustomHeaderDelegate(
              greeting: greeting,
              subtitle: _timeGreetingText(),
              timeIcon: _timeGreetingIcon(),
              statusLabel: statusLabel,
              statusOnline: online,
              pendingCount: pending,
              onSettings: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.settings);
              },
            ),
          ),

          // Contenu Principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // Carte de Statistiques
                  _EnhancedStatsCard(
                    online: online,
                    pending: pending,
                    deliveriesCount: deliveries.length,
                    onDeliveries: () => context.go(AppRoutes.clientDeliveries),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),

                  if (role == UserRole.client) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _WalletBalanceCard()
                        .animate()
                        .fade(delay: 80.ms)
                        .slideY(begin: 0.1, end: 0),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Actions Rapides
                  Text(
                    'Actions rapides',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ).animate().fade(delay: 100.ms),

                  const SizedBox(height: AppSpacing.sm),

                  _QuickActionsGrid(
                    onNewDelivery: () =>
                        context.push(AppRoutes.clientNewDelivery),
                    onDeliveries: () => context.go(AppRoutes.clientDeliveries),
                    onDataUsage: () => context.push(AppRoutes.dataUsage),
                    onSync: () => context.push(AppRoutes.pendingSync),
                  ).animate().fade(delay: 150.ms).slideY(begin: 0.1, end: 0),

                  if (role == UserRole.client)
                    const _FavoritesStrip().animate().fade(delay: 180.ms),

                  const SizedBox(height: AppSpacing.xl),

                  // Section des courses
                  McSectionHeader(
                    title: l10n.navDeliveries,
                    actionLabel: l10n.commonSeeAll,
                    onAction: () => context.go(AppRoutes.clientDeliveries),
                  ).animate().fade(delay: 200.ms),

                  const SizedBox(height: AppSpacing.sm),

                  if (role == UserRole.client)
                    const _ClientDeliveries()
                        .animate()
                        .fade(delay: 250.ms)
                        .slideY(begin: 0.05, end: 0)
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: McEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: l10n.emptyDeliveries,
                        message: l10n.shellModuleWipDesc('4'),
                      ),
                    ).animate().fade(delay: 250.ms),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  IconData _timeGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.waving_hand_rounded;
    if (hour < 18) return Icons.wb_sunny_rounded;
    return Icons.nightlight_round;
  }

  String? _accountName(WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    return switch (auth) {
      AuthAuthenticated(:final account) => account.displayName,
      AuthLocked(:final account) => account.displayName,
      _ => null,
    };
  }
}

// ============================================================
// EN-TÊTE PERSONNALISÉ
// ============================================================

class _SliverCustomHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SliverCustomHeaderDelegate({
    required this.greeting,
    required this.subtitle,
    required this.timeIcon,
    required this.statusLabel,
    required this.statusOnline,
    required this.pendingCount,
    this.onSettings,
  });

  final String greeting;
  final String subtitle;
  final IconData timeIcon;
  final String statusLabel;
  final bool statusOnline;
  final int pendingCount;
  final VoidCallback? onSettings;

  @override
  double get minExtent => 140.0;

  @override
  double get maxExtent => 200.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final percent = shrinkOffset / maxExtent;
    final isCompact = percent > 0.4;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: isCompact ? 11 : 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              timeIcon,
                              size: isCompact ? 12 : 14,
                              color: const Color(0xFF93C5FD),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: 200.ms,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          child: Text(
                            greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const _HeaderMessages(),
                      const SizedBox(width: 8),
                      const _HeaderBell(),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.settings_outlined,
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                ],
              ),
              if (!isCompact) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: 300.ms,
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusOnline
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFFF87171),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (statusOnline
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFFF87171))
                                      .withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }

  @override
  bool shouldRebuild(covariant _SliverCustomHeaderDelegate oldDelegate) {
    return greeting != oldDelegate.greeting ||
        subtitle != oldDelegate.subtitle ||
        timeIcon != oldDelegate.timeIcon ||
        statusLabel != oldDelegate.statusLabel ||
        statusOnline != oldDelegate.statusOnline ||
        pendingCount != oldDelegate.pendingCount;
  }
}

/// Acces a l'espace « Messages », avec la pastille des conversations non lues.
///
/// Elle lit elle-meme le total des non-lus (somme des conversations) : l'accueil
/// n'a rien a lui transmettre. Sans donnee encore chargee, l'icone reste nue.
class _HeaderMessages extends ConsumerWidget {
  const _HeaderMessages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (items) => items.fold<int>(0, (sum, c) => sum + c.unread),
          orElse: () => 0,
        );
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: _HeaderIconButton(
        icon: Icons.forum_outlined,
        onPressed: () => context.push(AppRoutes.messages),
      ),
    );
  }
}

/// Cloche du centre de notifications, avec sa pastille de non-lus.
///
/// Elle est autonome : elle lit elle-meme le compteur, de sorte qu'aucun ecran
/// d'accueil n'a a le lui transmettre. La pastille disparait quand tout est lu.
class _HeaderBell extends ConsumerWidget {
  const _HeaderBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: _HeaderIconButton(
        icon: Icons.notifications_none_rounded,
        onPressed: () => context.push(AppRoutes.notifications),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFFEAF2FF), size: 22),
      ),
    );
  }
}

// ============================================================
// CARTE DE STATISTIQUES ENRICHIE
// ============================================================

class _EnhancedStatsCard extends StatelessWidget {
  const _EnhancedStatsCard({
    required this.online,
    required this.pending,
    required this.deliveriesCount,
    required this.onDeliveries,
  });

  final bool online;
  final int pending;
  final int deliveriesCount;
  final VoidCallback onDeliveries;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);

    return InkWell(
      onTap: onDeliveries,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_shipping_outlined,
                value: '$deliveriesCount',
                label: 'Courses',
                color: iconColor,
              ),
            ),
            _buildDivider(isDark),
            Expanded(
              child: _StatTile(
                icon: online ? Icons.wifi : Icons.wifi_off_rounded,
                value: online ? 'En ligne' : 'Hors-ligne',
                label: 'Réseau',
                color: online
                    ? iconColor
                    : (isDark
                          ? const Color(0xFFFB7185)
                          : const Color(0xFFBE123C)),
              ),
            ),
            _buildDivider(isDark),
            Expanded(
              child: _StatTile(
                icon: Icons.sync_rounded,
                value: pending > 0 ? '$pending à synchro' : 'À jour',
                label: 'Données',
                color: pending > 0
                    ? (isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFB45309))
                    : iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 36,
      width: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GRILLE D'ACTIONS RAPIDES
// ============================================================

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onNewDelivery,
    required this.onDeliveries,
    required this.onDataUsage,
    required this.onSync,
  });

  final VoidCallback onNewDelivery;
  final VoidCallback onDeliveries;
  final VoidCallback onDataUsage;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: compact ? 1.15 : 1.32,
          children: [
            _ModernActionCard(
              title: 'Nouvelle course',
              subtitle: 'Commander un coursier',
              icon: Icons.add_circle_outline_rounded,
              accentColor: AppColors.primary,
              onTap: onNewDelivery,
            ),
            _ModernActionCard(
              title: 'Mes courses',
              subtitle: 'Suivre mes colis',
              icon: Icons.inventory_2_outlined,
              accentColor: AppColors.primary,
              onTap: onDeliveries,
            ),
            _ModernActionCard(
              title: 'Données',
              subtitle: 'Utilisation & Stockage',
              icon: Icons.pie_chart_outline_rounded,
              accentColor: AppColors.primary,
              onTap: onDataUsage,
            ),
            _ModernActionCard(
              title: 'Synchronisation',
              subtitle: 'Gérer le hors-ligne',
              icon: Icons.cloud_sync_outlined,
              accentColor: AppColors.primary,
              onTap: onSync,
            ),
          ],
        );
      },
    );
  }
}

class _ModernActionCard extends StatefulWidget {
  const _ModernActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_ModernActionCard> createState() => _ModernActionCardState();
}

class _ModernActionCardState extends State<_ModernActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: 100.ms,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(
                  alpha: isDark ? 0.05 : 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, size: 22, color: iconColor),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF64748B),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFFB6C3D6)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SOLDE MAJIPAY (§1, EXI-C39)
// ============================================================

/// Carte de solde MajiPay sur l'accueil client, raccourci vers le portefeuille.
///
/// Le solde est lu a l'ouverture, jamais mis en cache : un montant perime
/// afficherait une somme fausse au moment ou l'utilisateur compte dessus. Un
/// solde indisponible (reseau coupe) se dit sobrement, il ne bloque rien.
class _WalletBalanceCard extends ConsumerWidget {
  const _WalletBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balance = ref.watch(majiPayBalanceProvider(UserRole.client));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.wallet);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.walletBalanceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  balance.when(
                    // Placeholder statique, jamais un indicateur qui tourne : sur
                    // l'accueil, un solde qui charge (voire ne repond pas, hors
                    // ligne) ne doit pas animer en boucle — ce serait du bruit, et
                    // cela empecherait tout `pumpAndSettle` de se stabiliser.
                    loading: () => Text(
                      '—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    error: (_, _) => Text(
                      l10n.payBalanceUnavailable,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    data: (value) => Text(
                      value == null
                          ? l10n.payBalanceUnavailable
                          : formatAriary(value.availableAriary),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADRESSES FAVORITES (§1, EXI-C05)
// ============================================================

/// Bandeau d'acces rapide aux adresses enregistrees (§1).
///
/// Absent quand le carnet est vide : un bandeau vide n'apprend rien. Chaque
/// puce ouvre le carnet, d'ou le tunnel de creation sait deja piocher une
/// adresse. On priorise domicile et travail, puis les plus utilisees.
class _FavoritesStrip extends ConsumerWidget {
  const _FavoritesStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressBookProvider).valueOrNull ?? const [];
    if (addresses.isEmpty) return const SizedBox.shrink();

    final sorted = [...addresses]
      ..sort((a, b) {
        int rank(AddressKind k) => switch (k) {
          AddressKind.home => 0,
          AddressKind.work => 1,
          AddressKind.favorite => 2,
          AddressKind.other => 3,
        };
        final byKind = rank(a.kind).compareTo(rank(b.kind));
        if (byKind != 0) return byKind;
        return b.useCount.compareTo(a.useCount);
      });
    final visible = sorted.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        McSectionHeader(
          title: l10n.addrBookTitle,
          actionLabel: l10n.commonSeeAll,
          onAction: () => context.push(AppRoutes.addressBook),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final saved = visible[index];
              return ActionChip(
                avatar: Icon(_kindIcon(saved.kind), size: 18),
                label: Text(saved.label),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.addressBook);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _kindIcon(AddressKind kind) => switch (kind) {
    AddressKind.home => Icons.home_outlined,
    AddressKind.work => Icons.work_outline,
    AddressKind.favorite => Icons.star_outline,
    AddressKind.other => Icons.place_outlined,
  };
}

// ============================================================
// APERÇU DES COURSES
// ============================================================

class _ClientDeliveries extends ConsumerWidget {
  const _ClientDeliveries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deliveries = ref.watch(deliveriesProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (deliveries == null) {
      return const SizedBox(height: 200, child: McSkeletonList(itemCount: 2));
    }

    if (deliveries.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: McEmptyState(
          icon: Icons.inventory_2_outlined,
          title: l10n.emptyDeliveries,
          message: l10n.addrBookEmptyHelp,
          actionLabel: l10n.emptyDeliveriesAction,
          onAction: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.clientNewDelivery);
          },
        ),
      );
    }

    final visible = deliveries.take(3).toList();
    return Column(
      children: [
        for (final delivery in visible) ...[
          DeliveryCard(delivery: delivery),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.clientNewDelivery);
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              l10n.clientNewDelivery,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
