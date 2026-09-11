import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Epinglage de certificat (EXI-SEC02).
///
/// Le TLS seul verifie qu'un certificat est signe par une autorite reconnue. Il
/// ne verifie pas que c'est **le bon** : une autorite compromise, ou un
/// certificat pousse sur l'appareil par un tiers, suffit a lire le trafic. Sur
/// un reseau mobile partage, c'est une attaque realiste, pas theorique.
///
/// L'epinglage compare l'empreinte de la cle publique servie a une liste
/// connue. Deux empreintes sont attendues, jamais une seule :
///
///  - l'empreinte **courante**, celle du certificat en service ;
///  - une empreinte **de secours**, celle du prochain certificat.
///
/// La raison est operationnelle, pas cryptographique. Avec une seule empreinte,
/// le jour du renouvellement, toutes les applications installees cessent de
/// fonctionner en meme temps — et il faut publier une mise a jour que les
/// utilisateurs mettront des semaines a installer. Avec deux, le nouveau
/// certificat est deja accepte avant d'etre mis en service.
class CertificatePinning {
  const CertificatePinning({required this.pins, this.enforced = true});

  /// Empreintes SHA-256 de cle publique, encodees en base64.
  ///
  /// Format identique a l'en-tete HTTP `Public-Key-Pins` : celui que produit
  /// `openssl` sur le certificat, ce qui evite une conversion manuelle a chaque
  /// rotation — et donc une erreur de saisie le jour ou il faut aller vite.
  final List<String> pins;

  /// Faux en developpement, ou aucun certificat n'est stable.
  ///
  /// La verification est **active par defaut** : un epinglage qu'on oublie
  /// d'activer ne protege personne, et l'oubli ne se voit pas.
  final bool enforced;

  /// Nombre minimal d'empreintes exigees pour que la rotation reste possible.
  static const int minimumPins = 2;

  /// La configuration permet-elle une rotation sans coupure ?
  bool get supportsRotation => pins.length >= minimumPins;

  /// Empreinte d'un certificat, au format attendu.
  static String fingerprintOf(X509Certificate certificate) =>
      base64Encode(sha256.convert(certificate.der).bytes);

  /// Le certificat servi est-il attendu ?
  ///
  /// Retourne `true` sans verifier lorsque l'epinglage est desactive : c'est le
  /// seul cas ou un certificat inconnu passe, et il est explicite.
  bool accepts(X509Certificate certificate) {
    if (!enforced) return true;
    return pins.contains(fingerprintOf(certificate));
  }

  /// Vue de la configuration pour le journal de diagnostic (EXI-P10).
  ///
  /// Les empreintes ne sont pas journalisees en entier : elles identifient
  /// l'infrastructure, et un journal exporte par un utilisateur circule.
  Map<String, dynamic> describe() => {
    'enforced': enforced,
    'pinCount': pins.length,
    'supportsRotation': supportsRotation,
    'pins': [for (final pin in pins) pin.substring(0, pin.length.clamp(0, 8))],
  };
}
