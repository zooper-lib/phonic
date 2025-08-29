/// ID3v2.4 metadata format capability definition.
///
/// This file defines the capabilities and constraints of the ID3v2.4 metadata
/// format, including supported fields, encoding enhancements, and value ranges.
///
/// ID3v2.4 is the most advanced version of the ID3v2 specification, providing
/// significant improvements over ID3v2.3 including UTF-8 encoding support,
/// unified date handling, and enhanced frame structure.

import '../container_kind.dart';
import '../tag_capability.dart';
import '../tag_key.dart';
import '../tag_semantics.dart';
import '../text_encoding.dart';

/// Encoding set for ID3v2.4 text fields with full Unicode support.
///
/// ID3v2.4 supports all major text encodings including UTF-8, which was
/// the key enhancement over ID3v2.3. This provides the most comprehensive
/// international text support of any ID3v2 version.
///
/// Corresponds to:
/// - [TextEncoding.iso88591]: ISO-8859-1 (Latin-1)
/// - [TextEncoding.utf16]: UTF-16 with BOM
/// - [TextEncoding.utf16be]: UTF-16 Big Endian
/// - [TextEncoding.utf16le]: UTF-16 Little Endian
/// - [TextEncoding.utf8]: UTF-8 (ID3v2.4 enhancement)
const Set<String> _id3v24TextEncodings = {
  TextEncoding.iso88591Name,
  TextEncoding.utf16Name,
  TextEncoding.utf16beName,
  TextEncoding.utf16leName,
  TextEncoding.utf8Name,
};

