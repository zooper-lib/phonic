import 'dart:typed_data';

import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/container_locator.dart';
import 'package:phonic/src/core/format_strategy.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/phonic_audio_file_impl.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';
import 'package:test/test.dart';

void main() {
  group('PhonicAudioFileImpl - Container Extraction and Decoding', () {
    late Uint8List mockFileBytes;
    late PhonicAudioFileImpl audioFile;

    setUp(() {
      mockFileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    });

    tearDown(() {
      audioFile.dispose();
    });

    group('extractContainersAndDecode', () {
      test('processes containers in precedence order', () async {
        // Create mock components with specific precedence
        final formatStrategy = _MockFormatStrategy();
        final locator1 = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final locator2 = _MockContainerLocator(ContainerKind.id3v1, shouldMatch: true);
        final codec1 = _MockTagCodec(ContainerKind.id3v2, '2.4');
        final codec2 = _MockTagCodec(ContainerKind.id3v1, 'v1');

        final codecRegistry = CodecRegistry(
          codecList: [codec1, codec2],
          containerLocatorList: [locator1, locator2],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify containers were processed in precedence order
        expect(locator1.extractCallCount, equals(1));
        expect(locator2.extractCallCount, equals(1));
        expect(codec1.readCallCount, equals(1));
        expect(codec2.readCallCount, equals(1));

        // Verify tags were loaded into memory
        expect(audioFile.inMemoryTagsByKey, isNotEmpty);
        expect(audioFile.getTag(TagKey.title), isNotNull);
      });

      test('skips containers when locator is not available', () async {
        final formatStrategy = _MockFormatStrategy();
        // Create registry without locators for some container types
        final codecRegistry = CodecRegistry(
          codecList: [_MockTagCodec(ContainerKind.id3v2, '2.4')],
          containerLocatorList: [], // No locators available
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify no containers were processed
        expect(audioFile.inMemoryTagsByKey, isEmpty);
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
      });

      test('skips containers when file does not match', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: false);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify container was not processed
        expect(locator.extractCallCount, equals(0));
        expect(codec.readCallCount, equals(0));
        expect(audioFile.inMemoryTagsByKey, isEmpty);
      });

      test('skips containers when extraction fails', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true, shouldExtract: false);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify extraction was attempted but codec was not called
        expect(locator.extractCallCount, equals(1));
        expect(codec.readCallCount, equals(0));
        expect(audioFile.inMemoryTagsByKey, isEmpty);
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
      });

      test('skips containers when codec is not available', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        // Create registry without codec for the container type
        final codecRegistry = CodecRegistry(
          codecList: [], // No codecs available
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify extraction was successful but no codec processing
        expect(locator.extractCallCount, equals(1));
        expect(audioFile.loadedContainersByKindAndVersion, isNotEmpty);
        expect(audioFile.inMemoryTagsByKey, isEmpty);
      });

      test('caches extracted container bytes', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify container bytes were cached
        final cachedBytes = audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')];
        expect(cachedBytes, isNotNull);
        expect(cachedBytes, equals(locator.mockContainerBytes));
      });

      test('merges tags from multiple containers with precedence', () async {
        final formatStrategy = _MockFormatStrategy();

        // Create two containers with conflicting title tags
        final locator1 = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final locator2 = _MockContainerLocator(ContainerKind.id3v1, shouldMatch: true);

        final codec1 = _MockTagCodec(ContainerKind.id3v2, '2.4');
        codec1.mockTags = [
          const TitleTag('ID3v2 Title', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
        ];

        final codec2 = _MockTagCodec(ContainerKind.id3v1, 'v1');
        codec2.mockTags = [
          const TitleTag('ID3v1 Title', provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
        ];

        final codecRegistry = CodecRegistry(
          codecList: [codec1, codec2],
          containerLocatorList: [locator1, locator2],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify ID3v2 title takes precedence over ID3v1 (based on format strategy precedence)
        final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
        expect(titleTag, isNotNull);
        expect(titleTag!.value, equals('ID3v2 Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('handles codec exceptions gracefully', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');
        codec.shouldThrowOnRead = true;

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method - should not throw
        await audioFile.extractContainersAndDecode();

        // Verify graceful handling - container bytes cached but no tags loaded
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
        expect(audioFile.inMemoryTagsByKey, isEmpty);
      });

      test('handles locator exceptions gracefully', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        locator.shouldThrowOnExtract = true;
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method - should not throw
        await audioFile.extractContainersAndDecode();

        // Verify graceful handling - no processing occurred
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
        expect(audioFile.inMemoryTagsByKey, isEmpty);
      });

      test('organizes tags by key correctly', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        // Set up multiple tags of different types
        codec.mockTags = [
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock', 'Pop']), // Single genre tag with multiple values
        ];

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify tags are organized by key
        expect(audioFile.getTags(TagKey.title), hasLength(1));
        expect(audioFile.getTags(TagKey.artist), hasLength(1));
        expect(audioFile.getTags(TagKey.genre), hasLength(1));

        expect(audioFile.getTag(TagKey.title)?.value, equals('Test Title'));
        expect(audioFile.getTag(TagKey.artist)?.value, equals('Test Artist'));

        // Verify genre tag contains both values
        final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
        expect(genreTag?.value, containsAll(['Rock', 'Pop']));
      });

      test('clears existing tags before loading new ones', () async {
        final formatStrategy = _MockFormatStrategy();
        final locator = _MockContainerLocator(ContainerKind.id3v2, shouldMatch: true);
        final codec = _MockTagCodec(ContainerKind.id3v2, '2.4');

        final codecRegistry = CodecRegistry(
          codecList: [codec],
          containerLocatorList: [locator],
        );

        final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

        audioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
        );

        // Add some existing tags
        audioFile.setTag(const TitleTag('Old Title'));
        audioFile.setTag(const ArtistTag('Old Artist'));
        expect(audioFile.inMemoryTagsByKey, hasLength(2));

        // Execute the method
        await audioFile.extractContainersAndDecode();

        // Verify old tags were cleared and new ones loaded
        expect(audioFile.getTag(TagKey.title)?.value, equals('Mock Title'));
        expect(audioFile.getTags(TagKey.artist), isEmpty); // Mock codec doesn't provide artist
      });
    });
  });
}

