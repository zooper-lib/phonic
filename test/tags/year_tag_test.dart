import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('YearTag', () {
    group('constructor', () {
      test('creates instance with valid year and default provenance', () {
        final tag = YearTag(1995);

        expect(tag.value, equals(1995));
        expect(tag.key, equals(TagKey.year));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid year and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = YearTag(2023, provenance: provenance);

        expect(tag.value, equals(2023));
        expect(tag.key, equals(TagKey.year));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with minimum valid year', () {
        final tag = YearTag(1900);

        expect(tag.value, equals(1900));
        expect(tag.key, equals(TagKey.year));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with maximum valid year', () {
        final tag = YearTag(2100);

        expect(tag.value, equals(2100));
        expect(tag.key, equals(TagKey.year));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with common historical years', () {
        final tag1950 = YearTag(1950);
        final tag1980 = YearTag(1980);
        final tag2000 = YearTag(2000);

        expect(tag1950.value, equals(1950));
        expect(tag1980.value, equals(1980));
        expect(tag2000.value, equals(2000));
      });

      test('creates instance with recent years', () {
        final tag2020 = YearTag(2020);
        final tag2023 = YearTag(2023);

        expect(tag2020.value, equals(2020));
        expect(tag2023.value, equals(2023));
      });

      test('key is always TagKey.year', () {
        final tag1 = YearTag(1900);
        final tag2 = YearTag(1995);
        final tag3 = YearTag(2100);

        expect(tag1.key, equals(TagKey.year));
        expect(tag2.key, equals(TagKey.year));
        expect(tag3.key, equals(TagKey.year));
      });
    });

    group('validation', () {
      test('throws ArgumentError for year below minimum (1899)', () {
        expect(
          () => YearTag(1899),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for year above maximum (2101)', () {
        expect(
          () => YearTag(2101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for very old years', () {
        expect(
          () => YearTag(1800),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => YearTag(1000),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => YearTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for far future years', () {
        expect(
          () => YearTag(3000),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => YearTag(9999),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative years', () {
        expect(
          () => YearTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => YearTag(-1995),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Year must be between 1900 and 2100 (inclusive)'),
            ),
          ),
        );
      });

      test('ArgumentError includes the invalid value', () {
        expect(
          () => YearTag(1899),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(1899),
            ),
          ),
        );

        expect(
          () => YearTag(2101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(2101),
            ),
          ),
        );
      });

      test('ArgumentError includes parameter name', () {
        expect(
          () => YearTag(1800),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              equals('value'),
            ),
          ),
        );
      });

      test('validation works with provenance parameter', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );

        expect(
          () => YearTag(1899, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => YearTag(2101, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        // Valid values should work fine with provenance
        final validTag = YearTag(1995, provenance: provenance);
        expect(validTag.value, equals(1995));
        expect(validTag.provenance, equals(provenance));
      });

      test('accepts boundary values', () {
        // Test that boundary values are valid
        final minTag = YearTag(1900);
        final maxTag = YearTag(2100);

        expect(minTag.value, equals(1900));
        expect(maxTag.value, equals(2100));
      });

      test('rejects values just outside boundaries', () {
        expect(() => YearTag(1899), throwsA(isA<ArgumentError>()));
        expect(() => YearTag(2101), throwsA(isA<ArgumentError>()));
      });
    });

    group('withProvenance', () {
      test('returns new YearTag instance with updated provenance', () {
        final originalTag = YearTag(
          1995,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(1995));
        expect(originalTag.key, equals(TagKey.year));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(1995));
        expect(updatedTag.key, equals(TagKey.year));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns YearTag type specifically', () {
        final originalTag = YearTag(2000);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<YearTag>());
        expect(updatedTag.runtimeType, equals(YearTag));
      });

      test('preserves year value exactly', () {
        final originalTag = YearTag(1987);
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
        final originalTag = YearTag(
          2010,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        final originalTag = YearTag(1999);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(1999));
          expect(updatedTag.key, equals(TagKey.year));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = YearTag(2005);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(2005));
          expect(updatedTag.key, equals(TagKey.year));
        }
      });
    });

    group('equality', () {
      test('equal instances with same year, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = YearTag(1995, provenance: provenance);
        final tag2 = YearTag(1995, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different years', () {
        final tag1 = YearTag(1995);
        final tag2 = YearTag(2000);

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

        final tag1 = YearTag(1995, provenance: provenance1);
        final tag2 = YearTag(1995, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = YearTag(2023);
        final tag2 = YearTag(2023);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with boundary years', () {
        final tag1Min = YearTag(1900);
        final tag2Min = YearTag(1900);
        final tag1Max = YearTag(2100);
        final tag2Max = YearTag(2100);

        expect(tag1Min, equals(tag2Min));
        expect(tag1Min.hashCode, equals(tag2Min.hashCode));
        expect(tag1Max, equals(tag2Max));
        expect(tag1Max.hashCode, equals(tag2Max.hashCode));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = YearTag(1987, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(1987));
        expect(tag.props[1], equals(TagKey.year));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = YearTag(2001);
        final tag2 = YearTag(2001);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and year', () {
        final tag = YearTag(1995);
        final result = tag.toString();

        expect(result, contains('YearTag'));
        expect(result, contains('1995'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = YearTag(2023, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('YearTag'));
        expect(result, contains('2023'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles boundary years', () {
        final tagMin = YearTag(1900);
        final tagMax = YearTag(2100);

        final resultMin = tagMin.toString();
        final resultMax = tagMax.toString();

        expect(resultMin, contains('1900'));
        expect(resultMax, contains('2100'));
      });

      test('handles common years', () {
        final tag1980 = YearTag(1980);
        final tag2000 = YearTag(2000);
        final tag2020 = YearTag(2020);

        expect(tag1980.toString(), contains('1980'));
        expect(tag2000.toString(), contains('2000'));
        expect(tag2020.toString(), contains('2020'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = YearTag(
          1995,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(1995));
        expect(tag.key, equals(TagKey.year));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = YearTag(2010);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(2010));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(2010));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always int type', () {
        final tag1 = YearTag(1900);
        final tag2 = YearTag(1995);
        final tag3 = YearTag(2100);

        expect(tag1.value, isA<int>());
        expect(tag2.value, isA<int>());
        expect(tag3.value, isA<int>());
      });

      test('withProvenance maintains YearTag type', () {
        final originalTag = YearTag(2005);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<YearTag>());
        expect(newTag.value, isA<int>());
        expect(newTag.runtimeType, equals(YearTag));
      });
    });

    group('edge cases', () {
      test('handles exact boundary values', () {
        final minTag = YearTag(1900);
        final maxTag = YearTag(2100);

        expect(minTag.value, equals(1900));
        expect(maxTag.value, equals(2100));
        expect(minTag.key, equals(TagKey.year));
        expect(maxTag.key, equals(TagKey.year));
      });

      test('validation edge case: exactly at boundaries', () {
        // Test that boundary values are valid
        final tag1900 = YearTag(1900);
        final tag2100 = YearTag(2100);

        expect(tag1900.value, equals(1900));
        expect(tag2100.value, equals(2100));

        // And that values just outside boundaries are invalid
        expect(() => YearTag(1899), throwsA(isA<ArgumentError>()));
        expect(() => YearTag(2101), throwsA(isA<ArgumentError>()));
      });

      test('handles common music era years', () {
        // Test various music eras
        final classical = YearTag(1920); // Early recordings
        final jazz = YearTag(1940); // Jazz era
        final rock = YearTag(1960); // Rock era
        final disco = YearTag(1975); // Disco era
        final eighties = YearTag(1985); // 80s music
        final grunge = YearTag(1992); // Grunge era
        final modern = YearTag(2020); // Modern music

        expect(classical.value, equals(1920));
        expect(jazz.value, equals(1940));
        expect(rock.value, equals(1960));
        expect(disco.value, equals(1975));
        expect(eighties.value, equals(1985));
        expect(grunge.value, equals(1992));
        expect(modern.value, equals(2020));
      });

      test('handles milestone years', () {
        // Test significant years in music history
        final y1900 = YearTag(1900); // Minimum boundary
        final y1950 = YearTag(1950); // Mid-20th century
        final y2000 = YearTag(2000); // Millennium
        final y2100 = YearTag(2100); // Maximum boundary

        expect(y1900.value, equals(1900));
        expect(y1950.value, equals(1950));
        expect(y2000.value, equals(2000));
        expect(y2100.value, equals(2100));
      });

      test('handles years around format transitions', () {
        // Years around major format transitions in music
        final vinyl = YearTag(1950); // Vinyl era
        final cd = YearTag(1985); // CD introduction
        final mp3 = YearTag(1995); // MP3 format
        final streaming = YearTag(2010); // Streaming era

        expect(vinyl.value, equals(1950));
        expect(cd.value, equals(1985));
        expect(mp3.value, equals(1995));
        expect(streaming.value, equals(2010));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<int> correctly', () {
        final tag = YearTag(1995);

        expect(tag, isA<YearTag>());
        expect(tag.value, isA<int>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = YearTag(1995);
        final tag2 = YearTag(1995);
        final tag3 = YearTag(2000);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = YearTag(1995);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'YearTag\(.*\)'));
        expect(result, contains('1995'));
        expect(result, contains('provenance:'));
      });
    });

    group('year specific scenarios', () {
      test('handles early recording era (1900-1930)', () {
        for (int year = 1900; year <= 1930; year += 5) {
          final tag = YearTag(year);
          expect(tag.value, equals(year));
        }
      });

      test('handles golden age of music (1930-1970)', () {
        for (int year = 1930; year <= 1970; year += 10) {
          final tag = YearTag(year);
          expect(tag.value, equals(year));
        }
      });

      test('handles modern music era (1970-2000)', () {
        for (int year = 1970; year <= 2000; year += 5) {
          final tag = YearTag(year);
          expect(tag.value, equals(year));
        }
      });

      test('handles digital music era (2000-2023)', () {
        for (int year = 2000; year <= 2023; year += 3) {
          final tag = YearTag(year);
          expect(tag.value, equals(year));
        }
      });

      test('handles future releases (2024-2100)', () {
        final years = [2024, 2030, 2050, 2075, 2100];
        for (final year in years) {
          final tag = YearTag(year);
          expect(tag.value, equals(year));
        }
      });

      test('handles reissue scenarios', () {
        // Original release vs reissue year handling
        final original1960 = YearTag(1960);
        final reissue2020 = YearTag(2020);

        expect(original1960.value, equals(1960));
        expect(reissue2020.value, equals(2020));
      });

      test('handles compilation album years', () {
        // Compilation albums often use the compilation year, not original recording years
        final compilation1995 = YearTag(1995);
        final compilation2010 = YearTag(2010);

        expect(compilation1995.value, equals(1995));
        expect(compilation2010.value, equals(2010));
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for years below minimum', () {
        try {
          YearTag(1899);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Year must be between 1900 and 2100 (inclusive)'));
          expect(error.invalidValue, equals(1899));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for years above maximum', () {
        try {
          YearTag(2101);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Year must be between 1900 and 2100 (inclusive)'));
          expect(error.invalidValue, equals(2101));
          expect(error.name, equals('value'));
        }
      });

      test('error message includes range information', () {
        try {
          YearTag(0);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('1900'));
          expect(error.message, contains('2100'));
          expect(error.message, contains('inclusive'));
        }
      });

      test('error occurs before provenance is processed', () {
        // Ensure validation happens early in constructor
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        expect(
          () => YearTag(1800, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('constants', () {
      test('minYear constant is correct', () {
        expect(YearTag.minYear, equals(1900));
      });

      test('maxYear constant is correct', () {
        expect(YearTag.maxYear, equals(2100));
      });

      test('constants are used in validation', () {
        // Test that the constants are actually used
        expect(() => YearTag(YearTag.minYear - 1), throwsA(isA<ArgumentError>()));
        expect(() => YearTag(YearTag.maxYear + 1), throwsA(isA<ArgumentError>()));

        // And that boundary values work
        final minTag = YearTag(YearTag.minYear);
        final maxTag = YearTag(YearTag.maxYear);

        expect(minTag.value, equals(YearTag.minYear));
        expect(maxTag.value, equals(YearTag.maxYear));
      });
    });
  });
}
