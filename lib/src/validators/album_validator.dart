import 'text_validator.dart';

/// Validator for album tag values.
///
/// This validator ensures that album values are not empty or whitespace-only.
///
/// Error keys:
/// - `empty`: Value is empty or contains only whitespace
///
/// Example usage:
/// ```dart
/// const validator = AlbumValidator();
///
/// final error = validator.validate('Abbey Road');  // null (valid)
/// final error2 = validator.validate('');           // {empty: {...}}
/// ```
final class AlbumValidator extends TextValidator {
  /// Creates a new album validator.
  const AlbumValidator() : super(fieldName: 'Album');

  /// Checks if a value is a valid album.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(String? value) {
    return const AlbumValidator().validate(value) == null;
  }
}
