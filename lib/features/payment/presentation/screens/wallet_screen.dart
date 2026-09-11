import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Portefeuille client (§11, EXI-C39) : solde MajiPay et journal des paiements.
///
/// Le solde est **lu** a l'ouverture (jamais mis en cache : il vieillirait au
/// moment precis ou il compte), et l'historique est une lecture seule. Le
/// remboursement n'est pas execute ici — MajiPay le traite — mais l'ecran en
/// explique la marche, pour que l'utilisateur sache quoi attendre.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balance = ref.watch(majiPayBalanceProvider(UserRole.client));
    final history = ref.watch(paymentHistoryProvider(50));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(majiPayBalanceProvider(UserRole.client));
          ref.invalidate(paymentHistoryProvider(50));
          await ref.read(paymentHistoryProvider(50).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _BalanceCard(balance: balance),
            const SizedBox(height: AppSpacing.lg),
            _RefundNotice(text: l10n.walletRefundNote),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.walletHistoryTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            history.when(
              loading: () => const McSkeletonList(itemCount: 3),
              error: (_, _) => McEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.walletHistoryEmpty,
                message: l10n.errorUnknown,
              ),
              data: (entries) => entries.isEmpty
                  ? McEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.walletHistoryEmpty,
                      message: l10n.walletHistoryEmptyHelp,
                    )
                  : Column(
                      children: [
                        for (final entry in entries) ...[
                          _HistoryTile(entry: entry),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de solde. Un solde indisponible (reseau coupe) n'est pas une erreur :
/// on le dit sobrement plutot que d'afficher un zero trompeur.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final AsyncValue<MajiPayBalance?> balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadii.sheetAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.walletBalanceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          balance.when(
            loading: () => const SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            error: (_, _) => Text(
              l10n.payBalanceUnavailable,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            data: (value) => value == null
                ? Text(
                    l10n.payBalanceUnavailable,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAriary(value.availableAriary),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (value.accountRef.isNotEmpty)
                        Text(
                          value.accountRef,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
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

class _RefundNotice extends StatelessWidget {
  const _RefundNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return McCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Ligne du journal. Le signe et la couleur disent le sens (entrant/sortant),
/// jamais la couleur seule : le libelle le porte aussi (EXI-T09).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final PaymentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final intent = entry.intent;
    final outgoing = entry.isOutgoing;

    final (statusLabel, statusTone) = switch (intent.status) {
      PaymentStatus.captured => (l10n.walletStatusCaptured, AppColors.success),
      PaymentStatus.cash => (l10n.walletStatusCash, AppColors.neutral),
      PaymentStatus.failed => (l10n.walletStatusFailed, AppColors.danger),
      _ => (l10n.walletStatusPending, AppColors.warning),
    };

    return McCard(
      onTap: intent.receiptRef == null || intent.receiptRef!.isEmpty
          ? null
          : () => _showReceipt(context, l10n, intent),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (outgoing ? AppColors.danger : AppColors.success)
                .withValues(alpha: 0.12),
            child: Icon(
              outgoing ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: outgoing ? AppColors.danger : AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outgoing ? l10n.walletOutgoing : l10n.walletIncoming,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: statusTone),
                ),
              ],
            ),
          ),
          Text(
            '${outgoing ? '-' : '+'}${formatAriary(intent.amountAriary)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: outgoing ? null : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceipt(
    BuildContext context,
    AppLocalizations l10n,
    PaymentIntent intent,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.payReceiptTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ReceiptRow(
                label: l10n.payAmount,
                value: formatAriary(intent.amountAriary),
              ),
              _ReceiptRow(
                label: l10n.payReceiptRef,
                value: intent.receiptRef ?? '',
              ),
              _ReceiptRow(
                label: l10n.walletHistoryTitle,
                value: _formatDate(intent.capturedAt ?? intent.createdAt),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.neutral,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
