import '../tag_key.dart';
import 'phonic_exception.dart';

/// Exception thrown when tag validation fails due to constraint violations.
///
/// This exception is raised when the Phonic library detects that a tag value
/// violates the constraints or capabilities of a target container format.
/// This can occur when:
///
/// - Text fields exceed maximum length limits (e.g., ID3v1's 30-character limit)
/// - Numeric values fall outside allowed ranges (e.g., rating not in 0-100 range)
/// - Required fields are missing or empty when they shouldn't be
/// - Field formats don't match expected patterns (e.g., invalid ISO-8601 dates)
/// - Container format doesn't support the specified tag type
/// - Multi-valued tags are used with single-value-only containers
///
/// The exception includes the specific [tagKey] that failed validation and
/// a [reason] describing why the validation failed, making it easy to
/// identify and correct the problematic data.
///
/// ## Usage Examples
///
/// ### Basic Exception Creation
/// ```dart
/// throw TagValidationException(
///   TagKey.title,
///   'Title exceeds maximum length of 30 characters for ID3v1',
///   context: 'value: "This is a very long title that exceeds the limit"'
/// );
/// ```
///
/// ### Exception Handling by Tag Type
/// ```dart
/// try {
///   audioFile.setTag(RatingTag(150)); // Invalid rating > 100
/// } on TagValidationException catch (e) {
///   if (e.tagKey == TagKey.rating) {
///     print('Rating validation failed: ${e.reason}');
///     // Provide corrected value
///     audioFile.setTag(RatingTag(100));
///   }
/// } on PhonicException catch (e) {
///   // Handle other Phonic exceptions
///   print('Other error: ${e.message}');
/// }
/// ```
///
/// ### Validation Error Logging
/// ```dart
/// void logValidationError(TagValidationException e) {
///   logger.warning('Tag validation failed for ${e.tagKey}: ${e.reason}');
///   if (e.context != null) {
///     logger.debug('Validation context: ${e.context}');
///   }
/// }
/// ```
///
/// ### Batch Validation with Error Collection
/// ```dart
/// List<TagValidationException> validateTags(List<MetadataTag> tags) {
///   final errors = <TagValidationException>[];
///
///   for (final tag in tags) {
///     try {
///       validateTag(tag);
///     } on TagValidationException catch (e) {
///       errors.add(e);
///     }
///   }
///
///   return errors;
/// }
/// ```
///
/// ### Container-Specific Validation
/// ```dart
/// void validateForId3v1(MetadataTag tag) {
///   if (tag is TitleTag && tag.value.length > 30) {
///     throw TagValidationException(
///       TagKey.title,
///       'Title length ${tag.value.length} exceeds ID3v1 limit of 30 characters',
///       context: 'container: ID3v1, value: "${tag.value}"'
///     );
///   }
/// }
/// ```
///
/// ## Error Recovery
///
/// When catching [TagValidationException], applications should:
/// 1. Log the validation error with tag key and reason for debugging
/// 2. Determine if the value can be automatically corrected (truncation, clamping)
/// 3. Provide user feedback about which fields need correction
/// 4. Offer suggestions for valid values or formats
/// 5. Consider skipping problematic tags while preserving others
///
/// ## Common Validation Scenarios
///
/// ### Length Constraints
/// - **ID3v1**: 30 characters for most text fields, 28 for comment with track
/// - **ID3v2**: Generally unlimited, but some implementations have practical limits
/// - **Vorbis**: No strict limits, but very large values may cause issues
/// - **MP4**: Varies by atom type, generally generous limits
///
/// ### Value Range Constraints
/// - **Rating**: Must be 0-100 (normalized from format-specific ranges)
/// - **Track/Disc Numbers**: Must be positive integers
/// - **BPM**: Must be positive, typically 1-999
/// - **Year**: Should be reasonable 4-digit year (e.g., 1900-2100)
///
/// ### Format Constraints
/// - **Date Fields**: Must be valid ISO-8601 format for dateRecorded
/// - **ISRC**: Must match ISRC format pattern (CC-XXX-YY-NNNNN)
/// - **Genre**: Some formats have predefined genre lists
///
/// ### Container Support Constraints
/// - **ID3v1**: Limited field support (no BPM, lyrics, artwork, etc.)
/// - **Multi-valued**: Some containers don't support multiple values for certain fields
/// - **Custom Fields**: Not all containers support custom/freeform fields
///
/// ## Thread Safety
///
/// [TagValidationException] instances are immutable and thread-safe.
final class TagValidationException extends PhonicException {
  /// The tag key that failed validation.
  ///
  /// This field identifies which specific tag field caused the validation
  /// failure, allowing applications to provide targeted error handling
  /// and user feedback. The tag key corresponds to the unified tag model
  /// field that was being validated.
  ///
  /// Examples:
  /// - [TagKey.title] for title length violations
  /// - [TagKey.rating] for rating range violations
  /// - [TagKey.dateRecorded] for invalid date format
  /// - [TagKey.trackNumber] for non-positive track numbers
  final TagKey tagKey;

  /// The specific reason why validation failed.
  ///
  /// This field provides a detailed explanation of what constraint was
  /// violated or what validation rule failed. The reason should be specific
  /// enough to help developers understand how to correct the issue.
  ///
  /// Examples:
  /// - "Title length 45 exceeds ID3v1 limit of 30 characters"
  /// - "Rating value 150 is outside allowed range of 0-100"
  /// - "Date format 'March 15, 2023' is not valid ISO-8601"
  /// - "Track number must be a positive integer, got -1"
  final String reason;

  /// Creates a new [TagValidationException] for the specified [tagKey] with
  /// the given [reason] and optional [context].
  ///
  /// The [tagKey] identifies which tag field failed validation. The [reason]
  /// should provide a clear explanation of what validation rule was violated.
  /// The [context] can provide additional information such as the actual
  /// value that failed, container format constraints, or operation details.
  ///
  /// Example:
  /// ```dart
  /// const TagValidationException(
  ///   TagKey.bpm,
  ///   'BPM value must be positive, got 0',
  ///   context: 'container: ID3v2.4, operation: setTag'
  /// );
  /// ```
  TagValidationException(this.tagKey, this.reason, {String? context}) : super('Tag validation failed for $tagKey: $reason', context: context);

  /// Returns a string representation of this exception.
  ///
  /// The format includes the specific exception type name, tag key, and reason:
  /// - With context: `"TagValidationException: Tag validation failed for tagKey: reason (Context: context)"`
  /// - Without context: `"TagValidationException: Tag validation failed for tagKey: reason"`
  ///
  /// Example output:
  /// ```
  /// TagValidationException: Tag validation failed for title: Title length 45 exceeds ID3v1 limit of 30 characters (Context: value: "This is a very long title that exceeds...")
  /// ```
  @override
  String toString() {
    final contextInfo = context != null ? ' (Context: $context)' : '';
    return 'TagValidationException: Tag validation failed for $tagKey: $reason$contextInfo';
  }
}
