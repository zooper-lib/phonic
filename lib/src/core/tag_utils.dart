import 'tag_capability.dart';
import 'tag_key.dart';

/// Determines whether a given [TagKey] represents a field that supports multiple values.
///
/// This utility function analyzes tag fields to determine their multi-valued nature,
/// which is important for proper tag handling, UI design, and data processing.
/// The function considers both the inherent nature of the tag type and how it's
/// typically handled across different container formats.
///
/// ## Multi-Valued Tag Categories
///
/// ### Inherently Multi-Valued Tags
/// These tags are designed to hold multiple distinct values:
/// - **Genre**: Multiple musical genres (Rock, Alternative, Indie)
/// - **Artwork**: Multiple images (front cover, back cover, artist photo, etc.)
/// - **Custom**: Application-specific fields that may contain multiple values
///
/// ### Container-Dependent Multi-Valued Tags
/// Some tags may support multiple values depending on the container format:
/// - **Vorbis Comments**: Native multi-value support for most fields
/// - **ID3v2**: Multiple frames of the same type for some fields
/// - **MP4**: Generally single-valued with delimiter-separated content
/// - **ID3v1**: Single-valued only due to format limitations
///
/// ## Implementation Details
///
/// The function uses a conservative approach, identifying fields that are
/// commonly multi-valued across formats or have inherent multi-value semantics.
/// This helps applications make informed decisions about:
/// - UI design (single input vs. list management)
/// - Data validation and normalization
/// - Merge conflict resolution strategies
/// - Storage and retrieval patterns
///
/// ## Usage Examples
///
/// ```dart
/// // Check if a field supports multiple values
/// if (isMultiValued(TagKey.genre)) {
///   // Handle as list of genres
///   final genres = ['Rock', 'Alternative', 'Indie'];
///   final genreTag = GenreTag(genres);
/// }
///
/// if (isMultiValued(TagKey.artwork)) {
///   // Handle multiple artwork images
///   final artworkList = <ArtworkTag>[];
///   // ... add multiple artwork tags
/// }
///
/// if (!isMultiValued(TagKey.title)) {
///   // Handle as single value
///   final titleTag = TitleTag('Song Title');
/// }
///
/// // Use in UI logic
/// Widget buildTagEditor(TagKey key) {
///   if (isMultiValued(key)) {
///     return MultiValueTagEditor(key: key);
///   } else {
///     return SingleValueTagEditor(key: key);
///   }
/// }
///
/// // Use in merge logic
/// List<MetadataTag> mergeTags(List<MetadataTag> tags, TagKey key) {
///   if (isMultiValued(key)) {
///     // Combine all values, removing duplicates
///     return combineMultiValuedTags(tags);
///   } else {
///     // Use precedence rules to select single value
///     return [selectHighestPrecedenceTag(tags)];
///   }
/// }
/// ```
///
/// ## Container Format Considerations
///
/// While this function provides a general assessment of multi-valued nature,
/// specific container formats may have different capabilities:
///
/// - **ID3v1**: No multi-valued support (all fields are single-valued)
/// - **ID3v2**: Some fields support multiple frames (artwork, comments)
/// - **Vorbis**: Native multi-value support for most text fields
/// - **MP4**: Generally single atoms with delimiter-separated content
///
/// For container-specific multi-value support, use [TagCapability.semantics]
/// to check the [TagSemantics.multiValued] property for the target format.
///
/// ## Performance Considerations
///
/// This function uses a simple switch statement for O(1) lookup performance.
/// It's safe to call frequently without performance concerns.
///
/// @param key The tag key to analyze for multi-valued support
/// @returns `true` if the tag key typically supports multiple values, `false` otherwise
///
/// ## See Also
///
/// - [TagSemantics.multiValued]: Container-specific multi-value support
/// - [TagCapability]: Complete capability information for container formats
/// - [GenreTag]: Example of inherently multi-valued tag implementation
/// - [ArtworkTag]: Example of multi-valued artwork handling
bool isMultiValued(TagKey key) {
  switch (key) {
    // Inherently multi-valued tags that commonly contain multiple distinct values
    case TagKey.genre:
      // Genres are commonly multi-valued across all formats
      // - Vorbis: Multiple GENRE= entries
      // - ID3v2: Delimited strings in TCON frame
      // - MP4: Semicolon-separated in ©gen atom
      // - ID3v1: Single genre only (format limitation)
      return true;

    case TagKey.artwork:
      // Artwork commonly includes multiple images of different types
      // - Front cover, back cover, artist photos, etc.
      // - Most formats support multiple artwork entries
      // - ID3v2: Multiple APIC frames
      // - Vorbis: Multiple METADATA_BLOCK_PICTURE blocks
      // - MP4: Multiple covr atoms
      return true;

    case TagKey.custom:
      // Custom fields may contain multiple values depending on application needs
      // - Vorbis: Multiple entries with same field name
      // - ID3v2: Multiple TXXX frames with same description
      // - MP4: Multiple freeform atoms (though less common)
      return true;

    // Single-valued tags that typically contain one distinct value
    case TagKey.title:
    case TagKey.artist:
    case TagKey.album:
    case TagKey.albumArtist:
    case TagKey.comment:
    case TagKey.grouping:
    case TagKey.composer:
    case TagKey.encoder:
    case TagKey.isrc:
    case TagKey.musicalKey:
    case TagKey.lyrics:
    case TagKey.trackNumber:
    case TagKey.discNumber:
    case TagKey.year:
    case TagKey.dateRecorded:
    case TagKey.bpm:
    case TagKey.rating:
      // These fields typically contain single values across all formats
      // Even when formats support multiple entries, the semantic meaning
      // is usually singular (one title, one artist, one album, etc.)
      return false;
  }
}

