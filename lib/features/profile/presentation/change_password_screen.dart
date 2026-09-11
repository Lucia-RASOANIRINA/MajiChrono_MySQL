import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Change (ou pose) le mot de passe du compte.
///
/// Le mot de passe actuel est demande sans etre obligatoire : un compte entre
/// par numero n'en a pas encore, et le serveur ne le reclame que s'il en existe
/// deja un. On evite ainsi d'afficher deux ecrans differents pour une meme
/// action.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text.isEmpty ? null : _current.text,
            newPassword: _next.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      router.pop();
    } on Failure catch (failure) {
      final message = failure is UnauthorizedFailure
          ? l10n.passwordWrongCurrent
          : failure.localizedMessage(l10n);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.passwordChangeTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.passwordCurrent,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.passwordNew,
                prefixIcon: const Icon(Icons.lock_reset_outlined),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? l10n.passwordTooShort : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.passwordConfirm,
                prefixIcon: const Icon(Icons.check_circle_outline),
              ),
              validator: (v) =>
                  v != _next.text ? l10n.passwordMismatch : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
