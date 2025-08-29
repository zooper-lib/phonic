import 'package:phonic/core/models/metadata/audio_metadata.dart';

abstract class PhonicAudioFile {
  /// Set or update a metadata tag
  ///
  /// The implementation will handle where this gets stored (ID3v1, ID3v2, Vorbis Comments, etc.)
  /// For MP3: setting title will update both ID3v1 and ID3v2 if they exist
  void setTag(MetadataTag tag);

  /// Get a metadata tag by type
  ///
  /// Returns the tag if it exists, null otherwise
  T? getTag<T extends MetadataTag>();

  /// Get all tags of a specific type (useful for album art where multiple can exist)
  List<T> getTags<T extends MetadataTag>();

  /// Remove a specific tag
  void removeTag(MetadataTag tag);

  /// Remove all tags of a specific type
  void removeTagsByType<T extends MetadataTag>();

  /// Get all metadata tags
  List<MetadataTag> getAllTags();

  /// Check if the file has been modified since last save
  bool get isDirty;

  /// Mark the file as clean (usually called after saving)
  void markClean();

  /// Encodes the audio file to bytes with current metadata
  List<int> encode();

  /// Gets the raw audio data without metadata
  List<int> get audioData;
}