/// Capability definition for ID3v2.4 metadata format.
///
/// ID3v2.4 provides the most comprehensive metadata support with the following characteristics:
/// - Variable-length text fields (no fixed size limits like ID3v1)
/// - Full encoding support: ISO-8859-1, UTF-16, and UTF-8
/// - Rating scale: 0-255 in POPM frames (converted to 0-100 unified scale)
/// - Date handling: Unified TDRC frame for date/time recording
/// - Full artwork support through APIC frames
/// - Custom fields and extended metadata support
/// - Multi-valued fields through multiple frames
/// - Enhanced frame structure and synchronization
///
/// Key improvements over ID3v2.3:
/// - UTF-8 encoding support for international text
/// - Unified TDRC frame instead of separate TYER/TDAT/TIME frames
/// - Improved frame structure and data integrity
/// - Enhanced synchronization and unsynchronization schemes
///
/// Frame mappings:
/// - TIT2: Title
/// - TPE1: Artist
/// - TALB: Album
/// - TPE2: Album Artist
/// - TCON: Genre (null-terminated for multiple values)
/// - COMM: Comment
/// - TIT1: Grouping
/// - TCOM: Composer
/// - TSSE: Encoder
/// - TSRC: ISRC
/// - TKEY: Musical Key
/// - USLT: Lyrics
/// - TRCK: Track Number
/// - TPOS: Disc Number
/// - TDRC: Date Recorded (unified date/time)
/// - TBPM: BPM
/// - POPM: Rating (0-255 scale)
/// - APIC: Artwork
const TagCapability id3v24Capability = TagCapability(
  containerKind: ContainerKind.id3v2,
  containerVersion: '2.4',
  semanticsByKey: {
    /// Title field: Variable length, single value, full encoding support.
    ///
    /// Stored in TIT2 frame. Supports ISO-8859-1, UTF-16, and UTF-8 encodings.
    /// UTF-8 support is a key enhancement over ID3v2.3.
    TagKey.title: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Artist field: Variable length, single value, full encoding support.
    ///
    /// Stored in TPE1 frame. Supports ISO-8859-1, UTF-16, and UTF-8 encodings.
    /// For multiple artists, use album artist field or separate with delimiters.
    TagKey.artist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Album field: Variable length, single value, full encoding support.
    ///
    /// Stored in TALB frame. Supports ISO-8859-1, UTF-16, and UTF-8 encodings.
    /// No practical length limit beyond frame size constraints.
    TagKey.album: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Album artist field: Variable length, single value, full encoding support.
    ///
    /// Stored in TPE2 frame. Used for compilation albums or when the album
    /// artist differs from the track artist.
    TagKey.albumArtist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Genre field: Variable length, supports multiple values via null-termination.
    ///
    /// Stored in TCON frame. Multiple genres are separated by null terminators
    /// (e.g., "Rock\0Alternative\0Indie"). This is an improvement over ID3v2.3's
    /// slash separation, providing better delimiter handling.
    TagKey.genre: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Comment field: Variable length, single value, full encoding support.
    ///
    /// Stored in COMM frame with language and description fields.
    /// Unlike ID3v1, there are no length restrictions.
    TagKey.comment: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Grouping field: Variable length, single value, full encoding support.
    ///
    /// Stored in TIT1 frame. Used for grouping related tracks together
    /// (e.g., "Classical", "Soundtrack").
    TagKey.grouping: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Composer field: Variable length, single value, full encoding support.
    ///
    /// Stored in TCOM frame. Particularly important for classical music
    /// and instrumental tracks.
    TagKey.composer: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Encoder field: Variable length, single value, full encoding support.
    ///
    /// Stored in TSSE frame. Records the software/hardware used to encode
    /// the audio file.
    TagKey.encoder: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// ISRC field: Variable length, single value, full encoding support.
    ///
    /// Stored in TSRC frame. International Standard Recording Code for
    /// unique track identification.
    TagKey.isrc: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Musical key field: Variable length, single value, full encoding support.
    ///
    /// Stored in TKEY frame. Musical key of the track (e.g., "C", "Am", "F#m").
    TagKey.musicalKey: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Lyrics field: Variable length, single value, full encoding support.
    ///
    /// Stored in USLT frame with language and description fields.
    /// Supports full song lyrics with no practical length limit.
    TagKey.lyrics: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Track number field: Stored as text in TRCK frame, supports track/total format.
    ///
    /// Can be stored as just the track number ("5") or with total tracks ("5/12").
    /// Validated to ensure positive integer values.
    TagKey.trackNumber: TagSemantics(
      minValue: 1,
      maxValue: 999, // Practical limit for track numbers
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Disc number field: Stored as text in TPOS frame, supports disc/total format.
    ///
    /// Similar to track number, can include total disc count ("2/3").
    /// Validated to ensure positive integer values.
    TagKey.discNumber: TagSemantics(
      minValue: 1,
      maxValue: 99, // Practical limit for disc numbers
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Year field: 4-digit year extracted from TDRC frame.
    ///
    /// ID3v2.4 uses the unified TDRC frame for date/time recording.
    /// The year is extracted from the full date/time value.
    TagKey.year: TagSemantics(
      minValue: 1000,
      maxValue: 3000,
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// BPM field: Beats per minute stored as text in TBPM frame.
    ///
    /// Stored as a text representation of the BPM value.
    /// Validated to ensure reasonable BPM ranges.
    TagKey.bpm: TagSemantics(
      minValue: 1,
      maxValue: 999,
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Rating field: 0-255 scale in POPM frame, converted to unified 0-100 scale.
    ///
    /// ID3v2.4 stores ratings in POPM (Popularimeter) frames with a 0-255 scale.
    /// The API converts this to the unified 0-100 scale for consistency.
    /// POPM frames also include email and play counter fields.
    TagKey.rating: TagSemantics(
      minValue: 0,
      maxValue: 100,
      multiValued: false,
    ),

    /// Date recorded field: Uses unified TDRC frame in ID3v2.4.
    ///
    /// ID3v2.4 introduced the TDRC frame to replace the separate TYER/TDAT/TIME
    /// frames used in ID3v2.3. This provides better date/time handling and
    /// supports ISO-8601 format timestamps.
    TagKey.dateRecorded: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v24TextEncodings,
    ),

    /// Artwork field: Full artwork support through APIC frames.
    ///
    /// ID3v2.4 APIC frames support multiple artwork types (front cover,
    /// back cover, artist photo, etc.) with MIME type and description.
    /// Supports lazy loading for memory efficiency.
    TagKey.artwork: TagSemantics(
      multiValued: true, // Multiple artwork images supported
    ),

    /// Custom field: Supports custom/non-standard metadata.
    ///
    /// ID3v2.4 allows custom frames and user-defined text frames (TXXX)
    /// for application-specific metadata not covered by standard frames.
    TagKey.custom: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v24TextEncodings,
    ),
  },
);
