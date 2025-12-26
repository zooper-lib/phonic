part of '../core/metadata_tag.dart';

/// Represents a composer metadata tag for audio files.
///
/// ComposerTag contains the name of the composer or songwriter of the track,
/// identifying the person or persons who composed the music, as distinct
/// from the performer (artist). This is particularly important for classical
/// music, covers, and tracks where the composer differs from the performer.
///
/// Format mappings:
/// - ID3v2: TCOM frame
/// - Vorbis: COMPOSER field
/// - MP4: ©wrt atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic composer tag
/// final composerTag = ComposerTag('Ludwig van Beethoven');
///
/// // Create with provenance information
/// final composerWithProvenance = ComposerTag(
///   'Johann Sebastian Bach',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = composerTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The composer value should be a non-empty string containing the composer name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class ComposerTag extends MetadataTag<String> {
  /// Creates a new ComposerTag with the specified composer value.
  ///
  /// @param value The name of the composer or songwriter, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = ComposerTag('Wolfgang Amadeus Mozart');
  /// ```
  const ComposerTag(
    String value, {
    super.provenance,
  }) : super(
         value: value,
         key: TagKey.composer,
       );

  /// Creates a new ComposerTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the composer tag while preserving the composer value. This is commonly
  /// used during tag processing operations where the same composer needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new ComposerTag instance with the same composer but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = ComposerTag('Franz Schubert');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  ComposerTag withProvenance(TagProvenance newProvenance) {
    return ComposerTag(value, provenance: newProvenance);
  }

  /// Converts this ComposerTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a ComposerTag from a JSON Map.
  static ComposerTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return ComposerTag(value, provenance: provenance);
  }
}
