import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_delivery_card.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Regroupement de statuts pour les onglets de l'historique (EXI-C33).
enum _HistoryTab { all, active, done, cancelled }

/// Fenetre temporelle du filtre historique.
enum _HistoryPeriod { all, days7, days30 }

/// Historique des courses (EXI-C33).
///
/// Alimente par la base locale, donc consultable hors ligne. Le rafraichissement
/// serveur est un complement, jamais une condition d'affichage. La recherche et
/// les filtres travaillent sur cette meme liste locale : ils restent donc
/// disponibles hors ligne, sans aller-retour serveur.
class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _HistoryTab _tab = _HistoryTab.all;
  _HistoryPeriod _period = _HistoryPeriod.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesTab(Delivery d) => switch (_tab) {
    _HistoryTab.all => true,
    _HistoryTab.active => d.status.isActive,
    _HistoryTab.done =>
      d.status == DeliveryStatus.delivered ||
          d.status == DeliveryStatus.deliveredWithReserves ||
          d.status == DeliveryStatus.paid ||
          d.status == DeliveryStatus.closed,
    _HistoryTab.cancelled =>
      d.status == DeliveryStatus.cancelled ||
          d.status == DeliveryStatus.refused,
  };

  bool _matchesPeriod(Delivery d) {
    final days = switch (_period) {
      _HistoryPeriod.all => null,
      _HistoryPeriod.days7 => 7,
      _HistoryPeriod.days30 => 30,
    };
    if (days == null) return true;
    return d.createdAt.isAfter(DateTime.now().subtract(Duration(days: days)));
  }

  bool _matchesQuery(Delivery d) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return d.id.toLowerCase().contains(q) ||
        d.pickup.summary.toLowerCase().contains(q) ||
        d.dropoff.summary.toLowerCase().contains(q) ||
        (d.driverName?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deliveries = ref.watch(deliveriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.deliveriesTitle,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: deliveries.when(
        loading: () => const McSkeletonList(),
        error: (_, _) => McEmptyState(
          icon: Icons.inventory_2_outlined,
          title: l10n.emptyDeliveries,
          message: l10n.errorUnknown,
        ),
        data: (items) => items.isEmpty
            ? McEmptyState(
                icon: Icons.inventory_2_outlined,
                title: l10n.emptyDeliveries,
                message: l10n.addrBookEmptyHelp,
                actionLabel: l10n.emptyDeliveriesAction,
                onAction: () => context.push(AppRoutes.clientNewDelivery),
              )
            : _buildList(context, l10n, items),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<Delivery> items,
  ) {
    // Le tri par date descendante est deja garanti en amont ; on ne fait
    // qu'appliquer les criteres successifs sur la meme liste.
    final filtered = items
        // Protection d'affichage supplementaire : une course est identifiee
        // par son id, jamais par le texte de ses adresses.
        .fold<Map<String, Delivery>>({}, (unique, delivery) {
          unique[delivery.id] = delivery;
          return unique;
        })
        .values
        .where(_matchesTab)
        .where(_matchesPeriod)
        .where(_matchesQuery)
        .toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(deliveryRepositoryProvider).refreshDeliveries(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SearchField(
            controller: _searchController,
            hint: l10n.histSearchHint,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: AppSpacing.md),
          _TabRow(
            current: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeriodRow(
            current: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              l10n.histResultCount(filtered.length),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.neutral),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: McEmptyState(
                icon: Icons.search_off,
                title: l10n.histNoMatch,
                message: l10n.histNoMatchHelp,
              ),
            )
          else
            for (final delivery in filtered) ...[
              DeliveryCard(delivery: delivery),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

/// Champ de recherche de l'historique. Bouton d'effacement des qu'un texte est
/// saisi, pour ne pas laisser l'utilisateur effacer caractere par caractere.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: AppRadii.componentAll),
      ),
    );
  }
}

/// Rangee d'onglets de statut (EXI-C33) : toutes / en cours / terminees /
/// annulees. Des `ChoiceChip` plutot qu'un `TabBar` pour rester sur la meme
/// grammaire de filtres que la supervision.
class _TabRow extends StatelessWidget {
  const _TabRow({required this.current, required this.onChanged});

  final _HistoryTab current;
  final ValueChanged<_HistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _HistoryTab.all: l10n.histFilterAll,
      _HistoryTab.active: l10n.histFilterActive,
      _HistoryTab.done: l10n.histFilterDone,
      _HistoryTab.cancelled: l10n.histFilterCancelled,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _HistoryTab.values) ...[
            ChoiceChip(
              label: Text(labels[tab]!),
              selected: current == tab,
              onSelected: (_) => onChanged(tab),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Rangee de fenetres temporelles (EXI-C33 : filtre par date).
class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.current, required this.onChanged});

  final _HistoryPeriod current;
  final ValueChanged<_HistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _HistoryPeriod.all: l10n.histPeriodAll,
      _HistoryPeriod.days7: l10n.histPeriod7,
      _HistoryPeriod.days30: l10n.histPeriod30,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in _HistoryPeriod.values) ...[
            FilterChip(
              label: Text(labels[period]!),
              selected: current == period,
              onSelected: (_) => onChanged(period),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Carte resumant une course, batie sur le composant partage `McDeliveryCard` :
/// le meme dessin de course sert ici, sur l'accueil et dans la supervision.
///
/// Une course non transmise (`pendingSync`) porte un lisere ardoise et un fait
/// « en attente » plutot qu'un lien : elle existe pour l'utilisateur, mais
/// aucun livreur ne l'a encore vue (EXI-C13), et ouvrir son suivi ne donnerait
/// rien a suivre.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({required this.delivery, super.key});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return McDeliveryCard(
      statusLabel: statusLabel(l10n, delivery.status),
      statusIcon: statusIcon(delivery.status),
      statusTone: statusTone(delivery.status),
      // Emplacement photo (EXI-C09) : la vraie photo du colis des que la chaine
      // photo l'a capturee, sinon une pastille au type du colis. Le chemin local
      // est resolu par le referentiel photo quand il existe.
      leading: McDeliveryThumb(icon: kindIcon(delivery.kind)),
      origin: delivery.pickup.summary,
      destination: delivery.dropoff.summary,
      accent: delivery.pendingSync ? AppColors.offline : null,
      trailing: delivery.priceAriary != null
          ? Text(
              formatAriary(delivery.priceAriary!),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      facts: [
        McDeliveryFact(
          Icons.straighten,
          l10n.deliveryDistance(delivery.distanceKm.toStringAsFixed(1)),
        ),
        if (delivery.pendingSync)
          McDeliveryFact(Icons.cloud_upload_outlined, l10n.deliveryPendingSync),
      ],
      onTap: delivery.pendingSync
          ? null
          : () => context.push(AppRoutes.clientTracking(delivery.id)),
    );
  }
}

