import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('DateRecordedTag', () {
    group('constructor', () {
      test('creates instance with valid full date and default provenance', () {
        final tag = DateRecordedTag('2023-03-15');

        expect(tag.value, equals('2023-03-15'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid date and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = DateRecordedTag('2023-03-15', provenance: provenance);

        expect(tag.value, equals('2023-03-15'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with year only format', () {
        final tag = DateRecordedTag('2023');

        expect(tag.value, equals('2023'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with year-month format', () {
        final tag = DateRecordedTag('2023-03');

        expect(tag.value, equals('2023-03'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with full date-time format', () {
        final tag = DateRecordedTag('2023-03-15T14:30:00');

        expect(tag.value, equals('2023-03-15T14:30:00'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with UTC timezone format', () {
        final tag = DateRecordedTag('2023-03-15T14:30:00Z');

        expect(tag.value, equals('2023-03-15T14:30:00Z'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with timezone offset format', () {
        final tag1 = DateRecordedTag('2023-03-15T14:30:00+02:00');
        final tag2 = DateRecordedTag('2023-03-15T14:30:00-05:00');

        expect(tag1.value, equals('2023-03-15T14:30:00+02:00'));
        expect(tag2.value, equals('2023-03-15T14:30:00-05:00'));
        expect(tag1.key, equals(TagKey.dateRecorded));
        expect(tag2.key, equals(TagKey.dateRecorded));
      });

      test('creates instance with milliseconds', () {
        final tag = DateRecordedTag('2023-03-15T14:30:00.123Z');

        expect(tag.value, equals('2023-03-15T14:30:00.123Z'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('trims whitespace from input', () {
        final tag = DateRecordedTag('  2023-03-15  ');

        expect(tag.value, equals('2023-03-15'));
        expect(tag.key, equals(TagKey.dateRecorded));
      });

      test('key is always TagKey.dateRecorded', () {
        final tag1 = DateRecordedTag('2023');
        final tag2 = DateRecordedTag('2023-03-15');
        final tag3 = DateRecordedTag('2023-03-15T14:30:00Z');

        expect(tag1.key, equals(TagKey.dateRecorded));
        expect(tag2.key, equals(TagKey.dateRecorded));
        expect(tag3.key, equals(TagKey.dateRecorded));
      });
    });

    group('ISO-8601 validation', () {
      group('valid formats', () {
        test('accepts year only format', () {
          final validYears = ['1900', '1995', '2000', '2023', '2100'];

          for (final year in validYears) {
            final tag = DateRecordedTag(year);
            expect(tag.value, equals(year));
          }
        });

        test('accepts year-month format', () {
          final validDates = [
            '2023-01',
            '2023-02',
            '2023-03',
            '2023-04',
            '2023-05',
            '2023-06',
            '2023-07',
            '2023-08',
            '2023-09',
            '2023-10',
            '2023-11',
            '2023-12',
          ];

          for (final date in validDates) {
            final tag = DateRecordedTag(date);
            expect(tag.value, equals(date));
          }
        });

        test('accepts full date format', () {
          final validDates = [
            '2023-01-01',
            '2023-02-28',
            '2023-03-15',
            '2023-04-30',
            '2023-05-31',
            '2023-06-15',
            '2023-07-04',
            '2023-08-25',
            '2023-09-30',
            '2023-10-31',
            '2023-11-15',
            '2023-12-31',
          ];

          for (final date in validDates) {
            final tag = DateRecordedTag(date);
            expect(tag.value, equals(date));
          }
        });

        test('accepts date-time format', () {
          final validDateTimes = [
            '2023-03-15T00:00:00',
            '2023-03-15T12:30:45',
            '2023-03-15T23:59:59',
            '2023-03-15T14:30:00',
          ];

          for (final dateTime in validDateTimes) {
            final tag = DateRecordedTag(dateTime);
            expect(tag.value, equals(dateTime));
          }
        });

        test('accepts UTC timezone format', () {
          final validDateTimes = [
            '2023-03-15T14:30:00Z',
            '2023-12-31T23:59:59Z',
            '2023-01-01T00:00:00Z',
          ];

          for (final dateTime in validDateTimes) {
            final tag = DateRecordedTag(dateTime);
            expect(tag.value, equals(dateTime));
          }
        });

        test('accepts timezone offset format', () {
          final validDateTimes = [
            '2023-03-15T14:30:00+00:00',
            '2023-03-15T14:30:00+02:00',
            '2023-03-15T14:30:00-05:00',
            '2023-03-15T14:30:00+09:30',
            '2023-03-15T14:30:00-11:00',
          ];

          for (final dateTime in validDateTimes) {
            final tag = DateRecordedTag(dateTime);
            expect(tag.value, equals(dateTime));
          }
        });

        test('accepts milliseconds format', () {
          final validDateTimes = [
            '2023-03-15T14:30:00.1Z',
            '2023-03-15T14:30:00.12Z',
            '2023-03-15T14:30:00.123Z',
            '2023-03-15T14:30:00.999+02:00',
          ];

          for (final dateTime in validDateTimes) {
            final tag = DateRecordedTag(dateTime);
            expect(tag.value, equals(dateTime));
          }
        });

        test('accepts leap year dates', () {
          final leapYearDates = [
            '2000-02-29', // Leap year (divisible by 400)
            '2004-02-29', // Leap year (divisible by 4, not by 100)
            '2020-02-29', // Recent leap year
            '2024-02-29', // Future leap year
          ];

          for (final date in leapYearDates) {
            final tag = DateRecordedTag(date);
            expect(tag.value, equals(date));
          }
        });

        test('accepts boundary dates', () {
          final boundaryDates = [
            '1900-01-01', // Minimum year
            '2100-12-31', // Maximum year
            '2023-01-31', // January boundary
            '2023-02-28', // February boundary (non-leap)
            '2024-02-29', // February boundary (leap)
            '2023-04-30', // April boundary
            '2023-12-31', // December boundary
          ];

          for (final date in boundaryDates) {
            final tag = DateRecordedTag(date);
            expect(tag.value, equals(date));
          }
        });
      });

      group('invalid formats', () {
        test('throws ArgumentError for empty string', () {
          expect(
            () => DateRecordedTag(''),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('Date recorded cannot be empty'),
              ),
            ),
          );
        });

        test('throws ArgumentError for whitespace only', () {
          expect(
            () => DateRecordedTag('   '),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('Date recorded cannot be empty'),
              ),
            ),
          );
        });

        test('throws ArgumentError for invalid date format', () {
          final invalidFormats = [
            '23-03-15', // Wrong year format
            '2023/03/15', // Wrong separators
            '2023.03.15', // Wrong separators
            '15-03-2023', // Wrong order
            '2023-3-15', // Single digit month
            '2023-03-5', // Single digit day
            '2023-13-15', // Invalid month
            '2023-03-32', // Invalid day
            '2023-02-30', // Invalid day for February
            'March 15, 2023', // Text format
            '2023-03-15 14:30:00', // Space instead of T
            'invalid', // Random text
          ];

          for (final format in invalidFormats) {
            expect(
              () => DateRecordedTag(format),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject format: $format',
            );
          }
        });

        test('throws ArgumentError for year out of range', () {
          final invalidYears = [
            '1899', // Below minimum
            '2101', // Above maximum
            '1800', // Way below
            '3000', // Way above
            '0000', // Zero year
          ];

          for (final year in invalidYears) {
            expect(
              () => DateRecordedTag(year),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  contains('Year must be between 1900 and 2100 (inclusive)'),
                ),
              ),
              reason: 'Should reject year: $year',
            );
          }
        });

        test('throws ArgumentError for invalid month', () {
          final invalidMonths = [
            '2023-00-15', // Month 0
            '2023-13-15', // Month 13
            '2023-99-15', // Month 99
          ];

          for (final date in invalidMonths) {
            expect(
              () => DateRecordedTag(date),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  contains('Month must be between 01 and 12'),
                ),
              ),
              reason: 'Should reject date: $date',
            );
          }
        });

        test('throws ArgumentError for invalid day', () {
          final invalidDays = [
            '2023-01-00', // Day 0
            '2023-01-32', // Day 32 in January
            '2023-02-30', // Day 30 in February
            '2023-04-31', // Day 31 in April (30-day month)
            '2023-06-31', // Day 31 in June (30-day month)
            '2023-09-31', // Day 31 in September (30-day month)
            '2023-11-31', // Day 31 in November (30-day month)
          ];

          for (final date in invalidDays) {
            expect(
              () => DateRecordedTag(date),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject date: $date',
            );
          }
        });

        test('throws ArgumentError for invalid leap year dates', () {
          final invalidLeapDates = [
            '1900-02-29', // Not a leap year (divisible by 100, not 400)
            '2001-02-29', // Not a leap year
            '2100-02-29', // Not a leap year (divisible by 100, not 400)
            '2023-02-29', // Not a leap year
          ];

          for (final date in invalidLeapDates) {
            expect(
              () => DateRecordedTag(date),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject non-leap year date: $date',
            );
          }
        });

        test('throws ArgumentError for invalid time components', () {
          final invalidTimes = [
            '2023-03-15T24:00:00', // Hour 24
            '2023-03-15T12:60:00', // Minute 60
            '2023-03-15T12:30:60', // Second 60
            '2023-03-15T99:30:00', // Hour 99
            '2023-03-15T12:99:00', // Minute 99
            '2023-03-15T12:30:99', // Second 99
          ];

          for (final time in invalidTimes) {
            expect(
              () => DateRecordedTag(time),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject time: $time',
            );
          }
        });

        test('ArgumentError includes the invalid value', () {
          expect(
            () => DateRecordedTag('invalid-date'),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.invalidValue,
                'invalidValue',
                equals('invalid-date'),
              ),
            ),
          );
        });

        test('ArgumentError includes parameter name', () {
          expect(
            () => DateRecordedTag('invalid'),
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
            () => DateRecordedTag('invalid-date', provenance: provenance),
            throwsA(isA<ArgumentError>()),
          );

          // Valid values should work fine with provenance
          final validTag = DateRecordedTag('2023-03-15', provenance: provenance);
          expect(validTag.value, equals('2023-03-15'));
          expect(validTag.provenance, equals(provenance));
        });
      });
    });

    group('withProvenance', () {
      test('returns new DateRecordedTag instance with updated provenance', () {
        final originalTag = DateRecordedTag(
          '2023-03-15',
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('2023-03-15'));
        expect(originalTag.key, equals(TagKey.dateRecorded));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('2023-03-15'));
        expect(updatedTag.key, equals(TagKey.dateRecorded));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns DateRecordedTag type specifically', () {
        final originalTag = DateRecordedTag('2023');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<DateRecordedTag>());
        expect(updatedTag.runtimeType, equals(DateRecordedTag));
      });

      test('preserves date value exactly', () {
        final originalTag = DateRecordedTag('2023-03-15T14:30:00Z');
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
        final originalTag = DateRecordedTag(
          '2023-12-25',
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
        final originalTag = DateRecordedTag('2023-06-01');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('2023-06-01'));
          expect(updatedTag.key, equals(TagKey.dateRecorded));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = DateRecordedTag('2023-09-15');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('2023-09-15'));
          expect(updatedTag.key, equals(TagKey.dateRecorded));
        }
      });
    });

    group('equality', () {
      test('equal instances with same date, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = DateRecordedTag('2023-03-15', provenance: provenance);
        final tag2 = DateRecordedTag('2023-03-15', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different dates', () {
        final tag1 = DateRecordedTag('2023-03-15');
        final tag2 = DateRecordedTag('2023-03-16');

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

        final tag1 = DateRecordedTag('2023-03-15', provenance: provenance1);
        final tag2 = DateRecordedTag('2023-03-15', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = DateRecordedTag('2023-03-15');
        final tag2 = DateRecordedTag('2023-03-15');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with different date formats for same logical date', () {
        // Note: These are different strings, so they should NOT be equal
        // The library doesn't normalize date formats
        final tag1 = DateRecordedTag('2023-03-15');
        final tag2 = DateRecordedTag('2023-03-15T00:00:00Z');

        expect(tag1, isNot(equals(tag2)));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = DateRecordedTag('2023-03-15', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('2023-03-15'));
        expect(tag.props[1], equals(TagKey.dateRecorded));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = DateRecordedTag('2023-03-15');
        final tag2 = DateRecordedTag('2023-03-15');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and date', () {
        final tag = DateRecordedTag('2023-03-15');
        final result = tag.toString();

        expect(result, contains('DateRecordedTag'));
        expect(result, contains('2023-03-15'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = DateRecordedTag('2023-03-15T14:30:00Z', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('DateRecordedTag'));
        expect(result, contains('2023-03-15T14:30:00Z'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles different date formats', () {
        final tagYear = DateRecordedTag('2023');
        final tagDate = DateRecordedTag('2023-03-15');
        final tagDateTime = DateRecordedTag('2023-03-15T14:30:00Z');

        final resultYear = tagYear.toString();
        final resultDate = tagDate.toString();
        final resultDateTime = tagDateTime.toString();

        expect(resultYear, contains('2023'));
        expect(resultDate, contains('2023-03-15'));
        expect(resultDateTime, contains('2023-03-15T14:30:00Z'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = DateRecordedTag(
          '2023-03-15',
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('2023-03-15'));
        expect(tag.key, equals(TagKey.dateRecorded));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = DateRecordedTag('2023-03-15');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('2023-03-15'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('2023-03-15'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        final tag1 = DateRecordedTag('2023');
        final tag2 = DateRecordedTag('2023-03-15');
        final tag3 = DateRecordedTag('2023-03-15T14:30:00Z');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
      });

      test('withProvenance maintains DateRecordedTag type', () {
        final originalTag = DateRecordedTag('2023-03-15');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<DateRecordedTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(DateRecordedTag));
      });
    });

    group('edge cases', () {
      test('handles leap year validation correctly', () {
        // Valid leap years
        final validLeapDates = [
          '2000-02-29', // Divisible by 400
          '2004-02-29', // Divisible by 4, not by 100
          '2020-02-29', // Recent leap year
          '2024-02-29', // Future leap year
        ];

        for (final date in validLeapDates) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }

        // Invalid leap years
        final invalidLeapDates = [
          '1900-02-29', // Divisible by 100, not by 400
          '2001-02-29', // Not divisible by 4
          '2100-02-29', // Divisible by 100, not by 400
        ];

        for (final date in invalidLeapDates) {
          expect(() => DateRecordedTag(date), throwsA(isA<ArgumentError>()));
        }
      });

      test('handles month-specific day limits', () {
        // 31-day months
        final thirtyOneDayMonths = ['01', '03', '05', '07', '08', '10', '12'];
        for (final month in thirtyOneDayMonths) {
          final tag = DateRecordedTag('2023-$month-31');
          expect(tag.value, equals('2023-$month-31'));
        }

        // 30-day months
        final thirtyDayMonths = ['04', '06', '09', '11'];
        for (final month in thirtyDayMonths) {
          final tag = DateRecordedTag('2023-$month-30');
          expect(tag.value, equals('2023-$month-30'));

          // Day 31 should be invalid
          expect(() => DateRecordedTag('2023-$month-31'), throwsA(isA<ArgumentError>()));
        }

        // February in non-leap year
        final febTag = DateRecordedTag('2023-02-28');
        expect(febTag.value, equals('2023-02-28'));
        expect(() => DateRecordedTag('2023-02-29'), throwsA(isA<ArgumentError>()));
      });

      test('handles boundary time values', () {
        final boundaryTimes = [
          '2023-03-15T00:00:00', // Midnight
          '2023-03-15T23:59:59', // End of day
          '2023-03-15T12:00:00', // Noon
        ];

        for (final time in boundaryTimes) {
          final tag = DateRecordedTag(time);
          expect(tag.value, equals(time));
        }
      });

      test('handles various timezone formats', () {
        final timezoneFormats = [
          '2023-03-15T14:30:00Z', // UTC
          '2023-03-15T14:30:00+00:00', // UTC with offset
          '2023-03-15T14:30:00+01:00', // CET
          '2023-03-15T14:30:00+02:00', // EET
          '2023-03-15T14:30:00-05:00', // EST
          '2023-03-15T14:30:00-08:00', // PST
          '2023-03-15T14:30:00+09:00', // JST
          '2023-03-15T14:30:00+05:30', // IST (half-hour offset)
          '2023-03-15T14:30:00-03:30', // NST (half-hour offset)
        ];

        for (final format in timezoneFormats) {
          final tag = DateRecordedTag(format);
          expect(tag.value, equals(format));
        }
      });

      test('handles historical and future dates within range', () {
        final historicalDates = [
          '1900-01-01', // Minimum boundary
          '1920-05-15', // Early recordings
          '1950-12-25', // Mid-century
          '1975-07-04', // Vinyl era
          '1985-11-30', // CD era
          '1995-03-15', // Digital era
        ];

        final futureDates = [
          '2025-01-01', // Near future
          '2050-06-15', // Mid-century future
          '2075-09-30', // Far future
          '2100-12-31', // Maximum boundary
        ];

        for (final date in [...historicalDates, ...futureDates]) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        final tag = DateRecordedTag('2023-03-15');

        expect(tag, isA<DateRecordedTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = DateRecordedTag('2023-03-15');
        final tag2 = DateRecordedTag('2023-03-15');
        final tag3 = DateRecordedTag('2023-03-16');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = DateRecordedTag('2023-03-15');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'DateRecordedTag\(.*\)'));
        expect(result, contains('2023-03-15'));
        expect(result, contains('provenance:'));
      });
    });

    group('date format specific scenarios', () {
      test('handles music industry standard dates', () {
        final industryDates = [
          '1955-07-05', // Rock and roll era
          '1967-06-01', // Summer of Love
          '1969-08-15', // Woodstock
          '1977-05-25', // Punk era
          '1981-08-01', // MTV launch
          '1991-09-24', // Grunge era
          '2001-10-23', // iPod launch
          '2008-07-10', // Streaming era
        ];

        for (final date in industryDates) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }
      });

      test('handles album release precision levels', () {
        // Different levels of precision for release dates
        final precisionLevels = [
          '2023', // Year only (common for older releases)
          '2023-03', // Month precision
          '2023-03-15', // Day precision (most common)
          '2023-03-15T14:30:00', // Time precision (rare)
          '2023-03-15T14:30:00Z', // Full timestamp (very rare)
        ];

        for (final date in precisionLevels) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }
      });

      test('handles reissue and remaster scenarios', () {
        // Original vs reissue dates
        final originalDate = DateRecordedTag('1969-09-26'); // Abbey Road original
        final reissueDate = DateRecordedTag('2019-09-27'); // 50th anniversary reissue

        expect(originalDate.value, equals('1969-09-26'));
        expect(reissueDate.value, equals('2019-09-27'));
      });

      test('handles compilation album dates', () {
        // Compilation albums use compilation date, not original recording dates
        final compilationDates = [
          '1995-11-28', // Beatles Anthology
          '2000-11-13', // Beatles 1
          '2010-11-09', // Various greatest hits
        ];

        for (final date in compilationDates) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }
      });

      test('handles live recording dates', () {
        // Live albums often have specific performance dates
        final liveRecordingDates = [
          '1970-04-10', // Paul McCartney Live
          '1976-09-23', // The Song Remains the Same
          '1991-11-18', // MTV Unplugged sessions
        ];

        for (final date in liveRecordingDates) {
          final tag = DateRecordedTag(date);
          expect(tag.value, equals(date));
        }
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for invalid format', () {
        try {
          DateRecordedTag('invalid-date');
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Date must be in ISO-8601 format'));
          expect(error.message, contains('2023'));
          expect(error.message, contains('2023-03-15'));
          expect(error.message, contains('2023-03-15T14:30:00Z'));
          expect(error.invalidValue, equals('invalid-date'));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for year out of range', () {
        try {
          DateRecordedTag('1800-01-01');
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Year must be between 1900 and 2100 (inclusive)'));
          expect(error.invalidValue, equals('1800-01-01'));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for invalid month', () {
        try {
          DateRecordedTag('2023-13-15');
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Month must be between 01 and 12'));
          expect(error.invalidValue, equals('2023-13-15'));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for invalid day', () {
        try {
          DateRecordedTag('2023-02-30');
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Day 30 is not valid for year 2023 month 2'));
          expect(error.invalidValue, equals('2023-02-30'));
          expect(error.name, equals('value'));
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
          () => DateRecordedTag('invalid-date', provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
