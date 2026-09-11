import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/features/driver/domain/entities/emergency.dart';

final emergencyActionsProvider = Provider<EmergencyActions>(
  (ref) => EmergencyActions(ref),
);

/// Envoi d'une alerte d'urgence (EXI-L13, differenciant D10).
///
/// L'alerte ne peut pas echouer du point de vue du livreur. Hors ligne, elle
/// rejoint la file de synchronisation en **priorite la plus haute**, au meme
/// rang que les constats : un appel a l'aide qui partirait derriere des
/// positions GPS n'aurait aucun sens.
///
/// Le drapeau « jamais abandonner » suit : une alerte n'expire pas au bout de
/// quinze tentatives. Tant que personne ne l'a accusee, elle reste a envoyer.
class EmergencyActions {
  EmergencyActions(this._ref);

  final Ref _ref;

  Future<EmergencyAlert> raise({
    required EmergencyKind kind,
    String? deliveryId,
  }) async {
    final alert = EmergencyAlert(
      id: 'sos_${const Uuid().v4()}',
      raisedAt: DateTime.now(),
      kind: kind,
      // La position n'est pas attendue : elle sera jointe si elle est deja
      // connue, jamais demandee a la volee. Attendre un point GPS couterait les
      // secondes qui comptent.
      deliveryId: deliveryId,
    );

    // Journalisee avant tout envoi : on veut la trace meme si l'application
    // s'arrete dans la seconde qui suit.
    AppLogger.instance.warn('emergency_raised', data: {'kind': kind.wireName});

    try {
      await _ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            ApiEndpoints.emergency,
            body: alert.toJson(),
            idempotencyKey: alert.id,
          );
      return alert;
    } on Failure {
      // Le reseau a lache : l'alerte part en file, au rang des preuves.
      await _ref
          .read(syncQueueProvider)
          .enqueue(
            method: 'POST',
            path: ApiEndpoints.emergency,
            idempotencyKey: alert.id,
            body: alert.toJson(),
            priority: SyncPriority.custody,
          );
      return alert;
    }
  }
}
