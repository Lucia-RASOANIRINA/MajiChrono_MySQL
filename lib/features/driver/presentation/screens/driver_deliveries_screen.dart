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
import 'package:majichrono/shared/widgets/mc_loader.dart';

/// Courses du livreur : celles qu'il porte, puis celles qu'il a terminees.
///
/// Deux sections plutot qu'un onglet par etat. Un livreur ouvre cet ecran pour
/// une raison precise — retrouver l'adresse d'une course en cours — et devoir
/// d'abord choisir un onglet ajoute un geste a un moment ou il est presse. Les
/// courses actives sont donc en haut, toujours, sans rien a toucher.
///
/// La liste vient du cache local : elle s'affiche **hors ligne** (EXI-P07), ce
/// qui est le cas d'usage principal — on consulte une adresse justement quand on
/// est dehors, sans reseau.
class DriverDeliveriesScreen extends ConsumerWidget {
  const DriverDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deliveries = ref.watch(deliveriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDeliveries)),
      body: deliveries.when(
        loading: () => const Center(child: McLoader()),
        error: (_, _) => Center(child: Text(l10n.errorUnknown)),
        data: (all) {
          // Les courses du livreur sont celles qui lui sont attribuees. Le
          // filtrage est fait ici et non par le serveur : hors ligne, la liste
          // doit rester juste sans qu'aucune requete ne parte.
          final mine = all.where((d) => d.driverId != null).toList();
          final active = mine.where((d) => d.status.isActive).toList();
          final done = mine.where((d) => !d.status.isActive).toList();

          if (mine.isEmpty) return const _Empty();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (active.isNotEmpty) ...[
                _SectionTitle(
                  label: l10n.driverDeliveriesActive,
                  count: active.length,
                ),
                for (final delivery in active)
                  _DeliveryTile(delivery: delivery, active: true),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (done.isNotEmpty) ...[
                _SectionTitle(
                  label: l10n.driverDeliveriesDone,
                  count: done.length,
                ),
                for (final delivery in done)
                  _DeliveryTile(delivery: delivery, active: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.driverDeliveriesEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.driverDeliveriesEmptyNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      '$label ($count)',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery, required this.active});

  final Delivery delivery;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        // Seules les courses actives s'ouvrent : une course terminee n'a plus
        // d'action, et ouvrir un ecran d'execution sur elle n'aurait aucun sens.
        onTap: active
            ? () => context.push(AppRoutes.driverActive(delivery.id))
            : null,
        leading: Icon(
          active ? Icons.local_shipping_outlined : Icons.check_circle_outline,
          color: active ? theme.colorScheme.primary : AppColors.success,
        ),
        title: Text(
          delivery.dropoff.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          delivery.pickup.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Le prix peut manquer sur une course creee hors ligne et pas
            // encore tarifee par le serveur : on n'affiche alors rien plutot
            // qu'un zero, qui se lirait comme une course gratuite.
            if (delivery.priceAriary != null)
              Text(
                formatAriary(delivery.priceAriary!),
                style: theme.textTheme.titleSmall,
              ),
            // Le marqueur « en attente de synchronisation » est montre ici
            // parce que c'est la liste qu'on consulte hors ligne : le livreur
            // doit voir ce qui n'est pas encore parti (EXI-S06).
            if (delivery.pendingSync)
              Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
