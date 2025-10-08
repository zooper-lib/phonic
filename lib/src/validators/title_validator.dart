import 'text_validator.dart';

/// Validator for title tag values.
///
/// This validator ensures that title values are not empty or whitespace-only.
///
/// Error keys:
/// - `empty`: Value is empty or contains only whitespace
///
/// Example usage:
/// ```dart
/// const validator = TitleValidator();
///
/// final error = validator.validate('My Song');  // null (valid)
/// final error2 = validator.validate('');        // {empty: {...}}
/// ```
final class TitleValidator extends TextValidator {
  /// Creates a new title validator.
  const TitleValidator() : super(fieldName: 'Title');

  /// Checks if a value is a valid title.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(String? value) {
    return const TitleValidator().validate(value) == null;
  }
}
