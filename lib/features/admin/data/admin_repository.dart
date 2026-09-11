import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Acces aux donnees de supervision (§13).
///
/// Toutes les methodes qui **decident** exigent un [ModerationDecision], qu'il
/// est impossible de construire sans motif suffisant. La verification a donc
/// lieu avant tout appel reseau : une decision incomplete n'atteint jamais le
/// serveur, et l'ecran recoit une erreur locale immediate plutot qu'un
/// aller-retour inutile sur un forfait compte (§4.4).
///
/// Le serveur revalide de son cote — le mobile propose, le serveur dispose
/// (§8.3) — mais l'utilisateur n'a pas a attendre le reseau pour apprendre
/// qu'il a laissé un champ vide.
class AdminRepository {
  AdminRepository({required this._client});

  final ApiClient _client;

  /// Chiffres du jour (EXI-A01).
  Future<DashboardSummary> dashboard() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminDashboard,
    );
    return DashboardSummary.fromJson(json);
  }

  /// Flotte, filtrable par statut (EXI-A02).
  Future<List<FleetDriver>> fleet({FleetStatus? status}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminFleet,
      query: {if (status != null) 'status': status.wireName},
    );
    return (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FleetDriver.fromJson)
        .whereType<FleetDriver>()
        .toList();
  }

  /// File des dossiers a valider (EXI-A03).
  Future<List<KycApplication>> kycQueue({KycStatusFilter? filter}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminKyc,
      query: {if (filter != null) 'status': filter.wireName},
    );
    return (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(KycApplication.fromJson)
        .whereType<KycApplication>()
        .toList();
  }

  /// Approuve ou refuse un dossier, motif a l'appui (EXI-A03).
  Future<KycApplication> reviewKyc({
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final approve = decision.action == ModerationAction.kycApprove;

    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminKycReview(driverId),
      body: {'approve': approve, 'reason': decision.reason},
      // La cle porte le dossier et le sens : deux appuis sur « refuser » ne
      // produisent qu'un refus, et un second avis contraire est refuse par le
      // serveur plutot que d'ecraser le premier en silence.
      idempotencyKey: 'kyc_${driverId}_${decision.action.wireName}',
    );

    final application = KycApplication.fromJson(json);
    if (application == null) throw const ServerFailure(statusCode: 500);

    // Le motif n'est pas journalise : il concerne une personne identifiable, et
    // les traces d'exploitation partent dans le diagnostic terrain (EXI-P10).
    AppLogger.instance.info(
      'admin_kyc_reviewed',
      data: {'decision': decision.action.wireName},
    );
    return application;
  }

  /// Suspend ou reintegre un compte (EXI-A06).
  Future<FleetDriver> setSuspension({
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final suspend = decision.action == ModerationAction.suspendAccount;

    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminDriverSuspension(driverId),
      body: {'suspend': suspend, 'reason': decision.reason},
      idempotencyKey: 'suspension_${driverId}_${decision.action.wireName}',
    );

    final driver = FleetDriver.fromJson(json);
    if (driver == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info(
      'admin_suspension',
      data: {'decision': decision.action.wireName},
    );
    return driver;
  }

  /// Rapport d'activite : volumes, taux, temps, zones, heures, performance.
  Future<AdminStats> stats() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminStats,
    );
    return AdminStats.fromJson(json);
  }

  /// Annuaire des comptes (clients ou livreurs), cherchable par nom/numero.
  Future<List<AdminUser>> users({String? role, String? query}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminUsers,
      query: {
        'role': ?role,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .whereType<AdminUser>()
        .toList();
  }

  /// Suspend ou reactive un compte quelconque (client ou livreur), avec motif.
  Future<void> setUserSuspension({
    required String accountId,
    required ModerationDecision decision,
  }) async {
    final suspend = decision.action == ModerationAction.suspendAccount;
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminUserSuspension(accountId),
      body: {'suspend': suspend, 'reason': decision.reason},
      idempotencyKey: 'usersusp_${accountId}_${decision.action.wireName}',
    );
    AppLogger.instance.info(
      'admin_user_suspension',
      data: {'decision': decision.action.wireName},
    );
  }

  /// Reaffecte une course a un autre livreur (EXI-A07).
  Future<Delivery> reassign({
    required String deliveryId,
    required String driverId,
    required ModerationDecision decision,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminDeliveryReassign(deliveryId),
      body: {'driverId': driverId, 'reason': decision.reason},
      idempotencyKey: 'reassign_${deliveryId}_$driverId',
    );

    final delivery = Delivery.fromJson(json);
    if (delivery == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info('admin_reassigned');
    return delivery;
  }

  /// Fil de suivi du dossier KYC d'un livreur (cote exploitation).
  Future<List<KycThreadMessage>> kycMessages(String driverId) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.adminKycMessages(driverId),
    );
    return (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(KycThreadMessage.fromJson)
        .whereType<KycThreadMessage>()
        .toList();
  }

  /// Reponse de l'exploitation au livreur sur le suivi de son dossier.
  Future<void> replyKyc({
    required String driverId,
    required String body,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.adminKycMessages(driverId),
      body: {'body': body},
    );
  }

  /// Litiges ouverts, les plus recents d'abord (EXI-A05).
  Future<List<Dispute>> disputes({DisputeStatus? status}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.disputes,
      query: {if (status != null) 'status': status.wireName},
    );
    return (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Dispute.fromJson)
        .whereType<Dispute>()
        .toList();
  }

  Future<Dispute> dispute(String id) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.dispute(id),
    );
    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);
    return dispute;
  }

  /// Ajoute un message au fil du litige (EXI-A05).
  Future<Dispute> replyToDispute({
    required String disputeId,
    required String body,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.disputeMessages(disputeId),
      body: {'body': body},
    );
    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);
    return dispute;
  }

  /// Tranche et clot le litige (EXI-A05).
  Future<Dispute> decideDispute({
    required String disputeId,
    required ModerationDecision decision,
  }) async {
    final resolve = decision.action == ModerationAction.resolveDispute;

    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.disputeDecision(disputeId),
      body: {'resolve': resolve, 'reason': decision.reason},
      idempotencyKey: 'dispute_${disputeId}_${decision.action.wireName}',
    );

    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);

    AppLogger.instance.info(
      'admin_dispute_decided',
      data: {'decision': decision.action.wireName},
    );
    return dispute;
  }
}

/// Filtre de la file KYC.
enum KycStatusFilter {
  submitted('submitted'),
  underReview('under_review'),
  approved('approved'),
  rejected('rejected');

  const KycStatusFilter(this.wireName);

  final String wireName;
}
