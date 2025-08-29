import '../container_kind.dart';
import '../format_constraints.dart';
import '../tag_capability.dart';
import '../tag_key.dart';
import '../tag_semantics.dart';
import '../text_encoding.dart';

/// Encoding set for ID3v1 text fields with Latin-1 only support.
///
/// ID3v1 only supports ISO-8859-1 (Latin-1) encoding, providing basic
/// Western European character support but no Unicode capabilities.
///
/// Corresponds to:
/// - [TextEncoding.iso88591]: ISO-8859-1 (Latin-1)
const Set<String> _id3v1TextEncodings = {
  TextEncoding.iso88591Name,
};

/// ID3v1 metadata capability definition with format-specific constraints.
///
/// ID3v1 is a legacy metadata format with a fixed 128-byte structure located
/// at the end of MP3 files. It has strict limitations on field lengths and
/// supported data types, making it the most constrained format supported by
/// the Phonic library.
///
/// Key limitations:
/// - 30-character limit for most text fields (title, artist, album)
/// - Comment field is 30 characters, but reduced to 28 when track number is present
/// - Track number is stored as a single byte (1-255) in the comment field
/// - Genre is stored as a single byte referencing standard genre codes (0-255)
/// - Year field is exactly 4 characters
/// - No support for extended metadata (artwork, lyrics, custom fields, etc.)
/// - Latin-1 encoding only (no Unicode support)
///
/// The ID3v1 format structure:
/// ```
/// Offset  Length  Field
/// 0       3       "TAG" identifier
/// 3       30      Title
/// 33      30      Artist
/// 63      30      Album
/// 93      4       Year
/// 97      30      Comment (or 28 + 1 null + 1 track if track present)
/// 127     1       Genre code
/// ```
///
/// Usage example:
/// ```dart
/// // Check if a field is supported by ID3v1
/// if (id3v1Capability.supports(TagKey.artwork)) {
///   // This will be false - ID3v1 doesn't support artwork
/// }
///
/// // Get field constraints
/// final titleSemantics = id3v1Capability.semantics(TagKey.title);
/// if (!titleSemantics.isValidTextLength(title.length)) {
///   title = titleSemantics.truncateText(title); // Truncate to 30 chars
/// }
///
/// // Check track number range
/// final trackSemantics = id3v1Capability.semantics(TagKey.trackNumber);
/// if (!trackSemantics.isValidValue(trackNumber)) {
///   trackNumber = trackSemantics.clampValue(trackNumber); // Clamp to 1-255
/// }
/// ```
const id3v1Capability = TagCapability(
  containerKind: ContainerKind.id3v1,
  containerVersion: 'v1',
  semanticsByKey: {
    /// Title field: 30-character limit, single value only.
    ///
    /// The title is stored at bytes 3-32 in the ID3v1 structure.
    /// Text exceeding 30 characters will be truncated during write operations.
    TagKey.title: TagSemantics(
      maxTextLength: ID3v1Constraints.maxTextLength,
      multiValued: false,
      allowedEncodings: _id3v1TextEncodings,
    ),

    /// Artist field: 30-character limit, single value only.
    ///
    /// The artist is stored at bytes 33-62 in the ID3v1 structure.
    /// Text exceeding 30 characters will be truncated during write operations.
    TagKey.artist: TagSemantics(
      maxTextLength: ID3v1Constraints.maxTextLength,
      multiValued: false,
      allowedEncodings: _id3v1TextEncodings,
    ),

    /// Album field: 30-character limit, single value only.
    ///
    /// The album is stored at bytes 63-92 in the ID3v1 structure.
    /// Text exceeding 30 characters will be truncated during write operations.
    TagKey.album: TagSemantics(
      maxTextLength: ID3v1Constraints.maxTextLength,
      multiValued: false,
      allowedEncodings: _id3v1TextEncodings,
    ),

    /// Year field: exactly 4 characters, single value only.
    ///
    /// The year is stored at bytes 93-96 in the ID3v1 structure.
    /// Should contain a 4-digit year (e.g., "1995", "2023").
    /// Values will be converted to string and padded/truncated to 4 characters.
    TagKey.year: TagSemantics(
      maxTextLength: ID3v1Constraints.yearLength,
      multiValued: false,
      allowedEncodings: _id3v1TextEncodings,
    ),

    /// Comment field: 30 characters normally, 28 when track number is present.
    ///
    /// The comment field behavior depends on whether a track number is present:
    /// - Without track: Full 30 characters available (bytes 97-126)
    /// - With track: 28 characters + null terminator + track byte (bytes 97-124, 125=null, 126=track)
    ///
    /// Note: The actual length constraint is handled dynamically by the codec
    /// based on whether a track number is being written. This capability
    /// definition uses the more restrictive 28-character limit to ensure
    /// compatibility when both comment and track are present.
    TagKey.comment: TagSemantics(
      maxTextLength: ID3v1Constraints.commentLengthWithTrack, // Conservative limit when track number is present
      multiValued: false,
      allowedEncodings: _id3v1TextEncodings,
    ),

    /// Track number: single byte value (1-255).
    ///
    /// The track number is stored at byte 126 in the ID3v1 structure, but only
    /// when the comment field is 28 characters or less with a null terminator
    /// at position 125. Track number 0 is not valid in ID3v1.
    ///
    /// When a track number is present, it reduces the available comment space
    /// from 30 to 28 characters.
    TagKey.trackNumber: TagSemantics(
      minValue: ID3v1Constraints.minTrackNumber,
      maxValue: ID3v1Constraints.maxTrackNumber,
      multiValued: false,
    ),

    /// Genre: single byte referencing standard ID3v1 genre codes (0-255).
    ///
    /// The genre is stored at byte 127 (the last byte) in the ID3v1 structure.
    /// It references the standard ID3v1 genre table where each number corresponds
    /// to a specific genre name (e.g., 0=Blues, 1=Classic Rock, etc.).
    ///
    /// The library handles conversion between genre names and numeric codes
    /// automatically during read/write operations.
    TagKey.genre: TagSemantics(
      minValue: ID3v1Constraints.minGenreCode,
      maxValue: ID3v1Constraints.maxGenreCode,
      multiValued: false,
    ),

    // Note: ID3v1 does not support the following fields that are available
    // in other formats. These fields will be omitted when writing to ID3v1:
    // - albumArtist: Not supported
    // - discNumber: Not supported
    // - dateRecorded: Only year is supported via the year field
    // - bpm: Not supported
    // - musicalKey: Not supported
    // - rating: Not supported
    // - lyrics: Not supported
    // - artwork: Not supported
    // - grouping: Not supported
    // - composer: Not supported
    // - encoder: Not supported
    // - isrc: Not supported
    // - custom: Not supported
  },
);
