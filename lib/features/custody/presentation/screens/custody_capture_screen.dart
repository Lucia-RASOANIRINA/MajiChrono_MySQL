import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/security/device_integrity.dart';
import 'package:majichrono/core/security/secure_screen.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/custody/data/services/photo_pipeline.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/custody_export.dart';
import 'package:majichrono/features/custody/presentation/providers/custody_providers.dart';
import 'package:majichrono/features/custody/presentation/screens/guided_camera_screen.dart';
import 'package:majichrono/features/custody/presentation/screens/seal_scan_screen.dart';
import 'package:majichrono/features/custody/presentation/widgets/signature_pad.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_primary_action.dart';

/// Saisie d'un constat contradictoire (§7.3).
///
/// L'ordre des sections suit le geste reel : on photographie le colis qu'on a
/// sous les yeux, on coche ce qu'on constate, on releve le scelle, puis on fait
/// signer. Demander la signature avant les photos obligerait a revenir en
/// arriere, et un constat qu'on refait est un constat qu'on bacle.
///
/// Le bouton de validation reste **desactive tant que le constat est
/// incomplet** (EXI-CC03), et l'ecran dit ce qui manque : un bouton grise sans
/// explication est le meilleur moyen de faire cocher n'importe quoi.
class CustodyCaptureScreen extends ConsumerStatefulWidget {
  const CustodyCaptureScreen({
    required this.delivery,
    required this.stage,
    super.key,
  });

  final Delivery delivery;
  final CustodyStage stage;

  @override
  ConsumerState<CustodyCaptureScreen> createState() =>
      _CustodyCaptureScreenState();
}

class _CustodyCaptureScreenState extends ConsumerState<CustodyCaptureScreen> {
  final Map<PhotoAngle, CustodyPhoto> _photos = {};
  final Set<ConditionCriterion> _checked = {};
  final TextEditingController _seal = TextEditingController();
  final TextEditingController _anomaly = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _thirdPartyName = TextEditingController();
  final TextEditingController _thirdPartyRelation = TextEditingController();

  late WeightCategory _weight = widget.delivery.package.weight;
  SealCheck? _sealCheck;

  /// Aucune valeur par defaut : « remis au destinataire » doit etre affirme, pas
  /// suppose. Une case pre-cochee ferait signer au livreur un recit qu'il n'a
  /// pas choisi (EXI-CC26 a EXI-CC29).
  HandoverOutcome? _outcome;

  /// Photos supplementaires, hors des quatre angles : le scelle rompu
  /// (EXI-CC22) et la piece justificative de l'issue (EXI-CC28, EXI-CC29).
  CustodyPhoto? _sealPhoto;
  CustodyPhoto? _outcomePhoto;

  VectorSignature? _partySignature;
  VectorSignature? _driverSignature;
  bool _busy = false;

  @override
  void dispose() {
    _seal.dispose();
    _anomaly.dispose();
    _otp.dispose();
    _reason.dispose();
    _thirdPartyName.dispose();
    _thirdPartyRelation.dispose();
    super.dispose();
  }

  bool get _isHandover => widget.stage == CustodyStage.handover;

  /// Un scelle rompu ou absent impose une photo de plus (EXI-CC22).
  bool get _needsSealPhoto =>
      _isHandover && (_sealCheck?.requiresIncident ?? false);

  /// Piece d'identite du tiers, ou colis remis en main propre.
  bool get _needsOutcomePhoto =>
      _isHandover && (_outcome?.requiresExtraPhoto ?? false);

  /// La signature du destinataire disparait dans le seul mode degrade.
  bool get _needsPartySignature =>
      !_isHandover || (_outcome?.requiresRecipientSignature ?? true);

  bool get _needsOtp => _isHandover && (_outcome?.requiresOtp ?? false);

