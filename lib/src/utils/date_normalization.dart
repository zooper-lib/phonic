/// Date normalization utilities for converting between different date formats.
///
/// This module provides utilities for converting date values between the
/// unified ISO-8601 format used by the Phonic API and the container-specific
/// date formats used by different audio metadata formats.
///
/// The unified API uses ISO-8601 format for consistency and interoperability,
/// but different container formats use different internal representations:
/// - ID3v2.4: TDRC frame with ISO-8601 format
/// - ID3v2.3: Separate TYER/TDAT/TIME frames for year/date/time components
/// - ID3v2.2: TYE frame for year only
/// - Vorbis Comments: DATE field with ISO-8601 format
/// - MP4 atoms: ©day atom with ISO-8601 format
/// - ID3v1: Year field (4 digits, limited range)
///
/// This module handles the conversion between these formats while preserving
/// precision and handling edge cases appropriately.

/// Utility class for date format conversion and normalization.
///
/// This class provides static methods for converting date values between
/// the unified ISO-8601 format and container-specific formats. All conversions
/// are designed to preserve as much information as possible while handling
/// format limitations gracefully.
///
/// The conversion algorithms handle various levels of date precision:
/// - Year only (YYYY)
/// - Year and month (YYYY-MM)
/// - Full date (YYYY-MM-DD)
/// - Date with time (YYYY-MM-DDTHH:MM:SS)
/// - Date with timezone (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DDTHH:MM:SS±HH:MM)
///
/// Example usage:
/// ```dart
/// // Convert from ID3v2.3 components to ISO-8601
/// final iso8601Date = DateNormalization.fromId3v23Components(
///   year: '2023',
///   date: '1503', // DDMM format
///   time: '1430', // HHMM format
/// ); // Returns '2023-03-15T14:30:00'
///
/// // Convert from ISO-8601 to ID3v2.3 components
/// final components = DateNormalization.toId3v23Components('2023-03-15T14:30:00');
/// // Returns Id3v23DateComponents(year: '2023', date: '1503', time: '1430')
///
/// // Parse and validate ISO-8601 date
/// final parsedDate = DateNormalization.parseIso8601Date('2023-03-15');
/// // Returns ParsedDate with year: 2023, month: 3, day: 15
/// ```
class DateNormalization {
  /// Private constructor to prevent instantiation of utility class.
  const DateNormalization._();

  /// Regular expression for validating ISO-8601 date formats.
  ///
  /// Supports the following formats:
  /// - YYYY (year only)
  /// - YYYY-MM (year and month)
  /// - YYYY-MM-DD (full date)
  /// - YYYY-MM-DDTHH:MM:SS (date and time)
  /// - YYYY-MM-DDTHH:MM:SSZ (date and time with UTC timezone)
  /// - YYYY-MM-DDTHH:MM:SS±HH:MM (date and time with timezone offset)
  /// - YYYY-MM-DDTHH:MM:SS.SSS (date and time with milliseconds)
  static final RegExp _iso8601Pattern = RegExp(
    r'^(\d{4})' // Year (YYYY)
    r'(?:-(\d{2}))?' // Optional month (-MM)
    r'(?:-(\d{2}))?' // Optional day (-DD)
    r'(?:T(\d{2}):(\d{2}):(\d{2}))?' // Optional time (THH:MM:SS)
    r'(?:\.(\d{1,3}))?' // Optional milliseconds (.SSS)
    r'(?:(Z)|([+-]\d{2}):?(\d{2}))?$', // Optional timezone (Z or ±HH:MM)
  );

  /// Regular expression for validating ID3v2.3 TDAT format (DDMM).
  static final RegExp _tdatPattern = RegExp(r'^(\d{2})(\d{2})$');

  /// Regular expression for validating ID3v2.3 TIME format (HHMM).
  static final RegExp _timePattern = RegExp(r'^(\d{2})(\d{2})$');

