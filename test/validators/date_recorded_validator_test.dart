import 'package:phonic/src/validators/date_recorded_validator.dart';
import 'package:test/test.dart';

void main() {
  group('DateRecordedValidator', () {
    const validator = DateRecordedValidator();

    group('validate', () {
      group('valid dates', () {
        test('accepts null values', () {
          expect(validator.validate(null), isNull);
        });

        test('accepts year-only format', () {
          expect(validator.validate('2023'), isNull);
          expect(validator.validate('1900'), isNull);
          expect(validator.validate('2100'), isNull);
          expect(validator.validate('1999'), isNull);
        });

        test('accepts year-month format', () {
          expect(validator.validate('2023-01'), isNull);
          expect(validator.validate('2023-12'), isNull);
          expect(validator.validate('2000-06'), isNull);
        });

        test('accepts full date format', () {
          expect(validator.validate('2023-03-15'), isNull);
          expect(validator.validate('2000-01-01'), isNull);
          expect(validator.validate('2023-12-31'), isNull);
        });

        test('accepts date with time', () {
          expect(validator.validate('2023-03-15T14:30:00'), isNull);
          expect(validator.validate('2023-01-01T00:00:00'), isNull);
          expect(validator.validate('2023-12-31T23:59:59'), isNull);
        });

        test('accepts date with UTC timezone', () {
          expect(validator.validate('2023-03-15T14:30:00Z'), isNull);
          expect(validator.validate('2023-01-01T00:00:00Z'), isNull);
        });

        test('accepts date with timezone offset', () {
          expect(validator.validate('2023-03-15T14:30:00+02:00'), isNull);
          expect(validator.validate('2023-03-15T14:30:00-05:00'), isNull);
          expect(validator.validate('2023-03-15T14:30:00+00:00'), isNull);
        });

        test('accepts date with milliseconds', () {
          expect(validator.validate('2023-03-15T14:30:00.123'), isNull);
          expect(validator.validate('2023-03-15T14:30:00.1Z'), isNull);
        });

        test('accepts leap year dates', () {
          expect(validator.validate('2024-02-29'), isNull); // Leap year
          expect(validator.validate('2000-02-29'), isNull); // Leap year
        });

        test('trims whitespace from valid dates', () {
          expect(validator.validate('  2023  '), isNull);
          expect(validator.validate(' 2023-03-15 '), isNull);
          expect(validator.validate('\t2023-03-15T14:30:00Z\n'), isNull);
        });
      });

      group('empty values', () {
        test('rejects empty string', () {
          final error = validator.validate('');
          expect(error, isNotNull);
          expect(error!.containsKey('empty'), isTrue);
        });

        test('rejects whitespace-only string', () {
          final error = validator.validate('   ');
          expect(error, isNotNull);
          expect(error!.containsKey('empty'), isTrue);
        });

        test('rejects tabs and newlines', () {
          final error = validator.validate('\t\n  ');
          expect(error, isNotNull);
          expect(error!.containsKey('empty'), isTrue);
        });
      });

      group('invalid format', () {
        test('rejects non-ISO-8601 formats', () {
          final testCases = [
            'March 2023',
            '03/15/2023',
            '15-03-2023',
            '2023/03/15',
            'not a date',
            '23',
            '202',
          ];

          for (final testCase in testCases) {
            final error = validator.validate(testCase);
            expect(error, isNotNull, reason: 'Expected error for: $testCase');
            expect(error!.containsKey('invalidFormat'), isTrue, reason: 'Expected invalidFormat error for: $testCase');
          }
        });

        test('rejects partial timestamps', () {
          expect(validator.validate('2023-03-15T14'), isNotNull);
          expect(validator.validate('2023-03-15T14:30'), isNotNull);
        });
      });

      group('year validation', () {
        test('rejects years before 1900', () {
          final error = validator.validate('1899');
          expect(error, isNotNull);
          expect(error!.containsKey('yearOutOfRange'), isTrue);

          final details = error['yearOutOfRange'] as Map<String, dynamic>;
          expect(details['min'], equals(1900));
          expect(details['max'], equals(2100));
          expect(details['actual'], equals(1899));
        });

        test('rejects years after 2100', () {
          final error = validator.validate('2101');
          expect(error, isNotNull);
          expect(error!.containsKey('yearOutOfRange'), isTrue);

          final details = error['yearOutOfRange'] as Map<String, dynamic>;
          expect(details['actual'], equals(2101));
        });

        test('rejects year out of range in full dates', () {
          expect(validator.validate('1800-03-15'), isNotNull);
          expect(validator.validate('2200-03-15'), isNotNull);
        });
      });

      group('month validation', () {
        test('rejects month 00', () {
          final error = validator.validate('2023-00');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidMonth'), isTrue);

          final details = error['invalidMonth'] as Map<String, dynamic>;
          expect(details['actual'], equals(0));
          expect(details['min'], equals(1));
          expect(details['max'], equals(12));
        });

        test('rejects month 13', () {
          final error = validator.validate('2023-13');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidMonth'), isTrue);

          final details = error['invalidMonth'] as Map<String, dynamic>;
          expect(details['actual'], equals(13));
        });

        test('rejects invalid months in full dates', () {
          expect(validator.validate('2023-00-15'), isNotNull);
          expect(validator.validate('2023-13-15'), isNotNull);
        });
      });

      group('day validation', () {
        test('rejects day 00', () {
          final error = validator.validate('2023-03-00');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidDay'), isTrue);
        });

        test('rejects day 32 for 31-day months', () {
          final error = validator.validate('2023-01-32');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidDay'), isTrue);
        });

        test('rejects day 31 for 30-day months', () {
          final error = validator.validate('2023-04-31');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidDay'), isTrue);

          final details = error['invalidDay'] as Map<String, dynamic>;
          expect(details['actual'], equals(31));
          expect(details['max'], equals(30));
          expect(details['year'], equals(2023));
          expect(details['month'], equals(4));
        });

        test('rejects February 30', () {
          final error = validator.validate('2023-02-30');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidDay'), isTrue);
        });

        test('rejects February 29 in non-leap years', () {
          final error = validator.validate('2023-02-29'); // 2023 is not a leap year
          expect(error, isNotNull);
          expect(error!.containsKey('invalidDay'), isTrue);

          final details = error['invalidDay'] as Map<String, dynamic>;
          expect(details['max'], equals(28));
        });

        test('validates days for all 31-day months', () {
          final months31 = [1, 3, 5, 7, 8, 10, 12];
          for (final month in months31) {
            final monthStr = month.toString().padLeft(2, '0');
            expect(validator.validate('2023-$monthStr-31'), isNull, reason: 'Month $month should allow day 31');
          }
        });

        test('validates days for all 30-day months', () {
          final months30 = [4, 6, 9, 11];
          for (final month in months30) {
            final monthStr = month.toString().padLeft(2, '0');
            expect(validator.validate('2023-$monthStr-30'), isNull, reason: 'Month $month should allow day 30');
            expect(validator.validate('2023-$monthStr-31'), isNotNull, reason: 'Month $month should reject day 31');
          }
        });
      });

      group('time component validation', () {
        test('rejects hour 24', () {
          final error = validator.validate('2023-03-15T24:00:00');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidHour'), isTrue);

          final details = error['invalidHour'] as Map<String, dynamic>;
          expect(details['actual'], equals(24));
          expect(details['min'], equals(0));
          expect(details['max'], equals(23));
        });

        test('rejects hour 25', () {
          final error = validator.validate('2023-03-15T25:00:00');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidHour'), isTrue);
        });

        test('rejects minute 60', () {
          final error = validator.validate('2023-03-15T14:60:00');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidMinute'), isTrue);

          final details = error['invalidMinute'] as Map<String, dynamic>;
          expect(details['actual'], equals(60));
          expect(details['min'], equals(0));
          expect(details['max'], equals(59));
        });

        test('rejects second 60', () {
          final error = validator.validate('2023-03-15T14:30:60');
          expect(error, isNotNull);
          expect(error!.containsKey('invalidSecond'), isTrue);

          final details = error['invalidSecond'] as Map<String, dynamic>;
          expect(details['actual'], equals(60));
          expect(details['min'], equals(0));
          expect(details['max'], equals(59));
        });

        test('accepts time 00:00:00', () {
          expect(validator.validate('2023-03-15T00:00:00'), isNull);
        });

        test('accepts time 23:59:59', () {
          expect(validator.validate('2023-03-15T23:59:59'), isNull);
        });
      });
    });

    group('validateOrThrow', () {
      test('returns trimmed value for valid dates', () {
        expect(validator.validateOrThrow('  2023  '), equals('2023'));
        expect(validator.validateOrThrow(' 2023-03-15 '), equals('2023-03-15'));
      });

      test('throws ArgumentError for empty string', () {
        expect(
          () => validator.validateOrThrow(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for invalid format', () {
        expect(
          () => validator.validateOrThrow('March 2023'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for year out of range', () {
        expect(
          () => validator.validateOrThrow('1899'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for invalid month', () {
        expect(
          () => validator.validateOrThrow('2023-13'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for invalid day', () {
        expect(
          () => validator.validateOrThrow('2023-02-30'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('formatErrorMessage', () {
      test('formats empty error', () {
        final error = {
          'empty': {'actual': ''},
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Date recorded cannot be empty'),
        );
      });

      test('formats invalidFormat error', () {
        final error = {
          'invalidFormat': {
            'actual': 'March 2023',
            'expected': 'ISO-8601 format',
          },
        };
        expect(
          validator.formatErrorMessage(error),
          contains('ISO-8601 format'),
        );
      });

      test('formats yearOutOfRange error', () {
        final error = {
          'yearOutOfRange': {
            'min': 1900,
            'max': 2100,
            'actual': 1899,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Year must be between 1900 and 2100 (inclusive)'),
        );
      });

      test('formats invalidMonth error', () {
        final error = {
          'invalidMonth': {
            'actual': 13,
            'min': 1,
            'max': 12,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Month must be between 01 and 12'),
        );
      });

      test('formats invalidDay error', () {
        final error = {
          'invalidDay': {
            'actual': 31,
            'max': 30,
            'year': 2023,
            'month': 4,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Day 31 is not valid for year 2023 month 4'),
        );
      });

      test('formats invalidHour error', () {
        final error = {
          'invalidHour': {
            'actual': 24,
            'min': 0,
            'max': 23,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Hour must be between 00 and 23'),
        );
      });

      test('formats invalidMinute error', () {
        final error = {
          'invalidMinute': {
            'actual': 60,
            'min': 0,
            'max': 59,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Minute must be between 00 and 59'),
        );
      });

      test('formats invalidSecond error', () {
        final error = {
          'invalidSecond': {
            'actual': 60,
            'min': 0,
            'max': 59,
          },
        };
        expect(
          validator.formatErrorMessage(error),
          equals('Second must be between 00 and 59'),
        );
      });

      test('returns generic message for unknown error', () {
        final error = {'unknown': {}};
        expect(
          validator.formatErrorMessage(error),
          equals('Invalid date recorded value'),
        );
      });
    });

    group('isValid static method', () {
      test('returns true for valid dates', () {
        expect(DateRecordedValidator.isValid('2023'), isTrue);
        expect(DateRecordedValidator.isValid('2023-03-15'), isTrue);
        expect(DateRecordedValidator.isValid('2023-03-15T14:30:00Z'), isTrue);
        expect(DateRecordedValidator.isValid(null), isTrue);
      });

      test('returns false for invalid dates', () {
        expect(DateRecordedValidator.isValid(''), isFalse);
        expect(DateRecordedValidator.isValid('March 2023'), isFalse);
        expect(DateRecordedValidator.isValid('1899'), isFalse);
        expect(DateRecordedValidator.isValid('2023-13-01'), isFalse);
        expect(DateRecordedValidator.isValid('2023-02-30'), isFalse);
      });
    });

    group('leap year handling', () {
      test('correctly identifies leap years divisible by 4', () {
        expect(validator.validate('2024-02-29'), isNull); // Divisible by 4
        expect(validator.validate('2020-02-29'), isNull); // Divisible by 4
      });

      test('correctly handles century years not divisible by 400', () {
        expect(validator.validate('1900-02-29'), isNotNull); // Not a leap year
        expect(validator.validate('2100-02-29'), isNotNull); // Not a leap year (if year range extended)
      });

      test('correctly handles century years divisible by 400', () {
        expect(validator.validate('2000-02-29'), isNull); // Leap year
      });

      test('rejects Feb 29 in non-leap years', () {
        expect(validator.validate('2023-02-29'), isNotNull);
        expect(validator.validate('2021-02-29'), isNotNull);
        expect(validator.validate('2022-02-29'), isNotNull);
      });

      test('accepts Feb 28 in all years', () {
        expect(validator.validate('2023-02-28'), isNull);
        expect(validator.validate('2024-02-28'), isNull);
        expect(validator.validate('1900-02-28'), isNull);
        expect(validator.validate('2000-02-28'), isNull);
      });
    });

    group('edge cases', () {
      test('handles minimum valid date', () {
        expect(validator.validate('1900-01-01'), isNull);
        expect(validator.validate('1900-01-01T00:00:00Z'), isNull);
      });

      test('handles maximum valid date', () {
        expect(validator.validate('2100-12-31'), isNull);
        expect(validator.validate('2100-12-31T23:59:59Z'), isNull);
      });

      test('handles boundary years', () {
        expect(validator.validate('1900'), isNull);
        expect(validator.validate('2100'), isNull);
        expect(validator.validate('1899'), isNotNull);
        expect(validator.validate('2101'), isNotNull);
      });

      test('handles all month boundaries', () {
        // January (31 days)
        expect(validator.validate('2023-01-31'), isNull);
        expect(validator.validate('2023-01-32'), isNotNull);

        // April (30 days)
        expect(validator.validate('2023-04-30'), isNull);
        expect(validator.validate('2023-04-31'), isNotNull);

        // February in leap year
        expect(validator.validate('2024-02-29'), isNull);
        expect(validator.validate('2024-02-30'), isNotNull);

        // February in non-leap year
        expect(validator.validate('2023-02-28'), isNull);
        expect(validator.validate('2023-02-29'), isNotNull);
      });
    });
  });
}
