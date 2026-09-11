import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:majichrono/app/app.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/presentation/widgets/delivery_options_step.dart';
import 'package:majichrono/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/address_book_screen.dart'
    show kindIcon, kindLabel;
import 'package:majichrono/features/delivery/presentation/widgets/address_form.dart';
import 'package:majichrono/features/delivery/presentation/widgets/price_breakdown.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

class CreateDeliveryScreen extends ConsumerStatefulWidget {
  const CreateDeliveryScreen({super.key});

  @override
  ConsumerState<CreateDeliveryScreen> createState() =>
      _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends ConsumerState<CreateDeliveryScreen> {
  int _step = 0;

  Address? _pickup;
  Address? _dropoff;
  DeliveryKind _kind = DeliveryKind.standard;
  WeightCategory _weight = WeightCategory.upTo2;
  PickupSlot _slot = const PickupSlot.immediate();
  PaymentMethod _payment = PaymentMethod.cash;
  final TextEditingController _value = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _length = TextEditingController();
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoId;
  bool _uploadingPhoto = false;

  Payer _payer = Payer.sender;
  List<ShoppingItem> _items = const [];
  String? _relayPointId;
  final TextEditingController _cap = TextEditingController();
  final TextEditingController _storeHint = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _description.dispose();
    _length.dispose();
    _width.dispose();
    _height.dispose();
    _cap.dispose();
    _storeHint.dispose();
    super.dispose();
  }

