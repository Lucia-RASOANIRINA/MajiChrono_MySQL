import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_patterns.dart';

class EmailCodeScreen extends ConsumerStatefulWidget {
  const EmailCodeScreen({required this.challenge, super.key});

  final EmailChallenge challenge;

  @override
  ConsumerState<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends ConsumerState<EmailCodeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late EmailChallenge _challenge = widget.challenge;
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _busy = false;
  String? _error;
  String? _unlinked;
  bool _registerBusy = false;
  String? _registerError;
  OtpVerification? _createdVerification;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _startTicker();

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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    // Focus automatique après un court délai
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
        // Forcer l'affichage du clavier
        FocusScope.of(context).requestFocus(_focusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _startTicker() {
    _remaining = _challenge.remaining;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _challenge.remaining);
      if (_remaining == Duration.zero) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _controller.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(
            challengeId: _challenge.challengeId,
            code: _controller.text,
          );

      switch (result) {
        case EmailLinked(:final verification):
          await ref
              .read(authControllerProvider.notifier)
              .onOtpVerified(verification);
        case EmailUnlinked(:final email):
          ref.read(pendingEmailLinkProvider.notifier).state = email;
          _ticker?.cancel();
          if (mounted) {
            setState(() {
              _unlinked = email;
              _registerBusy = true;
            });
          }
          try {
            final verification = await ref
                .read(authRepositoryProvider)
                .registerWithEmail(_challenge.challengeId);
            if (mounted) {
              setState(() {
                _createdVerification = verification;
                _registerBusy = false;
              });
            }
          } on Failure catch (failure) {
            if (mounted) {
              setState(() {
                _registerBusy = false;
                _registerError = failure.localizedMessage(l10n);
              });
            }
          }
      }
    } on ValidationFailure catch (failure) {
      if (!mounted) return;
      final left = failure.details?['attemptsLeft'] as int?;
      setState(() {
        _controller.clear();
        _error = left != null && left > 0
            ? l10n.authOtpInvalid(left)
            : l10n.authOtpLocked;
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cree un compte a partir de l'e-mail deja prouve, sans passer par le
  /// numero (bouton "Creer mon compte avec cet e-mail" de [_UnlinkedPanel]).
  Future<void> _registerWithEmail() async {
    final verification = _createdVerification;
    if (_registerBusy || verification == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .onOtpVerified(verification);
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fresh = await ref
          .read(authRepositoryProvider)
          .requestEmailCode(_challenge.email);
      if (!mounted) return;
      setState(() {
        _challenge = fresh;
        _controller.clear();
      });
      _startTicker();
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = failure.localizedMessage(AppLocalizations.of(context)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _formattedRemaining {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_unlinked != null) {
      return _UnlinkedPanel(
        email: _unlinked!,
        busy: _registerBusy,
        created: _createdVerification != null,
        error: _registerError,
        onRegister: _registerWithEmail,
      );
    }

    final expired = _remaining == Duration.zero;

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
          _EmailCodeBackgroundIcons(),

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
                        // Flèche retour vers EmailAuthScreen
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () {
                              context.go(AppRoutes.authSignIn);
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),

                        // En-tête
                        _EmailCodeHeader(
                          title: l10n.authEmailCodeTitle,
                          email: _challenge.email,
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
                              // Message d'envoi
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.send_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        l10n.authEmailCodeSentTo(
                                          _challenge.email,
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),

                              // Hint
                              Text(
                                l10n.authEmailCodeHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Timer
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: expired
                                      ? Colors.red.shade50
                                      : AppColors.primary.withValues(
                                          alpha: 0.06,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: expired
                                        ? Colors.red.shade200
                                        : AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Icon(
                                          expired
                                              ? Icons.timer_off_outlined
                                              : Icons.timer_outlined,
                                          color: expired
                                              ? Colors.red.shade400
                                              : AppColors.primary,
                                          size: 20,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      expired
                                          ? l10n.authOtpExpired
                                          : l10n.authOtpExpiresIn(
                                              _formattedRemaining,
                                            ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: expired
                                                ? Colors.red.shade600
                                                : AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              // Champ de saisie du code avec curseur visible
                              _CodeInputField(
                                controller: _controller,
                                focusNode: _focusNode,
                                cursorController: _cursorController,
                                enabled: !expired,
                                onChanged: (value) {
                                  setState(() => _error = null);
                                  if (value.length == 6) _verify();
                                },
                                theme: theme,
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

                              // Bouton "Renvoyer"
                              Center(
                                child: TextButton.icon(
                                  onPressed: _busy ? null : _resend,
                                  icon: Icon(
                                    Icons.refresh,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  label: Text(
                                    l10n.authOtpResend,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              // Bouton "Continuer"
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      expired ||
                                          _busy ||
                                          _controller.text.length != 6
                                      ? null
                                      : _verify,
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
                                              l10n.commonContinue,
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
// CHAMP DE SAISIE DU CODE AVEC CURSEUR VISIBLE (CORRIGÉ)
// ============================================================

class _CodeInputField extends StatefulWidget {
  const _CodeInputField({
    required this.controller,
    required this.focusNode,
    required this.cursorController,
    required this.enabled,
    required this.onChanged,
    required this.theme,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AnimationController cursorController;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ThemeData theme;

  @override
  State<_CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<_CodeInputField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;
    final textLength = widget.controller.text.length;

    return Stack(
      children: [
        // TextField invisible pour la saisie réelle
        Opacity(
          opacity: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (value) {
                setState(() {});
                widget.onChanged(value);
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '',
              ),
            ),
          ),
        ),
        // Interface visuelle des cases
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.focusNode.requestFocus();
            // Forcer l'ouverture du clavier
            FocusScope.of(context).requestFocus(widget.focusNode);
            // Forcer le clavier à s'afficher (important sur certains appareils)
            SystemChannels.textInput.invokeMethod('TextInput.show');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final hasValue = textLength > index;
                final isActive = isFocused && textLength == index;
                final isFilled = hasValue;

                Color borderColor;
                double borderWidth;
                Color? backgroundColor;

                if (isFilled) {
                  borderColor = AppColors.primary;
                  borderWidth = 2;
                  backgroundColor = AppColors.primary.withValues(alpha: 0.04);
                } else if (isActive) {
                  borderColor = AppColors.primary;
                  borderWidth = 2.5;
                  backgroundColor = AppColors.primary.withValues(alpha: 0.06);
                } else {
                  borderColor = Colors.grey.shade200;
                  borderWidth = 1;
                  backgroundColor = const Color(0xFFF8FAFC);
                }

                return Container(
                  width: 44,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Chiffre
                        Text(
                          hasValue ? widget.controller.text[index] : '',
                          style: widget.theme.textTheme.displaySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),
                        // Curseur clignotant (uniquement sur la case active)
                        if (isActive)
                          AnimatedBuilder(
                            animation: widget.cursorController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: widget.cursorController.value,
                                child: Container(
                                  width: 2.5,
                                  height: 28,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PANEL COMPTE INCONNU
// ============================================================

class _UnlinkedPanel extends StatelessWidget {
  const _UnlinkedPanel({
    required this.email,
    required this.busy,
    required this.created,
    required this.error,
    required this.onRegister,
  });

  final String email;
  final bool busy;
  final bool created;
  final String? error;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
          ),
          _EmailCodeBackgroundIcons(),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.go(AppRoutes.authSignIn),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 26,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          created
                              ? l10n.authEmailCreatedTitle
                              : l10n.authEmailUnlinkedTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          created
                              ? l10n.authEmailCreatedBody
                              : l10n.authEmailUnlinkedBody(email),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        if (error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],

                        if (created) ...[
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: busy
                                  ? null
                                  : () => context.go(AppRoutes.authPhone),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                l10n.authEmailAddPhoneAction,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: busy ? null : onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    created
                                        ? l10n.authEmailContinueAction
                                        : l10n.authEmailRegisterAction,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Option secondaire : rattacher plutot un compte
                        // telephone deja existant.
                        if (!created)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => context.go(AppRoutes.authPhone),
                            child: Text(
                              l10n.authEmailUnlinkedAction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
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
// EN-TÊTE
// ============================================================

class _EmailCodeHeader extends StatelessWidget {
  const _EmailCodeHeader({required this.title, required this.email});

  final String title;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 44, color: Colors.white),
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
          email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
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

class _EmailCodeBackgroundIcons extends StatelessWidget {
  const _EmailCodeBackgroundIcons();

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.two_wheeler,
      Icons.local_shipping,
      Icons.location_on_outlined,
      Icons.delivery_dining,
      Icons.storefront_outlined,
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
