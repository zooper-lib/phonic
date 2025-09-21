import 'dart:typed_data';

import 'encoding_options.dart';
import 'metadata_tag.dart';
import 'tag_key.dart';

/// Abstract interface for audio file metadata operations.
///
/// PhonicAudioFile provides a unified interface for reading and writing
/// metadata tags across different audio container formats. This interface
/// abstracts away format-specific details and provides a consistent API
/// for tag operations regardless of the underlying container type.
///
/// The interface supports:
/// - Reading individual tags by key
/// - Reading multiple values for multi-valued tags
/// - Writing and updating tag values
/// - Removing tags and specific tag values
/// - Change tracking with dirty flags
/// - Serialization back to audio file format
/// - Memory management for large files
///
/// ## Usage Examples
///
/// ### Reading Tags
/// ```dart
/// final audioFile = await Phonic.fromFile('song.mp3');
///
/// // Get single tag value
/// final titleTag = audioFile.getTag(TagKey.title);
/// print('Title: ${titleTag?.value}');
///
/// // Get all values for multi-valued tags
/// final genreTags = audioFile.getTags(TagKey.genre);
/// for (final tag in genreTags) {
///   print('Genre: ${tag.value}');
/// }
///
/// // Get all tags
/// final allTags = audioFile.getAllTags();
/// ```
///
/// ### Writing Tags
/// ```dart
/// // Set single tag
/// audioFile.setTag(TitleTag('New Title'));
/// audioFile.setTag(ArtistTag('New Artist'));
///
/// // Set multi-valued tag
/// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
///
/// // Remove tag completely
/// audioFile.removeTag(TagKey.comment);
///
/// // Remove specific value from multi-valued tag
/// audioFile.removeTagValue(TagKey.genre, 'Pop');
/// ```
///
/// ### Change Management
/// ```dart
/// // Check if file has unsaved changes
/// if (audioFile.isDirty) {
///   final updatedBytes = await audioFile.encode();
///   await File('song.mp3').writeAsBytes(updatedBytes);
///   audioFile.markClean();
/// }
/// ```
///
/// ## Memory Management
///
/// Implementations should:
/// - Load artwork and large payloads lazily
/// - Cache container data only when necessary
/// - Provide dispose() method for cleanup
/// - Minimize memory footprint for large collections
///
/// ## Thread Safety
///
/// Implementations are not required to be thread-safe. Concurrent access
/// to the same instance should be synchronized by the caller.
abstract class PhonicAudioFile {
  /// Retrieves a single metadata tag for the specified key.
  ///
  /// Returns the highest-precedence tag value for the given key, or null
  /// if no tag exists for that key. For multi-valued tags, this returns
  /// the first value according to the format's precedence rules.
  ///
  /// ## Precedence Rules
  ///
  /// When multiple containers contain the same tag field, precedence is
  /// determined by the format strategy:
  /// - **MP3**: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
  /// - **FLAC/OGG/Opus**: Vorbis Comments only
  /// - **MP4/M4A**: MP4 atoms only
  ///
  /// ## Multi-valued Tag Behavior
  ///
  /// For tags that can contain multiple values (like genre or artwork),
  /// this method returns the first value from the highest-precedence
  /// container. Use [getTags] to retrieve all values.
  ///
  /// ## Performance Notes
  ///
  /// - This method is optimized for single-value access
  /// - Artwork data is loaded lazily and won't impact performance
  /// - Repeated calls for the same key are efficient due to internal caching
  ///
  /// @param key The tag key to retrieve
  /// @returns The metadata tag for the key, or null if not found
  ///
  /// Example:
  /// ```dart
  /// // Basic tag retrieval
  /// final titleTag = audioFile.getTag(TagKey.title);
  /// if (titleTag != null) {
  ///   print('Title: ${titleTag.value}');
  ///   print('Source: ${titleTag.provenance}');
  /// }
  ///
  /// // Handling different tag types
  /// final ratingTag = audioFile.getTag(TagKey.rating) as RatingTag?;
  /// if (ratingTag != null) {
  ///   print('Rating: ${ratingTag.value}/100');
  /// }
  ///
  /// // Multi-valued tag (returns first value)
  /// final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
  /// if (genreTag != null) {
  ///   print('Primary genre: ${genreTag.value.first}');
  /// }
  /// ```
  MetadataTag? getTag(TagKey key);

