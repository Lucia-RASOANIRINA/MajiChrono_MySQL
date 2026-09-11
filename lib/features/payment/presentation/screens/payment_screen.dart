import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_confirm_screen.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_qr_screen.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_scan_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Point d'entree du paiement d'une course (§11.2).
///
/// Les deux profils voient le meme ecran, avec deux actions inversees : le
/// client peut **presenter** son code ou **scanner** celui du livreur ; le
/// livreur, l'inverse. Cette symetrie n'est pas une coquetterie — au comptoir
/// comme sur le trottoir, c'est rarement la meme personne qui a une main libre.
///
/// Quel que soit le chemin, l'argent va du client au livreur et le payeur
/// confirme sur son propre appareil.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({required this.delivery, required this.role, super.key});

  final Delivery delivery;
  final UserRole role;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _busy = false;
  PaymentIntent? _settled;

  bool get _isDriver => widget.role == UserRole.driver;

  int get _amount => widget.delivery.priceAriary ?? 0;

  Future<T?> _guard<T>(Future<T?> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      return await action();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Le livreur presente son code : demande d'encaissement.
  Future<void> _present() async {
    final intent = await _guard(
      () => ref
          .read(paymentActionsProvider)
          .requestCollection(
            deliveryId: widget.delivery.id,
            amountAriary: _amount,
          ),
    );
    if (intent == null || !mounted) return;

    final result = await Navigator.of(context).push<PaymentIntent>(
      MaterialPageRoute(
        builder: (_) => PaymentQrScreen(
          intent: intent,
          onRenew: () => ref
              .read(paymentActionsProvider)
              .requestCollection(
                deliveryId: widget.delivery.id,
                amountAriary: _amount,
              ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _settled = result);
  }

  /// Le client scanne le code du livreur, puis confirme chez lui.
  Future<void> _scanAndConfirm() async {
    final scanned = await Navigator.of(context).push<ScannedPayment>(
      MaterialPageRoute(builder: (_) => const PaymentScanScreen()),
    );
    if (scanned == null || !mounted) return;

    final claimed = await _guard(
      () => ref.read(paymentActionsProvider).claim(scanned),
    );
    if (claimed == null || !mounted) return;

    // Une offre deja reglee par le scan n'a rien a confirmer.
    if (claimed.status.isFinal) {
      setState(() => _settled = claimed);
      return;
    }

    final result = await Navigator.of(context).push<PaymentIntent>(
      MaterialPageRoute(builder: (_) => PaymentConfirmScreen(intent: claimed)),
    );
    if (result != null && mounted) setState(() => _settled = result);
  }

  /// Le livreur scanne le code du client : encaissement d'une offre.
  Future<void> _scanOffer() async {
    final scanned = await Navigator.of(context).push<ScannedPayment>(
      MaterialPageRoute(builder: (_) => const PaymentScanScreen()),
    );
    if (scanned == null || !mounted) return;

    final settled = await _guard(
      () => ref.read(paymentActionsProvider).claim(scanned),
    );
    if (settled != null && mounted) setState(() => _settled = settled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = ref.watch(majiPayBalanceProvider(widget.role));
    final settled = _settled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.payTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            l10n.payAmount,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            formatAriary(_amount),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          // Le solde est lu, jamais recopie : MajiPay en est la source de
          // verite, et un solde mis en cache afficherait un montant faux au
          // moment precis ou il compte.
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.payBalance),
              subtitle: Text(balance.valueOrNull?.accountRef ?? ''),
              trailing: balance.isLoading
                  ? const McLoader.small()
                  : Text(
                      balance.valueOrNull == null
                          ? l10n.payBalanceUnavailable
                          : formatAriary(balance.valueOrNull!.availableAriary),
                      style: theme.textTheme.titleMedium,
                    ),
            ),
          ),

          if (settled != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Receipt(intent: settled, isDriver: _isDriver),
          ],

          const SizedBox(height: AppSpacing.xl),
          if (_isDriver) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _present,
              icon: const Icon(Icons.qr_code_2),
              label: Text(l10n.payShowQr),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scanOffer,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.payScan),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.payCollectHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _scanAndConfirm,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.payScan),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.payScanHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recu, consultable des que le mouvement a eu lieu (EXI-MP10).
class _Receipt extends StatelessWidget {
  const _Receipt({required this.intent, required this.isDriver});

  final PaymentIntent intent;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (icon, tone, label) = switch (intent.status) {
      PaymentStatus.captured => (
        Icons.check_circle_outline,
        AppColors.success,
        isDriver ? l10n.payReceived : l10n.payCaptured,
      ),
      PaymentStatus.cash => (
        Icons.payments_outlined,
        AppColors.success,
        l10n.payCashDone,
      ),
      _ => (
        Icons.error_outline,
        AppColors.danger,
        switch (intent.failure) {
          PaymentFailure.insufficientFunds => l10n.payFailedInsufficient,
          PaymentFailure.expired => l10n.payFailedExpired,
          PaymentFailure.declined => l10n.payFailedDeclined,
          _ => l10n.payFailedUnavailable,
        },
      ),
    };

    return Card(
      color: tone.withValues(alpha: 0.10),
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (intent.receiptRef != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${l10n.payReceiptRef} : ${intent.receiptRef}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatAriary(intent.amountAriary),
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
