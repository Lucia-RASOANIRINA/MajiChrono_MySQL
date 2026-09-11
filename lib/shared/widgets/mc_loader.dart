import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:majichrono/l10n/app_localizations.dart';

/// Indicateur de chargement de MajiChrono.
///
/// Un livreur sur son scooter qui avance, plutot qu'un cercle qui tourne. Le
/// cercle est universel mais muet : il dit « attendez » sans dire ce qu'on
/// attend. Ici l'attente ressemble a ce que fait l'application — quelque chose
/// est en route.
///
/// L'animation est **dessinee**, pas importee : un GIF ou un Lottie pesent
/// quelques centaines de kilo-octets pour un mouvement de trois formes, et
/// chaque kilo-octet compte dans un APK deja au-dessus de son budget (EXI-P03).
///
/// Le mouvement respecte `MediaQuery.disableAnimations` : un utilisateur qui a
/// desactive les animations systeme, souvent pour des raisons vestibulaires ou
/// de batterie, ne doit pas les retrouver ici (EXI-T09).
class McLoader extends StatefulWidget {
  const McLoader({this.size = 56, this.color, this.semanticLabel, super.key});

  /// Version compacte, pour un bouton ou une ligne de liste.
  const McLoader.small({this.color, this.semanticLabel, super.key}) : size = 24;

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  State<McLoader> createState() => _McLoaderState();
}

class _McLoaderState extends State<McLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.color ?? Theme.of(context).colorScheme.primary;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      // Le lecteur d'ecran doit annoncer une attente, pas decrire un dessin.
      label: widget.semanticLabel ?? AppLocalizations.of(context).commonLoading,
      liveRegion: true,
      child: SizedBox(
        width: widget.size * 1.6,
        height: widget.size,
        child: reduced
            // Sans animation, on garde un repere fixe plutot qu'un ecran vide :
            // l'utilisateur doit toujours voir que quelque chose est en cours.
            ? CustomPaint(
                painter: _ScooterPainter(
                  progress: 0.5,
                  tone: tone,
                  still: true,
                ),
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => CustomPaint(
                  painter: _ScooterPainter(
                    progress: _controller.value,
                    tone: tone,
                    still: false,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Trace le scooter, ses roues et son sillage.
class _ScooterPainter extends CustomPainter {
  const _ScooterPainter({
    required this.progress,
    required this.tone,
    required this.still,
  });

  final double progress;
  final Color tone;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height;
    final stroke = math.max(1.6, unit * 0.085);

    final body = Paint()
      ..color = tone
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Le scooter avance de gauche a droite puis revient : un defilement en
    // boucle donnerait un saut visible a chaque cycle.
    final sway = still ? 0.0 : math.sin(progress * 2 * math.pi) * unit * 0.06;
    final bounce = still
        ? 0.0
        : math.sin(progress * 4 * math.pi) * unit * 0.025;

    canvas.translate(size.width * 0.30 + sway, unit * 0.5 + bounce);

    final wheelRadius = unit * 0.17;
    final rearWheel = Offset(-unit * 0.34, unit * 0.28);
    final frontWheel = Offset(unit * 0.40, unit * 0.28);

    // --- Sillage ---------------------------------------------------------
    // Trois traits qui defilent : c'est le mouvement, pas le vehicule, qui
    // rend l'attente lisible.
    final trail = Paint()
      ..color = tone.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.7
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final phase = still ? 0.5 : (progress + i * 0.33) % 1.0;
      final x = -unit * (0.55 + phase * 0.5);
      final length = unit * 0.26 * (1 - phase * 0.5);
      final y = unit * (-0.12 + i * 0.22);
      canvas.drawLine(Offset(x, y), Offset(x - length, y), trail);
    }

    // --- Roues -----------------------------------------------------------
    canvas.drawCircle(rearWheel, wheelRadius, body);
    canvas.drawCircle(frontWheel, wheelRadius, body);

    // --- Chassis ---------------------------------------------------------
    final chassis = Path()
      ..moveTo(rearWheel.dx, rearWheel.dy)
      ..lineTo(-unit * 0.10, unit * 0.06)
      ..lineTo(unit * 0.18, unit * 0.06)
      ..lineTo(frontWheel.dx, frontWheel.dy);
    canvas.drawPath(chassis, body);

    // Colonne de direction et guidon.
    canvas.drawLine(
      Offset(unit * 0.18, unit * 0.06),
      Offset(unit * 0.34, -unit * 0.24),
      body,
    );
    canvas.drawLine(
      Offset(unit * 0.26, -unit * 0.24),
      Offset(unit * 0.42, -unit * 0.24),
      body,
    );

    // --- Le livreur ------------------------------------------------------
    // Tete, buste, bras : trois traits suffisent a faire lire une personne.
    final head = Offset(-unit * 0.02, -unit * 0.34);
    canvas.drawCircle(head, unit * 0.10, body);
    canvas.drawLine(
      Offset(head.dx, head.dy + unit * 0.11),
      Offset(-unit * 0.06, unit * 0.02),
      body,
    );
    canvas.drawLine(
      Offset(head.dx + unit * 0.02, head.dy + unit * 0.16),
      Offset(unit * 0.30, -unit * 0.20),
      body,
    );

    // --- Le colis --------------------------------------------------------
    // Il est la raison du trajet : sans lui, c'est un scooter, pas une
    // livraison.
    final boxSize = unit * 0.20;
    final box = Rect.fromLTWH(
      -unit * 0.40,
      -unit * 0.22,
      boxSize,
      boxSize * 0.85,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(unit * 0.03)),
      body,
    );
  }

  @override
  bool shouldRepaint(_ScooterPainter old) =>
      old.progress != progress || old.tone != tone || old.still != still;
}
