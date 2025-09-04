import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/utils/flac_picture_parser.dart';
import 'package:test/test.dart';

void main() {
  group('FlacPictureParser', () {
    late FlacPictureParser parser;

    setUp(() {
      parser = const FlacPictureParser();
    });

    group('parsePictureBlock', () {
      test('parses valid METADATA_BLOCK_PICTURE with front cover', () {
        // Create a valid METADATA_BLOCK_PICTURE block
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03, // Front cover
          mimeType: 'image/jpeg',
          description: 'Album cover',
          width: 500,
          height: 500,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG header
        );

        final artworkData = parser.parsePictureBlock(blockBytes);

        expect(artworkData.mimeType, equals('image/jpeg'));
        expect(artworkData.type, equals(ArtworkType.frontCover));
        expect(artworkData.description, equals('Album cover'));
      });

      test('parses valid METADATA_BLOCK_PICTURE with back cover', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x04, // Back cover
          mimeType: 'image/png',
          description: 'Back cover art',
          width: 300,
          height: 300,
          colorDepth: 32,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // PNG header
        );

        final artworkData = parser.parsePictureBlock(blockBytes);

        expect(artworkData.mimeType, equals('image/png'));
        expect(artworkData.type, equals(ArtworkType.backCover));
        expect(artworkData.description, equals('Back cover art'));
      });

      test('parses METADATA_BLOCK_PICTURE with empty description', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: '', // Empty description
          width: 400,
          height: 400,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );

        final artworkData = parser.parsePictureBlock(blockBytes);

        expect(artworkData.mimeType, equals('image/jpeg'));
        expect(artworkData.type, equals(ArtworkType.frontCover));
        expect(artworkData.description, isNull); // Empty description becomes null
      });

      test('parses METADATA_BLOCK_PICTURE with no description', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: null, // No description
          width: 400,
          height: 400,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );

        final artworkData = parser.parsePictureBlock(blockBytes);

        expect(artworkData.mimeType, equals('image/jpeg'));
        expect(artworkData.type, equals(ArtworkType.frontCover));
        expect(artworkData.description, isNull);
      });

      test('maps all artwork types correctly', () {
        final testCases = [
          (0x03, ArtworkType.frontCover),
          (0x04, ArtworkType.backCover),
          (0x05, ArtworkType.leaflet),
          (0x06, ArtworkType.media),
          (0x07, ArtworkType.leadArtist),
          (0x08, ArtworkType.artist),
          (0x09, ArtworkType.conductor),
          (0x0A, ArtworkType.band),
          (0x0B, ArtworkType.composer),
          (0x0C, ArtworkType.lyricist),
          (0x0D, ArtworkType.recordingLocation),
          (0x0E, ArtworkType.duringRecording),
          (0x0F, ArtworkType.duringPerformance),
          (0x10, ArtworkType.movieScreenCapture),
          (0x11, ArtworkType.brightColoredFish),
          (0x12, ArtworkType.illustration),
          (0x13, ArtworkType.bandLogotype),
          (0x14, ArtworkType.publisherLogotype),
        ];

        for (final (pictureTypeValue, expectedArtworkType) in testCases) {
          final blockBytes = _createValidPictureBlock(
            pictureType: pictureTypeValue,
            mimeType: 'image/jpeg',
            description: 'Test',
            width: 100,
            height: 100,
            colorDepth: 24,
            numberOfColors: 0,
            imageData: Uint8List.fromList([0xFF, 0xD8]),
          );

          final artworkData = parser.parsePictureBlock(blockBytes);
          expect(
            artworkData.type,
            equals(expectedArtworkType),
            reason: 'Picture type 0x${pictureTypeValue.toRadixString(16)} should map to $expectedArtworkType',
          );
        }
      });

      test('defaults to front cover for unknown picture type', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0xFF, // Unknown type
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8]),
        );

        final artworkData = parser.parsePictureBlock(blockBytes);
        expect(artworkData.type, equals(ArtworkType.frontCover));
      });

      test('creates lazy loader for image data', () async {
        final imageData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: imageData,
        );

        final artworkData = parser.parsePictureBlock(blockBytes);

        // Load the image data
        final loadedData = await artworkData.data;
        expect(loadedData, equals(imageData));
      });

      test('handles UTF-8 encoded MIME type and description', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: 'Álbum cövér with ümlauts', // UTF-8 characters
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8]),
        );

        final artworkData = parser.parsePictureBlock(blockBytes);
        expect(artworkData.description, equals('Álbum cövér with ümlauts'));
      });

      test('throws FormatException for empty block', () {
        expect(
          () => parser.parsePictureBlock(Uint8List(0)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws FormatException for insufficient data', () {
        // Block with only 3 bytes (need at least 4 for picture type)
        final blockBytes = Uint8List.fromList([0x00, 0x00, 0x03]);

        expect(
          () => parser.parsePictureBlock(blockBytes),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for invalid MIME type length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Picture type
        builder.add(_uint32Bytes(1000)); // Invalid MIME type length (exceeds remaining data)

        expect(
          () => parser.parsePictureBlock(builder.toBytes()),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for empty MIME type', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Picture type
        builder.add(_uint32Bytes(0)); // Empty MIME type length

        expect(
          () => parser.parsePictureBlock(builder.toBytes()),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for invalid description length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Picture type
        builder.add(_uint32Bytes(10)); // MIME type length
        builder.add(utf8.encode('image/jpeg')); // MIME type (10 bytes)
        builder.add(_uint32Bytes(1000)); // Invalid description length

        expect(
          () => parser.parsePictureBlock(builder.toBytes()),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for zero picture data length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Picture type
        builder.add(_uint32Bytes(10)); // MIME type length
        builder.add(utf8.encode('image/jpeg')); // MIME type
        builder.add(_uint32Bytes(0)); // Description length
        builder.add(_uint32Bytes(100)); // Width
        builder.add(_uint32Bytes(100)); // Height
        builder.add(_uint32Bytes(24)); // Color depth
        builder.add(_uint32Bytes(0)); // Number of colors
        builder.add(_uint32Bytes(0)); // Zero picture data length

        expect(
          () => parser.parsePictureBlock(builder.toBytes()),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for invalid picture data length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Picture type
        builder.add(_uint32Bytes(10)); // MIME type length
        builder.add(utf8.encode('image/jpeg')); // MIME type
        builder.add(_uint32Bytes(0)); // Description length
        builder.add(_uint32Bytes(100)); // Width
        builder.add(_uint32Bytes(100)); // Height
        builder.add(_uint32Bytes(24)); // Color depth
        builder.add(_uint32Bytes(0)); // Number of colors
        builder.add(_uint32Bytes(1000)); // Invalid picture data length (exceeds remaining)

        expect(
          () => parser.parsePictureBlock(builder.toBytes()),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('mapArtworkTypeToFlacPictureType', () {
      test('maps all artwork types to correct FLAC picture type values', () {
        final testCases = [
          (ArtworkType.frontCover, 0x03),
          (ArtworkType.backCover, 0x04),
          (ArtworkType.leaflet, 0x05),
          (ArtworkType.media, 0x06),
          (ArtworkType.leadArtist, 0x07),
          (ArtworkType.artist, 0x08),
          (ArtworkType.conductor, 0x09),
          (ArtworkType.band, 0x0A),
          (ArtworkType.composer, 0x0B),
          (ArtworkType.lyricist, 0x0C),
          (ArtworkType.recordingLocation, 0x0D),
          (ArtworkType.duringRecording, 0x0E),
          (ArtworkType.duringPerformance, 0x0F),
          (ArtworkType.movieScreenCapture, 0x10),
          (ArtworkType.brightColoredFish, 0x11),
          (ArtworkType.illustration, 0x12),
          (ArtworkType.bandLogotype, 0x13),
          (ArtworkType.publisherLogotype, 0x14),
        ];

        for (final (artworkType, expectedValue) in testCases) {
          final result = parser.mapArtworkTypeToFlacPictureType(artworkType);
          expect(result, equals(expectedValue), reason: '$artworkType should map to 0x${expectedValue.toRadixString(16)}');
        }
      });
    });

    group('isValidPictureBlock', () {
      test('returns true for valid picture block', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8]),
        );

        expect(parser.isValidPictureBlock(blockBytes), isTrue);
      });

      test('returns false for too small block', () {
        final blockBytes = Uint8List.fromList([0x00, 0x00, 0x03]);
        expect(parser.isValidPictureBlock(blockBytes), isFalse);
      });

      test('returns false for invalid picture type', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0xFF, // Invalid type > 0x14
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8]),
        );

        expect(parser.isValidPictureBlock(blockBytes), isFalse);
      });

      test('returns false for zero MIME type length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Valid picture type
        builder.add(_uint32Bytes(0)); // Zero MIME type length
        builder.add(Uint8List(100)); // Padding

        expect(parser.isValidPictureBlock(builder.toBytes()), isFalse);
      });

      test('returns false for excessive MIME type length', () {
        final builder = BytesBuilder();
        builder.add(_uint32Bytes(0x03)); // Valid picture type
        builder.add(_uint32Bytes(200)); // Excessive MIME type length
        builder.add(Uint8List(100)); // Insufficient data

        expect(parser.isValidPictureBlock(builder.toBytes()), isFalse);
      });
    });

    group('extractMetadata', () {
      test('extracts all metadata fields correctly', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/png',
          description: 'Album artwork',
          width: 600,
          height: 400,
          colorDepth: 32,
          numberOfColors: 256,
          imageData: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        );

        final metadata = parser.extractMetadata(blockBytes);

        expect(metadata.artworkType, equals(ArtworkType.frontCover));
        expect(metadata.mimeType, equals('image/png'));
        expect(metadata.description, equals('Album artwork'));
        expect(metadata.width, equals(600));
        expect(metadata.height, equals(400));
        expect(metadata.colorDepth, equals(32));
        expect(metadata.numberOfColors, equals(256));
        expect(metadata.dataLength, equals(4));
      });

      test('handles null description correctly', () {
        final blockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: null,
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8]),
        );

        final metadata = parser.extractMetadata(blockBytes);
        expect(metadata.description, isNull);
      });

      test('throws FormatException for invalid block', () {
        expect(
          () => parser.extractMetadata(Uint8List(0)),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('FlacPictureMetadata', () {
      test('identifies indexed color images correctly', () {
        final metadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/png',
          width: 100,
          height: 100,
          colorDepth: 8,
          numberOfColors: 256,
          dataLength: 1000,
        );

        expect(metadata.isIndexedColor, isTrue);
      });

      test('identifies non-indexed color images correctly', () {
        final metadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/jpeg',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          dataLength: 1000,
        );

        expect(metadata.isIndexedColor, isFalse);
      });

      test('identifies vector images correctly', () {
        final metadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/svg+xml',
          width: 0,
          height: 0,
          colorDepth: 0,
          numberOfColors: 0,
          dataLength: 1000,
        );

        expect(metadata.isPossiblyVector, isTrue);
      });

      test('provides correct color format descriptions', () {
        // Vector image
        final vectorMetadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/svg+xml',
          width: 0,
          height: 0,
          colorDepth: 0,
          numberOfColors: 0,
          dataLength: 1000,
        );
        expect(vectorMetadata.colorFormatDescription, equals('Vector'));

        // Indexed color
        final indexedMetadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/png',
          width: 100,
          height: 100,
          colorDepth: 8,
          numberOfColors: 256,
          dataLength: 1000,
        );
        expect(indexedMetadata.colorFormatDescription, equals('8-bit indexed (256 colors)'));

        // True color
        final trueColorMetadata = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/jpeg',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          dataLength: 1000,
        );
        expect(trueColorMetadata.colorFormatDescription, equals('24-bit'));
      });

      test('equality works correctly', () {
        final metadata1 = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          dataLength: 1000,
        );

        final metadata2 = const FlacPictureMetadata(
          artworkType: ArtworkType.frontCover,
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          dataLength: 1000,
        );

        final metadata3 = const FlacPictureMetadata(
          artworkType: ArtworkType.backCover, // Different type
          mimeType: 'image/jpeg',
          description: 'Test',
          width: 100,
          height: 100,
          colorDepth: 24,
          numberOfColors: 0,
          dataLength: 1000,
        );

        expect(metadata1, equals(metadata2));
        expect(metadata1, isNot(equals(metadata3)));
      });
    });
  });
}

