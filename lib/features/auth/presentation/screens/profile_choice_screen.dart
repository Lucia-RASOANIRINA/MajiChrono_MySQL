import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_patterns.dart';

class ProfileChoiceScreen extends ConsumerStatefulWidget {
  const ProfileChoiceScreen({super.key});

  @override
  ConsumerState<ProfileChoiceScreen> createState() =>
      _ProfileChoiceScreenState();
}

class _ProfileChoiceScreenState extends ConsumerState<ProfileChoiceScreen>
    with TickerProviderStateMixin {
  final TextEditingController _name = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  UserRole? _role;
  bool _busy = false;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuart,
          ),
        );
    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _role;
    final l10n = AppLocalizations.of(context);

    if (role == null || _busy) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.authProfileNameRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Le champ recueille le nom complet ; on le scinde en prenom (premier
      // mot) et nom (le reste). L'ecran « Modifier le profil » permet ensuite
      // d'ajuster chaque partie separement.
      final parts = _name.text.trim().split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      await ref
          .read(authControllerProvider.notifier)
          .chooseProfile(role: role, firstName: firstName, lastName: lastName);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Fond dégradé
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
          ),

          // Icônes de fond
          _ProfileBackgroundIcons(),

          // Motif technique
          Positioned.fill(
            child: CustomPaint(
              painter: TechPatternPainter(
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // En-tête (sans bouton de retour)
                        _ProfileHeader(
                          title: l10n.authProfileTitle,
                          subtitle: l10n.authProfileSubtitle,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Modal blanc
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Cartes de choix
                              _ProfileCard(
                                role: UserRole.client,
                                title: l10n.roleClient,
                                description: l10n.roleClientDesc,
                                selected: _role == UserRole.client,
                                onTap: () => setState(() {
                                  _role = UserRole.client;
                                  _error = null;
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _ProfileCard(
                                role: UserRole.driver,
                                title: l10n.roleDriver,
                                description: l10n.roleDriverDesc,
                                selected: _role == UserRole.driver,
                                onTap: () => setState(() {
                                  _role = UserRole.driver;
                                  _error = null;
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),


                              // Champ Nom
                              TextField(
                                controller: _name,
                                focusNode: _focusNode,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.authProfileName,
                                  hintText: l10n.authProfileNameHint,
                                  labelStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  hintStyle: const TextStyle(fontSize: 16),
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _submit(),
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade700,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),

                              // Bouton "Confirmer"
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _role == null || _busy
                                      ? null
                                      : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              l10n.commonConfirm,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),

                        // Icônes de confiance
                        const SizedBox(height: AppSpacing.sm),
                        _TrustIcons(),

                        // Camion de livraison animé
                        const SizedBox(height: AppSpacing.md),
                        _MovingTruck(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CAMION DE LIVRAISON ANIMÉ
// ============================================================

class _MovingTruck extends StatefulWidget {
  const _MovingTruck();

  @override
  State<_MovingTruck> createState() => _MovingTruckState();
}

class _MovingTruckState extends State<_MovingTruck>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _positionAnimation = Tween<double>(begin: -0.3, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 0.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: 55,
          child: Stack(
            children: [
              // Ligne de route
              Positioned(
                bottom: 8,
                left: 20,
                right: 20,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),

              // Camion qui se déplace
              Positioned(
                left:
                    MediaQuery.of(context).size.width *
                        _positionAnimation.value -
                    45,
                bottom: 8 + _bounceAnimation.value * 6,
                child: Transform.rotate(
                  angle: _bounceAnimation.value * 0.03,
                  child: const Icon(
                    Icons.local_shipping,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),

              // Traînée lumineuse derrière le camion
              Positioned(
                left:
                    MediaQuery.of(context).size.width *
                        _positionAnimation.value -
                    65,
                bottom: 12 + _bounceAnimation.value * 6,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      radius: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// CARTE DE CHOIX DE PROFIL
// ============================================================

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.role,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                role.icon,
                size: 28,
                color: selected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected
                          ? AppColors.primary
                          : Colors.grey.shade800,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : Colors.grey.shade300,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EN-TÊTE
// ============================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_outline, size: 44, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ICÔNES DE CONFIANCE
// ============================================================

class _TrustIcons extends StatelessWidget {
  const _TrustIcons();

  @override
  Widget build(BuildContext context) {
    return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrustIcon(icon: Icons.shield, size: 24),
            const SizedBox(width: AppSpacing.sm),
            _TrustIcon(icon: Icons.lock_outline, size: 22),
            const SizedBox(width: AppSpacing.sm),
            _TrustIcon(icon: Icons.verified, size: 24),
            const SizedBox(width: AppSpacing.sm),
            _TrustIcon(icon: Icons.security, size: 24),
          ],
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut);
  }
}

class _TrustIcon extends StatelessWidget {
  const _TrustIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: size),
    );
  }
}

// ============================================================
// ICÔNES DE FOND
// ============================================================

class _ProfileBackgroundIcons extends StatelessWidget {
  const _ProfileBackgroundIcons();

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.person_outline,
      Icons.people_outline,
      Icons.person_add_outlined,
      Icons.badge_outlined,
      Icons.account_circle_outlined,
    ];

    final positions = [
      (0.04, 0.04, 45, 0),
      (0.86, 0.06, 35, 1),
      (0.10, 0.28, 30, 2),
      (0.80, 0.32, 40, 3),
      (0.04, 0.55, 38, 4),
      (0.92, 0.58, 28, 0),
      (0.08, 0.78, 34, 1),
      (0.84, 0.80, 30, 2),
      (0.48, 0.12, 24, 3),
      (0.96, 0.90, 40, 4),
      (0.02, 0.92, 26, 0),
      (0.42, 0.88, 24, 1),
      (0.72, 0.46, 22, 2),
      (0.28, 0.70, 32, 3),
      (0.58, 0.28, 22, 4),
    ];

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: positions.map((pos) {
              final x = pos.$1 * constraints.maxWidth;
              final y = pos.$2 * constraints.maxHeight;
              final size = pos.$3.toDouble();
              final iconIndex = pos.$4;
              final iconData = icons[iconIndex % icons.length];

              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: 0.04 + (size / 200),
                  child: Icon(iconData, size: size, color: Colors.white),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
