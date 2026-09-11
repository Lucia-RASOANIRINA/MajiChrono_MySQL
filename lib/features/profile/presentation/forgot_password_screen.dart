import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// « Mot de passe oublie » : preuve de possession de la boite mail, puis nouveau
/// mot de passe.
///
/// Le parcours reutilise le code e-mail deja en place : on demande un code a
/// l'adresse, puis on le presente avec le nouveau mot de passe. Rien n'indique
/// si l'adresse porte un compte tant que le code n'est pas prouve — c'est ce qui
/// empeche d'enumerer les comptes depuis cet ecran.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  EmailChallenge? _challenge;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestEmailCode(_email.text.trim());
      setState(() => _challenge = challenge);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.codeSentToEmail(challenge.email))),
      );
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    if (_next.text.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordTooShort)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            challengeId: _challenge!.challengeId,
            code: _code.text.trim(),
            newPassword: _next.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      router.pop();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sent = _challenge != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.passwordForgotTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.passwordForgotHelp),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            enabled: !sent,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.profileEmailLabel,
              prefixIcon: const Icon(Icons.alternate_email),
            ),
          ),
          if (!sent) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _requestCode,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
              child: _busy
                  ? const _Spinner()
                  : Text(l10n.commonSend),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.codeEnterTitle,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.passwordNew,
                prefixIcon: const Icon(Icons.lock_reset_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _reset,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
              child: _busy ? const _Spinner() : Text(l10n.passwordReset),
            ),
          ],
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
