import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/features/custody/presentation/providers/custody_providers.dart';
import 'package:majichrono/features/custody/presentation/screens/custody_comparator_screen.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Acces au comparateur de constats depuis une course (EXI-CC31).
///
/// Le meme bouton sert a l'expediteur et au livreur : l'exigence est que les
/// deux parties voient la meme chose. Il disparait tant qu'aucun constat n'a ete
/// etabli — proposer un comparateur vide laisserait croire qu'il n'y a rien a
/// comparer, alors qu'il n'y a simplement rien encore.
class CustodyProofAction extends ConsumerWidget {
  const CustodyProofAction({required this.delivery, super.key});

  final Delivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chain = ref.watch(custodyChainProvider(delivery.id)).valueOrNull;

    if (chain?.pickup == null) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.fact_check_outlined),
      tooltip: l10n.custodyComparatorTitle,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CustodyComparatorScreen(chain: chain!, delivery: delivery),
        ),
      ),
    );
  }
}
