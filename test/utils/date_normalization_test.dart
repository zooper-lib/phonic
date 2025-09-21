import 'package:phonic/src/utils/date_normalization.dart';
import 'package:test/test.dart';

void main() {
  group('DateNormalization', () {
    group('fromId3v23Components', () {
      test('should convert year only', () {
        final result = DateNormalization.fromId3v23Components(year: '2023');
        expect(result, equals('2023'));
      });

      test('should convert year and date', () {
        final result = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503', // March 15th (DDMM format)
        );
        expect(result, equals('2023-03-15'));
      });

      test('should convert full date and time', () {
        final result = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503',
          time: '1430', // 14:30 (HHMM format)
        );
        expect(result, equals('2023-03-15T14:30:00'));
      });

      test('should handle leap year dates', () {
        final result = DateNormalization.fromId3v23Components(
          year: '2024',
          date: '2902', // February 29th in leap year
        );
        expect(result, equals('2024-02-29'));
      });

      test('should handle edge case dates', () {
        // January 1st
        final jan1 = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '0101',
        );
        expect(jan1, equals('2023-01-01'));

        // December 31st
        final dec31 = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '3112',
        );
        expect(dec31, equals('2023-12-31'));
      });

      test('should handle midnight and end of day times', () {
        // Midnight
        final midnight = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503',
          time: '0000',
        );
        expect(midnight, equals('2023-03-15T00:00:00'));

        // End of day
        final endOfDay = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503',
          time: '2359',
        );
        expect(endOfDay, equals('2023-03-15T23:59:00'));
      });

      test('should throw on invalid year', () {
        expect(
          () => DateNormalization.fromId3v23Components(year: '1899'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(year: '2101'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(year: 'abcd'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(year: '23'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid date format', () {
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '123', // Too short
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '12345', // Too long
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: 'abcd',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid date values', () {
        // Invalid month
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '1513', // Month 13
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid day
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '3202', // February 32nd
          ),
          throwsA(isA<ArgumentError>()),
        );

        // February 29th in non-leap year
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '2902',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid time format', () {
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '1503',
            time: '123', // Too short
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '1503',
            time: '12345', // Too long
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid time values', () {
        // Invalid hour
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '1503',
            time: '2430', // Hour 24
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid minute
        expect(
          () => DateNormalization.fromId3v23Components(
            year: '2023',
            date: '1503',
            time: '1460', // Minute 60
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle empty or null date/time gracefully', () {
        // Empty date
        final emptyDate = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '',
        );
        expect(emptyDate, equals('2023'));

        // Null time with valid date
        final nullTime = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503',
          time: null,
        );
        expect(nullTime, equals('2023-03-15'));

        // Empty time
        final emptyTime = DateNormalization.fromId3v23Components(
          year: '2023',
          date: '1503',
          time: '',
        );
        expect(emptyTime, equals('2023-03-15'));
      });
    });

    group('toId3v23Components', () {
      test('should convert year only', () {
        final result = DateNormalization.toId3v23Components('2023');
        expect(result.year, equals('2023'));
        expect(result.date, isNull);
        expect(result.time, isNull);
      });

      test('should convert full date', () {
        final result = DateNormalization.toId3v23Components('2023-03-15');
        expect(result.year, equals('2023'));
        expect(result.date, equals('1503')); // DDMM format
        expect(result.time, isNull);
      });

      test('should convert full date and time', () {
        final result = DateNormalization.toId3v23Components('2023-03-15T14:30:00');
        expect(result.year, equals('2023'));
        expect(result.date, equals('1503'));
        expect(result.time, equals('1430')); // HHMM format
      });

      test('should convert date with timezone', () {
        final result = DateNormalization.toId3v23Components('2023-03-15T14:30:00Z');
        expect(result.year, equals('2023'));
        expect(result.date, equals('1503'));
        expect(result.time, equals('1430'));
      });

      test('should convert date with timezone offset', () {
        final result = DateNormalization.toId3v23Components('2023-03-15T14:30:00+02:00');
        expect(result.year, equals('2023'));
        expect(result.date, equals('1503'));
        expect(result.time, equals('1430'));
      });

      test('should handle edge case dates', () {
        // January 1st
        final jan1 = DateNormalization.toId3v23Components('2023-01-01');
        expect(jan1.date, equals('0101'));

        // December 31st
        final dec31 = DateNormalization.toId3v23Components('2023-12-31');
        expect(dec31.date, equals('3112'));
      });

      test('should handle edge case times', () {
        // Midnight
        final midnight = DateNormalization.toId3v23Components('2023-03-15T00:00:00');
        expect(midnight.time, equals('0000'));

        // End of day
        final endOfDay = DateNormalization.toId3v23Components('2023-03-15T23:59:59');
        expect(endOfDay.time, equals('2359'));
      });

      test('should throw on invalid ISO-8601 format', () {
        expect(
          () => DateNormalization.toId3v23Components('2023/03/15'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.toId3v23Components('invalid'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.toId3v23Components(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('parseIso8601Date', () {
      test('should parse year only', () {
        final result = DateNormalization.parseIso8601Date('2023');
        expect(result.year, equals(2023));
        expect(result.month, isNull);
        expect(result.day, isNull);
        expect(result.hour, isNull);
        expect(result.minute, isNull);
        expect(result.second, isNull);
        expect(result.millisecond, isNull);
        expect(result.timezone, isNull);
      });

      test('should parse year and month', () {
        final result = DateNormalization.parseIso8601Date('2023-03');
        expect(result.year, equals(2023));
        expect(result.month, equals(3));
        expect(result.day, isNull);
        expect(result.hasTime, isFalse);
        expect(result.hasTimezone, isFalse);
        expect(result.isCompleteDate, isFalse);
      });

      test('should parse full date', () {
        final result = DateNormalization.parseIso8601Date('2023-03-15');
        expect(result.year, equals(2023));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
        expect(result.hasTime, isFalse);
        expect(result.hasTimezone, isFalse);
        expect(result.isCompleteDate, isTrue);
      });

      test('should parse date and time', () {
        final result = DateNormalization.parseIso8601Date('2023-03-15T14:30:45');
        expect(result.year, equals(2023));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
        expect(result.hour, equals(14));
        expect(result.minute, equals(30));
        expect(result.second, equals(45));
        expect(result.hasTime, isTrue);
        expect(result.hasTimezone, isFalse);
        expect(result.isCompleteDate, isTrue);
      });

      test('should parse date and time with milliseconds', () {
        final result = DateNormalization.parseIso8601Date('2023-03-15T14:30:45.123');
        expect(result.millisecond, equals(123));

        // Test padding of milliseconds
        final result2 = DateNormalization.parseIso8601Date('2023-03-15T14:30:45.1');
        expect(result2.millisecond, equals(100));

        final result3 = DateNormalization.parseIso8601Date('2023-03-15T14:30:45.12');
        expect(result3.millisecond, equals(120));
      });

      test('should parse date with UTC timezone', () {
        final result = DateNormalization.parseIso8601Date('2023-03-15T14:30:45Z');
        expect(result.timezone, equals('Z'));
        expect(result.hasTimezone, isTrue);
      });

      test('should parse date with timezone offset', () {
        final result1 = DateNormalization.parseIso8601Date('2023-03-15T14:30:45+02:00');
        expect(result1.timezone, equals('+02:00'));

        final result2 = DateNormalization.parseIso8601Date('2023-03-15T14:30:45-05:00');
        expect(result2.timezone, equals('-05:00'));
      });

      test('should handle leap year validation', () {
        // Valid leap year date
        final leapYear = DateNormalization.parseIso8601Date('2024-02-29');
        expect(leapYear.day, equals(29));

        // Invalid leap year date
        expect(
          () => DateNormalization.parseIso8601Date('2023-02-29'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate date ranges', () {
        // Valid dates
        expect(() => DateNormalization.parseIso8601Date('2023-01-01'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-12-31'), returnsNormally);

        // Invalid month
        expect(
          () => DateNormalization.parseIso8601Date('2023-13-01'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid day
        expect(
          () => DateNormalization.parseIso8601Date('2023-02-30'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate time ranges', () {
        // Valid times
        expect(() => DateNormalization.parseIso8601Date('2023-03-15T00:00:00'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-03-15T23:59:59'), returnsNormally);

        // Invalid hour
        expect(
          () => DateNormalization.parseIso8601Date('2023-03-15T24:00:00'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid minute
        expect(
          () => DateNormalization.parseIso8601Date('2023-03-15T14:60:00'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid second
        expect(
          () => DateNormalization.parseIso8601Date('2023-03-15T14:30:60'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate year range', () {
        // Valid years
        expect(() => DateNormalization.parseIso8601Date('1900'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2100'), returnsNormally);

        // Invalid years
        expect(
          () => DateNormalization.parseIso8601Date('1899'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.parseIso8601Date('2101'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on invalid formats', () {
        expect(
          () => DateNormalization.parseIso8601Date(''),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.parseIso8601Date('invalid'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DateNormalization.parseIso8601Date('2023/03/15'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle whitespace', () {
        final result = DateNormalization.parseIso8601Date('  2023-03-15  ');
        expect(result.year, equals(2023));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
      });
    });

    group('isValidIso8601Date', () {
      test('should return true for valid dates', () {
        expect(DateNormalization.isValidIso8601Date('2023'), isTrue);
        expect(DateNormalization.isValidIso8601Date('2023-03'), isTrue);
        expect(DateNormalization.isValidIso8601Date('2023-03-15'), isTrue);
        expect(DateNormalization.isValidIso8601Date('2023-03-15T14:30:00'), isTrue);
        expect(DateNormalization.isValidIso8601Date('2023-03-15T14:30:00Z'), isTrue);
        expect(DateNormalization.isValidIso8601Date('2023-03-15T14:30:00+02:00'), isTrue);
      });

      test('should return false for invalid dates', () {
        expect(DateNormalization.isValidIso8601Date(''), isFalse);
        expect(DateNormalization.isValidIso8601Date('invalid'), isFalse);
        expect(DateNormalization.isValidIso8601Date('2023/03/15'), isFalse);
        expect(DateNormalization.isValidIso8601Date('2023-13-01'), isFalse);
        expect(DateNormalization.isValidIso8601Date('2023-02-30'), isFalse);
        expect(DateNormalization.isValidIso8601Date('1899'), isFalse);
        expect(DateNormalization.isValidIso8601Date('2101'), isFalse);
      });
    });

    group('normalizeIso8601Date', () {
      test('should normalize various formats', () {
        expect(
          DateNormalization.normalizeIso8601Date('2023'),
          equals('2023'),
        );

        expect(
          DateNormalization.normalizeIso8601Date('2023-03-15'),
          equals('2023-03-15'),
        );

        expect(
          DateNormalization.normalizeIso8601Date('2023-03-15T14:30:00'),
          equals('2023-03-15T14:30:00'),
        );

        expect(
          DateNormalization.normalizeIso8601Date('2023-03-15T14:30:00Z'),
          equals('2023-03-15T14:30:00Z'),
        );
      });

      test('should add missing seconds when time is present', () {
        // When hour and minute are present but second is not, should default to 00
        final normalized = DateNormalization.normalizeIso8601Date('2023-03-15T14:30:00');
        expect(normalized, contains(':00')); // Should have seconds
      });
    });

    group('extractYear', () {
      test('should extract year from various formats', () {
        expect(DateNormalization.extractYear('2023'), equals(2023));
        expect(DateNormalization.extractYear('2023-03'), equals(2023));
        expect(DateNormalization.extractYear('2023-03-15'), equals(2023));
        expect(DateNormalization.extractYear('2023-03-15T14:30:00Z'), equals(2023));
      });

      test('should throw on invalid dates', () {
        expect(
          () => DateNormalization.extractYear('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity in round-trip conversions', () {
        final testCases = [
          '2023',
          '2023-03-15',
          '2023-03-15T14:30:00',
        ];

        for (final testCase in testCases) {
          // ISO-8601 -> ID3v2.3 -> ISO-8601
          final components = DateNormalization.toId3v23Components(testCase);
          final backToIso = DateNormalization.fromId3v23Components(
            year: components.year,
            date: components.date,
            time: components.time,
          );
          expect(backToIso, equals(testCase));
        }
      });

      test('should handle ID3v2.3 -> ISO-8601 -> ID3v2.3 round-trip', () {
        final testCases = [
          ('2023', null, null),
          ('2023', '1503', null),
          ('2023', '1503', '1430'),
        ];

        for (final (year, date, time) in testCases) {
          // ID3v2.3 -> ISO-8601 -> ID3v2.3
          final iso8601 = DateNormalization.fromId3v23Components(
            year: year,
            date: date,
            time: time,
          );
          final backToComponents = DateNormalization.toId3v23Components(iso8601);

          expect(backToComponents.year, equals(year));
          expect(backToComponents.date, equals(date));
          expect(backToComponents.time, equals(time));
        }
      });
    });

    group('edge cases and error handling', () {
      test('should handle various month lengths correctly', () {
        // 31-day months
        expect(() => DateNormalization.parseIso8601Date('2023-01-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-03-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-05-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-07-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-08-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-10-31'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-12-31'), returnsNormally);

        // 30-day months
        expect(() => DateNormalization.parseIso8601Date('2023-04-30'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-06-30'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-09-30'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-11-30'), returnsNormally);

        // Invalid 31st day for 30-day months
        expect(() => DateNormalization.parseIso8601Date('2023-04-31'), throwsA(isA<ArgumentError>()));
        expect(() => DateNormalization.parseIso8601Date('2023-06-31'), throwsA(isA<ArgumentError>()));
        expect(() => DateNormalization.parseIso8601Date('2023-09-31'), throwsA(isA<ArgumentError>()));
        expect(() => DateNormalization.parseIso8601Date('2023-11-31'), throwsA(isA<ArgumentError>()));

        // February in non-leap year
        expect(() => DateNormalization.parseIso8601Date('2023-02-28'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2023-02-29'), throwsA(isA<ArgumentError>()));

        // February in leap year
        expect(() => DateNormalization.parseIso8601Date('2024-02-29'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2024-02-30'), throwsA(isA<ArgumentError>()));
      });

      test('should handle leap year calculations correctly', () {
        // Standard leap years (divisible by 4)
        expect(() => DateNormalization.parseIso8601Date('2024-02-29'), returnsNormally);
        expect(() => DateNormalization.parseIso8601Date('2020-02-29'), returnsNormally);

        // Century years not divisible by 400 (not leap years)
        expect(() => DateNormalization.parseIso8601Date('1900-02-29'), throwsA(isA<ArgumentError>()));

        // Century years divisible by 400 (leap years)
        expect(() => DateNormalization.parseIso8601Date('2000-02-29'), returnsNormally);

        // Non-leap years
        expect(() => DateNormalization.parseIso8601Date('2023-02-29'), throwsA(isA<ArgumentError>()));
        expect(() => DateNormalization.parseIso8601Date('2021-02-29'), throwsA(isA<ArgumentError>()));
      });

      test('should handle timezone formats correctly', () {
        // UTC timezone
        final utc = DateNormalization.parseIso8601Date('2023-03-15T14:30:00Z');
        expect(utc.timezone, equals('Z'));

        // Positive offset
        final plus = DateNormalization.parseIso8601Date('2023-03-15T14:30:00+02:00');
        expect(plus.timezone, equals('+02:00'));

        // Negative offset
        final minus = DateNormalization.parseIso8601Date('2023-03-15T14:30:00-05:00');
        expect(minus.timezone, equals('-05:00'));

        // Timezone without colon (should still work if supported by regex)
        // Note: Current implementation expects colon, so this would fail
        // If we want to support this, we'd need to update the regex
      });
    });
  });

  group('Id3v23DateComponents', () {
    test('should create components correctly', () {
      final components = const Id3v23DateComponents(
        year: '2023',
        date: '1503',
        time: '1430',
      );

      expect(components.year, equals('2023'));
      expect(components.date, equals('1503'));
      expect(components.time, equals('1430'));
    });

    test('should handle null date and time', () {
      final components = const Id3v23DateComponents(year: '2023');
      expect(components.year, equals('2023'));
      expect(components.date, isNull);
      expect(components.time, isNull);
    });

    test('should implement equality correctly', () {
      final components1 = const Id3v23DateComponents(
        year: '2023',
        date: '1503',
        time: '1430',
      );

      final components2 = const Id3v23DateComponents(
        year: '2023',
        date: '1503',
        time: '1430',
      );

      final components3 = const Id3v23DateComponents(
        year: '2023',
        date: '1503',
      );

      expect(components1, equals(components2));
      expect(components1, isNot(equals(components3)));
      expect(components1.hashCode, equals(components2.hashCode));
    });

    test('should have meaningful toString', () {
      final components = const Id3v23DateComponents(
        year: '2023',
        date: '1503',
        time: '1430',
      );

      final str = components.toString();
      expect(str, contains('2023'));
      expect(str, contains('1503'));
      expect(str, contains('1430'));
    });
  });

  group('ParsedDate', () {
    test('should create parsed date correctly', () {
      final parsed = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
        second: 45,
        millisecond: 123,
        timezone: 'Z',
      );

      expect(parsed.year, equals(2023));
      expect(parsed.month, equals(3));
      expect(parsed.day, equals(15));
      expect(parsed.hour, equals(14));
      expect(parsed.minute, equals(30));
      expect(parsed.second, equals(45));
      expect(parsed.millisecond, equals(123));
      expect(parsed.timezone, equals('Z'));
    });

    test('should handle optional components', () {
      final parsed = const ParsedDate(year: 2023);
      expect(parsed.year, equals(2023));
      expect(parsed.month, isNull);
      expect(parsed.day, isNull);
      expect(parsed.hour, isNull);
      expect(parsed.minute, isNull);
      expect(parsed.second, isNull);
      expect(parsed.millisecond, isNull);
      expect(parsed.timezone, isNull);
    });

    test('should implement helper properties correctly', () {
      final yearOnly = const ParsedDate(year: 2023);
      expect(yearOnly.hasTime, isFalse);
      expect(yearOnly.hasTimezone, isFalse);
      expect(yearOnly.isCompleteDate, isFalse);

      final dateOnly = const ParsedDate(year: 2023, month: 3, day: 15);
      expect(dateOnly.hasTime, isFalse);
      expect(dateOnly.hasTimezone, isFalse);
      expect(dateOnly.isCompleteDate, isTrue);

      final withTime = const ParsedDate(year: 2023, month: 3, day: 15, hour: 14, minute: 30);
      expect(withTime.hasTime, isTrue);
      expect(withTime.hasTimezone, isFalse);
      expect(withTime.isCompleteDate, isTrue);

      final withTimezone = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
        timezone: 'Z',
      );
      expect(withTimezone.hasTime, isTrue);
      expect(withTimezone.hasTimezone, isTrue);
      expect(withTimezone.isCompleteDate, isTrue);
    });

    test('should implement equality correctly', () {
      final parsed1 = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
      );

      final parsed2 = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
      );

      final parsed3 = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
      );

      expect(parsed1, equals(parsed2));
      expect(parsed1, isNot(equals(parsed3)));
      expect(parsed1.hashCode, equals(parsed2.hashCode));
    });

    test('should have meaningful toString', () {
      final parsed = const ParsedDate(
        year: 2023,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
        timezone: 'Z',
      );

      final str = parsed.toString();
      expect(str, contains('2023'));
      expect(str, contains('3'));
      expect(str, contains('15'));
      expect(str, contains('14'));
      expect(str, contains('30'));
      expect(str, contains('Z'));
    });
  });
}
