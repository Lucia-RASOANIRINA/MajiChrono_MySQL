import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Zone de signature manuscrite (EXI-CC16, EXI-CC24, EXI-CC40).
///
/// La capture est **vectorielle** : chaque point porte ses coordonnees, une
/// pression et un temps relatif. Le rendu visible n'est qu'une projection de
/// ces points ; c'est le vecteur qui est conserve et transmis. Une image de
/// signature se copie-colle, une suite de points horodates se rejoue et
/// s'expertise.
///
/// La mention d'engagement (EXI-CC18) est affichee **au-dessus** de la zone,
/// dans la langue de l'utilisateur : signer sous une phrase qu'on n'a pas lue
/// n'engage personne.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    required this.signerLabel,
    required this.onChanged,
    this.height = 200,
    super.key,
  });

  /// Qui signe : expediteur, livreur, destinataire, tiers.
  final String signerLabel;

  /// Emet la signature des qu'un trait existe, `null` si la zone est vide.
  final ValueChanged<VectorSignature?> onChanged;

  final double height;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<SignaturePoint>> _strokes = [];
  List<SignaturePoint> _current = [];
  DateTime? _startedAt;

  void _begin(Offset position, double pressure) {
    _startedAt ??= DateTime.now();
    _current = [_point(position, pressure)];
    setState(() => _strokes.add(_current));
    _emit();
  }

  void _extend(Offset position, double pressure) {
    if (_strokes.isEmpty) return;
    setState(() => _current.add(_point(position, pressure)));
    _emit();
  }

  SignaturePoint _point(Offset position, double pressure) => SignaturePoint(
    position.dx,
    position.dy,
    // Les ecrans capacitifs d'entree de gamme ne remontent pas de pression
    // reelle : on retient une valeur par defaut plutot que zero, qui laisserait
    // croire a un trace sans appui.
    pressure <= 0 ? 0.5 : pressure,
    DateTime.now().difference(_startedAt!).inMilliseconds,
  );

  void _emit() => widget.onChanged(
    _strokes.isEmpty
        ? null
        : VectorSignature(
            strokes: _strokes,
            signedAt: DateTime.now(),
            signerLabel: widget.signerLabel,
          ),
  );

  /// Efface le trace (§15.3 : effacement possible, validation explicite).
  void clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _startedAt = null;
    });
    widget.onChanged(null);
  }

  bool get isEmpty => _strokes.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mention d'engagement, au-dessus de la zone (EXI-CC18).
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: AppRadii.component,
              topRight: AppRadii.component,
            ),
          ),
          child: Text(
            l10n.custodyEngagement,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: const BorderRadius.only(
              bottomLeft: AppRadii.component,
              bottomRight: AppRadii.component,
            ),
          ),
          child: Listener(
            onPointerDown: (event) =>
                _begin(event.localPosition, event.pressure),
            onPointerMove: (event) =>
                _extend(event.localPosition, event.pressure),
            child: CustomPaint(
              painter: _SignaturePainter(_strokes, theme.colorScheme.onSurface),
              child: _strokes.isEmpty
                  ? Center(
                      child: Text(
                        l10n.custodySignHere,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.signerLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _strokes.isEmpty ? null : clear,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: Text(l10n.custodyClearSignature),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes, this.color);

  final List<List<SignaturePoint>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      for (var i = 1; i < stroke.length; i++) {
        final from = stroke[i - 1];
        final to = stroke[i];
        // L'epaisseur suit la pression : le rendu reflete le vecteur, il ne
        // l'invente pas.
        final paint = Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5 + to.pressure * 2.5;
        canvas.drawLine(Offset(from.x, from.y), Offset(to.x, to.y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
