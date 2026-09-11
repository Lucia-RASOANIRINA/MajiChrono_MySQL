import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Tableau de bord des gains (EXI-L12).
///
/// Jour, semaine, mois **et detail par course**. Le detail n'est pas un
/// supplement : c'est ce qui permet a un livreur de verifier un montant et de
/// contester precisement, plutot que de constater un ecart global sans pouvoir
/// designer la course en cause.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.earningsTitle)),
      body: earnings.when(
        loading: () => const McSkeletonList(itemCount: 3),
        error: (_, _) => McEmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.earningsEmpty,
          message: l10n.errorNetwork,
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(earningsProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.earningsToday,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatAriary(summary.todayAriary),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.earningsCount(summary.todayCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _MajiPayCard(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: l10n.earningsWeek,
                      amount: summary.weekAriary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Tile(
                      label: l10n.earningsMonth,
                      amount: summary.monthAriary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.earningsCommission,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (summary.entries.isEmpty)
                SizedBox(
                  height: 200,
                  child: Card(
                    child: McEmptyState(
                      icon: Icons.payments_outlined,
                      title: l10n.earningsEmpty,
                      message: l10n.driverNoOffersHelp,
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final entry in summary.entries) ...[
                        ListTile(
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.success,
                          ),
                          title: Text(entry.label),
                          subtitle: Text(
                            '${entry.at.hour.toString().padLeft(2, '0')}:'
                            '${entry.at.minute.toString().padLeft(2, '0')}',
                          ),
                          trailing: Text(
                            formatAriary(entry.amountAriary),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (entry != summary.entries.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const _TransactionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Historique des transactions MajiPay du livreur (EXI-L12, §20).
///
/// Complement du detail par course, qui melange especes et MajiPay : cette
/// section montre les mouvements MajiPay a proprement parler — les
/// encaissements captures. Absente tant qu'il n'y en a aucun.
class _TransactionsSection extends ConsumerWidget {
  const _TransactionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final history = ref.watch(paymentHistoryProvider(20)).valueOrNull;
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.walletHistoryTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              for (final entry in history) ...[
                ListTile(
                  leading: Icon(
                    entry.isOutgoing
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: entry.isOutgoing
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  title: Text(
                    entry.isOutgoing ? l10n.walletOutgoing : l10n.walletIncoming,
                  ),
                  trailing: Text(
                    '${entry.isOutgoing ? '-' : '+'}'
                    '${formatAriary(entry.intent.amountAriary)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry != history.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Solde MajiPay du livreur, avec le bouton de retrait (EXI-MP09).
///
/// Le solde est **lu**, jamais recopie : c'est MajiPay qui en est la source. Le
/// bouton reste inactif tant que le solde n'est pas connu — on ne propose pas de
/// retirer d'un montant qu'on n'a pas encore pu afficher.
class _MajiPayCard extends ConsumerWidget {
  const _MajiPayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = ref.watch(majiPayBalanceProvider(UserRole.driver));

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.withdrawAvailable,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            balance.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Text('—', style: theme.textTheme.displaySmall),
              data: (b) => Text(
                b == null ? '—' : formatAriary(b.availableAriary),
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: balance.valueOrNull == null
                    ? null
                    : () => _openSheet(context, balance.value!.availableAriary),
                icon: const Icon(Icons.north_east),
                label: Text(l10n.withdrawAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, int maxAmount) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WithdrawSheet(maxAmount: maxAmount),
    );
  }
}

/// Feuille de saisie d'un retrait : montant et destination, puis confirmation.
class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet({required this.maxAmount});

  final int maxAmount;

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amount = TextEditingController();
  final _destination = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final amount = int.tryParse(_amount.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _error = l10n.withdrawInvalidAmount);
      return;
    }
    if (amount > widget.maxAmount) {
      setState(() => _error = l10n.withdrawInsufficient);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final receipt = await ref
          .read(paymentActionsProvider)
          .withdraw(
            amountAriary: amount,
            destination: _destination.text.trim(),
          );
      if (!mounted) return;

      // Le solde a bouge chez MajiPay : on invalide pour le relire, et on
      // rafraichit les gains dans la foulee.
      ref.invalidate(majiPayBalanceProvider(UserRole.driver));
      ref.invalidate(earningsProvider);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.withdrawSuccess(receipt.ref))),
      );
    } on ServerFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = failure.code == 'insufficient_funds'
            ? l10n.withdrawInsufficient
            : l10n.errorNetwork;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.errorNetwork;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.withdrawTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l10n.withdrawAvailable} : ${formatAriary(widget.maxAmount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            autofocus: true,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: l10n.withdrawAmountLabel,
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _destination,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: l10n.withdrawDestinationLabel,
              prefixIcon: const Icon(Icons.smartphone_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.withdrawConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(formatAriary(amount), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
