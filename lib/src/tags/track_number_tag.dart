part of '../core/metadata_tag.dart';

/// Represents a track number metadata tag for audio files.
///
/// TrackNumberTag contains the track number indicating the position of the track
/// within its containing album or collection. This tag provides essential
/// organizational information for music libraries and playback systems.
///
/// The track number value must be a positive integer (> 0) representing the
/// track's position. Track numbers typically start from 1 and increment
/// sequentially within an album. Some formats support "track/total" notation
/// (e.g., "3/12"), but this tag stores only the track number portion.
///
/// Format mappings:
/// - ID3v2: TRCK frame (may include total tracks as "track/total")
/// - Vorbis: TRACKNUMBER field
/// - MP4: trkn atom (includes both track and total as binary data)
/// - ID3v1: Track field (single byte, 1-255)
///
/// Example usage:
/// ```dart
/// // Create a basic track number tag
/// final trackTag = TrackNumberTag(3);
///
/// // Create with provenance information
/// final trackWithProvenance = TrackNumberTag(
///   7,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = trackTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The track number value must be greater than 0. Values of 0 or negative
/// numbers will cause an ArgumentError to be thrown during construction.
/// Different container formats may have different maximum values (e.g.,
/// ID3v1 supports 1-255), but validation is handled during encoding.
final class TrackNumberTag extends MetadataTag<int> {
  /// Validator for track number values.
  ///
  /// This validator can be used to validate track number values before creating
  /// a [TrackNumberTag] instance, or with form validation libraries.
  ///
  /// Example:
  /// ```dart
  /// // Pre-validate before creating tag
  /// if (TrackNumberTag.validator.validate(userInput) == null) {
  ///   final tag = TrackNumberTag(userInput);
  /// }
  /// ```
  static const validator = TrackNumberValidator();

  /// Creates a new TrackNumberTag with the specified track number.
  ///
  /// @param value The track number within the album, must be greater than 0
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is less than or equal to 0
  ///
  /// Example:
  /// ```dart
  /// final tag = TrackNumberTag(5);
  /// final firstTrack = TrackNumberTag(1);
  /// ```
  TrackNumberTag(
    int value, {
    super.provenance,
  }) : super(
         value: validator.validateOrThrow(value),
         key: TagKey.trackNumber,
       );

  /// Creates a new TrackNumberTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the track number tag while preserving the track number value. This is
  /// commonly used during tag processing operations where the same track number
  /// needs to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new TrackNumberTag instance with the same track number but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = TrackNumberTag(3);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  TrackNumberTag withProvenance(TagProvenance newProvenance) {
    return TrackNumberTag(value, provenance: newProvenance);
  }

  /// Converts this TrackNumberTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a TrackNumberTag from a JSON Map.
  static TrackNumberTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as int?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return TrackNumberTag(value, provenance: provenance);
  }
}
