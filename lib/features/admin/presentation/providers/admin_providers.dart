import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/admin/data/admin_repository.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(client: ref.watch(apiClientProvider)),
);

/// Chiffres du jour (EXI-A01).
///
/// `autoDispose` : un tableau de bord est une photographie de l'instant. Le
/// garder en memoire entre deux visites afficherait un etat perime a quelqu'un
/// dont le metier est precisement de savoir ce qui se passe **maintenant**.
final adminDashboardProvider = FutureProvider.autoDispose<DashboardSummary>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

/// Filtre courant de la carte de flotte.
final fleetFilterProvider = StateProvider.autoDispose<FleetStatus?>(
  (_) => null,
);

final adminFleetProvider = FutureProvider.autoDispose<List<FleetDriver>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .fleet(status: ref.watch(fleetFilterProvider)),
);

/// Livreurs mobilisables, pour la reaffectation (EXI-A07).
final availableDriversProvider = FutureProvider.autoDispose<List<FleetDriver>>((
  ref,
) async {
  final all = await ref.watch(adminRepositoryProvider).fleet();
  return all.where((d) => d.status.canReceiveDeliveries).toList();
});

/// File des dossiers a valider (EXI-A03).
final kycQueueProvider = FutureProvider.autoDispose<List<KycApplication>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .kycQueue(filter: KycStatusFilter.submitted),
);

final disputesProvider = FutureProvider.autoDispose<List<Dispute>>(
  (ref) => ref.watch(adminRepositoryProvider).disputes(),
);

final disputeProvider = FutureProvider.autoDispose.family<Dispute, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).dispute(id),
);

/// Fil de suivi du dossier KYC d'un livreur, cote exploitation.
final adminKycThreadProvider = FutureProvider.autoDispose
    .family<List<KycThreadMessage>, String>(
      (ref, driverId) =>
          ref.watch(adminRepositoryProvider).kycMessages(driverId),
    );

/// Filtre de la liste des courses (EXI-A04).
///
/// Il vit dans l'etat plutot que dans l'ecran : un exploitant qui ouvre une
/// course puis revient ne doit pas avoir a re-cocher ses criteres.
final deliveryFilterProvider = StateProvider<DeliveryFilter>(
  (_) => const DeliveryFilter(),
);

/// Rapport d'activite de l'exploitation (statistiques & rapports).
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

/// Annuaire des utilisateurs, par role et terme de recherche.
typedef AdminUsersQuery = ({String? role, String query});

final adminUsersProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, AdminUsersQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .users(role: q.role, query: q.query),
    );

/// Actions d'exploitation. Toutes exigent une decision motivee.
final adminActionsProvider = Provider<AdminActions>((ref) => AdminActions(ref));

class AdminActions {
  AdminActions(this._ref);

  final Ref _ref;

  AdminRepository get _repository => _ref.read(adminRepositoryProvider);

  Future<KycApplication> reviewKyc({
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final reviewed = await _repository.reviewKyc(
      driverId: driverId,
      decision: decision,
    );
    // Un dossier valide entre dans la flotte et sort de la file : les deux vues
    // doivent bouger ensemble, sinon l'exploitant voit un dossier deja traite
    // reapparaitre au prochain retour sur l'ecran.
    _ref
      ..invalidate(kycQueueProvider)
      ..invalidate(adminFleetProvider)
      ..invalidate(adminDashboardProvider);
    return reviewed;
  }

  /// Suspend/reactive un compte quelconque (client ou livreur).
  Future<void> suspendUser({
    required String accountId,
    required ModerationDecision decision,
  }) async {
    await _repository.setUserSuspension(
      accountId: accountId,
      decision: decision,
    );
    _ref
      ..invalidate(adminFleetProvider)
      ..invalidate(adminDashboardProvider);
  }

  Future<FleetDriver> setSuspension({
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final driver = await _repository.setSuspension(
      driverId: driverId,
      decision: decision,
    );
    _ref
      ..invalidate(adminFleetProvider)
      ..invalidate(availableDriversProvider)
      ..invalidate(adminDashboardProvider);
    return driver;
  }

  Future<Delivery> reassign({
    required String deliveryId,
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final delivery = await _repository.reassign(
      deliveryId: deliveryId,
      driverId: driverId,
      decision: decision,
    );
    _ref
      ..invalidate(adminFleetProvider)
      ..invalidate(availableDriversProvider);
    return delivery;
  }

  Future<Dispute> reply({
    required String disputeId,
    required String body,
  }) async {
    final dispute = await _repository.replyToDispute(
      disputeId: disputeId,
      body: body,
    );
    _ref
      ..invalidate(disputeProvider(disputeId))
      ..invalidate(disputesProvider);
    return dispute;
  }

  Future<Dispute> decide({
    required String disputeId,
    required ModerationDecision decision,
  }) async {
    final dispute = await _repository.decideDispute(
      disputeId: disputeId,
      decision: decision,
    );
    _ref
      ..invalidate(disputeProvider(disputeId))
      ..invalidate(disputesProvider)
      ..invalidate(adminDashboardProvider);
    return dispute;
  }
}