  /// Assemble le constat courant, complet ou non.
  CustodyReport _build() {
    final grid = ConditionGrid(_checked);
    final note = _anomaly.text.trim();

    // EXI-CC13 : le commentaire d'anomalie est porte par une photo, pour que la
    // preuve soit indissociable de son explication.
    final photos = _photos.values.map((photo) {
      if (!grid.hasAnomaly || note.isEmpty || photo.angle != PhotoAngle.top) {
        return photo;
      }
      return CustodyPhoto(
        angle: photo.angle,
        localPath: photo.localPath,
        takenAt: photo.takenAt,
        sizeBytes: photo.sizeBytes,
        sha256: photo.sha256,
        point: photo.point,
        anomalyNote: note,
      );
    }).toList();

    // Les pieces supplementaires ne sont jointes que lorsqu'elles sont exigees :
    // une photo de scelle conservee apres correction du choix induirait le
    // lecteur du constat en erreur.
    if (_needsSealPhoto && _sealPhoto != null) photos.add(_sealPhoto!);
    if (_needsOutcomePhoto && _outcomePhoto != null) photos.add(_outcomePhoto!);

    final reason = _reason.text.trim();
    final thirdName = _thirdPartyName.text.trim();
    final thirdRelation = _thirdPartyRelation.text.trim();

    return CustodyReport(
      id: const Uuid().v4(),
      deliveryId: widget.delivery.id,
      stage: widget.stage,
      photos: photos,
      grid: grid,
      sealNumber: _seal.text.trim(),
      weight: _weight,
      signatures: [
        if (_needsPartySignature) ?_partySignature,
        ?_driverSignature,
      ],
      capturedAt: DateTime.now(),
      point: _isHandover
          ? widget.delivery.dropoff.point
          : widget.delivery.pickup.point,
      sealCheck: _isHandover ? _sealCheck : null,
      outcome: _isHandover ? _outcome : null,
      reserveReason: reason.isEmpty ? null : reason,
      thirdPartyName: thirdName.isEmpty ? null : thirdName,
      thirdPartyRelation: thirdRelation.isEmpty ? null : thirdRelation,
      otpVerified: _needsOtp && _otp.text.trim().length == 6,
    );
  }

