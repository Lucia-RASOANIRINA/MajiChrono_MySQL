import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Pave numerique du code PIN.
///
/// Un pave dedie plutot que le clavier systeme, pour trois raisons : les touches
/// font 72 dp, bien au-dela des 48 dp exiges par EXI-T09, ce qui compte pour un
/// livreur qui saisit son code d'une main, moto a l'arret ; aucun clavier tiers
/// ne voit passer le code ; et la disposition ne change pas d'un telephone a
/// l'autre, ce qui evite la faute de frappe sur un parc materiel heterogene (§4.4).
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometrics,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Affiche une touche de biometrie si l'appareil en dispose (EXI-T04).
  final VoidCallback? onBiometrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            _Row(
              children: [
                for (final d in row) _DigitKey(digit: d, onTap: onDigit),
              ],
            ),
          _Row(
            children: [
              if (onBiometrics != null)
                _IconKey(icon: Icons.fingerprint, onTap: onBiometrics!)
              else
                const SizedBox(width: 72, height: 72),
              _DigitKey(digit: '0', onTap: onDigit),
              _IconKey(icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    ),
  );
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onTap});

  final String digit;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(digit),
          child: Center(
            child: Text(digit, style: theme.textTheme.headlineMedium),
          ),
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Icon(icon, size: 28)),
    ),
  );
}

/// Points indiquant les chiffres deja saisis.
class PinDots extends StatelessWidget {
  const PinDots({
    required this.filled,
    this.length = 4,
    this.error = false,
    super.key,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error
                  ? scheme.error
                  : i < filled
                  ? scheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: error ? scheme.error : scheme.outline,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}
