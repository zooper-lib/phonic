/// Enumeration of supported audio media file formats.
///
/// This enum identifies the different types of audio file formats that
/// the Phonic library can process. Each media kind determines which
/// container formats are applicable and how format detection is performed.
///
/// Media kinds are used for:
/// - File format detection and validation
/// - Determining applicable container strategies
/// - Selecting appropriate codecs for reading/writing
/// - Establishing precedence rules for multi-container formats
enum MediaKind {
  /// MPEG-1 Audio Layer III (MP3) files.
  ///
  /// MP3 is one of the most widely used audio formats, supporting multiple
  /// metadata container types. MP3 files can contain ID3v1, ID3v2, or both
  /// types of metadata containers simultaneously.
  ///
  /// Characteristics:
  /// - Lossy compression format
  /// - Supports multiple metadata containers (ID3v1, ID3v2.x)
  /// - Container precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
  /// - Fan-out strategy: Write to ID3v2.4 and optionally ID3v1 for compatibility
  ///
  /// File extensions: .mp3
  /// MIME types: audio/mpeg, audio/mp3
  ///
  /// Metadata containers:
  /// - ID3v2 (versions 2.2, 2.3, 2.4): Rich metadata at file beginning
  /// - ID3v1: Legacy 128-byte metadata at file end
  ///
  /// Detection methods:
  /// - ID3v2 header signature ("ID3" at file start)
  /// - MP3 frame sync patterns (0xFFE0 or 0xFFF0 masks)
  /// - File extension as fallback
  ///
  /// Common use cases:
  /// - Music distribution and streaming
  /// - Portable audio players
  /// - Legacy system compatibility
  mp3,

  /// Free Lossless Audio Codec (FLAC) files.
  ///
  /// FLAC is a lossless compression format that uses Vorbis Comments
  /// for metadata storage within structured metadata blocks. FLAC provides
  /// excellent compression while preserving perfect audio quality.
  ///
  /// Characteristics:
  /// - Lossless compression format
  /// - Uses Vorbis Comments exclusively for text metadata
  /// - Artwork stored in METADATA_BLOCK_PICTURE blocks
  /// - Supports multiple metadata blocks of the same type
  /// - Full Unicode support with UTF-8 encoding
  ///
  /// File extensions: .flac
  /// MIME types: audio/flac, audio/x-flac
  ///
  /// Metadata containers:
  /// - Vorbis Comments: Key-value pairs in VORBIS_COMMENT metadata block
  /// - METADATA_BLOCK_PICTURE: Binary artwork data with type information
  ///
  /// Detection methods:
  /// - FLAC signature ("fLaC" at file start)
  /// - Metadata block structure validation
  /// - File extension as fallback
  ///
  /// Advantages:
  /// - Perfect audio quality preservation
  /// - Efficient lossless compression
  /// - Rich metadata support with no length restrictions
  /// - Multi-valued field support
  /// - Embedded artwork with multiple images
  flac,

  /// OGG Vorbis audio files.
  ///
  /// OGG Vorbis is an open-source lossy compression format that stores
  /// metadata using Vorbis Comments within the OGG container structure.
  /// The format provides good compression efficiency and quality.
  ///
  /// Characteristics:
  /// - Lossy compression format (Vorbis codec)
  /// - Uses Vorbis Comments for all metadata
  /// - Artwork typically stored as base64-encoded METADATA_BLOCK_PICTURE
  /// - Streaming-friendly with page-based structure
  /// - Full Unicode support
  ///
  /// File extensions: .ogg, .oga
  /// MIME types: audio/ogg, application/ogg
  ///
  /// Metadata containers:
  /// - Vorbis Comments: Embedded in comment header packet
  /// - METADATA_BLOCK_PICTURE: Base64-encoded artwork (FLAC-style)
  ///
  /// Detection methods:
  /// - OGG signature ("OggS" page headers)
  /// - Vorbis codec identification in stream headers
  /// - File extension as fallback
  ///
  /// Advantages:
  /// - Open-source and patent-free
  /// - Good compression efficiency
  /// - Streaming support with seeking
  /// - Rich metadata capabilities
  /// - Multi-valued field support
  ogg,

