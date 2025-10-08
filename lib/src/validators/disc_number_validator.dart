import 'tag_validator.dart';

/// Validator for disc number tag values.
///
/// This validator ensures that disc number values are positive integers
/// greater than 0, representing the disc's position within a multi-disc set.
///
/// Error keys:
/// - `notPositive`: Value is not a positive integer (must be > 0)
///
/// Example usage:
/// ```dart
/// const validator = DiscNumberValidator();
///
/// final error = validator.validate(2);   // null (valid)
/// final error2 = validator.validate(0);  // {notPositive: {...}}
/// final error3 = validator.validate(-1); // {notPositive: {...}}
/// ```
final class DiscNumberValidator extends TagValidator<int> {
  /// The minimum valid disc number value (exclusive).
  static const int min = 0;

  /// Error key for non-positive values.
  static const String notPositiveError = 'notPositive';

  /// Creates a new disc number validator.
  const DiscNumberValidator();

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
      return 'Disc number must be greater than 0';
    }
    return 'Invalid disc number';
  }

  /// Checks if a value is a valid disc number.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(int? value) {
    return const DiscNumberValidator().validate(value) == null;
  }
}
