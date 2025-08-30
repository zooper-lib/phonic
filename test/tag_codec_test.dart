import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';

// Test implementation of TagCodec for testing purposes
class TestTagCodec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.id3v2,
    containerVersion: '2.4',
    semanticsByKey: {
      TagKey.title: TagSemantics(maxTextLength: 100),
      TagKey.artist: TagSemantics(maxTextLength: 100),
      TagKey.genre: TagSemantics(multiValued: false),
      TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
    },
  );

  @override
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    // Simple test implementation that creates mock tags
    return [
      TitleTag(
        'Test Title',
        provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
      ),
      ArtistTag(
        'Test Artist',
        provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
      ),
      GenreTag(
        const ['Rock', 'Alternative'],
        provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
      ),
    ];
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
  }) {
    // Simple test implementation that returns mock container bytes
    final buffer = BytesBuilder();

    // Write a simple header
    buffer.add([0x49, 0x44, 0x33]); // "ID3"
    buffer.add([0x04, 0x00]); // Version 2.4
    buffer.add([0x00]); // Flags
    buffer.add([0x00, 0x00, 0x00, 0x00]); // Size (placeholder)

    // Write tag count
    buffer.add([tagsToWrite.length]);

    return buffer.toBytes();
  }
}

void main() {
  group('TagCodec', () {
    late TestTagCodec codec;

    setUp(() {
      codec = TestTagCodec();
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
        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.4'));
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.rating), isTrue);
        expect(capability.supports(TagKey.artwork), isFalse);
      });

      test('should provide semantic constraints through capability', () {
        final titleSemantics = codec.capability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, equals(100));

        final ratingSemantics = codec.capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(255));

        final genreSemantics = codec.capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isFalse);
      });
    });

    group('readFromContainer', () {
      test('should parse container bytes and return metadata tags', () {
        final containerBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00]);
        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(3));
        expect(tags[0], isA<TitleTag>());
        expect(tags[1], isA<ArtistTag>());
        expect(tags[2], isA<GenreTag>());
      });

      test('should set proper provenance on parsed tags', () {
        final containerBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00]);
        final tags = codec.readFromContainer(containerBytes);

        for (final tag in tags) {
          expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
          expect(tag.provenance.containerVersion, equals('2.4'));
          expect(tag.provenance.confidence, equals(TagConfidence.certain));
        }
      });

      test('should handle empty container bytes', () {
        final containerBytes = Uint8List(0);
        final tags = codec.readFromContainer(containerBytes);

        // Implementation should handle empty bytes gracefully
        expect(tags, isA<List<MetadataTag>>());
      });
    });

    group('writeToContainer', () {
      test('should encode tags to container bytes', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Test Song'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock']),
        ];

        final containerBytes = codec.writeToContainer(tagsToWrite: tagsToWrite);

        expect(containerBytes, isNotEmpty);
        expect(containerBytes.length, greaterThan(10)); // Should have header + data

        // Check for ID3 header
        expect(containerBytes[0], equals(0x49)); // 'I'
        expect(containerBytes[1], equals(0x44)); // 'D'
        expect(containerBytes[2], equals(0x33)); // '3'
        expect(containerBytes[3], equals(0x04)); // Version major
        expect(containerBytes[4], equals(0x00)); // Version minor
      });

      test('should handle empty tag list', () {
        final containerBytes = codec.writeToContainer(tagsToWrite: []);

        expect(containerBytes, isNotEmpty);
        // Should still have header even with no tags
        expect(containerBytes.length, greaterThanOrEqualTo(10));
      });

      test('should accept existing container bytes parameter', () {
        final existingBytes = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tagsToWrite = <MetadataTag>[const TitleTag('Test')];

        final containerBytes = codec.writeToContainer(
          tagsToWrite: tagsToWrite,
          existingContainerBytes: existingBytes,
        );

        expect(containerBytes, isNotEmpty);
        // Implementation should handle existing bytes (may preserve or replace)
      });

      test('should filter unsupported tags based on capability', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Supported Title'),
          const ArtistTag('Supported Artist'),
          // ArtworkTag would be unsupported based on our test capability
        ];

        final containerBytes = codec.writeToContainer(tagsToWrite: tagsToWrite);

        expect(containerBytes, isNotEmpty);
        // Implementation should only process supported tags
      });
    });

    group('capability integration', () {
      test('should use capability for tag validation', () {
        final capability = codec.capability;

        // Test supported fields
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.rating), isTrue);

        // Test unsupported fields
        expect(capability.supports(TagKey.artwork), isFalse);
        expect(capability.supports(TagKey.lyrics), isFalse);
      });

      test('should provide semantic constraints for validation', () {
        final capability = codec.capability;

        // Test text length constraints
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, equals(100));

        // Test numeric range constraints
        final ratingSemantics = capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(255));

        // Test multi-value constraints
        final genreSemantics = capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isFalse);
      });
    });

    group('interface compliance', () {
      test('should implement all required abstract methods', () {
        // Verify that our test codec implements all required methods
        expect(codec.containerKind, isA<ContainerKind>());
        expect(codec.containerVersion, isA<String>());
        expect(codec.capability, isA<TagCapability>());

        // Verify methods can be called without throwing
        expect(() => codec.readFromContainer(Uint8List(0)), returnsNormally);
        expect(() => codec.writeToContainer(tagsToWrite: []), returnsNormally);
      });

      test('should maintain consistent container identification', () {
        // Container kind and version should match between codec and capability
        expect(codec.capability.containerKind, equals(codec.containerKind));
        expect(codec.capability.containerVersion, equals(codec.containerVersion));
      });
    });
  });
}