  /// Converts ID3v2.3 date components (TYER/TDAT/TIME) to ISO-8601 format.
  ///
  /// ID3v2.3 uses separate frames for date components:
  /// - TYER: Year (YYYY format)
  /// - TDAT: Date (DDMM format, day and month)
  /// - TIME: Time (HHMM format, hour and minute)
  ///
  /// This method combines these components into a single ISO-8601 formatted
  /// string. Missing components are handled gracefully - if only year is
  /// provided, returns year-only format; if date is also provided, returns
  /// full date format, etc.
  ///
  /// @param year The year component (YYYY format), required
  /// @param date The date component (DDMM format), optional
  /// @param time The time component (HHMM format), optional
  /// @returns ISO-8601 formatted date string
  /// @throws ArgumentError if year is invalid or date/time formats are malformed
  ///
  /// Example:
  /// ```dart
  /// // Year only
  /// final yearOnly = DateNormalization.fromId3v23Components(year: '2023');
  /// // Returns '2023'
  ///
  /// // Year and date
  /// final withDate = DateNormalization.fromId3v23Components(
  ///   year: '2023',
  ///   date: '1503', // March 15th
  /// );
  /// // Returns '2023-03-15'
  ///
  /// // Full date and time
  /// final fullDateTime = DateNormalization.fromId3v23Components(
  ///   year: '2023',
  ///   date: '1503',
  ///   time: '1430', // 14:30
  /// );
  /// // Returns '2023-03-15T14:30:00'
  /// ```
  static String fromId3v23Components({
    required String year,
    String? date,
    String? time,
  }) {
    // Validate year
    final yearInt = int.tryParse(year);
    if (yearInt == null || year.length != 4 || yearInt < 1900 || yearInt > 2100) {
      throw ArgumentError.value(
        year,
        'year',
        'Year must be a 4-digit number between 1900 and 2100',
      );
    }

    // If no date provided, return year only
    if (date == null || date.trim().isEmpty) {
      return year;
    }

    // Validate and parse date (DDMM format)
    final dateMatch = _tdatPattern.firstMatch(date.trim());
    if (dateMatch == null) {
      throw ArgumentError.value(
        date,
        'date',
        'Date must be in DDMM format (e.g., "1503" for March 15th)',
      );
    }

    final day = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);

