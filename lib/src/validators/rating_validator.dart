import 'package:phonic/src/core/metadata_tag.dart';

import 'tag_validator.dart';

/// Validator for rating tag values.
///
/// This validator ensures that rating values are within the valid range
/// of 0-100 (inclusive), representing a percentage-based rating scale.
///
/// The validator can be used in multiple contexts:
/// 1. Internally by [RatingTag] constructor for validation
/// 2. Externally by users for pre-validation before creating tags
/// 3. With form validation libraries like reactive_forms
///
/// Error keys:
/// - `outOfRange`: Value is outside the valid range (0-100)
///
/// Example usage:
/// ```dart
/// // Direct validation
/// const validator = RatingValidator();
/// final error = validator.validate(150);
/// if (error != null) {
///   print('Invalid: ${error}'); // {outOfRange: {min: 0, max: 100, actual: 150}}
/// }
///
/// // With reactive_forms
/// final control = FormControl<int>(
///   validators: [
///     Validators.delegate((c) => validator.validate(c.value)),
///   ],
/// );
///
/// // In a TextField with precise error handling
/// ReactiveTextField<int>(
///   formControlName: 'rating',
///   validationMessages: {
///     'outOfRange': (error) {
///       final e = error as Map;
///       return 'Rating must be between ${e['min']} and ${e['max']}, you entered ${e['actual']}';
///     },
///   },
/// );
/// ```
class RatingValidator extends TagValidator<int> {
  /// The minimum valid rating value (inclusive).
  static const int min = 0;

  /// The maximum valid rating value (inclusive).
  static const int max = 100;

  /// Error key for out-of-range values.
  static const String outOfRangeError = 'outOfRange';

  /// Creates a new rating validator.
  const RatingValidator();

  @override
  Map<String, dynamic>? validate(int? value) {
    // Null values are considered valid (use with required validator if needed)
    if (value == null) {
      return null;
    }

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
    final data = error[outOfRangeError] as Map<String, dynamic>;
    return 'Rating must be between ${data['min']} and ${data['max']} (inclusive)';
  }

  /// Checks if a value is within the valid rating range.
  ///
  /// This is a convenience method for quick boolean checks.
  ///
  /// Parameters:
  /// - [value]: The value to check
  ///
  /// Returns:
  /// - `true` if the value is valid, `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// if (RatingValidator.isValid(85)) {
  ///   print('Valid rating');
  /// }
  /// ```
  static bool isValid(int? value) {
    return const RatingValidator().validate(value) == null;
  }
}
