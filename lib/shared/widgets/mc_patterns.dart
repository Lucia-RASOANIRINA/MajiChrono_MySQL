import 'package:flutter/material.dart';

/// Motifs de fond dessines au trait, en filigrane.
///
/// Ils occupent les grands aplats de bleu sans les charger : un fond
/// parfaitement uni parait plat sur un ecran bas de gamme, un fond image coute
/// des octets qu'on n'a pas (budget d'APK, §10.1). Un trace vectoriel tres peu
/// contraste donne de la matiere pour presque rien.

/// Trame technique : une grille de circuits, evoquant la mesure et le reseau.
///
/// Elle habille le fond de l'ecran de choix. Le motif est volontairement
/// regulier et calme — il ne doit jamais concurrencer le contenu, seulement
/// eviter le vide.
class TechPatternPainter extends CustomPainter {
  const TechPatternPainter({required this.color, this.spacing = 44});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final node = Paint()..color = color;

    // Grille de points, avec de courts segments qui relient un point sur trois :
    // assez pour lire « circuit », trop rare pour distraire.
    var row = 0;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      var col = 0;
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.4, node);

        // Une liaison horizontale ou verticale, en alternance, une case sur
        // deux : le trace garde un air ordonne sans devenir une vraie grille.
        if ((row + col).isEven && x + spacing < size.width) {
          canvas.drawLine(Offset(x + 4, y), Offset(x + spacing - 4, y), line);
        }
        if ((row + col).isOdd && y + spacing < size.height) {
          canvas.drawLine(Offset(x, y + 4), Offset(x, y + spacing - 4), line);
        }
        col++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(TechPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

/// Trame d'enveloppes : le rabat d'un pli, repete en diagonale.
///
/// Elle habille la carte « e-mail » de l'ecran de choix, et redit sans un mot
/// ce que la carte propose. Tres pale, elle reste un fond ; le rabat en V suffit
/// a evoquer le courrier.
class EnvelopePatternPainter extends CustomPainter {
  const EnvelopePatternPainter({required this.color, this.tile = 40});

  final Color color;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    for (var y = tile * 0.2; y < size.height + tile; y += tile) {
      for (var x = -tile; x < size.width; x += tile * 1.4) {
        final w = tile * 0.72;
        final h = tile * 0.5;
        final rect = Rect.fromLTWH(x, y, w, h);

        // Le contour du pli.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          line,
        );
        // Le rabat : deux traits qui descendent des coins hauts vers le centre.
        canvas.drawLine(
          rect.topLeft,
          Offset(rect.center.dx, rect.center.dy),
          line,
        );
        canvas.drawLine(
          rect.topRight,
          Offset(rect.center.dx, rect.center.dy),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(EnvelopePatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tile != tile;
}
