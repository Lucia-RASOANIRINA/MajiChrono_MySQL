import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majichrono/app/app.dart';
import 'package:majichrono/core/config/app_config.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/data_meter.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/storage/app_database.dart';

/// Amorcage de l'application.
///
/// Tout ce qui doit exister avant le premier pixel est initialise ici, puis
/// injecte par surcharge de providers. Consequence directe : aucun ecran
/// n'affiche de chargement pour attendre le socle, ce qui sert l'exigence
/// EXI-P01 (ecran interactif en moins de 2,5 s sur un appareil a 2 Go).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final logger = AppLogger.instance;

  FlutterError.onError = (details) {
    logger.error(
      'flutter_error',
      error: details.exception,
      stackTrace: details.stack,
      data: {'library': details.library ?? 'flutter'},
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('platform_error', error: error, stackTrace: stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  final dataMeter = DataMeter(prefs);
  await dataMeter.load();

  final database = AppDatabase();

  logger.info(
    'bootstrap',
    data: {'apiMode': config.apiMode.name, 'flavor': config.flavor.name},
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dataMeterProvider.overrideWithValue(dataMeter),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const MajiChronoApp(),
    ),
  );
}
