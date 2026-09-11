import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Le chronometre de MajiChrono, dessine au trait.
///
/// C'est le second symbole de la marque, a cote du scooter : le nom dit
/// *Chrono*, l'icone le montre. Elle sert ici en filigrane derriere le titre et
/// en petit repere sous la marque centrale — jamais comme sujet, toujours comme
/// signe. D'ou le reglage d'[opacity] : la meme forme se pose a huit pour cent
/// derriere un texte, ou a pleine encre en vignette.
///
/// Le trace est vectoriel : aucun fichier a charger, et il reste net a toutes
/// les tailles, du filigrane de cent quatre-vingts pixels au repere de quarante.
class McStopwatchIcon extends StatelessWidget {
  const McStopwatchIcon({
    this.size = 96,
    this.opacity = 1,
    this.color = Colors.white,
    super.key,
  });

  final double size;

  /// De 0 (invisible) a 1 (pleine encre). Le filigrane vit vers 0.08.
  final double opacity;

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _StopwatchPainter(color: color.withValues(alpha: opacity)),
    ),
  );
}

class _StopwatchPainter extends CustomPainter {
  const _StopwatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final stroke = unit * 0.055;
    final center = Offset(unit / 2, unit * 0.56);
    final radius = unit * 0.34;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Le boitier.
    canvas.drawCircle(center, radius, line);

    // Le poussoir et la couronne, en haut.
    final top = Offset(center.dx, center.dy - radius);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - unit * 0.11),
      top,
      line,
    );
    canvas.drawLine(
      Offset(center.dx - unit * 0.09, center.dy - radius - unit * 0.11),
      Offset(center.dx + unit * 0.09, center.dy - radius - unit * 0.11),
      line,
    );

    // Les deux aiguilles, arretees sur une pose vive plutot que sur midi : un
    // chronometre a l'arret sur midi a l'air neuf ; celui-ci a l'air d'avoir
    // compte.
    canvas.drawLine(center, Offset(center.dx, center.dy - radius * 0.62), line);
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.5, center.dy - radius * 0.28),
      line,
    );

    // Quatre reperes cardinaux, discrets.
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.7
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 4; i++) {
      final rad = i * math.pi / 2;
      final dir = Offset(math.cos(rad), math.sin(rad));
      canvas.drawLine(
        center + dir * (radius * 0.66),
        center + dir * (radius * 0.82),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_StopwatchPainter oldDelegate) =>
      oldDelegate.color != color;
}
