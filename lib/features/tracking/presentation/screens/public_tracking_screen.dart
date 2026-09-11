import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/presentation/screens/deliveries_screen.dart';
import 'package:majichrono/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Suivi public, ouvert depuis un lien SMS (EXI-C24, differenciant D9).
///
/// Aucune session n'est requise : le destinataire n'installe rien et n'a pas de
/// compte. L'ecran est volontairement pauvre — statut, point de repere de
/// destination, prenom du livreur, delai estime. Le lien circule par SMS et peut
/// etre transfere ; il ne doit exposer ni numero, ni identite complete, ni
/// historique.
class PublicTrackingScreen extends ConsumerWidget {
  const PublicTrackingScreen({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tracking = ref.watch(publicTrackingProvider(token));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackingPublicTitle)),
      body: tracking.when(
        loading: () => const McSkeletonList(itemCount: 2),
        error: (_, _) => McEmptyState(
          icon: Icons.link_off,
          title: l10n.trackingPublicTitle,
          message: l10n.trackingPublicExpired,
        ),
        data: (data) {
          if (data == null) {
            return McEmptyState(
              icon: Icons.link_off,
              title: l10n.trackingPublicTitle,
              message: l10n.trackingPublicExpired,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(status: data.status),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        data.destinationLandmark,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (data.etaMinutes != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.trackingEta(data.etaMinutes!),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      if (data.driverFirstName != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.two_wheeler, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            // Un prenom tres long, ou un fort agrandissement
                            // systeme des polices, deborderait la Row sans ce
                            // garde-fou : on laisse le texte se tronquer.
                            Flexible(
                              child: Text(
                                data.driverFirstName!,
                                style: theme.textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
