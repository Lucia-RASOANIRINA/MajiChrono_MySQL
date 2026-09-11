// Outil de capture : rend la zone de signature (SignaturePad) avec une
// signature simulee, et l'exporte en PNG. Range dans tool/ pour ne pas tourner
// dans la suite de tests. Invocation :
//
//   flutter test tool/capture_signature.dart
//
// La zone de signature est celle que voit le livreur au moment de la remise :
// le destinataire y signe, sous la mention d'engagement, sur le telephone du
// livreur (EXI-CC16, EXI-CC18, EXI-CC24).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/app/theme/app_theme.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/widgets/signature_pad.dart';
import 'package:majichrono/l10n/app_localizations.dart';

void _noop(VectorSignature? _) {}

/// Charge Roboto depuis le cache du SDK : sans cela, `flutter test` rend le
/// texte en paves (police de substitution), et la capture serait illisible.
Future<void> _loadRoboto() async {
  const dir =
      r'C:\src\flutter\bin\cache\artifacts\material_fonts';
  final loader = FontLoader('Roboto');
  for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final file = File('$dir\\$name');
    if (file.existsSync()) {
      loader.addFont(
        Future.value(file.readAsBytesSync().buffer.asByteData()),
      );
    }
  }
  await loader.load();
}

Future<void> main() async {
  testWidgets('capture de la zone de signature', (tester) async {
    await _loadRoboto();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('mg')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light().copyWith(
          textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF1F5F9),
            title: const Text(
              'Preuve de remise',
              style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
            ),
          ),
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 420,
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text(
                      'Le destinataire signe sur le telephone du livreur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 16),
                    SignaturePad(
                      signerLabel: 'Signature du destinataire',
                      onChanged: _noop,
                      height: 220,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Simuler une signature manuscrite : une suite de traits dans la zone.
    // On vise le Listener de dessin (celui qui porte onPointerMove), pas les
    // ecouteurs de defilement du framework.
    final pad = find.byWidgetPredicate(
      (w) => w is Listener && w.onPointerMove != null,
    );
    final rect = tester.getRect(pad);
    final base = Offset(rect.left + rect.width * 0.22, rect.center.dy + 10);

    final gesture = await tester.startGesture(base);
    const moves = <Offset>[
      Offset(18, -40),
      Offset(20, 46),
      Offset(22, -50),
      Offset(24, 40),
      Offset(26, -30),
      Offset(20, 34),
      Offset(30, -12),
      Offset(34, 20),
      Offset(40, -24),
    ];
    for (final move in moves) {
      await gesture.moveBy(move);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = r'D:\gtmp\claude\D--MajiChrono\0fe45000-41da-4758-932e-b133449d15c5\scratchpad\signature.png';
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('SIGNATURE CAPTURE -> $path');
    });
  });
}
