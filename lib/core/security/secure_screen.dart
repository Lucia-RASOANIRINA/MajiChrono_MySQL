import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/security/device_integrity.dart';

/// Interdit la capture d'ecran tant que l'ecran est affiche (EXI-SEC06).
///
/// Enveloppe l'ecran plutot que d'exiger un appel dans chaque `initState` :
/// une protection qu'il faut penser a poser est une protection qu'on oublie de
/// poser sur l'ecran suivant.
///
/// Le drapeau est **retire au demontage**, jamais laisse en place : le laisser
/// actif noircirait l'apercu de toute l'application dans les applications
/// recentes, y compris sur des ecrans qui n'ont rien de sensible.
///
/// La protection couvre la capture systeme et l'apercu des recents. Elle ne
/// couvre pas un second telephone braque sur l'ecran — rien ne le peut, et
/// pretendre le contraire serait pire que ne rien faire.
class SecureScreen extends StatefulWidget {
  const SecureScreen({required this.surface, required this.child, super.key});

  final SecureSurface surface;
  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  /// Canal de la plateforme. Sur Android il pose `FLAG_SECURE`.
  static const MethodChannel _channel = MethodChannel('mg.majichrono/secure');

  @override
  void initState() {
    super.initState();
    _apply(secure: true);
  }

  @override
  void dispose() {
    _apply(secure: false);
    super.dispose();
  }

  Future<void> _apply({required bool secure}) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException catch (error) {
      // L'echec est journalise mais **jamais bloquant** : un livreur ne doit
      // pas se retrouver incapable de faire un constat parce qu'une API
      // systeme a change de comportement sur son modele de telephone.
      AppLogger.instance.warn(
        'secure_flag_failed',
        data: {'surface': widget.surface.wireName, 'code': error.code},
      );
    } on MissingPluginException {
      // Plateforme sans implementation native — poste de developpement, test.
      // Silencieux : ce n'est pas une anomalie d'execution.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
