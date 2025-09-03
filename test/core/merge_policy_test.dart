import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/id3v1_capability.dart';
import 'package:phonic/src/capabilities/id3v24_capability.dart';
import 'package:phonic/src/capabilities/vorbis_capability.dart';
import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_merger.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';

void main() {
  group('MergePolicy', () {
    late MergePolicy policy;
    late Mp3FormatStrategy strategy;

    setUp(() {
      strategy = const Mp3FormatStrategy();
      policy = MergePolicy.fromStrategy(strategy);
    });

    group('constructor', () {
      test('creates policy with strategy', () {
        final customPolicy = MergePolicy(strategy);
        expect(customPolicy.strategy, equals(strategy));
      });

      test('creates policy with custom merger', () {
        final customMerger = const TagMerger();
        final customPolicy = MergePolicy(strategy, merger: customMerger);
        expect(customPolicy.merger, equals(customMerger));
      });

      test('fromStrategy factory creates policy with default merger', () {
        final factoryPolicy = MergePolicy.fromStrategy(strategy);
        expect(factoryPolicy.strategy, equals(strategy));
        expect(factoryPolicy.merger, isA<TagMerger>());
      });
    });

    group('precedenceFor', () {
      test('returns strategy precedence for matching media kind', () {
        final precedence = policy.precedenceFor(MediaKind.mp3);
        expect(precedence, equals(strategy.precedence));
        expect(precedence, hasLength(4));
        expect(precedence[0], equals((ContainerKind.id3v2, '2.4')));
        expect(precedence[1], equals((ContainerKind.id3v2, '2.3')));
        expect(precedence[2], equals((ContainerKind.id3v2, '2.2')));
        expect(precedence[3], equals((ContainerKind.id3v1, 'v1')));
      });

      test('returns empty list for non-matching media kind', () {
        final precedence = policy.precedenceFor(MediaKind.flac);
        expect(precedence, isEmpty);
      });

      test('returns empty list for unsupported media kind', () {
        final precedence = policy.precedenceFor(MediaKind.m4a);
        expect(precedence, isEmpty);
      });
    });

    group('writeFanout', () {
      test('returns strategy fanout for matching media kind', () {
        final fanout = policy.writeFanout(MediaKind.mp3);
        expect(fanout, equals(strategy.fanout));
        expect(fanout, hasLength(2));
        expect(fanout[0], equals((ContainerKind.id3v2, '2.4')));
        expect(fanout[1], equals((ContainerKind.id3v1, 'v1')));
      });

      test('returns empty list for non-matching media kind', () {
        final fanout = policy.writeFanout(MediaKind.flac);
        expect(fanout, isEmpty);
      });

      test('returns empty list for unsupported media kind', () {
        final fanout = policy.writeFanout(MediaKind.ogg);
        expect(fanout, isEmpty);
      });
    });

    group('normalizeForTarget', () {
      test('returns null for unsupported tag', () {
        final artworkTag = ArtworkTag(
          ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => Uint8List.fromList([1, 2, 3]),
          ),
        );

        final normalized = policy.normalizeForTarget(artworkTag, id3v1Capability);
        expect(normalized, isNull);
      });

      test('returns original tag when no normalization needed', () {
        const titleTag = TitleTag('Short Title');

        final normalized = policy.normalizeForTarget(titleTag, id3v24Capability);
        expect(normalized, equals(titleTag));
      });

      test('truncates text tags that exceed length limits', () {
        const longTitle = 'This is a very long title that definitely exceeds the thirty character limit';
        const titleTag = TitleTag(longTitle);

        final normalized = policy.normalizeForTarget(titleTag, id3v1Capability);
        expect(normalized, isA<TitleTag>());
        expect((normalized as TitleTag).value, hasLength(30));
        expect(normalized.value, equals(longTitle.substring(0, 30)));
        expect(normalized.provenance, equals(titleTag.provenance));
      });

      test('clamps numeric tags to valid ranges', () {
        final highRating = RatingTag(100); // At max limit

        // Create a capability with lower max rating
        const restrictiveCapability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.rating: TagSemantics(minValue: 0, maxValue: 50), // Lower max
          },
        );

        final normalized = policy.normalizeForTarget(highRating, restrictiveCapability);
        expect(normalized, isA<RatingTag>());
        expect((normalized as RatingTag).value, equals(50)); // Clamped to capability max
        expect(normalized.provenance, equals(highRating.provenance));
      });

      test('clamps numeric tags to minimum values', () {
        final lowTrack = TrackNumberTag(1); // At minimum

        // Create a capability with higher minimum
        const restrictiveCapability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.trackNumber: TagSemantics(minValue: 5, maxValue: 999), // Higher min
          },
        );

        final normalized = policy.normalizeForTarget(lowTrack, restrictiveCapability);
        expect(normalized, isA<TrackNumberTag>());
        expect((normalized as TrackNumberTag).value, equals(5)); // Clamped to capability min
        expect(normalized.provenance, equals(lowTrack.provenance));
      });

      test('converts multi-genre to single genre for non-multi-valued containers', () {
        final multiGenre = GenreTag(const ['Rock', 'Alternative', 'Indie']);

        final normalized = policy.normalizeForTarget(multiGenre, id3v1Capability);
        expect(normalized, isA<GenreTag>());
        expect((normalized as GenreTag).value, hasLength(1));
        expect(normalized.value.first, equals('Rock'));
        expect(normalized.provenance, equals(multiGenre.provenance));
      });

      test('preserves multi-genre for multi-valued containers', () {
        final multiGenre = GenreTag(const ['Rock', 'Alternative', 'Indie']);

        final normalized = policy.normalizeForTarget(multiGenre, vorbisCapability);
        expect(normalized, equals(multiGenre));
      });

      test('handles all text tag types', () {
        const longText = 'This is a very long text that exceeds limits';

        final tags = [
          const TitleTag(longText),
          const ArtistTag(longText),
          const AlbumTag(longText),
          const AlbumArtistTag(longText),
          const CommentTag(longText),
          const GroupingTag(longText),
          const ComposerTag(longText),
          const EncoderTag(longText),
          const IsrcTag(longText),
          const MusicalKeyTag(longText),
          const LyricsTag(longText),
          const CustomTag(longText),
        ];

        for (final tag in tags) {
          final normalized = policy.normalizeForTarget(tag, id3v1Capability);
          if (normalized != null) {
            expect((normalized.value as String).length, lessThanOrEqualTo(30));
          }
        }
      });

      test('handles all numeric tag types', () {
        final tags = [
          TrackNumberTag(50), // Valid value
          DiscNumberTag(10), // Valid value
          YearTag(2000), // Valid value
          BpmTag(120), // Valid value
          RatingTag(80), // Valid value
        ];

        for (final tag in tags) {
          final normalized = policy.normalizeForTarget(tag, id3v24Capability);
          expect(normalized, isNotNull);
          expect(normalized!.value, isA<int>());
        }
      });

      test('preserves provenance in normalized tags', () {
        const provenance = TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);
        const longTitle = TitleTag('This is a very long title that exceeds limits', provenance: provenance);

        final normalized = policy.normalizeForTarget(longTitle, id3v1Capability);
        expect(normalized!.provenance, equals(provenance));
      });
    });

    group('normalizeAllForTarget', () {
      test('normalizes all supported tags', () {
        final tags = <MetadataTag>[
          const TitleTag('Valid Title'),
          const ArtistTag('Valid Artist'),
          ArtworkTag(
            ArtworkData(
              mimeType: 'image/jpeg',
              type: ArtworkType.frontCover,
              dataLoader: () async => Uint8List.fromList([1, 2, 3]),
            ),
          ),
        ];

        final normalized = policy.normalizeAllForTarget(tags, id3v1Capability);
        expect(normalized, hasLength(2)); // Artwork filtered out
        expect(normalized[0], isA<TitleTag>());
        expect(normalized[1], isA<ArtistTag>());
      });

      test('returns empty list when no tags are supported', () {
        final tags = <MetadataTag>[
          ArtworkTag(
            ArtworkData(
              mimeType: 'image/jpeg',
              type: ArtworkType.frontCover,
              dataLoader: () async => Uint8List.fromList([1, 2, 3]),
            ),
          ),
          const CustomTag('Custom field'),
        ];

        final normalized = policy.normalizeAllForTarget(tags, id3v1Capability);
        expect(normalized, isEmpty);
      });

      test('applies normalization to each tag', () {
        const longText = 'This is a very long title that exceeds the thirty character limit';
        final tags = [
          const TitleTag(longText),
          const ArtistTag(longText),
        ];

        final normalized = policy.normalizeAllForTarget(tags, id3v1Capability);
        expect(normalized, hasLength(2));
        expect((normalized[0].value as String).length, equals(30));
        expect((normalized[1].value as String).length, equals(30));
      });
    });

    group('mergeWithPrecedence', () {
      test('merges tags using format precedence', () {
        final tagsByContainer = <ContainerKind, List<MetadataTag>>{
          ContainerKind.id3v2: [
            const TitleTag('ID3v2 Title', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
            GenreTag(const ['Rock'], provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
          ],
          ContainerKind.id3v1: [
            const TitleTag('ID3v1 Title', provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
            GenreTag(const ['Pop'], provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
          ],
        };

        final merged = policy.mergeWithPrecedence(tagsByContainer, MediaKind.mp3);
        expect(merged, hasLength(2));

        final titleTag = merged.firstWhere((tag) => tag.key == TagKey.title) as TitleTag;
        expect(titleTag.value, equals('ID3v2 Title')); // Higher precedence

        final genreTag = merged.firstWhere((tag) => tag.key == TagKey.genre) as GenreTag;
        expect(genreTag.value, contains('Rock')); // Higher precedence
      });

      test('returns empty list for unsupported media kind', () {
        final tagsByContainer = <ContainerKind, List<MetadataTag>>{
          ContainerKind.id3v2: [const TitleTag('Title')],
        };

        final merged = policy.mergeWithPrecedence(tagsByContainer, MediaKind.flac);
        expect(merged, isEmpty);
      });

      test('handles empty container map', () {
        final merged = policy.mergeWithPrecedence({}, MediaKind.mp3);
        expect(merged, isEmpty);
      });

      test('merges genre tags correctly', () {
        final tagsByContainer = <ContainerKind, List<MetadataTag>>{
          ContainerKind.id3v2: [
            GenreTag(const ['Rock', 'Alternative'], provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
          ],
          ContainerKind.id3v1: [
            GenreTag(const ['Pop'], provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
          ],
        };

        final merged = policy.mergeWithPrecedence(tagsByContainer, MediaKind.mp3);
        expect(merged, hasLength(1));

        final genreTag = merged.first as GenreTag;
        expect(genreTag.value, containsAll(['Rock', 'Alternative', 'Pop']));
      });
    });

    group('property access', () {
      test('provides access to strategy', () {
        expect(policy.strategy, equals(strategy));
      });

      test('provides access to merger', () {
        expect(policy.merger, isA<TagMerger>());
      });
    });

    group('edge cases', () {
      test('handles tags with no constraints gracefully', () {
        const titleTag = TitleTag('Any Title');

        // Create capability with no constraints
        const unconstrainedCapability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(), // No constraints
          },
        );

        final normalized = policy.normalizeForTarget(titleTag, unconstrainedCapability);
        expect(normalized, equals(titleTag));
      });

      test('handles zero-length text gracefully', () {
        const emptyTitle = TitleTag('');

        final normalized = policy.normalizeForTarget(emptyTitle, id3v1Capability);
        expect(normalized, equals(emptyTitle));
      });

      test('handles boundary values for numeric constraints', () {
        final boundaryRating = RatingTag(100); // Exactly at max

        final normalized = policy.normalizeForTarget(boundaryRating, id3v24Capability);
        expect(normalized, equals(boundaryRating));
      });

      test('handles single-genre tags with multi-value containers', () {
        final singleGenre = GenreTag.single('Rock');

        final normalized = policy.normalizeForTarget(singleGenre, vorbisCapability);
        expect(normalized, equals(singleGenre));
      });
    });
  });
}
