part of '../core/metadata_tag.dart';

/// Represents an ISRC (International Standard Recording Code) metadata tag for audio files.
///
/// IsrcTag contains the International Standard Recording Code, which is a unique
/// identifier for sound recordings and music videos. The ISRC is typically formatted
/// as "CC-XXX-YY-NNNNN" where CC is the country code, XXX is the registrant code,
/// YY is the year of reference, and NNNNN is the designation code.
///
/// Format mappings:
/// - ID3v2: TSRC frame
/// - Vorbis: ISRC field
/// - MP4: Custom freeform atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic ISRC tag
/// final isrcTag = IsrcTag('USRC17607839');
///
/// // Create with full formatted ISRC
/// final formattedIsrcTag = IsrcTag('US-RC1-76-07839');
///
/// // Create with provenance information
/// final isrcWithProvenance = IsrcTag(
///   'GB-UM7-15-12345',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = isrcTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The ISRC value should be a string containing the recording code. While the
/// standard format includes hyphens, many systems store ISRCs without formatting.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class IsrcTag extends MetadataTag<String> {
  /// Creates a new IsrcTag with the specified ISRC value.
  ///
  /// @param value The International Standard Recording Code, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = IsrcTag('USRC17607839');
  /// final formattedTag = IsrcTag('US-RC1-76-07839');
  /// ```
  const IsrcTag(
    String value, {
    super.provenance,
  }) : super(
         value: value,
         key: TagKey.isrc,
       );

  /// Creates a new IsrcTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the ISRC tag while preserving the ISRC value. This is commonly
  /// used during tag processing operations where the same ISRC needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new IsrcTag instance with the same ISRC but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = IsrcTag('USRC17607839');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  IsrcTag withProvenance(TagProvenance newProvenance) {
    return IsrcTag(value, provenance: newProvenance);
  }

  /// Converts this IsrcTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates an IsrcTag from a JSON Map.
  static IsrcTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return IsrcTag(value, provenance: provenance);
  }
}
