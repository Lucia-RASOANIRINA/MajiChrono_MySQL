import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:majichrono/core/storage/app_database.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Persistance locale du carnet d'adresses et des courses.
///
/// C'est la source de verite de l'affichage : les ecrans lisent la base, jamais
/// le reseau. Consequence directe, l'historique et le carnet restent utilisables
/// hors ligne (EXI-C33, EXI-C13) et l'interface repond instantanement, sans
/// attendre un aller-retour a 2 500 ms en 2G (§4.1).
class DeliveryLocalDataSource {
  DeliveryLocalDataSource(this._db);

  final AppDatabase _db;

  // --- Carnet d'adresses -------------------------------------------------

  Stream<List<SavedAddress>> watchAddressBook() {
    final query = _db.select(_db.savedAddresses)
      ..orderBy([
        // Les plus utilisees d'abord : sur un carnet de dix entrees, cela evite
        // de faire defiler a chaque envoi.
        (t) => OrderingTerm.desc(t.useCount),
        (t) => OrderingTerm.desc(t.lastUsedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toSavedAddress).whereType<SavedAddress>().toList(),
    );
  }

  Future<void> upsertAddress(SavedAddress entry) => _db
      .into(_db.savedAddresses)
      .insertOnConflictUpdate(
        SavedAddressesCompanion.insert(
          id: entry.id,
          label: entry.label,
          // Le `payload` porte aussi la nature (domicile/travail/favori) : c'est
          // un blob volontairement souple (§4.3), on n'ajoute pas une colonne
          // ni une migration Drift pour ce seul champ.
          payload: jsonEncode({
            'kind': entry.kind.wireName,
            'address': entry.address.toJson(),
          }),
          useCount: Value(entry.useCount),
          lastUsedAt: Value(entry.lastUsedAt),
          createdAt: DateTime.now(),
        ),
      );

  /// Aligne le cache local sur le carnet du serveur (source de verite), **sans
  /// perdre** les entrees creees hors ligne pas encore synchronisees (id
  /// prefixe `local_`) : on ne remplace que la portion deja connue du serveur.
  Future<void> replaceAddressBook(List<SavedAddress> entries) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.savedAddresses,
        )..where((t) => t.id.like('local%').not())).go();
        for (final entry in entries) {
          await upsertAddress(entry);
        }
      });

  Future<void> deleteAddress(String id) =>
      (_db.delete(_db.savedAddresses)..where((t) => t.id.equals(id))).go();

  Future<void> touchAddress(String id) async {
    final row = await (_db.select(
      _db.savedAddresses,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (_db.update(_db.savedAddresses)..where((t) => t.id.equals(id))).write(
      SavedAddressesCompanion(
        useCount: Value(row.useCount + 1),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
  }

  SavedAddress? _toSavedAddress(SavedAddressesData row) {
    final decoded = jsonDecode(row.payload) as Map<String, dynamic>;
    // Forme actuelle : `{kind, address}`. Ancienne forme (avant la nature) : le
    // payload etait l'adresse elle-meme — on la lit encore, pour ne pas perdre
    // un carnet ecrit par une version anterieure.
    final rawAddress = decoded['address'] is Map<String, dynamic>
        ? decoded['address'] as Map<String, dynamic>
        : decoded;
    final address = Address.fromJson(rawAddress);
    if (address == null) return null;
    return SavedAddress(
      id: row.id,
      label: row.label,
      kind: AddressKind.fromWire(decoded['kind'] as String?),
      address: address,
      useCount: row.useCount,
      lastUsedAt: row.lastUsedAt,
    );
  }

  // --- Courses ------------------------------------------------------------

  Stream<List<Delivery>> watchDeliveries() {
    final query = _db.select(_db.cachedDeliveries)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(_toDelivery).whereType<Delivery>().toList(),
    );
  }

  Future<Delivery?> deliveryById(String id) async {
    final row = await (_db.select(
      _db.cachedDeliveries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDelivery(row);
  }

  Future<void> upsertDelivery(Delivery delivery, {required bool pendingSync}) =>
      _db
          .into(_db.cachedDeliveries)
          .insertOnConflictUpdate(
            CachedDeliveriesCompanion.insert(
              id: delivery.id,
              status: delivery.status.wireName,
              payload: jsonEncode(delivery.toJson()),
              createdAt: delivery.createdAt,
              updatedAt: DateTime.now(),
              pendingSync: Value(pendingSync),
            ),
          );

  /// Remplace l'identifiant local d'une course par celui attribue par le
  /// serveur, une fois la creation confirmee.
  ///
  /// L'identifiant local est genere par le client pour qu'une course creee hors
  /// ligne existe immediatement (EXI-C13) ; il n'a aucune valeur pour le
  /// serveur, qui attribue le sien.
  Future<void> replaceDelivery(String localId, Delivery confirmed) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.cachedDeliveries,
      )..where((t) => t.id.equals(localId))).go();
      await upsertDelivery(confirmed, pendingSync: false);
    });
  }

  Future<void> replaceAll(List<Delivery> deliveries) async {
    await _db.transaction(() async {
      // Les courses non transmises ne sont jamais ecrasees par une reponse
      // serveur : le serveur ne les connait pas encore.
      await (_db.delete(
        _db.cachedDeliveries,
      )..where((t) => t.pendingSync.equals(false))).go();
      for (final delivery in deliveries) {
        await upsertDelivery(delivery, pendingSync: false);
      }
    });
  }

  Delivery? _toDelivery(CachedDelivery row) {
    final delivery = Delivery.fromJson(
      jsonDecode(row.payload) as Map<String, dynamic>,
    );
    return delivery?.copyWith(pendingSync: row.pendingSync);
  }
}
