import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/i18n/locale_controller.dart';
import 'package:majichrono/features/auth/data/device_lock.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/auth_branding.dart';
import 'package:majichrono/features/auth/presentation/widgets/google_account_sheet.dart';
import 'package:majichrono/features/auth/presentation/widgets/phone_field.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Entree par numero : connexion ou inscription, **sans SMS**.
///
/// La preuve est le verrouillage du telephone lui-meme — code, schema,
/// empreinte ou visage, ce que l'utilisateur utilise deja. A l'inscription, le
/// telephone cree une cle secrete, la garde dans son stockage securise et la
/// confie au serveur ; se connecter, c'est deverrouiller le telephone pour
/// presenter cette cle.
///
/// Le mot de passe reste un secours : obligatoire si le telephone n'a aucun
/// verrouillage, facultatif sinon, et demande une fois sur un nouveau
/// telephone, qui est ensuite reconnu.
class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({this.isSignUp = false, super.key});

  final bool isSignUp;

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  MalagasyPhone? _phone;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// Le message d'erreur invite a basculer vers l'autre mode (inscription <->
  /// connexion) : on affiche alors le lien en evidence.
  bool _suggestSwitch = false;

  /// Le telephone a un verrouillage configure (nul tant qu'on ne sait pas).
  bool? _lockAvailable;

  /// Cle d'appareil deja enregistree sur ce telephone pour le numero saisi.
  String? _deviceKey;

  /// Mot de passe de secours deplie a l'inscription.
  bool _wantsBackupPassword = false;

  @override
  void initState() {
    super.initState();
    unawaited(_probeLock());
  }

  Future<void> _probeLock() async {
    final available = await ref.read(deviceLockProvider).isAvailable();
    if (mounted) setState(() => _lockAvailable = available);
  }

  Future<void> _onPhone(MalagasyPhone? phone) async {
    setState(() {
      _phone = phone;
      _error = null;
      _deviceKey = null;
    });
    if (phone == null || widget.isSignUp) return;
    final key = await ref.read(deviceKeyStoreProvider).secretFor(phone.e164);
    if (mounted && _phone == phone) setState(() => _deviceKey = key);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _useLock => _lockAvailable ?? false;

  /// Champs de mot de passe visibles : secours deplie, telephone sans
  /// verrouillage, ou connexion depuis un telephone pas encore reconnu.
  bool get _showPassword => widget.isSignUp
      ? (!_useLock || _wantsBackupPassword)
      : (!_useLock || _deviceKey == null);

  bool get _passwordRequired =>
      widget.isSignUp ? !_useLock : _showPassword;

  bool get _canSubmit {
    if (_phone == null || _busy || _lockAvailable == null) return false;
    if (widget.isSignUp) {
      final typed = _password.text.isNotEmpty || _confirm.text.isNotEmpty;
      if (_passwordRequired || typed) {
        return _password.text.length >= 8 && _confirm.text == _password.text;
      }
      return true;
    }
    return !_showPassword || _password.text.isNotEmpty;
  }

  Future<void> _submit() async {
    final phone = _phone;
    if (phone == null || !_canSubmit) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _busy = true;
      _error = null;
      _suggestSwitch = false;
    });
    try {
      if (widget.isSignUp) {
        await _signUp(phone, l10n);
      } else {
        await _signIn(phone, l10n);
      }
    } on Failure catch (failure) {
      if (!mounted) return;
      if (failure is UnauthorizedFailure &&
          failure.code == 'device_not_recognized') {
        // Cle revoquee ou compte recree ailleurs : on l'oublie et l'on passe
        // au mot de passe de secours.
        await ref.read(deviceKeyStoreProvider).forget(phone.e164);
        setState(() {
          _deviceKey = null;
          _error = l10n.authDeviceNotRecognized;
        });
        return;
      }
      final (message, suggestSwitch) = switch (failure) {
        ServerFailure(code: 'phone_not_registered') => (
          l10n.authPhoneNotRegistered,
          true,
        ),
        ConflictFailure(code: 'phone_taken') => (l10n.authPhoneTaken, true),
        ConflictFailure(code: 'password_not_set') => (
          l10n.authPhonePasswordNotSet,
          false,
        ),
        UnauthorizedFailure() => (l10n.authPhoneBadCredentials, false),
        ValidationFailure() when widget.isSignUp => (
          l10n.authPasswordTooShort,
          false,
        ),
        _ => (failure.localizedMessage(l10n), false),
      };
      setState(() {
        _error = message;
        _suggestSwitch = suggestSwitch;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Inscription : le verrouillage du telephone tient lieu de code SMS.
  Future<void> _signUp(MalagasyPhone phone, AppLocalizations l10n) async {
    final keys = ref.read(deviceKeyStoreProvider);
    final password = _password.text.isEmpty ? null : _password.text;
    String? secret;
    if (_useLock) {
      final ok = await ref
          .read(deviceLockProvider)
          .confirm(reason: l10n.authDeviceLockReasonSignUp);
      if (!ok) {
        if (mounted) setState(() => _error = l10n.authDeviceLockCancelled);
        return;
      }
      secret = await keys.createFor(phone.e164);
    }
    try {
      final verification = await ref
          .read(authRepositoryProvider)
          .registerWithPhone(
            phone: phone,
            password: password,
            deviceSecret: secret,
          );
      await ref.read(authControllerProvider.notifier).onOtpVerified(verification);
    } on Failure {
      // Compte non cree : la cle ne doit pas laisser croire le contraire.
      if (secret != null) await keys.forget(phone.e164);
      rethrow;
    }
  }

  /// Connexion : deverrouillage du telephone si la cle est la, sinon mot de
  /// passe de secours, apres quoi ce telephone est reconnu.
  Future<void> _signIn(MalagasyPhone phone, AppLocalizations l10n) async {
    final repository = ref.read(authRepositoryProvider);
    final PhoneLoginResult result;
    final key = _deviceKey;
    if (_useLock && key != null) {
      final ok = await ref
          .read(deviceLockProvider)
          .confirm(reason: l10n.authDeviceLockReasonSignIn);
      if (!ok) {
        if (mounted) setState(() => _error = l10n.authDeviceLockCancelled);
        return;
      }
      result = await repository.loginWithPhone(phone: phone, deviceSecret: key);
    } else {
      result = await repository.loginWithPhone(
        phone: phone,
        password: _password.text,
      );
      if (result is PhonePasswordVerified && _useLock) {
        await _rememberThisPhone(phone);
      }
    }
    switch (result) {
      case PhonePasswordVerified(:final verification):
        await ref
            .read(authControllerProvider.notifier)
            .onOtpVerified(verification);
      case PhoneOtpRequired(:final challenge):
        if (mounted) {
          unawaited(context.push(AppRoutes.authOtp, extra: challenge));
        }
    }
  }

  /// Lie ce telephone au compte apres une entree par mot de passe : la
  /// prochaine fois, son verrouillage suffira. Un echec n'empeche pas
  /// d'entrer — le mot de passe sera simplement redemande.
  Future<void> _rememberThisPhone(MalagasyPhone phone) async {
    final keys = ref.read(deviceKeyStoreProvider);
    try {
      final secret = await keys.createFor(phone.e164);
      await ref.read(authRepositoryProvider).enrollDevice(secret);
    } on Failure {
      await keys.forget(phone.e164);
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

  void _switchMode() => context.go(
    widget.isSignUp ? AppRoutes.authPhone : AppRoutes.authPhoneSignUp,
  );

  /// Texte d'aide sous le numero : ce qui va se passer en appuyant.
  String? _hint(AppLocalizations l10n) {
    if (_lockAvailable == null) return null;
    if (!_useLock) return l10n.authNoDeviceLockHint;
    if (widget.isSignUp) return l10n.authDeviceLockSignUpHint;
    if (_phone == null) return null;
    return _deviceKey != null
        ? l10n.authDeviceLockSignInHint
        : l10n.authNewDeviceHint;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final googleAccounts =
        ref.watch(googleAccountHintsProvider).valueOrNull ?? const [];
    final hint = _hint(l10n);
    final unlocks = !widget.isSignUp && _useLock && _deviceKey != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Hero(
              headline: widget.isSignUp
                  ? l10n.authPhoneSignUpHeadline
                  : l10n.authPhoneSignInHeadline,
              lead: widget.isSignUp
                  ? l10n.authPhoneSignUpLead
                  : l10n.authPhoneSignInLead,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: authSurfaceColor(context),
                  borderRadius: AppRadii.sheetTop,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhoneField(
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onChanged: _onPhone,
                          onSubmitted: _submit,
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _LockHint(
                            text: hint,
                            icon: _useLock
                                ? Icons.fingerprint_rounded
                                : Icons.lock_outline_rounded,
                          ),
                        ],
                        if (widget.isSignUp && _useLock) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _wantsBackupPassword =
                                    !_wantsBackupPassword,
                              ),
                              icon: Icon(
                                _wantsBackupPassword
                                    ? Icons.expand_less_rounded
                                    : Icons.add_rounded,
                              ),
                              label: Text(l10n.authBackupPasswordToggle),
                            ),
                          ),
                        ],
                        if (_showPassword) ...[
                          const SizedBox(height: AppSpacing.md),
                          _PasswordField(
                            controller: _password,
                            label: l10n.authFieldPassword,
                            obscure: _obscure,
                            onToggle: () =>
                                setState(() => _obscure = !_obscure),
                            helper: widget.isSignUp
                                ? (_useLock
                                      ? l10n.authBackupPasswordHint
                                      : l10n.authPasswordTooShort)
                                : null,
                            newPassword: widget.isSignUp,
                            action: widget.isSignUp
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onChanged: () => setState(() => _error = null),
                            onSubmitted: widget.isSignUp ? null : _submit,
                          ),
                          if (widget.isSignUp) ...[
                            const SizedBox(height: AppSpacing.md),
                            _PasswordField(
                              controller: _confirm,
                              label: l10n.authFieldPasswordConfirm,
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              error:
                                  _confirm.text.isNotEmpty &&
                                      _confirm.text != _password.text
                                  ? l10n.authPasswordMismatch
                                  : null,
                              newPassword: true,
                              action: TextInputAction.done,
                              onChanged: () => setState(() => _error = null),
                              onSubmitted: _submit,
                            ),
                          ],
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: _canSubmit ? _submit : null,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (unlocks || (widget.isSignUp && _useLock)) ...[
                                      const Icon(Icons.fingerprint_rounded),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: Text(
                                        widget.isSignUp
                                            ? l10n.authPhoneCreateAction
                                            : (unlocks
                                                  ? l10n.authUnlockAndEnter
                                                  : l10n.authPhoneSignInAction),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!unlocks &&
                                        !(widget.isSignUp && _useLock)) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _busy ? null : _switchMode,
                          style: _suggestSwitch
                              ? TextButton.styleFrom(
                                  backgroundColor: AppColors.accent.withValues(
                                    alpha: 0.25,
                                  ),
                                )
                              : null,
                          child: Text(
                            widget.isSignUp
                                ? l10n.authPhoneSwitchToSignIn
                                : l10n.authPhoneSwitchToSignUp,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (googleAccounts.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  l10n.authOrSeparator,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _continueWithGoogle,
                            icon: const SocialMark(
                              provider: SocialProvider.google,
                              size: 20,
                            ),
                            label: Text(l10n.authGoogleContinue),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.authPhoneTerms,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encadre explicatif : comment l'utilisateur va prouver que c'est lui.
class _LockHint extends StatelessWidget {
  const _LockHint({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadii.componentAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.headline, required this.lead});

  final String headline;
  final String lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.authChoice),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              const Spacer(),
              // Bascule de langue : deux pastilles, l'active en ambre, l'autre
              // translucide sur le bleu.
              for (final (code, label) in [
                ('fr', l10n.langFrench),
                ('mg', l10n.langMalagasy),
              ])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _LanguagePill(
                    label: label,
                    selected: locale.languageCode == code,
                    onTap: () => ref
                        .read(localeProvider.notifier)
                        .set(AppLocales.fromCode(code)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: AppRadii.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.authPhoneCityBadge,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  headline,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lead,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
    required this.action,
    required this.newPassword,
    this.helper,
    this.error,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final TextInputAction action;
  final bool newPassword;
  final String? helper;
  final String? error;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      autofillHints: [
        newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: error,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: obscure ? l10n.authPasswordShow : l10n.authPasswordHide,
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.componentAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.accent
            : Colors.white.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primaryDark : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
