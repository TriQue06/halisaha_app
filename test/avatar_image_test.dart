import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:japonkale/core/utils/avatar_image.dart';

void main() {
  group('Profil fotoğrafı biçim tespiti', () {
    test('JPEG, PNG ve WebP imzaları tanınır', () {
      expect(
        AvatarImageType.detect(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0])),
        AvatarImageType.jpeg,
      );
      expect(
        AvatarImageType.detect(
          Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
        ),
        AvatarImageType.png,
      );
      expect(
        AvatarImageType.detect(Uint8List.fromList(<int>[
          0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, //
          0x57, 0x45, 0x42, 0x50, 0x56, 0x50,
        ])),
        AvatarImageType.webp,
      );
    });

    test('desteklenmeyen veya eksik veri reddedilir', () {
      // GIF
      expect(AvatarImageType.detect(Uint8List.fromList('GIF89a'.codeUnits)), isNull);
      // WebP imzasının yarısı
      expect(
        AvatarImageType.detect(Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46, 0, 0])),
        isNull,
      );
      expect(AvatarImageType.detect(Uint8List(0)), isNull);
    });
  });
}
