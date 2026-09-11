import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/custody/presentation/widgets/custody_proof_action.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_screen.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/providers/review_providers.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/delivery/presentation/widgets/rating_sheet.dart';
import 'package:majichrono/features/tracking/domain/entities/tracking.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:majichrono/features/tracking/presentation/widgets/delivery_map.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/features/support/presentation/screens/open_dispute_sheet.dart';
import 'package:majichrono/shared/widgets/mc_driver_card.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';
import 'package:majichrono/shared/widgets/mc_step_trail.dart';

/// Etape de la frise horizontale (0 = pris en charge, 1 = en transit,
/// 2 = livre) deduite du statut de la course.
int trackingStage(DeliveryStatus status) => switch (status) {
  DeliveryStatus.draft ||
  DeliveryStatus.pending ||
  DeliveryStatus.accepted ||
  DeliveryStatus.atPickup ||
  DeliveryStatus.cancelled => 0,
  DeliveryStatus.pickedUp ||
  DeliveryStatus.inTransit ||
  DeliveryStatus.atDestination => 1,
  DeliveryStatus.delivered ||
  DeliveryStatus.deliveredWithReserves ||
  DeliveryStatus.refused ||
  DeliveryStatus.returning ||
  DeliveryStatus.paid ||
  DeliveryStatus.disputed ||
  DeliveryStatus.closed => 2,
};

/// Suivi d'une course pour l'expediteur (EXI-C20 a EXI-C24).
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({required this.deliveryId, super.key});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deliveriesAsync = ref.watch(deliveriesProvider);
    final deliveries = deliveriesAsync.valueOrNull;
    final delivery = deliveries?.where((d) => d.id == deliveryId).firstOrNull;
    final tracking = ref.watch(trackingProvider(deliveryId));

    // Trois cas distincts, et non deux : la base locale peut encore etre en
    // train de repondre. Les confondre affichait un ecran vide, sans rien dire
    // a l'utilisateur — exactement ce que le §15.2.3 interdit.
    if (deliveries == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trackingTitle)),
        body: const McSkeletonList(itemCount: 3),
      );
    }

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trackingTitle)),
        body: McEmptyState(
          icon: Icons.inventory_2_outlined,
          title: l10n.emptyDeliveries,
          message: l10n.trackingPublicExpired,
        ),
      );
    }

    final snapshot = tracking.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trackingTitle),
        actions: [
          // Discussion avec le livreur, des qu'une course est acceptee.
          if (delivery.driverId != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Discussion',
              onPressed: () => context.push(
                AppRoutes.chat(delivery.id),
                extra: delivery.driverName,
              ),
            ),
          if (delivery.paymentMethod == PaymentMethod.majipay &&
              (delivery.status == DeliveryStatus.delivered ||
                  delivery.status == DeliveryStatus.deliveredWithReserves))
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: l10n.payTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentScreen(delivery: delivery, role: UserRole.client),
                ),
              ),
            ),
          // EXI-CC31 : l'expediteur voit exactement le meme comparateur que le
          // livreur. Une preuve contradictoire qui ne serait visible que d'un
          // cote ne serait plus contradictoire.
          CustodyProofAction(delivery: delivery),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Le statut d'abord : c'est la reponse a « ou en est mon colis ? ».
          // La carte le precise, elle ne le remplace pas.
          Builder(
            builder: (context) {
              final status = snapshot?.status ?? delivery.status;
              return Column(
                children: [
                  McCard(
                    child: Row(
                      children: [
                        McStatusBadge(
                          label: statusLabel(l10n, status),
                          icon: statusIcon(status),
                          tone: statusTone(status),
                        ),
                        const Spacer(),
                        if (snapshot?.etaMinutes != null)
                          Text(
                            l10n.trackingEta(snapshot!.etaMinutes!),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Resume horizontal de l'avancement (comme la maquette).
                  McCard(
                    child: McStepTrail(
                      labels: [
                        l10n.statusPickedUp,
                        l10n.statusInTransit,
                        l10n.statusDelivered,
                      ],
                      currentIndex: trackingStage(status),
                    ),
                  ),
                ],
              );
            },
          ),
          if ((snapshot?.status ?? delivery.status).isCancellableByClient) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, delivery.id),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(l10n.cancelDelivery),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          DeliveryMap(
            pickup: delivery.pickup.point,
            dropoff: delivery.dropoff.point,
            driverPosition: snapshot?.driverPosition,
            trace: snapshot?.trace ?? const [],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (snapshot?.driver != null) ...[
            _DriverCard(driver: snapshot!.driver!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (delivery.relayPickupCode != null &&
              delivery.relayPickupCode!.isNotEmpty) ...[
            _RelayPickupCard(code: delivery.relayPickupCode!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (delivery.trackingToken != null) ...[
            _ShareTrackingCard(token: delivery.trackingToken!),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Une course remise se note : c'est le moment ou l'expediteur a tout
          // le contexte en tete (EXI-C40).
          if (delivery.status == DeliveryStatus.delivered ||
              delivery.status == DeliveryStatus.deliveredWithReserves) ...[
            _RateDriverCard(deliveryId: delivery.id),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            l10n.trackingTimeline,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot == null)
            // `nested` : ce squelette vit dans la liste de l'ecran.
            const McSkeletonList(itemCount: 2, nested: true)
          else
            _Timeline(entries: snapshot.timeline),
          // Ouvrir un litige n'a de sens qu'une fois un livreur engage : avant,
          // il n'y a pas d'autre partie a instruire (§13).
          if (delivery.driverId != null && !delivery.pendingSync) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: () => showOpenDisputeSheet(
                context,
                ref,
                deliveryId: delivery.id,
              ),
              icon: const Icon(Icons.gavel_outlined, size: 18),
              label: Text(l10n.disputeReportButton),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final fee = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CancelSheet(deliveryId: id),
    );
    if (fee == null) return; // l'utilisateur a garde sa course
    messenger.showSnackBar(
      SnackBar(
        content: Text(fee > 0 ? l10n.cancelDoneWithFee(fee) : l10n.cancelDone),
      ),
    );
  }
}

/// Feuille d'annulation : un motif, l'avertissement de frais, puis confirmation.
/// Rend les frais retenus au `Navigator.pop`, ou rien si l'utilisateur renonce.
class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet({required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  String? _reason;
  bool _busy = false;

  List<String> _reasons(AppLocalizations l10n) => [
    l10n.cancelReasonMind,
    l10n.cancelReasonWrongAddress,
    l10n.cancelReasonTooLong,
    l10n.cancelReasonOther,
  ];

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final fee = await ref
          .read(deliveryRepositoryProvider)
          .cancelDelivery(widget.deliveryId, reason: _reason);
      ref.invalidate(deliveriesProvider);
      navigator.pop(fee);
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cancelSheetTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.cancelSheetHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final reason in _reasons(l10n))
                ChoiceChip(
                  label: Text(reason),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy || _reason == null ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.cancelConfirm),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelKeep),
          ),
        ],
      ),
    );
  }
}

