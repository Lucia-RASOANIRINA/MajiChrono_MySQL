import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/auth/presentation/widgets/malagasy_phone_formatter.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Champ de numero malgache : indicatif `+261` fixe, neuf chiffres mis en
/// forme pendant la frappe (`34 12 345 67`), operateur reconnu affiche sous le
/// champ.
///
/// Le numero valide remonte par [onChanged] (nul tant qu'il ne l'est pas) :
/// l'ecran n'a jamais a re-analyser le texte saisi.
class PhoneField extends StatefulWidget {
  const PhoneField({
    required this.onChanged,
    this.initial,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.label,
    super.key,
  });

  final ValueChanged<MalagasyPhone?> onChanged;
  final MalagasyPhone? initial;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final String? label;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null
        ? ''
        : MalagasyPhoneFormatter.format(widget.initial!.national),
  );
  MalagasyPhone? _phone;

  @override
  void initState() {
    super.initState();
    _phone = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final phone = MalagasyPhone.tryParse(text);
    setState(() => _phone = phone);
    widget.onChanged(phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final digits = _controller.text.replaceAll(' ', '');
    final complete = digits.length == MalagasyPhoneFormatter.nationalDigits;

    final String? error = complete && _phone == null
        ? (MalagasyPhone.isUnknownOperator(digits)
              ? l10n.authPhoneUnknownOperator
              : l10n.authPhoneInvalid)
        : null;
    final String? helper = switch (_phone?.operator) {
      null || MobileOperator.unknown => null,
      final known => l10n.authPhoneOperator(known.label),
    };

    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
        const MalagasyPhoneFormatter(),
      ],
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      decoration: InputDecoration(
        labelText: widget.label ?? l10n.authPhoneLabel,
        hintText: '34 12 345 67',
        errorText: error,
        helperText: helper,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadii.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _MadagascarFlag(),
                const SizedBox(width: 6),
                Text(
                  l10n.authPhoneCountry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 48),
        suffixIcon: _phone != null
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
            : null,
      ),
      onChanged: _changed,
      onSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}

/// Drapeau malgache dessine : blanc au guindant, rouge et vert en bandes.
/// Dessine plutot qu'un emoji, que certains Android d'entree de gamme
/// affichent en deux lettres « MG ».
class _MadagascarFlag extends StatelessWidget {
  const _MadagascarFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 22,
        height: 15,
        child: Row(
          children: [
            Container(width: 7, color: Colors.white),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ColoredBox(color: Color(0xFFFC3D32))),
                  Expanded(child: ColoredBox(color: Color(0xFF007E3A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
