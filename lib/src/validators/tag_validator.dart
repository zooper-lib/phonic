/// Base class for all tag validators.
///
/// This abstract class provides a foundation for implementing validators
/// that can be used both internally by tag constructors and externally
/// by users for input validation (e.g., with reactive_forms).
///
/// Validators return `null` for valid values and a `Map<String, dynamic>`
/// containing error information for invalid values.
///
/// Example usage:
/// ```dart
/// final validator = RatingValidator();
///
/// // Check if a value is valid
/// final error = validator.validate(150);
/// if (error != null) {
///   print('Validation failed: ${error}');
/// }
///
/// // Validate and throw on error (used internally by tags)
/// try {
///   final value = validator.validateOrThrow(150);
/// } on ArgumentError catch (e) {
///   print('Invalid rating: ${e.message}');
/// }
///
/// // Use with reactive_forms
/// final control = FormControl<int>(
///   validators: [
///     Validators.delegate((c) => validator.validate(c.value)),
///   ],
/// );
/// ```
abstract class TagValidator<T> {
  /// Creates a new tag validator.
  const TagValidator();

  /// Validates the given value.
  ///
  /// Returns `null` if the value is valid, or a `Map<String, dynamic>`
  /// containing error information if the value is invalid.
  ///
  /// The error map typically has a single key identifying the validation
  /// error type, with a value containing detailed error information such
  /// as constraints and the actual value.
  ///
  /// Example error format:
  /// ```dart
  /// {
  ///   'outOfRange': {
  ///     'min': 0,
  ///     'max': 100,
  ///     'actual': 150,
  ///   }
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [value]: The value to validate. Can be `null`.
  ///
  /// Returns:
  /// - `null` if validation passes
  /// - `Map<String, dynamic>` with error details if validation fails
  Map<String, dynamic>? validate(T? value);

  /// Validates the value and throws an [ArgumentError] if invalid.
  ///
  /// This method is used internally by tag constructors to ensure
  /// validation while throwing exceptions for invalid values.
  ///
  /// Parameters:
  /// - [value]: The value to validate. Must not be `null`.
  ///
  /// Returns:
  /// - The validated value if validation passes
  ///
  /// Throws:
  /// - [ArgumentError] if validation fails
  ///
  /// Example:
  /// ```dart
  /// final validator = RatingValidator();
  /// final validatedRating = validator.validateOrThrow(85);
  /// ```
  T validateOrThrow(T value) {
    final error = validate(value);
    if (error != null) {
      throw ArgumentError(formatErrorMessage(error));
    }
    return value;
  }

  /// Formats the error map into a human-readable error message.
  ///
  /// This method is called by [validateOrThrow] to create the error
  /// message for the [ArgumentError].
  ///
  /// Subclasses should override this method to provide custom error
  /// messages that are appropriate for their validation rules.
  ///
  /// Parameters:
  /// - [error]: The error map returned by [validate]
  ///
  /// Returns:
  /// - A human-readable error message string
  String formatErrorMessage(Map<String, dynamic> error);
}
