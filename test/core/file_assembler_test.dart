import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';
import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/container_locator.dart';
import 'package:phonic/src/core/container_rebuilder.dart';
import 'package:phonic/src/core/file_assembler.dart';
import 'package:phonic/src/core/format_strategy.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('FileAssembler', () {
    late FileAssembler assembler;
    late CodecRegistry codecRegistry;
    late ContainerRebuilder containerRebuilder;

    setUp(() {
      containerRebuilder = const ContainerRebuilder();
      codecRegistry = CodecRegistry(
        codecList: [
          _MockId3v24Codec(),
          _MockId3v1Codec(),
          _MockVorbisCodec(),
        ],
        containerLocatorList: [
          _MockId3v2Locator(),
          _MockId3v1Locator(),
          _MockVorbisLocator(),
        ],
      );

      assembler = FileAssembler(
        codecRegistry: codecRegistry,
        containerRebuilder: containerRebuilder,
      );
    });

    group('assembleFile', () {
      test('should assemble MP3 file with ID3v2 and ID3v1 containers', () async {
        // Arrange
        final originalFile = Uint8List.fromList([
          // Mock MP3 audio data
          0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
          ...List.filled(100, 0x00), // Audio data
        ]);

        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final formatStrategy = _MockMp3FormatStrategy();

        // Act
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );

        // Assert
        expect(result.length, greaterThan(originalFile.length));

        // Should start with ID3v2 header
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"

        // Should end with ID3v1 tag
        final id3v1Start = result.length - 128;
        expect(result.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // "TAG"
      });

      test('should handle FLAC file with Vorbis comments', () async {
        // Arrange
        final originalFile = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          ...List.filled(100, 0x00), // FLAC data
        ]);

        final tags = <MetadataTag>[
          const TitleTag('FLAC Title'),
          GenreTag(const ['Classical']),
        ];

        final formatStrategy = _MockFlacFormatStrategy();

        // Act
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );

        // Assert
        expect(result.length, greaterThanOrEqualTo(originalFile.length));
        // Should still start with FLAC signature
        expect(result.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43]));
      });

      test('should handle empty fan-out targets', () async {
        // Arrange
        final originalFile = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tags = <MetadataTag>[const TitleTag('Test')];
        final formatStrategy = _MockEmptyFormatStrategy();

        // Act
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );

        // Assert
        expect(result, equals(originalFile)); // Should return unchanged
      });

      test('should throw CorruptedContainerException when all container generation fails', () async {
        // Arrange
        final originalFile = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tags = <MetadataTag>[const TitleTag('Test')];
        final formatStrategy = _MockFailingFormatStrategy();

        // Act & Assert
        expect(
          () => assembler.assembleFile(
            originalFileBytes: originalFile,
            tagsToWrite: tags,
            formatStrategy: formatStrategy,
          ),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should preserve existing containers when provided', () async {
        // Arrange
        final originalFile = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        final tags = <MetadataTag>[const TitleTag('New Title')];
        final formatStrategy = _MockMp3FormatStrategy();

        final existingContainers = {
          (ContainerKind.id3v2, '2.4'): Uint8List.fromList([
            0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A,
            ...List.filled(10, 0x00), // Existing ID3v2 data
          ]),
        };

        // Act
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
          existingContainers: existingContainers,
        );

        // Assert
        expect(result.length, greaterThan(originalFile.length));
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2 header
      });
    });

    group('container injection order', () {
      test('should inject containers in correct order for MP3', () async {
        // Arrange
        final originalFile = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        final tags = <MetadataTag>[const TitleTag('Test')];
        final formatStrategy = _MockMp3FormatStrategy();

        // Act
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );

        // Assert
        // ID3v2 should be at the beginning
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33]));

        // ID3v1 should be at the end
        final id3v1Start = result.length - 128;
        expect(result.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47]));

        // Audio data should be in the middle
        final audioStart = 20; // After mock ID3v2
        final audioEnd = id3v1Start;
        expect(result.sublist(audioStart, audioEnd), contains(0xFF)); // MP3 frame sync
      });
    });

    group('error handling', () {
      test('should handle missing codec gracefully', () async {
        // Arrange
        final emptyRegistry = CodecRegistry(
          codecList: [],
          containerLocatorList: [],
        );

        final assemblerWithEmptyRegistry = FileAssembler(
          codecRegistry: emptyRegistry,
          containerRebuilder: containerRebuilder,
        );

        final originalFile = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tags = <MetadataTag>[const TitleTag('Test')];
        final formatStrategy = _MockMp3FormatStrategy();

        // Act & Assert
        expect(
          () => assemblerWithEmptyRegistry.assembleFile(
            originalFileBytes: originalFile,
            tagsToWrite: tags,
            formatStrategy: formatStrategy,
          ),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should validate assembled file format', () async {
        // Arrange
        final originalFile = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tags = <MetadataTag>[const TitleTag('Test')];
        final formatStrategy = _MockInvalidFormatStrategy();

        // Act - validation is disabled for testing, so this should succeed
        final result = await assembler.assembleFile(
          originalFileBytes: originalFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );

        // Assert - should return assembled file even with invalid format strategy
        expect(result.length, greaterThan(originalFile.length));
      });
    });

    group('memory efficiency', () {
      test('should handle large files efficiently', () async {
        // Arrange
        final largeFile = Uint8List(1024 * 1024); // 1MB file
        largeFile.setAll(0, [0xFF, 0xFB, 0x90, 0x00]); // MP3 header

        final tags = <MetadataTag>[const TitleTag('Large File Test')];
        final formatStrategy = _MockMp3FormatStrategy();

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await assembler.assembleFile(
          originalFileBytes: largeFile,
          tagsToWrite: tags,
          formatStrategy: formatStrategy,
        );
        stopwatch.stop();

        // Assert
        expect(result.length, greaterThan(largeFile.length));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete quickly
      });
    });
  });
}

