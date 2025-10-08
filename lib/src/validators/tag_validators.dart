import 'album_validator.dart';
import 'artist_validator.dart';
import 'bpm_validator.dart';
import 'date_recorded_validator.dart';
import 'disc_number_validator.dart';
import 'rating_validator.dart';
import 'title_validator.dart';
import 'track_number_validator.dart';
import 'year_validator.dart';

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

  /// Validator for title tag values (non-empty).
  static const title = TitleValidator();

  /// Validator for artist tag values (non-empty).
  static const artist = ArtistValidator();

  /// Validator for album tag values (non-empty).
  static const album = AlbumValidator();

  /// Validator for rating tag values (0-100 range).
  static const rating = RatingValidator();

  /// Validator for BPM tag values (1-999 range).
  static const bpm = BpmValidator();

  /// Validator for year tag values (1900-2100 range).
  static const year = YearValidator();

  /// Validator for track number tag values (> 0).
  static const trackNumber = TrackNumberValidator();

  /// Validator for disc number tag values (> 0).
  static const discNumber = DiscNumberValidator();

  /// Validator for date recorded tag values (ISO-8601 format).
  static const dateRecorded = DateRecordedValidator();
}
