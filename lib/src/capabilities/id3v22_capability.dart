/// ID3v2.2 metadata format capability definition.
///
/// This file defines the capabilities and constraints of the ID3v2.2 metadata
/// format, including supported fields, encoding limitations, and value ranges.
///
/// ID3v2.2 is the earliest version of the ID3v2 specification and has more
/// limited capabilities compared to later versions. It uses 3-character frame
/// IDs and has restricted encoding support, but provides the foundation for
/// variable-length metadata fields that improved upon ID3v1.
library;

import '../core/container_kind.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';
import '../core/tag_semantics.dart';
import '../core/text_encoding.dart';

/// Encoding set for ID3v2.2 text fields with limited support.
///
/// ID3v2.2 primarily supports ISO-8859-1 encoding with limited Unicode support.
/// This is more restrictive than later versions which added UTF-16 and UTF-8.
///
/// Corresponds to:
/// - [TextEncoding.iso88591]: ISO-8859-1 (Latin-1) - primary encoding
const Set<String> _id3v22TextEncodings = {
  TextEncoding.iso88591Name,
};

/// Capability definition for ID3v2.2 metadata format.
///
/// ID3v2.2 provides basic metadata support with the following characteristics:
/// - Variable-length text fields (improvement over ID3v1's fixed lengths)
/// - Limited encoding support: primarily ISO-8859-1
/// - 3-character frame IDs (TT2, TP1, TAL, etc.)
/// - Basic artwork support through PIC frames (not APIC like later versions)
/// - No extended header support
/// - Limited field set compared to later versions
///
/// Key limitations compared to later versions:
/// - No UTF-8 or UTF-16 encoding support
/// - 3-character frame IDs instead of 4-character
/// - Missing some fields (rating, lyrics, disc number, etc.)
/// - PIC frames instead of APIC for artwork
/// - No extended header or advanced features
///
/// Frame mappings:
/// - TT2: Title
/// - TP1: Artist
/// - TAL: Album
/// - TP2: Album Artist
/// - TCO: Genre
/// - COM: Comment
/// - TT1: Grouping
/// - TCM: Composer
/// - TSS: Encoder
/// - TRK: Track Number
/// - TYE: Year
/// - TBP: BPM
/// - PIC: Artwork (different from APIC in later versions)
/// - TXX: Custom text
const TagCapability id3v22Capability = TagCapability(
  containerKind: ContainerKind.id3v2,
  containerVersion: '2.2',
  semanticsByKey: {
    /// Title field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TT2 frame. Limited to ISO-8859-1 encoding which restricts
    /// international character support compared to later versions.
    TagKey.title: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Artist field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TP1 frame. For multiple artists, use delimiters within
    /// the single field or use album artist field.
    TagKey.artist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Album field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TAL frame. No practical length limit beyond frame size
    /// constraints, which is an improvement over ID3v1's 30-character limit.
    TagKey.album: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Album artist field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TP2 frame. Used for compilation albums or when the album
    /// artist differs from the track artist.
    TagKey.albumArtist: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Genre field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TCO frame. Supports both text genres and numeric ID3v1
    /// genre codes in parentheses (e.g., "(17)" for Rock or "Rock").
    /// Multiple genres can be separated by delimiters.
    TagKey.genre: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Comment field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in COM frame. Unlike ID3v1, there are no length restrictions
    /// and the comment doesn't overlap with track number storage.
    TagKey.comment: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Grouping field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TT1 frame. Used for grouping related tracks together
    /// (e.g., "Classical", "Soundtrack").
    TagKey.grouping: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Composer field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TCM frame. Particularly important for classical music
    /// and instrumental tracks.
    TagKey.composer: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Encoder field: Variable length, single value, ISO-8859-1 encoding.
    ///
    /// Stored in TSS frame. Records the software/hardware used to encode
    /// the audio file.
    TagKey.encoder: TagSemantics(
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Track number field: Stored as text in TRK frame.
    ///
    /// Can be stored as just the track number ("5") or with total tracks ("5/12").
    /// Validated to ensure positive integer values.
    TagKey.trackNumber: TagSemantics(
      minValue: 1,
      maxValue: 999, // Practical limit for track numbers
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Year field: 4-digit year stored in TYE frame.
    ///
    /// ID3v2.2 uses a simple year field without the complex date handling
    /// of later versions.
    TagKey.year: TagSemantics(
      minValue: 1000,
      maxValue: 3000,
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// BPM field: Beats per minute stored as text in TBP frame.
    ///
    /// Stored as a text representation of the BPM value.
    /// Validated to ensure reasonable BPM ranges.
    TagKey.bpm: TagSemantics(
      minValue: 1,
      maxValue: 999,
      multiValued: false,
      allowedEncodings: _id3v22TextEncodings,
    ),

    /// Artwork field: Basic artwork support through PIC frames.
    ///
    /// ID3v2.2 uses PIC frames instead of the APIC frames used in later
    /// versions. This provides basic image attachment capabilities but
    /// with a simpler structure than later versions.
    TagKey.artwork: TagSemantics(
      multiValued: true, // Multiple artwork images supported
    ),

    /// Custom field: Supports custom/non-standard metadata.
    ///
    /// ID3v2.2 allows custom text frames (TXX) for application-specific
    /// metadata not covered by standard frames.
    TagKey.custom: TagSemantics(
      multiValued: true,
      allowedEncodings: _id3v22TextEncodings,
    ),

    // Note: Fields not supported in ID3v2.2:
    // - discNumber: TPOS/TPA not standardized in v2.2
    // - musicalKey: TKEY not available in v2.2
    // - rating: POPM not available in v2.2
    // - lyrics: USLT not available in v2.2
    // - isrc: TSRC not available in v2.2
    // - dateRecorded: Only simple year field available
  },
);
