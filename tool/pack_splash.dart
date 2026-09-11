// Prepare l'illustration detouree pour l'ecran de demarrage.
//
// Recadre les marges transparentes, puis pose le sujet centre dans un canevas
// carre avec une marge de securite (le sujet occupe ~76 % du cote), afin que le
// masque circulaire d'Android 12+ ne rogne ni les roues ni le caisson. Le fond
// reste transparent : le bleu du theme de lancement transparait dessous.
//
//   dart run tool/pack_splash.dart <cutout.png> <sortie.png> [taille]
//
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final inPath = args.isNotEmpty ? args[0] : r'D:\gtmp\cut_36.png';
  final outPath = args.length > 1
      ? args[1]
      : r'D:\MajiChrono\android\app\src\main\res\drawable\splash_logo.png';
  final size = args.length > 2 ? int.parse(args[2]) : 768;

  final src = img.decodePng(File(inPath).readAsBytesSync())!;
  final trimmed = img.trim(src, mode: img.TrimMode.transparent);

  // Facteur d'echelle : le plus grand cote du sujet occupe 76 % du canevas.
  final safe = size * 0.76;
  final scale = safe / (trimmed.width > trimmed.height
      ? trimmed.width
      : trimmed.height);
  final rw = (trimmed.width * scale).round();
  final rh = (trimmed.height * scale).round();
  final resized = img.copyResize(
    trimmed,
    width: rw,
    height: rh,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.compositeImage(
    canvas,
    resized,
    dstX: (size - rw) ~/ 2,
    dstY: (size - rh) ~/ 2,
  );

  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('OK: $outPath (${size}x$size, sujet ${rw}x$rh)');
}