  /// Retrieves all metadata tags for the specified key.
  ///
  /// Returns all tag values for the given key from all containers,
  /// ordered by precedence. For single-valued tags, this typically
  /// returns a list with one element. For multi-valued tags like
  /// genre or artwork, this returns all available values.
  ///
  /// ## Ordering and Precedence
  ///
  /// The returned list is ordered by container precedence:
  /// 1. **Highest precedence** containers appear first
  /// 2. **Multiple values** from the same container maintain their original order
  /// 3. **Cross-container** values are merged according to format strategy rules
  ///
  /// ## Use Cases
  ///
  /// - **Multi-valued tags**: Get all genre entries, artwork images, etc.
  /// - **Provenance analysis**: Examine which containers provide each value
  /// - **Conflict resolution**: Compare values from different sources
  /// - **Comprehensive display**: Show all available metadata for a field
  ///
  /// ## Performance Considerations
  ///
  /// - For artwork tags, image data is loaded lazily
  /// - Large collections of tags are returned efficiently
  /// - Consider using [getTag] for single-value access when appropriate
  ///
  /// @param key The tag key to retrieve all values for
  /// @returns List of all metadata tags for the key (may be empty if no tags exist)
  ///
  /// Example:
  /// ```dart
  /// // Get all genre tags (may include multiple genres)
  /// final genreTags = audioFile.getTags(TagKey.genre);
  /// for (final tag in genreTags) {
  ///   final genres = (tag as GenreTag).value;
  ///   print('Genres from ${tag.provenance.containerKind}: ${genres.join(', ')}');
  /// }
  ///
  /// // Get all artwork images
  /// final artworkTags = audioFile.getTags(TagKey.artwork);
  /// for (final tag in artworkTags) {
  ///   final artwork = (tag as ArtworkTag).value;
  ///   print('${artwork.type}: ${artwork.mimeType}');
  ///   // Load image data only when needed
  ///   final imageData = await artwork.data;
  /// }
  ///
  /// // Compare values across containers
  /// final titleTags = audioFile.getTags(TagKey.title);
  /// if (titleTags.length > 1) {
  ///   print('Title conflicts detected:');
  ///   for (final tag in titleTags) {
  ///     print('  ${tag.provenance.containerKind}: "${tag.value}"');
  ///   }
  /// }
  ///
  /// // Check if any tags exist for a key
  /// final commentTags = audioFile.getTags(TagKey.comment);
  /// if (commentTags.isEmpty) {
  ///   print('No comments found in any container');
  /// }
  /// ```
  List<MetadataTag> getTags(TagKey key);

  /// Retrieves all metadata tags from all containers.
  ///
  /// Returns the complete set of metadata tags from all containers
  /// in the file, with duplicates resolved according to precedence
  /// rules. This provides a comprehensive view of all available
  /// metadata.
  ///
  /// Returns:
  /// - List of all metadata tags in the file
  ///
  /// Example:
  /// ```dart
  /// final allTags = audioFile.getAllTags();
  /// for (final tag in allTags) {
  ///   print('${tag.key}: ${tag.value}');
  /// }
  /// ```
  List<MetadataTag> getAllTags();

