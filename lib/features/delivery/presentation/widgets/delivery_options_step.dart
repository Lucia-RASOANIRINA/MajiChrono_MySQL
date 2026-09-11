import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/delivery/presentation/providers/relay_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Troisieme pas de la creation : les differenciants (§5).
///
/// Trois sections, dont deux conditionnelles. L'achat pour compte n'apparait que
/// si le type de course est « achat pour compte » ; le relais, que si le colis
/// tient dans une boutique. Afficher des options inapplicables ferait chercher
/// pourquoi elles ne marchent pas.
class DeliveryOptionsStep extends ConsumerWidget {
  const DeliveryOptionsStep({
    required this.kind,
    required this.weight,
    required this.dropoffDistrict,
    required this.dropoffPoint,
    required this.payer,
    required this.items,
    required this.cap,
    required this.storeHint,
    required this.relayPointId,
    required this.onPayer,
    required this.onItems,
    required this.onRelay,
    super.key,
  });

  final DeliveryKind kind;
  final WeightCategory weight;
  final String dropoffDistrict;

  /// Position du point de remise, quand elle est connue : sert a trier les
  /// relais du plus proche au plus loin et a afficher leur distance (§7).
  final GeoPoint? dropoffPoint;
  final Payer payer;
  final List<ShoppingItem> items;
  final TextEditingController cap;
  final TextEditingController storeHint;
  final String? relayPointId;
  final ValueChanged<Payer> onPayer;
  final ValueChanged<List<ShoppingItem>> onItems;
  final ValueChanged<String?> onRelay;

  bool get _isShopping => kind == DeliveryKind.shopping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // --- Achat pour compte (EXI-C07, D5) ---------------------------
        if (_isShopping) ...[
          Text(l10n.shoppingTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.shoppingHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ShoppingSection(
            items: items,
            cap: cap,
            storeHint: storeHint,
            onItems: onItems,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Payeur (EXI-C42) -------------------------------------------
        Text(l10n.payerTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<Payer>(
          groupValue: payer,
          onChanged: (value) => onPayer(value ?? Payer.sender),
          child: Column(
            children: [
              RadioListTile<Payer>(
                value: Payer.sender,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.payerSender),
              ),
              RadioListTile<Payer>(
                value: Payer.recipient,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.payerRecipient),
              ),
            ],
          ),
        ),
        // Le port du se paie a la porte : si le destinataire n'a pas ete
        // prevenu du montant, il refuse le colis et c'est le livreur qui perd
        // sa course.
        if (payer.requiresRecipientNotice)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.payerRecipientNotice,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),

        // --- Point relais (D6) ------------------------------------------
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.relayTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.relayHelp,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _RelaySection(
          district: dropoffDistrict,
          dropoffPoint: dropoffPoint,
          weightKg: weight.maxKg,
          selectedId: relayPointId,
          onSelect: onRelay,
        ),
      ],
    );
  }
}

/// Liste d'articles et plafond de depense.
class _ShoppingSection extends StatefulWidget {
  const _ShoppingSection({
    required this.items,
    required this.cap,
    required this.storeHint,
    required this.onItems,
  });

  final List<ShoppingItem> items;
  final TextEditingController cap;
  final TextEditingController storeHint;
  final ValueChanged<List<ShoppingItem>> onItems;

  @override
  State<_ShoppingSection> createState() => _ShoppingSectionState();
}

