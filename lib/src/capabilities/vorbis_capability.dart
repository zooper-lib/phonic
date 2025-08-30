/// Vorbis Comments metadata format capability definition.
///
/// This file defines the capabilities and constraints of the Vorbis Comments
/// metadata format, which is used in FLAC, OGG Vorbis, and Opus audio files.
///
/// Vorbis Comments provide a flexible key-value structure with full Unicode
/// support and native multi-valued field capabilities, making them one of
/// the most flexible metadata formats supported by the library.

import '../core/container_kind.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';
import '../core/tag_semantics.dart';
import '../core/text_encoding.dart';

/// Encoding set for Vorbis Comments with UTF-8 support only.
///
/// Vorbis Comments exclusively use UTF-8 encoding for all text fields,
/// providing full Unicode support without the complexity of multiple
/// encoding options found in ID3v2 formats.
///
/// This simplifies text handling and ensures consistent international
/// character support across all Vorbis-based formats (FLAC, OGG, Opus).
///
/// Uses [TextEncoding.utf8Name] constant to ensure consistency with the
/// TextEncoding enum definition.
const Set<String> _vorbisTextEncodings = {
  TextEncoding.utf8Name,
};

/// Capability definition for Vorbis Comments metadata format.
///
/// Vorbis Comments provide comprehensive metadata support with the following characteristics:
/// - UTF-8 encoding for all text fields (full Unicode support)
/// - No length restrictions on individual fields
/// - Native multi-valued field support through multiple key=value pairs
/// - Case-insensitive field names by convention (stored as uppercase)
/// - Artwork support through METADATA_BLOCK_PICTURE (FLAC) or base64 encoding (OGG)
/// - Extensible field names for custom metadata
/// - Clean key-value semantics without complex frame structures
///
/// Key advantages over other formats:
/// - Simplest and most flexible metadata structure
/// - Full Unicode support without encoding complexity
/// - Native multi-value support (no delimiter parsing needed)
/// - No arbitrary length limits or constraints
/// - Consistent behavior across FLAC, OGG Vorbis, and Opus
///
/// Field mappings (case-insensitive, stored uppercase):
/// - TITLE: Title
/// - ARTIST: Artist
/// - ALBUM: Album
/// - ALBUMARTIST: Album Artist
/// - GENRE: Genre (supports multiple GENRE= entries)
/// - COMMENT: Comment
/// - GROUPING: Grouping
/// - COMPOSER: Composer
/// - ENCODER: Encoder
/// - ISRC: ISRC
/// - KEY: Musical Key
/// - LYRICS: Lyrics
/// - TRACKNUMBER: Track Number
/// - DISCNUMBER: Disc Number
/// - DATE: Date Recorded (ISO-8601 format)
/// - BPM: BPM
/// - RATING: Rating (0-100 scale, stored as text)
/// - METADATA_BLOCK_PICTURE: Artwork (FLAC format)
/// - Custom fields: Any field name not in standard set
const TagCapability vorbisCapability = TagCapability(
  containerKind: ContainerKind.vorbis,
  containerVersion: '',
  semanticsByKey: {
    /// Title field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as TITLE=value. No length restrictions, full Unicode support.
    /// Multiple TITLE entries are technically possible but not recommended.
    TagKey.title: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Artist field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as ARTIST=value. For multiple artists, use multiple ARTIST
    /// entries or ALBUMARTIST for compilation albums.
    TagKey.artist: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Album field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as ALBUM=value. No length restrictions, supports full album
    /// titles in any language.
    TagKey.album: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Album artist field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as ALBUMARTIST=value. Used for compilation albums or when
    /// the album artist differs from individual track artists.
    TagKey.albumArtist: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Genre field: Variable length, supports multiple values natively.
    ///
    /// Stored as multiple GENRE=value entries. This is the cleanest
    /// multi-genre implementation, avoiding delimiter parsing issues
    /// found in other formats. Each genre gets its own GENRE= entry.
    ///
    /// Example:
    /// GENRE=Rock
    /// GENRE=Alternative
    /// GENRE=Indie
    TagKey.genre: TagSemantics(
      multiValued: true,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Comment field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as COMMENT=value. Unlike ID3v1, there are no length
    /// restrictions and full Unicode is supported.
    TagKey.comment: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Grouping field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as GROUPING=value. Used for organizing tracks into
    /// logical groups or categories.
    TagKey.grouping: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Composer field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as COMPOSER=value. Important for classical music and
    /// instrumental tracks where composer differs from performer.
    TagKey.composer: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Encoder field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as ENCODER=value. Records the software/hardware used
    /// to encode the audio file.
    TagKey.encoder: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// ISRC field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as ISRC=value. International Standard Recording Code
    /// for unique track identification.
    TagKey.isrc: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Musical key field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as KEY=value. Musical key of the track (e.g., "C", "Am", "F#m").
    /// Note: Some systems use INITIALKEY instead of KEY.
    TagKey.musicalKey: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Lyrics field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored as LYRICS=value. Supports full song lyrics with no length
    /// restrictions and complete Unicode support for international lyrics.
    TagKey.lyrics: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Track number field: Stored as text in TRACKNUMBER field.
    ///
    /// Stored as TRACKNUMBER=value. Can be just the track number ("5")
    /// or include total tracks ("5/12"). Validated as positive integer.
    TagKey.trackNumber: TagSemantics(
      minValue: 1,
      maxValue: 999, // Practical limit for track numbers
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Disc number field: Stored as text in DISCNUMBER field.
    ///
    /// Stored as DISCNUMBER=value. Similar to track number, can include
    /// total disc count ("2/3"). Validated as positive integer.
    TagKey.discNumber: TagSemantics(
      minValue: 1,
      maxValue: 99, // Practical limit for disc numbers
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Year field: 4-digit year extracted from DATE field.
    ///
    /// Vorbis Comments use the DATE field for date information, typically
    /// in ISO-8601 format. The year is extracted from the full date value.
    TagKey.year: TagSemantics(
      minValue: 1000,
      maxValue: 3000,
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// BPM field: Beats per minute stored as text in BPM field.
    ///
    /// Stored as BPM=value. Text representation of the BPM value,
    /// validated to ensure reasonable BPM ranges.
    TagKey.bpm: TagSemantics(
      minValue: 1,
      maxValue: 999,
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Rating field: 0-100 scale stored as text in RATING field.
    ///
    /// Stored as RATING=value. Uses the unified 0-100 scale directly,
    /// unlike ID3v2 which uses 0-255. Stored as text representation.
    TagKey.rating: TagSemantics(
      minValue: 0,
      maxValue: 100,
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Date recorded field: Uses DATE field in ISO-8601 format.
    ///
    /// Stored as DATE=value. Vorbis Comments recommend ISO-8601 format
    /// for date fields, providing consistent date/time representation.
    TagKey.dateRecorded: TagSemantics(
      multiValued: false,
      allowedEncodings: _vorbisTextEncodings,
    ),

    /// Artwork field: Supports multiple artwork through METADATA_BLOCK_PICTURE.
    ///
    /// FLAC uses METADATA_BLOCK_PICTURE blocks for artwork storage.
    /// OGG Vorbis may use base64-encoded COVERART fields or similar.
    /// Supports multiple artwork types and lazy loading.
    TagKey.artwork: TagSemantics(
      multiValued: true, // Multiple artwork images supported
    ),

    /// Custom field: Supports any custom field names.
    ///
    /// Vorbis Comments allow arbitrary field names for custom metadata.
    /// Field names should be uppercase by convention and contain only
    /// ASCII letters, numbers, and underscores.
    TagKey.custom: TagSemantics(
      multiValued: true,
      allowedEncodings: _vorbisTextEncodings,
    ),
  },
);
