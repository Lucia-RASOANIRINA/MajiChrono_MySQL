import 'dart:io';

/// Integrite de l'appareil et protection de l'affichage (EXI-SEC05, EXI-SEC06).
///
/// Deux mesures, deux intentions distinctes :
///
///  - **EXI-SEC05** : un appareil roote donne a n'importe quelle application le
///    droit de lire le stockage des autres. Le chiffrement au repos des
///    constats (EXI-CC46) et le Keystore y perdent une bonne part de leur
///    valeur. On ne peut pas l'empecher ; on peut le **savoir et le dire**.
///  - **EXI-SEC06** : les ecrans qui affichent un code de paiement, un code
///    PIN ou une piece d'identite ne doivent pas finir dans une capture
///    d'ecran, ni dans l'apercu des applications recentes.
///
/// Aucune de ces mesures n'est infaillible : un appareil roote peut mentir, et
/// une capture peut se faire avec un second telephone. Elles relevent le cout
/// d'une attaque opportuniste, pas d'une attaque determinee — et c'est
/// exactement ce qu'on leur demande.

/// Verdict d'integrite.
enum IntegrityVerdict {
  /// Aucun indice de compromission.
  clean('clean'),

  /// Indices presents : binaires connus, chemins accessibles en ecriture.
  compromised('compromised'),

  /// Verification impossible sur cette plateforme.
  unknown('unknown');

  const IntegrityVerdict(this.wireName);

  final String wireName;

  /// Faut-il prevenir l'utilisateur ?
  ///
  /// Prevenir, pas bloquer. Refuser de demarrer sur un appareil roote
  /// priverait de l'application des livreurs dont le telephone d'occasion est
  /// arrive roote, sans qu'ils l'aient demande ni meme su.
  bool get warrantsWarning => this == IntegrityVerdict.compromised;
}

/// Detection d'appareil roote (EXI-SEC05).
///
/// Heuristique volontairement simple : la presence de binaires et de chemins
/// que seul un appareil modifie possede. Une detection sophistiquee se contourne
/// tout aussi facilement, pour un cout de maintenance bien superieur.
class DeviceIntegrity {
  const DeviceIntegrity({this.fileSystem = const LocalFileProbe()});

  final FileProbe fileSystem;

  /// Chemins caracteristiques d'un appareil Android modifie.
  static const List<String> suspiciousPaths = [
    '/system/app/Superuser.apk',
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/data/local/su',
    '/data/local/bin/su',
    '/data/local/xbin/su',
    '/system/sd/xbin/su',
  ];

  IntegrityVerdict check() {
    // La verification n'a de sens que sur Android : sur iOS le jailbreak se
    // detecte autrement, et sur un poste de developpement elle n'a aucun objet.
    if (!fileSystem.isAndroid) return IntegrityVerdict.unknown;

    final found = suspiciousPaths.any(fileSystem.exists);
    return found ? IntegrityVerdict.compromised : IntegrityVerdict.clean;
  }
}

/// Acces au systeme de fichiers, injectable pour les tests.
abstract interface class FileProbe {
  bool get isAndroid;
  bool exists(String path);
}

class LocalFileProbe implements FileProbe {
  const LocalFileProbe();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool exists(String path) => File(path).existsSync();
}

/// Ecrans dont le contenu ne doit pas etre capturable (EXI-SEC06).
///
/// La liste est **fermee** et nommee ici plutot que laissee au jugement de
/// chaque ecran : c'est la seule facon de repondre a « qu'est-ce qui est
/// protege ? » sans relire toute l'application.
enum SecureSurface {
  /// Saisie et creation du code PIN.
  pinEntry('pin_entry'),

  /// Code QR de paiement et ecran de confirmation.
  payment('payment'),

  /// Pieces d'identite d'un dossier KYC.
  kycDocuments('kyc_documents'),

  /// Constat en cours : photos, signatures, position.
  custodyCapture('custody_capture');

  const SecureSurface(this.wireName);

  final String wireName;
}
