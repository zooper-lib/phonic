part of '../metadata_tag.dart';

/// Represents a date recorded metadata tag for audio files.
///
/// DateRecordedTag contains the full recording or release date of the track,
/// providing precise temporal information for music libraries and organization
/// systems. This tag helps users sort, filter, and organize their music
/// collections by exact dates and discover music from specific time periods.
///
/// The date value must be in ISO-8601 format, supporting various levels of
/// precision from year-only to full date-time with timezone information.
/// This validation ensures data integrity and cross-platform compatibility
/// while accommodating different levels of date precision available in
/// source metadata.
///
/// Supported ISO-8601 formats:
/// - Year only: "2023"
/// - Year-month: "2023-03"
/// - Full date: "2023-03-15"
/// - Date with time: "2023-03-15T14:30:00"
/// - Date with timezone: "2023-03-15T14:30:00Z"
/// - Date with offset: "2023-03-15T14:30:00+02:00"
///
/// Format mappings:
/// - ID3v2: TDRC frame (v2.4) or TYER/TDAT/TIME combination (v2.3)
/// - Vorbis: DATE field
/// - MP4: ©day atom
/// - ID3v1: Not supported (year portion extracted to year field)
///
/// Example usage:
/// ```dart
/// // Create a basic date tag with full date
/// final dateTag = DateRecordedTag('2023-03-15');
///
/// // Create with year only
/// final yearOnlyTag = DateRecordedTag('2023');
///
/// // Create with full timestamp
/// final timestampTag = DateRecordedTag('2023-03-15T14:30:00Z');
///
/// // Create with provenance information
/// final dateWithProvenance = DateRecordedTag(
///   '2023-03-15',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = dateTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The date value must be a valid ISO-8601 formatted string. Invalid formats
/// will cause an ArgumentError to be thrown during construction. This ensures
/// consistent date handling across different container formats and platforms.
final class DateRecordedTag extends MetadataTag<String> {
  /// Regular expression for validating ISO-8601 date formats.
  ///
  /// Supports the following formats:
  /// - YYYY (year only)
  /// - YYYY-MM (year and month)
  /// - YYYY-MM-DD (full date)
  /// - YYYY-MM-DDTHH:MM:SS (date and time)
  /// - YYYY-MM-DDTHH:MM:SSZ (date and time with UTC timezone)
  /// - YYYY-MM-DDTHH:MM:SS±HH:MM (date and time with timezone offset)
  static final RegExp _iso8601Pattern = RegExp(
    r'^(\d{4})' // Year (YYYY)
    r'(?:-(\d{2}))?' // Optional month (-MM)
    r'(?:-(\d{2}))?' // Optional day (-DD)
    r'(?:T(\d{2}):(\d{2}):(\d{2}))?' // Optional time (THH:MM:SS)
    r'(?:\.(\d{1,3}))?' // Optional milliseconds (.SSS)
    r'(?:(Z)|([+-]\d{2}):?(\d{2}))?$', // Optional timezone (Z or ±HH:MM)
  );

  /// Creates a new DateRecordedTag with the specified ISO-8601 date.
  ///
  /// @param value The recording date in ISO-8601 format
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is not a valid ISO-8601 date format
  ///
  /// Example:
  /// ```dart
  /// final tag = DateRecordedTag('2023-03-15');
  /// final yearOnly = DateRecordedTag('2023');
  /// final withTime = DateRecordedTag('2023-03-15T14:30:00Z');
  /// ```
  DateRecordedTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: _validateIso8601Date(value),
         key: TagKey.dateRecorded,
         provenance: provenance,
       );

  /// Validates that the date string is in valid ISO-8601 format.
  ///
  /// @param value The date string to validate
  /// @returns The validated date string
  /// @throws ArgumentError if the date is not in valid ISO-8601 format
  static String _validateIso8601Date(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Date recorded cannot be empty',
      );
    }

    final trimmedValue = value.trim();

    if (!_iso8601Pattern.hasMatch(trimmedValue)) {
      throw ArgumentError.value(
        value,
        'value',
        'Date must be in ISO-8601 format (e.g., "2023", "2023-03-15", "2023-03-15T14:30:00Z")',
      );
    }

    // Additional validation for date components
    final match = _iso8601Pattern.firstMatch(trimmedValue)!;
    final year = int.parse(match.group(1)!);
    final monthStr = match.group(2);
    final dayStr = match.group(3);
    final hourStr = match.group(4);
    final minuteStr = match.group(5);
    final secondStr = match.group(6);

    // Validate year range (reasonable range for audio recordings)
    if (year < 1900 || year > 2100) {
      throw ArgumentError.value(
        value,
        'value',
        'Year must be between 1900 and 2100 (inclusive)',
      );
    }

    // Validate month if present
    if (monthStr != null) {
      final month = int.parse(monthStr);
      if (month < 1 || month > 12) {
        throw ArgumentError.value(
          value,
          'value',
          'Month must be between 01 and 12',
        );
      }
    }

    // Validate day if present
    if (dayStr != null && monthStr != null) {
      final month = int.parse(monthStr);
      final day = int.parse(dayStr);

      if (day < 1 || day > _getDaysInMonth(year, month)) {
        throw ArgumentError.value(
          value,
          'value',
          'Day $day is not valid for year $year month $month',
        );
      }
    }

    // Validate time components if present
    if (hourStr != null) {
      final hour = int.parse(hourStr);
      if (hour < 0 || hour > 23) {
        throw ArgumentError.value(
          value,
          'value',
          'Hour must be between 00 and 23',
        );
      }
    }

    if (minuteStr != null) {
      final minute = int.parse(minuteStr);
      if (minute < 0 || minute > 59) {
        throw ArgumentError.value(
          value,
          'value',
          'Minute must be between 00 and 59',
        );
      }
    }

    if (secondStr != null) {
      final second = int.parse(secondStr);
      if (second < 0 || second > 59) {
        throw ArgumentError.value(
          value,
          'value',
          'Second must be between 00 and 59',
        );
      }
    }

    return trimmedValue;
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

  /// Creates a new DateRecordedTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the date recorded tag while preserving the date value. This is commonly
  /// used during tag processing operations where the same date needs to
  /// be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new DateRecordedTag instance with the same date but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = DateRecordedTag('2023-03-15');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  DateRecordedTag withProvenance(TagProvenance newProvenance) {
    return DateRecordedTag(value, provenance: newProvenance);
  }
}
