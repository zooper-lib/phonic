import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/formats/vorbis/vorbis_comments_codec.dart';
import 'package:phonic/src/utils/flac_picture_parser.dart';

void main() {
  group('FLAC Picture Integration', () {
    test('end-to-end METADATA_BLOCK_PICTURE parsing workflow', () async {
      // Create a realistic METADATA_BLOCK_PICTURE block
      final imageData = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, // JPEG header
        0x00, 0x01, 0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, // JFIF data
        0xFF, 0xD9, // JPEG end marker
      ]);

      final pictureBlockBytes = _createValidPictureBlock(
        pictureType: 0x03, // Front cover
        mimeType: 'image/jpeg',
        description: 'Album Cover Art',
        width: 500,
        height: 500,
        colorDepth: 24,
        numberOfColors: 0,
        imageData: imageData,
      );

      // Test direct parser usage
      const parser = FlacPictureParser();
      final artworkData = parser.parsePictureBlock(pictureBlockBytes);

      expect(artworkData.mimeType, equals('image/jpeg'));
      expect(artworkData.type, equals(ArtworkType.frontCover));
      expect(artworkData.description, equals('Album Cover Art'));

      // Test lazy loading
      final loadedData = await artworkData.data;
      expect(loadedData, equals(imageData));
      expect(loadedData.length, equals(22));

      // Test codec integration
      const codec = VorbisCommentsCodec();
      final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);

      expect(artworkTag.value.mimeType, equals('image/jpeg'));
      expect(artworkTag.value.type, equals(ArtworkType.frontCover));
      expect(artworkTag.value.description, equals('Album Cover Art'));

      // Verify lazy loading works through codec
      final codecLoadedData = await artworkTag.value.data;
      expect(codecLoadedData, equals(imageData));
    });

    test('handles multiple artwork types in sequence', () async {
      final testCases = [
        (0x03, ArtworkType.frontCover, 'Front Cover'),
        (0x04, ArtworkType.backCover, 'Back Cover'),
        (0x08, ArtworkType.artist, 'Artist Photo'),
        (0x13, ArtworkType.bandLogotype, 'Band Logo'),
      ];

      const parser = FlacPictureParser();
      const codec = VorbisCommentsCodec();

      for (final (pictureType, expectedType, description) in testCases) {
        final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
        final pictureBlockBytes = _createValidPictureBlock(
          pictureType: pictureType,
          mimeType: 'image/png',
          description: description,
          width: 300,
          height: 300,
          colorDepth: 32,
          numberOfColors: 0,
          imageData: imageData,
        );

        // Test parser
        final artworkData = parser.parsePictureBlock(pictureBlockBytes);
        expect(artworkData.type, equals(expectedType));
        expect(artworkData.description, equals(description));

        // Test codec
        final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);
        expect(artworkTag.value.type, equals(expectedType));
        expect(artworkTag.value.description, equals(description));

        // Verify data loading
        final loadedData = await artworkTag.value.data;
        expect(loadedData, equals(imageData));
      }
    });

    test('validates picture block structure correctly', () {
      const parser = FlacPictureParser();

      // Valid block
      final validBlock = _createValidPictureBlock(
        pictureType: 0x03,
        mimeType: 'image/jpeg',
        description: 'Test',
        width: 100,
        height: 100,
        colorDepth: 24,
        numberOfColors: 0,
        imageData: Uint8List.fromList([0xFF, 0xD8]),
      );
      expect(parser.isValidPictureBlock(validBlock), isTrue);

      // Invalid blocks
      expect(parser.isValidPictureBlock(Uint8List(0)), isFalse); // Empty
      expect(parser.isValidPictureBlock(Uint8List(10)), isFalse); // Too small

      // Invalid picture type
      final invalidTypeBlock = _createValidPictureBlock(
        pictureType: 0xFF, // Invalid type
        mimeType: 'image/jpeg',
        description: 'Test',
        width: 100,
        height: 100,
        colorDepth: 24,
        numberOfColors: 0,
        imageData: Uint8List.fromList([0xFF, 0xD8]),
      );
      expect(parser.isValidPictureBlock(invalidTypeBlock), isFalse);
    });

    test('extracts metadata without loading image data', () {
      const parser = FlacPictureParser();

      final pictureBlockBytes = _createValidPictureBlock(
        pictureType: 0x05, // Leaflet
        mimeType: 'image/png',
        description: 'Liner Notes',
        width: 800,
        height: 600,
        colorDepth: 32,
        numberOfColors: 0,
        imageData: Uint8List(5000), // Large image data
      );

      final metadata = parser.extractMetadata(pictureBlockBytes);

      expect(metadata.artworkType, equals(ArtworkType.leaflet));
      expect(metadata.mimeType, equals('image/png'));
      expect(metadata.description, equals('Liner Notes'));
      expect(metadata.width, equals(800));
      expect(metadata.height, equals(600));
      expect(metadata.colorDepth, equals(32));
      expect(metadata.numberOfColors, equals(0));
      expect(metadata.dataLength, equals(5000));
      expect(metadata.isIndexedColor, isFalse);
      expect(metadata.isPossiblyVector, isFalse);
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
