import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('IsrcTag', () {
    group('constructor', () {
      test('creates instance with ISRC value and default provenance', () {
        const tag = IsrcTag('USRC17607839');

        expect(tag.value, equals('USRC17607839'));
        expect(tag.key, equals(TagKey.isrc));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with ISRC value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = IsrcTag('GB-UM7-15-12345', provenance: provenance);

        expect(tag.value, equals('GB-UM7-15-12345'));
        expect(tag.key, equals(TagKey.isrc));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty ISRC', () {
        const tag = IsrcTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.isrc));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = IsrcTag('🎵 ISRC with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 ISRC with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.isrc));
      });

      test('creates instance with very long ISRC value', () {
        final longIsrc = 'A' * 1000;
        final tag = IsrcTag(longIsrc);

        expect(tag.value, equals(longIsrc));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.isrc));
      });

      test('key is always TagKey.isrc', () {
        const tag1 = IsrcTag('ISRC1');
        const tag2 = IsrcTag('ISRC2');
        const tag3 = IsrcTag('');

        expect(tag1.key, equals(TagKey.isrc));
        expect(tag2.key, equals(TagKey.isrc));
        expect(tag3.key, equals(TagKey.isrc));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = IsrcTag(
          'USRC17607839',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('USRC17607839'));
        expect(tag.key, equals(TagKey.isrc));
      });
    });

    group('withProvenance', () {
      test('returns new IsrcTag instance with updated provenance', () {
        const originalTag = IsrcTag(
          'USRC17607839',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('USRC17607839'));
        expect(originalTag.key, equals(TagKey.isrc));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('USRC17607839'));
        expect(updatedTag.key, equals(TagKey.isrc));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns IsrcTag type specifically', () {
        const originalTag = IsrcTag('Test ISRC');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<IsrcTag>());
        expect(updatedTag.runtimeType, equals(IsrcTag));
      });

      test('preserves ISRC value exactly', () {
        const originalTag = IsrcTag('Complex ISRC: éñ中文🎵 with special chars');
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
        const originalTag = IsrcTag(
          'Test ISRC',
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
        const originalTag = IsrcTag('Test ISRC');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test ISRC'));
          expect(updatedTag.key, equals(TagKey.isrc));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = IsrcTag('Test ISRC');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test ISRC'));
          expect(updatedTag.key, equals(TagKey.isrc));
        }
      });
    });

    group('equality', () {
      test('equal instances with same ISRC, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = IsrcTag('Same ISRC', provenance: provenance);
        const tag2 = IsrcTag('Same ISRC', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different ISRCs', () {
        const tag1 = IsrcTag('ISRC1');
        const tag2 = IsrcTag('ISRC2');

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

        const tag1 = IsrcTag('Same ISRC', provenance: provenance1);
        const tag2 = IsrcTag('Same ISRC', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = IsrcTag('Test ISRC');
        const tag2 = IsrcTag('Test ISRC');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty ISRCs', () {
        const tag1 = IsrcTag('');
        const tag2 = IsrcTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = IsrcTag('ISRC');
        const tag2 = IsrcTag('isrc');
        const tag3 = IsrcTag('Isrc');

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
        const tag = IsrcTag('Test ISRC', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test ISRC'));
        expect(tag.props[1], equals(TagKey.isrc));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = IsrcTag('Same ISRC');
        const tag2 = IsrcTag('Same ISRC');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and ISRC', () {
        const tag = IsrcTag('My Favorite ISRC');
        final result = tag.toString();

        expect(result, contains('IsrcTag'));
        expect(result, contains('My Favorite ISRC'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = IsrcTag('Test ISRC', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('IsrcTag'));
        expect(result, contains('Test ISRC'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in ISRC', () {
        const tag = IsrcTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty ISRC', () {
        const tag = IsrcTag('');
        final result = tag.toString();

        expect(result, contains('IsrcTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = IsrcTag(
          'Immutable ISRC',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable ISRC'));
        expect(tag.key, equals(TagKey.isrc));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = IsrcTag('Original ISRC');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original ISRC'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original ISRC'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = IsrcTag('String ISRC');
        const tag2 = IsrcTag('');
        const tag3 = IsrcTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains IsrcTag type', () {
        const originalTag = IsrcTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<IsrcTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(IsrcTag));
      });
    });

    group('edge cases', () {
      test('handles very long ISRC values', () {
        final longIsrc = 'A' * 10000;
        final tag = IsrcTag(longIsrc);

        expect(tag.value, equals(longIsrc));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.isrc));
      });

      test('handles unicode and emoji in ISRC values', () {
        const tag = IsrcTag('🎵 ISRC with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 ISRC with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only ISRCs', () {
        const tag1 = IsrcTag(' ');
        const tag2 = IsrcTag('   ');
        const tag3 = IsrcTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles ISRCs with quotes and special formatting', () {
        const tag1 = IsrcTag('"Quoted ISRC"');
        const tag2 = IsrcTag("'Single Quoted'");
        const tag3 = IsrcTag('ISRC with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted ISRC"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('ISRC with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = IsrcTag('Test ISRC');

        expect(tag, isA<IsrcTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = IsrcTag('Same ISRC');
        const tag2 = IsrcTag('Same ISRC');
        const tag3 = IsrcTag('Different ISRC');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = IsrcTag('Test ISRC');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'IsrcTag\(.*\)'));
        expect(result, contains('Test ISRC'));
        expect(result, contains('provenance:'));
      });
    });

    group('ISRC format use cases', () {
      test('handles standard formatted ISRCs correctly', () {
        const isrcs = [
          'US-RC1-76-07839',
          'GB-UM7-15-12345',
          'FR-Z03-19-00001',
          'DE-A12-20-54321',
          'JP-B25-18-98765',
          'CA-C34-21-11111',
          'AU-D45-17-22222',
          'SE-E56-22-33333',
        ];

        for (final isrc in isrcs) {
          final tag = IsrcTag(isrc);
          expect(tag.value, equals(isrc));
          expect(tag.key, equals(TagKey.isrc));
        }
      });

      test('handles unformatted ISRCs', () {
        const tag1 = IsrcTag('USRC17607839');
        const tag2 = IsrcTag('GBUM71512345');
        const tag3 = IsrcTag('FRZ031900001');
        const tag4 = IsrcTag('DEA122054321');

        expect(tag1.value, equals('USRC17607839'));
        expect(tag2.value, equals('GBUM71512345'));
        expect(tag3.value, equals('FRZ031900001'));
        expect(tag4.value, equals('DEA122054321'));
      });

      test('handles ISRCs with different separators', () {
        const tag1 = IsrcTag('US.RC1.76.07839');
        const tag2 = IsrcTag('US_RC1_76_07839');
        const tag3 = IsrcTag('US RC1 76 07839');

        expect(tag1.value, equals('US.RC1.76.07839'));
        expect(tag2.value, equals('US_RC1_76_07839'));
        expect(tag3.value, equals('US RC1 76 07839'));
      });

      test('handles ISRCs with mixed case', () {
        const tag1 = IsrcTag('us-rc1-76-07839');
        const tag2 = IsrcTag('Us-Rc1-76-07839');
        const tag3 = IsrcTag('US-rc1-76-07839');

        expect(tag1.value, equals('us-rc1-76-07839'));
        expect(tag2.value, equals('Us-Rc1-76-07839'));
        expect(tag3.value, equals('US-rc1-76-07839'));
      });

      test('handles partial or malformed ISRCs', () {
        const tag1 = IsrcTag('US-RC1');
        const tag2 = IsrcTag('INCOMPLETE');
        const tag3 = IsrcTag('123456789012');
        const tag4 = IsrcTag('XX-YYY-ZZ-AAAAA');

        expect(tag1.value, equals('US-RC1'));
        expect(tag2.value, equals('INCOMPLETE'));
        expect(tag3.value, equals('123456789012'));
        expect(tag4.value, equals('XX-YYY-ZZ-AAAAA'));
      });
    });

    group('real-world ISRC examples', () {
      test('handles major label ISRCs', () {
        const tag1 = IsrcTag('USSM10012345'); // Sony Music
        const tag2 = IsrcTag('USUM71234567'); // Universal Music
        const tag3 = IsrcTag('USWD11234567'); // Warner Music
        const tag4 = IsrcTag('USEM51234567'); // EMI

        expect(tag1.value, equals('USSM10012345'));
        expect(tag2.value, equals('USUM71234567'));
        expect(tag3.value, equals('USWD11234567'));
        expect(tag4.value, equals('USEM51234567'));
      });

      test('handles independent label ISRCs', () {
        const tag1 = IsrcTag('USRC17607839'); // CD Baby
        const tag2 = IsrcTag('TCACB1234567'); // TuneCore
        const tag3 = IsrcTag('QZFYY1234567'); // DistroKid

        expect(tag1.value, equals('USRC17607839'));
        expect(tag2.value, equals('TCACB1234567'));
        expect(tag3.value, equals('QZFYY1234567'));
      });

      test('handles international ISRCs', () {
        const tag1 = IsrcTag('GBUM71512345'); // UK
        const tag2 = IsrcTag('FRPO61234567'); // France
        const tag3 = IsrcTag('DEUM71234567'); // Germany
        const tag4 = IsrcTag('JPVI01234567'); // Japan
        const tag5 = IsrcTag('BRBMG1234567'); // Brazil

        expect(tag1.value, equals('GBUM71512345'));
        expect(tag2.value, equals('FRPO61234567'));
        expect(tag3.value, equals('DEUM71234567'));
        expect(tag4.value, equals('JPVI01234567'));
        expect(tag5.value, equals('BRBMG1234567'));
      });
    });
  });
}
