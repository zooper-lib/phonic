part of '../core/metadata_tag.dart';

/// Represents an artwork metadata tag for audio files.
///
/// ArtworkTag contains embedded artwork images associated with the track
/// or album, using lazy loading to optimize memory usage. This tag maps
/// to format-specific implementations across different container types:
///
/// Format mappings:
/// - ID3v2: APIC frame (with picture type and description)
/// - Vorbis: METADATA_BLOCK_PICTURE (FLAC) or base64 encoded (OGG)
/// - MP4: covr atom
/// - ID3v1: Not supported (will be omitted)
///
/// The artwork data is loaded lazily through the [ArtworkData] class,
/// which means the image bytes are only loaded when actually needed.
/// This provides significant memory efficiency when working with large
/// audio collections.
///
/// Example usage:
/// ```dart
/// // Create artwork with lazy loading
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'Album front cover',
///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
/// );
/// final artworkTag = ArtworkTag(artworkData);
///
/// // Create with provenance information
/// final artworkWithProvenance = ArtworkTag(
///   artworkData,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Access artwork metadata without loading image data
/// print('MIME Type: ${artworkTag.value.mimeType}');
/// print('Type: ${artworkTag.value.type}');
/// print('Description: ${artworkTag.value.description}');
///
/// // Load the actual image data when needed
/// final imageBytes = await artworkTag.value.data;
/// print('Image size: ${imageBytes.length} bytes');
///
/// // Update provenance immutably
/// final updatedTag = artworkTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// Multiple artwork images of different types (front cover, back cover,
/// artist photos, etc.) can be present in a single audio file. Each
/// artwork tag represents one image with its associated metadata.
///
/// The lazy loading mechanism ensures that:
/// - Metadata can be examined without loading image data
/// - Memory usage remains low when scanning large collections
/// - Image data is only loaded when actually needed for display or processing
/// - Multiple references to the same artwork share the same loader
final class ArtworkTag extends MetadataTag<ArtworkData> {
  /// Creates a new ArtworkTag with the specified artwork data.
  ///
  /// @param value The artwork data containing image metadata and lazy loader
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final artworkData = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   dataLoader: () async => loadImageBytes(),
  /// );
  /// final tag = ArtworkTag(artworkData);
  /// ```
  const ArtworkTag(
    ArtworkData value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.artwork,
         provenance: provenance,
       );

  /// Creates a new ArtworkTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the artwork tag while preserving the artwork data. This is commonly
  /// used during tag processing operations where the same artwork needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new ArtworkTag instance with the same artwork data but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = ArtworkTag(artworkData);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  ArtworkTag withProvenance(TagProvenance newProvenance) {
    return ArtworkTag(value, provenance: newProvenance);
  }
}
