part of '../core/metadata_tag.dart';

/// Represents a musical key metadata tag for audio files.
///
/// MusicalKeyTag contains the musical key or tonality of the track, describing
/// the key signature the track is written in. This information is valuable
/// for musicians, DJs, and music analysis applications for harmonic mixing
/// and key-based organization.
///
/// The key value typically uses standard musical notation such as:
/// - Major keys: "C major", "D major", "F# major"
/// - Minor keys: "Am", "Dm", "F#m"
/// - Alternative notations: "C", "Am", "F#"
/// - Camelot notation: "1A", "5B" (used by some DJ software)
///
/// Format mappings:
/// - ID3v2: TKEY frame
/// - Vorbis: KEY field
/// - MP4: Custom freeform atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic musical key tag
/// final keyTag = MusicalKeyTag('C major');
///
/// // Create with different notation styles
/// final minorKeyTag = MusicalKeyTag('Am');
/// final sharpKeyTag = MusicalKeyTag('F#m');
/// final camelotTag = MusicalKeyTag('5B');
///
/// // Create with provenance information
/// final keyWithProvenance = MusicalKeyTag(
///   'D minor',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = keyTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The musical key value should be a non-empty string containing the key
/// information in any recognized notation. Different container formats
/// may have length limitations that are handled automatically during
/// encoding operations.
final class MusicalKeyTag extends MetadataTag<String> {
  /// Creates a new MusicalKeyTag with the specified musical key value.
  ///
  /// @param value The musical key or tonality of the track, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = MusicalKeyTag('C major');
  /// final minorTag = MusicalKeyTag('Am');
  /// final sharpTag = MusicalKeyTag('F#');
  /// ```
  const MusicalKeyTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.musicalKey,
         provenance: provenance,
       );

  /// Creates a new MusicalKeyTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the musical key tag while preserving the key value. This is commonly
  /// used during tag processing operations where the same key needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new MusicalKeyTag instance with the same key but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = MusicalKeyTag('C major');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  MusicalKeyTag withProvenance(TagProvenance newProvenance) {
    return MusicalKeyTag(value, provenance: newProvenance);
  }

  /// Converts this MusicalKeyTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a MusicalKeyTag from a JSON Map.
  static MusicalKeyTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return MusicalKeyTag(value, provenance: provenance);
  }
}