  Future<CustodyPhoto?> _capture({
    required PhotoAngle angle,
    required String fileName,
    String? note,
  }) async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => GuidedCameraScreen(angle: angle)),
    );
    if (bytes == null || !mounted) return null;

    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(root.path, 'custody', widget.delivery.id, widget.stage.wireName),
    );

    return const PhotoPipeline().process(
      raw: bytes,
      angle: angle,
      directory: directory,
      fileName: fileName,
      takenAt: DateTime.now(),
      point: _isHandover
          ? widget.delivery.dropoff.point
          : widget.delivery.pickup.point,
      anomalyNote: note,
    );
  }

  /// Lecture du code-barres du scelle (EXI-CC14).
  Future<void> _scanSeal() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SealScanScreen()));
    if (code == null || !mounted) return;
    setState(() => _seal.text = code);
  }

  Future<void> _takePhoto(PhotoAngle angle) async {
    final photo = await _capture(angle: angle, fileName: angle.wireName);
    if (photo != null && mounted) setState(() => _photos[angle] = photo);
  }

  /// Photo du scelle rompu ou absent (EXI-CC22).
  Future<void> _takeSealPhoto(String note) async {
    final photo = await _capture(
      angle: PhotoAngle.top,
      fileName: 'seal_incident',
      note: note,
    );
    if (photo != null && mounted) setState(() => _sealPhoto = photo);
  }

  /// Piece justificative de l'issue : identite du tiers (EXI-CC28) ou colis
  /// remis en main propre (EXI-CC29).
  Future<void> _takeOutcomePhoto(String note) async {
    final photo = await _capture(
      angle: PhotoAngle.top,
      fileName: 'outcome_${_outcome?.wireName ?? 'extra'}',
      note: note,
    );
    if (photo != null && mounted) setState(() => _outcomePhoto = photo);
  }

  Future<void> _validate() async {
    final report = _build();
    if (!report.isComplete || _busy) return;

    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final sealed = await ref
          .read(custodyActionsProvider)
          .sealAndSubmit(report);

      // L'export est propose la, sur le constat encore complet en memoire :
      // c'est le seul moment ou les traces de signature sont sous la main sans
      // relecture du stockage (EXI-CC32).
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.custodySealed),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.custodyExportPdf,
            // Le contexte du Navigator, et non celui de cet ecran : l'ecran est
            // ferme juste apres, et une action qui s'appuierait sur un widget
            // demonte echouerait au moment ou l'on clique.
            onPressed: () => exportCustodyPdf(
              navigator.context,
              report: sealed,
              delivery: widget.delivery,
            ),
          ),
        ),
      );
      navigator.pop(sealed);
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
    final report = _build();

    String criterionLabel(ConditionCriterion c) => switch (c) {
      ConditionCriterion.packagingIntact => l10n.conditionPackagingIntact,
      ConditionCriterion.impactMark => l10n.conditionImpactMark,
      ConditionCriterion.moistureMark => l10n.conditionMoistureMark,
      ConditionCriterion.alreadyOpened => l10n.conditionAlreadyOpened,
      ConditionCriterion.originalTapePresent => l10n.conditionOriginalTape,
      ConditionCriterion.crushedCorners => l10n.conditionCrushedCorners,
    };

    // EXI-SEC06 : un constat en cours porte des photos de colis, deux
    // signatures et une position. Rien de tout cela ne doit passer par une
    // capture d'ecran.
    return SecureScreen(
      surface: SecureSurface.custodyCapture,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isHandover ? l10n.custodyHandoverTitle : l10n.custodyPickupTitle,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // --- Photos guidees ---------------------------------------------
            Text(l10n.custodyStepPhotos, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              children: [
                for (final angle in PhotoAngle.values)
                  _PhotoSlot(
                    angle: angle,
                    photo: _photos[angle],
                    onTap: () => _takePhoto(angle),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.custodyPhotoInAppOnly,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // --- Grille d'etat ------------------------------------------------
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.custodyConditionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.custodyConditionHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in ConditionCriterion.values)
                  FilterChip(
                    label: Text(criterionLabel(c)),
                    selected: _checked.contains(c),
                    // Couleur **et** libelle : la couleur seule serait illisible
                    // en plein soleil (EXI-T09).
                    selectedColor: c.positive
                        ? AppColors.success.withValues(alpha: 0.20)
                        : AppColors.danger.withValues(alpha: 0.20),
                    onSelected: (on) => setState(
                      () => on ? _checked.add(c) : _checked.remove(c),
                    ),
                  ),
              ],
            ),
            if (report.grid.hasAnomaly) ...[
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _anomaly,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.custodyAnomalyNote,
                  prefixIcon: const Icon(Icons.report_problem_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            // --- Scelle -------------------------------------------------------
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.custodyStepSeal, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _seal,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.custodySealNumber,
                hintText: l10n.custodySealHint,
                prefixIcon: const Icon(Icons.qr_code_2_outlined),
                // EXI-CC14 : le scan **remplit** le champ, il ne le remplace
                // pas. Une etiquette sale se lit parfois de travers, et un
                // numero faux vaut moins qu'un numero saisi a la main.
                suffixIcon: IconButton(
                  icon: const Icon(Icons.barcode_reader),
                  tooltip: l10n.custodySealScan,
                  onPressed: _scanSeal,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_isHandover) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.custodySealCheck, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<SealCheck>(
                segments: [
                  ButtonSegment(
                    value: SealCheck.intact,
                    label: Text(l10n.sealIntact),
                  ),
                  ButtonSegment(
                    value: SealCheck.broken,
                    label: Text(l10n.sealBroken),
                  ),
                  ButtonSegment(
                    value: SealCheck.absent,
                    label: Text(l10n.sealAbsent),
                  ),
                ],
                selected: _sealCheck == null ? {} : {_sealCheck!},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _sealCheck = s.isEmpty ? null : s.first),
              ),
              if (_needsSealPhoto) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.custodySealIncident)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // EXI-CC22 : le scelle rompu se photographie. Sans cette image, la
                // rupture ne serait qu'une affirmation.
                _ExtraPhotoTile(
                  label: l10n.custodyExtraPhotoSeal,
                  missingLabel: l10n.custodyExtraPhotoMissing,
                  photo: _sealPhoto,
                  onTap: () => _takeSealPhoto(l10n.custodyExtraPhotoSeal),
                ),
              ],
            ],

            // --- Poids confirme (EXI-CC15) ------------------------------------
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.custodyWeightConfirm, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final w in WeightCategory.values)
                  ChoiceChip(
                    label: Text(switch (w) {
                      WeightCategory.upTo2 => l10n.pkgWeightLt2,
                      WeightCategory.from2to5 => l10n.pkgWeight2to5,
                      WeightCategory.from5to15 => l10n.pkgWeight5to15,
                      WeightCategory.over15 => l10n.pkgWeightGt15,
                    }),
                    selected: _weight == w,
                    onSelected: (_) => setState(() => _weight = w),
                  ),
              ],
            ),

            // --- Issue de la remise (EXI-CC26 a EXI-CC29) ---------------------
            if (_isHandover) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.custodyOutcomeTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.custodyOutcomeHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Une liste verticale, pas des puces cote a cote : les cinq issues
              // ont des consequences differentes, et un livreur qui vise a une
              // main sur un ecran ensoleille ne doit pas pouvoir se tromper de
              // quelques pixels entre « remis » et « refuse ».
              RadioGroup<HandoverOutcome>(
                groupValue: _outcome,
                onChanged: (value) => setState(() {
                  _outcome = value;
                  // Changer d'issue invalide la piece justificative de la
                  // precedente : une photo de piece d'identite n'a rien a faire
                  // dans un constat de refus.
                  _outcomePhoto = null;
                }),
                child: Column(
                  children: [
                    for (final outcome in HandoverOutcome.values)
                      RadioListTile<HandoverOutcome>(
                        value: outcome,
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (outcome) {
                          HandoverOutcome.delivered => l10n.outcomeDelivered,
                          HandoverOutcome.withReserves =>
                            l10n.outcomeWithReserves,
                          HandoverOutcome.refused => l10n.outcomeRefused,
                          HandoverOutcome.thirdParty => l10n.outcomeThirdParty,
                          HandoverOutcome.noSignature =>
                            l10n.outcomeNoSignature,
                        }),
                      ),
                  ],
                ),
              ),

              if (_outcome != null) ...[
                // Consequence annoncee avant validation : le livreur doit savoir
                // ce qu'il declenche, pas le decouvrir apres coup.
                if (_outcome!.opensDispute)
                  _OutcomeNotice(
                    icon: Icons.gavel_outlined,
                    color: AppColors.warning,
                    text: l10n.custodyReservesNotice,
                  ),
                if (_outcome == HandoverOutcome.refused)
                  _OutcomeNotice(
                    icon: Icons.undo_outlined,
                    color: AppColors.warning,
                    text: l10n.custodyRefusedNotice,
                  ),
                if (_outcome == HandoverOutcome.noSignature)
                  _OutcomeNotice(
                    icon: Icons.campaign_outlined,
                    color: AppColors.danger,
                    text: l10n.custodyNoSignatureNotice,
                  ),
              ],

              // Motif ecrit : reserves, refus, absence de signature (EXI-CC26,
              // CC27, CC29).
              if (_outcome?.requiresReason ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _reason,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.custodyOutcomeReason,
                    helperText: l10n.custodyOutcomeReasonHelp,
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              // Identite du tiers **et** lien avec le destinataire (EXI-CC28) :
              // c'est le lien qui rend la remise opposable.
              if (_outcome == HandoverOutcome.thirdParty) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _thirdPartyName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.custodyThirdPartyName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _thirdPartyRelation,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.custodyThirdPartyRelation,
                    hintText: l10n.custodyThirdPartyRelationHint,
                    prefixIcon: const Icon(Icons.link_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              if (_needsOutcomePhoto) ...[
                const SizedBox(height: AppSpacing.md),
                Builder(
                  builder: (_) {
                    final label = _outcome == HandoverOutcome.thirdParty
                        ? l10n.custodyExtraPhotoId
                        : l10n.custodyExtraPhotoHandover;
                    return _ExtraPhotoTile(
                      label: label,
                      missingLabel: l10n.custodyExtraPhotoMissing,
                      photo: _outcomePhoto,
                      onTap: () => _takeOutcomePhoto(label),
                    );
                  },
                ),
              ],
            ],

            // --- Code OTP du destinataire (EXI-CC24) --------------------------
            if (_needsOtp) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.custodyOtpTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.custodyOtpHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 8),
                decoration: const InputDecoration(counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ],

            // --- Signatures ----------------------------------------------------
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.custodyStepSignatures,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            // EXI-CC29 : dans le mode degrade, le pad du destinataire disparait
            // plutot que de rester vide. Un cadre de signature laisse vide invite
            // a le faire remplir par n'importe qui.
            if (_needsPartySignature) ...[
              SignaturePad(
                signerLabel: _isHandover
                    ? l10n.custodySignerRecipient
                    : l10n.custodySignerSender,
                onChanged: (s) => setState(() => _partySignature = s),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            SignaturePad(
              signerLabel: l10n.custodySignerDriver,
              onChanged: (s) => setState(() => _driverSignature = s),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (!report.isComplete)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: AppSpacing.card,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(l10n.custodyIncomplete)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: McPrimaryAction.driver(
          label: l10n.custodyValidate,
          icon: Icons.lock_outline,
          busy: _busy,
          // EXI-CC03 : le statut ne peut pas progresser sans constat complet.
          onPressed: report.isComplete ? _validate : null,
        ),
      ),
    );
  }
}

