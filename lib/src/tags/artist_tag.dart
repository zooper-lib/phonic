part of '../metadata_tag.dart';

/// Represents an artist metadata tag for audio files.
///
/// ArtistTag contains the primary artist or performer of the track, which
/// identifies the main artist, band, or performer responsible for the audio
/// content. For tracks with multiple artists, this typically contains the
/// primary or lead artist.
///
/// Format mappings:
/// - ID3v2: TPE1 frame
/// - Vorbis: ARTIST field
/// - MP4: ©ART atom
/// - ID3v1: Artist field (30 character limit)
///
/// Example usage:
/// ```dart
/// // Create a basic artist tag
/// final artistTag = ArtistTag('The Beatles');
///
/// // Create with provenance information
/// final artistWithProvenance = ArtistTag(
///   'The Beatles',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = artistTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The artist value should be a non-empty string containing the artist name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class ArtistTag extends MetadataTag<String> {
  /// Creates a new ArtistTag with the specified artist value.
  ///
  /// @param value The name of the artist or performer, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = ArtistTag('Artist Name');
  /// ```
  const ArtistTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.artist,
         provenance: provenance,
       );

  /// Creates a new ArtistTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the artist tag while preserving the artist value. This is commonly
  /// used during tag processing operations where the same artist needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new ArtistTag instance with the same artist but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = ArtistTag('Artist Name');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  ArtistTag withProvenance(TagProvenance newProvenance) {
    return ArtistTag(value, provenance: newProvenance);
  }
}
