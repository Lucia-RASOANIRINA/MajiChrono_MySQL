import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// Generation des visuels de marque.
///
/// Les icones sont **dessinees par programme** plutot que deposees en binaire :
/// un PNG dans un depot est un fichier que personne ne sait plus reproduire six
/// mois plus tard, et dont on ne peut ni corriger une teinte ni changer une
/// proportion sans rouvrir un editeur.
///
/// Ici, la charte est du code : les couleurs viennent des memes valeurs que le
/// theme, et regenerer se fait par `dart run tool/generate_brand_assets.dart`.
///
/// Le motif est volontairement geometrique — un colis et son sillage de
/// vitesse. Il reste lisible a 48 px dans une liste d'applications, ce qu'un
/// dessin detaille ne fait pas.
void main() {
  Directory('assets/icon').createSync(recursive: true);

  _write('assets/icon/app_icon.png', _icon(1024, withBackground: true));
  // Icone adaptative Android : le premier plan est recadre par le lanceur, donc
  // le motif tient dans les 66 % centraux.
  _write('assets/icon/app_icon_foreground.png', _icon(1024, safeArea: true));
  _write('assets/icon/app_icon_monochrome.png', _icon(1024, monochrome: true));

  stdout.writeln('Icones generees dans assets/icon/');
}

/// Bleu profond de la marque, identique a `AppColors.primary`.
const int _brand = 0xFF1E2A78;
const int _accent = 0xFF2F6BE4;

void _write(String path, Image image) =>
    File(path).writeAsBytesSync(encodePng(image));

Image _icon(
  int size, {
  bool withBackground = false,
  bool safeArea = false,
  bool monochrome = false,
}) {
  final image = Image(width: size, height: size, numChannels: 4);
  fill(image, color: ColorRgba8(0, 0, 0, 0));

  if (withBackground) {
    fillCircle(
      image,
      x: size ~/ 2,
      y: size ~/ 2,
      radius: size ~/ 2,
      color: _rgb(_brand),
    );
  }

  // Le motif occupe 62 % de la toile quand il doit survivre au recadrage du
  // lanceur adaptatif, 78 % sinon.
  final scale = safeArea ? 0.62 : 0.78;
  final unit = size * scale;
  final left = (size - unit) / 2;
  final top = (size - unit) / 2;

  final mark = monochrome ? _rgb(0xFFFFFFFF) : _rgb(0xFFFFFFFF);
  final trail = monochrome ? _rgb(0xFFFFFFFF) : _rgb(_accent);

  // --- Le scooter porteur ----------------------------------------------
  //
  // Le logo et l'indicateur de chargement dessinent desormais **la meme
  // marque** : un scooter qui porte un colis. Avoir deux symboles — un colis
  // pour le lanceur, un scooter pour les attentes — obligeait a apprendre deux
  // fois la meme chose, et aucun des deux ne devenait familier.
  final stroke = math.max(2, unit * 0.055).round();

  // Les deux roues, posees sur une meme ligne.
  final wheelRadius = unit * 0.15;
  final wheelY = top + unit * 0.70;
  final rearX = left + unit * 0.26;
  final frontX = left + unit * 0.76;

  for (final wheelX in [rearX, frontX]) {
    // `drawCircle` ne trace qu'un cercle d'un pixel : l'epaisseur s'obtient en
    // empilant des cercles concentriques. C'est brut, mais l'image est generee
    // une fois pour toutes, hors execution.
    for (var r = wheelRadius.round() - stroke; r <= wheelRadius.round(); r++) {
      drawCircle(
        image,
        x: wheelX.round(),
        y: wheelY.round(),
        radius: r,
        color: mark,
      );
    }
  }

  // Le chassis, de la roue arriere au guidon.
  _roundedBar(
    image,
    x: rearX.round(),
    y: (wheelY - stroke / 2).round(),
    w: (frontX - rearX).round(),
    h: stroke,
    color: mark,
  );
  _roundedBar(
    image,
    x: (frontX - stroke / 2).round(),
    y: (top + unit * 0.42).round(),
    w: stroke,
    h: (wheelY - top - unit * 0.42).round(),
    color: mark,
  );
  // Le guidon.
  _roundedBar(
    image,
    x: (frontX - unit * 0.13).round(),
    y: (top + unit * 0.42 - stroke / 2).round(),
    w: (unit * 0.20).round(),
    h: stroke,
    color: mark,
  );

  // Le colis, sur le porte-bagages arriere : c'est lui qui fait lire
  // « livraison » et non « deux-roues ».
  final boxSide = unit * 0.26;
  final boxLeft = rearX - boxSide * 0.35;
  final boxTop = wheelY - wheelRadius - boxSide - unit * 0.05;

  _roundedBox(
    image,
    x: boxLeft.round(),
    y: boxTop.round(),
    w: boxSide.round(),
    h: boxSide.round(),
    thickness: stroke,
    color: mark,
  );
  // La bande de scellement du colis.
  fillRect(
    image,
    x1: (boxLeft + boxSide * 0.40).round(),
    y1: boxTop.round(),
    x2: (boxLeft + boxSide * 0.60).round(),
    y2: (boxTop + boxSide).round(),
    color: mark,
  );

  // --- Le sillage de vitesse -------------------------------------------
  for (var i = 0; i < 3; i++) {
    final lineY = top + unit * (0.36 + i * 0.14);
    final lineLength = unit * (0.24 - i * 0.05);
    final lineLeft = left + unit * 0.02;

    _roundedBar(
      image,
      x: lineLeft.round(),
      y: (lineY - stroke / 2).round(),
      w: lineLength.round(),
      h: stroke,
      color: trail,
    );
  }

  return image;
}

ColorRgba8 _rgb(int argb) => ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);

/// Contour de rectangle d'epaisseur donnee.
void _roundedBox(
  Image image, {
  required int x,
  required int y,
  required int w,
  required int h,
  required int thickness,
  required Color color,
}) {
  fillRect(image, x1: x, y1: y, x2: x + w, y2: y + thickness, color: color);
  fillRect(
    image,
    x1: x,
    y1: y + h - thickness,
    x2: x + w,
    y2: y + h,
    color: color,
  );
  fillRect(image, x1: x, y1: y, x2: x + thickness, y2: y + h, color: color);
  fillRect(
    image,
    x1: x + w - thickness,
    y1: y,
    x2: x + w,
    y2: y + h,
    color: color,
  );
}

void _roundedBar(
  Image image, {
  required int x,
  required int y,
  required int w,
  required int h,
  required Color color,
}) {
  if (w <= 0 || h <= 0) return;
  fillRect(image, x1: x, y1: y, x2: x + w, y2: y + h, color: color);
  fillCircle(image, x: x, y: y + h ~/ 2, radius: h ~/ 2, color: color);
  fillCircle(image, x: x + w, y: y + h ~/ 2, radius: h ~/ 2, color: color);
}
