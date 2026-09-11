import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/support/data/dispute_repository.dart';

final disputeRepositoryProvider = Provider<DisputeRepository>(
  (ref) => DisputeRepository(client: ref.watch(apiClientProvider)),
);

/// Litiges de l'utilisateur, les plus recents d'abord (§13).
///
/// `autoDispose` : la liste se relit a l'ouverture de l'ecran. Un litige avance
/// entre deux visites — un message de l'exploitation, une decision — et une
/// liste gardee en cache l'afficherait fige.
final clientDisputesProvider = FutureProvider.autoDispose<List<Dispute>>(
  (ref) => ref.watch(disputeRepositoryProvider).list(),
);

/// Un litige et son fil, rafraichi a chaque ouverture du detail.
final clientDisputeProvider = FutureProvider.autoDispose.family<Dispute, String>(
  (ref, id) => ref.watch(disputeRepositoryProvider).read(id),
);

/// Actions sur les litiges cote client : ouvrir, repondre.
final disputeActionsProvider = Provider<DisputeActions>(
  (ref) => DisputeActions(ref),
);

class DisputeActions {
  DisputeActions(this._ref);

  final Ref _ref;

  DisputeRepository get _repo => _ref.read(disputeRepositoryProvider);

  Future<Dispute> open({
    required String deliveryId,
    required String reason,
  }) async {
    final dispute = await _repo.open(deliveryId: deliveryId, reason: reason);
    _ref.invalidate(clientDisputesProvider);
    return dispute;
  }

  Future<Dispute> reply({
    required String disputeId,
    required String body,
  }) async {
    final dispute = await _repo.reply(disputeId: disputeId, body: body);
    _ref.invalidate(clientDisputeProvider(disputeId));
    _ref.invalidate(clientDisputesProvider);
    return dispute;
  }
}
