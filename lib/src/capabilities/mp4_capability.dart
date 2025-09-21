/// MP4 metadata format capability definition.
///
/// This file defines the capabilities and constraints of the MP4 metadata
/// format, which uses iTunes-style atoms within the ilst container for
/// metadata storage in MP4, M4A, M4V, and similar container formats.
///
/// MP4 metadata provides comprehensive support through a hierarchical atom
/// structure with both standardized iTunes-compatible atoms and extensible
/// freeform atoms for custom metadata.

import '../core/container_kind.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';
import '../core/tag_semantics.dart';
import '../core/text_encoding.dart';

/// Encoding set for MP4 text atoms with UTF-8 support.
///
/// MP4 containers exclusively use UTF-8 encoding for text-based atoms,
/// providing full Unicode support with consistent character handling
/// across all iTunes-compatible applications and players.
///
/// This simplifies text processing compared to ID3v2 formats and ensures
/// reliable international character support in all MP4-based audio files.
///
/// Uses [TextEncoding.utf8Name] constant to ensure consistency with the
/// TextEncoding enum definition.
const Set<String> _mp4TextEncodings = {
  TextEncoding.utf8Name,
};

/// Capability definition for MP4 metadata format.
///
/// MP4 metadata provides comprehensive support with the following characteristics:
/// - UTF-8 encoding for all text atoms (full Unicode support)
/// - Hierarchical atom structure (moov.udta.meta.ilst)
/// - iTunes-compatible standard atoms (©nam, ©ART, trkn, disk, etc.)
/// - Freeform atoms for custom metadata (----:domain:name format)
/// - Type-aware data storage (text, integers, binary data)
/// - Multiple artwork support through covr atoms with type classification
/// - No arbitrary length limits on text fields
/// - Efficient binary storage with atom size headers
///
/// Key advantages over other formats:
/// - Rich type system supporting different data types natively
/// - Wide compatibility with iTunes, QuickTime, and media players
/// - Extensible through freeform atoms with domain namespacing
/// - Efficient binary representation with clear atom boundaries
/// - Consistent UTF-8 encoding without complexity of multiple options
///
/// Standard atom mappings (iTunes-compatible):
/// - ©nam: Title
/// - ©ART: Artist
/// - ©alb: Album
/// - aART: Album Artist
/// - ©gen: Genre (semicolon-separated for multiple values)
/// - ©cmt: Comment
/// - ©grp: Grouping
/// - ©wrt: Composer
/// - ©too: Encoder
/// - ----:com.apple.iTunes:ISRC: ISRC (freeform)
/// - ----:com.apple.iTunes:initialkey: Musical Key (freeform)
/// - ©lyr: Lyrics
/// - trkn: Track Number (binary: track/total as 16-bit integers)
/// - disk: Disc Number (binary: disc/total as 16-bit integers)
/// - ©day: Year (text representation)
/// - tmpo: BPM (16-bit integer)
/// - rtng: Rating (8-bit integer, 0-100 scale)
/// - covr: Artwork (binary data with MIME type classification)
/// - Freeform atoms: Custom fields (----:domain:name format)
const TagCapability mp4Capability = TagCapability(
  containerKind: ContainerKind.mp4,
  containerVersion: '',
  semanticsByKey: {
    /// Title field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©nam atom. No length restrictions, full Unicode support.
    /// iTunes and compatible players display this as the primary track title.
    TagKey.title: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Artist field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©ART atom. For multiple artists, use semicolon separation
    /// or rely on album artist field for compilation albums.
    TagKey.artist: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Album field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©alb atom. No length restrictions, supports full album
    /// titles in any language with complete Unicode support.
    TagKey.album: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Album artist field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in aART atom. Used for compilation albums or when the album
    /// artist differs from individual track artists. iTunes uses this for
    /// proper album grouping in library views.
    TagKey.albumArtist: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Genre field: Variable length, supports multiple values via semicolon separation.
    ///
    /// Stored in ©gen atom. Multiple genres are typically separated by
    /// semicolons (e.g., "Rock;Alternative;Indie") following iTunes conventions.
    /// Some applications may use other delimiters, but semicolon is standard.
    TagKey.genre: TagSemantics(
      multiValued: false, // Single atom with delimited content
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Comment field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©cmt atom. Unlike ID3v1, there are no length restrictions
    /// and full Unicode is supported for international comments.
    TagKey.comment: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Grouping field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©grp atom. Used for organizing tracks into logical
    /// groups or categories within iTunes and compatible applications.
    TagKey.grouping: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Composer field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©wrt atom. Important for classical music and instrumental
    /// tracks where composer differs from performer. iTunes displays this
    /// in detailed track information.
    TagKey.composer: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Encoder field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©too atom. Records the software/hardware used to encode
    /// the audio file. iTunes and other applications may display this
    /// in file information dialogs.
    TagKey.encoder: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// ISRC field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in freeform atom ----:com.apple.iTunes:ISRC. International
    /// Standard Recording Code for unique track identification. Uses iTunes
    /// freeform atom format for compatibility.
    TagKey.isrc: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Musical key field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in freeform atom ----:com.apple.iTunes:initialkey. Musical
    /// key of the track (e.g., "C", "Am", "F#m"). Uses iTunes freeform
    /// atom format as there's no standard atom for this field.
    TagKey.musicalKey: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Lyrics field: Variable length, single value, UTF-8 encoding.
    ///
    /// Stored in ©lyr atom. Supports full song lyrics with no length
    /// restrictions and complete Unicode support for international lyrics.
    /// iTunes displays this in the lyrics tab.
    TagKey.lyrics: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Track number field: Stored as binary data in trkn atom.
    ///
    /// MP4 uses a binary format with track number and total tracks as
    /// 16-bit big-endian integers. Format: [padding][track][total][padding]
    /// where each field is 2 bytes. Validated as positive integer.
    TagKey.trackNumber: TagSemantics(
      minValue: 1,
      maxValue: 65535, // 16-bit unsigned integer limit
      multiValued: false,
    ),

    /// Disc number field: Stored as binary data in disk atom.
    ///
    /// Similar to track number, uses binary format with disc number and
    /// total discs as 16-bit big-endian integers. Validated as positive integer.
    TagKey.discNumber: TagSemantics(
      minValue: 1,
      maxValue: 65535, // 16-bit unsigned integer limit
      multiValued: false,
    ),

    /// Year field: 4-digit year stored as text in ©day atom.
    ///
    /// MP4 typically stores the full date in ©day atom, but year can be
    /// extracted from date strings or stored as standalone year value.
    /// Text format allows flexible date representation.
    TagKey.year: TagSemantics(
      minValue: 1000,
      maxValue: 3000,
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// BPM field: Beats per minute stored as 16-bit integer in tmpo atom.
    ///
    /// MP4 stores BPM as binary integer data rather than text, providing
    /// more efficient storage and precise representation. Validated to
    /// ensure reasonable BPM ranges.
    TagKey.bpm: TagSemantics(
      minValue: 1,
      maxValue: 65535, // 16-bit unsigned integer limit
      multiValued: false,
    ),

    /// Rating field: 0-100 scale stored as 8-bit integer in rtng atom.
    ///
    /// MP4 uses the unified 0-100 scale directly in binary format,
    /// unlike ID3v2 which uses 0-255. Stored as single byte value
    /// for efficient representation.
    TagKey.rating: TagSemantics(
      minValue: 0,
      maxValue: 100,
      multiValued: false,
    ),

    /// Date recorded field: Uses ©day atom with flexible date format.
    ///
    /// MP4 ©day atom can store various date formats including ISO-8601,
    /// year-only, or other date representations. Text format provides
    /// flexibility for different date precision levels.
    TagKey.dateRecorded: TagSemantics(
      multiValued: false,
      allowedEncodings: _mp4TextEncodings,
    ),

    /// Artwork field: Full artwork support through covr atoms.
    ///
    /// MP4 covr atoms support multiple artwork images with automatic
    /// MIME type detection based on image format. Supports JPEG and PNG
    /// formats with efficient binary storage and lazy loading.
    TagKey.artwork: TagSemantics(
      multiValued: true, // Multiple covr atoms supported
    ),

    /// Custom field: Supports freeform atoms for custom metadata.
    ///
    /// MP4 allows custom metadata through freeform atoms using the format
    /// ----:domain:name where domain provides namespacing (e.g.,
    /// ----:com.apple.iTunes:CUSTOM_FIELD). This provides extensibility
    /// while maintaining compatibility with iTunes and other players.
    TagKey.custom: TagSemantics(
      multiValued: true,
      allowedEncodings: _mp4TextEncodings,
    ),
  },
);
