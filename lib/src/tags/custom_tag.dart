part of '../core/metadata_tag.dart';

/// Represents a custom metadata tag for audio files.
///
/// CustomTag contains custom, proprietary, or non-standard metadata that
/// doesn't fit into the other predefined categories. The actual field name
/// and meaning depend on the specific implementation and container format
/// capabilities. This tag type provides flexibility for handling specialized
/// or vendor-specific metadata fields.
///
/// Format mappings:
/// - ID3v2: TXXX frames (user-defined text)
/// - Vorbis: Any non-standard field name
/// - MP4: Freeform atoms (----:domain:name format)
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic custom tag
/// final customTag = CustomTag('Custom metadata value');
///
/// // Create with provenance information
/// final customWithProvenance = CustomTag(
///   'Vendor-specific data',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = customTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The custom value should be a string containing the custom metadata content.
/// Different container formats have varying support for custom fields:
/// - ID3v2 supports user-defined text frames (TXXX) with description fields
/// - Vorbis Comments allow arbitrary field names beyond the standard set
/// - MP4 supports freeform atoms with domain and name identifiers
/// - ID3v1 has no support for custom fields and will omit them
///
/// When working with custom tags, consider that:
/// - Field names and meanings are not standardized across formats
/// - Some players may not display or preserve custom metadata
/// - Cross-format compatibility may be limited
/// - Custom fields should be used sparingly for specialized use cases
final class CustomTag extends MetadataTag<String> {
  /// Creates a new CustomTag with the specified custom value.
  ///
  /// @param value The custom metadata content, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = CustomTag('Application-specific metadata');
  /// ```
  const CustomTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.custom,
         provenance: provenance,
       );

  /// Creates a new CustomTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the custom tag while preserving the custom value. This is commonly
  /// used during tag processing operations where the same custom data needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new CustomTag instance with the same custom value but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = CustomTag('Custom data');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  CustomTag withProvenance(TagProvenance newProvenance) {
    return CustomTag(value, provenance: newProvenance);
  }
}
