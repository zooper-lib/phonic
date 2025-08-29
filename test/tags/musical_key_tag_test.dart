import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/container_kind.dart';
import 'package:phonic/src/metadata_tag.dart';
import 'package:phonic/src/tag_confidence.dart';
import 'package:phonic/src/tag_key.dart';
import 'package:phonic/src/tag_provenance.dart';

void main() {
  group('MusicalKeyTag', () {
    group('constructor', () {
      test('creates instance with musical key value and default provenance', () {
        const tag = MusicalKeyTag('C major');

        expect(tag.value, equals('C major'));
        expect(tag.key, equals(TagKey.musicalKey));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with musical key value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = MusicalKeyTag('D minor', provenance: provenance);

        expect(tag.value, equals('D minor'));
        expect(tag.key, equals(TagKey.musicalKey));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty musical key', () {
        const tag = MusicalKeyTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.musicalKey));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with various key notations', () {
        const majorKey = MusicalKeyTag('C major');
        const minorKey = MusicalKeyTag('Am');
        const sharpKey = MusicalKeyTag('F#m');
        const flatKey = MusicalKeyTag('Bb');
        const camelotKey = MusicalKeyTag('5B');
        const openKey = MusicalKeyTag('1d');

        expect(majorKey.value, equals('C major'));
        expect(minorKey.value, equals('Am'));
        expect(sharpKey.value, equals('F#m'));
        expect(flatKey.value, equals('Bb'));
        expect(camelotKey.value, equals('5B'));
        expect(openKey.value, equals('1d'));

        // All should have the same key type
        expect(majorKey.key, equals(TagKey.musicalKey));
        expect(minorKey.key, equals(TagKey.musicalKey));
        expect(sharpKey.key, equals(TagKey.musicalKey));
        expect(flatKey.key, equals(TagKey.musicalKey));
        expect(camelotKey.key, equals(TagKey.musicalKey));
        expect(openKey.key, equals(TagKey.musicalKey));
      });

      test('creates instance with unicode and special characters', () {
        const tag = MusicalKeyTag('C♯ major');

        expect(tag.value, equals('C♯ major'));
        expect(tag.key, equals(TagKey.musicalKey));
      });

      test('creates instance with very long key description', () {
        final longKey = 'C major with extended harmonic analysis and detailed notation' * 10;
        final tag = MusicalKeyTag(longKey);

        expect(tag.value, equals(longKey));
        expect(tag.key, equals(TagKey.musicalKey));
      });

      test('key is always TagKey.musicalKey', () {
        const tag1 = MusicalKeyTag('C major');
        const tag2 = MusicalKeyTag('Am');
        const tag3 = MusicalKeyTag('');

        expect(tag1.key, equals(TagKey.musicalKey));
        expect(tag2.key, equals(TagKey.musicalKey));
        expect(tag3.key, equals(TagKey.musicalKey));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = MusicalKeyTag(
          'F# minor',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('F# minor'));
        expect(tag.key, equals(TagKey.musicalKey));
      });
    });

    group('withProvenance', () {
      test('returns new MusicalKeyTag instance with updated provenance', () {
        const originalTag = MusicalKeyTag(
          'G major',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('G major'));
        expect(originalTag.key, equals(TagKey.musicalKey));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('G major'));
        expect(updatedTag.key, equals(TagKey.musicalKey));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns MusicalKeyTag type specifically', () {
        const originalTag = MusicalKeyTag('Dm');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<MusicalKeyTag>());
        expect(updatedTag.runtimeType, equals(MusicalKeyTag));
      });

      test('preserves musical key value exactly', () {
        const originalTag = MusicalKeyTag('F♯ minor');
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
        const originalTag = MusicalKeyTag(
          'Bb major',
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
        const originalTag = MusicalKeyTag('E minor');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('E minor'));
          expect(updatedTag.key, equals(TagKey.musicalKey));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = MusicalKeyTag('A major');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('A major'));
          expect(updatedTag.key, equals(TagKey.musicalKey));
        }
      });
    });

    group('equality', () {
      test('equal instances with same musical key, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = MusicalKeyTag('C major', provenance: provenance);
        const tag2 = MusicalKeyTag('C major', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different musical keys', () {
        const tag1 = MusicalKeyTag('C major');
        const tag2 = MusicalKeyTag('D minor');

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

        const tag1 = MusicalKeyTag('Am', provenance: provenance1);
        const tag2 = MusicalKeyTag('Am', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = MusicalKeyTag('F# major');
        const tag2 = MusicalKeyTag('F# major');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty musical keys', () {
        const tag1 = MusicalKeyTag('');
        const tag2 = MusicalKeyTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = MusicalKeyTag('C major');
        const tag2 = MusicalKeyTag('c major');
        const tag3 = MusicalKeyTag('C MAJOR');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag2, isNot(equals(tag3)));
      });

      test('handles different key notations as different', () {
        const tag1 = MusicalKeyTag('C major');
        const tag2 = MusicalKeyTag('C');
        const tag3 = MusicalKeyTag('1A'); // Camelot notation for C major

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
        const tag = MusicalKeyTag('Eb major', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Eb major'));
        expect(tag.props[1], equals(TagKey.musicalKey));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = MusicalKeyTag('G minor');
        const tag2 = MusicalKeyTag('G minor');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and musical key', () {
        const tag = MusicalKeyTag('D major');
        final result = tag.toString();

        expect(result, contains('MusicalKeyTag'));
        expect(result, contains('D major'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = MusicalKeyTag('F minor', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('MusicalKeyTag'));
        expect(result, contains('F minor'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in musical key', () {
        const tag = MusicalKeyTag('C♯ major');
        final result = tag.toString();

        expect(result, contains('C♯ major'));
      });

      test('handles empty musical key', () {
        const tag = MusicalKeyTag('');
        final result = tag.toString();

        expect(result, contains('MusicalKeyTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = MusicalKeyTag(
          'B minor',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('B minor'));
        expect(tag.key, equals(TagKey.musicalKey));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = MusicalKeyTag('Ab major');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Ab major'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Ab major'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = MusicalKeyTag('C major');
        const tag2 = MusicalKeyTag('');
        const tag3 = MusicalKeyTag('5B');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('5B')); // String, not int
      });

      test('withProvenance maintains MusicalKeyTag type', () {
        const originalTag = MusicalKeyTag('Em');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<MusicalKeyTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(MusicalKeyTag));
      });
    });

    group('edge cases', () {
      test('handles very long musical key descriptions', () {
        final longKey = 'C major with extended harmonic analysis' * 100;
        final tag = MusicalKeyTag(longKey);

        expect(tag.value, equals(longKey));
        expect(tag.key, equals(TagKey.musicalKey));
      });

      test('handles unicode and special musical symbols', () {
        const tag = MusicalKeyTag('C♯ major (D♭ enharmonic)');
        expect(tag.value, equals('C♯ major (D♭ enharmonic)'));
      });

      test('handles whitespace-only musical keys', () {
        const tag1 = MusicalKeyTag(' ');
        const tag2 = MusicalKeyTag('   ');
        const tag3 = MusicalKeyTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles musical keys with quotes and special formatting', () {
        const tag1 = MusicalKeyTag('"C major"');
        const tag2 = MusicalKeyTag("'A minor'");
        const tag3 = MusicalKeyTag('Key:\nC major\t(Ionian mode)');

        expect(tag1.value, equals('"C major"'));
        expect(tag2.value, equals("'A minor'"));
        expect(tag3.value, equals('Key:\nC major\t(Ionian mode)'));
      });

      test('handles various musical key notation systems', () {
        const traditionalMajor = MusicalKeyTag('C major');
        const traditionalMinor = MusicalKeyTag('A minor');
        const shortMajor = MusicalKeyTag('C');
        const shortMinor = MusicalKeyTag('Am');
        const camelot = MusicalKeyTag('8B');
        const openKey = MusicalKeyTag('1d');
        const numeric = MusicalKeyTag('0');
        const modal = MusicalKeyTag('C Dorian');

        expect(traditionalMajor.value, equals('C major'));
        expect(traditionalMinor.value, equals('A minor'));
        expect(shortMajor.value, equals('C'));
        expect(shortMinor.value, equals('Am'));
        expect(camelot.value, equals('8B'));
        expect(openKey.value, equals('1d'));
        expect(numeric.value, equals('0'));
        expect(modal.value, equals('C Dorian'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = MusicalKeyTag('F# minor');

        expect(tag, isA<MusicalKeyTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = MusicalKeyTag('G major');
        const tag2 = MusicalKeyTag('G major');
        const tag3 = MusicalKeyTag('G minor');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = MusicalKeyTag('Bb major');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'MusicalKeyTag\(.*\)'));
        expect(result, contains('Bb major'));
        expect(result, contains('provenance:'));
      });
    });

    group('musical key specific scenarios', () {
      test('handles all 12 chromatic keys in major', () {
        final majorKeys = [
          'C major',
          'C# major',
          'Db major',
          'D major',
          'D# major',
          'Eb major',
          'E major',
          'F major',
          'F# major',
          'Gb major',
          'G major',
          'G# major',
          'Ab major',
          'A major',
          'A# major',
          'Bb major',
          'B major',
        ];

        for (final key in majorKeys) {
          final tag = MusicalKeyTag(key);
          expect(tag.value, equals(key));
          expect(tag.key, equals(TagKey.musicalKey));
        }
      });

      test('handles all 12 chromatic keys in minor', () {
        final minorKeys = ['Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'A#m', 'Bm'];

        for (final key in minorKeys) {
          final tag = MusicalKeyTag(key);
          expect(tag.value, equals(key));
          expect(tag.key, equals(TagKey.musicalKey));
        }
      });

      test('handles modal keys', () {
        final modalKeys = ['C Dorian', 'D Phrygian', 'E Lydian', 'F Mixolydian', 'G Aeolian', 'A Locrian'];

        for (final key in modalKeys) {
          final tag = MusicalKeyTag(key);
          expect(tag.value, equals(key));
          expect(tag.key, equals(TagKey.musicalKey));
        }
      });

      test('handles Camelot wheel notation', () {
        final camelotKeys = [
          '1A',
          '1B',
          '2A',
          '2B',
          '3A',
          '3B',
          '4A',
          '4B',
          '5A',
          '5B',
          '6A',
          '6B',
          '7A',
          '7B',
          '8A',
          '8B',
          '9A',
          '9B',
          '10A',
          '10B',
          '11A',
          '11B',
          '12A',
          '12B',
        ];

        for (final key in camelotKeys) {
          final tag = MusicalKeyTag(key);
          expect(tag.value, equals(key));
          expect(tag.key, equals(TagKey.musicalKey));
        }
      });

      test('handles Open Key notation', () {
        final openKeys = [
          '1d',
          '1m',
          '2d',
          '2m',
          '3d',
          '3m',
          '4d',
          '4m',
          '5d',
          '5m',
          '6d',
          '6m',
          '7d',
          '7m',
          '8d',
          '8m',
          '9d',
          '9m',
          '10d',
          '10m',
          '11d',
          '11m',
          '12d',
          '12m',
        ];

        for (final key in openKeys) {
          final tag = MusicalKeyTag(key);
          expect(tag.value, equals(key));
          expect(tag.key, equals(TagKey.musicalKey));
        }
      });
    });
  });
}
