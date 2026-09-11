import 'package:flutter_test/flutter_test.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

/// EXI-T01 : inscription par numero malgache `+261 3x xx xxx xx`.
///
/// C'est le premier champ que remplit tout utilisateur de l'application. Un
/// rejet a tort ferme la porte a un livreur ; une acceptation a tort envoie un
/// SMS dans le vide et laisse l'utilisateur attendre un code qui n'arrivera pas.
void main() {
  group('formes acceptees', () {
    const equivalentes = [
      '+261341234567',
      '+261 34 12 345 67',
      '00261341234567',
      '0341234567',
      '034 12 345 67',
      '034-12-345-67',
      '(034) 12 345 67',
      '261341234567',
    ];

    test('toutes les ecritures usuelles donnent le meme numero canonique', () {
      for (final saisie in equivalentes) {
        final phone = MalagasyPhone.tryParse(saisie);
        expect(phone, isNotNull, reason: 'refuse a tort : $saisie');
        expect(phone!.e164, '+261341234567', reason: 'mal normalise : $saisie');
      }
    });
  });

  group('formes refusees', () {
    const invalides = {
      '': 'vide',
      '0341234': 'trop court',
      '03412345678': 'trop long',
      '+261241234567': 'ne commence pas par 3 (fixe)',
      '+33612345678': 'indicatif etranger',
      'abcdefghij': 'non numerique',
      '+2613412345a': 'caractere parasite',
    };

    test('les saisies invalides sont refusees', () {
      invalides.forEach((saisie, motif) {
        expect(
          MalagasyPhone.tryParse(saisie),
          isNull,
          reason: 'accepte a tort ($motif) : "$saisie"',
        );
      });
    });
  });

  group('operateur', () {
    test('les prefixes connus sont reconnus', () {
      expect(MalagasyPhone.tryParse('0321234567')!.operator, MobileOperator.orange);
      expect(MalagasyPhone.tryParse('0371234567')!.operator, MobileOperator.orange);
      expect(MalagasyPhone.tryParse('0391234567')!.operator, MobileOperator.orange);
      expect(MalagasyPhone.tryParse('0331234567')!.operator, MobileOperator.airtel);
      expect(MalagasyPhone.tryParse('0341234567')!.operator, MobileOperator.telma);
      expect(MalagasyPhone.tryParse('0381234567')!.operator, MobileOperator.telma);
      expect(MalagasyPhone.tryParse('0361234567')!.operator, MobileOperator.telma);
    });

    test('le fixe Telma est reconnu', () {
      // Beaucoup de boutiques d'Antananarivo n'ont qu'un 020.
      final phone = MalagasyPhone.tryParse('0202212345');
      expect(phone, isNotNull);
      expect(phone!.operator, MobileOperator.telmaFixe);
    });

    test('un prefixe qu aucun operateur n exploite est refuse', () {
      // Le refus est volontaire : un numero bien forme mais impossible partait
      // autrefois en inscription, le SMS n'arrivait jamais, et l'utilisateur
      // concluait que l'application ne marche pas.
      for (final input in ['0301234567', '0351234567', '0311234567']) {
        expect(MalagasyPhone.tryParse(input), isNull, reason: input);
        expect(MalagasyPhone.isUnknownOperator(input), isTrue, reason: input);
      }
    });

    test('une saisie trop courte n est pas un prefixe inconnu', () {
      // Distinguer les deux permet d'afficher le bon message : « prefixe
      // inconnu » sur un numero complet, « numero invalide » sur une saisie en
      // cours.
      expect(MalagasyPhone.isUnknownOperator('034123'), isFalse);
    });

    test('seules les lignes mobiles recoivent un SMS', () {
      expect(MobileOperator.telma.receivesSms, isTrue);
      expect(MobileOperator.telmaFixe.receivesSms, isFalse);
      expect(MobileOperator.unknown.receivesSms, isFalse);
    });
  });

  group('mises en forme', () {
    final phone = MalagasyPhone.tryParse('+261341234567')!;

    test('forme nationale lisible', () {
      expect(phone.displayNational, '034 12 345 67');
    });

    test('forme internationale lisible', () {
      expect(phone.displayInternational, '+261 34 12 345 67');
    });

    test('forme masquee : rien d exploitable ne subsiste', () {
      // EXI-T10 et EXI-B07 : c'est la seule forme admise dans un journal ou
      // face a l'autre partie.
      expect(phone.masked, '+261 ** ** *** 67');
      expect(phone.masked.contains('1234'), isFalse);
    });
  });

  test('l egalite porte sur le numero canonique, pas sur la saisie', () {
    expect(
      MalagasyPhone.tryParse('0341234567'),
      MalagasyPhone.tryParse('+261 34 12 345 67'),
    );
  });
}
