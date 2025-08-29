/// ID3v2.3 metadata format capability definition.
///
/// This file defines the capabilities and constraints of the ID3v2.3 metadata
/// format, including supported fields, encoding limitations, and value ranges.
///
/// ID3v2.3 is a widely-supported metadata format that provides significant
/// improvements over ID3v1 while maintaining broad compatibility. It supports
/// variable-length fields, multiple text encodings (except UTF-8), and
/// extensive metadata including artwork and custom fields.

import '../container_kind.dart';
import '../tag_capability.dart';
import '../tag_key.dart';
import '../tag_semantics.dart';
import '../text_encoding.dart';

/// Encoding set for ID3v2.3 text fields without UTF-8 support.
///
/// ID3v2.3 supports ISO-8859-1 and UTF-16 encodings but lacks UTF-8 support,
/// which was added in ID3v2.4. This provides good international text support
/// through UTF-16 while maintaining backward compatibility with Latin-1.
///
/// Corresponds to:
/// - [TextEncoding.iso88591]: ISO-8859-1 (Latin-1)
/// - [TextEncoding.utf16]: UTF-16 with BOM
/// - [TextEncoding.utf16be]: UTF-16 Big Endian
/// - [TextEncoding.utf16le]: UTF-16 Little Endian
const Set<String> _id3v23TextEncodings = {
  TextEncoding.iso88591Name,
  TextEncoding.utf16Name,
  TextEncoding.utf16beName,
  TextEncoding.utf16leName,
};

/// Capability definition for ID3v2.3 metadata format.
///
/// ID3v2.3 provides extensive metadata support with the following characteristics:
/// - Variable-length text fields (no fixed size limits like ID3v1)
/// - Multiple encoding support: ISO-8859-1, UTF-16 (no UTF-8)
/// - Rating scale: 0-255 in POPM frames (converted to 0-100 unified scale)
/// - Date handling: Separate TYER/TDAT/TIME frames (not TDRC like v2.4)
/// - Full artwork support through APIC frames
/// - Custom fields and extended metadata support
/// - Multi-valued fields through multiple frames
///
/// Key limitations compared to ID3v2.4:
/// - No UTF-8 encoding support (added in v2.4)
/// - Uses legacy date frames instead of unified TDRC
/// - Some frame types differ from v2.4
///
/// Frame mappings:
/// - TIT2: Title
/// - TPE1: Artist
/// - TALB: Album
/// - TPE2: Album Artist
/// - TCON: Genre (slash-separated for multiple values)
/// - COMM: Comment
/// - TIT1: Grouping
/// - TCOM: Composer
/// - TENC: Encoder
/// - TSRC: ISRC
/// - TKEY: Musical Key
/// - USLT: Lyrics
/// - TRCK: Track Number
/// - TPOS: Disc Number
/// - TYER: Year
/// - TBPM: BPM
/// - POMP: Rating (0-255 scale)
/// - APIC: Artwork
const TagCapability id3v23Capability = TagCapability(
  containerKind: ContainerKind.id3v2,
  containerVersion: '2.3',
  semanticsByKey: {
    /// Title field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TIT2 frame. Supports ISO-8859-1 and UTF-16 encodings.
    /// No practical length limit beyond frame size constraints.
    TagKey.title: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Artist field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TPE1 frame. Supports ISO-8859-1 and UTF-16 encodings.
    /// For multiple artists, use album artist field or separate with delimiters.
    TagKey.artist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Album field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TALB frame. Supports ISO-8859-1 and UTF-16 encodings.
    /// No practical length limit beyond frame size constraints.
    TagKey.album: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Album artist field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TPE2 frame. Used for compilation albums or when the album
    /// artist differs from the track artist.
    TagKey.albumArtist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Genre field: Variable length, supports multiple values via slash separation.
    ///
    /// Stored in TCON frame. Multiple genres are separated by forward slashes
    /// (e.g., "Rock/Alternative/Indie"). Also supports numeric ID3v1 genre
    /// codes in parentheses (e.g., "(17)" for Rock).
    TagKey.genre: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Comment field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in COMM frame with language and description fields.
    /// Unlike ID3v1, there are no length restrictions.
    TagKey.comment: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Grouping field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TIT1 frame. Used for grouping related tracks together
    /// (e.g., "Classical", "Soundtrack").
    TagKey.grouping: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Composer field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TCOM frame. Particularly important for classical music
    /// and instrumental tracks.
    TagKey.composer: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Encoder field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TENC frame. Records the software/hardware used to encode
    /// the audio file.
    TagKey.encoder: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// ISRC field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TSRC frame. International Standard Recording Code for
    /// unique track identification.
    TagKey.isrc: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Musical key field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in TKEY frame. Musical key of the track (e.g., "C", "Am", "F#m").
    TagKey.musicalKey: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Lyrics field: Variable length, single value, multiple encodings supported.
    ///
    /// Stored in USLT frame with language and description fields.
    /// Supports full song lyrics with no practical length limit.
    TagKey.lyrics: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Track number field: Stored as text in TRCK frame, supports track/total format.
    ///
    /// Can be stored as just the track number ("5") or with total tracks ("5/12").
    /// Validated to ensure positive integer values.
    TagKey.trackNumber: TagSemantics(
      minValue: 1,
      maxValue: 999, // Practical limit for track numbers
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Disc number field: Stored as text in TPOS frame, supports disc/total format.
    ///
    /// Similar to track number, can include total disc count ("2/3").
    /// Validated to ensure positive integer values.
    TagKey.discNumber: TagSemantics(
      minValue: 1,
      maxValue: 99, // Practical limit for disc numbers
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Year field: 4-digit year stored in TYER frame.
    ///
    /// ID3v2.3 uses separate date frames (TYER/TDAT/TIME) instead of
    /// the unified TDRC frame introduced in v2.4.
    TagKey.year: TagSemantics(
      minValue: 1000,
      maxValue: 3000,
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// BPM field: Beats per minute stored as text in TBPM frame.
    ///
    /// Stored as a text representation of the BPM value.
    /// Validated to ensure reasonable BPM ranges.
    TagKey.bpm: TagSemantics(
      minValue: 1,
      maxValue: 999,
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Rating field: 0-255 scale in POPM frame, converted to unified 0-100 scale.
    ///
    /// ID3v2.3 stores ratings in POPM (Popularimeter) frames with a 0-255 scale.
    /// The API converts this to the unified 0-100 scale for consistency.
    /// POPM frames also include email and play counter fields.
    TagKey.rating: TagSemantics(
      minValue: 0,
      maxValue: 100,
      multiValued: false,
    ),

    /// Date recorded field: Uses separate TYER/TDAT/TIME frames in ID3v2.3.
    ///
    /// Unlike ID3v2.4 which uses TDRC, ID3v2.3 requires separate frames
    /// for year, date, and time components. The API handles this conversion.
    TagKey.dateRecorded: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v23TextEncodings,
    ),

    /// Artwork field: Full artwork support through APIC frames.
    ///
    /// ID3v2.3 APIC frames support multiple artwork types (front cover,
    /// back cover, artist photo, etc.) with MIME type and description.
    /// Supports lazy loading for memory efficiency.
    TagKey.artwork: TagSemantics(
      multiValued: true, // Multiple artwork images supported
    ),

    /// Custom field: Supports custom/non-standard metadata.
    ///
    /// ID3v2.3 allows custom frames and user-defined text frames (TXXX)
    /// for application-specific metadata not covered by standard frames.
    TagKey.custom: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v23TextEncodings,
    ),
  },
);
