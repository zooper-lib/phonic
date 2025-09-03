import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_inference.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('TagInference', () {
    late TagInference inference;

    setUp(() {
      inference = const TagInference();
    });

    group('inferMissingTags', () {
      test('returns empty list for empty input', () {
        final result = inference.inferMissingTags([]);
        expect(result, isEmpty);
      });

      test('returns original tags when no inference is possible', () {
        final originalTags = [
          const TitleTag('Test Title'),
          const CommentTag('Test Comment'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(2));
        expect(result[0], equals(originalTags[0]));
        expect(result[1], equals(originalTags[1]));
      });

      test('preserves original tags when adding inferred tags', () {
        final originalTags = [
          const ArtistTag('The Beatles'),
          const TitleTag('Hey Jude'),
        ];

        final result = inference.inferMissingTags(originalTags);

        // Should contain original tags plus inferred AlbumArtistTag
        expect(result, hasLength(3));
        expect(result.sublist(0, 2), equals(originalTags));
      });
    });

    group('albumArtist inference', () {
      test('infers albumArtist from artist when albumArtist is missing', () {
        final originalTags = [
          const ArtistTag(
            'Pink Floyd',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          const TitleTag('Wish You Were Here'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(3));

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.value, equals('Pink Floyd'));
        expect(inferredAlbumArtist.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(inferredAlbumArtist.provenance.containerVersion, equals('2.4'));
        expect(inferredAlbumArtist.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('does not infer albumArtist when albumArtist already exists', () {
        final originalTags = [
          const ArtistTag('John Lennon'),
          const AlbumArtistTag('The Beatles'),
          const TitleTag('Imagine'),
        ];

        final result = inference.inferMissingTags(originalTags);

        // Should not add another AlbumArtistTag
        expect(result, hasLength(3));
        expect(result.whereType<AlbumArtistTag>(), hasLength(1));
        expect(result.whereType<AlbumArtistTag>().first.value, equals('The Beatles'));
      });

      test('does not infer albumArtist when artist is missing', () {
        final originalTags = [
          const TitleTag('Test Title'),
          const CommentTag('Test Comment'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(2));
        expect(result.whereType<AlbumArtistTag>(), isEmpty);
      });

      test('uses first artist tag when multiple artists exist', () {
        final originalTags = [
          const ArtistTag(
            'Primary Artist',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          const ArtistTag(
            'Secondary Artist',
            provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(3));

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.value, equals('Primary Artist'));
        expect(inferredAlbumArtist.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('preserves provenance from source artist tag', () {
        final originalTags = [
          const ArtistTag(
            'Test Artist',
            provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
        ];

        final result = inference.inferMissingTags(originalTags);

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.provenance.containerKind, equals(ContainerKind.vorbis));
        expect(inferredAlbumArtist.provenance.containerVersion, equals(''));
        expect(inferredAlbumArtist.provenance.confidence, equals(TagConfidence.inferred));
      });
    });

    group('year derivation', () {
      test('derives year from dateRecorded when year is missing', () {
        final originalTags = <MetadataTag>[
          DateRecordedTag(
            '1973-03-01',
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          const TitleTag('The Dark Side of the Moon'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(3));

        final derivedYear = result.whereType<YearTag>().first;
        expect(derivedYear.value, equals(1973));
        expect(derivedYear.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(derivedYear.provenance.containerVersion, equals('2.4'));
        expect(derivedYear.provenance.confidence, equals(TagConfidence.derived));
      });

      test('does not derive year when year already exists', () {
        final originalTags = <MetadataTag>[
          DateRecordedTag('1973-03-01'),
          YearTag(1973),
          const TitleTag('Test Title'),
        ];

        final result = inference.inferMissingTags(originalTags);

        // Should not add another YearTag
        expect(result, hasLength(3));
        expect(result.whereType<YearTag>(), hasLength(1));
        expect(result.whereType<YearTag>().first.value, equals(1973));
      });

      test('does not derive year when dateRecorded is missing', () {
        final originalTags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result.whereType<YearTag>(), isEmpty);
      });

      test('handles various ISO-8601 date formats', () {
        final testCases = [
          ('2023', 2023),
          ('2023-03', 2023),
          ('2023-03-15', 2023),
          ('2023-03-15T14:30:00', 2023),
          ('2023-03-15T14:30:00Z', 2023),
          ('2023-03-15T14:30:00+02:00', 2023),
          ('1969-08-15T00:00:00-04:00', 1969),
        ];

        for (final (dateString, expectedYear) in testCases) {
          final originalTags = <MetadataTag>[
            DateRecordedTag(
              dateString,
              provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
            ),
          ];

          final result = inference.inferMissingTags(originalTags);

          expect(result, hasLength(2), reason: 'Failed for date: $dateString');

          final derivedYear = result.whereType<YearTag>().first;
          expect(derivedYear.value, equals(expectedYear), reason: 'Failed for date: $dateString');
          expect(derivedYear.provenance.confidence, equals(TagConfidence.derived));
        }
      });

      test('uses first dateRecorded tag when multiple dates exist', () {
        final originalTags = <MetadataTag>[
          DateRecordedTag(
            '1975-10-31',
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          DateRecordedTag(
            '1976-01-01',
            provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(3));

        final derivedYear = result.whereType<YearTag>().first;
        expect(derivedYear.value, equals(1975));
        expect(derivedYear.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('preserves provenance from source dateRecorded tag', () {
        final originalTags = <MetadataTag>[
          DateRecordedTag(
            '1980-12-08',
            provenance: const TagProvenance(ContainerKind.mp4, '1.0', TagConfidence.certain),
          ),
        ];

        final result = inference.inferMissingTags(originalTags);

        final derivedYear = result.whereType<YearTag>().first;
        expect(derivedYear.provenance.containerKind, equals(ContainerKind.mp4));
        expect(derivedYear.provenance.containerVersion, equals('1.0'));
        expect(derivedYear.provenance.confidence, equals(TagConfidence.derived));
      });
    });

    group('combined inference', () {
      test('applies both albumArtist and year inference together', () {
        final originalTags = <MetadataTag>[
          const ArtistTag(
            'Queen',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          DateRecordedTag(
            '1975-10-31',
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          const TitleTag('Bohemian Rhapsody'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(5));

        // Check inferred AlbumArtist
        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.value, equals('Queen'));
        expect(inferredAlbumArtist.provenance.confidence, equals(TagConfidence.inferred));

        // Check derived Year
        final derivedYear = result.whereType<YearTag>().first;
        expect(derivedYear.value, equals(1975));
        expect(derivedYear.provenance.confidence, equals(TagConfidence.derived));
      });

      test('applies partial inference when only some rules match', () {
        final originalTags = [
          const ArtistTag('The Who'),
          const TitleTag('Baba O\'Riley'),
          // No DateRecorded, so no year derivation
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(3));

        // Should have inferred AlbumArtist but no Year
        expect(result.whereType<AlbumArtistTag>(), hasLength(1));
        expect(result.whereType<YearTag>(), isEmpty);

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.value, equals('The Who'));
      });
    });

    group('inferMissingTagsForContainer', () {
      test('applies same inference rules regardless of container', () {
        final originalTags = <MetadataTag>[
          const ArtistTag('Led Zeppelin'),
          DateRecordedTag('1971-11-08'),
        ];

        final id3Result = inference.inferMissingTagsForContainer(
          originalTags,
          ContainerKind.id3v2,
          '2.4',
        );

        final vorbisResult = inference.inferMissingTagsForContainer(
          originalTags,
          ContainerKind.vorbis,
          '',
        );

        // Both should produce the same inference results
        expect(id3Result, hasLength(4));
        expect(vorbisResult, hasLength(4));

        expect(id3Result.whereType<AlbumArtistTag>(), hasLength(1));
        expect(id3Result.whereType<YearTag>(), hasLength(1));
        expect(vorbisResult.whereType<AlbumArtistTag>(), hasLength(1));
        expect(vorbisResult.whereType<YearTag>(), hasLength(1));
      });
    });

    group('canInferTag', () {
      test('returns true for albumArtist when artist is available', () {
        final tags = [const ArtistTag('Test Artist')];

        final canInfer = inference.canInferTag(TagKey.albumArtist, tags);

        expect(canInfer, isTrue);
      });

      test('returns false for albumArtist when artist is missing', () {
        final tags = [const TitleTag('Test Title')];

        final canInfer = inference.canInferTag(TagKey.albumArtist, tags);

        expect(canInfer, isFalse);
      });

      test('returns false for albumArtist when albumArtist already exists', () {
        final tags = [
          const ArtistTag('Test Artist'),
          const AlbumArtistTag('Test Album Artist'),
        ];

        final canInfer = inference.canInferTag(TagKey.albumArtist, tags);

        expect(canInfer, isFalse);
      });

      test('returns true for year when dateRecorded is available', () {
        final tags = <MetadataTag>[DateRecordedTag('2023-03-15')];

        final canInfer = inference.canInferTag(TagKey.year, tags);

        expect(canInfer, isTrue);
      });

      test('returns false for year when dateRecorded is missing', () {
        final tags = [const TitleTag('Test Title')];

        final canInfer = inference.canInferTag(TagKey.year, tags);

        expect(canInfer, isFalse);
      });

      test('returns false for year when year already exists', () {
        final tags = <MetadataTag>[
          DateRecordedTag('2023-03-15'),
          YearTag(2023),
        ];

        final canInfer = inference.canInferTag(TagKey.year, tags);

        expect(canInfer, isFalse);
      });

      test('returns false for unsupported tag keys', () {
        final tags = <MetadataTag>[
          const ArtistTag('Test Artist'),
          DateRecordedTag('2023-03-15'),
        ];

        final canInferTitle = inference.canInferTag(TagKey.title, tags);
        final canInferComment = inference.canInferTag(TagKey.comment, tags);

        expect(canInferTitle, isFalse);
        expect(canInferComment, isFalse);
      });
    });

    group('getInferrableKeys', () {
      test('returns empty list when no inference is possible', () {
        final tags = [
          const TitleTag('Test Title'),
          const CommentTag('Test Comment'),
        ];

        final inferrable = inference.getInferrableKeys(tags);

        expect(inferrable, isEmpty);
      });

      test('returns albumArtist when artist is available', () {
        final tags = [const ArtistTag('Test Artist')];

        final inferrable = inference.getInferrableKeys(tags);

        expect(inferrable, equals([TagKey.albumArtist]));
      });

      test('returns year when dateRecorded is available', () {
        final tags = <MetadataTag>[DateRecordedTag('2023-03-15')];

        final inferrable = inference.getInferrableKeys(tags);

        expect(inferrable, equals([TagKey.year]));
      });

      test('returns both keys when both inferences are possible', () {
        final tags = <MetadataTag>[
          const ArtistTag('Test Artist'),
          DateRecordedTag('2023-03-15'),
        ];

        final inferrable = inference.getInferrableKeys(tags);

        expect(inferrable, containsAll([TagKey.albumArtist, TagKey.year]));
        expect(inferrable, hasLength(2));
      });

      test('excludes keys that already exist', () {
        final tags = <MetadataTag>[
          const ArtistTag('Test Artist'),
          const AlbumArtistTag('Test Album Artist'), // Already exists
          DateRecordedTag('2023-03-15'),
        ];

        final inferrable = inference.getInferrableKeys(tags);

        expect(inferrable, equals([TagKey.year]));
      });
    });

    group('edge cases', () {
      test('handles empty artist value gracefully', () {
        final originalTags = [
          const ArtistTag(''), // Empty artist
          const TitleTag('Test Title'),
        ];

        final result = inference.inferMissingTags(originalTags);

        // Should still infer AlbumArtist even with empty artist
        expect(result, hasLength(3));

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.value, equals(''));
      });

      test('handles tags with none provenance', () {
        final originalTags = <MetadataTag>[
          const ArtistTag('Test Artist'), // Uses TagProvenance.none() by default
          DateRecordedTag('2023-03-15'),
        ];

        final result = inference.inferMissingTags(originalTags);

        expect(result, hasLength(4));

        final inferredAlbumArtist = result.whereType<AlbumArtistTag>().first;
        expect(inferredAlbumArtist.provenance.containerKind, equals(ContainerKind.none));
        expect(inferredAlbumArtist.provenance.confidence, equals(TagConfidence.inferred));

        final derivedYear = result.whereType<YearTag>().first;
        expect(derivedYear.provenance.containerKind, equals(ContainerKind.none));
        expect(derivedYear.provenance.confidence, equals(TagConfidence.derived));
      });
    });
  });
}
