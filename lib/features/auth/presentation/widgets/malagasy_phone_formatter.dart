import 'package:flutter/services.dart';

/// Mise en forme du numero pendant la saisie : `34 12 345 67`.
///
/// Le champ affiche l'indicatif `+261` a part, en prefixe fixe : l'utilisateur
/// ne tape que ses neuf chiffres nationaux, et les espaces se posent seuls la
/// ou un Malgache les dicte. Trois defauts de la saisie libre disparaissent :
///
/// - les espaces ne sont plus a taper, ni a effacer un par un : le retour
///   arriere place juste apres un espace efface le chiffre qui le precede ;
/// - une saisie `034…`, `+261 34…` ou `00261…` collee depuis un SMS ou un
///   contact est ramenee aux neuf chiffres, sans que l'utilisateur ait a
///   retirer le zero ou l'indicatif ;
/// - le curseur reste a sa place logique (meme nombre de chiffres a sa
///   gauche), meme quand un espace apparait ou disparait sous lui.
class MalagasyPhoneFormatter extends TextInputFormatter {
  const MalagasyPhoneFormatter();

  static const int nationalDigits = 9;

  /// Positions (en chiffres) apres lesquelles un espace est insere : 2-2-3-2.
  static const List<int> _breaks = [2, 4, 7];

  /// Met en forme neuf chiffres nationaux au plus.
  static String format(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (_breaks.contains(i)) out.write(' ');
      out.write(digits[i]);
    }
    return out.toString();
  }

  /// Ramene une saisie quelconque aux chiffres nationaux, sans 0 ni indicatif.
  ///
  /// Rend aussi combien de chiffres de tete ont ete retires, pour recaler le
  /// curseur.
  static (String, int) normalize(String raw) {
    final hasPlus = raw.trimLeft().startsWith('+');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    var stripped = 0;

    if (hasPlus && digits.startsWith('261')) {
      stripped = 3;
    } else if (digits.startsWith('00261')) {
      stripped = 5;
    } else if (digits.startsWith('261') && digits.length >= 12) {
      stripped = 3;
    } else if (digits.startsWith('0')) {
      stripped = 1;
    }
    digits = digits.substring(stripped);
    if (digits.length > nationalDigits) {
      digits = digits.substring(0, nationalDigits);
    }
    return (digits, stripped);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var cursor = newValue.selection.baseOffset.clamp(0, text.length);

    // Retour arriere sur un espace : les chiffres n'ont pas change, seul le
    // separateur a disparu — et la mise en forme le remettrait aussitot. On
    // efface donc le chiffre qui le precede, ce que l'utilisateur voulait.
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final newDigitsRaw = text.replaceAll(RegExp(r'\D'), '');
    final deletedSeparator =
        text.length < oldValue.text.length && oldDigits == newDigitsRaw;
    if (deletedSeparator && cursor > 0) {
      text = text.substring(0, cursor - 1) + text.substring(cursor);
      cursor -= 1;
    }

    final digitsBeforeCursor = text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final (digits, stripped) = normalize(text);
    final logical = (digitsBeforeCursor - stripped).clamp(0, digits.length);

    final formatted = format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetForDigit(formatted, logical),
      ),
    );
  }

  /// Position, dans le texte mis en forme, qui suit le [digitCount]-ieme
  /// chiffre.
  static int _offsetForDigit(String formatted, int digitCount) {
    if (digitCount == 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted.codeUnitAt(i) != 0x20) seen++;
      if (seen == digitCount) return i + 1;
    }
    return formatted.length;
  }
}
