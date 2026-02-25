part of '../core/metadata_tag.dart';

/// Represents a BPM (beats per minute) metadata tag for audio files.
///
/// BpmTag contains the tempo of the track measured in beats per minute,
/// providing essential rhythmic information for music libraries, DJ software,
/// and tempo-based organization systems. This tag helps users sort, filter,
/// and organize their music collections by tempo and discover music with
/// similar rhythmic characteristics.
///
/// The BPM value must be within a reasonable range (1-999) representing
/// a realistic musical tempo. This validation ensures data integrity while
/// accommodating the full spectrum of musical tempos from very slow ballads
/// to extremely fast electronic music. Values outside this range are
/// considered invalid and will cause an ArgumentError during construction.
///
/// Format mappings:
/// - ID3v2: TBPM frame
/// - Vorbis: BPM field
/// - MP4: tmpo atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic BPM tag
/// final bpmTag = BpmTag(120);
///
/// // Create with provenance information
/// final bpmWithProvenance = BpmTag(
///   140,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = bpmTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The BPM value must be between 1 and 999 (inclusive). Values outside
/// this range will cause an ArgumentError to be thrown during construction.
/// This range accommodates extremely slow ambient music through the fastest
/// electronic genres while preventing obviously invalid tempo values.
final class BpmTag extends MetadataTag<int> {
  /// Validator for BPM values.
  ///
  /// This validator can be used to validate BPM values before creating
  /// a [BpmTag] instance, or with form validation libraries.
  ///
  /// Example:
  /// ```dart
  /// // Pre-validate before creating tag
  /// if (BpmTag.validator.validate(userInput) == null) {
  ///   final tag = BpmTag(userInput);
  /// }
  /// ```
  static const validator = BpmValidator();

  /// The minimum valid BPM value (inclusive).
  static const int minBpm = BpmValidator.min;

  /// The maximum valid BPM value (inclusive).
  static const int maxBpm = BpmValidator.max;

  /// Creates a new BpmTag with the specified BPM value.
  ///
  /// @param value The tempo in beats per minute, must be between 1 and 999 (inclusive)
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is not within the valid BPM range
  ///
  /// Example:
  /// ```dart
  /// final tag = BpmTag(120);
  /// final fastTag = BpmTag(180);
  /// final slowTag = BpmTag(60);
  /// ```
  BpmTag(
    int value, {
    super.provenance,
  }) : super(
         value: validator.validateOrThrow(value),
         key: TagKey.bpm,
       );

  /// Creates a new BpmTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the BPM tag while preserving the BPM value. This is commonly
  /// used during tag processing operations where the same BPM needs to
  /// be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new BpmTag instance with the same BPM but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = BpmTag(128);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  BpmTag withProvenance(TagProvenance newProvenance) {
    return BpmTag(value, provenance: newProvenance);
  }

  /// Converts this BpmTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a BpmTag from a JSON Map.
  static BpmTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as int?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return BpmTag(value, provenance: provenance);
  }
}
