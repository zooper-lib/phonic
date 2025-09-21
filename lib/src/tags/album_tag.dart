part of '../core/metadata_tag.dart';

/// Represents an album metadata tag for audio files.
///
/// AlbumTag contains the album or collection name that the track belongs to,
/// which identifies the album, EP, compilation, or other collection containing
/// the audio content. For standalone singles, this may be empty or contain
/// the single title.
///
/// Format mappings:
/// - ID3v2: TALB frame
/// - Vorbis: ALBUM field
/// - MP4: ©alb atom
/// - ID3v1: Album field (30 character limit)
///
/// Example usage:
/// ```dart
/// // Create a basic album tag
/// final albumTag = AlbumTag('Abbey Road');
///
/// // Create with provenance information
/// final albumWithProvenance = AlbumTag(
///   'Abbey Road',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = albumTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The album value should be a non-empty string containing the album name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class AlbumTag extends MetadataTag<String> {
  /// Creates a new AlbumTag with the specified album value.
  ///
  /// @param value The name of the album or collection, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = AlbumTag('Album Name');
  /// ```
  const AlbumTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.album,
         provenance: provenance,
       );

  /// Creates a new AlbumTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the album tag while preserving the album value. This is commonly
  /// used during tag processing operations where the same album needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new AlbumTag instance with the same album but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = AlbumTag('Album Name');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  AlbumTag withProvenance(TagProvenance newProvenance) {
    return AlbumTag(value, provenance: newProvenance);
  }

  /// Converts this AlbumTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates an AlbumTag from a JSON Map.
  static AlbumTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return AlbumTag(value, provenance: provenance);
  }
}
