import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/container_rebuilder.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('ContainerRebuilder', () {
    late ContainerRebuilder rebuilder;

    setUp(() {
      rebuilder = const ContainerRebuilder();
    });

    group('Basic Container Rebuilding', () {
      test('should create new container when no existing data provided', () {
        final codec = const Id3v24Codec();
        final tags = [
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final result = rebuilder.rebuildContainer(
          codec: codec,
          tagsToWrite: tags,
          existingContainerBytes: null,
        );

        expect(result, isNotEmpty);
        expect(result.length, greaterThanOrEqualTo(10)); // At least header size

        // Verify ID3v2.4 signature
        expect(result[0], equals(0x49)); // 'I'
        expect(result[1], equals(0x44)); // 'D'
        expect(result[2], equals(0x33)); // '3'
        expect(result[3], equals(0x04)); // Version 2.4
        expect(result[4], equals(0x00)); // Revision
      });

      test('should create new container when existing data is empty', () {
        final codec = const Id3v24Codec();
        final tags = [const TitleTag('Test Title')];

        final result = rebuilder.rebuildContainer(
          codec: codec,
          tagsToWrite: tags,
          existingContainerBytes: Uint8List(0),
        );

        expect(result, isNotEmpty);
        expect(result[0], equals(0x49)); // 'I'
        expect(result[1], equals(0x44)); // 'D'
        expect(result[2], equals(0x33)); // '3'
      });

      test('should handle corrupted existing container gracefully', () {
        final codec = const Id3v24Codec();
        final tags = [const TitleTag('Test Title')];

        // Create corrupted container data
        final corruptedContainer = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, // Valid header start
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid size
          0x00, 0x00, 0x00, 0x00, // Corrupted data
        ]);

        final result = rebuilder.rebuildContainer(
          codec: codec,
          tagsToWrite: tags,
          existingContainerBytes: corruptedContainer,
        );

        // Should fall back to creating new container
        expect(result, isNotEmpty);
        expect(result[0], equals(0x49)); // 'I'
        expect(result[1], equals(0x44)); // 'D'
        expect(result[2], equals(0x33)); // '3'
      });

      test('should handle empty tags list', () {
        final codec = const Id3v24Codec();

        final result = rebuilder.rebuildContainer(
          codec: codec,
          tagsToWrite: [],
          existingContainerBytes: null,
        );

        expect(result, isNotEmpty);
        // Should return empty container
        expect(result.length, equals(10)); // Just header
      });
    });

    group('Error Handling', () {
      test('should handle unsupported container kind gracefully', () {
        // Create a mock codec with unsupported container kind
        final mockCodec = _MockCodec();
        final tags = [const TitleTag('Test')];

        final result = rebuilder.rebuildContainer(
          codec: mockCodec,
          tagsToWrite: tags,
          existingContainerBytes: null,
        );

        // Should fall back to codec's writeToContainer
        expect(result, equals(mockCodec.expectedOutput));
      });

      test('should handle codec exceptions gracefully', () {
        final codec = _ThrowingCodec();
        final tags = [const TitleTag('Test')];

        expect(
          () => rebuilder.rebuildContainer(
            codec: codec,
            tagsToWrite: tags,
            existingContainerBytes: null,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

// Mock classes for testing

class _MockCodec implements TagCodec {
  final Uint8List expectedOutput = Uint8List.fromList([1, 2, 3, 4]);

  @override
  ContainerKind get containerKind => ContainerKind.none;

  @override
  String get containerVersion => '';

  @override
  TagCapability get capability => throw UnimplementedError();

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    return [];
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    return expectedOutput;
  }
}

class _ThrowingCodec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => throw UnimplementedError();

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    throw Exception('Test exception');
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    throw Exception('Test exception');
  }
}


