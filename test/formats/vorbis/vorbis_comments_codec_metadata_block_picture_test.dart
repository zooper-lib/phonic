import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/formats/vorbis/vorbis_comments_codec.dart';
import 'package:test/test.dart';

void main() {
  group('VorbisCommentsCodec METADATA_BLOCK_PICTURE', () {
    late VorbisCommentsCodec codec;

    setUp(() {
      codec = const VorbisCommentsCodec();
    });

    group('parseMetadataBlockPicture', () {
      test('parses valid METADATA_BLOCK_PICTURE block', () {
        // Create a valid METADATA_BLOCK_PICTURE block
        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: 0x03, // Front cover
          mimeType: 'image/jpeg',
          description: 'Album cover',
          width: 500,
          height: 500,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG header
        );

        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);

        expect(artworkTag.value.mimeType, equals('image/jpeg'));
        expect(artworkTag.value.type, equals(ArtworkType.frontCover));
        expect(artworkTag.value.description, equals('Album cover'));
      });

      test('creates lazy loader for image data', () async {
        final imageData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: 0x04, // Back cover
          mimeType: 'image/png',
          description: 'Back cover art',
          width: 300,
          height: 300,
          colorDepth: 32,
          numberOfColors: 0,
          imageData: imageData,
        );

        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);

        // Verify metadata
        expect(artworkTag.value.mimeType, equals('image/png'));
        expect(artworkTag.value.type, equals(ArtworkType.backCover));
        expect(artworkTag.value.description, equals('Back cover art'));

        // Load and verify image data
        final loadedData = await artworkTag.value.data;
        expect(loadedData, equals(imageData));
      });

      test('handles picture block with no description', () {
        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: 0x05, // Leaflet
          mimeType: 'image/gif',
          description: null, // No description
          width: 200,
          height: 150,
          colorDepth: 8,
          numberOfColors: 256,
          imageData: Uint8List.fromList([0x47, 0x49, 0x46, 0x38]), // GIF header
        );

        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);

        expect(artworkTag.value.mimeType, equals('image/gif'));
        expect(artworkTag.value.type, equals(ArtworkType.leaflet));
        expect(artworkTag.value.description, isNull);
      });

      test('handles various artwork types', () {
        final testCases = [
          (0x06, ArtworkType.media),
          (0x07, ArtworkType.leadArtist),
          (0x08, ArtworkType.artist),
          (0x13, ArtworkType.bandLogotype),
          (0x14, ArtworkType.publisherLogotype),
        ];

        for (final (pictureTypeValue, expectedArtworkType) in testCases) {
          final pictureBlockBytes = _createValidPictureBlock(
            pictureType: pictureTypeValue,
            mimeType: 'image/jpeg',
            description: 'Test artwork',
            width: 100,
            height: 100,
            colorDepth: 24,
            numberOfColors: 0,
            imageData: Uint8List.fromList([0xFF, 0xD8]),
          );

          final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);
          expect(
            artworkTag.value.type,
            equals(expectedArtworkType),
            reason: 'Picture type 0x${pictureTypeValue.toRadixString(16)} should map to $expectedArtworkType',
          );
        }
      });

      test('throws FormatException for invalid picture block', () {
        // Empty block
        expect(
          () => codec.parseMetadataBlockPicture(Uint8List(0)),
          throwsA(isA<ArgumentError>()),
        );

        // Insufficient data
        final invalidBlock = Uint8List.fromList([0x00, 0x00, 0x03]);
        expect(
          () => codec.parseMetadataBlockPicture(invalidBlock),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles UTF-8 encoded description', () {
        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/jpeg',
          description: 'Álbum cövér with spëcial characters 🎵', // UTF-8 with emoji
          width: 400,
          height: 400,
          colorDepth: 24,
          numberOfColors: 0,
          imageData: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );

        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);
        expect(artworkTag.value.description, equals('Álbum cövér with spëcial characters 🎵'));
      });

      test('handles large image data efficiently', () async {
        // Create a larger image data block to test lazy loading
        final largeImageData = Uint8List(10000);
        for (int i = 0; i < largeImageData.length; i++) {
          largeImageData[i] = i % 256;
        }

        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: 0x03,
          mimeType: 'image/png',
          description: 'Large image',
          width: 1000,
          height: 1000,
          colorDepth: 32,
          numberOfColors: 0,
          imageData: largeImageData,
        );

        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);

        // Verify metadata is accessible immediately
        expect(artworkTag.value.mimeType, equals('image/png'));
        expect(artworkTag.value.description, equals('Large image'));

        // Verify lazy loading works for large data
        final loadedData = await artworkTag.value.data;
        expect(loadedData.length, equals(10000));
        expect(loadedData, equals(largeImageData));
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
