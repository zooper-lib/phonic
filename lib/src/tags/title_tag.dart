part of '../core/metadata_tag.dart';

/// Represents a title metadata tag for audio files.
///
/// TitleTag contains the title or name of the track, which is typically
/// the most prominent metadata field displayed to users. This tag maps
/// to format-specific implementations across different container types:
///
/// Format mappings:
/// - ID3v2: TIT2 frame
/// - Vorbis: TITLE field
/// - MP4: ©nam atom
/// - ID3v1: Title field (30 character limit)
///
/// Example usage:
/// ```dart
/// // Create a basic title tag
/// final titleTag = TitleTag('My Song Title');
///
/// // Create with provenance information
/// final titleWithProvenance = TitleTag(
///   'My Song Title',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = titleTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The title value should be a non-empty string containing the track name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
///
/// For validation and form integration, use [TitleTag.validator]:
/// ```dart
/// // Pre-validate before creating tag
/// if (TitleTag.validator.validate(userInput) == null) {
///   final tag = TitleTag(userInput);
/// }
/// ```
final class TitleTag extends MetadataTag<String> {
  /// Public validator for title tag values.
  ///
  /// This validator ensures that title values are not empty or whitespace-only,
  /// making it useful for form validation where title is a required field.
  ///
  /// Example usage:
  /// ```dart
  /// // Pre-validate before creating tag
  /// if (TitleTag.validator.validate(userInput) == null) {
  ///   final tag = TitleTag(userInput);
  /// }
  /// ```
  static const validator = TitleValidator();

  /// Creates a new TitleTag with the specified title value.
  ///
  /// @param value The title or name of the track, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = TitleTag('Song Title');
  /// ```
  const TitleTag(
    String value, {
    super.provenance,
  }) : super(
         value: value,
         key: TagKey.title,
       );

  /// Creates a new TitleTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the title tag while preserving the title value. This is commonly
  /// used during tag processing operations where the same title needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new TitleTag instance with the same title but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = TitleTag('Song Title');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  TitleTag withProvenance(TagProvenance newProvenance) {
    return TitleTag(value, provenance: newProvenance);
  }

  /// Converts this TitleTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a TitleTag from a JSON Map.
  static TitleTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return TitleTag(value, provenance: provenance);
  }
}
