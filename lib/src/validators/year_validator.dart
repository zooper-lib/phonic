import 'tag_validator.dart';

/// Validator for year tag values.
///
/// This validator ensures that year values are within the valid range
/// of 1900-2100 (inclusive), representing a four-digit year that accommodates
/// historical recordings and future releases.
///
/// Error keys:
/// - `outOfRange`: Value is outside the valid range (1900-2100)
///
/// Example usage:
/// ```dart
/// const validator = YearValidator();
///
/// final error = validator.validate(2023);  // null (valid)
/// final error2 = validator.validate(1800); // {outOfRange: {...}}
/// final error3 = validator.validate(2200); // {outOfRange: {...}}
/// ```
final class YearValidator extends TagValidator<int> {
  /// The minimum valid year value (inclusive).
  static const int min = 1900;

  /// The maximum valid year value (inclusive).
  static const int max = 2100;

  /// Error key for out-of-range values.
  static const String outOfRangeError = 'outOfRange';

  /// Creates a new year validator.
  const YearValidator();

  @override
  Map<String, dynamic>? validate(int? value) {
    // Null values are allowed (optional field)
    if (value == null) return null;

    // Check range
    if (value < min || value > max) {
      return {
        outOfRangeError: {
          'min': min,
          'max': max,
          'actual': value,
        },
      };
    }

    return null;
  }

  @override
  String formatErrorMessage(Map<String, dynamic> error) {
    if (error.containsKey(outOfRangeError)) {
      return 'Year must be between $min and $max (inclusive)';
    }
    return 'Invalid year value';
  }

  /// Checks if a value is within the valid year range.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(int? value) {
    return const YearValidator().validate(value) == null;
  }
}
