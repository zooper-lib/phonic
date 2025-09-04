import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('GroupingTag', () {
    group('constructor', () {
      test('creates instance with grouping value and default provenance', () {
        const tag = GroupingTag('Symphony No. 9 in D minor');

        expect(tag.value, equals('Symphony No. 9 in D minor'));
        expect(tag.key, equals(TagKey.grouping));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with grouping value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = GroupingTag('Beethoven: Symphony No. 9', provenance: provenance);

        expect(tag.value, equals('Beethoven: Symphony No. 9'));
        expect(tag.key, equals(TagKey.grouping));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty grouping', () {
        const tag = GroupingTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.grouping));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = GroupingTag('🎼 Grouping with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎼 Grouping with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.grouping));
      });

      test('creates instance with very long grouping', () {
        final longGrouping = 'A' * 1000;
        final tag = GroupingTag(longGrouping);

        expect(tag.value, equals(longGrouping));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.grouping));
      });

      test('creates instance with multi-line grouping', () {
        const multiLineGrouping = '''This is a multi-line grouping
that spans several lines
and includes various information
about the work.''';
        const tag = GroupingTag(multiLineGrouping);

        expect(tag.value, equals(multiLineGrouping));
        expect(tag.key, equals(TagKey.grouping));
      });

      test('key is always TagKey.grouping', () {
        const tag1 = GroupingTag('Grouping 1');
        const tag2 = GroupingTag('Grouping 2');
        const tag3 = GroupingTag('');

        expect(tag1.key, equals(TagKey.grouping));
        expect(tag2.key, equals(TagKey.grouping));
        expect(tag3.key, equals(TagKey.grouping));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = GroupingTag(
          'Const Grouping',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Grouping'));
        expect(tag.key, equals(TagKey.grouping));
      });
    });

    group('withProvenance', () {
      test('returns new GroupingTag instance with updated provenance', () {
        const originalTag = GroupingTag(
          'Original Grouping',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Grouping'));
        expect(originalTag.key, equals(TagKey.grouping));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Grouping'));
        expect(updatedTag.key, equals(TagKey.grouping));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns GroupingTag type specifically', () {
        const originalTag = GroupingTag('Test Grouping');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<GroupingTag>());
        expect(updatedTag.runtimeType, equals(GroupingTag));
      });

      test('preserves grouping value exactly', () {
        const originalTag = GroupingTag('Complex Grouping: éñ中文🎼 with special chars');
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
        const originalTag = GroupingTag(
          'Test Grouping',
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
        const originalTag = GroupingTag('Test Grouping');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Grouping'));
          expect(updatedTag.key, equals(TagKey.grouping));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = GroupingTag('Test Grouping');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Grouping'));
          expect(updatedTag.key, equals(TagKey.grouping));
        }
      });
    });

    group('equality', () {
      test('equal instances with same grouping, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = GroupingTag('Same Grouping', provenance: provenance);
        const tag2 = GroupingTag('Same Grouping', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different groupings', () {
        const tag1 = GroupingTag('Grouping 1');
        const tag2 = GroupingTag('Grouping 2');

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

        const tag1 = GroupingTag('Same Grouping', provenance: provenance1);
        const tag2 = GroupingTag('Same Grouping', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = GroupingTag('Test Grouping');
        const tag2 = GroupingTag('Test Grouping');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty groupings', () {
        const tag1 = GroupingTag('');
        const tag2 = GroupingTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = GroupingTag('Grouping');
        const tag2 = GroupingTag('grouping');
        const tag3 = GroupingTag('GROUPING');

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
        const tag = GroupingTag('Test Grouping', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Grouping'));
        expect(tag.props[1], equals(TagKey.grouping));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = GroupingTag('Same Grouping');
        const tag2 = GroupingTag('Same Grouping');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and grouping', () {
        const tag = GroupingTag('My Grouping');
        final result = tag.toString();

        expect(result, contains('GroupingTag'));
        expect(result, contains('My Grouping'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = GroupingTag('Test Grouping', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('GroupingTag'));
        expect(result, contains('Test Grouping'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in grouping', () {
        const tag = GroupingTag('Special: éñ中文🎼');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎼'));
      });

      test('handles empty grouping', () {
        const tag = GroupingTag('');
        final result = tag.toString();

        expect(result, contains('GroupingTag('));
        expect(result, contains('TagProvenance.none()'));
      });

      test('handles multi-line groupings', () {
        const tag = GroupingTag('Line 1\nLine 2\nLine 3');
        final result = tag.toString();

        expect(result, contains('Line 1\nLine 2\nLine 3'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = GroupingTag(
          'Immutable Grouping',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Grouping'));
        expect(tag.key, equals(TagKey.grouping));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = GroupingTag('Original Grouping');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Grouping'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Grouping'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = GroupingTag('String Grouping');
        const tag2 = GroupingTag('');
        const tag3 = GroupingTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains GroupingTag type', () {
        const originalTag = GroupingTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<GroupingTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(GroupingTag));
      });
    });

    group('edge cases', () {
      test('handles very long grouping values', () {
        final longGrouping = 'A' * 10000;
        final tag = GroupingTag(longGrouping);

        expect(tag.value, equals(longGrouping));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.grouping));
      });

      test('handles unicode and emoji in grouping values', () {
        const tag = GroupingTag('🎼 Music Grouping with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎼 Music Grouping with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only groupings', () {
        const tag1 = GroupingTag(' ');
        const tag2 = GroupingTag('   ');
        const tag3 = GroupingTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles groupings with quotes and special formatting', () {
        const tag1 = GroupingTag('"Quoted Grouping"');
        const tag2 = GroupingTag("'Single Quoted'");
        const tag3 = GroupingTag('Grouping with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Grouping"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Grouping with\nnewlines\tand\ttabs'));
      });

      test('handles typical grouping scenarios', () {
        const scenarios = [
          'Symphony No. 9 in D minor, Op. 125',
          'The Beatles: Sgt. Pepper\'s Lonely Hearts Club Band',
          'Bach: The Well-Tempered Clavier, Book I',
          'Pink Floyd: The Wall',
          'Beethoven: Piano Sonatas',
          'Mozart: Requiem in D minor, K. 626',
          'Led Zeppelin IV',
          'Vivaldi: The Four Seasons',
        ];

        for (final scenario in scenarios) {
          final tag = GroupingTag(scenario);
          expect(tag.value, equals(scenario));
          expect(tag.key, equals(TagKey.grouping));
        }
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = GroupingTag('Test Grouping');

        expect(tag, isA<GroupingTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = GroupingTag('Same Grouping');
        const tag2 = GroupingTag('Same Grouping');
        const tag3 = GroupingTag('Different Grouping');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = GroupingTag('Test Grouping');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'GroupingTag\(.*\)'));
        expect(result, contains('Test Grouping'));
        expect(result, contains('provenance:'));
      });
    });

    group('grouping-specific scenarios', () {
      test('handles classical music grouping use cases', () {
        const symphony = GroupingTag('Beethoven: Symphony No. 9 in D minor, Op. 125 "Choral"');
        const concerto = GroupingTag('Mozart: Piano Concerto No. 21 in C major, K. 467');
        const suite = GroupingTag('Bach: Orchestral Suite No. 3 in D major, BWV 1068');
        const sonata = GroupingTag('Chopin: Piano Sonata No. 2 in B♭ minor, Op. 35');

        expect(symphony.key, equals(TagKey.grouping));
        expect(concerto.key, equals(TagKey.grouping));
        expect(suite.key, equals(TagKey.grouping));
        expect(sonata.key, equals(TagKey.grouping));

        expect(symphony.value, contains('Symphony'));
        expect(concerto.value, contains('Concerto'));
        expect(suite.value, contains('Suite'));
        expect(sonata.value, contains('Sonata'));
      });

      test('handles popular music grouping use cases', () {
        const album = GroupingTag('The Beatles: Sgt. Pepper\'s Lonely Hearts Club Band');
        const conceptAlbum = GroupingTag('Pink Floyd: The Wall');
        const soundtrack = GroupingTag('Guardians of the Galaxy: Awesome Mix Vol. 1');
        const compilation = GroupingTag('Now That\'s What I Call Music! 85');

        expect(album.value, contains('Beatles'));
        expect(conceptAlbum.value, contains('Pink Floyd'));
        expect(soundtrack.value, contains('Guardians'));
        expect(compilation.value, contains('Now That\'s'));
      });

      test('handles work and movement groupings', () {
        const movement1 = GroupingTag('Symphony No. 5: I. Allegro con brio');
        const movement2 = GroupingTag('Symphony No. 5: II. Andante con moto');
        const movement3 = GroupingTag('Symphony No. 5: III. Scherzo: Allegro');
        const movement4 = GroupingTag('Symphony No. 5: IV. Allegro');

        expect(movement1.value, contains('I. Allegro'));
        expect(movement2.value, contains('II. Andante'));
        expect(movement3.value, contains('III. Scherzo'));
        expect(movement4.value, contains('IV. Allegro'));
      });

      test('handles thematic and conceptual groupings', () {
        const theme = GroupingTag('Love Songs Collection');
        const era = GroupingTag('80s New Wave Hits');
        const mood = GroupingTag('Relaxing Ambient Soundscapes');
        const genre = GroupingTag('Progressive Rock Epics');

        expect(theme.value, contains('Love Songs'));
        expect(era.value, contains('80s'));
        expect(mood.value, contains('Ambient'));
        expect(genre.value, contains('Progressive'));
      });
    });
  });
}
