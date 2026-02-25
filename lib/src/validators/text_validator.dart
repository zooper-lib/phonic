import 'tag_validator.dart';

/// Validator for text tag values that require non-empty content.
///
/// This validator ensures that text values are not empty or whitespace-only,
/// making it useful for required metadata fields like title, artist, and album.
///
/// Error keys:
/// - `empty`: Value is null, empty, or contains only whitespace
///
/// Example usage:
/// ```dart
/// const validator = TextValidator();
///
/// final error = validator.validate('My Song');  // null (valid)
/// final error2 = validator.validate('');        // {empty: {...}}
/// final error3 = validator.validate('   ');     // {empty: {...}}
/// ```
class TextValidator extends TagValidator<String> {
  /// Error key for empty values.
  static const String emptyError = 'empty';

  /// The field name for error messages.
  final String fieldName;

  /// Creates a new text validator.
  ///
  /// The [fieldName] is used in error messages to provide context-specific
  /// feedback (e.g., "Title cannot be empty" vs "Artist cannot be empty").
  const TextValidator({required this.fieldName});

  @override
  Map<String, dynamic>? validate(String? value) {
    // Null values are allowed (optional field)
    if (value == null) return null;

    // Check for empty or whitespace-only string
    if (value.trim().isEmpty) {
      return {
        emptyError: {
          'fieldName': fieldName,
          'actual': value,
        },
      };
    }

    return null;
  }

  @override
  String validateOrThrow(String value) {
    final error = validate(value);
    if (error != null) {
      throw ArgumentError(formatErrorMessage(error));
    }
    // Return trimmed value (normalized)
    return value.trim();
  }

  @override
  String formatErrorMessage(Map<String, dynamic> error) {
    if (error.containsKey(emptyError)) {
      final details = error[emptyError] as Map<String, dynamic>;
      final actual = details['actual'] as String;
      return '$fieldName cannot be empty. Actual: "$actual"';
    }
    return 'Invalid $fieldName value';
  }
}
