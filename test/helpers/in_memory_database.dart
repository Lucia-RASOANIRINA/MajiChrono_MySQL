import 'package:drift/native.dart';
import 'package:majichrono/core/storage/app_database.dart';

/// Base locale en memoire pour les tests.
///
/// Aucun fichier n'est touche : les tests d'integration de la file de
/// synchronisation (§16.2) peuvent donc s'executer en parallele sans se
/// marcher dessus.
AppDatabase openInMemoryDatabase() => AppDatabase.forTesting(NativeDatabase.memory());
