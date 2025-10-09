import 'tag_validator.dart';

/// Validator for track number tag values.
///
/// This validator ensures that track number values are positive integers
/// greater than 0, representing the track's position within an album or collection.
///
/// Error keys:
/// - `notPositive`: Value is not a positive integer (must be > 0)
///
/// Example usage:
/// ```dart
/// const validator = TrackNumberValidator();
///
/// final error = validator.validate(5);   // null (valid)
/// final error2 = validator.validate(0);  // {notPositive: {...}}
/// final error3 = validator.validate(-1); // {notPositive: {...}}
/// ```
final class TrackNumberValidator extends TagValidator<int> {
  /// The minimum valid track number value (exclusive).
  static const int min = 0;

  /// Error key for non-positive values.
  static const String notPositiveError = 'notPositive';

  /// Creates a new track number validator.
  const TrackNumberValidator();

  @override
  Map<String, dynamic>? validate(int? value) {
    // Null values are allowed (optional field)
    if (value == null) return null;

    // Check if positive
    if (value <= min) {
      return {
        notPositiveError: {
          'actual': value,
        },
      };
    }

    return null;
  }

  @override
  String formatErrorMessage(Map<String, dynamic> error) {
    if (error.containsKey(notPositiveError)) {
      return 'Track number must be greater than 0';
    }
    return 'Invalid track number';
  }

  /// Checks if a value is a valid track number.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(int? value) {
    return const TrackNumberValidator().validate(value) == null;
  }
}
