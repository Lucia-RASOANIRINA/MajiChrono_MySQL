import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/security/device_integrity.dart';
import 'package:majichrono/core/security/secure_screen.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_primary_action.dart';

/// Confirmation du paiement par le payeur (EXI-MP02).
///
/// C'est l'ecran qui porte l'invariant du module : **le scan n'a rien
/// autorise**. L'appariement a seulement revele le montant et le beneficiaire ;
/// le debit n'a lieu qu'ici, apres saisie du code sur l'appareil du payeur.
///
/// Le montant et le beneficiaire sont affiches en grand, avant le champ de
/// code. Demander un code avant de montrer ce qu'on paie reviendrait a faire
/// signer un cheque en blanc.
class PaymentConfirmScreen extends ConsumerStatefulWidget {
  const PaymentConfirmScreen({required this.intent, super.key});

  final PaymentIntent intent;

  @override
  ConsumerState<PaymentConfirmScreen> createState() =>
      _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState extends ConsumerState<PaymentConfirmScreen> {
  final TextEditingController _pin = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);

    try {
      final settled = await ref
          .read(paymentActionsProvider)
          .confirm(intentId: widget.intent.id, pin: _pin.text.trim());

      if (settled == null) {
        // Code faux : le serveur n'a pas ete sollicite. Inutile de lui faire
        // porter une tentative qui n'a pas franchi la porte de l'appareil.
        setState(() => _error = l10n.payWrongPin);
        return;
      }

      navigator.pop(settled);
    } on Failure catch (failure) {
      setState(() => _error = failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payCash() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final cash = await ref
          .read(paymentActionsProvider)
          .fallbackToCash(widget.intent.id);
      navigator.pop(cash);
    } on Failure catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure.localizedMessage(AppLocalizations.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = ref.watch(majiPayBalanceProvider(UserRole.client));

    final covered = balance.valueOrNull?.covers(widget.intent.amountAriary);

    // EXI-SEC06 : montant, beneficiaire et solde ne doivent pas finir dans une
    // capture d'ecran ni dans l'apercu des applications recentes.
    return SecureScreen(
      surface: SecureSurface.payment,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.payConfirmTitle)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Ce qu'on paie, avant de demander comment.
            Text(
              l10n.payAmount,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              formatAriary(widget.intent.amountAriary),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${l10n.payConfirmTo} : ${widget.intent.payeeLabel ?? '-'}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(l10n.payBalance),
                subtitle: Text(balance.valueOrNull?.accountRef ?? ''),
                trailing: Text(
                  balance.valueOrNull == null
                      ? l10n.payBalanceUnavailable
                      : formatAriary(balance.valueOrNull!.availableAriary),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: covered == false ? AppColors.danger : null,
                  ),
                ),
              ),
            ),

            if (covered == false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.payFailedInsufficient,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text(l10n.payConfirmPin, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
              decoration: InputDecoration(counterText: '', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),

            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.payConfirmNever,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            // EXI-MP08 : la sortie especes est offerte d'emblee, pas seulement
            // apres un echec. Un client sans solde ne doit pas avoir a echouer
            // d'abord pour decouvrir qu'il peut payer autrement.
            OutlinedButton.icon(
              onPressed: _busy ? null : _payCash,
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.payCashFallback),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.payCashHelp,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottomNavigationBar: McPrimaryAction(
          label: l10n.payConfirmAction(
            formatAriary(widget.intent.amountAriary),
          ),
          icon: Icons.lock_outline,
          busy: _busy,
          onPressed: _pin.text.trim().length == 4 ? _confirm : null,
        ),
      ),
    );
  }
}