  Future<void> _pickPackagePhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _uploadingPhoto = true;
    });
    try {
      final id = await ref
          .read(deliveryRepositoryProvider)
          .uploadPackagePhoto(bytes: bytes, contentType: 'image/jpeg');
      setState(() => _photoId = id);
    } on Failure catch (failure) {
      // L'envoi a echoue : on retire l'apercu pour ne pas laisser croire que la
      // photo est jointe.
      setState(() {
        _photoBytes = null;
        _photoId = null;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  ShoppingOrder? get _shopping {
    if (_kind != DeliveryKind.shopping) return null;
    return ShoppingOrder(
      items: _items,
      capAriary: int.tryParse(_cap.text.replaceAll(' ', '')) ?? 0,
      storeHint: _storeHint.text.trim().isEmpty ? null : _storeHint.text.trim(),
    );
  }

  bool get _canContinue => switch (_step) {
    0 =>
      _pickup != null &&
          _dropoff != null &&
          _pickup!.point.distanceKmTo(_dropoff!.point) >= 0.05,
    1 => true,
    2 => _shopping?.isComplete ?? true,
    _ => true,
  };

  PriceEstimate get _estimate => ref
      .read(tariffGridProvider)
      .estimate(
        straightLineKm: _pickup!.point.distanceKmTo(_dropoff!.point),
        kind: _kind,
        weight: _weight,
        slot: _slot,
        insuredValueAriary: int.tryParse(_value.text.replaceAll(' ', '')),
      );

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final delivery = await ref
          .read(deliveryRepositoryProvider)
          .createDelivery(
            DeliveryDraft(
              pickup: _pickup!,
              dropoff: _dropoff!,
              kind: _kind,
              package: PackageDeclaration(
                weight: _weight,
                lengthCm: int.tryParse(_length.text.trim()),
                widthCm: int.tryParse(_width.text.trim()),
                heightCm: int.tryParse(_height.text.trim()),
                declaredValueAriary: int.tryParse(
                  _value.text.replaceAll(' ', ''),
                ),
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
                photoId: _photoId,
              ),
              slot: _slot,
              paymentMethod: _payment,
              payer: _payer,
              shopping: _shopping,
              relayPointId: _relayPointId,
            ),
          );

      router.pop();
      // Le formulaire est retire de l'arbre au retour : le message doit etre
      // emis par le messenger racine pour rester visible sur la liste.
      MajiChronoApp.messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              delivery.pendingSync ? l10n.deliveryQueued : l10n.deliveryCreated,
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.localizedMessage(l10n)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final titles = [
      l10n.stepAddresses,
      l10n.stepPackage,
      l10n.stepOptions,
      l10n.stepReview,
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.newDeliveryTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          // Étapes
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                for (var i = 0; i < titles.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _ModernStepChip(
                      number: i + 1,
                      label: titles[i],
                      active: i <= _step,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildStep(l10n)),
          _BottomActionBar(
            label: _step == 3 ? l10n.confirmDelivery : l10n.commonContinue,
            busy: _busy,
            onPressed: !_canContinue
                ? null
                : () {
                    if (_step < 3) {
                      setState(() => _step++);
                    } else {
                      _submit();
                    }
                  },
            isLastStep: _step == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AppLocalizations l10n) => switch (_step) {
    0 => _AddressStep(
      pickup: _pickup,
      dropoff: _dropoff,
      onPickup: (a) => setState(() => _pickup = a),
      onDropoff: (a) => setState(() => _dropoff = a),
    ),
    1 => _PackageStep(
      kind: _kind,
      weight: _weight,
      slot: _slot,
      payment: _payment,
      value: _value,
      description: _description,
      length: _length,
      width: _width,
      height: _height,
      photoBytes: _photoBytes,
      uploadingPhoto: _uploadingPhoto,
      onPickPhoto: _pickPackagePhoto,
      onRemovePhoto: () => setState(() {
        _photoBytes = null;
        _photoId = null;
      }),
      onKind: (k) => setState(() => _kind = k),
      onWeight: (w) => setState(() => _weight = w),
      onSlot: (s) => setState(() => _slot = s),
      onPayment: (p) => setState(() => _payment = p),
    ),
    2 => DeliveryOptionsStep(
      kind: _kind,
      weight: _weight,
      dropoffDistrict: _dropoff?.district ?? '',
      dropoffPoint: _dropoff?.point,
      payer: _payer,
      items: _items,
      cap: _cap,
      storeHint: _storeHint,
      relayPointId: _relayPointId,
      onPayer: (p) => setState(() => _payer = p),
      onItems: (i) => setState(() => _items = i),
      onRelay: (id) => setState(() => _relayPointId = id),
    ),
    _ => _ReviewStep(
      pickup: _pickup!,
      dropoff: _dropoff!,
      kind: _kind,
      weight: _weight,
      slot: _slot,
      payment: _payment,
      estimate: _estimate,
    ),
  };
}

// ============================================================
// BARRE D'ACTION EN BAS
// ============================================================

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.label,
    required this.busy,
    required this.onPressed,
    required this.isLastStep,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final bool isLastStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLastStep ? AppColors.primary : AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLastStep && onPressed != null)
                const Icon(Icons.check, size: 20),
              if (isLastStep && onPressed != null) const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!isLastStep && onPressed != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ÉTAPE MODERNE
// ============================================================

class _ModernStepChip extends StatelessWidget {
  const _ModernStepChip({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ÉTAPE 1 : ADRESSES
// ============================================================

class _AddressStep extends ConsumerStatefulWidget {
  const _AddressStep({
    required this.pickup,
    required this.dropoff,
    required this.onPickup,
    required this.onDropoff,
  });

  final Address? pickup;
  final Address? dropoff;
  final ValueChanged<Address?> onPickup;
  final ValueChanged<Address?> onDropoff;

  @override
  ConsumerState<_AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends ConsumerState<_AddressStep> {
  late Address? _pickupSeed = widget.pickup;
  late Address? _dropoffSeed = widget.dropoff;
  // La cle ne change qu'au **choix d'une adresse enregistree** : c'est le seul
  // cas ou le formulaire doit se re-remplir. La saisie manuelle ne la touche
  // pas, sinon chaque frappe recreerait le formulaire et perdrait le focus.
  int _pickupKey = 0;
  int _dropoffKey = 0;

  @override
  void initState() {
    super.initState();
    ref.read(deliveryRepositoryProvider).fetchAddresses().ignore();
  }

  Future<void> _pickSaved({required bool isPickup}) async {
    final selected = await showModalBottomSheet<SavedAddress>(
      context: context,
      builder: (_) => const _SavedAddressPicker(),
    );
    if (selected == null) return;
    ref.read(deliveryRepositoryProvider).touchAddress(selected.id).ignore();
    setState(() {
      if (isPickup) {
        _pickupSeed = selected.address;
        _pickupKey++;
      } else {
        _dropoffSeed = selected.address;
        _dropoffKey++;
      }
    });
    (isPickup ? widget.onPickup : widget.onDropoff)(selected.address);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSaved =
        (ref.watch(addressBookProvider).valueOrNull ?? const []).isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ModernSectionHeader(
          title: l10n.addrPickupTitle,
          icon: Icons.trip_origin,
        ),
        if (hasSaved)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pickSaved(isPickup: true),
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: Text(l10n.addressPickSaved),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        AddressForm(
          key: ValueKey('pickup_$_pickupKey'),
          initial: _pickupSeed,
          onChanged: widget.onPickup,
        ),
        const SizedBox(height: AppSpacing.xl),
        _ModernSectionHeader(
          title: l10n.addrDropoffTitle,
          icon: Icons.place_outlined,
        ),
        if (hasSaved)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pickSaved(isPickup: false),
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: Text(l10n.addressPickSaved),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        AddressForm(
          key: ValueKey('dropoff_$_dropoffKey'),
          initial: _dropoffSeed,
          onChanged: widget.onDropoff,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Feuille de choix d'une adresse enregistree, alimentee par le carnet.
class _SavedAddressPicker extends ConsumerWidget {
  const _SavedAddressPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(addressBookProvider).valueOrNull ?? const [];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.addressPickSaved,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final entry in book)
            ListTile(
              leading: Icon(kindIcon(entry.kind)),
              title: Text(
                entry.label.isEmpty ? kindLabel(l10n, entry.kind) : entry.label,
              ),
              subtitle: Text(
                entry.address.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(entry),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION HEADER MODERNE
// ============================================================

class _ModernSectionHeader extends StatelessWidget {
  const _ModernSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ÉTAPE 2 : COLIS, CRÉNEAU, PAIEMENT
// ============================================================

/// Champ compact pour une dimension (cm), centre, clavier numerique.
class _DimField extends StatelessWidget {
  const _DimField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _PackageStep extends StatelessWidget {
  const _PackageStep({
    required this.kind,
    required this.weight,
    required this.slot,
    required this.payment,
    required this.value,
    required this.description,
    required this.length,
    required this.width,
    required this.height,
    required this.photoBytes,
    required this.uploadingPhoto,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onKind,
    required this.onWeight,
    required this.onSlot,
    required this.onPayment,
  });

  final DeliveryKind kind;
  final WeightCategory weight;
  final PickupSlot slot;
  final PaymentMethod payment;
  final TextEditingController value;
  final TextEditingController description;
  final TextEditingController length;
  final TextEditingController width;
  final TextEditingController height;
  final Uint8List? photoBytes;
  final bool uploadingPhoto;
  final ValueChanged<ImageSource> onPickPhoto;
  final VoidCallback onRemovePhoto;
  final ValueChanged<DeliveryKind> onKind;
  final ValueChanged<WeightCategory> onWeight;
  final ValueChanged<PickupSlot> onSlot;
  final ValueChanged<PaymentMethod> onPayment;

  void _choosePhotoSource(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profilePhotoFromCamera),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePhotoFromGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String kindLabel(DeliveryKind k) => switch (k) {
      DeliveryKind.standard => l10n.kindStandard,
      DeliveryKind.document => l10n.kindDocument,
      DeliveryKind.fragile => l10n.kindFragile,
      DeliveryKind.food => l10n.kindFood,
      DeliveryKind.shopping => l10n.kindShopping,
    };

    String weightLabel(WeightCategory w) => switch (w) {
      WeightCategory.upTo2 => l10n.pkgWeightLt2,
      WeightCategory.from2to5 => l10n.pkgWeight2to5,
      WeightCategory.from5to15 => l10n.pkgWeight5to15,
      WeightCategory.over15 => l10n.pkgWeightGt15,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernSectionHeader(
            title: l10n.kindTitle,
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in DeliveryKind.values)
                _ModernChoiceChip(
                  label: kindLabel(k),
                  selected: kind == k,
                  onTap: () => onKind(k),
                ),
            ],
          ),
          if (kind == DeliveryKind.shopping)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.shoppingHelp,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          _ModernSectionHeader(
            title: l10n.pkgWeight,
            icon: Icons.scale_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Column(
            children: [
              for (final w in WeightCategory.values)
                _ModernRadioTile(
                  label: weightLabel(w),
                  selected: weight == w,
                  onTap: () => onWeight(w),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${l10n.pkgValue} (${l10n.addrOptional})',
              prefixIcon: Icon(
                Icons.payments_outlined,
                color: AppColors.primary,
              ),
              suffixText: 'Ar',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: description,
            decoration: InputDecoration(
              labelText: '${l10n.pkgDescription} (${l10n.addrOptional})',
              prefixIcon: Icon(Icons.notes_outlined, color: AppColors.primary),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Dimensions (optionnelles), en centimetres.
          Text(
            '${l10n.pkgDimensions} (${l10n.addrOptional})',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DimField(controller: length, label: l10n.pkgLength),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DimField(controller: width, label: l10n.pkgWidth),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DimField(controller: height, label: l10n.pkgHeight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Photo du colis (EXI-C09), optionnelle : elle aide le livreur a
          // reconnaitre l'envoi et sert de preuve en cas de litige.
          if (photoBytes == null)
            OutlinedButton.icon(
              onPressed: () => _choosePhotoSource(context),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(l10n.pkgAddPhoto),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photoBytes!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (uploadingPhoto)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.check_circle, color: AppColors.success),
                const Spacer(),
                IconButton(
                  onPressed: onRemovePhoto,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),

          _ModernSectionHeader(
            title: l10n.slotTitle,
            icon: Icons.access_time_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.slotImmediate)),
              ButtonSegment(value: false, label: Text(l10n.slotScheduled)),
            ],
            selected: {slot.isImmediate},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
            ),
            onSelectionChanged: (selection) => onSlot(
              selection.first
                  ? const PickupSlot.immediate()
                  : PickupSlot.scheduled(
                      date: DateTime.now().add(const Duration(days: 1)),
                      hour: 8,
                    ),
            ),
          ),
          if (!slot.isImmediate) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hour in const [6, 8, 10, 12, 14, 16])
                  _ModernChoiceChip(
                    label: l10n.slotRange(hour, hour + 2),
                    selected: slot.startHour == hour,
                    onTap: () => onSlot(
                      PickupSlot.scheduled(
                        date:
                            slot.scheduledDate ??
                            DateTime.now().add(const Duration(days: 1)),
                        hour: hour,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          _ModernSectionHeader(
            title: l10n.paymentTitle,
            icon: Icons.payment_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModernRadioTile(
            label: l10n.paymentCash,
            selected: payment == PaymentMethod.cash,
            onTap: () => onPayment(PaymentMethod.cash),
          ),
          _ModernRadioTile(
            label: l10n.paymentMajipay,
            subtitle: l10n.paymentMajipaySoon,
            selected: false,
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ============================================================
// CHOICE CHIP MODERNE
// ============================================================

class _ModernChoiceChip extends StatelessWidget {
  const _ModernChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outlineVariant,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RADIO TILE MODERNE
// ============================================================

class _ModernRadioTile extends StatelessWidget {
  const _ModernRadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? AppColors.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

// ============================================================
// ÉTAPE 3 : RÉCAPITULATIF
// ============================================================

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.pickup,
    required this.dropoff,
    required this.kind,
    required this.weight,
    required this.slot,
    required this.payment,
    required this.estimate,
  });

  final Address pickup;
  final Address dropoff;
  final DeliveryKind kind;
  final WeightCategory weight;
  final PickupSlot slot;
  final PaymentMethod payment;
  final PriceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Récapitulatif des adresses
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _ReviewItem(
                  icon: Icons.trip_origin,
                  title: pickup.summary,
                  subtitle: pickup.contactPhone.displayNational,
                  iconColor: Colors.green.shade600,
                ),
                const Divider(height: 1, indent: 56),
                _ReviewItem(
                  icon: Icons.place_outlined,
                  title: dropoff.summary,
                  subtitle: dropoff.contactPhone.displayNational,
                  iconColor: Colors.blue.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Détails de la course
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.estimateTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PriceBreakdown(estimate: estimate),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ============================================================
// ÉLÉMENT DE RÉCAPITULATIF
// ============================================================

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
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