class _ShoppingSectionState extends State<_ShoppingSection> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();
  bool _substitutable = false;

  @override
  void dispose() {
    _label.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _add() {
    final label = _label.text.trim();
    if (label.isEmpty) return;

    widget.onItems([
      ...widget.items,
      ShoppingItem(
        label: label,
        quantity: int.tryParse(_quantity.text) ?? 1,
        estimatedUnitAriary: int.tryParse(_price.text.replaceAll(' ', '')),
        substitutable: _substitutable,
      ),
    ]);

    setState(() {
      _label.clear();
      _price.clear();
      _quantity.text = '1';
      _substitutable = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final estimated = widget.items.fold<int>(
      0,
      (sum, i) => sum + i.estimatedTotalAriary,
    );
    final cap = int.tryParse(widget.cap.text.replaceAll(' ', '')) ?? 0;
    final capInRange =
        cap >= ShoppingOrder.minCapAriary && cap <= ShoppingOrder.maxCapAriary;
    final capTooLow = cap > 0 && estimated > 0 && cap < estimated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Articles deja saisis.
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              l10n.shoppingEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < widget.items.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                dense: true,
                title: Text(
                  '${widget.items[i].quantity} × ${widget.items[i].label}',
                ),
                subtitle: widget.items[i].substitutable
                    ? Text(l10n.shoppingSubstitutable)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.items[i].estimatedUnitAriary != null)
                      Text(formatAriary(widget.items[i].estimatedTotalAriary)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          widget.onItems([...widget.items]..removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),

        // Saisie d'un article.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: l10n.shoppingItemLabel,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.shoppingItemQuantity,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.shoppingItemPrice,
            isDense: true,
            suffixText: 'Ar',
          ),
        ),
        // La substitution se decide article par article : accepter un autre riz
        // n'engage pas a accepter un autre medicament.
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _substitutable,
          title: Text(l10n.shoppingSubstitutable),
          onChanged: (on) => setState(() => _substitutable = on ?? false),
        ),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(l10n.shoppingAddItem),
        ),

        const SizedBox(height: AppSpacing.lg),
        if (estimated > 0)
          Text(
            '${l10n.shoppingEstimated} : ${formatAriary(estimated)}',
            style: theme.textTheme.titleMedium,
          ),

        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.cap,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.shoppingCap,
            suffixText: 'Ar',
            helperText: l10n.shoppingCapHelp,
            helperMaxLines: 3,
            errorText: widget.cap.text.isEmpty || capInRange
                ? null
                : l10n.shoppingCapOutOfRange(
                    formatAriary(ShoppingOrder.minCapAriary),
                    formatAriary(ShoppingOrder.maxCapAriary),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        // Un plafond inferieur a l'estimation est presque toujours une erreur de
        // saisie : on le dit avant l'envoi plutot que de laisser le livreur le
        // decouvrir devant la caisse.
        if (capTooLow)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.shoppingCapTooLow,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.storeHint,
          decoration: InputDecoration(
            labelText: l10n.shoppingStoreHint,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// Choix d'un point relais de remise.
class _RelaySection extends ConsumerWidget {
  const _RelaySection({
    required this.district,
    required this.dropoffPoint,
    required this.weightKg,
    required this.selectedId,
    required this.onSelect,
  });

  final String district;
  final GeoPoint? dropoffPoint;
  final double weightKg;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // On ne filtre pas sur le quartier ici (un relais du quartier voisin peut
    // arranger) : on laisse le serveur trier par proximite quand il le peut.
    final relays = ref.watch(
      relayPointsProvider((
        district: null,
        lat: dropoffPoint?.latitude,
        lng: dropoffPoint?.longitude,
      )),
    );

    return relays.when(
      loading: () => const Center(child: McLoader()),
      // Un reseau de relais indisponible n'empeche pas de commander : la
      // livraison a l'adresse reste le defaut.
      error: (_, _) => Text(l10n.relayNone),
      data: (points) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<String?>(
            groupValue: selectedId,
            onChanged: onSelect,
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.relayNone),
                ),
                for (final relay in points)
                  RadioListTile<String?>(
                    value: relay.id,
                    contentPadding: EdgeInsets.zero,
                    // Un relais qui ne peut pas prendre le colis reste visible
                    // mais inerte, avec sa raison : le masquer laisserait
                    // croire qu'il n'existe pas.
                    enabled: relay.canAccept(weightKg),
                    title: Text(relay.name),
                    subtitle: Text(
                      relay.canAccept(weightKg)
                          ? '${relay.landmark} · ${relay.district}'
                                '${relay.distanceKm != null ? ' · ${l10n.relayDistance(relay.distanceKm!.toStringAsFixed(1))}' : ''}\n'
                                '${relay.openingHours} · '
                                '${l10n.relayStorage(relay.storageDays)}'
                          : l10n.relayTooHeavy,
                      style: relay.canAccept(weightKg)
                          ? null
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.danger,
                            ),
                    ),
                    isThreeLine: relay.canAccept(weightKg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
