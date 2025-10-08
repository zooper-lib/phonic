part of '../core/metadata_tag.dart';

/// Represents a disc number metadata tag for audio files.
///
/// DiscNumberTag contains the disc number indicating which disc or volume
/// the track belongs to in multi-disc releases. This tag provides essential
/// organizational information for music libraries and playback systems when
/// dealing with box sets, multi-disc albums, or compilation series.
///
/// The disc number value must be a positive integer (> 0) representing the
/// disc's position within the set. Disc numbers typically start from 1 and
/// increment sequentially. Some formats support "disc/total" notation
/// (e.g., "2/3"), but this tag stores only the disc number portion.
///
/// Format mappings:
/// - ID3v2: TPOS frame (may include total discs as "disc/total")
/// - Vorbis: DISCNUMBER field
/// - MP4: disk atom (includes both disc and total as binary data)
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic disc number tag
/// final discTag = DiscNumberTag(2);
///
/// // Create with provenance information
/// final discWithProvenance = DiscNumberTag(
///   1,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = discTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The disc number value must be greater than 0. Values of 0 or negative
/// numbers will cause an ArgumentError to be thrown during construction.
/// Different container formats may have different maximum values, but
/// validation is handled during encoding.
final class DiscNumberTag extends MetadataTag<int> {
  /// Validator for disc number values.
  ///
  /// This validator can be used to validate disc number values before creating
  /// a [DiscNumberTag] instance, or with form validation libraries.
  ///
  /// Example:
  /// ```dart
  /// // Pre-validate before creating tag
  /// if (DiscNumberTag.validator.validate(userInput) == null) {
  ///   final tag = DiscNumberTag(userInput);
  /// }
  /// ```
  static const validator = DiscNumberValidator();

  /// Creates a new DiscNumberTag with the specified disc number.
  ///
  /// @param value The disc number within the set, must be greater than 0
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is less than or equal to 0
  ///
  /// Example:
  /// ```dart
  /// final tag = DiscNumberTag(2);
  /// final firstDisc = DiscNumberTag(1);
  /// ```
  DiscNumberTag(
    int value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: validator.validateOrThrow(value),
         key: TagKey.discNumber,
         provenance: provenance,
       );

  /// Creates a new DiscNumberTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the disc number tag while preserving the disc number value. This is
  /// commonly used during tag processing operations where the same disc number
  /// needs to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new DiscNumberTag instance with the same disc number but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = DiscNumberTag(2);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  DiscNumberTag withProvenance(TagProvenance newProvenance) {
    return DiscNumberTag(value, provenance: newProvenance);
  }

  /// Converts this DiscNumberTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a DiscNumberTag from a JSON Map.
  static DiscNumberTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as int?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return DiscNumberTag(value, provenance: provenance);
  }
}
