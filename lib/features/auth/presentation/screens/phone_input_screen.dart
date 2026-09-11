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
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/auth_branding.dart';
import 'package:majichrono/features/auth/presentation/widgets/google_account_sheet.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({this.isSignUp = false, super.key});

  final bool isSignUp;

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  MalagasyPhone? _phone;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _phone = MalagasyPhone.tryParse(value);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final phone = _phone;
    if (phone == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.isSignUp) {
        final challenge = await ref
            .read(authRepositoryProvider)
            .requestOtp(phone);
        if (!mounted) return;
        unawaited(context.push(AppRoutes.authOtp, extra: challenge));
        return;
      }

      final result = await ref
          .read(authRepositoryProvider)
          .loginWithPhone(
            phone: phone,
            password: _passwordController.text.trim().isEmpty
                ? null
                : _passwordController.text,
          );
      if (!mounted) return;
      switch (result) {
        case PhoneOtpRequired(:final challenge):
          unawaited(context.push(AppRoutes.authOtp, extra: challenge));
        case PhonePasswordVerified(:final verification):
          await ref
              .read(authControllerProvider.notifier)
              .onOtpVerified(verification);
      }
    } on ConflictFailure catch (failure) {
      if (!mounted) return;
      if (failure.details?['code'] == 'password_required' ||
          _passwordController.text.isEmpty) {
        setState(() => _error = 'Ce compte utilise un mot de passe.');
      }
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = failure.localizedMessage(AppLocalizations.of(context)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    final email = await showGoogleAccountSheet(context);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final operator = _phone?.operator;

    final googleAccounts =
        ref.watch(googleAccountHintsProvider).valueOrNull ?? const [];

    final isFrench = locale.languageCode == 'fr';
    final termsText = isFrench
        ? 'En continuant, vous acceptez nos conditions générales'
        : 'Amin\'ny fanohizana dia ekenao ny fepetra fampiasana';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 408,
            child: const ColoredBox(color: AppColors.primary),
          ),
          const Positioned(
            top: 104,
            right: -18,
            child: _PhoneBlueAccent(),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête
                    _CompactHeader(
                      title: l10n.authPhoneTitle,
                      subtitle: l10n.authPhoneSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Modal blanc
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.isSignUp
                                ? l10n.authSignUp
                                : l10n.authSignIn,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                                selectedForegroundColor: AppColors.primary,
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
                                  .set(AppLocales.fromCode(selection.first)),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),

                          // Champ téléphone
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d +().-]'),
                              ),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.authPhoneLabel,
                              hintText: '034 00 000 01',
                              labelStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              hintStyle: const TextStyle(fontSize: 18),
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              errorText:
                                  _controller.text.isNotEmpty && _phone == null
                                  ? (MalagasyPhone.isUnknownOperator(
                                          _controller.text,
                                        )
                                        ? l10n.authPhoneUnknownOperator
                                        : l10n.authPhoneInvalid)
                                  : null,
                              helperText: switch (operator) {
                                null => null,
                                MobileOperator.unknown => null,
                                MobileOperator.telmaFixe => l10n.authPhoneNoSms,
                                final known => l10n.authPhoneOperator(
                                  known.label,
                                ),
                              },
                              helperMaxLines: 1,
                              errorMaxLines: 1,
                              helperStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              errorStyle: const TextStyle(fontSize: 13),
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
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: _onChanged,
                            onSubmitted: (_) => _submit(),
                          ),
                          if (!widget.isSignUp) ...[
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe (si vous en avez un)',
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 15,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: AppColors.primary,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Afficher le mot de passe'
                                      : 'Masquer le mot de passe',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.62,
                                    ),
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryLight,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.xs),
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

                          // Bouton Continuer
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _phone == null || _busy
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFE2E6ED),
                                disabledForegroundColor: const Color(0xFF64748B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.go(
                                        widget.isSignUp
                                            ? AppRoutes.authPhone
                                            : AppRoutes.authPhoneSignUp,
                                      ),
                              child: Text(
                                widget.isSignUp
                                    ? l10n.authAlreadyAccount
                                    : '${l10n.authNoAccount} ${l10n.authSignUp}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                          // Séparateur et Google
                          if (googleAccounts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            _BuildDivider(text: l10n.authOrSeparator),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _continueWithGoogle,
                                icon: const SocialMark(
                                  provider: SocialProvider.google,
                                  size: 20,
                                ),
                                label: Text(
                                  l10n.authGoogleContinue,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),

                          // Mention légale - plus claire et visible
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                termsText,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _PhoneBlueAccent extends StatelessWidget {
  const _PhoneBlueAccent();

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
            Icons.local_shipping_outlined,
            size: 42,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EN-TÊTE
// ============================================================

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 26,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            height: 1.35,
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