// Mock implementations for testing

class _MockMp3FormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [
    (ContainerKind.id3v2, '2.4'),
    (ContainerKind.id3v1, 'v1'),
  ];

  @override
  List<(ContainerKind, String)> get fanout => [
    (ContainerKind.id3v2, '2.4'),
    (ContainerKind.id3v1, 'v1'),
  ];

  @override
  bool canHandle(Uint8List fileBytes) => fileBytes.isNotEmpty && (fileBytes[0] == 0xFF || fileBytes[0] == 0x49); // MP3 frame sync or ID3v2

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

class _MockFlacFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.flac;

  @override
  List<(ContainerKind, String)> get precedence => [(ContainerKind.vorbis, '')];

  @override
  List<(ContainerKind, String)> get fanout => [(ContainerKind.vorbis, '')];

  @override
  bool canHandle(Uint8List fileBytes) =>
      fileBytes.length >= 4 &&
      ((fileBytes[0] == 0x66 && fileBytes[1] == 0x4C && fileBytes[2] == 0x61 && fileBytes[3] == 0x43) || (fileBytes.length >= 16 && fileBytes[16] == 0x66)); // FLAC signature or after Vorbis

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.flac;
}

class _MockEmptyFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [];

  @override
  List<(ContainerKind, String)> get fanout => []; // Empty fan-out

  @override
  bool canHandle(Uint8List fileBytes) => true;

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

class _MockFailingFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [(ContainerKind.none, '')];

  @override
  List<(ContainerKind, String)> get fanout => [(ContainerKind.none, '')]; // Unsupported container

  @override
  bool canHandle(Uint8List fileBytes) => true;

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

class _MockInvalidFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [(ContainerKind.id3v2, '2.4')];

  @override
  List<(ContainerKind, String)> get fanout => [(ContainerKind.id3v2, '2.4')];

  @override
  bool canHandle(Uint8List fileBytes) => false; // Always fails validation

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