/// Mock format strategy for testing
class _MockFormatStrategy implements FormatStrategy {
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
  ];

  @override
  bool canHandle(Uint8List fileBytes) => true;

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

/// Mock container locator for testing
class _MockContainerLocator implements ContainerLocator {
  @override
  final ContainerKind containerKind;

  final bool shouldMatch;
  final bool shouldExtract;
  bool shouldThrowOnExtract = false;

  int extractCallCount = 0;

  final Uint8List mockContainerBytes = Uint8List.fromList([10, 20, 30, 40]);

  _MockContainerLocator(
    this.containerKind, {
    this.shouldMatch = true,
    this.shouldExtract = true,
  });

  @override
  bool fileMatches(Uint8List fileBytes) => shouldMatch;

  @override
  Uint8List? extract(Uint8List fileBytes) {
    extractCallCount++;

    if (shouldThrowOnExtract) {
      throw Exception('Mock extraction error');
    }

    return shouldExtract ? mockContainerBytes : null;
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Not needed for extraction tests
    return fileBytes;
  }
}

/// Mock tag codec for testing
class _MockTagCodec implements TagCodec {
  @override
  final ContainerKind containerKind;

  @override
  final String containerVersion;

  int readCallCount = 0;
  bool shouldThrowOnRead = false;

  List<MetadataTag> mockTags = [
    const TitleTag('Mock Title'),
  ];

  _MockTagCodec(this.containerKind, this.containerVersion);

  @override
  TagCapability get capability => TagCapability(
    containerKind: containerKind,
    containerVersion: containerVersion,
    semanticsByKey: const {
      TagKey.title: TagSemantics(),
      TagKey.artist: TagSemantics(),
      TagKey.genre: TagSemantics(multiValued: true),
    },
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    readCallCount++;

    if (shouldThrowOnRead) {
      throw Exception('Mock codec read error');
    }

    return mockTags;
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    // Not needed for extraction tests
    return Uint8List.fromList([1, 2, 3]);
  }
}