/// Determines whether a [TagKey] supports multiple values in a specific container format.
///
/// This function provides container-specific multi-value support information by
/// checking the [TagSemantics.multiValued] property for the given tag key in
/// the specified capability definition.
///
/// Unlike [isMultiValued], which provides general multi-value assessment,
/// this function gives precise information about what a specific container
/// format supports for a particular field.
///
/// ## Usage Examples
///
/// ```dart
/// import '../capabilities/vorbis_capability.dart';
/// import '../capabilities/id3v24_capability.dart';
/// import '../capabilities/id3v1_capability.dart';
///
/// // Check Vorbis Comments support
/// final vorbisSupportsMultiGenre = isMultiValuedInContainer(
///   TagKey.genre,
///   vorbisCapability,
/// ); // true - Vorbis supports multiple GENRE= entries
///
/// // Check ID3v2.4 support
/// final id3v24SupportsMultiGenre = isMultiValuedInContainer(
///   TagKey.genre,
///   id3v24Capability,
/// ); // true - ID3v2.4 uses null-terminated strings in TCON
///
/// // Check ID3v1 support
/// final id3v1SupportsMultiGenre = isMultiValuedInContainer(
///   TagKey.genre,
///   id3v1Capability,
/// ); // false - ID3v1 supports only single genre byte
///
/// // Use in format-specific processing
/// void processGenres(List<String> genres, TagCapability capability) {
///   if (isMultiValuedInContainer(TagKey.genre, capability)) {
///     // Write all genres to container
///     writeMultipleGenres(genres, capability);
///   } else {
///     // Use only first genre for single-value containers
///     writeSingleGenre(genres.first, capability);
///   }
/// }
/// ```
///
/// ## Container Format Differences
///
/// Different container formats have varying multi-value support:
///
/// ### Vorbis Comments (FLAC, OGG, Opus)
/// - Native multi-value support through multiple field entries
/// - Most text fields can have multiple values
/// - Clean separation without delimiter parsing
///
/// ### ID3v2.4
/// - Multi-value support through frame repetition or delimited content
/// - Genre uses null-terminated strings in single TCON frame
/// - Artwork supports multiple APIC frames
///
/// ### ID3v2.3/v2.2
/// - Similar to ID3v2.4 but genre uses slash separation
/// - Some fields support multiple frames
///
/// ### MP4
/// - Generally single atoms with delimiter-separated content
/// - Multiple covr atoms for artwork
/// - Limited multi-value support compared to Vorbis
///
/// ### ID3v1
/// - No multi-value support (legacy format limitations)
/// - All fields are single-valued with strict length limits
///
/// @param key The tag key to check for multi-value support
/// @param capability The container capability definition to check against
/// @returns `true` if the container supports multiple values for this field, `false` otherwise
///
/// ## See Also
///
/// - [isMultiValued]: General multi-value assessment independent of container
/// - [TagCapability.semantics]: Get complete semantic constraints for a field
/// - [TagSemantics.multiValued]: The underlying multi-value flag
bool isMultiValuedInContainer(TagKey key, TagCapability capability) {
  return capability.semantics(key).multiValued;
}
