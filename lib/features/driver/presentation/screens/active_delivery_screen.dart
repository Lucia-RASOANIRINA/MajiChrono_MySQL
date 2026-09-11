import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/screens/custody_capture_screen.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/custody/presentation/widgets/custody_proof_action.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_screen.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/features/driver/presentation/screens/grouped_route_screen.dart';
import 'package:majichrono/features/driver/presentation/widgets/emergency_button.dart';
import 'package:majichrono/features/driver/presentation/widgets/shopping_receipt_card.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_primary_action.dart';

/// Execution d'une course par le livreur (EXI-L08).
///
/// Un seul bouton, pleine largeur, 64 dp, portant le libelle de **l'action
/// suivante** et rien d'autre (§15.3). C'est la contrainte la plus forte du
/// parcours livreur : trois gestes par etape au maximum (§15.2.2), avec un
/// telephone tenu d'une main, moto a l'arret, parfois sous la pluie.
class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  const ActiveDeliveryScreen({required this.deliveryId, super.key});

  final String deliveryId;

  @override
  ConsumerState<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen> {
  bool _busy = false;

  Future<void> _advance(Delivery delivery, DriverAction action) async {
    if (_busy) return;

    // EXI-CC03 : le statut ne progresse pas tant que le constat de l'etape
    // n'est pas complet. La verification passe par l'ecran de constat, qui ne
    // rend la main qu'une fois le document scelle — un retour vide signifie que
    // le livreur a renonce, et la course reste ou elle est.
    if (action.requiresCustodyReport) {
      final sealed = await Navigator.of(context).push<CustodyReport>(
        MaterialPageRoute(
          builder: (_) => CustodyCaptureScreen(
            delivery: delivery,
            stage: action == DriverAction.pickedUp
                ? CustodyStage.pickup
                : CustodyStage.handover,
          ),
        ),
      );
      if (sealed == null || !mounted) return;
    }

    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(driverActionsProvider).advance(delivery, action);
    } on ConflictFailure catch (failure) {
      // Le serveur fait foi (EXI-S04) : on affiche son etat plutot que de
      // laisser le livreur re-appuyer sur un bouton qui ne passera pas.
      messenger.showSnackBar(
        SnackBar(content: Text(failure.currentState ?? l10n.errorConflict)),
      );
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Delegue l'itineraire a l'application cartographique installee (EXI-L07).
  ///
  /// L'exigence est de deleguer, pas de reimplementer : un livreur connait deja
  /// son application de navigation, ses raccourcis et ses cartes hors ligne.
  Future<void> _navigate(Delivery delivery) async {
    final target =
        delivery.status == DeliveryStatus.accepted ||
            delivery.status == DeliveryStatus.atPickup
        ? delivery.pickup.point
        : delivery.dropoff.point;

    final uri = Uri.parse(
      'geo:${target.latitude},${target.longitude}'
      '?q=${target.latitude},${target.longitude}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Appelle le contact de l'etape en cours (EXI-L07, §17).
  ///
  /// A Antananarivo, le telephone reste le premier outil de coordination : un
  /// livreur appelle pour se faire ouvrir un portail bien plus souvent qu'il ne
  /// consulte une carte.
  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deliveries = ref.watch(deliveriesProvider).valueOrNull;
    final delivery = deliveries
        ?.where((d) => d.id == widget.deliveryId)
        .firstOrNull;

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.driverActiveDelivery)),
        body: McEmptyState(
          icon: Icons.inventory_2_outlined,
          title: l10n.emptyDeliveries,
          message: l10n.errorUnknown,
        ),
      );
    }

    final action = DriverAction.nextFor(delivery.status);

    String label(DriverAction a) => switch (a) {
      DriverAction.arrivedAtPickup => l10n.driverStepArrivedPickup,
      DriverAction.pickedUp => l10n.driverStepPickedUp,
      DriverAction.arrivedAtDestination => l10n.driverStepArrivedDestination,
      DriverAction.delivered => l10n.driverStepDelivered,
    };

    final target =
        delivery.status == DeliveryStatus.accepted ||
            delivery.status == DeliveryStatus.atPickup
        ? delivery.pickup
        : delivery.dropoff;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.driverActiveDelivery),
        actions: [
          // Discussion avec l'expediteur, disponible pendant toute la course.
          // On transmet son contact : son nom titre l'ecran, son numero ouvre
          // l'appel direct depuis l'en-tete de la discussion.
          IconButton(
            tooltip: l10n.chatTitle,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push(
              AppRoutes.chat(delivery.id),
              extra: (
                delivery.pickup.contactName,
                delivery.pickup.contactPhone.e164,
              ),
            ),
          ),
          // L'encaissement n'apparait qu'une fois le colis remis : proposer de
          // se faire payer avant d'avoir livre inverserait l'ordre des choses
          // et exposerait le client.
          if (delivery.paymentMethod == PaymentMethod.majipay &&
              (delivery.status == DeliveryStatus.delivered ||
                  delivery.status == DeliveryStatus.deliveredWithReserves))
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: l10n.payCollect,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentScreen(delivery: delivery, role: UserRole.driver),
                ),
              ),
            ),
          // Le parcours groupe n'apparait que lorsqu'il y a un groupe : un
          // bouton qui mene a une liste d'une seule course serait un detour.
          if (ref.watch(activeGroupProvider) != null)
            IconButton(
              icon: const Icon(Icons.route_outlined),
              tooltip: l10n.groupTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GroupedRouteScreen(group: ref.read(activeGroupProvider)!),
                ),
              ),
            ),
          // Le livreur relit ses propres constats : c'est ce qui lui permet de
          // contester une reclamation avec la preuve qu'il a lui-meme etablie.
          CustodyProofAction(delivery: delivery),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(status: delivery.status),
                  const SizedBox(height: AppSpacing.md),
                  // L'adresse affichee est celle de l'etape en cours, et non les
                  // deux : le livreur n'a besoin que de sa destination immediate.
                  Text(target.landmark, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    target.district,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigate(delivery),
                          icon: const Icon(Icons.navigation_outlined),
                          label: Text(l10n.driverNavigate),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.outlined(
                        onPressed: () => _call(target.contactPhone.e164),
                        icon: const Icon(Icons.phone_outlined),
                        tooltip: l10n.driverCall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (action?.requiresCustodyReport ?? false)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: AppSpacing.card,
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        // EXI-CC03 : le statut ne progressera pas sans constat.
                        // On l'annonce avant, pour que l'etape ne surprenne pas
                        // le livreur au moment ou il tient le colis.
                        l10n.driverCustodyRequired,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // EXI-C07 : la liste et le plafond restent sous les yeux du livreur
          // pendant toute la course, pas seulement a l'acceptation.
          if (delivery.kind == DeliveryKind.shopping) ...[
            const SizedBox(height: AppSpacing.lg),
            ShoppingReceiptCard(delivery: delivery),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => _showIncidentSheet(context, delivery),
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(l10n.driverIncident),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
          ),
          _IncidentHistory(deliveryId: delivery.id),
          const SizedBox(height: AppSpacing.md),
          // EXI-L13, D10. Volontairement **sous** le signalement d'incident et
          // visuellement distinct : ce sont deux gestes differents. Un incident
          // se motive et se met en file ; une urgence part tout de suite. Les
          // confondre ferait porter a l'une la prudence de l'autre.
          EmergencyButton(deliveryId: delivery.id),
        ],
      ),
      bottomNavigationBar: action == null
          ? null
          : McPrimaryAction.driver(
              label: label(action),
              busy: _busy,
              icon: Icons.check_circle_outline,
              onPressed: () => _advance(delivery, action),
            ),
    );
  }

  /// Signalement d'incident (EXI-L14, §19).
  ///
  /// Chaque motif affiche **sa consequence** : l'exigence demande que la suite
  /// soit definie, et un livreur planté devant un portail a besoin de savoir ce
  /// qui se passe ensuite, pas seulement d'avoir coche une case. Le choix ouvre
  /// un formulaire — description, photo, position — qui **envoie vraiment** le
  /// signalement, la ou l'ancienne feuille se contentait de se refermer.
  void _showIncidentSheet(BuildContext context, Delivery delivery) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              Text(
                l10n.driverIncident,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final type in IncidentType.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.report_problem_outlined),
                  title: Text(incidentTypeLabel(l10n, type)),
                  subtitle: Text(incidentOutcomeLabel(l10n, type.outcome)),
                  trailing: const Icon(Icons.chevron_right),
                  // Le choix ferme la feuille et ouvre un ecran plein — un
                  // formulaire tient mieux sur une page que dans une feuille qui
                  // se redimensionne.
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            IncidentReportScreen(delivery: delivery, type: type),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Rappel des incidents deja signales sur la course, avec leur statut de
/// resolution (§19). Absent tant qu'il n'y en a aucun : une section vide
/// n'apprendrait rien.
class _IncidentHistory extends ConsumerWidget {
  const _IncidentHistory({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final incidents =
        ref.watch(deliveryIncidentsProvider(deliveryId)).valueOrNull ??
        const [];
    if (incidents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.incidentHistoryTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final incident in incidents)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        incident.resolution == IncidentResolution.resolved
                            ? Icons.check_circle_outline
                            : Icons.schedule,
                        size: 18,
                        color:
                            incident.resolution == IncidentResolution.resolved
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incidentTypeLabel(l10n, incident.type),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              incident.resolution ==
                                      IncidentResolution.resolved
                                  ? l10n.incidentResolutionResolved
                                  : l10n.incidentResolutionOpen,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (incident.description != null &&
                                incident.description!.isNotEmpty)
                              Text(
                                incident.description!,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libelle d'un type d'incident (§19), partage entre la feuille et l'historique.
String incidentTypeLabel(AppLocalizations l10n, IncidentType type) =>
    switch (type) {
      IncidentType.senderAbsent => l10n.incidentSenderAbsent,
      IncidentType.recipientAbsent => l10n.incidentRecipientAbsent,
      IncidentType.addressIncorrect => l10n.incidentAddressIncorrect,
      IncidentType.packageDamaged => l10n.incidentPackageDamaged,
      IncidentType.packageRefused => l10n.incidentPackageRefused,
      IncidentType.accident => l10n.incidentAccident,
      IncidentType.gpsProblem => l10n.incidentGpsProblem,
      IncidentType.vehicleProblem => l10n.incidentVehicleProblem,
      IncidentType.paymentProblem => l10n.incidentPaymentProblem,
      IncidentType.other => l10n.incidentOther,
    };

String incidentOutcomeLabel(AppLocalizations l10n, IncidentOutcome o) =>
    switch (o) {
      IncidentOutcome.waitThenReturn => l10n.outcomeWaitThenReturn,
      IncidentOutcome.contactSupport => l10n.outcomeContactSupport,
      IncidentOutcome.returnToSender => l10n.outcomeReturnToSender,
      IncidentOutcome.reassign => l10n.outcomeReassign,
      IncidentOutcome.documentThenContinue => l10n.outcomeDocumentThenContinue,
    };

/// Ecran plein de signalement d'incident (§19) : le motif est deja choisi ; on
/// saisit une description, une photo facultative et la position best-effort,
/// puis on envoie vraiment. Une page — et non une feuille qui se redimensionne —
/// garantit que l'en-tete et le bouton d'envoi restent toujours visibles.
class IncidentReportScreen extends ConsumerStatefulWidget {
  const IncidentReportScreen({
    required this.delivery,
    required this.type,
    super.key,
  });

  final Delivery delivery;
  final IncidentType type;

  @override
  ConsumerState<IncidentReportScreen> createState() =>
      _IncidentReportScreenState();
}

class _IncidentReportScreenState extends ConsumerState<IncidentReportScreen> {
  final _description = TextEditingController();
  List<int>? _photoBytes;
  String? _photoId;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
    try {
      final id = await ref
          .read(deliveryRepositoryProvider)
          .uploadPackagePhoto(bytes: bytes, contentType: 'image/jpeg');
      if (mounted) setState(() => _photoId = id);
    } on Object {
      // Une photo qui ne monte pas ne bloque pas le signalement : l'incident
      // part sans elle plutot que d'etre retenu.
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final type = widget.type;
    setState(() => _submitting = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Position jointe au mieux : un dernier point connu, jamais une attente de
    // fix GPS — un incident ne se retient pas pour une coordonnee.
    double? lat;
    double? lng;
    try {
      final last = await Geolocator.getLastKnownPosition();
      lat = last?.latitude;
      lng = last?.longitude;
    } on Object {
      // Permission refusee, service coupe : on envoie sans position.
    }

    try {
      await ref
          .read(driverActionsProvider)
          .reportIncident(
            widget.delivery.id,
            type,
            description: _description.text.trim(),
            photoId: _photoId,
            lat: lat,
            lng: lng,
          );
      ref.invalidate(deliveryIncidentsProvider(widget.delivery.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.incidentReported)),
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = widget.type;

    return Scaffold(
      appBar: AppBar(title: Text(incidentTypeLabel(l10n, type))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Consequence du motif : le livreur sait ce qui se passe ensuite.
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: AppSpacing.card,
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      incidentOutcomeLabel(l10n, type.outcome),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.incidentDescriptionLabel,
              hintText: l10n.incidentDescriptionHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _photoBytes == null
                      ? l10n.incidentAddPhoto
                      : l10n.incidentPhotoAdded,
                ),
              ),
              if (_photoBytes != null) ...[
                const SizedBox(width: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadii.componentAll,
                  child: Image.memory(
                    Uint8List.fromList(_photoBytes!),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: AppSizes.minTouchTarget,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l10n.incidentSubmit),
            ),
          ),
        ),
      ),
    );
  }
}
