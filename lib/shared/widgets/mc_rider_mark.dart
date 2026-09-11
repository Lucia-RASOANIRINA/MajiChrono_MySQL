import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';

/// Illustration de marque MajiChrono : un livreur sur son scooter, caisson a
/// l'arriere, file de vitesse derriere lui.
///
/// Dessinee au trait plein, en blanc et bleu clair, sur fond **transparent** :
/// posee sur le bleu de la charte (splash, en-tete), c'est le bleu du fond qui
/// transparait, donc aucun raccord de couleur. Vectorielle, elle reste nette a
/// toutes les tailles et ne pese que du code.
///
/// La composition tient dans un disque central (marge de securite) pour que le
/// masque circulaire de l'ecran de demarrage d'Android 12+ ne coupe pas le
/// livreur ; seule la file de vitesse, decorative, effleure les bords.
class McRiderMark extends StatelessWidget {
  const McRiderMark({this.size = 128, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: RiderMarkPainter()),
  );
}

/// Peintre de l'illustration. Coordonnees exprimees sur une grille de 100,
/// mises a l'echelle du cote le plus court.
class RiderMarkPainter extends CustomPainter {
  const RiderMarkPainter();

  static const _white = Colors.white;
  static const _blue = AppColors.primaryLight; // 0xFF2F6BE4
  static const _navy = Color(0xFF0E1440);
  static const _accent = AppColors.accent; // ambre

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);
    double u(double v) => v * s;

    Paint fill(Color c) => Paint()
      ..style = PaintingStyle.fill
      ..color = c
      ..isAntiAlias = true;
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u(w)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c
      ..isAntiAlias = true;

    // Marge de securite : le dessin occupe 86 % du canevas, centre, pour que le
    // masque circulaire de l'ecran de demarrage d'Android 12+ ne rogne pas le
    // livreur ni les roues.
    const inset = 0.86;
    canvas.save();
    canvas.translate(
      size.width * (1 - inset) / 2,
      size.height * (1 - inset) / 2,
    );
    canvas.scale(inset);

    // --- File de vitesse, derriere le livreur -----------------------------
    for (var i = 0; i < 3; i++) {
      final y = 30.0 + i * 9;
      final len = 24.0 - i * 4;
      canvas.drawLine(p(6, y), p(6 + len, y), stroke(_white, 2.6));
    }

    // --- Scooter ----------------------------------------------------------
    const rearC = Offset(34, 74);
    const frontC = Offset(74, 74);
    const wheelR = 12.0;

    // Chassis : plancher bas reliant les deux roues, releve a l'avant.
    final chassis = Path()
      ..moveTo(u(rearC.dx), u(rearC.dy - 2))
      ..lineTo(u(46), u(70))
      ..lineTo(u(58), u(70))
      ..lineTo(u(66), u(58)) // montee vers la colonne de direction
      ..lineTo(u(70), u(58))
      ..lineTo(u(74), u(72))
      ..lineTo(u(rearC.dx + 2), u(72))
      ..close();
    canvas.drawPath(chassis, fill(_white));

    // Tablier avant + colonne de direction.
    canvas.drawPath(
      Path()
        ..moveTo(u(64), u(70))
        ..lineTo(u(70), u(40))
        ..lineTo(u(74), u(40))
        ..lineTo(u(72), u(70))
        ..close(),
      fill(_white),
    );
    // Guidon.
    canvas.drawLine(p(66, 41), p(78, 39), stroke(_white, 3.4));
    // Phare.
    canvas.drawCircle(p(76, 45), u(2.6), fill(_accent));

    // Roues : pneu blanc epais, moyeu bleu.
    for (final c in [rearC, frontC]) {
      canvas.drawCircle(p(c.dx, c.dy), u(wheelR), stroke(_white, 5));
      canvas.drawCircle(p(c.dx, c.dy), u(4.5), fill(_blue));
      canvas.drawCircle(p(c.dx, c.dy), u(1.6), fill(_white));
    }

    // --- Caisson de livraison, sur le porte-bagages arriere ---------------
    final boxRect = Rect.fromLTWH(u(16), u(30), u(24), u(24));
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, Radius.circular(u(3))),
      fill(_white),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, Radius.circular(u(3))),
      stroke(_blue, 2),
    );
    // Baobab stylise sur le caisson : tronc epais, couronne aplatie et deux
    // branches — la silhouette qui dit Madagascar en trois traits.
    canvas.drawLine(p(28, 50), p(28, 41), stroke(_blue, 3));
    canvas.drawOval(
      Rect.fromCenter(center: p(28, 40), width: u(13), height: u(6)),
      fill(_blue),
    );
    canvas.drawLine(p(28, 44), p(24, 41), stroke(_blue, 2));
    canvas.drawLine(p(28, 44), p(32, 41), stroke(_blue, 2));

    // --- Livreur ----------------------------------------------------------
    // Jambe pliee : cuisse puis tibia, le pied pose sur le plancher.
    canvas.drawLine(p(49, 55), p(53, 63), stroke(_blue, 6.5));
    canvas.drawLine(p(53, 63), p(58, 66), stroke(_blue, 6.5));
    // Tronc penche vers le guidon.
    canvas.drawLine(p(50, 56), p(60, 40), stroke(_blue, 9));
    // Bras vers le guidon.
    canvas.drawLine(p(59, 43), p(71, 41), stroke(_blue, 5));
    // Casque : calotte + visiere.
    canvas.drawCircle(p(63, 33), u(8), fill(_blue));
    canvas.drawPath(
      Path()
        ..moveTo(u(63), u(29))
        ..lineTo(u(72), u(31))
        ..lineTo(u(71), u(35))
        ..lineTo(u(63), u(35))
        ..close(),
      fill(_white),
    );
    // Petite visiere avant.
    canvas.drawLine(p(70, 31), p(74, 31), stroke(_navy, 2.4));

    canvas.restore();
  }

  @override
  bool shouldRepaint(RiderMarkPainter oldDelegate) => false;
}