  /// Opus audio files in OGG containers.
  ///
  /// Opus is a modern, open-source audio codec designed for internet
  /// transmission. It provides excellent quality at low bitrates and
  /// uses Vorbis Comments for metadata storage.
  ///
  /// Characteristics:
  /// - Modern lossy compression format optimized for speech and music
  /// - Uses Vorbis Comments for metadata (same as OGG Vorbis)
  /// - Excellent quality at low bitrates (6-510 kbps)
  /// - Low latency suitable for real-time applications
  /// - Full Unicode support
  ///
  /// File extensions: .opus
  /// MIME types: audio/opus
  ///
  /// Metadata containers:
  /// - Vorbis Comments: Embedded in OpusHead/OpusTags packets
  /// - METADATA_BLOCK_PICTURE: Base64-encoded artwork (FLAC-style)
  ///
  /// Detection methods:
  /// - OGG signature with Opus codec identification
  /// - OpusHead packet in stream headers
  /// - File extension as fallback
  ///
  /// Advantages:
  /// - Superior quality at low bitrates
  /// - Low latency for real-time use
  /// - Open-source and royalty-free
  /// - Adaptive bitrate capabilities
  /// - Rich metadata support
  opus,

  /// MPEG-4 Audio (M4A) files.
  ///
  /// M4A files use the MP4 container format with AAC audio compression.
  /// They store metadata in iTunes-style atoms within the hierarchical
  /// MP4 structure, providing rich metadata capabilities.
  ///
  /// Characteristics:
  /// - Lossy compression format (typically AAC codec)
  /// - Uses MP4 atoms for metadata storage
  /// - iTunes-compatible metadata structure
  /// - Supports both standard and freeform atoms
  /// - Type-aware data storage with efficient binary encoding
  ///
  /// File extensions: .m4a, .aac
  /// MIME types: audio/mp4, audio/m4a, audio/aac
  ///
  /// Metadata containers:
  /// - MP4 atoms: Hierarchical structure (moov.udta.meta.ilst)
  /// - Standard atoms: iTunes-compatible fields (©nam, ©ART, etc.)
  /// - Freeform atoms: Custom fields with domain namespacing
  ///
  /// Detection methods:
  /// - MP4 file type box (ftyp) with M4A brand
  /// - Compatible brands indicating audio-only content
  /// - File extension as fallback
  ///
  /// Advantages:
  /// - Excellent compression efficiency
  /// - Rich metadata with type safety
  /// - Wide software compatibility
  /// - Embedded artwork support
  /// - Extensible through freeform atoms
  m4a,

  /// MPEG-4 Video (MP4) files with audio tracks.
  ///
  /// MP4 files are multimedia containers that can contain both audio and
  /// video streams. When processing MP4 files, the library focuses on
  /// audio track metadata while ignoring video-specific information.
  ///
  /// Characteristics:
  /// - Multimedia container format (audio + video)
  /// - Uses same MP4 atom structure as M4A for metadata
  /// - May contain multiple audio tracks
  /// - Video-specific metadata is ignored by this library
  /// - Same metadata capabilities as M4A format
  ///
  /// File extensions: .mp4, .m4v
  /// MIME types: video/mp4, audio/mp4
  ///
  /// Metadata containers:
  /// - MP4 atoms: Same structure as M4A files
  /// - Focus on audio track metadata only
  /// - Video track metadata is not processed
  ///
  /// Detection methods:
  /// - MP4 file type box (ftyp) with MP4 brands
  /// - Compatible brands indicating video content
  /// - Presence of both audio and video tracks
  /// - File extension as fallback
  ///
  /// Processing notes:
  /// - Only audio-related metadata is extracted/modified
  /// - Video streams and video-specific atoms are preserved but ignored
  /// - File structure modifications must preserve video data integrity
  /// - Moov atom positioning affects video playback compatibility
  mp4,
}
