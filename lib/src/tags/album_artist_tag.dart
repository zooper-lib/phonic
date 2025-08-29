part of '../metadata_tag.dart';

/// Represents an album artist metadata tag for audio files.
///
/// AlbumArtistTag contains the primary artist of the album, which may differ
/// from the track artist. This field is commonly used in compilation albums,
/// soundtracks, or albums featuring guest artists where the album artist
/// differs from individual track artists. If not explicitly set, it often
/// defaults to the track artist.
///
/// Format mappings:
/// - ID3v2: TPE2 frame
/// - Vorbis: ALBUMARTIST field
/// - MP4: aART atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic album artist tag
/// final albumArtistTag = AlbumArtistTag('Various Artists');
///
/// // Create with provenance information
/// final albumArtistWithProvenance = AlbumArtistTag(
///   'Various Artists',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = albumArtistTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The album artist value should be a non-empty string containing the artist name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class AlbumArtistTag extends MetadataTag<String> {
  /// Creates a new AlbumArtistTag with the specified album artist value.
  ///
  /// @param value The name of the album artist, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = AlbumArtistTag('Album Artist Name');
  /// ```
  const AlbumArtistTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.albumArtist,
         provenance: provenance,
       );

  /// Creates a new AlbumArtistTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the album artist tag while preserving the album artist value. This is commonly
  /// used during tag processing operations where the same album artist needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new AlbumArtistTag instance with the same album artist but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = AlbumArtistTag('Album Artist Name');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  AlbumArtistTag withProvenance(TagProvenance newProvenance) {
    return AlbumArtistTag(value, provenance: newProvenance);
  }
}
