import 'dart:convert';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/sync/sync_item.dart';
import 'package:majichrono/core/sync/sync_queue.dart';
import 'package:majichrono/features/delivery/data/datasources/delivery_local_data_source.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:uuid/uuid.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl({
    required this._client,
    required this._local,
    required this._queue,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final ApiClient _client;
  final DeliveryLocalDataSource _local;
  final SyncQueue _queue;
  final Uuid _uuid;

  @override
  Stream<List<SavedAddress>> watchAddressBook() => _local.watchAddressBook();

  @override
  Future<List<SavedAddress>> fetchAddresses() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.addresses,
    );
    final entries = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SavedAddress.fromJson)
        .whereType<SavedAddress>()
        .toList();
    // Le serveur fait foi : on remplace le cache local par sa version.
    await _local.replaceAddressBook(entries);
    return entries;
  }

  /// Enregistrement **local d'abord** (EXI-C05) : le carnet doit rester
  /// utilisable hors reseau. On ecrit en cache tout de suite, puis on pousse au
  /// serveur ; si le reseau manque, l'entree reste locale et part en file de
  /// synchronisation.
  @override
  Future<SavedAddress> saveAddress({
    String? id,
    required String label,
    required AddressKind kind,
    required Address address,
  }) async {
    final localId = id ?? 'local_${_uuid.v4()}';
    var entry = SavedAddress(
      id: localId,
      label: label,
      kind: kind,
      address: address,
    );
    await _local.upsertAddress(entry);

    final body = {
      'label': label,
      'kind': kind.wireName,
      'address': address.toJson(),
    };
    final path = id == null ? ApiEndpoints.addresses : ApiEndpoints.address(id);
    try {
      final json = id == null
          ? await _client.post<Map<String, dynamic>>(path, body: body)
          : await _client.patch<Map<String, dynamic>>(path, body: body);
      final server = SavedAddress.fromJson(json);
      if (server != null) {
        // Le serveur a pose l'identifiant definitif : on remplace l'entree
        // locale provisoire par la sienne.
        if (server.id != localId) await _local.deleteAddress(localId);
        await _local.upsertAddress(server);
        entry = server;
      }
    } on Failure {
      await _queue.enqueue(
        method: id == null ? 'POST' : 'PATCH',
        path: path,
        idempotencyKey: 'addr_$localId',
        body: body,
        priority: SyncPriority.rating,
      );
    }
    return entry;
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _local.deleteAddress(id);
    // Une entree jamais montee au serveur (id local) n'a rien a y supprimer.
    if (id.startsWith('local_')) return;
    try {
      await _client.delete<void>(ApiEndpoints.address(id));
    } on Failure {
      await _queue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.address(id),
        idempotencyKey: 'addr_del_$id',
        priority: SyncPriority.rating,
      );
    }
  }

  @override
  Future<void> touchAddress(String id) => _local.touchAddress(id);

  @override
  Future<String> uploadPackagePhoto({
    required List<int> bytes,
    required String contentType,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.media,
      body: {'imageBase64': base64Encode(bytes), 'contentType': contentType},
    );
    return json['id'] as String;
  }

  @override
  Stream<List<Delivery>> watchDeliveries() => _local.watchDeliveries();

  @override
  Future<Delivery?> deliveryById(String id) => _local.deliveryById(id);

  /// Creation locale d'abord, envoi ensuite (EXI-C13).
  ///
  /// L'ordre est l'exigence : une course creee dans un tunnel doit exister pour
  /// l'utilisateur avant toute tentative reseau. Si l'envoi echoue, la course
  /// reste marquee « en attente » et l'interface le montre — elle n'est ni
  /// perdue, ni faussement presentee comme diffusee aux livreurs.
  ///
  /// La cle d'idempotence est generee ici, et **conservee** pour les reprises :
  /// c'est elle qui garantit qu'une course envoyee deux fois n'en cree qu'une
  /// (EXI-S01, EXI-B01).
  @override
  Future<Delivery> createDelivery(DeliveryDraft draft) async {
    final localId = 'local_${_uuid.v4()}';
    final idempotencyKey = _uuid.v4();

    final local = Delivery(
      id: localId,
      status: DeliveryStatus.pending,
      kind: draft.kind,
      pickup: draft.pickup,
      dropoff: draft.dropoff,
      package: draft.package,
      slot: draft.slot,
      paymentMethod: draft.paymentMethod,
      createdAt: DateTime.now(),
      pendingSync: true,
      payer: draft.payer,
      shopping: draft.shopping,
      relayPointId: draft.relayPointId,
    );

    await _local.upsertDelivery(local, pendingSync: true);

    try {
      final json = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.deliveries,
        body: local.toJson()..remove('id'),
        idempotencyKey: idempotencyKey,
      );

      final confirmed = Delivery.fromJson(json);
      if (confirmed == null) throw const ServerFailure(statusCode: 500);

      await _local.replaceDelivery(localId, confirmed);
      return confirmed;
    } on Failure catch (failure) {
      AppLogger.instance.info(
        'delivery_queued',
        data: {'reason': failure.runtimeType.toString()},
      );

      // La cle generee plus haut est **deposee avec l'element**, pas
      // regeneree a la reprise : c'est elle qui garantit qu'une course
      // envoyee deux fois n'en cree qu'une (EXI-S01, EXI-B01).
      await _queue.enqueue(
        method: 'POST',
        path: ApiEndpoints.deliveries,
        idempotencyKey: idempotencyKey,
        body: local.toJson()..remove('id'),
        priority: SyncPriority.transition,
      );

      return local;
    }
  }

  @override
  Future<void> refreshDeliveries() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.deliveries,
    );
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Delivery.fromJson)
        .whereType<Delivery>()
        // Une reponse API ne doit jamais produire deux cartes pour la meme
        // course, meme si un proxy ou une pagination renvoie un doublon.
        .fold<Map<String, Delivery>>({}, (unique, delivery) {
          unique[delivery.id] = delivery;
          return unique;
        })
        .values
        .toList();
    await _local.replaceAll(items);
  }

  @override
  Future<int> cancelDelivery(String id, {String? reason}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.deliveryCancel(id),
      body: {'reason': ?reason},
    );
    final updated = Delivery.fromJson(json);
    if (updated != null) {
      await _local.upsertDelivery(updated, pendingSync: false);
    }
    return (json['cancelFee'] as num?)?.toInt() ?? 0;
  }
}