  /// Sets or updates a metadata tag.
  ///
  /// Adds the specified tag to the file's metadata, replacing any
  /// existing tag with the same key. The tag will be written to
  /// appropriate containers based on the format's fan-out policy.
  ///
  /// ## Fan-out Behavior
  ///
  /// The tag is written to containers according to the format strategy:
  /// - **MP3**: Written to ID3v2.4 and optionally ID3v1 (if supported)
  /// - **FLAC/OGG/Opus**: Written to Vorbis Comments
  /// - **MP4/M4A**: Written to MP4 atoms
  ///
  /// ## Container Compatibility
  ///
  /// - Tags are automatically validated against container capabilities
  /// - Values are normalized to fit container constraints (length limits, ranges)
  /// - Unsupported tags are skipped for containers that don't support them
  /// - Multi-valued tags are encoded appropriately for each container format
  ///
  /// ## Validation and Normalization
  ///
  /// The library automatically handles:
  /// - **Text truncation** for length-limited containers (e.g., ID3v1)
  /// - **Value clamping** for numeric ranges (e.g., rating 0-100 to 0-255)
  /// - **Encoding selection** based on container capabilities
  /// - **Format-specific encoding** (e.g., genre delimiters)
  ///
  /// ## State Changes
  ///
  /// - Sets the [isDirty] flag to indicate unsaved changes
  /// - Replaces any existing tag with the same key
  /// - Preserves other tags and metadata
  ///
  /// @param tag The metadata tag to set
  /// @throws TagValidationException if the tag value violates constraints
  /// @throws UnsupportedFormatException if the tag type is not supported by any target container
  ///
  /// Example:
  /// ```dart
  /// // Set basic text tags
  /// audioFile.setTag(TitleTag('New Song Title'));
  /// audioFile.setTag(ArtistTag('Artist Name'));
  /// audioFile.setTag(AlbumTag('Album Title'));
  ///
  /// // Set numeric tags with validation
  /// audioFile.setTag(RatingTag(85)); // 0-100 scale
  /// audioFile.setTag(TrackNumberTag(3));
  /// audioFile.setTag(YearTag(2023));
  ///
  /// // Set multi-valued tags
  /// audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));
  ///
  /// // Set artwork with lazy loading
  /// final artworkData = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   description: 'Album cover',
  ///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
  /// );
  /// audioFile.setTag(ArtworkTag(artworkData));
  ///
  /// // Handle validation errors
  /// try {
  ///   audioFile.setTag(RatingTag(150)); // Invalid: exceeds 100
  /// } on TagValidationException catch (e) {
  ///   print('Validation failed: ${e.reason}');
  ///   // Correct the value
  ///   audioFile.setTag(RatingTag(100));
  /// }
  ///
  /// // Check if changes need saving
  /// if (audioFile.isDirty) {
  ///   final updatedBytes = await audioFile.encode();
  ///   await File('updated.mp3').writeAsBytes(updatedBytes);
  ///   audioFile.markClean();
  /// }
  /// ```
  void setTag(MetadataTag tag);

  /// Removes all tags for the specified key.
  ///
  /// Removes all metadata tags with the given key from all containers
  /// in the file. This completely eliminates the tag field from the
  /// file's metadata.
  ///
  /// Parameters:
  /// - [key]: The tag key to remove
  ///
  /// Example:
  /// ```dart
  /// // Remove all comment tags
  /// audioFile.removeTag(TagKey.comment);
  /// ```
  void removeTag(TagKey key);

  /// Removes a specific value from a multi-valued tag.
  ///
  /// For multi-valued tags like genre or artwork, this removes only
  /// the specified value while leaving other values intact. For
  /// single-valued tags, this is equivalent to removeTag().
  ///
  /// Parameters:
  /// - [key]: The tag key to modify
  /// - [value]: The specific value to remove
  ///
  /// Example:
  /// ```dart
  /// // Remove 'Pop' from genre list while keeping other genres
  /// audioFile.removeTagValue(TagKey.genre, 'Pop');
  /// ```
  void removeTagValue(TagKey key, dynamic value);

  /// Indicates whether the file has unsaved changes.
  ///
  /// Returns true if any metadata has been modified since the file
  /// was loaded or last marked clean. This flag helps determine
  /// when the file needs to be saved.
  ///
  /// Returns:
  /// - true if there are unsaved changes, false otherwise
  bool get isDirty;

  /// Marks the file as having no unsaved changes.
  ///
  /// Resets the dirty flag to indicate that all changes have been
  /// saved. This should be called after successfully writing the
  /// file to storage.
  void markClean();

