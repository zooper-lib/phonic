import 'dart:typed_data';

import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/encoding_preparation.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingPreparation', () {
    late EncodingPreparation preparation;
    late TagCapability id3v1Capability;
    late TagCapability id3v24Capability;
    late TagCapability vorbisCapability;

    setUp(() {
      preparation = EncodingPreparation();

      // Define test capabilities
      id3v1Capability = const TagCapability(
        containerKind: ContainerKind.id3v1,
        containerVersion: 'v1',
        semanticsByKey: {
          TagKey.title: TagSemantics(maxTextLength: 30),
          TagKey.artist: TagSemantics(maxTextLength: 30),
          TagKey.album: TagSemantics(maxTextLength: 30),
          TagKey.year: TagSemantics(minValue: 1000, maxValue: 9999),
          TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
          TagKey.genre: TagSemantics(multiValued: false), // Single genre only
        },
      );

      id3v24Capability = const TagCapability(
        containerKind: ContainerKind.id3v2,
        containerVersion: '2.4',
        semanticsByKey: {
          TagKey.title: TagSemantics(),
          TagKey.artist: TagSemantics(),
          TagKey.album: TagSemantics(),
          TagKey.genre: TagSemantics(multiValued: false), // Single TCON frame with delimiters
          TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
          TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 65535),
          TagKey.year: TagSemantics(minValue: 1000, maxValue: 9999),
          TagKey.artwork: TagSemantics(multiValued: true),
        },
      );

      vorbisCapability = const TagCapability(
        containerKind: ContainerKind.vorbis,
        containerVersion: '',
        semanticsByKey: {
          TagKey.title: TagSemantics(),
          TagKey.artist: TagSemantics(),
          TagKey.album: TagSemantics(),
          TagKey.genre: TagSemantics(multiValued: true), // Multiple GENRE fields
          TagKey.rating: TagSemantics(minValue: 0, maxValue: 100),
          TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 999999),
          TagKey.year: TagSemantics(minValue: 1000, maxValue: 9999),
          TagKey.artwork: TagSemantics(multiValued: true),
        },
      );
    });

    group('prepareTagsForEncoding', () {
      test('applies fan-out logic for MP3 format', () {
        final strategy = const Mp3FormatStrategy();
        final capabilities = {
          (ContainerKind.id3v2, '2.4'): id3v24Capability,
          (ContainerKind.id3v1, 'v1'): id3v1Capability,
        };

        final inputTags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock', 'Alternative']),
        ];

        final result = preparation.prepareTagsForEncoding(
          tags: inputTags,
          strategy: strategy,
          capabilities: capabilities,
        );

        // Should have tags for both ID3v2.4 and ID3v1 (fan-out targets)
        expect(result.keys, hasLength(2));
        expect(result.containsKey((ContainerKind.id3v2, '2.4')), isTrue);
        expect(result.containsKey((ContainerKind.id3v1, 'v1')), isTrue);

        // ID3v2.4 should have all tags
        final id3v24Tags = result[(ContainerKind.id3v2, '2.4')]!;
        expect(id3v24Tags, hasLength(3));

        // ID3v1 should have all tags (genre normalized to single value)
        final id3v1Tags = result[(ContainerKind.id3v1, 'v1')]!;
        expect(id3v1Tags, hasLength(3));

        // Check genre normalization for ID3v1 (should be single genre)
        final id3v1GenreTag = id3v1Tags.whereType<GenreTag>().first;
        expect(id3v1GenreTag.value, hasLength(1));
        expect(id3v1GenreTag.value.first, equals('Rock'));
      });

      test('handles missing capabilities gracefully', () {
        final strategy = const Mp3FormatStrategy();
        final capabilities = {
          // Only provide ID3v2.4 capability, missing ID3v1
          (ContainerKind.id3v2, '2.4'): id3v24Capability,
        };

        final inputTags = <MetadataTag>[const TitleTag('Test Title')];

        final result = preparation.prepareTagsForEncoding(
          tags: inputTags,
          strategy: strategy,
          capabilities: capabilities,
        );

        // Should only have ID3v2.4 tags (ID3v1 skipped due to missing capability)
        expect(result.keys, hasLength(1));
        expect(result.containsKey((ContainerKind.id3v2, '2.4')), isTrue);
      });
    });

    group('filterSupportedTags', () {
      test('filters out unsupported tags', () {
        final inputTags = <MetadataTag>[
          const TitleTag('Supported'),
          const ArtistTag('Supported'),
          ArtworkTag(
            ArtworkData(
              mimeType: 'image/jpeg',
              type: ArtworkType.frontCover,
              dataLoader: () async => Uint8List(0),
            ),
          ), // Not supported by ID3v1
          RatingTag(85), // Not supported by ID3v1
        ];

        final result = preparation.filterSupportedTags(inputTags, id3v1Capability);

        expect(result, hasLength(2));
        expect(result.every((tag) => id3v1Capability.supports(tag.key)), isTrue);
        expect(result.any((tag) => tag.key == TagKey.title), isTrue);
        expect(result.any((tag) => tag.key == TagKey.artist), isTrue);
        expect(result.any((tag) => tag.key == TagKey.artwork), isFalse);
        expect(result.any((tag) => tag.key == TagKey.rating), isFalse);
      });

      test('preserves all tags when all are supported', () {
        final inputTags = <MetadataTag>[
          const TitleTag('Test'),
          const ArtistTag('Test'),
          GenreTag(const ['Rock']),
        ];

        final result = preparation.filterSupportedTags(inputTags, vorbisCapability);

        expect(result, hasLength(3));
        expect(result, equals(inputTags));
      });
    });

    group('normalizeTagsForContainer', () {
      test('truncates text fields to maximum length', () {
        final inputTags = <MetadataTag>[
          const TitleTag('This title is way too long for ID3v1 format and needs truncation'),
          const ArtistTag('Short'), // Should not be truncated
        ];

        final result = preparation.normalizeTagsForContainer(inputTags, id3v1Capability);

        expect(result, hasLength(2));

        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value.length, equals(30));
        expect(titleTag.value, equals('This title is way too long for'));

        final artistTag = result.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Short')); // Unchanged
      });

      test('clamps numeric values to valid ranges', () {
        final inputTags = <MetadataTag>[
          TrackNumberTag(1), // Valid, within range
          TrackNumberTag(300), // Above maximum for ID3v1
          YearTag(2000), // Valid year
          YearTag(2050), // Valid year
        ];

        final result = preparation.normalizeTagsForContainer(inputTags, id3v1Capability);

        expect(result, hasLength(4));

        final trackTags = result.whereType<TrackNumberTag>().toList();
        expect(trackTags[0].value, equals(1)); // Unchanged (within range)
        expect(trackTags[1].value, equals(255)); // Clamped to maximum

        final yearTags = result.whereType<YearTag>().toList();
        expect(yearTags[0].value, equals(2000)); // Unchanged (within range)
        expect(yearTags[1].value, equals(2050)); // Unchanged (within range)
      });

      test('handles genre multi-value normalization', () {
        final inputTags = <MetadataTag>[
          GenreTag(const ['Rock', 'Alternative', 'Indie']),
        ];

        // Test with single-value container (ID3v1)
        final id3v1Result = preparation.normalizeTagsForContainer(inputTags, id3v1Capability);
        final id3v1GenreTag = id3v1Result.whereType<GenreTag>().first;
        expect(id3v1GenreTag.value, hasLength(1));
        expect(id3v1GenreTag.value.first, equals('Rock'));

        // Test with multi-value container (Vorbis)
        final vorbisResult = preparation.normalizeTagsForContainer(inputTags, vorbisCapability);
        final vorbisGenreTag = vorbisResult.whereType<GenreTag>().first;
        expect(vorbisGenreTag.value, hasLength(3));
        expect(vorbisGenreTag.value, containsAll(['Rock', 'Alternative', 'Indie']));
      });

      test('handles rating constraints for different containers', () {
        final inputTags = <MetadataTag>[RatingTag(85)]; // 0-100 scale

        // Test Vorbis (keeps 0-100 scale)
        final vorbisResult = preparation.normalizeTagsForContainer(inputTags, vorbisCapability);
        final vorbisRatingTag = vorbisResult.whereType<RatingTag>().first;
        expect(vorbisRatingTag.value, equals(85)); // Unchanged

        // Test ID3v2 (also keeps 0-100 scale at preparation level)
        final id3v24Result = preparation.normalizeTagsForContainer(inputTags, id3v24Capability);
        final id3v24RatingTag = id3v24Result.whereType<RatingTag>().first;
        expect(id3v24RatingTag.value, equals(85)); // Scale conversion happens at codec level
      });

      test('preserves tags when no normalization needed', () {
        final inputTags = <MetadataTag>[
          const TitleTag('Short Title'),
          TrackNumberTag(5),
          GenreTag(const ['Rock']),
        ];

        final result = preparation.normalizeTagsForContainer(inputTags, id3v24Capability);

        // Should return the same tag instances when no changes needed
        expect(result, hasLength(3));
        expect(result[0], same(inputTags[0])); // Title unchanged
        expect(result[1], same(inputTags[1])); // Track unchanged
        expect(result[2], same(inputTags[2])); // Genre unchanged
      });
    });

    group('edge cases', () {
      test('handles empty tag list', () {
        final result = preparation.prepareTagsForEncoding(
          tags: [],
          strategy: const Mp3FormatStrategy(),
          capabilities: {
            (ContainerKind.id3v2, '2.4'): id3v24Capability,
          },
        );

        expect(result.keys, hasLength(1));
        expect(result[(ContainerKind.id3v2, '2.4')], isEmpty);
      });

      test('handles zero-length text after truncation', () {
        final capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 0),
          },
        );

        final inputTags = <MetadataTag>[const TitleTag('Any Title')];

        final result = preparation.normalizeTagsForContainer(inputTags, capability);
        final titleTag = result.whereType<TitleTag>().first;

        expect(titleTag.value, isEmpty);
      });

      test('handles extreme numeric values', () {
        final inputTags = <MetadataTag>[
          TrackNumberTag(1000), // Above ID3v1 maximum
          YearTag(2080), // Valid year, will test with restrictive capability
        ];

        final result = preparation.normalizeTagsForContainer(inputTags, id3v1Capability);

        final trackTag = result.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(255)); // Clamped to ID3v1 maximum

        final yearTag = result.whereType<YearTag>().first;
        expect(yearTag.value, equals(2080)); // Unchanged (within YearTag validation range)
      });
    });
  });
}
