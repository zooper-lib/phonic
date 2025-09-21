import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('ComposerTag', () {
    group('constructor', () {
      test('creates instance with composer value and default provenance', () {
        const tag = ComposerTag('Ludwig van Beethoven');

        expect(tag.value, equals('Ludwig van Beethoven'));
        expect(tag.key, equals(TagKey.composer));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with composer value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = ComposerTag('Johann Sebastian Bach', provenance: provenance);

        expect(tag.value, equals('Johann Sebastian Bach'));
        expect(tag.key, equals(TagKey.composer));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty composer', () {
        const tag = ComposerTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.composer));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = ComposerTag('🎼 Composer Name with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎼 Composer Name with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.composer));
      });

      test('creates instance with very long composer name', () {
        final longComposer = 'A' * 1000;
        final tag = ComposerTag(longComposer);

        expect(tag.value, equals(longComposer));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.composer));
      });

      test('key is always TagKey.composer', () {
        const tag1 = ComposerTag('Composer 1');
        const tag2 = ComposerTag('Composer 2');
        const tag3 = ComposerTag('');

        expect(tag1.key, equals(TagKey.composer));
        expect(tag2.key, equals(TagKey.composer));
        expect(tag3.key, equals(TagKey.composer));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = ComposerTag(
          'Const Composer',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Composer'));
        expect(tag.key, equals(TagKey.composer));
      });
    });

    group('withProvenance', () {
      test('returns new ComposerTag instance with updated provenance', () {
        const originalTag = ComposerTag(
          'Wolfgang Amadeus Mozart',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Wolfgang Amadeus Mozart'));
        expect(originalTag.key, equals(TagKey.composer));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Wolfgang Amadeus Mozart'));
        expect(updatedTag.key, equals(TagKey.composer));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns ComposerTag type specifically', () {
        const originalTag = ComposerTag('Test Composer');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<ComposerTag>());
        expect(updatedTag.runtimeType, equals(ComposerTag));
      });

      test('preserves composer value exactly', () {
        const originalTag = ComposerTag('Complex Composer: éñ中文🎼 with special chars');
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
        const originalTag = ComposerTag(
          'Test Composer',
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
        const originalTag = ComposerTag('Test Composer');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Composer'));
          expect(updatedTag.key, equals(TagKey.composer));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = ComposerTag('Test Composer');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Composer'));
          expect(updatedTag.key, equals(TagKey.composer));
        }
      });
    });

    group('equality', () {
      test('equal instances with same composer, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = ComposerTag('Same Composer', provenance: provenance);
        const tag2 = ComposerTag('Same Composer', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different composers', () {
        const tag1 = ComposerTag('Composer 1');
        const tag2 = ComposerTag('Composer 2');

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

        const tag1 = ComposerTag('Same Composer', provenance: provenance1);
        const tag2 = ComposerTag('Same Composer', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = ComposerTag('Test Composer');
        const tag2 = ComposerTag('Test Composer');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty composers', () {
        const tag1 = ComposerTag('');
        const tag2 = ComposerTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = ComposerTag('Composer');
        const tag2 = ComposerTag('composer');
        const tag3 = ComposerTag('COMPOSER');

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
        const tag = ComposerTag('Test Composer', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Composer'));
        expect(tag.props[1], equals(TagKey.composer));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = ComposerTag('Same Composer');
        const tag2 = ComposerTag('Same Composer');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and composer', () {
        const tag = ComposerTag('My Favorite Composer');
        final result = tag.toString();

        expect(result, contains('ComposerTag'));
        expect(result, contains('My Favorite Composer'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = ComposerTag('Test Composer', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('ComposerTag'));
        expect(result, contains('Test Composer'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in composer', () {
        const tag = ComposerTag('Special: éñ中文🎼');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎼'));
      });

      test('handles empty composer', () {
        const tag = ComposerTag('');
        final result = tag.toString();

        expect(result, contains('ComposerTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = ComposerTag(
          'Immutable Composer',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Composer'));
        expect(tag.key, equals(TagKey.composer));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = ComposerTag('Original Composer');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Composer'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Composer'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = ComposerTag('String Composer');
        const tag2 = ComposerTag('');
        const tag3 = ComposerTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains ComposerTag type', () {
        const originalTag = ComposerTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<ComposerTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(ComposerTag));
      });
    });

    group('edge cases', () {
      test('handles very long composer values', () {
        final longComposer = 'A' * 10000;
        final tag = ComposerTag(longComposer);

        expect(tag.value, equals(longComposer));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.composer));
      });

      test('handles unicode and emoji in composer values', () {
        const tag = ComposerTag('🎼 Composer Name with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎼 Composer Name with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only composers', () {
        const tag1 = ComposerTag(' ');
        const tag2 = ComposerTag('   ');
        const tag3 = ComposerTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles composers with quotes and special formatting', () {
        const tag1 = ComposerTag('"Quoted Composer"');
        const tag2 = ComposerTag("'Single Quoted'");
        const tag3 = ComposerTag('Composer with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Composer"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Composer with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = ComposerTag('Test Composer');

        expect(tag, isA<ComposerTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = ComposerTag('Same Composer');
        const tag2 = ComposerTag('Same Composer');
        const tag3 = ComposerTag('Different Composer');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = ComposerTag('Test Composer');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'ComposerTag\(.*\)'));
        expect(result, contains('Test Composer'));
        expect(result, contains('provenance:'));
      });
    });

    group('classical music use cases', () {
      test('handles classical composer names correctly', () {
        const composers = [
          'Ludwig van Beethoven',
          'Johann Sebastian Bach',
          'Wolfgang Amadeus Mozart',
          'Frédéric Chopin',
          'Pyotr Ilyich Tchaikovsky',
          'Claude Debussy',
          'Igor Stravinsky',
          'Antonio Vivaldi',
          'George Frideric Handel',
          'Franz Schubert',
        ];

        for (final composer in composers) {
          final tag = ComposerTag(composer);
          expect(tag.value, equals(composer));
          expect(tag.key, equals(TagKey.composer));
        }
      });

      test('handles composer names with titles and periods', () {
        const tag1 = ComposerTag('J.S. Bach');
        const tag2 = ComposerTag('W.A. Mozart');
        const tag3 = ComposerTag('C.P.E. Bach');
        const tag4 = ComposerTag('Dr. John Smith');

        expect(tag1.value, equals('J.S. Bach'));
        expect(tag2.value, equals('W.A. Mozart'));
        expect(tag3.value, equals('C.P.E. Bach'));
        expect(tag4.value, equals('Dr. John Smith'));
      });

      test('handles multiple composers in single field', () {
        const tag1 = ComposerTag('Bach, Mozart');
        const tag2 = ComposerTag('Lennon/McCartney');
        const tag3 = ComposerTag('Rodgers & Hammerstein');

        expect(tag1.value, equals('Bach, Mozart'));
        expect(tag2.value, equals('Lennon/McCartney'));
        expect(tag3.value, equals('Rodgers & Hammerstein'));
      });
    });

    group('modern music use cases', () {
      test('handles songwriter and band names', () {
        const tag1 = ComposerTag('John Lennon');
        const tag2 = ComposerTag('Taylor Swift');
        const tag3 = ComposerTag('Radiohead');
        const tag4 = ComposerTag('Billie Eilish');

        expect(tag1.value, equals('John Lennon'));
        expect(tag2.value, equals('Taylor Swift'));
        expect(tag3.value, equals('Radiohead'));
        expect(tag4.value, equals('Billie Eilish'));
      });

      test('handles producer and songwriter credits', () {
        const tag1 = ComposerTag('Max Martin');
        const tag2 = ComposerTag('Pharrell Williams');
        const tag3 = ComposerTag('Rick Rubin');

        expect(tag1.value, equals('Max Martin'));
        expect(tag2.value, equals('Pharrell Williams'));
        expect(tag3.value, equals('Rick Rubin'));
      });
    });
  });
}
