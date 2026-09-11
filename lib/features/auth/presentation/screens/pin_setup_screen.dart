import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/pin_keypad.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Creation du code PIN a 4 chiffres (EXI-T04).
///
/// Propose apres la premiere connexion, et jamais impose : un livreur qui refuse
/// le code doit pouvoir travailler quand meme. La contrepartie est que le
/// verrouillage automatique (EXI-SEC07) ne s'applique qu'aux comptes qui en ont
/// un — verrouiller sans code enfermerait l'utilisateur dehors.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({this.onDone, super.key});

  final VoidCallback? onDone;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _first = '';
  String _second = '';
  bool _confirming = false;
  bool _error = false;

  void _onDigit(String digit) {
    if (_error) setState(() => _error = false);

    if (!_confirming) {
      if (_first.length >= 4) return;
      setState(() => _first += digit);
      if (_first.length == 4) {
        setState(() => _confirming = true);
      }
      return;
    }

    if (_second.length >= 4) return;
    setState(() => _second += digit);
    if (_second.length == 4) _validate();
  }

  void _onBackspace() {
    setState(() {
      _error = false;
      if (_confirming && _second.isNotEmpty) {
        _second = _second.substring(0, _second.length - 1);
      } else if (_confirming) {
        _confirming = false;
        _first = _first.substring(0, _first.length - 1);
      } else if (_first.isNotEmpty) {
        _first = _first.substring(0, _first.length - 1);
      }
    });
  }

  Future<void> _validate() async {
    if (_first != _second) {
      await HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _second = '';
      });
      return;
    }

    await ref.read(authControllerProvider.notifier).setPin(_first);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).authPinSaved)),
    );
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filled = _confirming ? _second.length : _first.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authPinTitle),
        actions: [
          TextButton(onPressed: widget.onDone, child: Text(l10n.authPinLater)),
        ],
      ),
      body: SafeArea(
        // Meme structure que l'ecran de verrouillage : en-tete defilant, pave
        // ancre. Un ecran de 320 dp ne peut pas afficher les deux en entier.
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: AppSpacing.screen,
                      child: Text(
                        _confirming
                            ? l10n.authPinConfirmTitle
                            : l10n.authPinSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PinDots(filled: filled, error: _error),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 24,
                      child: _error
                          ? Text(
                              l10n.authPinMismatch,
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
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
