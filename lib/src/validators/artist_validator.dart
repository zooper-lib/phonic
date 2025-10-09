import 'text_validator.dart';

/// Validator for artist tag values.
///
/// This validator ensures that artist values are not empty or whitespace-only.
///
/// Error keys:
/// - `empty`: Value is empty or contains only whitespace
///
/// Example usage:
/// ```dart
/// const validator = ArtistValidator();
///
/// final error = validator.validate('The Beatles');  // null (valid)
/// final error2 = validator.validate('');            // {empty: {...}}
/// ```
final class ArtistValidator extends TextValidator {
  /// Creates a new artist validator.
  const ArtistValidator() : super(fieldName: 'Artist');

  /// Checks if a value is a valid artist.
  ///
  /// Returns `true` if the value is valid, `false` otherwise.
  static bool isValid(String? value) {
    return const ArtistValidator().validate(value) == null;
  }
}
