import '../tag_key.dart';

/// Mapping table for Vorbis comment field names.
///
/// This class provides static mappings between unified [TagKey] values and
/// their corresponding Vorbis comment field names used in FLAC and OGG formats.
/// Vorbis comments use case-insensitive field names in KEY=VALUE format.
///
/// The mappings follow the standard Vorbis comment field names as defined in
/// the Vorbis specification and common implementations:
///
/// - **FLAC**: Uses Vorbis comments in METADATA_BLOCK_VORBIS_COMMENT blocks
/// - **OGG Vorbis**: Uses Vorbis comments in comment headers
/// - **OGG Opus**: Uses Vorbis comments for metadata
///
/// Example usage:
/// ```dart
/// // Get Vorbis field name for a tag key
/// final titleField = VorbisCommentMap.keys[TagKey.title]; // "TITLE"
/// final artistField = VorbisCommentMap.keys[TagKey.artist]; // "ARTIST"
///
/// // Check if a tag is supported
/// final supportsRating = VorbisCommentMap.keys.containsKey(TagKey.rating); // true
/// final supportsCustom = VorbisCommentMap.keys.containsKey(TagKey.custom); // false
///
/// // Get all supported tag keys
/// final supportedTags = VorbisCommentMap.getSupportedTags();
/// ```
///
/// Notable characteristics of Vorbis comments:
/// - Field names are case-insensitive (but conventionally uppercase)
/// - Multiple values for the same field are supported natively
/// - UTF-8 encoding is used for all text
/// - No length limits (unlike ID3v1)
/// - Custom fields are supported without special encoding
/// - Artwork is handled separately via METADATA_BLOCK_PICTURE (FLAC) or base64 encoding (OGG)
class VorbisCommentMap {
  /// Field name mappings for Vorbis comments.
  ///
  /// Maps unified [TagKey] values to their corresponding Vorbis comment field names.
  /// These field names are based on the standard Vorbis comment specification
  /// and are widely supported across FLAC, OGG Vorbis, and OGG Opus formats.
  ///
  /// Field name conventions:
  /// - All field names are uppercase by convention
  /// - Field names are case-insensitive when parsing
  /// - Multi-word field names use no separators (e.g., ALBUMARTIST, TRACKNUMBER)
  /// - Standard field names should be preferred over custom variants
  static const Map<TagKey, String> keys = {
    TagKey.title: 'TITLE',
    TagKey.artist: 'ARTIST',
    TagKey.album: 'ALBUM',
    TagKey.albumArtist: 'ALBUMARTIST',
    TagKey.trackNumber: 'TRACKNUMBER',
    TagKey.discNumber: 'DISCNUMBER',
    TagKey.dateRecorded: 'DATE',
    TagKey.genre: 'GENRE',
    TagKey.comment: 'COMMENT',
    TagKey.bpm: 'BPM',
    TagKey.musicalKey: 'KEY',
    TagKey.rating: 'RATING',
    TagKey.lyrics: 'LYRICS',
    TagKey.grouping: 'GROUPING',
    TagKey.composer: 'COMPOSER',
    TagKey.encoder: 'ENCODER',
    TagKey.isrc: 'ISRC',
    // Note: artwork is handled separately via METADATA_BLOCK_PICTURE (FLAC)
    // or base64 encoded fields (OGG), not through standard comment fields
    // Note: custom fields are supported natively in Vorbis comments without
    // special encoding, so TagKey.custom is not included in this mapping
  };

  /// Returns all supported tag keys for Vorbis comments.
  ///
  /// This method provides a convenient way to check which tags are supported
  /// by Vorbis comments without needing to access the map directly.
  ///
  /// Example:
  /// ```dart
  /// final supportedTags = VorbisCommentMap.getSupportedTags();
  /// final supportsRating = supportedTags.contains(TagKey.rating); // true
  /// final supportsArtwork = supportedTags.contains(TagKey.artwork); // false
  /// ```
  static Set<TagKey> getSupportedTags() {
    return keys.keys.toSet();
  }

  /// Returns the Vorbis comment field name for a given tag key.
  ///
  /// Returns null if the tag is not supported in Vorbis comments through
  /// standard field mappings. Note that custom fields and artwork are
  /// handled through different mechanisms.
  ///
  /// Example:
  /// ```dart
  /// final fieldName = VorbisCommentMap.getFieldName(TagKey.title); // "TITLE"
  /// final unsupported = VorbisCommentMap.getFieldName(TagKey.artwork); // null
  /// ```
  static String? getFieldName(TagKey tagKey) {
    return keys[tagKey];
  }

  /// Returns the tag key for a given Vorbis comment field name.
  ///
  /// This method performs case-insensitive matching since Vorbis comment
  /// field names are case-insensitive. Returns null if the field name
  /// is not recognized as a standard field.
  ///
  /// Example:
  /// ```dart
  /// final tagKey = VorbisCommentMap.getTagKey("TITLE"); // TagKey.title
  /// final lowerCase = VorbisCommentMap.getTagKey("artist"); // TagKey.artist
  /// final unknown = VorbisCommentMap.getTagKey("CUSTOM_FIELD"); // null
  /// ```
  static TagKey? getTagKey(String fieldName) {
    final upperFieldName = fieldName.toUpperCase();

    for (final entry in keys.entries) {
      if (entry.value == upperFieldName) {
        return entry.key;
      }
    }

    return null;
  }

  /// Returns whether a field name is a standard Vorbis comment field.
  ///
  /// This method performs case-insensitive matching and can be used to
  /// distinguish between standard fields and custom fields when parsing
  /// Vorbis comments.
  ///
  /// Example:
  /// ```dart
  /// final isStandard = VorbisCommentMap.isStandardField("TITLE"); // true
  /// final isCustom = VorbisCommentMap.isStandardField("MY_CUSTOM_FIELD"); // false
  /// ```
  static bool isStandardField(String fieldName) {
    return getTagKey(fieldName) != null;
  }

  /// Private constructor to prevent instantiation.
  ///
  /// This class only provides static methods and constants, so instantiation
  /// is not needed or allowed.
  VorbisCommentMap._();
}
