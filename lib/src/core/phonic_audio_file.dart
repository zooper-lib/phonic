import 'dart:typed_data';

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
  /// Parameters:
  /// - [key]: The tag key to retrieve
  ///
  /// Returns:
  /// - The metadata tag for the key, or null if not found
  ///
  /// Example:
  /// ```dart
  /// final titleTag = audioFile.getTag(TagKey.title);
  /// if (titleTag != null) {
  ///   print('Title: ${titleTag.value}');
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
  /// Parameters:
  /// - [key]: The tag key to retrieve
  ///
  /// Returns:
  /// - List of all metadata tags for the key (may be empty)
  ///
  /// Example:
  /// ```dart
  /// final genreTags = audioFile.getTags(TagKey.genre);
  /// for (final tag in genreTags) {
  ///   print('Genre: ${tag.value} from ${tag.provenance}');
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
  /// Parameters:
  /// - [tag]: The metadata tag to set
  ///
  /// Example:
  /// ```dart
  /// audioFile.setTag(TitleTag('New Song Title'));
  /// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
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
  /// Returns:
  /// - Future containing the complete encoded audio file bytes
  ///
  /// Throws:
  /// - [TagValidationException] if tag values are invalid
  /// - [UnsupportedFormatException] if format cannot be written
  ///
  /// Example:
  /// ```dart
  /// if (audioFile.isDirty) {
  ///   final bytes = await audioFile.encode();
  ///   await File('updated_song.mp3').writeAsBytes(bytes);
  ///   audioFile.markClean();
  /// }
  /// ```
  Future<Uint8List> encode();

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
