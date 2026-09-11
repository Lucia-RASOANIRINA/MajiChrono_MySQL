import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Fiche vehicule structuree du livreur (§22).
///
/// Complementaire du dossier KYC (qui porte les pieces) : ici les informations.
/// Toute modification remet la validation en attente — on l'annonce, pour que le
/// livreur sache pourquoi son vehicule repasse « en attente » apres une retouche.
class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(vehicleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleTitle)),
      body: vehicle.when(
        loading: () => const McSkeletonList(itemCount: 4),
        error: (_, _) => Center(child: Text(l10n.errorNetwork)),
        data: (v) => _VehicleForm(vehicle: v),
      ),
    );
  }
}

class _VehicleForm extends ConsumerStatefulWidget {
  const _VehicleForm({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<_VehicleForm> {
  late VehicleType _type;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _plate;
  late final TextEditingController _insurance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _type = v.type ?? VehicleType.moto;
    _brand = TextEditingController(text: v.brand ?? '');
    _model = TextEditingController(text: v.model ?? '');
    _plate = TextEditingController(text: v.plate ?? '');
    _insurance = TextEditingController(text: v.insuranceExpiry ?? '');
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _plate.dispose();
    _insurance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(driverActionsProvider)
          .saveVehicle(
            type: _type,
            brand: _brand.text.trim(),
            model: _model.text.trim(),
            plate: _plate.text.trim(),
            insuranceExpiry: _insurance.text.trim(),
          );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleSaved)));
    } on Failure catch (failure) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _typeLabel(AppLocalizations l10n, VehicleType t) => switch (t) {
    VehicleType.moto => l10n.vehicleTypeMoto,
    VehicleType.bicycle => l10n.vehicleTypeBicycle,
    VehicleType.car => l10n.vehicleTypeCar,
    VehicleType.tricycle => l10n.vehicleTypeTricycle,
  };

  (String, McStatusTone, IconData) _validationView(
    AppLocalizations l10n,
    VehicleValidation v,
  ) => switch (v) {
    VehicleValidation.validated => (
      l10n.vehicleValidationValidated,
      McStatusTone.success,
      Icons.verified_outlined,
    ),
    VehicleValidation.rejected => (
      l10n.vehicleValidationRejected,
      McStatusTone.danger,
      Icons.cancel_outlined,
    ),
    VehicleValidation.pending => (
      l10n.vehicleValidationPending,
      McStatusTone.warning,
      Icons.hourglass_empty,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (statusLabel, statusTone, statusIcon) = _validationView(
      l10n,
      widget.vehicle.validation,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (!widget.vehicle.isEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: McStatusBadge(
              label: statusLabel,
              icon: statusIcon,
              tone: statusTone,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        DropdownButtonFormField<VehicleType>(
          initialValue: _type,
          decoration: InputDecoration(labelText: l10n.vehicleType),
          items: [
            for (final t in VehicleType.values)
              DropdownMenuItem(value: t, child: Text(_typeLabel(l10n, t))),
          ],
          onChanged: (t) => setState(() => _type = t ?? _type),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _brand,
          decoration: InputDecoration(labelText: l10n.vehicleBrand),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _model,
          decoration: InputDecoration(labelText: l10n.vehicleModel),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _plate,
          decoration: InputDecoration(labelText: l10n.vehiclePlate),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _insurance,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(labelText: l10n.vehicleInsurance),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.info),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.vehicleRevalidateNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: AppSizes.minTouchTarget,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.vehicleSave),
          ),
        ),
      ],
    );
  }
}
