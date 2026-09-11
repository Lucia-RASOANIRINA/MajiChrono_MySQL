import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/pin_keypad.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Ecran de verrouillage (EXI-T04, EXI-SEC07).
///
/// Il ne fait **aucun appel reseau** : la session est deja en memoire, seul le
/// verrou local est en cause. Un livreur hors couverture doit pouvoir rouvrir
/// son application et reprendre sa course (§4.1).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({required this.state, super.key});

  final AuthLocked state;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // La biometrie est proposee d'emblee quand elle est disponible : c'est le
    // geste le plus court, et le pave numerique reste accessible en cas de refus.
    if (widget.state.biometricsAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_tryBiometrics());
      });
    }
  }

  Future<void> _tryBiometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometrics(
          reason: AppLocalizations.of(context).authBiometricsReason,
        );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 4 || _busy) return;
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == 4) await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .unlockWithPin(_pin);
    if (!mounted) return;
    if (!ok) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _error = true;
        _pin = '';
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        // L'en-tete defile, le pave reste ancre en bas. Sans cela l'ecran
        // deborde des qu'il est court — cas reel sur les 320 dp du parc
        // d'entree de gamme (EXI-P09) et des qu'une police systeme agrandie
        // est active.
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.authWelcome(widget.state.account.displayName),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.authLockSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PinDots(filled: _pin.length, error: _error),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 24,
                      child: _error
                          ? Text(
                              l10n.authLockWrongPin,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            PinKeypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onBiometrics: widget.state.biometricsAvailable
                  ? _tryBiometrics
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: Text(l10n.authSignOut),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
