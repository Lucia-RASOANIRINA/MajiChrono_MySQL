import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/i18n/locale_controller.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/auth_branding.dart';
import 'package:majichrono/features/auth/presentation/widgets/google_account_sheet.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

enum EmailAuthMode { signIn, signUp }

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({required this.mode, super.key});

  final EmailAuthMode mode;

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');
  static const int minPasswordLength = 8;

  bool get _isSignUp => widget.mode == EmailAuthMode.signUp;

  @override
  void initState() {
    super.initState();

    final beginOffset = _isSignUp
        ? const Offset(0, 0.08)
        : const Offset(0, -0.08);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(begin: beginOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuart,
          ),
        );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(EmailAuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _animationController.reset();

      final beginOffset = _isSignUp
          ? const Offset(0, 0.08)
          : const Offset(0, -0.08);

      _slideAnimation = Tween<Offset>(begin: beginOffset, end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutQuart,
            ),
          );

      _animationController.forward();

      setState(() {
        _error = null;
        _password.clear();
        _confirm.clear();
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (!_emailPattern.hasMatch(_email.text.trim())) return false;
    if (_password.text.length < minPasswordLength) return false;
    if (_isSignUp && _confirm.text != _password.text) return false;
    return true;
  }

  Future<void> _submit() async {
    if (_busy || !_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context);
    final repository = ref.read(authRepositoryProvider);

    try {
      final result = _isSignUp
          ? await repository.signUpWithPassword(
              email: _email.text.trim(),
              password: _password.text,
            )
          : await repository.signInWithPassword(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (!mounted) return;
      await _handle(result);
    } on UnauthorizedFailure {
      if (!mounted) return;
      setState(() => _error = l10n.authBadCredentials);
    } on ConflictFailure {
      if (!mounted) return;
      setState(() => _error = l10n.authEmailTaken);
    } on ValidationFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = failure.details?['minLength'] != null
            ? l10n.authPasswordTooShort
            : failure.localizedMessage(l10n),
      );
    } on ServerFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = failure.code == 'mail_delivery_failed'
            ? "Le service e-mail n'est pas configure. Ajoutez les parametres SMTP dans DirectAdmin."
            : failure.localizedMessage(l10n),
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handle(EmailVerification result) async {
    switch (result) {
      case EmailLinked(:final verification):
        await ref
            .read(authControllerProvider.notifier)
            .onOtpVerified(verification);
      case EmailUnlinked(:final email):
        // Apres une **inscription**, on prouve d'abord la possession de la boite
        // par un code e-mail : c'est le sens du parcours par adresse. Le numero
        // ne vient qu'ensuite, depuis l'ecran de code (panneau « compte a
        // completer »). A la connexion, en revanche, une adresse sans compte
        // mene directement au numero — il n'y a pas d'adresse a prouver.
        if (_isSignUp) {
          final l10n = AppLocalizations.of(context);
          try {
            final challenge = await ref
                .read(authRepositoryProvider)
                .requestEmailCode(email);
            if (mounted) {
              unawaited(
                context.push(AppRoutes.authEmailCode, extra: challenge),
              );
            }
          } on Failure catch (failure) {
            if (mounted) {
              setState(() => _error = failure.localizedMessage(l10n));
            }
          }
        } else {
          ref.read(pendingEmailLinkProvider.notifier).state = email;
          if (mounted) unawaited(context.push(AppRoutes.authPhone));
        }
    }
  }

  Future<void> _social(SocialProvider provider) async {
    final email = await showGoogleAccountSheet(context, provider: provider);
    if (email == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestEmailCode(email);
      if (!mounted) return;
      unawaited(context.push(AppRoutes.authEmailCode, extra: challenge));
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = failure.localizedMessage(AppLocalizations.of(context)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    if (_isSignUp) {
      context.pop();
    } else {
      context.push(AppRoutes.authSignUp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);

    final title = _isSignUp ? l10n.authSignUpTitle : l10n.authSignInTitle;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Le bleu reste réservé à l'en-tête pour garder la saisie lumineuse.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: const ColoredBox(color: AppColors.primary),
          ),
          const Positioned(
            top: 104,
            right: -18,
            child: _EmailBlueAccent(),
          ),
          Positioned(
            top: 0,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => context.go(AppRoutes.authChoice),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                        // En-tête
                        _EmailHeader(title: title),
                        const SizedBox(height: AppSpacing.md),

                        // Modal blanc : sa hauteur suit son contenu (le champ de
                        // confirmation n'apparait qu'a l'inscription), au lieu
                        // d'une hauteur fixe qui deborde sur les petits ecrans.
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(32),
                                bottom: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Sélecteur de langue
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SegmentedButton<String>(
                                    segments: [
                                      ButtonSegment(
                                        value: 'fr',
                                        label: Text(
                                          l10n.langFrench,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      ButtonSegment(
                                        value: 'mg',
                                        label: Text(
                                          l10n.langMalagasy,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                    selected: {locale.languageCode},
                                    showSelectedIcon: false,
                                    style: SegmentedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      selectedBackgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      selectedForegroundColor:
                                          AppColors.primary,
                                      foregroundColor: Colors.grey.shade500,
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                    ),
                                    onSelectionChanged: (selection) => ref
                                        .read(localeProvider.notifier)
                                        .set(
                                          AppLocales.fromCode(selection.first),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Champ Email
                                TextField(
                                  controller: _email,
                                  autofocus: true,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.deny(
                                      RegExp(r'\s'),
                                    ),
                                  ],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.authFieldEmail,
                                    hintText: 'exemple@email.com',
                                    labelStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    hintStyle: const TextStyle(fontSize: 16),
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                    errorText:
                                        _email.text.isNotEmpty &&
                                            !_emailPattern.hasMatch(
                                              _email.text.trim(),
                                            )
                                        ? l10n.authGoogleEmailInvalid
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  onSubmitted: (_) {
                                    if (_password.text.isNotEmpty) {
                                      _submit();
                                    } else {
                                      FocusScope.of(context).nextFocus();
                                    }
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Champ Mot de passe
                                TextField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: _isSignUp
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.authFieldPassword,
                                    hintText: '••••••••',
                                    labelStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    hintStyle: const TextStyle(fontSize: 16),
                                    prefixIcon: Icon(
                                      Icons.lock_outlined,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey.shade500,
                                        size: 22,
                                      ),
                                    ),
                                    errorText:
                                        _password.text.isNotEmpty &&
                                            _password.text.length <
                                                minPasswordLength
                                        ? l10n.authPasswordTooShort
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  onSubmitted: (_) {
                                    if (_isSignUp) {
                                      FocusScope.of(context).nextFocus();
                                    } else {
                                      _submit();
                                    }
                                  },
                                ),

                                // Champ Confirmation (signup uniquement)
                                if (_isSignUp) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  TextField(
                                    controller: _confirm,
                                    obscureText: _obscure,
                                    keyboardType: TextInputType.visiblePassword,
                                    textInputAction: TextInputAction.done,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: l10n.authFieldPasswordConfirm,
                                      hintText: '••••••••',
                                      labelStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      hintStyle: const TextStyle(fontSize: 16),
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                      errorText:
                                          _confirm.text.isNotEmpty &&
                                              _confirm.text != _password.text
                                          ? l10n.authPasswordMismatch
                                          : null,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
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
                                    onChanged: (_) =>
                                        setState(() => _error = null),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ],
                                if (!_isSignUp)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push(
                                        AppRoutes.authForgotPassword,
                                      ),
                                      child: Text(l10n.passwordForgot),
                                    ),
                                  ),

                                // Message d'erreur
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(10),
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

                                // Bouton principal
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _canSubmit && !_busy
                                        ? _submit
                                        : null,
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
                                        : Text(
                                            _isSignUp
                                                ? l10n.authSignUp
                                                : l10n.authSignIn,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),

                                // Séparateur
                                const SizedBox(height: AppSpacing.md),
                                _BuildDivider(
                                  text: _isSignUp
                                      ? l10n.authOrSignUpWith
                                      : l10n.authOrSignInWith,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Boutons sociaux
                                _SocialButtons(
                                  onGooglePressed: _busy
                                      ? null
                                      : () => _social(SocialProvider.google),
                                  onFacebookPressed: _busy
                                      ? null
                                      : () => _social(SocialProvider.facebook),
                                  onTwitterPressed: _busy
                                      ? null
                                      : () => _social(SocialProvider.twitter),
                                ),

                                const SizedBox(height: AppSpacing.sm),

                                // Lien basculer entre connexion et inscription
                                _ToggleSection(
                                  isSignUp: _isSignUp,
                                  onToggle: _toggleMode,
                                  l10n: l10n,
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),

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

class _EmailBlueAccent extends StatelessWidget {
  const _EmailBlueAccent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.11),
                width: 1.5,
              ),
            ),
          ),
          Icon(
            Icons.alternate_email_rounded,
            size: 42,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION BASCULE CONNEXION / INSCRIPTION
// ============================================================

class _ToggleSection extends StatelessWidget {
  const _ToggleSection({
    required this.isSignUp,
    required this.onToggle,
    required this.l10n,
    required this.theme,
  });

  final bool isSignUp;
  final VoidCallback onToggle;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSignUp ? l10n.authHaveAccount : l10n.authNoAccount,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(
                isSignUp ? l10n.authSignIn : l10n.authSignUp,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// MOTO EN MOUVEMENT
// ============================================================

class _MovingMotorcycle extends StatefulWidget {
  const _MovingMotorcycle();

  @override
  State<_MovingMotorcycle> createState() => _MovingMotorcycleState();
}

class _MovingMotorcycleState extends State<_MovingMotorcycle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _positionAnimation = Tween<double>(begin: -0.3, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 0.5).animate(
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
          height: 50,
          child: Stack(
            children: [
              Positioned(
                bottom: 6,
                left: 20,
                right: 20,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              Positioned(
                left:
                    MediaQuery.of(context).size.width *
                        _positionAnimation.value -
                    35,
                bottom: 6 + _bounceAnimation.value * 6,
                child: Transform.rotate(
                  angle: _bounceAnimation.value * 0.04,
                  child: const Icon(
                    Icons.two_wheeler,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left:
                    MediaQuery.of(context).size.width *
                        _positionAnimation.value -
                    50,
                bottom: 10 + _bounceAnimation.value * 6,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
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
// BOUTONS SOCIAUX
// ============================================================

class _SocialButtons extends StatelessWidget {
  const _SocialButtons({
    required this.onGooglePressed,
    required this.onFacebookPressed,
    required this.onTwitterPressed,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final VoidCallback? onTwitterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          icon: Icons.g_mobiledata,
          label: 'Google',
          color: const Color(0xFF4285F4),
          onPressed: onGooglePressed,
        ),
        const SizedBox(width: AppSpacing.sm),
        _SocialButton(
          icon: Icons.facebook,
          label: 'Facebook',
          color: const Color(0xFF1877F2),
          onPressed: onFacebookPressed,
        ),
        const SizedBox(width: AppSpacing.sm),
        _SocialButton(
          icon: Icons.alternate_email,
          label: 'X',
          color: const Color(0xFF1DA1F2),
          onPressed: onTwitterPressed,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EN-TÊTE
// ============================================================

class _EmailHeader extends StatelessWidget {
  const _EmailHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.email_outlined, size: 44, color: Colors.white),
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
      ],
    );
  }
}

// ============================================================
// SEPARATEUR
// ============================================================

class _BuildDivider extends StatelessWidget {
  const _BuildDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
      ],
    );
  }
}