    // Validate date components
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        date,
        'date',
        'Month must be between 01 and 12',
      );
    }

    if (day < 1 || day > _getDaysInMonth(yearInt, month)) {
      throw ArgumentError.value(
        date,
        'date',
        'Day $day is not valid for year $yearInt month $month',
      );
    }

    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');

    // If no time provided, return date only
    if (time == null || time.trim().isEmpty) {
      return '$year-$monthStr-$dayStr';
    }

    // Validate and parse time (HHMM format)
    final timeMatch = _timePattern.firstMatch(time.trim());
    if (timeMatch == null) {
      throw ArgumentError.value(
        time,
        'time',
        'Time must be in HHMM format (e.g., "1430" for 14:30)',
      );
    }

    final hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);

    // Validate time components
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(
        time,
        'time',
        'Hour must be between 00 and 23',
      );
    }

    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(
        time,
        'time',
        'Minute must be between 00 and 59',
      );
    }

    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');

    return '$year-$monthStr-${dayStr}T$hourStr:$minuteStr:00';
  }

  /// Converts an ISO-8601 date string to ID3v2.3 date components.
  ///
  /// This method parses an ISO-8601 formatted date and extracts the components
  /// needed for ID3v2.3 frames (TYER/TDAT/TIME). The conversion handles various
  /// levels of precision in the input date.
  ///
  /// @param iso8601Date The ISO-8601 formatted date string
  /// @returns Id3v23DateComponents containing year, date, and time components
  /// @throws ArgumentError if the date string is not valid ISO-8601 format
  ///
  /// Example:
  /// ```dart
  /// // Full date and time
  /// final components = DateNormalization.toId3v23Components('2023-03-15T14:30:00');
  /// // Returns Id3v23DateComponents(year: '2023', date: '1503', time: '1430')
  ///
  /// // Date only
  /// final dateOnly = DateNormalization.toId3v23Components('2023-03-15');
  /// // Returns Id3v23DateComponents(year: '2023', date: '1503', time: null)
  ///
  /// // Year only
  /// final yearOnly = DateNormalization.toId3v23Components('2023');
  /// // Returns Id3v23DateComponents(year: '2023', date: null, time: null)
  /// ```
  static Id3v23DateComponents toId3v23Components(String iso8601Date) {
    final parsedDate = parseIso8601Date(iso8601Date);

    final year = parsedDate.year.toString().padLeft(4, '0');

    String? date;
    if (parsedDate.month != null && parsedDate.day != null) {
      final dayStr = parsedDate.day!.toString().padLeft(2, '0');
      final monthStr = parsedDate.month!.toString().padLeft(2, '0');
      date = '$dayStr$monthStr'; // DDMM format
    }

    String? time;
    if (parsedDate.hour != null && parsedDate.minute != null) {
      final hourStr = parsedDate.hour!.toString().padLeft(2, '0');
      final minuteStr = parsedDate.minute!.toString().padLeft(2, '0');
      time = '$hourStr$minuteStr'; // HHMM format
    }

    return Id3v23DateComponents(
      year: year,
      date: date,
      time: time,
    );
  }

  /// Parses an ISO-8601 date string into its component parts.
  ///
  /// This method provides detailed parsing of ISO-8601 formatted dates,
  /// extracting all available components including year, month, day, hour,
  /// minute, second, milliseconds, and timezone information.
  ///
  /// @param iso8601Date The ISO-8601 formatted date string to parse
  /// @returns ParsedDate containing all extracted date components
  /// @throws ArgumentError if the date string is not valid ISO-8601 format
  ///
  /// Example:
  /// ```dart
  /// // Parse full date and time with timezone
  /// final parsed = DateNormalization.parseIso8601Date('2023-03-15T14:30:00Z');
  /// // Returns ParsedDate with all components filled
  ///
  /// // Parse date only
  /// final dateOnly = DateNormalization.parseIso8601Date('2023-03-15');
  /// // Returns ParsedDate with year, month, day filled, time components null
  /// ```
  static ParsedDate parseIso8601Date(String iso8601Date) {
    if (iso8601Date.trim().isEmpty) {
      throw ArgumentError.value(
        iso8601Date,
        'iso8601Date',
        'Date string cannot be empty',
      );
    }

    final trimmedDate = iso8601Date.trim();
    final match = _iso8601Pattern.firstMatch(trimmedDate);

    if (match == null) {
      throw ArgumentError.value(
        iso8601Date,
        'iso8601Date',
        'Date must be in ISO-8601 format (e.g., "2023", "2023-03-15", "2023-03-15T14:30:00Z")',
      );
    }

    final year = int.parse(match.group(1)!);
    final monthStr = match.group(2);
    final dayStr = match.group(3);
    final hourStr = match.group(4);
    final minuteStr = match.group(5);
    final secondStr = match.group(6);
    final millisecondStr = match.group(7);
    final isUtc = match.group(8) == 'Z';
    final timezoneHourStr = match.group(9);
    final timezoneMinuteStr = match.group(10);

    // Validate year range
    if (year < 1900 || year > 2100) {
      throw ArgumentError.value(
        iso8601Date,
        'iso8601Date',
        'Year must be between 1900 and 2100 (inclusive)',
      );
    }

    int? month;
    if (monthStr != null) {
      month = int.parse(monthStr);
      if (month < 1 || month > 12) {
        throw ArgumentError.value(
          iso8601Date,
          'iso8601Date',
          'Month must be between 01 and 12',
        );
      }
    }

    int? day;
    if (dayStr != null && month != null) {
      day = int.parse(dayStr);
      if (day < 1 || day > _getDaysInMonth(year, month)) {
        throw ArgumentError.value(
          iso8601Date,
          'iso8601Date',
          'Day $day is not valid for year $year month $month',
        );
      }
    }

    int? hour;
    if (hourStr != null) {
      hour = int.parse(hourStr);
      if (hour < 0 || hour > 23) {
        throw ArgumentError.value(
          iso8601Date,
          'iso8601Date',
          'Hour must be between 00 and 23',
        );
      }
    }

    int? minute;
    if (minuteStr != null) {
      minute = int.parse(minuteStr);
      if (minute < 0 || minute > 59) {
        throw ArgumentError.value(
          iso8601Date,
          'iso8601Date',
          'Minute must be between 00 and 59',
        );
      }
    }

    int? second;
    if (secondStr != null) {
      second = int.parse(secondStr);
      if (second < 0 || second > 59) {
        throw ArgumentError.value(
          iso8601Date,
          'iso8601Date',
          'Second must be between 00 and 59',
        );
      }
    }

    int? millisecond;
    if (millisecondStr != null) {
      // Pad or truncate to 3 digits
      final paddedMs = millisecondStr.padRight(3, '0').substring(0, 3);
      millisecond = int.parse(paddedMs);
    }

    String? timezone;
    if (isUtc) {
      timezone = 'Z';
    } else if (timezoneHourStr != null && timezoneMinuteStr != null) {
      timezone = '$timezoneHourStr:$timezoneMinuteStr';
    }

    return ParsedDate(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      millisecond: millisecond,
      timezone: timezone,
    );
  }

  /// Validates an ISO-8601 date string without parsing it.
  ///
  /// This method provides a quick way to check if a date string is valid
  /// ISO-8601 format without the overhead of full parsing. It performs
  /// the same validation as [parseIso8601Date] but returns a boolean
  /// result instead of throwing exceptions.
  ///
  /// @param iso8601Date The date string to validate
  /// @returns true if the date is valid ISO-8601 format, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = DateNormalization.isValidIso8601Date('2023-03-15'); // true
  /// final isInvalid = DateNormalization.isValidIso8601Date('2023/03/15'); // false
  /// ```
  static bool isValidIso8601Date(String iso8601Date) {
    try {
      parseIso8601Date(iso8601Date);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Normalizes an ISO-8601 date string to a canonical format.
  ///
  /// This method parses an ISO-8601 date and reconstructs it in a canonical
  /// format, ensuring consistent representation. It handles various input
  /// formats and normalizes them to standard ISO-8601 format.
  ///
  /// @param iso8601Date The date string to normalize
  /// @returns Normalized ISO-8601 date string
  /// @throws ArgumentError if the input date is not valid ISO-8601 format
  ///
  /// Example:
  /// ```dart
  /// // Normalize various formats
  /// final normalized1 = DateNormalization.normalizeIso8601Date('2023-3-5');
  /// // Returns '2023-03-05'
  ///
  /// final normalized2 = DateNormalization.normalizeIso8601Date('2023-03-15T14:30:00+02:00');
  /// // Returns '2023-03-15T14:30:00+02:00'
  /// ```
  static String normalizeIso8601Date(String iso8601Date) {
    final parsed = parseIso8601Date(iso8601Date);
    return _formatParsedDate(parsed);
  }

  /// Extracts the year component from an ISO-8601 date string.
  ///
  /// This method provides a convenient way to extract just the year
  /// from a date string without full parsing overhead.
  ///
  /// @param iso8601Date The ISO-8601 date string
  /// @returns The year as an integer
  /// @throws ArgumentError if the date string is invalid
  ///
  /// Example:
  /// ```dart
  /// final year = DateNormalization.extractYear('2023-03-15T14:30:00Z'); // 2023
  /// ```
  static int extractYear(String iso8601Date) {
    final parsed = parseIso8601Date(iso8601Date);
    return parsed.year;
  }

  /// Formats a ParsedDate back to ISO-8601 string format.
  static String _formatParsedDate(ParsedDate parsed) {
    final buffer = StringBuffer();

    // Year is always present
    buffer.write(parsed.year.toString().padLeft(4, '0'));

    // Add month if present
    if (parsed.month != null) {
      buffer.write('-${parsed.month!.toString().padLeft(2, '0')}');

      // Add day if present
      if (parsed.day != null) {
        buffer.write('-${parsed.day!.toString().padLeft(2, '0')}');

        // Add time if present
        if (parsed.hour != null && parsed.minute != null) {
          buffer.write('T${parsed.hour!.toString().padLeft(2, '0')}');
          buffer.write(':${parsed.minute!.toString().padLeft(2, '0')}');

          // Add seconds (default to 00 if not specified but time is present)
          final second = parsed.second ?? 0;
          buffer.write(':${second.toString().padLeft(2, '0')}');

          // Add milliseconds if present
          if (parsed.millisecond != null) {
            buffer.write('.${parsed.millisecond!.toString().padLeft(3, '0')}');
          }

          // Add timezone if present
          if (parsed.timezone != null) {
            buffer.write(parsed.timezone!);
          }
        }
      }
    }

    return buffer.toString();
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
}

/// Represents the components of an ID3v2.3 date structure.
///
/// ID3v2.3 uses separate frames for date components:
/// - TYER: Year (YYYY format)
/// - TDAT: Date (DDMM format)
/// - TIME: Time (HHMM format)
///
/// This class encapsulates these components for easy conversion between
/// ID3v2.3 format and ISO-8601 format.
class Id3v23DateComponents {
  /// The year component in YYYY format.
  final String year;

  /// The date component in DDMM format (day and month).
  ///
  /// Null if only year information is available.
  final String? date;

  /// The time component in HHMM format (hour and minute).
  ///
  /// Null if time information is not available.
  final String? time;

  /// Creates a new Id3v23DateComponents instance.
  ///
  /// @param year The year in YYYY format (required)
  /// @param date The date in DDMM format (optional)
  /// @param time The time in HHMM format (optional)
  const Id3v23DateComponents({
    required this.year,
    this.date,
    this.time,
  });

  @override
  String toString() {
    final buffer = StringBuffer('Id3v23DateComponents(year: $year');
    if (date != null) {
      buffer.write(', date: $date');
    }
    if (time != null) {
      buffer.write(', time: $time');
    }
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Id3v23DateComponents && other.year == year && other.date == date && other.time == time;
  }

  @override
  int get hashCode => Object.hash(year, date, time);
}

/// Represents a parsed ISO-8601 date with all its components.
///
/// This class provides structured access to all components of an ISO-8601
/// date, including optional components like time and timezone information.
/// Components that are not present in the original date string will be null.
class ParsedDate {
  /// The year component (always present).
  final int year;

  /// The month component (1-12), null if not specified.
  final int? month;

  /// The day component (1-31), null if not specified.
  final int? day;

  /// The hour component (0-23), null if not specified.
  final int? hour;

  /// The minute component (0-59), null if not specified.
  final int? minute;

  /// The second component (0-59), null if not specified.
  final int? second;

  /// The millisecond component (0-999), null if not specified.
  final int? millisecond;

  /// The timezone component (e.g., 'Z', '+02:00'), null if not specified.
  final String? timezone;

  /// Creates a new ParsedDate instance.
  const ParsedDate({
    required this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
    this.second,
    this.millisecond,
    this.timezone,
  });

  /// Returns true if this date includes time information.
  bool get hasTime => hour != null && minute != null;

  /// Returns true if this date includes timezone information.
  bool get hasTimezone => timezone != null;

  /// Returns true if this date is a complete date (year, month, day).
  bool get isCompleteDate => month != null && day != null;

  @override
  String toString() {
    final buffer = StringBuffer('ParsedDate(year: $year');
    if (month != null) buffer.write(', month: $month');
    if (day != null) buffer.write(', day: $day');
    if (hour != null) buffer.write(', hour: $hour');
    if (minute != null) buffer.write(', minute: $minute');
    if (second != null) buffer.write(', second: $second');
    if (millisecond != null) buffer.write(', millisecond: $millisecond');
    if (timezone != null) buffer.write(', timezone: $timezone');
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedDate &&
        other.year == year &&
        other.month == month &&
        other.day == day &&
        other.hour == hour &&
        other.minute == minute &&
        other.second == second &&
        other.millisecond == millisecond &&
        other.timezone == timezone;
  }

  @override
  int get hashCode => Object.hash(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    timezone,
  );
}
