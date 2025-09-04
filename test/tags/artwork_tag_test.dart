import 'dart:typed_data';

import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/mime_type.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/utils/lazy_artwork_loader.dart';
import 'package:test/test.dart';

void main() {
  group('ArtworkTag', () {
    late ArtworkData testArtworkData;
    late Uint8List testImageBytes;

    setUp(() {
      // Create test image data (simple JPEG-like header)
      testImageBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG header
        0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, // JFIF marker
        ...List.generate(100, (i) => i % 256), // Some image data
        0xFF, 0xD9, // JPEG end marker
      ]);

      testArtworkData = ArtworkData(
        mimeType: MimeType.jpeg.standardName,
        type: ArtworkType.frontCover,
        description: 'Test album cover',
        dataLoader: () async => testImageBytes,
      );
    });

    group('constructor', () {
      test('creates instance with all required parameters', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag = ArtworkTag(
          testArtworkData,
          provenance: provenance,
        );

        expect(tag.value, equals(testArtworkData));
        expect(tag.key, equals(TagKey.artwork));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with default provenance', () {
        final tag = ArtworkTag(testArtworkData);

        expect(tag.value, equals(testArtworkData));
        expect(tag.key, equals(TagKey.artwork));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with different artwork types', () {
        for (final artworkType in ArtworkType.values) {
          final artworkData = ArtworkData(
            mimeType: MimeType.png.standardName,
            type: artworkType,
            dataLoader: () async => testImageBytes,
          );
          final tag = ArtworkTag(artworkData);

          expect(tag.value.type, equals(artworkType));
          expect(tag.key, equals(TagKey.artwork));
        }
      });

      test('creates instance with different MIME types', () {
        final mimeTypes = [
          MimeType.jpeg.standardName,
          MimeType.png.standardName,
          MimeType.gif.standardName,
          MimeType.webp.standardName,
        ];

        for (final mimeType in mimeTypes) {
          final artworkData = ArtworkData(
            mimeType: mimeType,
            type: ArtworkType.frontCover,
            dataLoader: () async => testImageBytes,
          );
          final tag = ArtworkTag(artworkData);

          expect(tag.value.mimeType, equals(mimeType));
        }
      });

      test('creates instance with and without description', () {
        // With description
        final artworkWithDesc = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.backCover,
          description: 'Back cover artwork',
          dataLoader: () async => testImageBytes,
        );
        final tagWithDesc = ArtworkTag(artworkWithDesc);

        expect(tagWithDesc.value.description, equals('Back cover artwork'));

        // Without description
        final artworkWithoutDesc = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.backCover,
          dataLoader: () async => testImageBytes,
        );
        final tagWithoutDesc = ArtworkTag(artworkWithoutDesc);

        expect(tagWithoutDesc.value.description, isNull);
      });

      test('creates instance with all container kinds in provenance', () {
        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final tag = ArtworkTag(testArtworkData, provenance: provenance);
          expect(tag.provenance.containerKind, equals(kind));
        }
      });

      test('creates instance with all confidence levels in provenance', () {
        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final tag = ArtworkTag(testArtworkData, provenance: provenance);
          expect(tag.provenance.confidence, equals(confidence));
        }
      });
    });

    group('withProvenance', () {
      test('returns new instance with updated provenance', () {
        final originalTag = ArtworkTag(
          testArtworkData,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(testArtworkData));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(testArtworkData));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns correct concrete type', () {
        final originalTag = ArtworkTag(testArtworkData);

        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<ArtworkTag>());
        expect(updatedTag.value, isA<ArtworkData>());
      });

      test('preserves value and key exactly', () {
        final originalTag = ArtworkTag(testArtworkData);

        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag.value, equals(originalTag.value));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance, equals(newProvenance));
      });

      test('works with none provenance', () {
        final originalTag = ArtworkTag(
          testArtworkData,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });
    });

    group('equality', () {
      test('equal instances with same artwork data and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = ArtworkTag(testArtworkData, provenance: provenance);
        final tag2 = ArtworkTag(testArtworkData, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different artwork data', () {
        final artworkData1 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () async => testImageBytes,
        );
        final artworkData2 = ArtworkData(
          mimeType: MimeType.png.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () async => testImageBytes,
        );

        final tag1 = ArtworkTag(artworkData1);
        final tag2 = ArtworkTag(artworkData2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different provenance', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v1,
          'v1',
          TagConfidence.certain,
        );

        final tag1 = ArtworkTag(testArtworkData, provenance: provenance1);
        final tag2 = ArtworkTag(testArtworkData, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = ArtworkTag(testArtworkData);
        final tag2 = ArtworkTag(testArtworkData);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal artwork data with different loaders but same metadata', () {
        final artworkData1 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          description: 'Cover',
          dataLoader: () async => testImageBytes,
        );
        final artworkData2 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          description: 'Cover',
          dataLoader: () async => Uint8List.fromList([1, 2, 3]), // Different loader
        );

        final tag1 = ArtworkTag(artworkData1);
        final tag2 = ArtworkTag(artworkData2);

        // Should be equal because ArtworkData equality excludes the loader
        expect(tag1, equals(tag2));
      });
    });

    group('lazy loading functionality', () {
      test('can access artwork metadata without loading image data', () {
        final tag = ArtworkTag(testArtworkData);

        // These should be accessible immediately without async operations
        expect(tag.value.mimeType, equals(MimeType.jpeg.standardName));
        expect(tag.value.type, equals(ArtworkType.frontCover));
        expect(tag.value.description, equals('Test album cover'));
      });

      test('can load image data asynchronously', () async {
        final tag = ArtworkTag(testArtworkData);

        final imageData = await tag.value.data;
        expect(imageData, equals(testImageBytes));
        expect(imageData.length, equals(testImageBytes.length));
      });

      test('works with LazyArtworkLoader', () async {
        // Create container bytes with embedded image
        final containerBytes = Uint8List.fromList([
          ...List.generate(50, (i) => i), // Some header data
          ...testImageBytes, // The actual image data
          ...List.generate(20, (i) => i + 200), // Some footer data
        ]);

        final loader = LazyArtworkLoader(containerBytes, 50, testImageBytes.length);
        final artworkData = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          description: 'Lazy loaded cover',
          dataLoader: () => loader.load(),
        );
        final tag = ArtworkTag(artworkData);

        // Verify metadata is accessible
        expect(tag.value.mimeType, equals(MimeType.jpeg.standardName));
        expect(tag.value.type, equals(ArtworkType.frontCover));
        expect(tag.value.description, equals('Lazy loaded cover'));

        // Verify lazy loading works
        final loadedData = await tag.value.data;
        expect(loadedData, equals(testImageBytes));
      });

      test('handles loading errors gracefully', () async {
        final artworkDataWithError = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () async => throw Exception('Loading failed'),
        );
        final tag = ArtworkTag(artworkDataWithError);

        // Metadata should still be accessible
        expect(tag.value.mimeType, equals(MimeType.jpeg.standardName));
        expect(tag.value.type, equals(ArtworkType.frontCover));

        // Loading should throw the expected error
        expect(() => tag.value.data, throwsException);
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = ArtworkTag(testArtworkData, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(testArtworkData));
        expect(tag.props[1], equals(TagKey.artwork));
        expect(tag.props[2], equals(provenance));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and artwork info', () {
        final tag = ArtworkTag(testArtworkData);
        final result = tag.toString();

        expect(result, contains('ArtworkTag'));
        expect(result, contains('ArtworkData'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = ArtworkTag(testArtworkData, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('ArtworkTag'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = ArtworkTag(
          testArtworkData,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(testArtworkData));
        expect(tag.key, equals(TagKey.artwork));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = ArtworkTag(testArtworkData);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(testArtworkData));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(testArtworkData));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('generic type parameter enforces ArtworkData type', () {
        final tag = ArtworkTag(testArtworkData);

        expect(tag.value, isA<ArtworkData>());
        expect(tag.value, isNot(isA<String>()));
        expect(tag.value, isNot(isA<int>()));
      });

      test('withProvenance maintains concrete type', () {
        final originalTag = ArtworkTag(testArtworkData);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<ArtworkTag>());
        expect(newTag.value, isA<ArtworkData>());
      });
    });

    group('edge cases', () {
      test('handles very large image data', () async {
        final largeImageBytes = Uint8List(1024 * 1024); // 1MB of data
        for (int i = 0; i < largeImageBytes.length; i++) {
          largeImageBytes[i] = i % 256;
        }

        final artworkData = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () async => largeImageBytes,
        );
        final tag = ArtworkTag(artworkData);

        final loadedData = await tag.value.data;
        expect(loadedData.length, equals(1024 * 1024));
        expect(loadedData, equals(largeImageBytes));
      });

      test('handles empty image data', () async {
        final emptyImageBytes = Uint8List(0);
        final artworkData = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () async => emptyImageBytes,
        );
        final tag = ArtworkTag(artworkData);

        final loadedData = await tag.value.data;
        expect(loadedData.length, equals(0));
        expect(loadedData, equals(emptyImageBytes));
      });

      test('handles unicode characters in description', () {
        final artworkData = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          description: '🎵 Album cover with émojis and ñ special chars 中文',
          dataLoader: () async => testImageBytes,
        );
        final tag = ArtworkTag(artworkData);

        expect(tag.value.description, equals('🎵 Album cover with émojis and ñ special chars 中文'));
      });

      test('handles all artwork types', () {
        for (final artworkType in ArtworkType.values) {
          final artworkData = ArtworkData(
            mimeType: MimeType.png.standardName,
            type: artworkType,
            description: 'Test ${artworkType.name}',
            dataLoader: () async => testImageBytes,
          );
          final tag = ArtworkTag(artworkData);

          expect(tag.value.type, equals(artworkType));
          expect(tag.value.description, equals('Test ${artworkType.name}'));
        }
      });
    });
  });
}
