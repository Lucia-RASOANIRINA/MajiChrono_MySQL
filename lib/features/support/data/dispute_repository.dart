import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';

/// Litiges vus du cote client (§13, assistance).
///
/// Le meme dossier que celui de l'exploitation — un litige est une preuve
/// contradictoire (EXI-CC31) — mais ouvert et suivi par une partie plutot que
/// tranche par elle. On reutilise donc l'entite [Dispute] partagee : deux
/// modeles finiraient par diverger et l'un des deux mentirait sur l'etat reel.
class DisputeRepository {
  DisputeRepository({required this._client});

  final ApiClient _client;

  /// Ouvre un litige sur une course dont l'appelant est partie prenante.
  ///
  /// La cle d'idempotence porte la course et le motif : un double appui — le
  /// reseau malgache coupe par a-coups — ne cree pas deux dossiers pour la
  /// meme reclamation.
  Future<Dispute> open({
    required String deliveryId,
    required String reason,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.disputes,
      body: {'deliveryId': deliveryId, 'reason': reason},
      idempotencyKey: 'dispute_open_${deliveryId}_${reason.hashCode}',
    );
    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);
    AppLogger.instance.info('dispute_opened');
    return dispute;
  }

  /// Litiges de l'appelant, les plus recents d'abord. Le serveur ne rend que
  /// ceux dont il est partie prenante.
  Future<List<Dispute>> list() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.disputes,
    );
    return (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Dispute.fromJson)
        .whereType<Dispute>()
        .toList();
  }

  Future<Dispute> read(String id) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.dispute(id),
    );
    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);
    return dispute;
  }

  /// Ajoute un message au fil, du cote client. `author` n'est qu'un indice pour
  /// le simulateur ; le serveur reel derive l'auteur du role authentifie.
  Future<Dispute> reply({required String disputeId, required String body}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.disputeMessages(disputeId),
      body: {'body': body, 'author': 'client'},
    );
    final dispute = Dispute.fromJson(json);
    if (dispute == null) throw const ServerFailure(statusCode: 500);
    return dispute;
  }
}
