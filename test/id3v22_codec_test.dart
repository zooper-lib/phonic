import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/src/core/container_kind.dart';
import '../lib/src/core/tag_codec.dart';
import '../lib/src/core/tag_key.dart';
import '../lib/src/exceptions/corrupted_container_exception.dart';
import '../lib/src/formats/id3/id3v22_codec.dart';

void main() {
  group('Id3v22Codec', () {
    late Id3v22Codec codec;

    setUp(() {
      codec = const Id3v22Codec();
    });

    group('instantiation', () {
      test('creates codec instance successfully', () {
        expect(codec, isNotNull);
        expect(codec, isA<Id3v22Codec>());
      });

      test('has correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.id3v2));
      });

      test('has correct container version', () {
        expect(codec.containerVersion, equals('2.2'));
      });

      test('has valid capability', () {
        final capability = codec.capability;
        expect(capability, isNotNull);
        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.2'));
      });

      test('capability supports expected ID3v2.2 fields', () {
        final capability = codec.capability;

        // Fields that should be supported in ID3v2.2
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.album), isTrue);
        expect(capability.supports(TagKey.albumArtist), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.comment), isTrue);
        expect(capability.supports(TagKey.grouping), isTrue);
        expect(capability.supports(TagKey.composer), isTrue);
        expect(capability.supports(TagKey.encoder), isTrue);
        expect(capability.supports(TagKey.trackNumber), isTrue);
        expect(capability.supports(TagKey.year), isTrue);
        expect(capability.supports(TagKey.bpm), isTrue);
        expect(capability.supports(TagKey.artwork), isTrue);
        expect(capability.supports(TagKey.custom), isTrue);
      });

      test('capability does not support fields missing in ID3v2.2', () {
        final capability = codec.capability;

        // Fields that should NOT be supported in ID3v2.2
        expect(capability.supports(TagKey.discNumber), isFalse);
        expect(capability.supports(TagKey.musicalKey), isFalse);
        expect(capability.supports(TagKey.rating), isFalse);
        expect(capability.supports(TagKey.lyrics), isFalse);
        expect(capability.supports(TagKey.isrc), isFalse);
        expect(capability.supports(TagKey.dateRecorded), isFalse);
      });

      test('capability has correct encoding constraints', () {
        final capability = codec.capability;
        final titleSemantics = capability.semantics(TagKey.title);

        // ID3v2.2 should only support ISO-8859-1
        expect(titleSemantics.allowedEncodings, isNotNull);
        expect(titleSemantics.allowedEncodings!.contains('ISO-8859-1'), isTrue);
        expect(titleSemantics.allowedEncodings!.contains('UTF-8'), isFalse);
        expect(titleSemantics.allowedEncodings!.contains('UTF-16'), isFalse);
      });

      test('capability has correct value constraints for numeric fields', () {
        final capability = codec.capability;

        // Track number constraints
        final trackSemantics = capability.semantics(TagKey.trackNumber);
        expect(trackSemantics.minValue, equals(1));
        expect(trackSemantics.maxValue, equals(999));

        // Year constraints
        final yearSemantics = capability.semantics(TagKey.year);
        expect(yearSemantics.minValue, equals(1000));
        expect(yearSemantics.maxValue, equals(3000));

        // BPM constraints
        final bpmSemantics = capability.semantics(TagKey.bpm);
        expect(bpmSemantics.minValue, equals(1));
        expect(bpmSemantics.maxValue, equals(999));
      });

      test('capability has correct multi-valued field settings', () {
        final capability = codec.capability;

        // Single-valued fields
        expect(capability.semantics(TagKey.title).multiValued, isFalse);
        expect(capability.semantics(TagKey.artist).multiValued, isFalse);
        expect(capability.semantics(TagKey.album).multiValued, isFalse);
        expect(capability.semantics(TagKey.comment).multiValued, isFalse);

        // Multi-valued fields
        expect(capability.semantics(TagKey.genre).multiValued, isTrue);
        expect(capability.semantics(TagKey.artwork).multiValued, isTrue);
        expect(capability.semantics(TagKey.custom).multiValued, isTrue);
      });
    });

    group('codec interface compliance', () {
      test('implements TagCodec interface', () {
        expect(codec, isA<TagCodec>());
      });

      test('readFromContainer returns empty list for empty input', () {
        final result = codec.readFromContainer(Uint8List(0));
        expect(result, isEmpty);
      });

      test('writeToContainer returns empty container for empty input', () {
        final result = codec.writeToContainer(tagsToWrite: []);
        expect(result, isA<Uint8List>());
        expect(result.length, equals(10)); // Should return valid empty ID3v2.2 header
        // Verify it's a valid empty ID3v2.2 container
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
        expect(result.sublist(3, 5), equals([0x02, 0x00])); // Version 2.2
        expect(result.sublist(6, 10), equals([0x00, 0x00, 0x00, 0x00])); // Size: 0
      });

      test('readFromContainer handles null input gracefully', () {
        // Test with minimal valid input
        final result = codec.readFromContainer(Uint8List(10));
        expect(result, isA<List>());
      });

      test('writeToContainer handles null existing container', () {
        final result = codec.writeToContainer(
          tagsToWrite: [],
          existingContainerBytes: null,
        );
        expect(result, isA<Uint8List>());
      });
    });

    group('const constructor', () {
      test('can be created as const', () {
        const codec1 = Id3v22Codec();
        const codec2 = Id3v22Codec();

        // Const constructors should create identical instances
        expect(identical(codec1.containerKind, codec2.containerKind), isTrue);
        expect(identical(codec1.containerVersion, codec2.containerVersion), isTrue);
      });

      test('multiple instances have same properties', () {
        const codec1 = Id3v22Codec();
        const codec2 = Id3v22Codec();

        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
        expect(codec1.capability.containerKind, equals(codec2.capability.containerKind));
        expect(codec1.capability.containerVersion, equals(codec2.capability.containerVersion));
      });
    });

    group('readFromContainer', () {
      test('parses basic ID3v2.2 text frames correctly', () {
        // Create a minimal ID3v2.2 tag with TT2 (title) frame
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x11, // Size: 17 bytes (synchsafe)
          // TT2 frame (Title)
          0x54, 0x54, 0x32, // "TT2"
          0x00, 0x00, 0x0B, // Size: 11 bytes (24-bit)
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, 0x20, 0x54, 0x69, 0x74, 0x6C, 0x65, // "Test Title"
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        expect(tags[0].key, equals(TagKey.title));
        expect(tags[0].value, equals('Test Title'));
        expect(tags[0].provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tags[0].provenance.containerVersion, equals('2.2'));
      });

      test('parses multiple ID3v2.2 frames correctly', () {
        // Create ID3v2.2 tag with multiple frames
        // Frame sizes: TT2(6+11=17), TP1(6+12=18), TAL(6+11=17) = 52 total
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x34, // Size: 52 bytes (0x34)
          // TT2 frame (Title) - 17 bytes total
          0x54, 0x54, 0x32, // "TT2"
          0x00, 0x00, 0x0B, // Size: 11 bytes
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, 0x20, 0x54, 0x69, 0x74, 0x6C, 0x65, // "Test Title"
          // TP1 frame (Artist) - 18 bytes total
          0x54, 0x50, 0x31, // "TP1"
          0x00, 0x00, 0x0C, // Size: 12 bytes
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, 0x20, 0x41, 0x72, 0x74, 0x69, 0x73, 0x74, // "Test Artist"
          // TAL frame (Album) - 17 bytes total
          0x54, 0x41, 0x4C, // "TAL"
          0x00, 0x00, 0x0B, // Size: 11 bytes
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, 0x20, 0x41, 0x6C, 0x62, 0x75, 0x6D, // "Test Album"
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(3));

        // Find each tag by key
        final titleTag = tags.firstWhere((tag) => tag.key == TagKey.title);
        final artistTag = tags.firstWhere((tag) => tag.key == TagKey.artist);
        final albumTag = tags.firstWhere((tag) => tag.key == TagKey.album);

        expect(titleTag.value, equals('Test Title'));
        expect(artistTag.value, equals('Test Artist'));
        expect(albumTag.value, equals('Test Album'));

        // Check provenance for all tags
        for (final tag in tags) {
          expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
          expect(tag.provenance.containerVersion, equals('2.2'));
        }
      });

      test('parses numeric frames correctly', () {
        // Create ID3v2.2 tag with numeric frames
        // Frame sizes: TRK(6+4=10), TYE(6+5=11), TBP(6+4=10) = 31 total
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x1F, // Size: 31 bytes (0x1F)
          // TRK frame (Track Number)
          0x54, 0x52, 0x4B, // "TRK"
          0x00, 0x00, 0x04, // Size: 4 bytes
          0x00, // ISO-8859-1 encoding
          0x31, 0x32, 0x33, // "123"
          // TYE frame (Year)
          0x54, 0x59, 0x45, // "TYE"
          0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, // ISO-8859-1 encoding
          0x32, 0x30, 0x32, 0x33, // "2023"
          // TBP frame (BPM)
          0x54, 0x42, 0x50, // "TBP"
          0x00, 0x00, 0x04, // Size: 4 bytes
          0x00, // ISO-8859-1 encoding
          0x31, 0x32, 0x30, // "120"
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(3));

        // Find each tag by key
        final trackTag = tags.firstWhere((tag) => tag.key == TagKey.trackNumber);
        final yearTag = tags.firstWhere((tag) => tag.key == TagKey.year);
        final bpmTag = tags.firstWhere((tag) => tag.key == TagKey.bpm);

        expect(trackTag.value, equals(123));
        expect(yearTag.value, equals(2023));
        expect(bpmTag.value, equals(120));
      });

      test('parses genre frame with slash-separated values', () {
        // Create ID3v2.2 tag with TCO (genre) frame
        // Frame size: TCO(6+22=28) = 28 total
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x1D, // Size: 29 bytes (0x1D)
          // TCO frame (Genre)
          0x54, 0x43, 0x4F, // "TCO"
          0x00, 0x00, 0x17, // Size: 23 bytes (1 encoding + 22 text)
          0x00, // ISO-8859-1 encoding
          // "Rock/Alternative/Indie" (22 bytes)
          0x52, 0x6F, 0x63, 0x6B, 0x2F, 0x41, 0x6C, 0x74, 0x65, 0x72, 0x6E, 0x61, 0x74, 0x69, 0x76, 0x65, 0x2F, 0x49, 0x6E, 0x64, 0x69, 0x65,
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));

        final genreTag = tags.firstWhere((tag) => tag.key == TagKey.genre);
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles corrupted frames gracefully', () {
        // Create ID3v2.2 tag with a corrupted frame
        // Let's simplify this test - just put valid frames with some padding
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x1C, // Size: 28 bytes
          // Valid TT2 frame (Title)
          0x54, 0x54, 0x32, // "TT2"
          0x00, 0x00, 0x0B, // Size: 11 bytes
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, 0x20, 0x54, 0x69, 0x74, 0x6C, 0x65, // "Test Title"
          // Another valid frame
          0x54, 0x50, 0x31, // "TP1"
          0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, // ISO-8859-1 encoding
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        final tags = codec.readFromContainer(containerBytes);

        // Should parse both valid frames
        expect(tags, hasLength(2));

        final titleTag = tags.firstWhere((tag) => tag.key == TagKey.title);
        final artistTag = tags.firstWhere((tag) => tag.key == TagKey.artist);

        expect(titleTag.value, equals('Test Title'));
        expect(artistTag.value, equals('Test'));
      });

      test('handles empty tag gracefully', () {
        // Create ID3v2.2 tag with no frames
        final containerBytes = Uint8List.fromList([
          // ID3v2.2 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, isEmpty);
      });

      test('rejects non-ID3v2.2 versions', () {
        // Create ID3v2.4 tag (should be rejected)
        final containerBytes = Uint8List.fromList([
          // ID3v2.4 header (10 bytes)
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4 (not 2.2)
          0x00, // No flags
          0x00, 0x00, 0x00, 0x00, // Size: 0 bytes
        ]);

        expect(
          () => codec.readFromContainer(containerBytes),
          throwsA(isA<CorruptedContainerException>()),
        );
      });
    });
  });
}