/// Invite a noter le livreur, ou rappel de la note deja donnee (EXI-C40).
///
/// La carte se relit d'elle-meme : une fois l'avis envoye, le provider renvoie
/// la note, et l'invitation cede la place a un rappel — on ne redemande pas de
/// noter une course deja notee.
class _RateDriverCard extends ConsumerWidget {
  const _RateDriverCard({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final review = ref.watch(deliveryReviewProvider(deliveryId));

    return McCard(
      child: review.when(
        loading: () => const SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => _invite(context, l10n, theme),
        data: (existing) {
          if (existing == null) return _invite(context, l10n, theme);
          // Note deja donnee : on la rappelle, en lecture seule.
          return Row(
            children: [
              Expanded(
                child: Text(
                  l10n.rateAlready,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < existing.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _invite(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.star_rounded, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(l10n.rateTitle, style: theme.textTheme.bodyLarge)),
        FilledButton.tonal(
          onPressed: () => showRatingSheet(context, deliveryId: deliveryId),
          child: Text(l10n.rateCta),
        ),
      ],
    );
  }
}

/// Fiche livreur (EXI-C22, EXI-C23).
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final DriverInfo driver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return McCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(title: l10n.trackingDriver),
          const SizedBox(height: AppSpacing.md),
          McDriverCard(
            compact: true,
            name: driver.displayName,
            rating: driver.rating,
            vehicle: driver.vehicleModel,
            plate: driver.plate,
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone_outlined),
                  label: Text('${l10n.trackingCall} ${driver.maskedPhone}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  // EXI-C23 : les numeros sont masques des deux cotes. On le
                  // dit a l'utilisateur, sinon un numero masque passe pour un
                  // defaut d'affichage.
                  l10n.trackingCallMasked,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Partage du lien de suivi public (EXI-C24, differenciant D9).
class _ShareTrackingCard extends StatelessWidget {
  const _ShareTrackingCard({required this.token});

  final String token;

  static const String publicHost = 'https://suivi.majichrono.mg';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final url = '$publicHost/$token';

    return McCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.share_outlined),
        title: Text(l10n.trackingShare),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.copy_outlined),
        // Le destinataire n'installe rien : il recoit un lien par SMS et suit
        // le colis dans son navigateur (D9).
        onTap: () async {
          await Clipboard.setData(
            ClipboardData(text: l10n.trackingShareMessage(url)),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
        },
      ),
    );
  }
}

/// Code de retrait au point relais (§7).
///
/// Le destinataire le presente au comptoir pour recuperer le colis. On le rend
/// copiable pour un partage par SMS, comme le lien de suivi : le relais n'a pas
/// a connaitre l'expediteur, seulement ce code.
class _RelayPickupCard extends StatelessWidget {
  const _RelayPickupCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return McCard(
      accent: AppColors.primary,
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.relayPickupCodeTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.relayPickupCodeHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: l10n.commonCopy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
            },
          ),
        ],
      ),
    );
  }
}

/// Frise chronologique horodatee (EXI-C21).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Text(
        AppLocalizations.of(context).trackingNoDriverYet,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return McCard(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _TimelineRow(
              entry: entries[i],
              isFirst: i == 0,
              isLast: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final time =
        '${entry.at.hour.toString().padLeft(2, '0')}:${entry.at.minute.toString().padLeft(2, '0')}';

    // Hauteurs fixes plutot qu'`IntrinsicHeight` avec un `Expanded` : mesurer
    // la hauteur intrinseque d'une colonne qui contient un enfant flexible est
    // un piege de mise en page, du meme genre que celui qui a vide cet ecran.
    // Une frise n'a pas besoin de s'etirer : ses etapes ont toutes la meme
    // hauteur.
    const rowHeight = 56.0;

    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 14,
                  color: isFirst
                      ? Colors.transparent
                      : theme.colorScheme.outlineVariant,
                ),
                Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: isLast
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  height: rowHeight - 26,
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                McStatusBadge(
                  label: statusLabel(l10n, entry.status),
                  icon: statusIcon(entry.status),
                  tone: statusTone(entry.status),
                ),
                Text(
                  time,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
