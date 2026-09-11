import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Traduit l'`avatarUrl` d'un compte en source d'image affichable.
///
/// Deux formes coexistent : en mode reel, une URL `https://.../avatar` servie
/// par le backend ; en mode simule, une `data:` URI qui porte l'image en clair
/// (le simulateur n'a pas de serveur d'images). On rend la bonne source pour
/// chacune, ou `null` quand il n'y a pas de photo — l'appelant retombe alors sur
/// l'initiale.
ImageProvider? avatarImage(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(url);
}
