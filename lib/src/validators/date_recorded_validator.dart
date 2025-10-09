import 'tag_validator.dart';

/// Validator for date recorded tag values in ISO-8601 format.
///
/// This validator ensures that date values conform to ISO-8601 format
/// with various levels of precision (year-only, year-month, full date,
/// date with time and timezone). It also validates date component ranges
/// and logical consistency (e.g., valid day for the given month/year).
///
/// Supported formats:
/// - Year only: "2023"
/// - Year-month: "2023-03"
/// - Full date: "2023-03-15"
/// - Date with time: "2023-03-15T14:30:00"
/// - Date with timezone: "2023-03-15T14:30:00Z"
/// - Date with offset: "2023-03-15T14:30:00+02:00"
///
/// Error keys:
/// - `empty`: Value is empty or contains only whitespace
/// - `invalidFormat`: Value doesn't match ISO-8601 format
/// - `yearOutOfRange`: Year is outside 1900-2100 range
/// - `invalidMonth`: Month is not between 01-12
/// - `invalidDay`: Day is not valid for the given month/year
/// - `invalidHour`: Hour is not between 00-23
/// - `invalidMinute`: Minute is not between 00-59
/// - `invalidSecond`: Second is not between 00-59
///
/// Example usage:
/// ```dart
/// const validator = DateRecordedValidator();
///
/// final error = validator.validate('2023-03-15');  // null (valid)
/// final error2 = validator.validate('');           // {empty: {...}}
/// final error3 = validator.validate('March 2023'); // {invalidFormat: {...}}
/// final error4 = validator.validate('2023-13-01'); // {invalidMonth: {...}}
/// ```
final class DateRecordedValidator extends TagValidator<String> {
  /// Regular expression for validating ISO-8601 date formats.
  static final RegExp _iso8601Pattern = RegExp(
    r'^(\d{4})' // Year (YYYY)
    r'(?:-(\d{2}))?' // Optional month (-MM)
    r'(?:-(\d{2}))?' // Optional day (-DD)
    r'(?:T(\d{2}):(\d{2}):(\d{2}))?' // Optional time (THH:MM:SS)
    r'(?:\.(\d{1,3}))?' // Optional milliseconds (.SSS)
    r'(?:(Z)|([+-]\d{2}):?(\d{2}))?$', // Optional timezone (Z or ±HH:MM)
  );

  /// The minimum valid year value (inclusive).
  static const int minYear = 1900;

  /// The maximum valid year value (inclusive).
  static const int maxYear = 2100;

  /// Error key for empty values.
  static const String emptyError = 'empty';

  /// Error key for invalid format.
  static const String invalidFormatError = 'invalidFormat';

  /// Error key for year out of range.
  static const String yearOutOfRangeError = 'yearOutOfRange';

  /// Error key for invalid month.
  static const String invalidMonthError = 'invalidMonth';

  /// Error key for invalid day.
  static const String invalidDayError = 'invalidDay';

  /// Error key for invalid hour.
  static const String invalidHourError = 'invalidHour';

  /// Error key for invalid minute.
  static const String invalidMinuteError = 'invalidMinute';

  /// Error key for invalid second.
  static const String invalidSecondError = 'invalidSecond';

  /// Creates a new date recorded validator.
  const DateRecordedValidator();

  @override
  Map<String, dynamic>? validate(String? value) {
    // Null values are allowed (optional field)
    if (value == null) return null;

    // Check for empty string
    if (value.trim().isEmpty) {
      return {
        emptyError: {
          'actual': value,
        },
      };
    }

    final trimmedValue = value.trim();

    // Check format
    if (!_iso8601Pattern.hasMatch(trimmedValue)) {
      return {
        invalidFormatError: {
          'actual': value,
          'expected': 'ISO-8601 format (e.g., "2023", "2023-03-15", "2023-03-15T14:30:00Z")',
        },
      };
    }

    // Parse and validate date components
    final match = _iso8601Pattern.firstMatch(trimmedValue)!;
    final year = int.parse(match.group(1)!);
    final monthStr = match.group(2);
    final dayStr = match.group(3);
    final hourStr = match.group(4);
    final minuteStr = match.group(5);
    final secondStr = match.group(6);

    // Validate year range
    if (year < minYear || year > maxYear) {
      return {
        yearOutOfRangeError: {
          'min': minYear,
          'max': maxYear,
          'actual': year,
        },
      };
    }

    // Validate month if present
    if (monthStr != null) {
      final month = int.parse(monthStr);
      if (month < 1 || month > 12) {
        return {
          invalidMonthError: {
            'actual': month,
            'min': 1,
            'max': 12,
          },
        };
      }

      // Validate day if present
      if (dayStr != null) {
        final day = int.parse(dayStr);
        final maxDays = _getDaysInMonth(year, month);

        if (day < 1 || day > maxDays) {
          return {
            invalidDayError: {
              'actual': day,
              'max': maxDays,
              'year': year,
              'month': month,
            },
          };
        }
      }
    }

    // Validate time components if present
    if (hourStr != null) {
      final hour = int.parse(hourStr);
      if (hour < 0 || hour > 23) {
        return {
          invalidHourError: {
            'actual': hour,
            'min': 0,
            'max': 23,
          },
        };
      }
    }

    if (minuteStr != null) {
      final minute = int.parse(minuteStr);
      if (minute < 0 || minute > 59) {
        return {
          invalidMinuteError: {
            'actual': minute,
            'min': 0,
            'max': 59,
          },
        };
      }
    }

    if (secondStr != null) {
      final second = int.parse(secondStr);
      if (second < 0 || second > 59) {
        return {
          invalidSecondError: {
            'actual': second,
            'min': 0,
            'max': 59,
          },
        };
      }
    }

    return null;
  }

  @override
  String validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) {
      throw ArgumentError(formatErrorMessage(error));
    }
    // Return trimmed value (normalized)
    return value.trim();
  }

  @override
  String formatErrorMessage(Map<String, dynamic> error) {
    if (error.containsKey(emptyError)) {
      return 'Date recorded cannot be empty';
    }
    if (error.containsKey(invalidFormatError)) {
      return 'Date must be in ISO-8601 format (e.g., "2023", "2023-03-15", "2023-03-15T14:30:00Z")';
    }
    if (error.containsKey(yearOutOfRangeError)) {
      return 'Year must be between $minYear and $maxYear (inclusive)';
    }
    if (error.containsKey(invalidMonthError)) {
      return 'Month must be between 01 and 12';
    }
    if (error.containsKey(invalidDayError)) {
      final details = error[invalidDayError] as Map<String, dynamic>;
      final year = details['year'];
      final month = details['month'];
      final day = details['actual'];
      return 'Day $day is not valid for year $year month $month';
    }
    if (error.containsKey(invalidHourError)) {
      return 'Hour must be between 00 and 23';
    }
    if (error.containsKey(invalidMinuteError)) {
      return 'Minute must be between 00 and 59';
    }
    if (error.containsKey(invalidSecondError)) {
      return 'Second must be between 00 and 59';
    }
    return 'Invalid date recorded value';
  }

  /// Returns the number of days in the specified month and year.
  ///
  /// Accounts for leap years when calculating February days.
  static int _getDaysInMonth(int year, int month) {
    switch (month) {
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        return _isLeapYear(year) ? 29 : 28;
      default:
        return 31; // Should never reach here due to month validation
    }
  }

  /// Determines if the specified year is a leap year.
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Checks if a value is a valid ISO-8601 date.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(String? value) {
    return const DateRecordedValidator().validate(value) == null;
  }
}
