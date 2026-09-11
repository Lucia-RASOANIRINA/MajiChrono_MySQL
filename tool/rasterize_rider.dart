// Generateur d'asset : rasterise `RiderMarkPainter` en PNG a fond transparent.
//
// Ce n'est pas un test de comportement mais un outil, range hors de `test/`
// pour ne pas s'executer dans la suite. On l'invoque a la demande :
//
//   flutter test tool/rasterize_rider.dart
//
// Il ecrit l'illustration a plusieurs tailles : un apercu, l'asset de marque,
// et le drawable de l'ecran de demarrage Android.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majichrono/shared/widgets/mc_rider_mark.dart';

Future<void> _render(WidgetTester tester, int px, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: px.toDouble(),
            height: px.toDouble(),
            child: McRiderMark(size: px.toDouble()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _renderPreview(WidgetTester tester, int px, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: px.toDouble(),
            height: px.toDouble(),
            color: const Color(0xFF1E2A78),
            child: McRiderMark(size: px.toDouble()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('rasterize rider mark', (tester) async {
    // Apercu (transparent + composite bleu, pour controle visuel).
    await _render(tester, 1024, r'D:\gtmp\rider_preview.png');
    await _renderPreview(tester, 1024, r'D:\gtmp\rider_preview_blue.png');

    // Asset de marque, reutilisable dans l'app.
    await _render(tester, 1024, r'D:\MajiChrono\assets\brand\rider_mark.png');

    // Drawable de l'ecran de demarrage Android (transparent : le bleu du
    // theme de lancement transparait dessous).
    await _render(
      tester,
      768,
      r'D:\MajiChrono\android\app\src\main\res\drawable\splash_logo.png',
    );
  });
}
