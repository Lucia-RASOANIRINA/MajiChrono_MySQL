import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/sync/sync_scheduler.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Demarre l'ordonnanceur et rend ses conflits visibles (EXI-S04).
///
/// Il est monte **au-dessus du Navigator**, comme le bandeau reseau : la file
/// ne doit pas s'arreter parce que l'utilisateur a change d'ecran, et un
/// conflit doit se voir quel que soit l'ecran affiche au moment ou le serveur
/// tranche.
///
/// « Le serveur fait foi » ne suffit pas : encore faut-il que l'utilisateur
/// l'apprenne. Un livreur qui a marque une course livree hors ligne, et dont le
/// serveur dit qu'elle a ete annulee entre-temps, doit le decouvrir maintenant —
/// pas devant la porte du destinataire.
class SyncGate extends ConsumerStatefulWidget {
  const SyncGate({required this.child, required this.messengerKey, super.key});

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  ConsumerState<SyncGate> createState() => _SyncGateState();
}

class _SyncGateState extends ConsumerState<SyncGate> {
  StreamSubscription<SyncRun>? _runs;

  @override
  void initState() {
    super.initState();
    // Apres la premiere frame : demarrer la file ne doit pas retarder le
    // premier rendu (EXI-P01).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheduler = ref.read(syncSchedulerProvider);
      _runs = scheduler.runs.listen(_onRun);
      unawaited(scheduler.start());
    });
  }

  void _onRun(SyncRun run) {
    if (!mounted) return;

    // Un envoi abouti peut avoir change l'etat cote serveur : on relit plutot
    // que de deviner.
    if (run.sent > 0) {
      unawaited(
        ref
            .read(deliveryRepositoryProvider)
            .refreshDeliveries()
            .catchError((_) {}),
      );
    }

    if (run.conflicts.isEmpty) return;

    final messenger = widget.messengerKey.currentState;
    final l10n = AppLocalizations.of(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.syncConflictNotice),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_runs?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
