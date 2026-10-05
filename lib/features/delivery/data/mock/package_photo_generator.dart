import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Photos de colis fabriquees pour le mode simule.
///
/// Les courses de demonstration n'ont pas de vraie photo : sans elles, la
/// file du livreur ne montrerait que des illustrations de repli et l'on ne
/// pourrait pas juger l'affichage reel. Le generateur dessine une scene simple
/// — un sol, une ombre, puis un carton, une enveloppe, un sac ou un panier
/// selon la nature du colis — avec des teintes variees. Ce n'est utilise
/// qu'en simulation ; en production, la photo est prise par l'expediteur.
class PackagePhotoGenerator {
  PackagePhotoGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int width = 640;
  static const int height = 400;

  /// Rend une photo JPEG du colis.
  Uint8List render(DeliveryKind kind) {
    final image = img.Image(width: width, height: height);
    _background(image);
    switch (kind) {
      case DeliveryKind.document:
        _envelope(image);
      case DeliveryKind.food:
        _bag(image);
      case DeliveryKind.shopping:
        _basket(image);
      case DeliveryKind.standard:
      case DeliveryKind.fragile:
        _box(image, fragile: kind == DeliveryKind.fragile);
    }
    return img.encodeJpg(image, quality: 82);
  }

  // --- Scene --------------------------------------------------------------

  void _background(img.Image image) {
    // Mur clair en haut, sol (table, carrelage) en bas, tons chauds varies.
    final wall = _pick(const [
      (236, 230, 220),
      (224, 232, 238),
      (240, 234, 226),
      (230, 226, 236),
    ]);
    final floor = _pick(const [
      (176, 132, 92),
      (150, 150, 150),
      (196, 168, 130),
      (120, 98, 80),
    ]);
    for (var y = 0; y < height; y++) {
      final onFloor = y > height * 0.62;
      final base = onFloor ? floor : wall;
      final shade = onFloor ? 1 - (y - height * 0.62) / height * 0.6 : 1.0;
      final c = img.ColorRgb8(
        (base.$1 * shade).round().clamp(0, 255),
        (base.$2 * shade).round().clamp(0, 255),
        (base.$3 * shade).round().clamp(0, 255),
      );
      img.drawLine(image, x1: 0, y1: y, x2: width - 1, y2: y, color: c);
    }
    // Ombre portee au sol.
    img.fillCircle(
      image,
      x: width ~/ 2,
      y: (height * 0.86).round(),
      radius: 150,
      color: img.ColorRgba8(0, 0, 0, 40),
    );
  }

  void _box(img.Image image, {required bool fragile}) {
    final kraft = _pick(const [
      (196, 150, 98),
      (184, 140, 90),
      (210, 168, 112),
      (232, 228, 220),
    ]);
    final front = img.ColorRgb8(kraft.$1, kraft.$2, kraft.$3);
    final side = _darker(kraft, 0.78);
    final top = _darker(kraft, 1.12);

    const left = 190, right = 420, topY = 150, bottom = 330, depth = 60;
    // Face avant.
    img.fillRect(
      image,
      x1: left,
      y1: topY,
      x2: right,
      y2: bottom,
      color: front,
    );
    // Dessus (parallelogramme).
    img.fillPolygon(
      image,
      vertices: [
        img.Point(left, topY),
        img.Point(left + depth, topY - 50),
        img.Point(right + depth, topY - 50),
        img.Point(right, topY),
      ],
      color: top,
    );
    // Cote droit.
    img.fillPolygon(
      image,
      vertices: [
        img.Point(right, topY),
        img.Point(right + depth, topY - 50),
        img.Point(right + depth, bottom - 50),
        img.Point(right, bottom),
      ],
      color: side,
    );
    // Ruban adhesif sur le dessus et la face.
    final tape = img.ColorRgba8(150, 110, 70, 170);
    img.fillPolygon(
      image,
      vertices: [
        img.Point(left + 100, topY),
        img.Point(left + 100 + depth, topY - 50),
        img.Point(left + 130 + depth, topY - 50),
        img.Point(left + 130, topY),
      ],
      color: tape,
    );
    img.fillRect(
      image,
      x1: left + 100,
      y1: topY,
      x2: left + 130,
      y2: topY + 60,
      color: tape,
    );
    // Etiquette d'expedition.
    img.fillRect(
      image,
      x1: left + 24,
      y1: topY + 90,
      x2: left + 120,
      y2: topY + 150,
      color: img.ColorRgb8(250, 250, 248),
    );
    for (var i = 0; i < 4; i++) {
      img.drawLine(
        image,
        x1: left + 32,
        y1: topY + 102 + i * 12,
        x2: left + 100 - i * 8,
        y2: topY + 102 + i * 12,
        color: img.ColorRgb8(90, 90, 100),
        thickness: 3,
      );
    }
    if (fragile) {
      // Etiquette « fragile » rouge avec un verre stylise.
      img.fillRect(
        image,
        x1: right - 110,
        y1: topY + 30,
        x2: right - 20,
        y2: topY + 100,
        color: img.ColorRgb8(210, 40, 40),
      );
      img.fillPolygon(
        image,
        vertices: [
          img.Point(right - 85, topY + 42),
          img.Point(right - 45, topY + 42),
          img.Point(right - 58, topY + 70),
          img.Point(right - 72, topY + 70),
        ],
        color: img.ColorRgb8(255, 255, 255),
      );
      img.drawLine(
        image,
        x1: right - 65,
        y1: topY + 70,
        x2: right - 65,
        y2: topY + 88,
        color: img.ColorRgb8(255, 255, 255),
        thickness: 4,
      );
    }
  }

