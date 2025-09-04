part of '../core/metadata_tag.dart';

/// Represents a rating metadata tag for audio files.
///
/// RatingTag contains a user-assigned rating or score for the track,
/// providing a way to organize and filter music collections by quality
/// or preference. This tag helps users sort, filter, and organize their
/// music libraries based on personal ratings and discover highly-rated
/// content within their collections.
///
/// The rating value must be within the range 0-100 (inclusive), representing
/// a percentage-based rating scale. This validation ensures data integrity
/// while providing a standardized scale across different container formats.
/// Values outside this range are considered invalid and will cause an
/// ArgumentError during construction.
///
/// Format mappings:
/// - ID3v2: POPM frame (0-255 scale, automatically converted to/from 0-100)
/// - Vorbis: RATING field
/// - MP4: Custom freeform atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic rating tag
/// final ratingTag = RatingTag(85);
///
/// // Create with provenance information
/// final ratingWithProvenance = RatingTag(
///   92,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = ratingTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The rating value must be between 0 and 100 (inclusive). Values outside
/// this range will cause an ArgumentError to be thrown during construction.
/// This range provides a standardized percentage-based rating system that
/// can be easily converted to format-specific scales as needed.
final class RatingTag extends MetadataTag<int> {
  /// The minimum valid rating value (inclusive).
  static const int minRating = 0;

  /// The maximum valid rating value (inclusive).
  static const int maxRating = 100;

  /// Creates a new RatingTag with the specified rating value.
  ///
  /// @param value The rating score, must be between 0 and 100 (inclusive)
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is not within the valid rating range
  ///
  /// Example:
  /// ```dart
  /// final tag = RatingTag(75);
  /// final highRating = RatingTag(95);
  /// final lowRating = RatingTag(25);
  /// final unrated = RatingTag(0);
  /// final perfect = RatingTag(100);
  /// ```
  RatingTag(
    int value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: _validateRating(value),
         key: TagKey.rating,
         provenance: provenance,
       );

  /// Validates that the rating is within the acceptable range.
  ///
  /// @param value The rating to validate
  /// @returns The validated rating
  /// @throws ArgumentError if the rating is not between 0 and 100 (inclusive)
  static int _validateRating(int value) {
    if (value < minRating || value > maxRating) {
      throw ArgumentError.value(
        value,
        'value',
        'Rating must be between $minRating and $maxRating (inclusive)',
      );
    }
    return value;
  }

  /// Creates a new RatingTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the rating tag while preserving the rating value. This is commonly
  /// used during tag processing operations where the same rating needs to
  /// be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new RatingTag instance with the same rating but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = RatingTag(88);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  RatingTag withProvenance(TagProvenance newProvenance) {
    return RatingTag(value, provenance: newProvenance);
  }
}
