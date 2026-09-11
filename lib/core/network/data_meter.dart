import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories de consommation affichees a l'utilisateur (EXI-T07, D8).
enum DataCategory { api, photos, maps, tracking, payment, other }

/// Compteur de donnees consommees.
///
/// Argument de confiance identifie comme differenciant D8 : l'utilisateur voit
/// ce que l'application depense sur son forfait, ventile par usage.
/// Le compteur est remis a zero au changement de mois.
class DataMeter extends ChangeNotifier {
  DataMeter(this._prefs);

  static const String _keyCounters = 'data_meter.counters.v1';
  static const String _keyPeriod = 'data_meter.period.v1';

  final SharedPreferences _prefs;
  final Map<DataCategory, int> _sent = {};
  final Map<DataCategory, int> _received = {};

  Future<void> load() async {
    final period = _prefs.getString(_keyPeriod);
    final current = _currentPeriod();
    if (period != current) {
      await reset(period: current);
      return;
    }
    final raw = _prefs.getString(_keyCounters);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final category in DataCategory.values) {
      final entry = decoded[category.name] as Map<String, dynamic>?;
      if (entry == null) continue;
      _sent[category] = (entry['sent'] as num?)?.toInt() ?? 0;
      _received[category] = (entry['received'] as num?)?.toInt() ?? 0;
    }
  }

  void record(DataCategory category, {int sent = 0, int received = 0}) {
    if (sent == 0 && received == 0) return;
    _sent[category] = (_sent[category] ?? 0) + sent;
    _received[category] = (_received[category] ?? 0) + received;
    _persist();
    notifyListeners();
  }

  int sentFor(DataCategory category) => _sent[category] ?? 0;
  int receivedFor(DataCategory category) => _received[category] ?? 0;
  int totalFor(DataCategory category) =>
      sentFor(category) + receivedFor(category);

  int get total => DataCategory.values.fold(0, (sum, c) => sum + totalFor(c));

  Map<DataCategory, int> get breakdown => {
    for (final c in DataCategory.values) c: totalFor(c),
  };

  Future<void> reset({String? period}) async {
    _sent.clear();
    _received.clear();
    await _prefs.setString(_keyPeriod, period ?? _currentPeriod());
    await _prefs.remove(_keyCounters);
    notifyListeners();
  }

  void _persist() {
    final payload = <String, dynamic>{
      for (final c in DataCategory.values)
        c.name: {'sent': sentFor(c), 'received': receivedFor(c)},
    };
    // Ecriture non bloquante : la precision au dernier octet n'est pas critique.
    unawaitedSet(_keyCounters, jsonEncode(payload));
  }

  void unawaitedSet(String key, String value) {
    // ignore: discarded_futures
    _prefs.setString(key, value);
  }

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Rendu court : « 340 Ko », « 2,4 Mo ».
  static String format(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}
