/// Operateur de telephonie mobile malgache, deduit du prefixe du numero.
///
/// L'information sert deux fois : afficher a l'utilisateur qu'on a bien reconnu
/// son operateur — rassurant quand on saisit un numero sur un ecran de 5 pouces —
/// et, plus tard, orienter le paiement vers le bon connecteur MajiPay. Le module
/// M11 du §11.3 designe explicitement cette detection par prefixe comme une
/// brique du routage operateur ; la faire ici evite de la refaire au module 7.
enum MobileOperator {
  orange('Orange', {'32', '37', '39'}),
  airtel('Airtel', {'33'}),

  /// Telma, qui exploite commercialement la marque YAS depuis 2025. Le libelle
  /// retenu est « Telma » : c'est le nom sous lequel les utilisateurs designent
  /// encore leur ligne, et celui qui figure sur leurs factures.
  telma('Telma', {'34', '38', '36'}),

  /// Ligne fixe Telma, en `020 XX XXX XX`.
  ///
  /// Elle est acceptee parce que beaucoup de boutiques et de bureaux
  /// d'Antananarivo n'ont que ce numero. Elle ne recoit **pas** de SMS : un
  /// compte ouvert sur un fixe doit passer par l'entree e-mail, ce que
  /// [receivesSms] permet a l'interface d'anticiper au lieu de laisser
  /// l'utilisateur attendre un code qui n'arrivera jamais.
  telmaFixe('Telma fixe', {'20'}),

  unknown('', {});

  const MobileOperator(this.label, this.prefixes);

  final String label;

  /// Deux chiffres suivant l'indicatif pays, sans le 0 national.
  final Set<String> prefixes;

  bool get isKnown => this != MobileOperator.unknown;

  bool get receivesSms =>
      this != MobileOperator.unknown && this != MobileOperator.telmaFixe;

  static MobileOperator fromNationalPrefix(String twoDigits) {
    for (final operator in MobileOperator.values) {
      if (operator.prefixes.contains(twoDigits)) return operator;
    }
    return MobileOperator.unknown;
  }
}

/// Numero de telephone mobile malgache (EXI-T01).
///
/// Format canonique retenu : `+261XXXXXXXXX` — indicatif pays suivi de neuf
/// chiffres commencant par 3. C'est cette forme qui circule sur le reseau ; les
/// formes saisies par l'utilisateur (`034 12 345 67`, `+261 34 12 345 67`,
/// `0341234567`) sont toutes normalisees vers elle.
///
/// La validation n'accepte que les plages **reellement exploitees a
/// Madagascar** : Orange (032, 037, 039), Airtel (033), Telma (034 et 038) et
/// le fixe Telma (020). Un numero en 035 ou 036 est refuse a la saisie.
///
/// C'est un choix, et il a un cout : le jour ou l'ARTEC attribue une nouvelle
/// plage, cette liste devra etre completee avant qu'un abonne de cette plage
/// puisse s'inscrire. Le cout inverse est plus lourd — un numero mal recopie
/// mais formellement valide part en inscription, le SMS n'arrive jamais, et
/// l'utilisateur conclut que l'application ne marche pas. Mieux vaut refuser
/// tot, avec un message qui nomme les operateurs attendus.
class MalagasyPhone {
  const MalagasyPhone._(this.e164);

  /// Forme canonique `+261XXXXXXXXX`.
  final String e164;

  static const String countryCode = '261';
  static const int nationalLength = 9;

  /// Analyse une saisie utilisateur. Retourne `null` si le numero est invalide.
  ///
  /// Tolerante a la mise en forme : espaces, points, tirets et parentheses sont
  /// ignores, car un utilisateur recopie son numero comme il l'a note.
  static MalagasyPhone? tryParse(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return null;

    var national = digits;

    if (national.startsWith('+$countryCode')) {
      national = national.substring(countryCode.length + 1);
    } else if (national.startsWith('00$countryCode')) {
      national = national.substring(countryCode.length + 2);
    } else if (national.startsWith(countryCode) &&
        national.length == countryCode.length + nationalLength) {
      national = national.substring(countryCode.length);
    } else if (national.startsWith('0')) {
      // Forme nationale : le 0 remplace l'indicatif pays.
      national = national.substring(1);
    }

    if (national.length != nationalLength) return null;
    if (!RegExp(r'^\d{9}$').hasMatch(national)) return null;

    // Le prefixe doit designer un operateur connu. C'est ce qui distingue un
    // numero valide d'un numero seulement bien forme.
    if (!MobileOperator.fromNationalPrefix(national.substring(0, 2)).isKnown) {
      return null;
    }

    return MalagasyPhone._('+$countryCode$national');
  }

  static bool isValid(String input) => tryParse(input) != null;

  /// Vrai si la saisie est bien formee — neuf chiffres apres l'indicatif — mais
  /// portee par un prefixe qu'aucun operateur n'exploite.
  ///
  /// Distinguer ce cas de la simple faute de frappe permet de dire *pourquoi* le
  /// numero est refuse : « 035 n'est pas un prefixe malgache » aide, « numero
  /// invalide » n'aide pas.
  static bool isUnknownOperator(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    var national = digits;
    if (national.startsWith('+$countryCode')) {
      national = national.substring(countryCode.length + 1);
    } else if (national.startsWith('00$countryCode')) {
      national = national.substring(countryCode.length + 2);
    } else if (national.startsWith(countryCode) &&
        national.length == countryCode.length + nationalLength) {
      national = national.substring(countryCode.length);
    } else if (national.startsWith('0')) {
      national = national.substring(1);
    }

    if (!RegExp(r'^\d{9}$').hasMatch(national)) return false;
    return !MobileOperator.fromNationalPrefix(
      national.substring(0, 2),
    ).isKnown;
  }

  /// Les neuf chiffres nationaux, sans indicatif ni zero.
  String get national => e164.substring(countryCode.length + 1);

  MobileOperator get operator =>
      MobileOperator.fromNationalPrefix(national.substring(0, 2));

  /// Mise en forme lisible : `034 12 345 67`.
  ///
  /// C'est la forme sous laquelle un Malgache lit et dicte son numero ; afficher
  /// `+261341234567` d'un bloc rend la relecture penible et les erreurs de
  /// saisie invisibles.
  String get displayNational {
    final n = national;
    return '0${n.substring(0, 2)} ${n.substring(2, 4)} '
        '${n.substring(4, 7)} ${n.substring(7)}';
  }

  /// Mise en forme internationale : `+261 34 12 345 67`.
  String get displayInternational {
    final n = national;
    return '+$countryCode ${n.substring(0, 2)} ${n.substring(2, 4)} '
        '${n.substring(4, 7)} ${n.substring(7)}';
  }

  /// Forme masquee, seule autorisee dans un journal ou face a l'autre partie
  /// (EXI-T10, EXI-B07) : `+261 ** ** *** 67`.
  String get masked => '+$countryCode ** ** *** ${national.substring(7)}';

  @override
  String toString() => e164;

  @override
  bool operator ==(Object other) =>
      other is MalagasyPhone && other.e164 == e164;

  @override
  int get hashCode => e164.hashCode;
}