/// Pastille de statut, batie sur le composant partage `McStatusBadge` : icone
/// **et** libelle dans une pilule teintee, jamais la couleur seule (EXI-T09).
///
/// Alignee a gauche, elle reste compacte meme placee dans un `Expanded` — la
/// pilule ne s'etire pas sur toute la largeur.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: McStatusBadge(
        label: statusLabel(l10n, status),
        icon: statusIcon(status),
        tone: statusTone(status),
      ),
    );
  }
}

/// Libelle d'un statut de course.
///
/// Extrait de `StatusBadge` pour servir aussi les puces de filtre de la
/// supervision (EXI-A04) : deux tables de correspondance finiraient par
/// diverger, et deux ecrans nommeraient le meme statut differemment.
String statusLabel(AppLocalizations l10n, DeliveryStatus status) =>
    switch (status) {
      DeliveryStatus.draft => l10n.statusDraft,
      DeliveryStatus.pending => l10n.statusPending,
      DeliveryStatus.accepted => l10n.statusAccepted,
      DeliveryStatus.atPickup => l10n.statusAtPickup,
      DeliveryStatus.pickedUp => l10n.statusPickedUp,
      DeliveryStatus.inTransit => l10n.statusInTransit,
      DeliveryStatus.atDestination => l10n.statusAtDestination,
      DeliveryStatus.delivered => l10n.statusDelivered,
      DeliveryStatus.deliveredWithReserves => l10n.statusDeliveredWithReserves,
      DeliveryStatus.refused => l10n.statusRefused,
      DeliveryStatus.returning => l10n.statusReturning,
      DeliveryStatus.paid => l10n.statusPaid,
      DeliveryStatus.disputed => l10n.statusDisputed,
      DeliveryStatus.cancelled => l10n.statusCancelled,
      DeliveryStatus.closed => l10n.statusClosed,
    };

