import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v24Codec', () {
    late Id3v24Codec codec;

    setUp(() {
      codec = const Id3v24Codec();
    });

    group('instantiation', () {
      test('should create codec instance successfully', () {
        expect(codec, isA<Id3v24Codec>());
        expect(codec, isA<TagCodec>());
      });

      test('should be const constructible', () {
        const codec1 = Id3v24Codec();
        const codec2 = Id3v24Codec();

        // Const constructors should create identical instances
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
      });

      test('should be stateless and reusable', () {
        final codec1 = const Id3v24Codec();
        final codec2 = const Id3v24Codec();

        // Multiple instances should have identical properties
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
        expect(codec1.capability.containerKind, equals(codec2.capability.containerKind));
        expect(codec1.capability.containerVersion, equals(codec2.capability.containerVersion));
      });
    });

    group('properties', () {
      test('should have correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.id3v2));
      });

      test('should have correct container version', () {
        expect(codec.containerVersion, equals('2.4'));
      });

      test('should have valid capability definition', () {
        final capability = codec.capability;

        expect(capability, isA<TagCapability>());
        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.4'));
      });

      test('should maintain consistency between codec and capability properties', () {
        final capability = codec.capability;

        // Container kind and version should match between codec and capability
        expect(capability.containerKind, equals(codec.containerKind));
        expect(capability.containerVersion, equals(codec.containerVersion));
      });
    });

    group('capability integration', () {
      test('should support all expected ID3v2.4 fields', () {
        final capability = codec.capability;

        // Test core text fields
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.album), isTrue);
        expect(capability.supports(TagKey.albumArtist), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.comment), isTrue);
        expect(capability.supports(TagKey.grouping), isTrue);
        expect(capability.supports(TagKey.composer), isTrue);
        expect(capability.supports(TagKey.encoder), isTrue);
        expect(capability.supports(TagKey.isrc), isTrue);
        expect(capability.supports(TagKey.musicalKey), isTrue);
        expect(capability.supports(TagKey.lyrics), isTrue);

        // Test numeric fields
        expect(capability.supports(TagKey.trackNumber), isTrue);
        expect(capability.supports(TagKey.discNumber), isTrue);
        expect(capability.supports(TagKey.year), isTrue);
        expect(capability.supports(TagKey.bpm), isTrue);
        expect(capability.supports(TagKey.rating), isTrue);

        // Test date field (ID3v2.4 specific)
        expect(capability.supports(TagKey.dateRecorded), isTrue);

        // Test multimedia fields
        expect(capability.supports(TagKey.artwork), isTrue);

        // Test custom fields
        expect(capability.supports(TagKey.custom), isTrue);
      });

      test('should provide correct semantic constraints for text fields', () {
        final capability = codec.capability;

        // Text fields should have no length limits (unlike ID3v1)
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, isNull);
        expect(titleSemantics.multiValued, isFalse);
        expect(titleSemantics.allowedEncodings, isNotNull);
        expect(titleSemantics.allowedEncodings!.contains('UTF-8'), isTrue);

        final artistSemantics = capability.semantics(TagKey.artist);
        expect(artistSemantics.maxTextLength, isNull);
        expect(artistSemantics.multiValued, isFalse);
        expect(artistSemantics.allowedEncodings!.contains('UTF-8'), isTrue);
      });

      test('should provide correct semantic constraints for numeric fields', () {
        final capability = codec.capability;

        // Track number constraints
        final trackSemantics = capability.semantics(TagKey.trackNumber);
        expect(trackSemantics.minValue, equals(1));
        expect(trackSemantics.maxValue, equals(999));
        expect(trackSemantics.multiValued, isFalse);

        // Disc number constraints
        final discSemantics = capability.semantics(TagKey.discNumber);
        expect(discSemantics.minValue, equals(1));
        expect(discSemantics.maxValue, equals(99));
        expect(discSemantics.multiValued, isFalse);

        // Year constraints
        final yearSemantics = capability.semantics(TagKey.year);
        expect(yearSemantics.minValue, equals(1000));
        expect(yearSemantics.maxValue, equals(3000));
        expect(yearSemantics.multiValued, isFalse);

        // BPM constraints
        final bpmSemantics = capability.semantics(TagKey.bpm);
        expect(bpmSemantics.minValue, equals(1));
        expect(bpmSemantics.maxValue, equals(999));
        expect(bpmSemantics.multiValued, isFalse);

        // Rating constraints (unified 0-100 scale)
        final ratingSemantics = capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(100));
        expect(ratingSemantics.multiValued, isFalse);
      });

      test('should provide correct semantic constraints for multi-valued fields', () {
        final capability = codec.capability;

        // Genre should support multiple values in ID3v2.4
        final genreSemantics = capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isTrue);
        expect(genreSemantics.allowedEncodings!.contains('UTF-8'), isTrue);

        // Artwork should support multiple values
        final artworkSemantics = capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, isTrue);

        // Custom fields should support multiple values
        final customSemantics = capability.semantics(TagKey.custom);
        expect(customSemantics.multiValued, isTrue);
        expect(customSemantics.allowedEncodings!.contains('UTF-8'), isTrue);
      });

      test('should support UTF-8 encoding (ID3v2.4 enhancement)', () {
        final capability = codec.capability;

        // All text fields should support UTF-8 in ID3v2.4
        final textFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          TagKey.genre,
          TagKey.comment,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.musicalKey,
          TagKey.lyrics,
          TagKey.dateRecorded,
          TagKey.custom,
        ];

        for (final field in textFields) {
          final semantics = capability.semantics(field);
          expect(
            semantics.allowedEncodings?.contains('UTF-8'),
            isTrue,
            reason: 'Field $field should support UTF-8 encoding in ID3v2.4',
          );
        }
      });
    });

    group('interface compliance', () {
      test('should implement all required TagCodec methods', () {
        // Verify that all abstract methods are implemented
        expect(codec.containerKind, isA<ContainerKind>());
        expect(codec.containerVersion, isA<String>());
        expect(codec.capability, isA<TagCapability>());

        // Methods should be callable
        expect(codec.readFromContainer(Uint8List(0)), isA<List<MetadataTag>>());
        expect(codec.writeToContainer(tagsToWrite: []), isA<Uint8List>());
      });

      test('should have consistent type signatures', () {
        // Verify method signatures match the interface
        expect(codec.readFromContainer, isA<List<MetadataTag> Function(Uint8List)>());
        expect(
          codec.writeToContainer,
          isA<Uint8List Function({required List<MetadataTag> tagsToWrite, Uint8List? existingContainerBytes})>(),
        );
      });
    });

    group('method stubs', () {
      test('readFromContainer should handle empty input', () {
        final emptyBytes = Uint8List(0);
        final result = codec.readFromContainer(emptyBytes);
        expect(result, isEmpty);
      });

      test('readFromContainer should handle invalid header', () {
        final invalidBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00]);

        expect(
          () => codec.readFromContainer(invalidBytes),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('writeToContainer should create valid ID3v2.4 container', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        // Should return a valid ID3v2.4 container
        expect(result, isA<Uint8List>());
        expect(result.length, greaterThanOrEqualTo(10)); // At least header size
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
        expect(result[3], equals(0x04)); // Version 2.4
      });

      test('writeToContainer should accept existingContainerBytes parameter', () {
        final existingBytes = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tagsToWrite = <MetadataTag>[const TitleTag('Test')];

        final result = codec.writeToContainer(
          tagsToWrite: tagsToWrite,
          existingContainerBytes: existingBytes,
        );

        // Should return a valid container (existingContainerBytes is currently ignored)
        expect(result, isA<Uint8List>());
        expect(result.length, greaterThanOrEqualTo(10));
      });
    });

    group('documentation and structure', () {
      test('should have proper class structure for future implementation', () {
        // Verify the codec has the expected structure for implementation
        expect(codec.containerKind, equals(ContainerKind.id3v2));
        expect(codec.containerVersion, equals('2.4'));

        // Capability should be properly configured for ID3v2.4
        final capability = codec.capability;
        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.4'));

        // Should support the expected set of fields for ID3v2.4
        final supportedFields = capability.semanticsByKey.keys.toSet();
        expect(supportedFields, contains(TagKey.title));
        expect(supportedFields, contains(TagKey.artist));
        expect(supportedFields, contains(TagKey.album));
        expect(supportedFields, contains(TagKey.genre));
        expect(supportedFields, contains(TagKey.dateRecorded)); // ID3v2.4 specific
        expect(supportedFields, contains(TagKey.artwork));
      });

      test('should be ready for implementation in subsequent tasks', () {
        // The codec structure should be complete for tasks 68 and 69
        expect(codec, isA<TagCodec>());
        expect(codec.capability, isNotNull);

        // Methods should exist and be implemented
        expect(codec.readFromContainer(Uint8List(0)), isA<List<MetadataTag>>());
        expect(codec.writeToContainer(tagsToWrite: []), isA<Uint8List>());
      });
    });

    group('readFromContainer implementation', () {
      test('should parse valid ID3v2.4 header with no frames', () {
        final headerBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
        ]);

        final result = codec.readFromContainer(headerBytes);
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

      test('should parse simple text frame (TIT2)', () {
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
      });

      test('should parse genre frame with multiple genres (TCON)', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x21, // Size: 33 bytes (10 frame header + 23 frame data)
          // TCON frame (Genre)
          0x54, 0x43, 0x4F, 0x4E, // "TCON"
          0x00, 0x00, 0x00, 0x17, // Size: 23 bytes (1 encoding + 22 text)
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          // "Rock\0Alternative\0Indie"
          0x52, 0x6F, 0x63, 0x6B, 0x00, // "Rock\0"
          0x41, 0x6C, 0x74, 0x65, 0x72, 0x6E, 0x61, 0x74, 0x69, 0x76, 0x65, 0x00, // "Alternative\0"
          0x49, 0x6E, 0x64, 0x69, 0x65, // "Indie"
        ]);

        final result = codec.readFromContainer(containerBytes);
        expect(result, hasLength(1));
        expect(result[0], isA<GenreTag>());
        final genreTag = result[0] as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('should parse track number frame (TRCK)', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x0F, // Size: 15 bytes
          // TRCK frame (Track Number)
          0x54, 0x52, 0x43, 0x4B, // "TRCK"
          0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          0x35, 0x2F, 0x31, 0x32, // "5/12"
        ]);

        final result = codec.readFromContainer(containerBytes);
        expect(result, hasLength(1));
        expect(result[0], isA<TrackNumberTag>());
        expect((result[0] as TrackNumberTag).value, equals(5));
      });

      test('should parse rating frame (POPM)', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x14, // Size: 20 bytes (10 frame header + 10 frame data)
          // POPM frame (Rating)
          0x50, 0x4F, 0x50, 0x4D, // "POPM"
          0x00, 0x00, 0x00, 0x0A, // Size: 10 bytes (5 email + 1 rating + 4 counter)
          0x00, 0x00, // No flags
          0x75, 0x73, 0x65, 0x72, 0x00, // "user\0"
          0xC8, // Rating: 200 (0-255 scale)
          0x00, 0x00, 0x00, 0x2A, // Counter: 42
        ]);

        final result = codec.readFromContainer(containerBytes);
        expect(result, hasLength(1));
        expect(result[0], isA<RatingTag>());
        // Rating 200 on 0-255 scale should convert to ~78 on 0-100 scale
        final expectedRating = ((200 - 1) * 100 / 254).round();
        expect((result[0] as RatingTag).value, equals(expectedRating));
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

      test('should handle corrupted frames gracefully', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x19, // Size: 25 bytes (10 corrupted header + 15 valid frame)
          // Corrupted frame (invalid size)
          0x54, 0x49, 0x54, 0x32, // "TIT2"
          0x7F, 0x7F, 0x7F, 0x7F, // Invalid size (too large)
          0x00, 0x00, // No flags
          // Valid frame after corruption
          0x54, 0x50, 0x45, 0x31, // "TPE1"
          0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        final result = codec.readFromContainer(containerBytes);
        // Should recover and parse the valid TPE1 frame
        expect(result, hasLength(1));
        expect(result[0], isA<ArtistTag>());
        expect((result[0] as ArtistTag).value, equals('Test'));
      });

      test('should handle padding at end of tag', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x14, // Size: 20 bytes
          // TIT2 frame
          0x54, 0x49, 0x54, 0x32, // "TIT2"
          0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          0x54, 0x65, 0x73, 0x74, // "Test"
          // Padding (null bytes)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);

        final result = codec.readFromContainer(containerBytes);
        expect(result, hasLength(1));
        expect(result[0], isA<TitleTag>());
        expect((result[0] as TitleTag).value, equals('Test'));
      });

      test('should parse multiple frames', () {
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x20, // Size: 32 bytes (15 + 17)
          // TIT2 frame (Title)
          0x54, 0x49, 0x54, 0x32, // "TIT2"
          0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          0x54, 0x65, 0x73, 0x74, // "Test"
          // TPE1 frame (Artist)
          0x54, 0x50, 0x45, 0x31, // "TPE1"
          0x00, 0x00, 0x00, 0x07, // Size: 7 bytes
          0x00, 0x00, // No flags
          0x03, // UTF-8 encoding
          0x41, 0x72, 0x74, 0x69, 0x73, 0x74, // "Artist"
        ]);

        final result = codec.readFromContainer(containerBytes);
        expect(result, hasLength(2));

        // Check title
        final titleTag = result.firstWhere((tag) => tag is TitleTag) as TitleTag;
        expect(titleTag.value, equals('Test'));

        // Check artist
        final artistTag = result.firstWhere((tag) => tag is ArtistTag) as ArtistTag;
        expect(artistTag.value, equals('Artist'));
      });
    });
  });
}
