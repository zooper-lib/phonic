import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/mime_type.dart';

void main() {
  group('MimeType', () {
    test('enum values have correct standard names', () {
      expect(MimeType.jpeg.standardName, equals('image/jpeg'));
      expect(MimeType.png.standardName, equals('image/png'));
      expect(MimeType.gif.standardName, equals('image/gif'));
      expect(MimeType.bmp.standardName, equals('image/bmp'));
      expect(MimeType.webp.standardName, equals('image/webp'));
      expect(MimeType.tiff.standardName, equals('image/tiff'));
      expect(MimeType.svg.standardName, equals('image/svg+xml'));
    });

    test('name getter returns standard name', () {
      expect(MimeType.jpeg.name, equals('image/jpeg'));
      expect(MimeType.png.name, equals('image/png'));
      expect(MimeType.svg.name, equals('image/svg+xml'));
    });

    test('fromName returns correct enum values', () {
      expect(MimeType.fromName('image/jpeg'), equals(MimeType.jpeg));
      expect(MimeType.fromName('image/png'), equals(MimeType.png));
      expect(MimeType.fromName('image/gif'), equals(MimeType.gif));
      expect(MimeType.fromName('image/bmp'), equals(MimeType.bmp));
      expect(MimeType.fromName('image/webp'), equals(MimeType.webp));
      expect(MimeType.fromName('image/tiff'), equals(MimeType.tiff));
      expect(MimeType.fromName('image/svg+xml'), equals(MimeType.svg));
    });

    test('fromName returns null for invalid names', () {
      expect(MimeType.fromName('image/jpg'), isNull); // Not standard
      expect(MimeType.fromName('IMAGE/JPEG'), isNull); // Case sensitive
      expect(MimeType.fromName('text/plain'), isNull); // Wrong type
      expect(MimeType.fromName(''), isNull);
      expect(MimeType.fromName('invalid'), isNull);
    });

    test('allNames returns all MIME type names', () {
      final allNames = MimeType.allNames;
      expect(allNames, contains('image/jpeg'));
      expect(allNames, contains('image/png'));
      expect(allNames, contains('image/gif'));
      expect(allNames, contains('image/bmp'));
      expect(allNames, contains('image/webp'));
      expect(allNames, contains('image/tiff'));
      expect(allNames, contains('image/svg+xml'));
      expect(allNames.length, equals(7));
    });

    test('namesFor returns correct set of names', () {
      final mimeTypes = {MimeType.jpeg, MimeType.png, MimeType.webp};
      final names = MimeType.namesFor(mimeTypes);
      expect(names, equals({'image/jpeg', 'image/png', 'image/webp'}));
    });

    test('supportsTransparency returns correct values', () {
      // Formats that support transparency
      expect(MimeType.png.supportsTransparency, isTrue);
      expect(MimeType.gif.supportsTransparency, isTrue);
      expect(MimeType.webp.supportsTransparency, isTrue);
      expect(MimeType.svg.supportsTransparency, isTrue);

      // Formats that don't support transparency
      expect(MimeType.jpeg.supportsTransparency, isFalse);
      expect(MimeType.bmp.supportsTransparency, isFalse);
      expect(MimeType.tiff.supportsTransparency, isFalse);
    });

    test('isLossy returns correct values', () {
      // Lossy formats
      expect(MimeType.jpeg.isLossy, isTrue);

      // Lossless formats
      expect(MimeType.png.isLossy, isFalse);
      expect(MimeType.gif.isLossy, isFalse);
      expect(MimeType.bmp.isLossy, isFalse);
      expect(MimeType.webp.isLossy, isFalse); // Can be both, defaults to lossless
      expect(MimeType.tiff.isLossy, isFalse);
      expect(MimeType.svg.isLossy, isFalse);
    });

    test('isVector returns correct values', () {
      // Vector format
      expect(MimeType.svg.isVector, isTrue);

      // Raster formats
      expect(MimeType.jpeg.isVector, isFalse);
      expect(MimeType.png.isVector, isFalse);
      expect(MimeType.gif.isVector, isFalse);
      expect(MimeType.bmp.isVector, isFalse);
      expect(MimeType.webp.isVector, isFalse);
      expect(MimeType.tiff.isVector, isFalse);
    });

    test('supportsAnimation returns correct values', () {
      // Formats that support animation
      expect(MimeType.gif.supportsAnimation, isTrue);
      expect(MimeType.webp.supportsAnimation, isTrue);
      expect(MimeType.svg.supportsAnimation, isTrue);

      // Formats that don't support animation
      expect(MimeType.jpeg.supportsAnimation, isFalse);
      expect(MimeType.png.supportsAnimation, isFalse);
      expect(MimeType.bmp.supportsAnimation, isFalse);
      expect(MimeType.tiff.supportsAnimation, isFalse);
    });

    test('fileExtension returns correct extensions', () {
      expect(MimeType.jpeg.fileExtension, equals('jpg'));
      expect(MimeType.png.fileExtension, equals('png'));
      expect(MimeType.gif.fileExtension, equals('gif'));
      expect(MimeType.bmp.fileExtension, equals('bmp'));
      expect(MimeType.webp.fileExtension, equals('webp'));
      expect(MimeType.tiff.fileExtension, equals('tiff'));
      expect(MimeType.svg.fileExtension, equals('svg'));
    });

    test('fileExtensions returns all valid extensions', () {
      expect(MimeType.jpeg.fileExtensions, equals({'jpg', 'jpeg'}));
      expect(MimeType.tiff.fileExtensions, equals({'tiff', 'tif'}));
      expect(MimeType.png.fileExtensions, equals({'png'}));
      expect(MimeType.gif.fileExtensions, equals({'gif'}));
      expect(MimeType.bmp.fileExtensions, equals({'bmp'}));
      expect(MimeType.webp.fileExtensions, equals({'webp'}));
      expect(MimeType.svg.fileExtensions, equals({'svg'}));
    });

    test('description returns human-readable descriptions', () {
      expect(MimeType.jpeg.description, equals('JPEG Image'));
      expect(MimeType.png.description, equals('PNG Image'));
      expect(MimeType.gif.description, equals('GIF Image'));
      expect(MimeType.bmp.description, equals('Bitmap Image'));
      expect(MimeType.webp.description, equals('WebP Image'));
      expect(MimeType.tiff.description, equals('TIFF Image'));
      expect(MimeType.svg.description, equals('SVG Vector Image'));
    });

    test('toString returns standard name', () {
      expect(MimeType.jpeg.toString(), equals('image/jpeg'));
      expect(MimeType.png.toString(), equals('image/png'));
      expect(MimeType.svg.toString(), equals('image/svg+xml'));
    });

    group('format characteristics', () {
      test('JPEG characteristics are correct', () {
        expect(MimeType.jpeg.supportsTransparency, isFalse);
        expect(MimeType.jpeg.isLossy, isTrue);
        expect(MimeType.jpeg.isVector, isFalse);
        expect(MimeType.jpeg.supportsAnimation, isFalse);
        expect(MimeType.jpeg.fileExtensions, contains('jpg'));
        expect(MimeType.jpeg.fileExtensions, contains('jpeg'));
      });

      test('PNG characteristics are correct', () {
        expect(MimeType.png.supportsTransparency, isTrue);
        expect(MimeType.png.isLossy, isFalse);
        expect(MimeType.png.isVector, isFalse);
        expect(MimeType.png.supportsAnimation, isFalse);
        expect(MimeType.png.fileExtension, equals('png'));
      });

      test('SVG characteristics are correct', () {
        expect(MimeType.svg.supportsTransparency, isTrue);
        expect(MimeType.svg.isLossy, isFalse);
        expect(MimeType.svg.isVector, isTrue);
        expect(MimeType.svg.supportsAnimation, isTrue);
        expect(MimeType.svg.fileExtension, equals('svg'));
      });

      test('WebP characteristics are correct', () {
        expect(MimeType.webp.supportsTransparency, isTrue);
        expect(MimeType.webp.isLossy, isFalse); // Defaults to lossless
        expect(MimeType.webp.isVector, isFalse);
        expect(MimeType.webp.supportsAnimation, isTrue);
        expect(MimeType.webp.fileExtension, equals('webp'));
      });
    });

    group('validation and utility', () {
      test('all enum values have unique standard names', () {
        final names = MimeType.values.map((e) => e.standardName).toSet();
        expect(names.length, equals(MimeType.values.length));
      });

      test('all enum values have valid file extensions', () {
        for (final mimeType in MimeType.values) {
          expect(mimeType.fileExtension, isNotEmpty);
          expect(mimeType.fileExtensions, isNotEmpty);
          expect(mimeType.fileExtensions, contains(mimeType.fileExtension));
        }
      });

      test('all enum values have descriptions', () {
        for (final mimeType in MimeType.values) {
          expect(mimeType.description, isNotEmpty);
          expect(mimeType.description, isNot(equals(mimeType.standardName)));
        }
      });

      test('standard names follow MIME type conventions', () {
        for (final mimeType in MimeType.values) {
          expect(mimeType.standardName, startsWith('image/'));
          expect(mimeType.standardName, isNot(contains(' ')));
          expect(mimeType.standardName, isNot(contains('\t')));
          expect(mimeType.standardName, isNot(contains('\n')));
        }
      });
    });
  });
}
