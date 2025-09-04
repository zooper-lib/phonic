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
final class TitleTag extends MetadataTag<String> {
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
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.title,
         provenance: provenance,
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
}
