import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('TitleTag', () {
    group('constructor', () {
      test('creates instance with title value and default provenance', () {
        const tag = TitleTag('My Song Title');

        expect(tag.value, equals('My Song Title'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with title value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = TitleTag('My Song Title', provenance: provenance);

        expect(tag.value, equals('My Song Title'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty title', () {
        const tag = TitleTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = TitleTag('🎵 Song Title with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 Song Title with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.title));
      });

      test('creates instance with very long title', () {
        final longTitle = 'A' * 1000;
        final tag = TitleTag(longTitle);

        expect(tag.value, equals(longTitle));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.title));
      });

      test('key is always TagKey.title', () {
        const tag1 = TitleTag('Title 1');
        const tag2 = TitleTag('Title 2');
        const tag3 = TitleTag('');

        expect(tag1.key, equals(TagKey.title));
        expect(tag2.key, equals(TagKey.title));
        expect(tag3.key, equals(TagKey.title));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = TitleTag(
          'Const Title',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Title'));
        expect(tag.key, equals(TagKey.title));
      });
    });

    group('withProvenance', () {
      test('returns new TitleTag instance with updated provenance', () {
        const originalTag = TitleTag(
          'Original Title',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Title'));
        expect(originalTag.key, equals(TagKey.title));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Title'));
        expect(updatedTag.key, equals(TagKey.title));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns TitleTag type specifically', () {
        const originalTag = TitleTag('Test Title');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<TitleTag>());
        expect(updatedTag.runtimeType, equals(TitleTag));
      });

      test('preserves title value exactly', () {
        const originalTag = TitleTag('Complex Title: éñ中文🎵 with special chars');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag.value, equals(originalTag.value));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance, equals(newProvenance));
      });

      test('works with TagProvenance.none()', () {
        const originalTag = TitleTag(
          'Test Title',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        const originalTag = TitleTag('Test Title');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Title'));
          expect(updatedTag.key, equals(TagKey.title));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = TitleTag('Test Title');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Title'));
          expect(updatedTag.key, equals(TagKey.title));
        }
      });
    });

    group('equality', () {
      test('equal instances with same title, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = TitleTag('Same Title', provenance: provenance);
        const tag2 = TitleTag('Same Title', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different titles', () {
        const tag1 = TitleTag('Title 1');
        const tag2 = TitleTag('Title 2');

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different provenance', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v1,
          'v1',
          TagConfidence.certain,
        );

        const tag1 = TitleTag('Same Title', provenance: provenance1);
        const tag2 = TitleTag('Same Title', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = TitleTag('Test Title');
        const tag2 = TitleTag('Test Title');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty titles', () {
        const tag1 = TitleTag('');
        const tag2 = TitleTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = TitleTag('Title');
        const tag2 = TitleTag('title');
        const tag3 = TitleTag('TITLE');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag2, isNot(equals(tag3)));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        const tag = TitleTag('Test Title', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Title'));
        expect(tag.props[1], equals(TagKey.title));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = TitleTag('Same Title');
        const tag2 = TitleTag('Same Title');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and title', () {
        const tag = TitleTag('My Song Title');
        final result = tag.toString();

        expect(result, contains('TitleTag'));
        expect(result, contains('My Song Title'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = TitleTag('Test Title', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('TitleTag'));
        expect(result, contains('Test Title'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in title', () {
        const tag = TitleTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty title', () {
        const tag = TitleTag('');
        final result = tag.toString();

        expect(result, contains('TitleTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = TitleTag(
          'Immutable Title',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Title'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = TitleTag('Original Title');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Title'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Title'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = TitleTag('String Title');
        const tag2 = TitleTag('');
        const tag3 = TitleTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains TitleTag type', () {
        const originalTag = TitleTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<TitleTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(TitleTag));
      });
    });

    group('edge cases', () {
      test('handles very long title values', () {
        final longTitle = 'A' * 10000;
        final tag = TitleTag(longTitle);

        expect(tag.value, equals(longTitle));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.title));
      });

      test('handles unicode and emoji in title values', () {
        const tag = TitleTag('🎵 Music Title with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Music Title with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only titles', () {
        const tag1 = TitleTag(' ');
        const tag2 = TitleTag('   ');
        const tag3 = TitleTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles titles with quotes and special formatting', () {
        const tag1 = TitleTag('"Quoted Title"');
        const tag2 = TitleTag("'Single Quoted'");
        const tag3 = TitleTag('Title with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Title"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Title with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = TitleTag('Test Title');

        expect(tag, isA<TitleTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = TitleTag('Same Title');
        const tag2 = TitleTag('Same Title');
        const tag3 = TitleTag('Different Title');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = TitleTag('Test Title');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'TitleTag\(.*\)'));
        expect(result, contains('Test Title'));
        expect(result, contains('provenance:'));
      });
    });
  });
}
