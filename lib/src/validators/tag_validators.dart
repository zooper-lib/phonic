import 'rating_validator.dart';

/// Convenience class providing access to all tag validators.
///
/// This class offers static constant instances of all available validators,
/// making it easy to access validators for use in form validation, input
/// validation, or pre-validation before creating tags.
///
/// Example usage:
/// ```dart
/// // Direct validation
/// final error = TagValidators.rating.validate(userInput);
/// if (error != null) {
///   print('Invalid rating: $error');
/// }
///
/// // With reactive_forms
/// final control = FormControl<int>(
///   validators: [
///     Validators.delegate((c) => TagValidators.rating.validate(c.value)),
///   ],
/// );
///
/// // Pre-validation before creating tags
/// if (TagValidators.rating.validate(value) == null) {
///   audioFile.setTag(RatingTag(value));
/// } else {
///   // Show error to user
/// }
/// ```
class TagValidators {
  // Private constructor to prevent instantiation
  TagValidators._();

  /// Validator for rating tag values (0-100 range).
  ///
  /// Example:
  /// ```dart
  /// final error = TagValidators.rating.validate(150);
  /// if (error != null) {
  ///   // Handle validation error
  ///   final data = error['outOfRange'];
  ///   print('Rating must be ${data['min']}-${data['max']}, got ${data['actual']}');
  /// }
  /// ```
  static const rating = RatingValidator();

  // Additional validators will be added here as they are implemented
  // static const bpm = BpmValidator();
  // static const year = YearValidator();
  // static const trackNumber = TrackNumberValidator();
  // static const discNumber = DiscNumberValidator();
  // static const iso8601Date = Iso8601DateValidator();
}
