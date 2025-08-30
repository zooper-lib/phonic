/// Enumeration of supported audio metadata container formats.
///
/// This enum identifies the different types of metadata containers that
/// the Phonic library can read from and write to. Each container type
/// has its own characteristics, capabilities, and limitations that affect
/// how metadata is stored and retrieved.
///
/// Container types are used for:
/// - Format detection and codec selection
/// - Precedence determination during tag merging
/// - Capability validation before writing
/// - Provenance tracking for tag sources
enum ContainerKind {
  /// No container or unknown container type.
  ///
  /// This value is used as a default when no specific container has been
  /// identified, or for tags that don't originate from a file container
  /// (e.g., user-provided defaults, inferred values).
  ///
  /// Characteristics:
  /// - No format-specific constraints
  /// - Lowest precedence in merge operations
  /// - Cannot be written to (used for provenance only)
  /// - Serves as a null object pattern for provenance tracking
  none,

  /// ID3v2 metadata containers (versions 2.2, 2.3, 2.4).
  ///
  /// ID3v2 is the most common metadata format for MP3 files, supporting
  /// rich metadata including artwork, lyrics, and custom fields. Different
  /// versions have varying capabilities and encoding support.
  ///
  /// Characteristics:
  /// - Supports all unified tag fields
  /// - Variable-length text fields with encoding options
  /// - Embedded artwork support with multiple image types
  /// - Frame-based structure with extensibility
  /// - Version-specific features (UTF-8 in v2.4, date handling differences)
  ///
  /// Common locations:
  /// - Beginning of MP3 files (most common)
  /// - Can appear at end of file (less common)
  /// - May coexist with ID3v1 tags
  ///
  /// Supported versions:
  /// - ID3v2.2: 3-character frame IDs, limited encoding
  /// - ID3v2.3: 4-character frame IDs, UTF-16 support
  /// - ID3v2.4: Enhanced date fields, UTF-8 support, improved structure
  id3v2,

  /// ID3v1 metadata containers (original and extended versions).
  ///
  /// ID3v1 is a legacy metadata format with a fixed 128-byte structure
  /// located at the end of MP3 files. Despite its limitations, it remains
  /// widely supported for compatibility reasons.
  ///
  /// Characteristics:
  /// - Fixed-length fields with strict character limits
  /// - 30-character limit for most text fields
  /// - Single-byte genre codes (0-255 standard genres)
  /// - Track number shares space with comment field (28 chars when present)
  /// - No support for artwork, lyrics, or extended metadata
  /// - Latin-1 encoding only
  ///
  /// Limitations:
  /// - Cannot store multi-valued fields
  /// - No support for custom fields
  /// - Limited character set and field lengths
  /// - No Unicode support
  ///
  /// Usage:
  /// - Often used alongside ID3v2 for maximum compatibility
  /// - Fallback option for simple players
  /// - May be the only metadata in older MP3 files
  id3v1,

  /// Vorbis Comment metadata containers.
  ///
  /// Vorbis Comments are used in various audio formats including FLAC,
  /// OGG Vorbis, and Opus. They provide a flexible key-value structure
  /// with full Unicode support and multi-valued field capabilities.
  ///
  /// Characteristics:
  /// - Key-value pair structure with UTF-8 encoding
  /// - Case-insensitive field names by convention
  /// - Multi-valued fields supported (multiple entries with same key)
  /// - No length limits on individual fields
  /// - Artwork stored as separate metadata blocks (FLAC) or base64 (OGG)
  /// - Extensible with custom field names
  ///
  /// Format variations:
  /// - FLAC: Stored in VORBIS_COMMENT metadata block
  /// - OGG Vorbis: Embedded in comment header packet
  /// - Opus: Similar to OGG Vorbis structure
  ///
  /// Advantages:
  /// - Full Unicode support
  /// - No arbitrary length restrictions
  /// - Clean key-value semantics
  /// - Multi-valued field support
  vorbis,

  /// MP4 metadata atom containers (iTunes-style and freeform).
  ///
  /// MP4 containers (including M4A, M4V) use a hierarchical atom structure
  /// for metadata storage. The iTunes-style metadata atoms provide
  /// standardized fields, while freeform atoms allow custom metadata.
  ///
  /// Characteristics:
  /// - Hierarchical atom structure (moov.udta.meta.ilst)
  /// - Type-aware data storage (text, integers, binary)
  /// - iTunes-compatible standard atoms (©nam, ©ART, etc.)
  /// - Freeform atoms for custom fields (----:domain:name format)
  /// - Embedded artwork with type classification
  /// - UTF-8 text encoding
  ///
  /// Atom types:
  /// - Standard atoms: Predefined iTunes-compatible fields
  /// - Freeform atoms: Custom fields with domain namespacing
  /// - Data atoms: Contain the actual metadata values with type information
  ///
  /// Advantages:
  /// - Rich type system for different data types
  /// - Efficient binary storage
  /// - Extensible through freeform atoms
  /// - Wide compatibility with iTunes and similar software
  mp4,
}
