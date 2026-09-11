import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/security/certificate_pinning.dart';
import 'package:majichrono/core/security/device_integrity.dart';

/// Durcissement (EXI-SEC02, EXI-SEC05, EXI-SEC06).
void main() {
  group('epinglage de certificat (EXI-SEC02)', () {
    test('deux empreintes permettent une rotation sans coupure', () {
      // Avec une seule empreinte, le jour du renouvellement, toutes les
      // applications installees cessent de fonctionner en meme temps.
      const single = CertificatePinning(pins: ['aaa']);
      const pair = CertificatePinning(pins: ['aaa', 'bbb']);

      expect(single.supportsRotation, isFalse);
      expect(pair.supportsRotation, isTrue);
      expect(CertificatePinning.minimumPins, 2);
    });

    test('la verification est active par defaut', () {
      // Un epinglage qu'on oublie d'activer ne protege personne, et l'oubli ne
      // se voit pas.
      const pinning = CertificatePinning(pins: ['aaa', 'bbb']);
      expect(pinning.enforced, isTrue);
    });

    test('le diagnostic ne publie pas les empreintes entieres', () {
      // Elles identifient l'infrastructure, et un journal exporte par un
      // utilisateur circule (EXI-P10).
      const pinning = CertificatePinning(
        pins: ['abcdefghijklmnop', 'qrstuvwxyz012345'],
      );

      final described = pinning.describe();
      final published = (described['pins'] as List<dynamic>).cast<String>();

      expect(described['pinCount'], 2);
      expect(described['supportsRotation'], isTrue);
      for (final pin in published) {
        expect(pin.length, lessThanOrEqualTo(8));
      }
      expect(published, isNot(contains('abcdefghijklmnop')));
    });
  });

  group('appareil compromis (EXI-SEC05)', () {
    test('un appareil sain ne declenche aucun avertissement', () {
      const integrity = DeviceIntegrity(fileSystem: _FakeProbe(android: true));
      expect(integrity.check(), IntegrityVerdict.clean);
      expect(IntegrityVerdict.clean.warrantsWarning, isFalse);
    });

    test('un binaire su connu suffit a signaler', () {
      const integrity = DeviceIntegrity(
        fileSystem: _FakeProbe(android: true, present: {'/system/bin/su'}),
      );

      expect(integrity.check(), IntegrityVerdict.compromised);
      expect(IntegrityVerdict.compromised.warrantsWarning, isTrue);
    });

    test('hors Android, le verdict est inconnu et non rassurant', () {
      // Repondre « sain » sur une plateforme non verifiee serait un mensonge
      // confortable.
      const integrity = DeviceIntegrity(fileSystem: _FakeProbe(android: false));

      expect(integrity.check(), IntegrityVerdict.unknown);
      expect(IntegrityVerdict.unknown.warrantsWarning, isFalse);
    });

    test('la detection previent, elle ne bloque pas', () {
      // Refuser de demarrer priverait de l'application des livreurs dont le
      // telephone d'occasion est arrive roote sans qu'ils l'aient su.
      expect(IntegrityVerdict.compromised.warrantsWarning, isTrue);
      expect(IntegrityVerdict.values.length, 3);
    });
  });

  group('ecrans proteges (EXI-SEC06)', () {
    test('la liste des surfaces sensibles est fermee et nommee', () {
      // C'est la seule facon de repondre a « qu'est-ce qui est protege ? » sans
      // relire toute l'application.
      expect(SecureSurface.values, hasLength(4));
      expect(
        SecureSurface.values.map((s) => s.wireName),
        containsAll([
          'pin_entry',
          'payment',
          'kyc_documents',
          'custody_capture',
        ]),
      );
    });
  });
}

class _FakeProbe implements FileProbe {
  const _FakeProbe({required this.android, this.present = const {}});

  final bool android;
  final Set<String> present;

  @override
  bool get isAndroid => android;

  @override
  bool exists(String path) => present.contains(path);
}
