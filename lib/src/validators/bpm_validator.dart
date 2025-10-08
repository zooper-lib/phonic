import 'tag_validator.dart';

/// Validator for BPM (beats per minute) tag values.
///
/// This validator ensures that BPM values are within the valid range
/// of 1-999 (inclusive), representing realistic musical tempos from
/// very slow ballads to extremely fast electronic music.
///
/// Error keys:
/// - `outOfRange`: Value is outside the valid range (1-999)
///
/// Example usage:
/// ```dart
/// const validator = BpmValidator();
///
/// final error = validator.validate(120);  // null (valid)
/// final error2 = validator.validate(0);   // {outOfRange: {...}}
/// final error3 = validator.validate(1000); // {outOfRange: {...}}
/// ```
final class BpmValidator extends TagValidator<int> {
  /// The minimum valid BPM value (inclusive).
  static const int min = 1;

  /// The maximum valid BPM value (inclusive).
  static const int max = 999;

  /// Error key for out-of-range values.
  static const String outOfRangeError = 'outOfRange';

  /// Creates a new BPM validator.
  const BpmValidator();

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
      return 'BPM must be between $min and $max (inclusive)';
    }
    return 'Invalid BPM value';
  }

  /// Checks if a value is within the valid BPM range.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(int? value) {
    return const BpmValidator().validate(value) == null;
  }
}
