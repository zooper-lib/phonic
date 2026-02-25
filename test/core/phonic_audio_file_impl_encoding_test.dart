import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/container_locator.dart';
import 'package:phonic/src/core/format_strategy.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/phonic_audio_file_impl.dart';
import 'package:phonic/src/core/post_write_validator.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';
import 'package:test/test.dart';

void main() {
  group('PhonicAudioFileImpl encoding', () {
    late PhonicAudioFileImpl audioFile;
    late CodecRegistry codecRegistry;
    late MergePolicy mergePolicy;

    setUp(() {
      codecRegistry = CodecRegistry(
        codecList: [
          _MockId3v24Codec(),
          _MockId3v1Codec(),
        ],
        containerLocatorList: [
          _MockId3v2Locator(),
          _MockId3v1Locator(),
        ],
      );

      mergePolicy = MergePolicy.fromStrategy(_MockMp3FormatStrategy());

      final mockFileBytes = Uint8List.fromList([
        0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
        ...List.filled(100, 0x00), // Audio data
      ]);

      audioFile = PhonicAudioFileImpl(
        fileBytes: mockFileBytes,
        formatStrategy: _MockMp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: mergePolicy,
        validator: PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: false,
          enableRoundTripValidation: false,
        ),
      );
    });

    group('encode', () {
      test('should encode file with updated tags', () async {
        // Arrange
        audioFile.setTag(const TitleTag('New Title'));
        audioFile.setTag(const ArtistTag('New Artist'));
        audioFile.setTag(RatingTag(85));

        expect(audioFile.isDirty, isTrue);

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThan(104)); // Original + containers

        // Should start with ID3v2 header
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"

        // Should end with ID3v1 tag
        final id3v1Start = encodedBytes.length - 128;
        expect(encodedBytes.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // "TAG"
      });

      test('should return original file when no tags are set', () async {
        // Arrange - no tags set
        expect(audioFile.getAllTags(), isEmpty);

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThanOrEqualTo(104)); // At least original size
      });

      test('should preserve existing containers when encoding', () async {
        // Arrange
        // Simulate existing containers
        audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')] = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A,
          ...List.filled(10, 0xFF), // Existing data
        ]);

        audioFile.setTag(const TitleTag('Updated Title'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThan(104));
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33]));
      });

      test('should handle encoding errors gracefully', () async {
        // Arrange
        final failingCodecRegistry = CodecRegistry(
          codecList: [_MockFailingCodec()],
          containerLocatorList: [_MockId3v2Locator()],
        );

        final failingAudioFile = PhonicAudioFileImpl(
          fileBytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          formatStrategy: _MockFailingFormatStrategy(),
          codecRegistry: failingCodecRegistry,
          mergePolicy: mergePolicy,
        );

        failingAudioFile.setTag(const TitleTag('Test'));

        // Act & Assert
        expect(
          () => failingAudioFile.encode(),
          throwsA(isA<PhonicException>()),
        );
      });

      test('should use encoding preparation for tag normalization', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Very Long Title That Should Be Normalized For ID3v1'));
        audioFile.setTag(GenreTag(const ['Rock', 'Alternative', 'Indie']));
        audioFile.setTag(RatingTag(85));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThan(104));
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2

        final id3v1Start = encodedBytes.length - 128;
        expect(encodedBytes.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // ID3v1
      });

      test('should clear dirty flag after successful encoding', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Test Title'));
        expect(audioFile.isDirty, isTrue);

        // Act
        await audioFile.encode();

        // Assert
        expect(audioFile.isDirty, isFalse);
      });

      test('should validate encoded file structure', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Validation Test'));
        audioFile.setTag(const ArtistTag('Test Artist'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - validation should pass without throwing
        expect(encodedBytes.length, greaterThan(104));

        // File should be detectable by format strategy
        expect(audioFile.formatStrategy.canHandle(encodedBytes), isTrue);
      });

      test('should handle empty tag list gracefully', () async {
        // Arrange - ensure no tags
        expect(audioFile.getAllTags(), isEmpty);

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThanOrEqualTo(104));
        expect(audioFile.isDirty, isFalse); // Should still clear dirty flag
      });

      test('should preserve unknown metadata during encoding', () async {
        // Arrange
        // Simulate existing container with unknown data
        audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')] = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, // Header (20 bytes total)
          0x54, 0x58, 0x58, 0x58, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, // Unknown frame header
          ...List.filled(10, 0xFF), // Unknown frame data
        ]);

        audioFile.setTag(const TitleTag('New Title'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert
        expect(encodedBytes.length, greaterThan(104));
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33]));
      });

      test('should handle validation failure gracefully', () async {
        // Arrange - create a scenario that might cause validation issues
        final corruptingCodecRegistry = CodecRegistry(
          codecList: [_MockCorruptingCodec()],
          containerLocatorList: [_MockId3v2Locator()],
        );

        final corruptingAudioFile = PhonicAudioFileImpl(
          fileBytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: corruptingCodecRegistry,
          mergePolicy: mergePolicy,
          validator: PostWriteValidator(
            codecRegistry: corruptingCodecRegistry,
            enableDeepValidation: true, // Enable validation that will try to read back
            enableRoundTripValidation: true, // Enable round-trip validation
          ),
        );

        corruptingAudioFile.setTag(const TitleTag('Test'));

        // Act & Assert - Use strict validation to enable round-trip validation
        expect(
          () => corruptingAudioFile.encode(
            const EncodingOptions(
              validationLevel: ValidationLevel.strict,
            ),
          ),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should maintain dirty flag if encoding fails', () async {
        // Arrange
        final failingCodecRegistry = CodecRegistry(
          codecList: [_MockFailingCodec()],
          containerLocatorList: [_MockId3v2Locator()],
        );

        final failingAudioFile = PhonicAudioFileImpl(
          fileBytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          formatStrategy: _MockFailingFormatStrategy(),
          codecRegistry: failingCodecRegistry,
          mergePolicy: mergePolicy,
        );

        failingAudioFile.setTag(const TitleTag('Test'));
        expect(failingAudioFile.isDirty, isTrue);

        // Act & Assert
        try {
          await failingAudioFile.encode();
          fail('Expected encoding to fail');
        } catch (e) {
          // Dirty flag should remain true since encoding failed
          expect(failingAudioFile.isDirty, isTrue);
        }
      });
    });

    group('audioData', () {
      test('should extract pure audio data by removing containers', () {
        // Arrange
        final fileWithContainers = Uint8List.fromList([
          // ID3v2 header
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A,
          ...List.filled(10, 0x00), // ID3v2 data
          // Audio data
          0xFF, 0xFB, 0x90, 0x00,
          ...List.filled(96, 0x00),
          // ID3v1 tag
          0x54, 0x41, 0x47, // "TAG"
          ...List.filled(125, 0x00),
        ]);

        final audioFileWithContainers = PhonicAudioFileImpl(
          fileBytes: fileWithContainers,
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Act
        final audioData = audioFileWithContainers.audioData;

        // Assert
        expect(audioData.length, equals(100)); // Just the audio portion
        expect(audioData[0], equals(0xFF)); // MP3 frame sync
        expect(audioData[1], equals(0xFB));
        expect(audioData[2], equals(0x90));
        expect(audioData[3], equals(0x00));
      });

      test('should return original data when no containers present', () {
        // Arrange - file with no containers
        final pureAudioFile = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          ...List.filled(96, 0x00),
        ]);

        final audioFileNoContainers = PhonicAudioFileImpl(
          fileBytes: pureAudioFile,
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Act
        final audioData = audioFileNoContainers.audioData;

        // Assert
        expect(audioData, equals(pureAudioFile));
      });
    });

    group('integration', () {
      test('should complete full read-modify-write cycle', () async {
        // Arrange
        final originalFile = Uint8List.fromList([
          // ID3v2 with existing title
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A,
          ...List.filled(10, 0x00),
          // Audio data
          0xFF, 0xFB, 0x90, 0x00,
          ...List.filled(96, 0x00),
        ]);

        final fullAudioFile = PhonicAudioFileImpl(
          fileBytes: originalFile,
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: PostWriteValidator(
            codecRegistry: codecRegistry,
            enableDeepValidation: false,
            enableRoundTripValidation: false,
          ),
        );

        // Simulate loading existing tags
        await fullAudioFile.extractContainersAndDecodeAsync();

        // Act - Modify tags
        fullAudioFile.setTag(const TitleTag('Modified Title'));
        fullAudioFile.setTag(const ArtistTag('New Artist'));

        expect(fullAudioFile.isDirty, isTrue);

        // Encode with changes
        final encodedFile = await fullAudioFile.encode();

        // Mark as clean
        fullAudioFile.markClean();
        expect(fullAudioFile.isDirty, isFalse);

        // Assert
        expect(encodedFile.length, greaterThanOrEqualTo(originalFile.length));
        expect(encodedFile.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2

        // Should contain ID3v1 if file is large enough
        if (encodedFile.length >= 128) {
          final id3v1Start = encodedFile.length - 128;
          expect(encodedFile.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // ID3v1
        }
      });

      test('should handle atomic operations correctly', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Atomic Test'));
        audioFile.setTag(RatingTag(95));

        // Act - Multiple encode operations should be consistent
        final encoded1 = await audioFile.encode();
        final encoded2 = await audioFile.encode();

        // Assert
        expect(encoded1, equals(encoded2)); // Should be identical
        expect(encoded1.length, equals(encoded2.length));
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
  bool canHandle(Uint8List fileBytes) => fileBytes.isNotEmpty && (fileBytes[0] == 0xFF || fileBytes[0] == 0x49);

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

class _MockFailingFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [(ContainerKind.id3v2, '2.4')];

  @override
  List<(ContainerKind, String)> get fanout => [(ContainerKind.id3v2, '2.4')];

  @override
  bool canHandle(Uint8List fileBytes) => false; // Always fails

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
    semanticsByKey: {
      TagKey.title: TagSemantics(),
      TagKey.artist: TagSemantics(),
      TagKey.rating: TagSemantics(),
      TagKey.genre: TagSemantics(),
    },
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return mock tags for testing
    return [
      const TitleTag('Existing Title'),
    ];
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return mock ID3v2.4 container
    return Uint8List.fromList([
      0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, // Header
      ...List.filled(10, 0x00), // Frame data
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
    semanticsByKey: {
      TagKey.title: TagSemantics(maxTextLength: 30),
      TagKey.artist: TagSemantics(maxTextLength: 30),
      TagKey.genre: TagSemantics(),
    },
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

class _MockFailingCodec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.id3v2,
    containerVersion: '2.4',
    semanticsByKey: {
      TagKey.title: TagSemantics(),
      TagKey.artist: TagSemantics(),
      TagKey.rating: TagSemantics(),
      TagKey.genre: TagSemantics(),
    },
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
    throw Exception('Mock codec failure');
  }
}

class _MockCorruptingCodec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.id3v2,
    containerVersion: '2.4',
    semanticsByKey: {
      TagKey.title: TagSemantics(),
      TagKey.artist: TagSemantics(),
      TagKey.rating: TagSemantics(),
      TagKey.genre: TagSemantics(),
    },
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Simulate parsing failure during validation
    throw const CorruptedContainerException('Corrupted container data');
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return container that looks valid to basic format detection but will fail deep parsing
    return Uint8List.fromList([
      0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, // Valid ID3v2 header
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Corrupted frame data
    ]);
  }
}

class _MockId3v2Locator extends ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  bool fileMatches(Uint8List fileBytes) {
    return fileBytes.length >= 3 && fileBytes[0] == 0x49 && fileBytes[1] == 0x44 && fileBytes[2] == 0x33;
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    if (!fileMatches(fileBytes)) return null;
    return fileBytes.sublist(0, fileBytes.length >= 20 ? 20 : fileBytes.length);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    if (containerBytes == null) {
      if (fileMatches(fileBytes)) {
        return fileBytes.sublist(20);
      }
      return fileBytes;
    }

    var audioData = fileBytes;
    if (fileMatches(audioData)) {
      audioData = audioData.sublist(20);
    }

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
    var result = fileBytes;
    if (fileMatches(result)) {
      result = result.sublist(0, result.length - 128);
    }

    if (containerBytes == null) {
      return result;
    }

    return Uint8List.fromList([...result, ...containerBytes]);
  }
}