  void _envelope(img.Image image) {
    final paper = _pick(const [
      (242, 236, 222),
      (226, 206, 160),
      (250, 250, 250),
    ]);
    const left = 160, right = 480, top = 170, bottom = 330;
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: bottom,
      color: img.ColorRgb8(paper.$1, paper.$2, paper.$3),
    );
    final fold = _darker(paper, 0.86);
    img.fillPolygon(
      image,
      vertices: [
        img.Point(left, top),
        img.Point((left + right) ~/ 2, top + 90),
        img.Point(right, top),
      ],
      color: fold,
    );
    // Timbre.
    img.fillRect(
      image,
      x1: right - 60,
      y1: top + 110,
      x2: right - 20,
      y2: top + 150,
      color: img.ColorRgb8(30, 42, 120),
    );
  }

  void _bag(img.Image image) {
    final paper = _pick(const [
      (200, 160, 110),
      (236, 236, 230),
      (60, 140, 80),
    ]);
    const left = 220, right = 420, top = 140, bottom = 340;
    img.fillPolygon(
      image,
      vertices: [
        img.Point(left + 10, top),
        img.Point(right - 10, top),
        img.Point(right, bottom),
        img.Point(left, bottom),
      ],
      color: img.ColorRgb8(paper.$1, paper.$2, paper.$3),
    );
    // Poignees.
    final handle = _darker(paper, 0.7);
    img.drawCircle(
      image,
      x: (left + right) ~/ 2,
      y: top,
      radius: 45,
      color: handle,
    );
    // Logo rond.
    img.fillCircle(
      image,
      x: (left + right) ~/ 2,
      y: (top + bottom) ~/ 2 + 20,
      radius: 34,
      color: img.ColorRgb8(244, 166, 42),
    );
  }

  void _basket(img.Image image) {
    const left = 190, right = 450, top = 200, bottom = 340;
    // Produits qui depassent : fruits et legumes colores.
    for (final (x, color) in [
      (240, img.ColorRgb8(230, 80, 40)),
      (300, img.ColorRgb8(250, 200, 40)),
      (360, img.ColorRgb8(90, 170, 60)),
      (410, img.ColorRgb8(200, 40, 60)),
    ]) {
      img.fillCircle(image, x: x, y: top - 10, radius: 34, color: color);
    }
    final weave = img.ColorRgb8(170, 120, 60);
    img.fillPolygon(
      image,
      vertices: [
        img.Point(left, top),
        img.Point(right, top),
        img.Point(right - 25, bottom),
        img.Point(left + 25, bottom),
      ],
      color: weave,
    );
    for (var y = top + 15; y < bottom; y += 22) {
      img.drawLine(
        image,
        x1: left + 10,
        y1: y,
        x2: right - 10,
        y2: y,
        color: img.ColorRgb8(130, 88, 40),
        thickness: 4,
      );
    }
  }

  // --- Aides --------------------------------------------------------------

  (int, int, int) _pick(List<(int, int, int)> options) =>
      options[_random.nextInt(options.length)];

  img.ColorRgb8 _darker((int, int, int) c, double f) => img.ColorRgb8(
    (c.$1 * f).round().clamp(0, 255),
    (c.$2 * f).round().clamp(0, 255),
    (c.$3 * f).round().clamp(0, 255),
  );
}
