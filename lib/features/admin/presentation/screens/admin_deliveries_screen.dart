import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/admin/presentation/widgets/reason_sheet.dart';
import 'package:majichrono/features/custody/presentation/widgets/custody_proof_action.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_error_view.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Liste des courses, filtres multicriteres (EXI-A04).
///
/// Le filtrage se fait **localement** sur ce que le mobile a deja : un
/// aller-retour reseau a chaque case cochee rendrait les filtres inutilisables
/// sur le terrain, et couterait du forfait pour trier ce qui est deja la (§4.4).
///
/// L'acces aux deux constats passe par le comparateur du module 5, sans variante
/// d'exploitation : EXI-CC31 impose que les trois profils voient la meme chose.
/// Une vue enrichie reservee a l'admin ne serait plus une preuve contradictoire,
/// ce serait un dossier a charge.
class AdminDeliveriesScreen extends ConsumerWidget {
  const AdminDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deliveries = ref.watch(deliveriesProvider);
    final filter = ref.watch(deliveryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDeliveriesTitle),
        actions: [
          if (!filter.isEmpty)
            TextButton(
              onPressed: () => ref.read(deliveryFilterProvider.notifier).state =
                  const DeliveryFilter(),
              child: Text(l10n.adminFilterClear),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          Expanded(
            child: deliveries.when(
              loading: () => const McSkeletonList(itemCount: 4),
              error: (error, _) => McErrorView(
                failure: error is Failure ? error : const UnknownFailure(),
                onRetry: () => ref.invalidate(deliveriesProvider),
              ),
              data: (all) {
                final matching = all.where(filter.matches).toList();

                if (matching.isEmpty) {
                  return McEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: l10n.adminDeliveriesEmpty,
                    message: l10n.adminFilterSearch,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: matching.length,
                  itemBuilder: (_, i) =>
                      _AdminDeliveryCard(delivery: matching[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final DeliveryFilter filter;

  /// Statuts proposes au filtre.
  ///
  /// Pas les quinze : une barre de quinze puces se fait defiler sans etre lue.
  /// Seulement ceux sur lesquels l'exploitation agit reellement.
  static const List<DeliveryStatus> _offered = [
    DeliveryStatus.pending,
    DeliveryStatus.inTransit,
    DeliveryStatus.disputed,
    DeliveryStatus.delivered,
    DeliveryStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.adminFilterSearch,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) =>
                ref.read(deliveryFilterProvider.notifier).state = filter
                    .copyWith(query: value),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (final status in _offered) ...[
                FilterChip(
                  label: Text(statusLabel(l10n, status)),
                  selected: filter.statuses.contains(status),
                  onSelected: (on) {
                    final next = {...filter.statuses};
                    on ? next.add(status) : next.remove(status);
                    ref.read(deliveryFilterProvider.notifier).state = filter
                        .copyWith(statuses: next);
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminDeliveryCard extends ConsumerStatefulWidget {
  const _AdminDeliveryCard({required this.delivery});

  final Delivery delivery;

  @override
  ConsumerState<_AdminDeliveryCard> createState() => _AdminDeliveryCardState();
}

class _AdminDeliveryCardState extends ConsumerState<_AdminDeliveryCard> {
  bool _busy = false;

  /// Reaffectation manuelle (EXI-A07).
  ///
  /// Deux etapes, dans cet ordre : choisir le livreur, puis motiver. Demander
  /// le motif avant de savoir vers qui reaffecter obligerait a le reecrire si
  /// le choix change.
  Future<void> _reassign() async {
    final l10n = AppLocalizations.of(context);
    final candidates = await ref.read(availableDriversProvider.future);
    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminReassignNone)));
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.adminReassignPick),
              subtitle: Text(l10n.adminReassignHelp),
            ),
            const Divider(height: 1),
            for (final driver in candidates)
              ListTile(
                leading: const Icon(Icons.two_wheeler),
                title: Text(driver.displayName),
                subtitle: Text(driver.plate ?? ''),
                onTap: () => Navigator.of(context).pop(driver.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final decision = await askForReason(
      context,
      action: ModerationAction.reassignDelivery,
      title: l10n.adminReassignTitle,
      actionLabel: l10n.adminReassign,
      help: l10n.adminReassignHelp,
    );
    if (decision == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(adminActionsProvider)
          .reassign(
            deliveryId: widget.delivery.id,
            driverId: picked,
            decision: decision,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
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
    final theme = Theme.of(context);
    final delivery = widget.delivery;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatusBadge(status: delivery.status)),
                if (delivery.priceAriary != null)
                  Text(
                    formatAriary(delivery.priceAriary!),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${delivery.pickup.district} → ${delivery.dropoff.district}',
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              delivery.driverName ?? l10n.adminReassignNone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                // Acces aux deux constats, par le comparateur commun aux trois
                // profils (EXI-A04, EXI-CC31).
                CustodyProofAction(delivery: delivery),
                const Spacer(),
                if (_busy)
                  const McLoader.small()
                else if (delivery.status.isActive)
                  TextButton.icon(
                    onPressed: _reassign,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.adminReassign),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
