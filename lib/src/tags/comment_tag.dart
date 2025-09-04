part of '../core/metadata_tag.dart';

/// Represents a comment metadata tag for audio files.
///
/// CommentTag contains free-form comment or description text about the track.
/// Unlike other metadata fields, comments are typically longer-form text and
/// may include multiple sentences, notes, or additional information about
/// the audio content.
///
/// Format mappings:
/// - ID3v2: COMM frame (with language and description)
/// - Vorbis: COMMENT field
/// - MP4: ©cmt atom
/// - ID3v1: Comment field (30 chars, or 28 if track number present)
///
/// Example usage:
/// ```dart
/// // Create a basic comment tag
/// final commentTag = CommentTag('Recorded live at Madison Square Garden');
///
/// // Create with provenance information
/// final commentWithProvenance = CommentTag(
///   'Recorded live at Madison Square Garden',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = commentTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The comment value should be a string containing descriptive text.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations. ID3v1 has particularly strict
/// limits (30 characters, or 28 if track number is present).
final class CommentTag extends MetadataTag<String> {
  /// Creates a new CommentTag with the specified comment value.
  ///
  /// @param value The comment or description text, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = CommentTag('Live recording from 2023 tour');
  /// ```
  const CommentTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.comment,
         provenance: provenance,
       );

  /// Creates a new CommentTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the comment tag while preserving the comment value. This is commonly
  /// used during tag processing operations where the same comment needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new CommentTag instance with the same comment but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = CommentTag('Live recording');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  CommentTag withProvenance(TagProvenance newProvenance) {
    return CommentTag(value, provenance: newProvenance);
  }

  /// Converts this CommentTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a CommentTag from a JSON Map.
  static CommentTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return CommentTag(value, provenance: provenance);
  }
}
