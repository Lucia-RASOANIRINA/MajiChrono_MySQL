import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/features/driver/domain/entities/driver_entities.dart';
import 'package:majichrono/features/driver/presentation/providers/driver_providers.dart';
import 'package:majichrono/features/driver/presentation/widgets/package_traits.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Carte d'une course proposee, avec acceptation en un geste (EXI-L05).
///
/// Le compte a rebours de 30 s est affiche sur le bouton lui-meme, et non dans
/// un coin : c'est l'information qui decide, et le livreur regarde le bouton
/// qu'il s'apprete a toucher. A l'expiration, la proposition disparait — une
/// offre perimee qu'on peut encore toucher produit un refus serveur et une
/// frustration inutile.
class AvailableDeliveryCard extends ConsumerStatefulWidget {
  const AvailableDeliveryCard({required this.offer, super.key});

  final AvailableDelivery offer;

  @override
  ConsumerState<AvailableDeliveryCard> createState() =>
      _AvailableDeliveryCardState();
}

class _AvailableDeliveryCardState extends ConsumerState<AvailableDeliveryCard> {
  static const int windowSeconds = 30;

  Timer? _ticker;
  int _remaining = windowSeconds;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining == 0) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final deliveryId = widget.offer.delivery.id;
    var accepted = false;

    try {
      await ref.read(driverActionsProvider).accept(deliveryId);
      accepted = true;
    } on ConflictFailure {
      // Course prise par un autre : cas normal de la course a l'acceptation.
      messenger.showSnackBar(SnackBar(content: Text(l10n.driverAlreadyTaken)));
    } on UnauthorizedFailure catch (failure) {
      // Dossier pas encore valide : on ne se contente pas d'un message d'erreur,
      // on explique et on propose de suivre le dossier aupres de l'exploitation.
      if (failure.code == 'kyc_not_approved' && mounted) {
        await _showInactiveDialog(context);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(failure.localizedMessage(l10n))),
        );
      }
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // La discussion avec l'expediteur s'ouvre d'elle-meme des l'acceptation :
    // c'est le moment ou les deux ont besoin de se coordonner (« j'arrive »,
    // « je suis en bas »), sans avoir a chercher un bouton.
    if (accepted && mounted) {
      unawaited(router.push(AppRoutes.chat(deliveryId)));
    }
  }

  /// Explique que le compte n'est pas encore actif (dossier en validation) et
  /// propose d'ouvrir le fil de suivi aupres de l'exploitation.
  Future<void> _showInactiveDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.pending_actions_outlined),
        title: Text(l10n.kycInactiveTitle),
        content: Text(l10n.kycInactiveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.kycInactiveClose),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              GoRouter.of(context).push(AppRoutes.kycFollowup);
            },
            child: Text(l10n.kycInactiveContact),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final offer = widget.offer;
    final expired = _remaining == 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, l10n),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.driverEarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    formatAriary(offer.estimatedEarningAriary),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),

              _PackageThumbnail(photoId: offer.delivery.package.photoId),

              const SizedBox(height: AppSpacing.md),
              _Line(
                icon: Icons.trip_origin,
                text: offer.delivery.pickup.summary,
                // La distance a vide est mise en avant : c'est du carburant que
                // le livreur avance sans etre paye (EXI-L04).
                trailing: l10n.driverPickupDistance(
                  offer.pickupDistanceKm.toStringAsFixed(1),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _Line(
                icon: Icons.place_outlined,
                text: offer.delivery.dropoff.summary,
                trailing: l10n.deliveryDistance(
                  offer.delivery.distanceKm.toStringAsFixed(1),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Temps estime de la course (EXI-L04, §15) : une approximation a
              // partir de la distance et d'une vitesse urbaine moyenne, de quoi
              // juger l'engagement sans promettre une precision qu'on n'a pas.
              _Line(
                icon: Icons.schedule,
                text: l10n.driverEtaLabel,
                trailing: l10n.driverEta(_etaMinutes(offer)),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: AppSizes.minTouchTarget,
                width: double.infinity,
                child: FilledButton(
                  onPressed: expired || _busy ? null : _accept,
                  child: Text(
                    expired
                        ? l10n.driverAccept
                        : l10n.driverAcceptIn(_remaining),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  // Refuser (EXI-L05, §15) : l'offre est ecartee et ne remonte
                  // plus. Cote serveur il n'y a rien a faire — ne pas accepter
                  // suffit — mais la masquer evite qu'elle revienne en boucle.
                  onPressed: _busy
                      ? null
                      : () => ref
                            .read(dismissedOffersProvider.notifier)
                            .dismiss(offer.delivery.id),
                  child: Text(l10n.driverRefuse),
                ),
              ),
              if (!expired) ...[
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: _remaining / windowSeconds,
                  minHeight: 4,
                  borderRadius: AppRadii.componentAll,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Temps estime, en minutes : distance a vide + course, a ~18 km/h (trafic
  /// dense d'Antananarivo), plancher a 5 minutes.
  int _etaMinutes(AvailableDelivery offer) {
    final km = offer.pickupDistanceKm + offer.delivery.distanceKm;
    final minutes = (km / 18.0 * 60).round();
    return minutes < 5 ? 5 : minutes;
  }

  void _showDetails(BuildContext context, AppLocalizations l10n) {
    final offer = widget.offer;
    final d = offer.delivery;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.driverDetails, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                _DetailRow(
                  icon: Icons.trip_origin,
                  label: d.pickup.landmark.isEmpty
                      ? d.pickup.summary
                      : '${d.pickup.landmark} · ${d.pickup.district}',
                ),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: d.dropoff.landmark.isEmpty
                      ? d.dropoff.summary
                      : '${d.dropoff.landmark} · ${d.dropoff.district}',
                ),
                _DetailRow(
                  icon: Icons.straighten,
                  label: l10n.deliveryDistance(d.distanceKm.toStringAsFixed(1)),
                ),
                _DetailRow(
                  icon: Icons.schedule,
                  label:
                      '${l10n.driverEtaLabel} : '
                      '${l10n.driverEta(_etaMinutes(offer))}',
                ),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label:
                      '${l10n.driverEarning} : '
                      '${formatAriary(offer.estimatedEarningAriary)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                PackageTraits(delivery: d),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _PackageThumbnail extends ConsumerWidget {
  const _PackageThumbnail({required this.photoId});

  final String? photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = Container(
      height: 96,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 34,
        color: theme.colorScheme.primary,
      ),
    );
    if (photoId == null || photoId!.isEmpty) return placeholder;
    return FutureBuilder<List<int>>(
      future: ref
          .read(apiClientProvider)
          .getBytes(ApiEndpoints.mediaItem(photoId!)),
      builder: (context, snapshot) {
        if (snapshot.hasError) return placeholder;
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 96,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Image.memory(
              Uint8List.fromList(snapshot.data!),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.trailing});

  final IconData icon;
  final String text;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          trailing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
