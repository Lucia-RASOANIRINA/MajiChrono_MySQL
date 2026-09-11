import 'dart:collection';

import 'package:logger/logger.dart';

/// Journalisation applicative.
///
/// Deux exigences pilotent ce fichier :
///  - EXI-T10 / EXI-MP11 : aucune donnee personnelle ni de paiement en clair ;
///  - EXI-P10 : journal local circulaire de 5 Mo, exportable par l'utilisateur.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxBufferBytes = 5 * 1024 * 1024;

  final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 6, colors: false),
    filter: ProductionFilter(),
  );

  final Queue<String> _buffer = Queue<String>();
  int _bufferBytes = 0;

  void debug(String message, {Map<String, Object?>? data}) =>
      _emit(Level.debug, message, data);

  void info(String message, {Map<String, Object?>? data}) =>
      _emit(Level.info, message, data);

  void warn(String message, {Map<String, Object?>? data, Object? error}) =>
      _emit(Level.warning, message, data, error);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) => _emit(Level.error, message, data, error, stackTrace);

  void _emit(
    Level level,
    String message,
    Map<String, Object?>? data, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final safeData = data == null ? '' : ' ${redactMap(data)}';
    final line = '[${level.name}] ${redact(message)}$safeData';
    _push(line);
    _logger.log(level, line, error: error, stackTrace: stackTrace);
  }

  void _push(String line) {
    _buffer.addLast(line);
    _bufferBytes += line.length;
    while (_bufferBytes > _maxBufferBytes && _buffer.isNotEmpty) {
      _bufferBytes -= _buffer.removeFirst().length;
    }
  }

  /// Export destine au support (EXI-P10).
  String exportBuffer() => _buffer.join('\n');

  void clear() {
    _buffer.clear();
    _bufferBytes = 0;
  }

  // --- Expurgation (EXI-T10, EXI-MP11) ---------------------------------

  static const Set<String> sensitiveKeys = {
    'phone',
    'phoneNumber',
    'msisdn',
    'telephone',
    'contactPhone',
    'otp',
    'code',
    'pin',
    'password',
    'token',
    'accessToken',
    'refreshToken',
    'authorization',
    'signature',
    'cin',
    'idNumber',
    'balance',
    'amount',
    'accountNumber',
    'paymentReference',
    'wallet',
    'latitude',
    'longitude',
    'lat',
    'lng',
  };

  static final RegExp _phonePattern = RegExp(r'\+?261[\s\d]{8,}|\b0\d{9}\b');
  static final RegExp _longDigits = RegExp(r'\b\d{6,}\b');

  /// Masque un numero en ne conservant que les deux derniers chiffres.
  static String maskPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '***';
    return '***${digits.substring(digits.length - 2)}';
  }

  static String redact(String input) => input
      .replaceAllMapped(_phonePattern, (m) => maskPhone(m.group(0)!))
      .replaceAll(_longDigits, '******');

  static Map<String, Object?> redactMap(Map<String, Object?> input) {
    return input.map((key, value) {
      if (sensitiveKeys.contains(key)) return MapEntry(key, '***');
      if (value is String) return MapEntry(key, redact(value));
      if (value is Map<String, Object?>) return MapEntry(key, redactMap(value));
      return MapEntry(key, value);
    });
  }
}
