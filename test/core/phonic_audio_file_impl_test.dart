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
  group('PhonicAudioFileImpl', () {
    late Uint8List mockFileBytes;
    late FormatStrategy mockFormatStrategy;
    late CodecRegistry mockCodecRegistry;
    late MergePolicy mockMergePolicy;
    late PhonicAudioFileImpl audioFile;

    setUp(() {
      // Create mock file bytes
      mockFileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Create mock format strategy
      mockFormatStrategy = _MockFormatStrategy();

      // Create mock codec registry
      mockCodecRegistry = CodecRegistry(
        codecList: [_MockTagCodec()],
        containerLocatorList: [_MockContainerLocator()],
      );

      // Create mock merge policy
      mockMergePolicy = MergePolicy.fromStrategy(mockFormatStrategy);

      // Create audio file instance
      audioFile = PhonicAudioFileImpl(
        fileBytes: mockFileBytes,
        formatStrategy: mockFormatStrategy,
        codecRegistry: mockCodecRegistry,
        mergePolicy: mockMergePolicy,
        validator: PostWriteValidator(
          codecRegistry: mockCodecRegistry,
          enableDeepValidation: false,
          enableRoundTripValidation: false,
        ),
      );
    });

    tearDown(() {
      audioFile.dispose();
    });

    group('constructor', () {
      test('creates instance with required parameters', () {
        expect(audioFile.formatStrategy, equals(mockFormatStrategy));
        expect(audioFile.codecRegistry, equals(mockCodecRegistry));
        expect(audioFile.mergePolicy, equals(mockMergePolicy));
        expect(audioFile.isDirty, isFalse);
      });

      test('creates instance with custom isDirty flag', () {
        final dirtyAudioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: mockFormatStrategy,
          codecRegistry: mockCodecRegistry,
          mergePolicy: mockMergePolicy,
          isDirty: true,
        );

        expect(dirtyAudioFile.isDirty, isTrue);
        dirtyAudioFile.dispose();
      });

      test('copies file bytes to prevent external modification', () {
        final originalBytes = Uint8List.fromList([1, 2, 3]);
        final audioFile = PhonicAudioFileImpl(
          fileBytes: originalBytes,
          formatStrategy: mockFormatStrategy,
          codecRegistry: mockCodecRegistry,
          mergePolicy: mockMergePolicy,
        );

        // Modify original bytes
        originalBytes[0] = 99;

        // Audio file should have original values
        expect(audioFile.audioData[0], equals(1));
        audioFile.dispose();
      });

      test('initializes empty tag and container maps', () {
        expect(audioFile.inMemoryTagsByKey, isEmpty);
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
      });
    });

    group('getTag', () {
      test('returns null when no tags exist for key', () {
        final result = audioFile.getTag(TagKey.title);
        expect(result, isNull);
      });

      test('returns first tag when multiple tags exist for key', () {
        final tag1 = const TitleTag('First Title');
        final tag2 = const TitleTag('Second Title');

        audioFile.inMemoryTagsByKey[TagKey.title] = [tag1, tag2];

        final result = audioFile.getTag(TagKey.title);
        expect(result, equals(tag1));
      });

      test('returns single tag when only one exists for key', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];

        final result = audioFile.getTag(TagKey.title);
        expect(result, equals(tag));
      });

      test('returns null when tag list is empty', () {
        audioFile.inMemoryTagsByKey[TagKey.title] = [];

        final result = audioFile.getTag(TagKey.title);
        expect(result, isNull);
      });
    });

    group('getTags', () {
      test('returns empty list when no tags exist for key', () {
        final result = audioFile.getTags(TagKey.title);
        expect(result, isEmpty);
      });

      test('returns all tags when multiple exist for key', () {
        final tag1 = const TitleTag('First Title');
        final tag2 = const TitleTag('Second Title');

        audioFile.inMemoryTagsByKey[TagKey.title] = [tag1, tag2];

        final result = audioFile.getTags(TagKey.title);
        expect(result, hasLength(2));
        expect(result, contains(tag1));
        expect(result, contains(tag2));
      });

      test('returns copy of tag list to prevent external modification', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];

        final result = audioFile.getTags(TagKey.title);
        result.clear();

        // Original list should be unchanged
        expect(audioFile.inMemoryTagsByKey[TagKey.title], hasLength(1));
      });

      test('returns single tag in list when only one exists', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];

        final result = audioFile.getTags(TagKey.title);
        expect(result, hasLength(1));
        expect(result.first, equals(tag));
      });

      test('returns multiple artwork tags for multi-valued artwork key', () {
        final artwork1 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Front Cover',
            dataLoader: () async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          ),
        );
        final artwork2 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/png',
            type: ArtworkType.backCover,
            description: 'Back Cover',
            dataLoader: () async => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          ),
        );

        audioFile.inMemoryTagsByKey[TagKey.artwork] = [artwork1, artwork2];

        final result = audioFile.getTags(TagKey.artwork);
        expect(result, hasLength(2));
        expect(result, contains(artwork1));
        expect(result, contains(artwork2));
      });
    });

    group('getAllTags', () {
      test('returns empty list when no tags exist', () {
        final result = audioFile.getAllTags();
        expect(result, isEmpty);
      });

      test('returns all tags from all keys', () {
        final titleTag = const TitleTag('Test Title');
        final artistTag = const ArtistTag('Test Artist');
        final genreTag1 = GenreTag(const ['Rock']);
        final genreTag2 = GenreTag(const ['Pop']);

        audioFile.inMemoryTagsByKey[TagKey.title] = [titleTag];
        audioFile.inMemoryTagsByKey[TagKey.artist] = [artistTag];
        audioFile.inMemoryTagsByKey[TagKey.genre] = [genreTag1, genreTag2];

        final result = audioFile.getAllTags();
        expect(result, hasLength(4));
        expect(result, contains(titleTag));
        expect(result, contains(artistTag));
        expect(result, contains(genreTag1));
        expect(result, contains(genreTag2));
      });

      test('returns tags in consistent order', () {
        final titleTag = const TitleTag('Test Title');
        final artistTag = const ArtistTag('Test Artist');

        audioFile.inMemoryTagsByKey[TagKey.title] = [titleTag];
        audioFile.inMemoryTagsByKey[TagKey.artist] = [artistTag];

        final result1 = audioFile.getAllTags();
        final result2 = audioFile.getAllTags();

        expect(result1.length, equals(result2.length));
        for (int i = 0; i < result1.length; i++) {
          expect(result1[i], equals(result2[i]));
        }
      });

      test('preserves provenance information for all tags', () {
        final id3v2Provenance = const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);
        final id3v1Provenance = const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain);
        final vorbisProvenance = const TagProvenance(ContainerKind.vorbis, '', TagConfidence.inferred);

        final titleTag = TitleTag('Test Title', provenance: id3v2Provenance);
        final artistTag = ArtistTag('Test Artist', provenance: id3v1Provenance);
        final genreTag = GenreTag(const ['Rock'], provenance: vorbisProvenance);

        audioFile.inMemoryTagsByKey[TagKey.title] = [titleTag];
        audioFile.inMemoryTagsByKey[TagKey.artist] = [artistTag];
        audioFile.inMemoryTagsByKey[TagKey.genre] = [genreTag];

        final result = audioFile.getAllTags();

        expect(result, hasLength(3));

        // Verify each tag maintains its provenance
        final resultTitle = result.firstWhere((tag) => tag.key == TagKey.title);
        expect(resultTitle.provenance, equals(id3v2Provenance));

        final resultArtist = result.firstWhere((tag) => tag.key == TagKey.artist);
        expect(resultArtist.provenance, equals(id3v1Provenance));

        final resultGenre = result.firstWhere((tag) => tag.key == TagKey.genre);
        expect(resultGenre.provenance, equals(vorbisProvenance));
      });

      test('flattens multi-valued tags while preserving individual provenance', () {
        final id3v2Provenance = const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);
        final vorbisProvenance = const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain);

        final genreTag1 = GenreTag(const ['Rock'], provenance: id3v2Provenance);
        final genreTag2 = GenreTag(const ['Pop'], provenance: vorbisProvenance);
        final genreTag3 = GenreTag(const ['Jazz'], provenance: id3v2Provenance);

        audioFile.inMemoryTagsByKey[TagKey.genre] = [genreTag1, genreTag2, genreTag3];

        final result = audioFile.getAllTags();

        expect(result, hasLength(3));
        expect(result, contains(genreTag1));
        expect(result, contains(genreTag2));
        expect(result, contains(genreTag3));

        // Verify each genre tag maintains its individual provenance
        final rockTag = result.firstWhere((tag) => (tag as GenreTag).value.contains('Rock'));
        expect(rockTag.provenance, equals(id3v2Provenance));

        final popTag = result.firstWhere((tag) => (tag as GenreTag).value.contains('Pop'));
        expect(popTag.provenance, equals(vorbisProvenance));

        final jazzTag = result.firstWhere((tag) => (tag as GenreTag).value.contains('Jazz'));
        expect(jazzTag.provenance, equals(id3v2Provenance));
      });

      test('returns new list instance to prevent external modification', () {
        final titleTag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [titleTag];

        final result1 = audioFile.getAllTags();
        final result2 = audioFile.getAllTags();

        // Verify different list instances
        expect(identical(result1, result2), isFalse);

        // Modify one result and verify the other is unaffected
        result1.clear();
        expect(result2, hasLength(1));
        expect(result2.first, equals(titleTag));

        // Verify original data is unaffected
        expect(audioFile.getAllTags(), hasLength(1));
      });

      test('handles mixed tag types with different value types', () {
        final titleTag = const TitleTag('Test Title');
        final trackTag = TrackNumberTag(5);
        final ratingTag = RatingTag(85);
        final genreTag = GenreTag(const ['Rock', 'Pop']);
        final yearTag = YearTag(2023);

        audioFile.inMemoryTagsByKey[TagKey.title] = [titleTag];
        audioFile.inMemoryTagsByKey[TagKey.trackNumber] = [trackTag];
        audioFile.inMemoryTagsByKey[TagKey.rating] = [ratingTag];
        audioFile.inMemoryTagsByKey[TagKey.genre] = [genreTag];
        audioFile.inMemoryTagsByKey[TagKey.year] = [yearTag];

        final result = audioFile.getAllTags();

        expect(result, hasLength(5));
        expect(result, contains(titleTag));
        expect(result, contains(trackTag));
        expect(result, contains(ratingTag));
        expect(result, contains(genreTag));
        expect(result, contains(yearTag));

        // Verify type safety is maintained
        final titleResult = result.firstWhere((tag) => tag.key == TagKey.title) as TitleTag;
        expect(titleResult.value, isA<String>());
        expect(titleResult.value, equals('Test Title'));

        final trackResult = result.firstWhere((tag) => tag.key == TagKey.trackNumber) as TrackNumberTag;
        expect(trackResult.value, isA<int>());
        expect(trackResult.value, equals(5));

        final genreResult = result.firstWhere((tag) => tag.key == TagKey.genre) as GenreTag;
        expect(genreResult.value, isA<List<String>>());
        expect(genreResult.value, equals(['Rock', 'Pop']));
      });

      test('maintains performance with large number of tags', () {
        // Add a large number of tags to test performance characteristics
        const tagCount = 1000;

        for (int i = 0; i < tagCount; i++) {
          final titleTag = TitleTag('Title $i');
          audioFile.inMemoryTagsByKey[TagKey.title] = (audioFile.inMemoryTagsByKey[TagKey.title] ?? [])..add(titleTag);
        }

        final stopwatch = Stopwatch()..start();
        final result = audioFile.getAllTags();
        stopwatch.stop();

        expect(result, hasLength(tagCount));
        // Performance should be reasonable (under 100ms for 1000 tags)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('returns empty list when called before container extraction', () {
        // This test verifies getAllTags behavior when no containers have been loaded
        final result = audioFile.getAllTags();
        expect(result, isEmpty);
        expect(result, isA<List<MetadataTag>>());
      });
    });

    group('setTag', () {
      test('adds new tag when key does not exist', () {
        expect(audioFile.isDirty, isFalse);

        final tag = const TitleTag('New Title');
        audioFile.setTag(tag);

        expect(audioFile.getTag(TagKey.title), equals(tag));
        expect(audioFile.isDirty, isTrue);
      });

      test('replaces existing tag when key exists', () {
        final oldTag = const TitleTag('Old Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [oldTag];
        audioFile.markClean();

        final newTag = const TitleTag('New Title');
        audioFile.setTag(newTag);

        expect(audioFile.getTag(TagKey.title), equals(newTag));
        expect(audioFile.getTags(TagKey.title), hasLength(1));
        expect(audioFile.isDirty, isTrue);
      });

      test('replaces multiple existing tags with single tag', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['Pop']);
        audioFile.inMemoryTagsByKey[TagKey.genre] = [tag1, tag2];
        audioFile.markClean();

        final newTag = GenreTag(const ['Jazz']);
        audioFile.setTag(newTag);

        expect(audioFile.getTags(TagKey.genre), hasLength(1));
        expect(audioFile.getTag(TagKey.genre), equals(newTag));
        expect(audioFile.isDirty, isTrue);
      });

      test('sets dirty flag when tag is added', () {
        expect(audioFile.isDirty, isFalse);

        audioFile.setTag(const TitleTag('Test'));

        expect(audioFile.isDirty, isTrue);
      });

      test('validates rating tag within valid range', () {
        expect(() => audioFile.setTag(RatingTag(0)), returnsNormally);
        expect(() => audioFile.setTag(RatingTag(50)), returnsNormally);
        expect(() => audioFile.setTag(RatingTag(100)), returnsNormally);
      });

      test('throws ArgumentError for invalid rating values (tag-level validation)', () {
        expect(
          () => audioFile.setTag(RatingTag(-1)),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => audioFile.setTag(RatingTag(101)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates track number as positive integer (tag-level validation)', () {
        expect(() => audioFile.setTag(TrackNumberTag(1)), returnsNormally);
        expect(() => audioFile.setTag(TrackNumberTag(99)), returnsNormally);

        expect(
          () => audioFile.setTag(TrackNumberTag(0)),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => audioFile.setTag(TrackNumberTag(-5)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates disc number as positive integer (tag-level validation)', () {
        expect(() => audioFile.setTag(DiscNumberTag(1)), returnsNormally);
        expect(() => audioFile.setTag(DiscNumberTag(5)), returnsNormally);

        expect(
          () => audioFile.setTag(DiscNumberTag(0)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates BPM within reasonable range (tag-level validation)', () {
        expect(() => audioFile.setTag(BpmTag(1)), returnsNormally);
        expect(() => audioFile.setTag(BpmTag(120)), returnsNormally);
        expect(() => audioFile.setTag(BpmTag(999)), returnsNormally);

        expect(
          () => audioFile.setTag(BpmTag(0)),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => audioFile.setTag(BpmTag(1000)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates year as 4-digit year (tag-level validation)', () {
        expect(() => audioFile.setTag(YearTag(1900)), returnsNormally);
        expect(() => audioFile.setTag(YearTag(2023)), returnsNormally);
        expect(() => audioFile.setTag(YearTag(2100)), returnsNormally);

        expect(
          () => audioFile.setTag(YearTag(999)),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => audioFile.setTag(YearTag(2101)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('allows text tags without length constraints when no codec available', () {
        // With mock format strategy that has no available codecs,
        // text tags should be allowed without length validation
        expect(() => audioFile.setTag(const TitleTag('This is a very long title that would exceed ID3v1 limits but should be allowed')), returnsNormally);
        expect(() => audioFile.setTag(const ArtistTag('Very Long Artist Name That Exceeds Typical Limits')), returnsNormally);
        expect(() => audioFile.setTag(const AlbumTag('Super Long Album Name')), returnsNormally);
      });

      test('handles multi-valued tags correctly', () {
        final multiGenreTag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(() => audioFile.setTag(multiGenreTag), returnsNormally);

        final retrievedTag = audioFile.getTag(TagKey.genre) as GenreTag;
        expect(retrievedTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('preserves tag provenance when setting', () {
        const provenance = TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);
        final tagWithProvenance = const TitleTag('Test Title', provenance: provenance);

        audioFile.setTag(tagWithProvenance);

        final retrievedTag = audioFile.getTag(TagKey.title);
        expect(retrievedTag?.provenance, equals(provenance));
      });

      test('handles empty fanout targets gracefully', () {
        // Create audio file with format strategy that has empty fanout
        final emptyFanoutStrategy = _MockEmptyFanoutFormatStrategy();
        final emptyFanoutAudioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: emptyFanoutStrategy,
          codecRegistry: mockCodecRegistry,
          mergePolicy: MergePolicy.fromStrategy(emptyFanoutStrategy),
        );

        // Should not throw exception even with empty fanout
        expect(() => emptyFanoutAudioFile.setTag(const TitleTag('Test')), returnsNormally);

        emptyFanoutAudioFile.dispose();
      });

      test('provides detailed error context in validation exceptions', () {
        try {
          audioFile.setTag(RatingTag(150));
          fail('Expected ArgumentError');
        } on ArgumentError catch (e) {
          expect(e.message, contains('Rating must be between 0 and 100'));
          expect(e.toString(), contains('Invalid argument'));
        }
      });

      test('throws TagValidationException when no container supports tag', () {
        // Create audio file with format strategy that has no codec for the fanout target
        final noCodecStrategy = _MockNoCodecFormatStrategy();
        final noCodecRegistry = CodecRegistry(
          codecList: [], // No codecs available
          containerLocatorList: [],
        );
        final noCodecAudioFile = PhonicAudioFileImpl(
          fileBytes: mockFileBytes,
          formatStrategy: noCodecStrategy,
          codecRegistry: noCodecRegistry,
          mergePolicy: MergePolicy.fromStrategy(noCodecStrategy),
        );

        expect(
          () => noCodecAudioFile.setTag(const TitleTag('Test')),
          throwsA(
            isA<TagValidationException>()
                .having((e) => e.tagKey, 'tagKey', TagKey.title)
                .having((e) => e.reason, 'reason', contains('not supported by any fan-out target container')),
          ),
        );

        noCodecAudioFile.dispose();
      });

      test('validates different tag value types correctly', () {
        // String tags
        expect(() => audioFile.setTag(const TitleTag('Valid Title')), returnsNormally);
        expect(() => audioFile.setTag(const CommentTag('Valid Comment')), returnsNormally);

        // Integer tags
        expect(() => audioFile.setTag(TrackNumberTag(5)), returnsNormally);
        expect(() => audioFile.setTag(RatingTag(85)), returnsNormally);

        // List<String> tags
        expect(() => audioFile.setTag(GenreTag(const ['Rock', 'Pop'])), returnsNormally);

        // Complex tags (should not throw validation errors for basic cases)
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => Uint8List.fromList([0xFF, 0xD8]),
        );
        expect(() => audioFile.setTag(ArtworkTag(artworkData)), returnsNormally);
      });

      test('handles concurrent tag setting correctly', () {
        // Set multiple tags in sequence
        audioFile.setTag(const TitleTag('Title'));
        audioFile.setTag(const ArtistTag('Artist'));
        audioFile.setTag(RatingTag(85));
        audioFile.setTag(GenreTag(const ['Rock']));

        // Verify all tags are set correctly
        expect((audioFile.getTag(TagKey.title) as TitleTag).value, equals('Title'));
        expect((audioFile.getTag(TagKey.artist) as ArtistTag).value, equals('Artist'));
        expect((audioFile.getTag(TagKey.rating) as RatingTag).value, equals(85));
        expect((audioFile.getTag(TagKey.genre) as GenreTag).value, equals(['Rock']));
        expect(audioFile.isDirty, isTrue);
      });

      test('replaces existing tags completely for same key', () {
        // Set initial genre tags
        audioFile.inMemoryTagsByKey[TagKey.genre] = [
          GenreTag(const ['Rock']),
          GenreTag(const ['Pop']),
          GenreTag(const ['Jazz']),
        ];
        audioFile.markClean();

        // Set new genre tag - should replace all existing ones
        final newGenreTag = GenreTag(const ['Classical']);
        audioFile.setTag(newGenreTag);

        final genreTags = audioFile.getTags(TagKey.genre);
        expect(genreTags, hasLength(1));
        expect(genreTags.first, equals(newGenreTag));
        expect((genreTags.first as GenreTag).value, equals(['Classical']));
        expect(audioFile.isDirty, isTrue);
      });
    });

    group('removeTag', () {
      test('removes existing tag and sets dirty flag', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];
        audioFile.markClean();

        audioFile.removeTag(TagKey.title);

        expect(audioFile.getTag(TagKey.title), isNull);
        expect(audioFile.isDirty, isTrue);
      });

      test('does nothing when tag does not exist', () {
        expect(audioFile.isDirty, isFalse);

        audioFile.removeTag(TagKey.title);

        expect(audioFile.isDirty, isFalse);
      });

      test('removes all tags for the key', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['Pop']);
        audioFile.inMemoryTagsByKey[TagKey.genre] = [tag1, tag2];
        audioFile.markClean();

        audioFile.removeTag(TagKey.genre);

        expect(audioFile.getTags(TagKey.genre), isEmpty);
        expect(audioFile.isDirty, isTrue);
      });
    });

    group('removeTagValue', () {
      test('does nothing when no tags exist for key', () {
        expect(audioFile.isDirty, isFalse);

        audioFile.removeTagValue(TagKey.title, 'Test');

        expect(audioFile.isDirty, isFalse);
      });

      test('does nothing when tag list is empty', () {
        audioFile.inMemoryTagsByKey[TagKey.title] = [];
        expect(audioFile.isDirty, isFalse);

        audioFile.removeTagValue(TagKey.title, 'Test');

        expect(audioFile.isDirty, isFalse);
      });

      test('removes single tag when value matches', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.title, 'Test Title');

        expect(audioFile.getTag(TagKey.title), isNull);
        expect(audioFile.isDirty, isTrue);
      });

      test('does not remove single tag when value does not match', () {
        final tag = const TitleTag('Test Title');
        audioFile.inMemoryTagsByKey[TagKey.title] = [tag];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.title, 'Different Title');

        expect(audioFile.getTag(TagKey.title), equals(tag));
        expect(audioFile.isDirty, isFalse);
      });

      test('removes matching values from multi-valued tag', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['Pop']);
        final tag3 = GenreTag(const ['Jazz']);
        audioFile.inMemoryTagsByKey[TagKey.genre] = [tag1, tag2, tag3];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.genre, ['Pop']);

        final remainingTags = audioFile.getTags(TagKey.genre);
        expect(remainingTags, hasLength(2));
        expect(remainingTags, contains(tag1));
        expect(remainingTags, contains(tag3));
        expect(remainingTags, isNot(contains(tag2)));
        expect(audioFile.isDirty, isTrue);
      });

      test('removes key when all values are removed', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['Rock']);
        audioFile.inMemoryTagsByKey[TagKey.genre] = [tag1, tag2];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.genre, ['Rock']);

        expect(audioFile.getTags(TagKey.genre), isEmpty);
        expect(audioFile.inMemoryTagsByKey.containsKey(TagKey.genre), isFalse);
        expect(audioFile.isDirty, isTrue);
      });

      test('removes specific artwork by matching ArtworkData', () {
        final artwork1 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Front Cover',
            dataLoader: () async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          ),
        );
        final artwork2 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/png',
            type: ArtworkType.backCover,
            description: 'Back Cover',
            dataLoader: () async => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          ),
        );
        final artwork3 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.artist,
            description: 'Artist Photo',
            dataLoader: () async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1]),
          ),
        );

        audioFile.inMemoryTagsByKey[TagKey.artwork] = [artwork1, artwork2, artwork3];
        audioFile.markClean();

        // Remove the back cover artwork by matching its ArtworkData
        audioFile.removeTagValue(TagKey.artwork, artwork2.value);

        final remainingArtwork = audioFile.getTags(TagKey.artwork);
        expect(remainingArtwork, hasLength(2));
        expect(remainingArtwork, contains(artwork1));
        expect(remainingArtwork, contains(artwork3));
        expect(remainingArtwork, isNot(contains(artwork2)));
        expect(audioFile.isDirty, isTrue);
      });

      test('removes all artwork when all values match', () {
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Cover',
          dataLoader: () async => Uint8List.fromList([0xFF, 0xD8]),
        );
        final artwork1 = ArtworkTag(artworkData);
        final artwork2 = ArtworkTag(artworkData); // Same artwork data

        audioFile.inMemoryTagsByKey[TagKey.artwork] = [artwork1, artwork2];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.artwork, artworkData);

        expect(audioFile.getTags(TagKey.artwork), isEmpty);
        expect(audioFile.inMemoryTagsByKey.containsKey(TagKey.artwork), isFalse);
        expect(audioFile.isDirty, isTrue);
      });

      test('does not remove artwork when ArtworkData does not match', () {
        final artwork1 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Front Cover',
            dataLoader: () async => Uint8List.fromList([0xFF, 0xD8]),
          ),
        );
        final differentArtworkData = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.frontCover,
          description: 'Front Cover',
          dataLoader: () async => Uint8List.fromList([0x89, 0x50]),
        );

        audioFile.inMemoryTagsByKey[TagKey.artwork] = [artwork1];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.artwork, differentArtworkData);

        expect(audioFile.getTags(TagKey.artwork), hasLength(1));
        expect(audioFile.getTags(TagKey.artwork).first, equals(artwork1));
        expect(audioFile.isDirty, isFalse);
      });

      test('handles complex value types correctly', () {
        // Test with different value types
        final stringTag = const TitleTag('Test Title');
        final intTag = RatingTag(85);
        final listTag = GenreTag(const ['Rock', 'Pop']);

        audioFile.inMemoryTagsByKey[TagKey.title] = [stringTag];
        audioFile.inMemoryTagsByKey[TagKey.rating] = [intTag];
        audioFile.inMemoryTagsByKey[TagKey.genre] = [listTag];
        audioFile.markClean();

        // Remove string value
        audioFile.removeTagValue(TagKey.title, 'Test Title');
        expect(audioFile.getTag(TagKey.title), isNull);

        // Remove int value
        audioFile.removeTagValue(TagKey.rating, 85);
        expect(audioFile.getTag(TagKey.rating), isNull);

        // Remove list value
        audioFile.removeTagValue(TagKey.genre, ['Rock', 'Pop']);
        expect(audioFile.getTag(TagKey.genre), isNull);

        expect(audioFile.isDirty, isTrue);
      });

      test('handles list comparison correctly for GenreTag', () {
        final genre1 = GenreTag(const ['Rock', 'Alternative']);
        final genre2 = GenreTag(const ['Pop', 'Electronic']);
        final genre3 = GenreTag(const ['Jazz']);

        audioFile.inMemoryTagsByKey[TagKey.genre] = [genre1, genre2, genre3];
        audioFile.markClean();

        // Remove genre with matching list value
        audioFile.removeTagValue(TagKey.genre, ['Pop', 'Electronic']);

        final remainingGenres = audioFile.getTags(TagKey.genre);
        expect(remainingGenres, hasLength(2));
        expect(remainingGenres, contains(genre1));
        expect(remainingGenres, contains(genre3));
        expect(remainingGenres, isNot(contains(genre2)));
        expect(audioFile.isDirty, isTrue);
      });

      test('does not remove when list order differs', () {
        final genre1 = GenreTag(const ['Rock', 'Alternative']);

        audioFile.inMemoryTagsByKey[TagKey.genre] = [genre1];
        audioFile.markClean();

        // Try to remove with different order - should not match
        audioFile.removeTagValue(TagKey.genre, ['Alternative', 'Rock']);

        expect(audioFile.getTags(TagKey.genre), hasLength(1));
        expect(audioFile.getTags(TagKey.genre).first, equals(genre1));
        expect(audioFile.isDirty, isFalse);
      });

      test('handles empty list values correctly', () {
        final emptyGenre = GenreTag(const []);

        audioFile.inMemoryTagsByKey[TagKey.genre] = [emptyGenre];
        audioFile.markClean();

        audioFile.removeTagValue(TagKey.genre, []);

        expect(audioFile.getTags(TagKey.genre), isEmpty);
        expect(audioFile.isDirty, isTrue);
      });

      test('removes multiple matching tags in multi-valued field', () {
        final artwork1 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => Uint8List.fromList([1, 2, 3]),
          ),
        );
        final artwork2 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/png',
            type: ArtworkType.backCover,
            dataLoader: () async => Uint8List.fromList([4, 5, 6]),
          ),
        );
        final artwork3 = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => Uint8List.fromList([1, 2, 3]),
          ),
        );

        audioFile.inMemoryTagsByKey[TagKey.artwork] = [artwork1, artwork2, artwork3];
        audioFile.markClean();

        // Remove artwork1's data - should remove both artwork1 and artwork3 since they have same data
        audioFile.removeTagValue(TagKey.artwork, artwork1.value);

        final remainingArtwork = audioFile.getTags(TagKey.artwork);
        expect(remainingArtwork, hasLength(1));
        expect(remainingArtwork.first, equals(artwork2));
        expect(audioFile.isDirty, isTrue);
      });
    });

    group('isDirty and markClean', () {
      test('isDirty returns false initially', () {
        expect(audioFile.isDirty, isFalse);
      });

      test('isDirty returns true after setting tag', () {
        audioFile.setTag(const TitleTag('Test'));
        expect(audioFile.isDirty, isTrue);
      });

      test('isDirty returns true after removing tag', () {
        audioFile.inMemoryTagsByKey[TagKey.title] = [const TitleTag('Test')];
        audioFile.markClean();

        audioFile.removeTag(TagKey.title);
        expect(audioFile.isDirty, isTrue);
      });

      test('markClean resets dirty flag', () {
        audioFile.setTag(const TitleTag('Test'));
        expect(audioFile.isDirty, isTrue);

        audioFile.markClean();
        expect(audioFile.isDirty, isFalse);
      });
    });

    group('encode', () {
      test('returns file bytes when no changes made', () async {
        final result = await audioFile.encode();
        expect(result, equals(mockFileBytes));
      });

      test('returns file bytes even when dirty', () async {
        audioFile.setTag(const TitleTag('Test'));

        final result = await audioFile.encode();
        expect(result, equals(mockFileBytes));
      });
    });

    group('audioData', () {
      test('returns original file bytes', () {
        final result = audioFile.audioData;
        expect(result, equals(mockFileBytes));
      });

      test('returns copy to prevent external modification', () {
        final result = audioFile.audioData;
        result[0] = 99;

        // Original should be unchanged
        expect(audioFile.audioData[0], equals(mockFileBytes[0]));
      });
    });

    group('dispose', () {
      test('clears all internal data structures', () {
        // Add some data
        audioFile.setTag(const TitleTag('Test'));
        audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')] = Uint8List.fromList([1, 2, 3]);

        expect(audioFile.inMemoryTagsByKey, isNotEmpty);
        expect(audioFile.loadedContainersByKindAndVersion, isNotEmpty);
        expect(audioFile.isDirty, isTrue);

        audioFile.dispose();

        expect(audioFile.inMemoryTagsByKey, isEmpty);
        expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
        expect(audioFile.isDirty, isFalse);
      });

      test('can be called multiple times safely', () {
        audioFile.setTag(const TitleTag('Test'));

        audioFile.dispose();
        audioFile.dispose(); // Should not throw

        expect(audioFile.inMemoryTagsByKey, isEmpty);
        expect(audioFile.isDirty, isFalse);
      });
    });

    group('properties access', () {
      test('provides access to format strategy', () {
        expect(audioFile.formatStrategy, equals(mockFormatStrategy));
      });

      test('provides access to codec registry', () {
        expect(audioFile.codecRegistry, equals(mockCodecRegistry));
      });

      test('provides access to merge policy', () {
        expect(audioFile.mergePolicy, equals(mockMergePolicy));
      });

      test('provides access to in-memory tags map', () {
        final tag = const TitleTag('Test');
        audioFile.setTag(tag);

        expect(audioFile.inMemoryTagsByKey[TagKey.title], contains(tag));
      });

      test('provides access to loaded containers map', () {
        final containerBytes = Uint8List.fromList([1, 2, 3]);
        audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')] = containerBytes;

        expect(
          audioFile.loadedContainersByKindAndVersion[(ContainerKind.id3v2, '2.4')],
          equals(containerBytes),
        );
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

/// Mock format strategy with empty fanout for testing
class _MockEmptyFanoutFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [
    (ContainerKind.id3v2, '2.4'),
  ];

  @override
  List<(ContainerKind, String)> get fanout => [];

  @override
  bool canHandle(Uint8List fileBytes) => true;

  @override
  MediaKind detectFormat(Uint8List fileBytes) => MediaKind.mp3;
}

/// Mock format strategy with fanout but no available codec for testing
class _MockNoCodecFormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;

  @override
  List<(ContainerKind, String)> get precedence => [
    (ContainerKind.id3v2, '2.4'),
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

/// Mock tag codec for testing
class _MockTagCodec implements TagCodec {
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
      TagKey.album: TagSemantics(),
      TagKey.albumArtist: TagSemantics(),
      TagKey.trackNumber: TagSemantics(),
      TagKey.discNumber: TagSemantics(),
      TagKey.year: TagSemantics(),
      TagKey.genre: TagSemantics(multiValued: true),
      TagKey.comment: TagSemantics(),
      TagKey.bpm: TagSemantics(),
      TagKey.rating: TagSemantics(),
      TagKey.artwork: TagSemantics(multiValued: true),
      TagKey.grouping: TagSemantics(),
      TagKey.composer: TagSemantics(),
      TagKey.encoder: TagSemantics(),
      TagKey.isrc: TagSemantics(),
      TagKey.musicalKey: TagSemantics(),
      TagKey.lyrics: TagSemantics(),
      TagKey.dateRecorded: TagSemantics(),
      TagKey.custom: TagSemantics(),
    },
  );

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
    // Return a minimal valid container with some dummy data
    // This simulates a basic container structure for testing
    return Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  }
}

/// Mock container locator for testing
class _MockContainerLocator implements ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  bool fileMatches(Uint8List fileBytes) => true;

  @override
  Uint8List? extract(Uint8List fileBytes) {
    // Return some dummy container bytes for extraction
    return Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // For testing, just return the original file bytes
    // This simulates the case where injection doesn't modify the file structure
    return Uint8List.fromList(fileBytes);
  }
}