/// Helper function to create a valid METADATA_BLOCK_PICTURE block for testing.
Uint8List _createValidPictureBlock({
  required int pictureType,
  required String mimeType,
  String? description,
  required int width,
  required int height,
  required int colorDepth,
  required int numberOfColors,
  required Uint8List imageData,
}) {
  final builder = BytesBuilder();

  // Picture type (32-bit big-endian)
  builder.add(_uint32Bytes(pictureType));

  // MIME type length and string
  final mimeTypeBytes = utf8.encode(mimeType);
  builder.add(_uint32Bytes(mimeTypeBytes.length));
  builder.add(mimeTypeBytes);

  // Description length and string
  final descriptionBytes = description != null ? utf8.encode(description) : Uint8List(0);
  builder.add(_uint32Bytes(descriptionBytes.length));
  if (descriptionBytes.isNotEmpty) {
    builder.add(descriptionBytes);
  }

  // Picture dimensions and color info
  builder.add(_uint32Bytes(width));
  builder.add(_uint32Bytes(height));
  builder.add(_uint32Bytes(colorDepth));
  builder.add(_uint32Bytes(numberOfColors));

  // Picture data length and data
  builder.add(_uint32Bytes(imageData.length));
  builder.add(imageData);

  return builder.toBytes();
}

/// Helper function to convert a 32-bit integer to big-endian bytes.
Uint8List _uint32Bytes(int value) {
  final bytes = Uint8List(4);
  bytes[0] = (value >> 24) & 0xFF;
  bytes[1] = (value >> 16) & 0xFF;
  bytes[2] = (value >> 8) & 0xFF;
  bytes[3] = value & 0xFF;
  return bytes;
}
