import 'package:majichrono/core/storage/secure_store.dart';

/// Stockage securise en memoire.
///
/// `flutter_secure_storage` s'appuie sur le Keystore Android, indisponible dans
/// un test qui s'execute sur le poste. Cette doublure conserve l'interface et
/// permet en plus d'inspecter ce qui a reellement ete ecrit — ce dont se sert le
/// test qui verifie qu'aucun code PIN n'apparait en clair.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> wipe() async => _values.clear();

  bool get isEmpty => _values.isEmpty;

  Map<String, String> dump() => Map.unmodifiable(_values);
}
