import 'package:flutter/material.dart';

/// Les trois profils d'une application unique (§2.1).
///
/// Le role administrateur n'est jamais choisi par l'utilisateur : il est
/// attribue cote serveur (EXI-T02). Il figure ici parce que l'application doit
/// savoir l'afficher, pas le revendiquer.
enum UserRole {
  client('client'),
  driver('driver'),
  admin('admin');

  const UserRole(this.wireName);

  /// Valeur echangee avec le backend.
  final String wireName;

  static UserRole? fromWire(String? value) {
    for (final role in UserRole.values) {
      if (role.wireName == value) return role;
    }
    return null;
  }

  IconData get icon => switch (this) {
    UserRole.client => Icons.local_shipping_outlined,
    UserRole.driver => Icons.two_wheeler_outlined,
    UserRole.admin => Icons.admin_panel_settings_outlined,
  };
}
