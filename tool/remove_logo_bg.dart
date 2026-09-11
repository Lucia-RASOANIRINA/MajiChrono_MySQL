// Detourage du fond de l'illustration MajiChrono.
//
// Le fond est un aplat bleu uni qui touche les quatre bords ; le sujet
// (livreur + scooter) est centre et n'atteint aucun bord. On rend donc le fond
// transparent par **remplissage depuis les bords** (flood fill 4-connexe) :
// seuls les pixels bleus *relies au bord* deviennent transparents. Les bleus
// interieurs du sujet (casque, carrosserie) sont preserves, puisqu'ils sont
// enfermes par des contours plus sombres qui arretent le remplissage.
//
//   dart run tool/remove_logo_bg.dart <entree.jpg> <sortie.png> [tolerance]
//
import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final inPath = args.isNotEmpty
      ? args[0]
      : r'C:\Users\D ELL\Downloads\logoMajiChrono.jpg';
  final outPath = args.length > 1 ? args[1] : r'D:\gtmp\logo_cutout.png';
  final tol = args.length > 2 ? double.parse(args[2]) : 96.0;

  final bytes = File(inPath).readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Image illisible: $inPath');
    exit(1);
  }
  final image = src.convert(numChannels: 4);
  final w = image.width;
  final h = image.height;

  // Couleur de fond : moyenne des quatre coins.
  final corners = [
    image.getPixel(0, 0),
    image.getPixel(w - 1, 0),
    image.getPixel(0, h - 1),
    image.getPixel(w - 1, h - 1),
  ];
  final bgR = corners.map((p) => p.r).reduce((a, b) => a + b) / 4;
  final bgG = corners.map((p) => p.g).reduce((a, b) => a + b) / 4;
  final bgB = corners.map((p) => p.b).reduce((a, b) => a + b) / 4;

  bool near(num r, num g, num b) {
    final dr = r - bgR, dg = g - bgG, db = b - bgB;
    return (dr * dr + dg * dg + db * db) <= tol * tol;
  }

  final visited = List<bool>.filled(w * h, false);
  final queue = Queue<int>();

  void seed(int x, int y) {
    final i = y * w + x;
    if (visited[i]) return;
    final p = image.getPixel(x, y);
    if (near(p.r, p.g, p.b)) {
      visited[i] = true;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  var cleared = 0;
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w;
    final y = i ~/ w;
    // Transparent.
    image.setPixelRgba(x, y, 0, 0, 0, 0);
    cleared++;
    void visit(int nx, int ny) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
      final ni = ny * w + nx;
      if (visited[ni]) return;
      final p = image.getPixel(nx, ny);
      if (near(p.r, p.g, p.b)) {
        visited[ni] = true;
        queue.add(ni);
      }
    }

    visit(x - 1, y);
    visit(x + 1, y);
    visit(x, y - 1);
    visit(x, y + 1);
  }

  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln(
    'OK: $outPath  (${w}x$h, bg=(${bgR.round()},${bgG.round()},'
    '${bgB.round()}), tol=$tol, transparents=$cleared)',
  );
}