/// Ton du statut pour la pastille du design system (`McStatusBadge`). Il suit
/// le meme regroupement que [statusColor] : une seule lecture des statuts, que
/// ce soit une couleur ou un ton.
McStatusTone statusTone(DeliveryStatus status) => switch (status) {
  DeliveryStatus.draft ||
  DeliveryStatus.cancelled ||
  DeliveryStatus.closed => McStatusTone.neutral,
  DeliveryStatus.pending ||
  DeliveryStatus.deliveredWithReserves ||
  DeliveryStatus.returning => McStatusTone.warning,
  DeliveryStatus.accepted ||
  DeliveryStatus.atPickup ||
  DeliveryStatus.pickedUp ||
  DeliveryStatus.inTransit ||
  DeliveryStatus.atDestination => McStatusTone.info,
  DeliveryStatus.delivered || DeliveryStatus.paid => McStatusTone.success,
  DeliveryStatus.refused || DeliveryStatus.disputed => McStatusTone.danger,
};

/// Icone d'un statut. Elle double le libelle partout ou le statut s'affiche, la
/// couleur ne portant jamais seule l'information (EXI-T09).
IconData statusIcon(DeliveryStatus status) => switch (status) {
  DeliveryStatus.draft => Icons.edit_note,
  DeliveryStatus.pending => Icons.hourglass_empty,
  DeliveryStatus.accepted => Icons.assignment_turned_in_outlined,
  DeliveryStatus.atPickup => Icons.storefront_outlined,
  DeliveryStatus.pickedUp => Icons.inventory_2_outlined,
  DeliveryStatus.inTransit => Icons.local_shipping_outlined,
  DeliveryStatus.atDestination => Icons.flag_outlined,
  DeliveryStatus.delivered => Icons.check_circle_outline,
  DeliveryStatus.deliveredWithReserves => Icons.fact_check_outlined,
  DeliveryStatus.refused => Icons.cancel_outlined,
  DeliveryStatus.returning => Icons.keyboard_return,
  DeliveryStatus.paid => Icons.paid_outlined,
  DeliveryStatus.disputed => Icons.gavel_outlined,
  DeliveryStatus.cancelled => Icons.cancel_outlined,
  DeliveryStatus.closed => Icons.lock_outline,
};

/// Icone du type de colis, pour la vignette de la course quand aucune photo
/// n'est encore disponible.
IconData kindIcon(DeliveryKind kind) => switch (kind) {
  DeliveryKind.standard => Icons.inventory_2_outlined,
  DeliveryKind.document => Icons.description_outlined,
  DeliveryKind.fragile => Icons.egg_outlined,
  DeliveryKind.food => Icons.restaurant_outlined,
  DeliveryKind.shopping => Icons.shopping_bag_outlined,
};

/// Couleur d'un statut. Elle double toujours le libelle, jamais l'inverse
/// (EXI-T09 : la couleur seule serait illisible en plein soleil).
Color statusColor(DeliveryStatus status) => switch (status) {
  DeliveryStatus.draft ||
  DeliveryStatus.cancelled ||
  DeliveryStatus.closed => AppColors.neutral,
  DeliveryStatus.pending ||
  DeliveryStatus.deliveredWithReserves ||
  DeliveryStatus.returning => AppColors.warning,
  DeliveryStatus.accepted ||
  DeliveryStatus.atPickup ||
  DeliveryStatus.pickedUp ||
  DeliveryStatus.inTransit ||
  DeliveryStatus.atDestination => AppColors.info,
  DeliveryStatus.delivered || DeliveryStatus.paid => AppColors.success,
  DeliveryStatus.refused || DeliveryStatus.disputed => AppColors.danger,
};
