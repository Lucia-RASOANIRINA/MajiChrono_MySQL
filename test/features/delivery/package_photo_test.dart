import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/delivery/data/mock/delivery_mock_module.dart';
import 'package:majichrono/features/delivery/data/mock/package_photo_generator.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

MockRequest _req(String method, String path, [Map<String, dynamic>? body]) =>
    MockRequest(
      method: method,
      path: path,
      query: const {},
      headers: const {},
      body: body ?? <String, dynamic>{},
    );

void main() {
  test(
    'la photo envoyee par l expediteur est celle que le livreur relit',
    () async {
      final deliveries = DeliveryMockModule();
      final backend = MockBackend()..register(deliveries);
      final photo = PackagePhotoGenerator().render(DeliveryKind.standard);

      final upload = await backend.handle(
        _req('POST', '/media', {
          'imageBase64': base64Encode(photo),
          'contentType': 'image/jpeg',
        }),
      );
      final id = (upload.body! as Map<String, dynamic>)['id'] as String;

      final read = await backend.handle(_req('GET', '/media/$id'));
      expect(read.statusCode, 200);
      expect(read.bytes, photo);
    },
  );

  test('chaque nature de colis donne une photo JPEG lisible', () {
    final generator = PackagePhotoGenerator();
    for (final kind in DeliveryKind.values) {
      final decoded = img.decodeJpg(generator.render(kind));
      expect(decoded, isNotNull, reason: kind.name);
      expect(decoded!.width, PackagePhotoGenerator.width);
      expect(decoded.height, PackagePhotoGenerator.height);
    }
  });
}
