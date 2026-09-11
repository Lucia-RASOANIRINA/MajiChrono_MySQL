import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

/// File de synchronisation (§10.2).
///
/// Toute ecriture de l'application y transite avant toute tentative reseau
/// (regle 9.3.3). La table est creee des le module 0 pour que les modules
/// suivants n'aient qu'a y deposer leurs elements.
class SyncQueueItems extends Table {
  TextColumn get id => text()();

  /// Cle d'idempotence generee par le client (EXI-S01), stable entre reprises.
  TextColumn get idempotencyKey => text()();

  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get payload => text()();

  /// Ordre de priorite EXI-S02 : constats(0) > transitions(1) > positions(2) > notations(3).
  IntColumn get priority => integer().withDefault(const Constant(2))();

  /// `pending` | `inFlight` | `failed` | `abandoned`
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Un constat n'est jamais abandonne automatiquement (EXI-S05).
  BoolColumn get neverAbandon => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Journal des evenements du socle : diagnostic terrain sans donnee personnelle.
class AppEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

/// Cache cle-valeur pour les reponses consultables hors ligne (EXI-C33).
class CachedDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get body => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Carnet d'adresses (EXI-C05).
///
/// Stocke localement et non seulement sur le serveur : le carnet doit etre
/// consultable pour creer une course hors ligne (EXI-C13).
class SavedAddresses extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();

  /// Adresse serialisee. Un blob JSON plutot qu'une colonne par champ : la
  /// forme de l'adresse composite (§4.3) evoluera — photo de facade, note
  /// vocale, point relais — et chaque ajout imposerait sinon une migration.
  TextColumn get payload => text()();

  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Courses connues de l'appareil.
///
/// Le cache local est la **source de verite de l'affichage** : l'historique est
/// consultable hors ligne (EXI-C33) et une course creee sans reseau y figure
/// immediatement (EXI-C13).
class CachedDeliveries extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Vrai tant que le serveur n'a pas confirme la course.
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tampon local des positions du livreur (EXI-L10, EXI-S03).
///
/// Les positions ne partent pas une par une : elles s'accumulent ici et sont
/// envoyees par lots de cinquante. Une position pese peu, mais une par
/// quinze secondes pendant huit heures en fait deux mille — autant de requetes,
/// d'en-tetes et de poignees de main TLS sur un forfait qui se compte en
/// megaoctets (§4.4).
///
/// Le tampon est **persistant** et non en memoire : une application tuee par le
/// systeme pendant une tournee ne doit pas laisser un trou dans la trace, qui
/// est ce qui permet de reconstituer un trajet en cas de litige.
class BufferedPositions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Course concernee, lorsque la position en accompagne une.
  TextColumn get deliveryId => text().nullable()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get speedKmh => real().nullable()();
  RealColumn get accuracyMeters => real().nullable()();

  /// Horodatage de la mesure, pas de l'envoi : c'est le moment ou le livreur
  /// etait la, et il ne doit pas etre reecrit par la date de transmission.
  DateTimeColumn get recordedAt => dateTime()();
}

@DriftDatabase(
  tables: [
    SyncQueueItems,
    AppEvents,
    CachedDocuments,
    SavedAddresses,
    CachedDeliveries,
    BufferedPositions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur de test : base en memoire, aucun fichier touche.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 -> v2 : arrivee du module 2 (carnet d'adresses et cache des courses).
      // Une migration explicite, et non un `deleteEverything` : un utilisateur
      // qui met a jour l'application ne doit pas perdre ce qui n'a pas encore
      // ete transmis au serveur.
      if (from < 2) {
        await m.createTable(savedAddresses);
        await m.createTable(cachedDeliveries);
      }
      // v2 -> v3 : arrivee du module 6 (tampon de positions du livreur).
      if (from < 3) {
        await m.createTable(bufferedPositions);
      }
    },
    beforeOpen: (details) async {
      // Integrite referentielle active des l'ouverture.
      await customStatement('PRAGMA foreign_keys = ON');
      // WAL : indispensable pour EXI-P08 (aucune perte a l'arret brutal).
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'majichrono.sqlite'));
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    return NativeDatabase.createInBackground(file);
  });
}
