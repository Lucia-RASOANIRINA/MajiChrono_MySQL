import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';

/// Verrouillage automatique apres inactivite (EXI-SEC07).
///
/// L'exigence ne vise que les profils livreur et exploitation, et la raison est
/// concrete : ce sont eux qui manipulent des pieces d'identite, des constats
/// signes et des positions de flotte. Un telephone de livreur pose sur une
/// table, ou perdu, ne doit pas exposer ces donnees. Un expediteur, lui, ne voit
/// que ses propres courses ; lui imposer un code toutes les cinq minutes serait
/// une gene sans contrepartie.
///
/// Le detecteur ecoute les evenements de pointeur **en phase de capture**, donc
/// sans jamais intercepter un geste destine a l'ecran en dessous.
class InactivityLock extends ConsumerStatefulWidget {
  const InactivityLock({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<InactivityLock> createState() => _InactivityLockState();
}

class _InactivityLockState extends ConsumerState<InactivityLock>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le retour au premier plan est le moment ou le telephone change le plus
    // souvent de mains : on repart d'un delai neuf.
    if (state == AppLifecycleState.resumed) _restart();
  }

  bool get _applies {
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return false;
    return auth.account.role == UserRole.driver ||
        auth.account.role == UserRole.admin;
  }

  void _restart() {
    _timer?.cancel();
    if (!_applies) return;

    final delay = ref.read(appConfigProvider).autoLockDelay;
    _timer = Timer(delay, () {
      if (!mounted) return;
      unawaited(ref.read(authControllerProvider.notifier).lock());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Redemarre le compte a rebours quand l'etat d'authentification change :
    // une connexion qui vient d'aboutir doit armer le verrou, une deconnexion
    // doit le desarmer.
    ref.listen(authControllerProvider, (_, _) => _restart());

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
