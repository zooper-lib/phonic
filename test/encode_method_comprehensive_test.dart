import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('PhonicAudioFileImpl encode method comprehensive tests', () {
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
      );
    });

    group('Requirements 2.1, 2.2, 2.3 - Complete file encoding', () {
      test('should orchestrate complete encoding pipeline', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Test Title'));
        audioFile.setTag(const ArtistTag('Test Artist'));
        audioFile.setTag(RatingTag(85));
        audioFile.setTag(GenreTag(const ['Rock', 'Alternative']));

        expect(audioFile.isDirty, isTrue);

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - Complete encoding pipeline
        expect(encodedBytes.length, greaterThan(104)); // Original + containers
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2 header

        final id3v1Start = encodedBytes.length - 128;
        expect(encodedBytes.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // ID3v1 tag
      });

      test('should use encoding preparation for tag normalization', () async {
        // Arrange - tags that need normalization
        audioFile.setTag(const TitleTag('Very Long Title That Exceeds ID3v1 30 Character Limit'));
        audioFile.setTag(GenreTag(const ['Rock', 'Alternative', 'Indie', 'Progressive']));
        audioFile.setTag(RatingTag(85));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - encoding preparation was used
        expect(encodedBytes.length, greaterThan(104));

        // Should have both ID3v2 and ID3v1 containers (fan-out)
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2

        final id3v1Start = encodedBytes.length - 128;
        expect(encodedBytes.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // ID3v1
      });

      test('should use container rebuilding to preserve unknown data', () async {
        // Arrange - simulate existing container with unknown data
        audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')] = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, // Header (20 bytes total)
          0x54, 0x58, 0x58, 0x58, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, // Unknown frame header
          ...List.filled(10, 0xFF), // Unknown frame data
        ]);

        audioFile.setTag(const TitleTag('New Title'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - container rebuilding was used
        expect(encodedBytes.length, greaterThan(104));
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33]));
      });

      test('should use file injection utilities', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Injection Test'));
        audioFile.setTag(const ArtistTag('Test Artist'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - file injection was used (containers in correct positions)
        expect(encodedBytes.length, greaterThan(104));

        // ID3v2 at beginning
        expect(encodedBytes.sublist(0, 3), equals([0x49, 0x44, 0x33]));

        // ID3v1 at end
        final id3v1Start = encodedBytes.length - 128;
        expect(encodedBytes.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47]));
      });
    });

    group('Requirement 6.2, 6.3 - Dirty flag management', () {
      test('should clear dirty flags after successful encoding', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Dirty Flag Test'));
        expect(audioFile.isDirty, isTrue);

        // Act
        await audioFile.encode();

        // Assert
        expect(audioFile.isDirty, isFalse);
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

      test('should clear dirty flag even when no tags are present', () async {
        // Arrange - no tags, but mark as dirty
        audioFile.markClean();
        audioFile.setTag(const TitleTag('Test'));
        audioFile.removeTag(TagKey.title);
        expect(audioFile.getAllTags(), isEmpty);
        expect(audioFile.isDirty, isTrue);

        // Act
        await audioFile.encode();

        // Assert
        expect(audioFile.isDirty, isFalse);
      });
    });

    group('Requirement 8.4 - Validation after write', () {
      test('should validate file structure after encoding', () async {
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

      test('should throw CorruptedContainerException for validation failures', () async {
        // Arrange - use corrupting codec that produces invalid containers
        final corruptingCodecRegistry = CodecRegistry(
          codecList: [_MockCorruptingCodec()],
          containerLocatorList: [_MockId3v2Locator()],
        );

        final corruptingAudioFile = PhonicAudioFileImpl(
          fileBytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: corruptingCodecRegistry,
          mergePolicy: mergePolicy,
        );

        corruptingAudioFile.setTag(const TitleTag('Test'));

        // Act & Assert
        expect(
          () => corruptingAudioFile.encode(),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should validate empty file detection', () async {
        // Arrange - create scenario that might produce empty file
        final emptyProducingCodecRegistry = CodecRegistry(
          codecList: [_MockEmptyProducingCodec()],
          containerLocatorList: [_MockId3v2Locator()],
        );

        final emptyProducingAudioFile = PhonicAudioFileImpl(
          fileBytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          formatStrategy: _MockMp3FormatStrategy(),
          codecRegistry: emptyProducingCodecRegistry,
          mergePolicy: mergePolicy,
        );

        emptyProducingAudioFile.setTag(const TitleTag('Test'));

        // Act & Assert
        expect(
          () => emptyProducingAudioFile.encode(),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should validate container extraction after encoding', () async {
        // Arrange
        audioFile.setTag(const TitleTag('Container Extraction Test'));

        // Act
        final encodedBytes = await audioFile.encode();

        // Assert - containers should be extractable
        final id3v2Locator = codecRegistry.findLocator(ContainerKind.id3v2);
        final id3v1Locator = codecRegistry.findLocator(ContainerKind.id3v1);

        expect(id3v2Locator!.fileMatches(encodedBytes), isTrue);
        expect(id3v1Locator!.fileMatches(encodedBytes), isTrue);

        final id3v2Container = id3v2Locator.extract(encodedBytes);
        final id3v1Container = id3v1Locator.extract(encodedBytes);

        expect(id3v2Container, isNotNull);
        expect(id3v1Container, isNotNull);
        expect(id3v2Container!.isNotEmpty, isTrue);
        expect(id3v1Container!.isNotEmpty, isTrue);
      });
    });

    group('Error handling and edge cases', () {
      test('should handle comprehensive error scenarios', () async {
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

        failingAudioFile.setTag(const TitleTag('Error Test'));

        // Act & Assert
        expect(
          () => failingAudioFile.encode(),
          throwsA(
            allOf([
              isA<CorruptedContainerException>(),
              predicate<CorruptedContainerException>((e) => e.message.contains('Failed to generate any containers')),
            ]),
          ),
        );
      });

      test('should provide meaningful error context', () async {
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

        failingAudioFile.setTag(const TitleTag('Context Test'));

        // Act & Assert
        try {
          await failingAudioFile.encode();
          fail('Expected encoding to fail');
        } on CorruptedContainerException catch (e) {
          expect(e.context, isNotNull);
          expect(e.context, contains('id3v2')); // Should contain container info
        }
      });
    });

    group('Integration scenarios', () {
      test('should handle complete read-modify-write cycle', () async {
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
        );

        // Simulate loading existing tags
        await fullAudioFile.extractContainersAndDecode();

        // Act - Modify tags
        fullAudioFile.setTag(const TitleTag('Modified Title'));
        fullAudioFile.setTag(const ArtistTag('New Artist'));
        fullAudioFile.setTag(GenreTag(const ['Electronic', 'Ambient']));

        expect(fullAudioFile.isDirty, isTrue);

        // Encode with changes
        final encodedFile = await fullAudioFile.encode();

        // Assert
        expect(fullAudioFile.isDirty, isFalse); // Should be clean after encoding
        expect(encodedFile.length, greaterThan(originalFile.length));
        expect(encodedFile.sublist(0, 3), equals([0x49, 0x44, 0x33])); // ID3v2

        // Should contain both ID3v2 and ID3v1 now
        final id3v1Start = encodedFile.length - 128;
        expect(encodedFile.sublist(id3v1Start, id3v1Start + 3), equals([0x54, 0x41, 0x47])); // ID3v1
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
        expect(audioFile.isDirty, isFalse); // Should remain clean
      });
    });
  });
}

// Mock implementations for comprehensive testing

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
    throw Exception('Corrupted container data');
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Return valid container that will pass basic validation but fail parsing
    return Uint8List.fromList([
      0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, // Valid header
      ...List.filled(10, 0x00), // Valid frame data
    ]);
  }
}

class _MockEmptyProducingCodec implements TagCodec {
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
    // Return empty container to trigger validation failure
    return Uint8List(0);
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


