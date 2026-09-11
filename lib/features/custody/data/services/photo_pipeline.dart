import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:path/path.dart' as p;

/// Traitement d'une photo de constat (EXI-CC41, EXI-CC42).
///
/// Le budget est chiffre par le cahier des charges : 1280 px sur le grand cote,
/// 200 Ko maximum par photo, 1,2 Mo pour le constat complet. Ce ne sont pas des
/// preferences esthetiques — un constat de quatre photos non compressees pese
/// plusieurs megaoctets, et sur le forfait d'un livreur malgache (§4.4) une
/// course couterait alors davantage en data qu'elle ne rapporte.
///
/// La compression est **iterative** : on baisse la qualite jusqu'a tenir le
/// budget, plutot que de fixer une qualite arbitraire qui tiendrait sur une
/// photo de mur uni et exploserait sur un colis texture.
class PhotoPipeline {
  const PhotoPipeline({this.maxLongSide = 1280, this.maxBytes = 200 * 1024});

  final int maxLongSide;
  final int maxBytes;

  /// Qualites tentees successivement. On commence haut : une photo de constat
  /// sert a etablir un dommage, la degrader d'emblee reviendrait a affaiblir la
  /// preuve pour economiser des octets qu'on n'a pas encore mesures.
  static const List<int> _qualities = [88, 78, 68, 58, 48, 38];

  /// Compresse et enregistre une photo, puis retourne sa description signee.
  Future<CustodyPhoto> process({
    required Uint8List raw,
    required PhotoAngle angle,
    required Directory directory,
    required DateTime takenAt,
    GeoPoint? point,
    String? anomalyNote,
    // Les photos supplementaires d'une remise (scelle rompu, piece d'identite
    // d'un tiers) reprennent un angle deja pris ; sans nom distinct, la seconde
    // ecraserait la premiere sur le disque.
    String? fileName,
  }) async {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const FormatException('Image illisible');
    }

    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxLongSide)
        : img.copyResize(decoded, height: maxLongSide);

    Uint8List encoded = Uint8List(0);
    for (final quality in _qualities) {
      encoded = img.encodeJpg(resized, quality: quality);
      if (encoded.length <= maxBytes) break;
    }

    await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, '${fileName ?? angle.wireName}.jpg'),
    );
    await file.writeAsBytes(encoded, flush: true);

    return CustodyPhoto(
      angle: angle,
      localPath: file.path,
      takenAt: takenAt,
      sizeBytes: encoded.length,
      // L'empreinte porte sur les octets **effectivement enregistres**, donc sur
      // l'image compressee : c'est elle qui sera transmise et comparee.
      sha256: sha256.convert(encoded).toString(),
      point: point,
      anomalyNote: anomalyNote,
    );
  }

  /// Empreinte d'un contenu quelconque, utilisee par les tests et le rendu PDF.
  static String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  /// Encode le vecteur de signature pour transmission.
  static String encodeSignature(VectorSignature signature) =>
      jsonEncode(signature.toJson());
}
