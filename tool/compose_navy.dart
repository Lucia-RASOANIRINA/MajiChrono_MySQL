// Apercu : compose une image transparente sur le bleu de la charte, comme au
// lancement.  dart run tool/compose_navy.dart <in.png> <out.png>
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final inPath = args[0];
  final outPath = args[1];
  final fg = img.decodePng(File(inPath).readAsBytesSync())!;
  final bg = img.Image(width: fg.width, height: fg.height, numChannels: 4);
  img.fill(bg, color: img.ColorRgb8(0x1E, 0x2A, 0x78));
  img.compositeImage(bg, fg);
  File(outPath).writeAsBytesSync(img.encodePng(bg));
  stdout.writeln('OK: $outPath');
}
