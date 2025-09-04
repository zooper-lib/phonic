import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v24Codec Integration Tests', () {
    late Id3v24Codec codec;

    setUp(() {
      codec = const Id3v24Codec();
    });

    test('should parse basic ID3v2.4 container with TIT2 frame', () {
      // Create a minimal valid ID3v2.4 container with a TIT2 (title) frame
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x0F, // Size: 15 bytes
        // TIT2 frame (Title)
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
        0x00, 0x00, // No flags
        0x03, // UTF-8 encoding
        0x54, 0x65, 0x73, 0x74, // "Test"
      ]);

      final result = codec.readFromContainer(containerBytes);

      expect(result, hasLength(1));
      expect(result[0], isA<TitleTag>());
      expect((result[0] as TitleTag).value, equals('Test'));
      expect(result[0].provenance.containerKind, equals(ContainerKind.id3v2));
      expect(result[0].provenance.containerVersion, equals('2.4'));
      expect(result[0].provenance.confidence, equals(TagConfidence.certain));
    });

    test('should handle empty container', () {
      final emptyBytes = Uint8List(0);
      final result = codec.readFromContainer(emptyBytes);
      expect(result, isEmpty);
    });

    test('should reject non-ID3v2.4 versions', () {
      final id3v23Bytes = Uint8List.fromList([
        0x49, 0x44, 0x33, // "ID3"
        0x03, 0x00, // Version 2.3 (not 2.4)
        0x00, // No flags
        0x00, 0x00, 0x00, 0x00, // Size: 0 bytes
      ]);

      expect(
        () => codec.readFromContainer(id3v23Bytes),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('should parse TPE1 (artist) frame', () {
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x11, // Size: 17 bytes
        // TPE1 frame (Artist)
        0x54, 0x50, 0x45, 0x31, // "TPE1"
        0x00, 0x00, 0x00, 0x07, // Size: 7 bytes
        0x00, 0x00, // No flags
        0x03, // UTF-8 encoding
        0x41, 0x72, 0x74, 0x69, 0x73, 0x74, // "Artist"
      ]);

      final result = codec.readFromContainer(containerBytes);

      expect(result, hasLength(1));
      expect(result[0], isA<ArtistTag>());
      expect((result[0] as ArtistTag).value, equals('Artist'));
    });

    test('should parse TCON (genre) frame with single genre', () {
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x0F, // Size: 15 bytes
        // TCON frame (Genre)
        0x54, 0x43, 0x4F, 0x4E, // "TCON"
        0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
        0x00, 0x00, // No flags
        0x03, // UTF-8 encoding
        0x52, 0x6F, 0x63, 0x6B, // "Rock"
      ]);

      final result = codec.readFromContainer(containerBytes);

      expect(result, hasLength(1));
      expect(result[0], isA<GenreTag>());
      final genreTag = result[0] as GenreTag;
      expect(genreTag.value, equals(['Rock']));
    });

    test('should parse TRCK (track number) frame', () {
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x0C, // Size: 12 bytes
        // TRCK frame (Track Number)
        0x54, 0x52, 0x43, 0x4B, // "TRCK"
        0x00, 0x00, 0x00, 0x02, // Size: 2 bytes
        0x00, 0x00, // No flags
        0x03, // UTF-8 encoding
        0x35, // "5"
      ]);

      final result = codec.readFromContainer(containerBytes);

      expect(result, hasLength(1));
      expect(result[0], isA<TrackNumberTag>());
      expect((result[0] as TrackNumberTag).value, equals(5));
    });

    test('should skip unknown frames', () {
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x0A, // Size: 10 bytes
        // Unknown frame
        0x58, 0x58, 0x58, 0x58, // "XXXX"
        0x00, 0x00, 0x00, 0x00, // Size: 0 bytes
        0x00, 0x00, // No flags
      ]);

      final result = codec.readFromContainer(containerBytes);
      expect(result, isEmpty);
    });

    test('should handle container with no frames', () {
      final containerBytes = Uint8List.fromList([
        // ID3v2.4 header
        0x49, 0x44, 0x33, // "ID3"
        0x04, 0x00, // Version 2.4
        0x00, // No flags
        0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
      ]);

      final result = codec.readFromContainer(containerBytes);
      expect(result, isEmpty);
    });
  });
}
