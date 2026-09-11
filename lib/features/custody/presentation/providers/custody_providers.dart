import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/custody/data/custody_repository.dart';
import 'package:majichrono/features/custody/data/services/custody_vault.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';

/// Coffre de chiffrement des constats au repos (EXI-CC46).
final custodyVaultProvider = Provider<CustodyVault>(
  (ref) => CustodyVault(ref.watch(secureStoreProvider)),
);

final custodyRepositoryProvider = Provider<CustodyRepository>(
  (ref) => CustodyRepository(
    client: ref.watch(apiClientProvider),
    db: ref.watch(appDatabaseProvider),
    vault: ref.watch(custodyVaultProvider),
    queue: ref.watch(syncQueueProvider),
  ),
);

/// Chaine de preuve d'une course, lue localement (EXI-CC05).
final custodyChainProvider = FutureProvider.family<CustodyChain, String>(
  (ref, deliveryId) =>
      ref.watch(custodyRepositoryProvider).chainFor(deliveryId),
);

final custodyActionsProvider = Provider<CustodyActions>(
  (ref) => CustodyActions(ref),
);

class CustodyActions {
  CustodyActions(this._ref);

  final Ref _ref;

  /// Scelle un constat puis le transmet.
  ///
  /// Le chainage est resolu **ici** et non dans l'ecran : la remise doit
  /// integrer l'empreinte de la prise en charge (EXI-CC44), et c'est le
  /// repository qui sait laquelle a ete enregistree. Laisser un ecran choisir
  /// l'empreinte precedente reviendrait a lui confier la solidite de la chaine.
  Future<CustodyReport> sealAndSubmit(CustodyReport draft) async {
    final repository = _ref.read(custodyRepositoryProvider);

    String? previousHash;
    if (draft.stage == CustodyStage.handover) {
      final chain = await repository.chainFor(draft.deliveryId);
      previousHash = chain.pickup?.hash;
    }

    final sealed = draft.seal(previousHash: previousHash);
    final result = await repository.submit(sealed);

    _ref.invalidate(custodyChainProvider(draft.deliveryId));
    return result;
  }
}