/// Consequence annoncee d'une issue de remise.
class _OutcomeNotice extends StatelessWidget {
  const _OutcomeNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// Photo supplementaire imposee par le scelle ou par l'issue de la remise.
class _ExtraPhotoTile extends StatelessWidget {
  const _ExtraPhotoTile({
    required this.label,
    required this.missingLabel,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final String missingLabel;
  final CustodyPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = photo != null;
    final file = taken ? File(photo!.localPath) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.componentAll,
      child: Container(
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          borderRadius: AppRadii.componentAll,
          border: Border.all(
            color: taken ? AppColors.success : AppColors.danger,
            width: taken ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: file != null && file.existsSync()
                  ? ClipRRect(
                      borderRadius: AppRadii.componentAll,
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : Icon(
                      Icons.add_a_photo_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  Text(
                    taken ? '' : missingLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            if (taken) const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

/// Emplacement d'une photo d'angle.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.angle,
    required this.photo,
    required this.onTap,
  });

  final PhotoAngle angle;
  final CustodyPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final label = switch (angle) {
      PhotoAngle.top => l10n.custodyPhotoTop,
      PhotoAngle.bottom => l10n.custodyPhotoBottom,
      PhotoAngle.side1 => l10n.custodyPhotoSide1,
      PhotoAngle.side2 => l10n.custodyPhotoSide2,
    };

    final file = photo == null ? null : File(photo!.localPath);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.componentAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.componentAll,
          border: Border.all(
            color: photo == null
                ? theme.colorScheme.outline
                : AppColors.success,
            width: photo == null ? 1 : 2,
          ),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null && file.existsSync()
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.success,
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(label, style: theme.textTheme.bodyMedium),
                ],
              ),
      ),
    );
  }
}