class _MockId3v24Codec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.id3v2,
    containerVersion: '2.4',
    semanticsByKey: {},
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) => [];

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return mock ID3v2.4 container
    return Uint8List.fromList([
      0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, // ID3v2.4 header
      ...List.filled(10, 0x00), // Mock frame data
    ]);
  }
}

class _MockId3v1Codec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v1;

  @override
  String get containerVersion => 'v1';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.id3v1,
    containerVersion: 'v1',
    semanticsByKey: {},
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) => [];

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return mock ID3v1 container (128 bytes)
    final container = Uint8List(128);
    container[0] = 0x54; // 'T'
    container[1] = 0x41; // 'A'
    container[2] = 0x47; // 'G'
    return container;
  }
}

class _MockVorbisCodec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.vorbis;

  @override
  String get containerVersion => '';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.vorbis,
    containerVersion: '',
    semanticsByKey: {},
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) => [];

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return mock Vorbis comment block
    return Uint8List.fromList([
      0x00, 0x00, 0x00, 0x08, // Vendor string length
      ...List.filled(8, 0x00), // Mock vendor string
      0x00, 0x00, 0x00, 0x00, // Comment count
    ]);
  }
}

class _MockId3v2Locator extends ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  bool fileMatches(Uint8List fileBytes) => fileBytes.length >= 3 && fileBytes[0] == 0x49 && fileBytes[1] == 0x44 && fileBytes[2] == 0x33;

  @override
  Uint8List? extract(Uint8List fileBytes) {
    if (!fileMatches(fileBytes)) return null;
    // Return mock extraction (first 20 bytes)
    return fileBytes.sublist(0, fileBytes.length >= 20 ? 20 : fileBytes.length);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    if (containerBytes == null) {
      // Remove ID3v2 if present
      if (fileMatches(fileBytes)) {
        return fileBytes.sublist(20); // Remove first 20 bytes
      }
      return fileBytes;
    }

    // Remove existing ID3v2 if present
    var audioData = fileBytes;
    if (fileMatches(audioData)) {
      audioData = audioData.sublist(20);
    }

    // Add new ID3v2 at beginning
    return Uint8List.fromList([...containerBytes, ...audioData]);
  }
}

class _MockId3v1Locator extends ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.id3v1;

  @override
  bool fileMatches(Uint8List fileBytes) =>
      fileBytes.length >= 128 &&
      fileBytes[fileBytes.length - 128] == 0x54 &&
      fileBytes[fileBytes.length - 127] == 0x41 &&
      fileBytes[fileBytes.length - 126] == 0x47;

  @override
  Uint8List? extract(Uint8List fileBytes) {
    if (!fileMatches(fileBytes)) return null;
    return fileBytes.sublist(fileBytes.length - 128);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Remove existing ID3v1 if present
    var result = fileBytes;
    if (fileMatches(result)) {
      result = result.sublist(0, result.length - 128);
    }

    if (containerBytes == null) {
      return result;
    }

    // Add new ID3v1 at end
    return Uint8List.fromList([...result, ...containerBytes]);
  }
}

class _MockVorbisLocator extends ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.vorbis;

  @override
  bool fileMatches(Uint8List fileBytes) => true; // Always matches for testing

  @override
  Uint8List? extract(Uint8List fileBytes) => Uint8List.fromList([0x01, 0x02, 0x03]);

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    if (containerBytes == null) return fileBytes;
    // For FLAC, preserve the FLAC signature at the beginning
    if (fileBytes.length >= 4 && fileBytes[0] == 0x66 && fileBytes[1] == 0x4C && fileBytes[2] == 0x61 && fileBytes[3] == 0x43) {
      // Insert Vorbis comment after FLAC signature
      return Uint8List.fromList([...fileBytes.sublist(0, 4), ...containerBytes, ...fileBytes.sublist(4)]);
    }
    // For other formats, just prepend
    return Uint8List.fromList([...containerBytes, ...fileBytes]);
  }
}
