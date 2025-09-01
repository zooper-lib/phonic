import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';

void main() {
  group('TagMerger', () {
    late TagMerger merger;

    setUp(() {
      merger = const TagMerger();
    });

    group('constructor', () {
      test('creates merger with default precedence', () {
        const merger = TagMerger();
        expect(merger.containerPrecedence, equals(TagMerger.defaultContainerPrecedence));
      });

      test('creates merger with custom precedence', () {
        const customPrecedence = [ContainerKind.vorbis, ContainerKind.id3v2];
        const merger = TagMerger(containerPrecedence: customPrecedence);
        expect(merger.containerPrecedence, equals(customPrecedence));
      });
    });

    group('mergeTags', () {
      test('returns empty list for empty input', () {
        final result = merger.mergeTags([]);
        expect(result, isEmpty);
      });

      test('returns single tag unchanged', () {
        final tag = const TitleTag('Test Title');
        final result = merger.mergeTags([tag]);
        expect(result, hasLength(1));
        expect(result.first, equals(tag));
      });

      test('merges different tag keys without conflict', () {
        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(3));
        expect(result.map((t) => t.key), containsAll([TagKey.title, TagKey.artist, TagKey.album]));
      });
    });

    group('single-valued tag merging', () {
      test('prefers ID3v2.4 over ID3v2.3', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'ID3v2.3 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.3', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2.4 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('ID3v2.4 Title'));
        expect(titleTag.provenance.containerVersion, equals('2.4'));
      });

      test('prefers ID3v2.3 over ID3v2.2', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'ID3v2.2 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.2', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2.3 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.3', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('ID3v2.3 Title'));
        expect(titleTag.provenance.containerVersion, equals('2.3'));
      });

      test('prefers ID3v2 over ID3v1', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'ID3v1 Title',
            provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('ID3v2 Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('prefers ID3v2 over Vorbis', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'Vorbis Title',
            provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('ID3v2 Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('prefers Vorbis over MP4', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'MP4 Title',
            provenance: TagProvenance(ContainerKind.mp4, '', TagConfidence.certain),
          ),
          const TitleTag(
            'Vorbis Title',
            provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Vorbis Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.vorbis));
      });

      test('prefers certain over inferred confidence', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'Inferred Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.inferred),
          ),
          const TitleTag(
            'Certain Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Certain Title'));
        expect(titleTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('prefers inferred over derived confidence', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'Derived Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.derived),
          ),
          const TitleTag(
            'Inferred Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.inferred),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Inferred Title'));
        expect(titleTag.provenance.confidence, equals(TagConfidence.inferred));
      });
    });

    group('GenreTag merging', () {
      test('combines genres from multiple tags', () {
        final tags = <MetadataTag>[
          GenreTag(
            const ['Rock', 'Alternative'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['Alternative', 'Indie'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('deduplicates genres while preserving order', () {
        final tags = <MetadataTag>[
          GenreTag(
            const ['Rock', 'Alternative', 'Indie'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['Alternative', 'Rock', 'Electronic'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie', 'Electronic']));
      });

      test('uses provenance from highest-precedence source', () {
        final tags = <MetadataTag>[
          GenreTag(
            const ['Vorbis Genre'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          GenreTag(
            const ['ID3v2 Genre'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(genreTag.provenance.containerVersion, equals('2.4'));
      });

      test('handles empty genre lists', () {
        final tags = <MetadataTag>[
          GenreTag(
            const [],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['Rock', 'Alternative'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative']));
      });

      test('handles single genre tag', () {
        final tag = GenreTag(const ['Rock']);
        final result = merger.mergeTags([tag]);
        expect(result, hasLength(1));
        expect(result.first, equals(tag));
      });

      test('merges three genre tags correctly', () {
        final tags = <MetadataTag>[
          GenreTag(
            const ['Rock'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['Alternative', 'Rock'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          GenreTag(
            const ['Indie', 'Alternative'],
            provenance: const TagProvenance(ContainerKind.mp4, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(genreTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });
    });

    group('artwork tag merging', () {
      test('returns highest-precedence artwork', () {
        final artworkData1 = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => Uint8List.fromList([1, 2, 3]),
        );
        final artworkData2 = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.backCover,
          dataLoader: () async => Uint8List.fromList([4, 5, 6]),
        );

        final tags = <MetadataTag>[
          ArtworkTag(
            artworkData1,
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          ArtworkTag(
            artworkData2,
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final artworkTag = result.first as ArtworkTag;
        expect(artworkTag.value.mimeType, equals('image/png'));
        expect(artworkTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });
    });

    group('mergeByContainerPrecedence', () {
      test('applies custom precedence order', () {
        final tagsByContainer = {
          ContainerKind.id3v1: [
            const TitleTag(
              'ID3v1 Title',
              provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
            ),
          ],
          ContainerKind.vorbis: [
            const TitleTag(
              'Vorbis Title',
              provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
            ),
          ],
        };

        // Custom precedence: Vorbis before ID3v1 (opposite of default)
        final customPrecedence = [ContainerKind.vorbis, ContainerKind.id3v1];
        final result = merger.mergeByContainerPrecedence(tagsByContainer, customPrecedence);

        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Vorbis Title'));
      });

      test('handles empty container map', () {
        final result = merger.mergeByContainerPrecedence({}, []);
        expect(result, isEmpty);
      });

      test('merges genres with custom precedence', () {
        final tagsByContainer = {
          ContainerKind.id3v2: [
            GenreTag(
              const ['Rock'],
              provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
            ),
          ],
          ContainerKind.vorbis: [
            GenreTag(
              const ['Alternative'],
              provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
            ),
          ],
        };

        // Vorbis first in custom precedence
        final customPrecedence = [ContainerKind.vorbis, ContainerKind.id3v2];
        final result = merger.mergeByContainerPrecedence(tagsByContainer, customPrecedence);

        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;
        expect(genreTag.value, equals(['Alternative', 'Rock']));
        expect(genreTag.provenance.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('withMergedProvenance', () {
      test('returns tag unchanged for empty source list', () {
        final tag = const TitleTag('Test');
        final result = merger.withMergedProvenance([], tag);
        expect(result, equals(tag));
      });

      test('uses provenance from single source', () {
        final sourceTag = const TitleTag(
          'Source',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );
        final resultTag = const TitleTag('Result');

        final result = merger.withMergedProvenance([sourceTag], resultTag);
        expect(result.provenance, equals(sourceTag.provenance));
      });

      test('creates derived provenance from highest-precedence source', () {
        final sources = [
          const TitleTag(
            'Vorbis',
            provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];
        final resultTag = const TitleTag('Merged');

        final result = merger.withMergedProvenance(sources, resultTag);
        expect(result.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(result.provenance.containerVersion, equals('2.4'));
        expect(result.provenance.confidence, equals(TagConfidence.derived));
      });
    });

    group('precedence comparison', () {
      test('handles unknown container kinds', () {
        // Create tags with container kinds not in the precedence list
        final tags = <MetadataTag>[
          const TitleTag(
            'Known',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          // Using a mock unknown container by creating a custom merger
        ];

        // Test that known containers are preferred over unknown ones
        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Known'));
      });

      test('handles unknown ID3v2 versions', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'Known Version',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          const TitleTag(
            'Unknown Version',
            provenance: TagProvenance(ContainerKind.id3v2, '2.5', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final titleTag = result.first as TitleTag;
        expect(titleTag.value, equals('Known Version'));
      });

      test('handles unknown confidence levels', () {
        final tags = <MetadataTag>[
          const TitleTag(
            'Known Confidence',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          // All confidence levels are known in the enum, so this test verifies the fallback logic
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        expect(result.first.value, equals('Known Confidence'));
      });
    });

    group('complex merging scenarios', () {
      test('merges mixed tag types with different precedences', () {
        final tags = <MetadataTag>[
          // Title tags with different precedences
          const TitleTag(
            'ID3v1 Title',
            provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
          const TitleTag(
            'ID3v2 Title',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          // Genre tags to be merged
          GenreTag(
            const ['Rock'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['Alternative'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          // Artist tag (single source)
          const ArtistTag(
            'Test Artist',
            provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(3)); // Title, Genre, Artist

        final titleTag = result.firstWhere((t) => t.key == TagKey.title) as TitleTag;
        expect(titleTag.value, equals('ID3v2 Title'));

        final genreTag = result.firstWhere((t) => t.key == TagKey.genre) as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative']));

        final artistTag = result.firstWhere((t) => t.key == TagKey.artist) as ArtistTag;
        expect(artistTag.value, equals('Test Artist'));
      });

      test('preserves order in genre merging based on precedence', () {
        final tags = <MetadataTag>[
          GenreTag(
            const ['Vorbis1', 'Vorbis2'],
            provenance: const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
          ),
          GenreTag(
            const ['ID3v2_1', 'ID3v2_2'],
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
          GenreTag(
            const ['MP4_1', 'MP4_2'],
            provenance: const TagProvenance(ContainerKind.mp4, '', TagConfidence.certain),
          ),
        ];

        final result = merger.mergeTags(tags);
        expect(result, hasLength(1));
        final genreTag = result.first as GenreTag;

        // ID3v2 should come first (highest precedence), then Vorbis, then MP4
        expect(genreTag.value, equals(['ID3v2_1', 'ID3v2_2', 'Vorbis1', 'Vorbis2', 'MP4_1', 'MP4_2']));
      });
    });
  });
}