  /// Encodes the file with current metadata to bytes.
  ///
  /// Generates the complete audio file with updated metadata,
  /// applying all pending changes to the appropriate containers.
  /// The returned bytes can be written to storage to persist
  /// the changes.
  ///
  /// ## Encoding Process
  ///
  /// The encoding process involves several steps:
  /// 1. **Validation**: All tags are validated against container capabilities
  /// 2. **Normalization**: Values are normalized to fit container constraints
  /// 3. **Container Building**: Each target container is rebuilt with new metadata
  /// 4. **File Assembly**: Containers are injected into the audio file structure
  /// 5. **Verification**: Optional post-write validation ensures file integrity
  ///
  /// ## Container Updates
  ///
  /// Only containers with changes are rebuilt:
  /// - **Modified containers** are completely reconstructed
  /// - **Unchanged containers** are preserved as-is for efficiency
  /// - **New containers** are created if tags require them
  /// - **Empty containers** may be removed to reduce file size
  ///
  /// ## Memory Efficiency
  ///
  /// - Large artwork data is streamed rather than loaded entirely into memory
  /// - Original audio data is preserved without copying when possible
  /// - Temporary buffers are used for container construction
  /// - Memory usage scales with metadata size, not audio file size
  ///
  /// ## Error Recovery
  ///
  /// If encoding fails partway through:
  /// - The original file data remains unchanged
  /// - No partial writes occur
  /// - The audio file instance remains in a consistent state
  /// - Specific error information is provided for debugging
  ///
  /// ## Performance Considerations
  ///
  /// - **Small files**: Encoding is typically very fast (< 1ms)
  /// - **Large files**: Time scales with file size and metadata complexity
  /// - **Artwork**: Large images may impact encoding time
  /// - **Multiple containers**: More containers require more processing
  ///
  /// ## Encoding Options
  ///
  /// The optional [options] parameter controls encoding behavior:
  ///
  /// - **Default strategy**: Uses [EncodingOptions.preserveExisting()] to maintain
  ///   compatibility with existing containers and metadata
  /// - **Optimized strategy**: Uses [EncodingOptions.optimized()] to target modern
  ///   container formats for best compatibility and feature support
  /// - **Explicit strategy**: Uses [EncodingOptions.explicit()] to specify exact
  ///   target containers and validation levels
  ///
  /// ### Encoding Strategies
  ///
  /// - [EncodingStrategy.preserveExisting] (default): Safest option, writes to
  ///   existing container types to maintain file compatibility
  /// - [EncodingStrategy.optimized]: Targets modern formats (ID3v2.4, latest specs)
  ///   for best metadata support and future compatibility
  /// - [EncodingStrategy.explicit]: Uses user-specified target containers
  ///
  /// ### Validation Levels
  ///
  /// - [ValidationLevel.basic]: Minimal validation, fastest encoding
  /// - [ValidationLevel.standard] (default): Reasonable validation with good performance
  /// - [ValidationLevel.strict]: Comprehensive validation including round-trip verification
  ///
  /// @param options Encoding configuration options (uses preserveExisting if null)
  /// @returns Future containing the complete encoded audio file bytes
  /// @throws TagValidationException if any tag values violate container constraints
  /// @throws UnsupportedFormatException if the format cannot be written
  /// @throws CorruptedContainerException if existing container data is corrupted
  /// @throws FileSystemException if temporary file operations fail
  ///
  /// Example:
  /// ```dart
  /// // Basic encoding with default options
  /// final bytes = await audioFile.encode();
  ///
  /// // Preserve existing containers (safest)
  /// final safeBytes = await audioFile.encode(EncodingOptions.preserveExisting());
  ///
  /// // Use optimized modern formats
  /// final modernBytes = await audioFile.encode(EncodingOptions.optimized());
  ///
  /// // Custom encoding with specific validation
  /// final customBytes = await audioFile.encode(
  ///   EncodingOptions.explicit(
  ///     targetContainers: [ContainerKind.id3v24],
  ///     validationLevel: ValidationLevel.strict,
  ///   ),
  /// );
  /// ```
  ///
  /// Example:
  /// ```dart
  /// // Basic encoding and saving
  /// if (audioFile.isDirty) {
  ///   try {
  ///     final bytes = await audioFile.encode();
  ///     await File('updated_song.mp3').writeAsBytes(bytes);
  ///     audioFile.markClean();
  ///     print('File saved successfully');
  ///   } catch (e) {
  ///     print('Failed to save file: $e');
  ///   }
  /// }
  ///
  /// // Encoding with error handling
  /// try {
  ///   final bytes = await audioFile.encode();
  ///
  ///   // Verify the encoded file size is reasonable
  ///   if (bytes.length > 100 * 1024 * 1024) { // 100MB
  ///     print('Warning: Encoded file is very large (${bytes.length} bytes)');
  ///   }
  ///
  ///   await File('output.mp3').writeAsBytes(bytes);
  /// ```
  Future<Uint8List> encode([EncodingOptions? options]);

  /// Gets the raw audio data without metadata containers.
  ///
  /// Returns the pure audio stream data with all metadata containers
  /// removed. This is useful for audio processing operations that
  /// need access to the raw audio content.
  ///
  /// Returns:
  /// - The raw audio data bytes
  Uint8List get audioData;

  /// Releases resources and cleans up memory.
  ///
  /// Disposes of cached data, closes file handles, and releases
  /// other resources held by this instance. The instance should
  /// not be used after calling dispose().
  void dispose();
}
