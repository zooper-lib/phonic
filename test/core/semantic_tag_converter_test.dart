import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/semantic_tag_converter.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('SemanticTagConverter', () {
    late SemanticTagConverter converter;

    setUp(() {
      converter = const SemanticTagConverter();
    });

    group('convertForTargetVersion', () {
      test('converts YearTag to DateRecordedTag for ID3v2.4 target', () {
        final sourceTags = <MetadataTag>[
          YearTag(
            2020,
            provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        final dateTag = result.first as DateRecordedTag;
        expect(dateTag.value, equals('2020'));
        expect(dateTag.provenance.confidence, equals(TagConfidence.derived));
        expect(dateTag.provenance.containerKind, equals(ContainerKind.id3v1));
      });

      test('preserves DateRecordedTag for ID3v2.4 target', () {
        final sourceTags = <MetadataTag>[
          DateRecordedTag(
            '2020-03-15',
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        final dateTag = result.first as DateRecordedTag;
        expect(dateTag.value, equals('2020-03-15'));
        expect(dateTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('resolves Year/DateRecorded conflict for ID3v2.4 target', () {
        final sourceTags = <MetadataTag>[
          YearTag(
            2020,
            provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
          DateRecordedTag(
            '2020-03-15',
            provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
          ),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        // Should resolve to single DateRecordedTag (more precise)
        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        final dateTag = result.first as DateRecordedTag;
        expect(dateTag.value, equals('2020-03-15'));
        expect(dateTag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('preserves YearTag for ID3v2.3 target (no TDRC conflict)', () {
        final sourceTags = <MetadataTag>[
          YearTag(
            2020,
            provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.3')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        // Should keep YearTag as-is (no conversion needed for ID3v2.3)
        expect(result, hasLength(1));
        expect(result.first, isA<YearTag>());
        final yearTag = result.first as YearTag;
        expect(yearTag.value, equals(2020));
        expect(yearTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('handles multiple Year tags by keeping highest precedence', () {
        final sourceTags = <MetadataTag>[
          YearTag(
            2019,
            provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
          ),
          YearTag(
            2020,
            provenance: const TagProvenance(ContainerKind.id3v2, '2.3', TagConfidence.certain),
          ),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        // Should convert to single DateRecordedTag with highest precedence year
        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        final dateTag = result.first as DateRecordedTag;
        expect(dateTag.value, equals('2020')); // ID3v2 has higher precedence than ID3v1
      });

      test('preserves non-conflicting tags unchanged', () {
        final sourceTags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          YearTag(2020),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        expect(result, hasLength(3));

        final titles = result.whereType<TitleTag>().toList();
        final artists = result.whereType<ArtistTag>().toList();
        final dates = result.whereType<DateRecordedTag>().toList();

        expect(titles, hasLength(1));
        expect(artists, hasLength(1));
        expect(dates, hasLength(1)); // YearTag converted to DateRecordedTag

        expect(titles.first.value, equals('Test Title'));
        expect(artists.first.value, equals('Test Artist'));
        expect(dates.first.value, equals('2020'));
      });

      test('handles empty tag list', () {
        final result = converter.convertForTargetVersion([], [(ContainerKind.id3v2, '2.4')]);
        expect(result, isEmpty);
      });

      test('handles empty target containers', () {
        final sourceTags = <MetadataTag>[YearTag(2020)];
        final result = converter.convertForTargetVersion(sourceTags, []);
        expect(result, equals(sourceTags));
      });
    });

    group('areTagsSemanticallyEquivalent', () {
      test('recognizes equivalent Year and DateRecorded tags', () {
        final yearTag = YearTag(2020);
        final dateTag = DateRecordedTag('2020');

        final result = converter.areTagsSemanticallyEquivalent(yearTag, dateTag);
        expect(result, isTrue);
      });

      test('recognizes equivalent Year and full DateRecorded tags', () {
        final yearTag = YearTag(2020);
        final dateTag = DateRecordedTag('2020-03-15');

        final result = converter.areTagsSemanticallyEquivalent(yearTag, dateTag);
        expect(result, isTrue);
      });

      test('recognizes non-equivalent Year and DateRecorded tags', () {
        final yearTag = YearTag(2020);
        final dateTag = DateRecordedTag('2019');

        final result = converter.areTagsSemanticallyEquivalent(yearTag, dateTag);
        expect(result, isFalse);
      });

      test('recognizes equivalent same-type tags', () {
        final tag1 = YearTag(2020);
        final tag2 = YearTag(2020);

        final result = converter.areTagsSemanticallyEquivalent(tag1, tag2);
        expect(result, isTrue);
      });

      test('recognizes non-equivalent same-type tags', () {
        final tag1 = YearTag(2020);
        final tag2 = YearTag(2019);

        final result = converter.areTagsSemanticallyEquivalent(tag1, tag2);
        expect(result, isFalse);
      });

      test('recognizes non-equivalent different types', () {
        final yearTag = YearTag(2020);
        final titleTag = const TitleTag('2020');

        final result = converter.areTagsSemanticallyEquivalent(yearTag, titleTag);
        expect(result, isFalse);
      });
    });

    group('resolveFrameConflicts', () {
      test('resolves Year/DateRecorded conflict with DateRecorded priority', () {
        final tags = <MetadataTag>[
          YearTag(2020, provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
          DateRecordedTag('2020-03-15', provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.resolveFrameConflicts(tags, targetContainers);

        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        expect((result.first as DateRecordedTag).value, equals('2020-03-15'));
      });

      test('converts single YearTag when no DateRecorded present', () {
        final tags = <MetadataTag>[
          YearTag(2020, provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.resolveFrameConflicts(tags, targetContainers);

        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        expect((result.first as DateRecordedTag).value, equals('2020'));
        expect(result.first.provenance.confidence, equals(TagConfidence.derived));
      });

      test('preserves single DateRecorded when no Year present', () {
        final tags = <MetadataTag>[
          DateRecordedTag('2020-03-15', provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.resolveFrameConflicts(tags, targetContainers);

        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        expect((result.first as DateRecordedTag).value, equals('2020-03-15'));
        expect(result.first.provenance.confidence, equals(TagConfidence.certain));
      });

      test('passes through tags when no ID3v2.4 target', () {
        final tags = <MetadataTag>[
          YearTag(2020),
          DateRecordedTag('2020-03-15'),
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.3')];

        final result = converter.resolveFrameConflicts(tags, targetContainers);

        expect(result, hasLength(2));
        expect(result.whereType<YearTag>(), hasLength(1));
        expect(result.whereType<DateRecordedTag>(), hasLength(1));
      });
    });

    group('edge cases', () {
      test('handles edge case date formats', () {
        final tags = <MetadataTag>[
          YearTag(2020),
          DateRecordedTag('2020-03'), // Month precision
        ];
        final targetContainers = [(ContainerKind.id3v2, '2.4')];

        final result = converter.convertForTargetVersion(tags, targetContainers);

        // Should resolve conflict, keeping DateRecorded (more precise)
        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
        expect((result.first as DateRecordedTag).value, equals('2020-03'));
      });

      test('handles multiple target containers', () {
        final sourceTags = <MetadataTag>[YearTag(2020)];
        final targetContainers = [
          (ContainerKind.id3v2, '2.3'),
          (ContainerKind.id3v2, '2.4'),
          (ContainerKind.id3v1, 'v1'),
        ];

        final result = converter.convertForTargetVersion(sourceTags, targetContainers);

        // Should convert because one target is ID3v2.4
        expect(result, hasLength(1));
        expect(result.first, isA<DateRecordedTag>());
      });
    });
  });
}
