import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_primary_action.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Dossier de verification du livreur (EXI-L01, EXI-L02).
///
/// Le dossier est **bloquant** : aucune course ne peut etre executee tant qu'il
/// n'est pas valide. Chaque piece se prend en photo (galerie ou appareil), et le
/// dossier ne se soumet que **complet** — c'est le serveur qui l'exige, l'ecran
/// ne fait que le refleter.
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _picker = ImagePicker();
  String? _busyKind;
  bool _submitting = false;

  /// Icone et libelle de chaque piece, par sa cle serveur.
  (IconData, String) _describe(AppLocalizations l10n, String kind) =>
      switch (kind) {
        'cin_front' => (Icons.badge_outlined, l10n.kycDocCinFront),
        'cin_back' => (Icons.badge_outlined, l10n.kycDocCinBack),
        'licence' => (Icons.card_membership_outlined, l10n.kycDocLicence),
        'selfie' => (Icons.face_outlined, l10n.kycDocSelfie),
        'registration' => (Icons.description_outlined, l10n.kycDocRegistration),
        'vehicle' => (Icons.two_wheeler_outlined, l10n.kycDocVehicle),
        'plate' => (Icons.pin_outlined, l10n.kycDocPlate),
        _ => (Icons.insert_drive_file_outlined, kind),
      };

  Future<void> _capture(String kind, ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _busyKind = kind);
    try {
      await ref
          .read(driverActionsProvider)
          .uploadKycDocument(
            kind: kind,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
    } on Failure catch (failure) {
      _snack(failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<void> _remove(String kind) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busyKind = kind);
    try {
      await ref.read(driverActionsProvider).deleteKycDocument(kind);
    } on Failure catch (failure) {
      _snack(failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  void _pickSource(String kind) {
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
                _capture(kind, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePhotoFromGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _capture(kind, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(driverActionsProvider).submitKyc();
      _snack(l10n.kycSubmitted);
    } on Failure catch (failure) {
      _snack(failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dossier = ref.watch(kycDossierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kycTitle)),
      body: dossier.when(
        loading: () => const McSkeletonList(itemCount: 3),
        error: (_, _) => Center(child: Text(l10n.errorNetwork)),
        data: (data) {
          final kyc = KycStatus.fromWire(data.status) ?? KycStatus.draft;
          final locked =
              kyc == KycStatus.submitted ||
              kyc == KycStatus.underReview ||
              kyc == KycStatus.approved;

          final (color, label) = switch (kyc) {
            KycStatus.draft => (AppColors.warning, l10n.kycStatusDraft),
            KycStatus.submitted => (AppColors.info, l10n.kycStatusSubmitted),
            KycStatus.underReview => (AppColors.info, l10n.kycStatusUnderReview),
            KycStatus.approved => (AppColors.success, l10n.kycStatusApproved),
            KycStatus.rejected => (AppColors.danger, l10n.kycStatusRejected),
          };

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                color: color.withValues(alpha: 0.10),
                child: Padding(
                  padding: AppSpacing.card,
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: color),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: theme.textTheme.titleMedium),
                            if (kyc != KycStatus.approved) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                locked
                                    ? l10n.kycUnderReviewHelp
                                    : l10n.kycProgress(
                                        data.uploaded.length,
                                        data.documents.length,
                                      ),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Column(
                  children: [
                    for (final kind in data.documents) ...[
                      _DocTile(
                        describe: _describe(l10n, kind),
                        captured: data.uploaded.contains(kind),
                        busy: _busyKind == kind,
                        locked: locked,
                        onCapture: () => _pickSource(kind),
                        onRemove: () => _remove(kind),
                      ),
                      if (kind != data.documents.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Informations structurees du vehicule (§22), en complement des
              // pieces ci-dessus.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.two_wheeler_outlined),
                  title: Text(l10n.vehicleManage),
                  subtitle: Text(l10n.vehicleManageHelp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.driverVehicle),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Contact avec l'exploitation pour suivre la validation du dossier.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(l10n.kycFollowupManage),
                  subtitle: Text(l10n.kycFollowupHelp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.kycFollowup),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: dossier.maybeWhen(
        data: (data) {
          final kyc = KycStatus.fromWire(data.status) ?? KycStatus.draft;
          final canSubmit =
              data.isComplete &&
              (kyc == KycStatus.draft || kyc == KycStatus.rejected);
          return McPrimaryAction(
            label: l10n.kycSubmit,
            icon: Icons.send_outlined,
            busy: _submitting,
            onPressed: canSubmit && !_submitting ? _submit : null,
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.describe,
    required this.captured,
    required this.busy,
    required this.locked,
    required this.onCapture,
    required this.onRemove,
  });

  final (IconData, String) describe;
  final bool captured;
  final bool busy;
  final bool locked;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, name) = describe;

    return ListTile(
      leading: Icon(
        icon,
        color: captured ? AppColors.success : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(name),
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : captured
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                if (!locked)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
              ],
            )
          : const Icon(Icons.add_a_photo_outlined),
      onTap: locked || captured ? null : onCapture,
    );
  }
}
