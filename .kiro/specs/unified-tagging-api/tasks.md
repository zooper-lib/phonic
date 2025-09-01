# Implementation Plan

- [x] 1. Create TagKey enum

  - Define TagKey enum with all unified field types (title, artist, album, etc.)
  - Add comprehensive Dart documentation for each enum value
  - _Requirements: 3.1_

- [x] 2. Create TagConfidence enum

  - Define TagConfidence enum with certain, inferred, derived values
  - Add Dart documentation explaining each confidence level
  - _Requirements: 4.3_

- [x] 3. Create ContainerKind enum

  - Define ContainerKind enum with none, id3v2, id3v1, vorbis, mp4 values
  - Add documentation for each container type
  - _Requirements: 4.1_

- [x] 4. Implement TagProvenance class

  - Create TagProvenance class with containerKind, containerVersion, confidence fields
  - Implement const constructors including TagProvenance.none()
  - Add Equatable implementation for proper equality comparison
  - Write unit tests for TagProvenance equality and construction
  - _Requirements: 4.1, 4.3_

- [x] 5. Create base MetadataTag sealed class

  - Define sealed MetadataTag<T> class with value, key, provenance fields
  - Implement const constructor and Equatable mixin
  - Add abstract withProvenance method for immutable updates
  - Write unit tests for base MetadataTag functionality
  - _Requirements: 3.2, 4.1, 9.1_

- [x] 6. Implement TitleTag class

  - Create TitleTag extending MetadataTag<String>
  - Implement constructor with TagKey.title
  - Override withProvenance method
  - Write unit tests for TitleTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 7. Implement ArtistTag class

  - Create ArtistTag extending MetadataTag<String>
  - Implement constructor with TagKey.artist
  - Override withProvenance method
  - Write unit tests for ArtistTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 8. Implement AlbumTag class

  - Create AlbumTag extending MetadataTag<String>
  - Implement constructor with TagKey.album
  - Override withProvenance method
  - Write unit tests for AlbumTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 9. Implement AlbumArtistTag class

  - Create AlbumArtistTag extending MetadataTag<String>
  - Implement constructor with TagKey.albumArtist
  - Override withProvenance method
  - Write unit tests for AlbumArtistTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 10. Implement GenreTag class

  - Create GenreTag extending MetadataTag<List<String>>
  - Implement constructor with TagKey.genre accepting List<String> of genres
  - Add convenience constructor accepting single String genre
  - Add generic encoding method with configurable delimiter (`toEncodedString`)
  - Implement automatic delimiter detection with null-terminator priority
  - Override withProvenance method
  - Write comprehensive unit tests for all constructors and encoding methods
  - Test edge cases: empty strings, single genres, mixed delimiters, whitespace handling
  - _Requirements: 3.1, 9.1_

- [x] 10a. Update MetadataTag base class for GenreTag

  - Add GenreTag to the part files in metadata_tag.dart
  - Update documentation examples to include GenreTag usage with multi-delimiter support
  - Ensure type safety for List<String> generic parameter
  - _Requirements: 3.1, 9.1_

- [x] 10b. Create comprehensive GenreTag format tests

  - Test ID3v2.4 null-terminated parsing and encoding (`Rock\0Alternative\0Indie`)
  - Test ID3v2.3 slash-separated parsing and encoding (`Rock/Alternative/Indie`)
  - Test parsing with semicolon delimiters (MP4/other formats)
  - Test parsing with pipe delimiters (some legacy systems)
  - Test parsing with comma delimiters (human-readable format)
  - Test parsing with backslash delimiters (some legacy systems)
  - Test automatic format detection priority (null-terminators first)
  - Test mixed delimiter scenarios and edge cases
  - Test round-trip parsing and encoding consistency for all ID3v2 versions
  - Test compatibility with existing files from different tagging software
  - _Requirements: 3.1, 9.1_

- [x] 11. Implement CommentTag class

  - Create CommentTag extending MetadataTag<String>
  - Implement constructor with TagKey.comment
  - Override withProvenance method
  - Write unit tests for CommentTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 12. Implement GroupingTag class

  - Create GroupingTag extending MetadataTag<String>
  - Implement constructor with TagKey.grouping
  - Override withProvenance method
  - Write unit tests for GroupingTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 13. Implement ComposerTag class

  - Create ComposerTag extending MetadataTag<String>
  - Implement constructor with TagKey.composer
  - Override withProvenance method
  - Write unit tests for ComposerTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 14. Implement EncoderTag class

  - Create EncoderTag extending MetadataTag<String>
  - Implement constructor with TagKey.encoder
  - Override withProvenance method
  - Write unit tests for EncoderTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 15. Implement IsrcTag class

  - Create IsrcTag extending MetadataTag<String>
  - Implement constructor with TagKey.isrc
  - Override withProvenance method
  - Write unit tests for IsrcTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 16. Implement MusicalKeyTag class

  - Create MusicalKeyTag extending MetadataTag<String>
  - Implement constructor with TagKey.musicalKey
  - Override withProvenance method
  - Write unit tests for MusicalKeyTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 17. Implement LyricsTag class

  - Create LyricsTag extending MetadataTag<String>
  - Implement constructor with TagKey.lyrics
  - Override withProvenance method
  - Write unit tests for LyricsTag creation and equality
  - _Requirements: 3.1, 9.1_

- [x] 18. Implement TrackNumberTag class

  - Create TrackNumberTag extending MetadataTag<int>
  - Implement constructor with TagKey.trackNumber and validation (> 0)
  - Override withProvenance method
  - Write unit tests including validation edge cases
  - _Requirements: 3.1, 9.1_

- [x] 19. Implement DiscNumberTag class

  - Create DiscNumberTag extending MetadataTag<int>
  - Implement constructor with TagKey.discNumber and validation (> 0)
  - Override withProvenance method
  - Write unit tests including validation edge cases
  - _Requirements: 3.1, 9.1_

- [x] 20. Implement YearTag class

  - Create YearTag extending MetadataTag<int>
  - Implement constructor with TagKey.year and validation (reasonable year range)
  - Override withProvenance method
  - Write unit tests including validation edge cases
  - _Requirements: 3.1, 9.1_

- [x] 21. Implement BpmTag class

  - Create BpmTag extending MetadataTag<int>

  - Implement constructor with TagKey.bpm and validation (> 0, < 1000)
  - Override withProvenance method
  - Write unit tests including validation edge cases
  - _Requirements: 3.1, 9.1_

- [x] 22. Implement RatingTag class

  - Create RatingTag extending MetadataTag<int>
  - Implement constructor with Tag
    Key.rating and validation (0-100 range)
  - Override withProvenance method
  - Write unit tests including boundary validation
  - _Requirements: 3.1, 3.3, 9.1_

- [x] 23. Implement DateRecordedTag class

  - Create DateRecordedTag extending MetadataTag<String>

  - Implement constructor with TagKey.dateRecorded and ISO-8601 validation
  - Override withProvenance method
  - Write unit tests for date format validation
  - _Requirements: 3.1, 3.2, 9.1_

- [x] 24. Create ArtworkType enum

  - Define ArtworkType enum with all standard artwork typ
    es
  - Add comprehensive documentation for each artwork type
  - _Requirements: 3.4_

- [x] 25. Implement ArtworkData class

  - Create ArtworkData class with mimeType, type, description, and lazy data loader
  - Implement Equatable for proper comparison (excluding data loader)
  - Add comprehensive Dart documentation
  - _Requirements: 3.4, 7.1, 7.2_

- [x] 26. Create LazyArtworkLoader class

  - Implement LazyArtworkLoader with container bytes and offset/length
  - Add load() method that extracts artwork data on demand
  - Write unit tests for lazy loading behavior
  - _Requirements: 7.1, 7.2_

- [x] 27. Implement ArtworkTag class

  - Create ArtworkTag extending MetadataTag<ArtworkData>
  - Implement constructor with TagKey.artwork
  - Override withProvenance method
  - Write unit tests for ArtworkTag creation and lazy loading
  - _Requirements: 3.4, 7.1_

- [x] 28. Implement CustomTag class

  - Create CustomTag extending MetadataTag<String> for custom fields
  - Implement constructor with TagKey.custom
  - Override withProvenance method
  - Write unit tests for CustomTag functionality
  - _Requirements: 3.1, 9.1_

- [x] 29. Create TagSemantics class

  - Implement TagSemantics with multiValued, maxTextLength, minValue, maxValue fields
  - Add const constructor and comprehensive documentation
  - Write unit tests for TagSemantics creation
  - _Requirements: 5.1, 5.2_

- [x] 30. Create TagCapability class

  - Implement TagCapability with containerKind, containerVersion, semanticsByKey
  - Add supports() and semantics() methods
  - Write unit tests for capability lookup functionality
  - _Requirements: 5.1, 5.2_

- [x] 31. Define ID3v1 capability constants

  - Create id3v1Capability constant with supported fields and length limits
  - Include 30-character limits for text fields and 28 for comment with track
  - Write unit tests verifying capability definitions
  - _Requirements: 5.4, 10.1_

- [x] 32. Define ID3v2.3 capability constants

  - Create id3v23Capability constant with all supported ID3v2.3 fields
  - Include rating range 0-255 and BPM constraints
  - Write unit tests verifying capability definitions
  - _Requirements: 5.1, 10.1_

- [x] 33. Define ID3v2.4 capability constants

  - Create id3v24Capability constant extending v2.3 with TDRC support
  - Include UTF-8 encoding support differences from v2.3
  - Write unit tests verifying capability definitions

  - _Requirements: 5.1, 10.1_

- [x] 34. Define Vorbis capability constants

  - Create vorbisCapability constant with all Vorbis comment fields
  - Include multi-valued field support and UTF-8 encoding
  - Write unit tests verifying capability definitions
  - _Requirements: 5.1, 10.2, 10.3_

- [x] 35. Define MP4 capability constants

  - Create mp4Capability constant with iTunes-style atom support
  - Include freeform atom support and artwork handling
  - Write unit tests verifying capability definitions
  - _Requirements: 5.1, 10.6_

- [x] 36. Create PhonicException base class

  - Implement PhonicException with message and context fields
  - Add comprehensive Dart documentation with usage examples
  - Write unit tests for exception creation and string representation
  - _Requirements: 8.1, 8.2_

- [x] 37. Implement UnsupportedFormatException

  - Create UnsupportedFormatException extending PhonicException
  - Add specific constructor and documentation
  - Write unit tests for exception creation and inheritance
  - _Requirements: 8.1_

- [x] 38. Implement CorruptedContainerException

  - Create CorruptedContainerException with byteOffset field
  - Add specific constructor and documentation
  - Write unit tests for exception creation with offset tracking
  - _Requirements: 8.1, 8.2_

- [x] 39. Implement TagValidationException

  - Create TagValidationException with tagKey and reason fields
  - Add specific constructor and documentation
  - Write unit tests for validation exception scenarios
  - _Requirements: 5.1, 8.1_

- [x] 40. Create Id3v2FrameMap class

  - Implement static maps for v2.2, v2.3, v2.4 frame ID mappings
  - Include all standard frame types (TIT2, TPE1, TALB, etc.)
  - Write unit tests verifying mapping completeness
  - _Requirements: 10.1_

- [x] 41. Create VorbisCommentMap class

  - Implement static map for Vorbis comment field name mappings
  - Include standard field names (TITLE, ARTIST, ALBUM, etc.)
  - Write unit tests verifying mapping completeness
  - _Requirements: 10.2, 10.3_

- [x] 42. Create Mp4AtomMap class

  - Implement static map for MP4 atom mappings (©nam, ©ART, etc.)
  - Include freeform atom patterns and artwork handling
  - Write unit tests verifying mapping completeness
  - _Requirements: 10.6_

- [x] 43. Create MediaKind enum

  - Define MediaKind enum with mp3, flac, ogg, opus, m4a, mp4 values
  - Add comprehensive documentation for each media type
  - _Requirements: 10.1, 10.2, 10.3, 10.6_

- [x] 44. Create FormatStrategy abstract class

  - Define FormatStrategy interface with mediaKind, precedence, fanout properties
  - Add canHandle and detectFormat abstract methods
  - Include comprehensive documentation and usage examples
  - _Requirements: 10.1, 10.2, 10.3, 10.6_

- [x] 45. Implement Mp3FormatStrategy class

  - Create Mp3FormatStrategy with ID3v2.4 > v2.3 > v2.2 > ID3v1 precedence
  - Implement canHandle method checking for ID3 headers or MP3 frame sync
  - Add fanout targeting ID3v2.4 and ID3v1
  - Write unit tests for MP3 format detection
  - _Requirements: 10.1, 10.4_

- [x] 46. Implement FlacFormatStrategy class

  - Create FlacFormatStrategy with Vorbis-only precedence and fanout
  - Implement canHandle method checking for FLAC signature
  - Write unit tests for FLAC format detection
  - _Requirements: 10.2_

- [x] 47. Implement OggFormatStrategy class

  - Create OggFormatStrategy with Vorbis-only precedence and fanout
  - Implement canHandle method checking for OGG signature
  - Write unit tests for OGG format detection
  - _Requirements: 10.3_

- [x] 48. Implement OpusFormatStrategy class

  - Create OpusFormatStrategy with Vorbis-only precedence and fanout
  - Implement canHandle method checking for Opus signature
  - Write unit tests for Opus format detection
  - _Requirements: 10.3_

- [x] 49. Implement Mp4FormatStrategy class

  - Create Mp4FormatStrategy with MP4 atom-only precedence and fanout
  - Implement canHandle method checking for MP4/M4A signatures
  - Write unit tests for MP4 format detection
  - _Requirements: 10.6_

- [x] 50. Create ByteReader utility class

  - Implement ByteReader for efficient binary data parsing
  - Add methods for reading integers, strings, and byte arrays
  - Include endianness handling and bounds checking
  - Write comprehensive unit tests for all read operations
  - _Requirements: 8.1, 8.2_

- [x] 51. Implement synchsafe integer utilities

  - Create synchsafe integer encoding and decoding functions
  - Add comprehensive documentation explaining synchsafe format
  - Write unit tests for synchsafe conversion edge cases
  - _Requirements: 8.1, 8.2_

- [x] 52. Create text encoding utilities

  - Implement UTF-8, UTF-16, and Latin-1 encoding detection
  - Add text conversion utilities between encodings
  - Include BOM handling for UTF-16
  - Write unit tests for encoding detection and conversion
  - _Requirements: 8.1, 8.2_

- [x] 52a. Create ID3v2 genre parsing utilities

  - Implement null-terminated string parsing for ID3v2.4 TCON frames

  - Implement slash-separated string parsing for ID3v2.3 TCON frames
  - Add generic delimiter detection algorithm for other formats
  - Support common delimiters: null, slash, semicolon, pipe, comma, backslash
  - Add delimiter frequency analysis with null-terminator priority
  - Handle edge cases: no delimiters, mixed delimiters, escaped delimiters
  - Create utility functions for consistent genre handling across ID3v2 versions
  - Write comprehensive unit tests for ID3v2-specific genre parsing
  - _Requirements: 3.1, 8.1, 10.1_

- [x] 53. Create ContainerLocator abstract class

  - Define ContainerLocator interface with containerKind property
  - Add abstract methods: fileMatches, extract, inject
  - Include comprehensive documentation and usage examples
  - _Requirements: 1.1, 1.2_

- [x] 54. Implement Id3v2Locator class

  - Create Id3v2Locator for detecting ID3v2 headers at file start
  - Implement fileMatches checking for "ID3" signature
  - Add extract method parsing header size and returning container bytes
  - Implement inject method placing ID3v2 at file beginning
  - Write unit tests with various ID3v2 header scenarios
  - _Requirements: 1.1, 1.2, 10.1_

- [x] 55. Implement Id3v1Locator class

  - Create Id3v1Locator for detecting 128-byte tags at file end
  - Implement fileMatches checking for "TAG" signature at offset -128
  - Add extract method returning fixed 128-byte tail
  - Implement inject method appending/replacing ID3v1 at file end
  - Write unit tests for ID3v1 detection and injection
  - _Requirements: 1.1, 1.2, 10.1_

- [x] 56. Implement VorbisLocator class for FLAC

  - Create VorbisLocator for FLAC Vorbis comment block detection
  - Implement fileMatches checking for FLAC signature
  - Add extract method finding and parsing Vorbis comment metadata block
  - Implement inject method replacing Vorbis comment block in FLAC structure
  - Write unit tests for FLAC Vorbis comment handling
  - _Requirements: 1.1, 1.2, 10.2_

- [x] 57. Implement OggVorbisLocator class

  - Create OggVorbisLocator for OGG Vorbis comment detection
  - Implement fileMatches checking for OGG signature

  - Add extract method parsing OGG pages to find comment header
  - Implement inject method rebuilding OGG stream with new comments
  - Write unit tests for OGG Vorbis comment handling
  - _Requirements: 1.1, 1.2, 10.3_

- [x] 58. Implement Mp4Locator class

  - Create Mp4Locator for MP4 ilst atom detection within moov
  - Implement fileMatches checking for MP4/M4A signatures
  - Add extract method navigating atom hierarchy to find ilst
  - Implement inject method replacing ilst atom in moov structure
  - Write unit tests for MP4 atom navigation and replacement
  - _Requirements: 1.1, 1.2, 10.6_

- [x] 59. Create TagCodec abstract class

  - Define TagCodec interface with containerKind, containerVersion, capability
  - Add abstract methods: readFromContainer, writeToContainer
  - Include comprehensive documentation and usage patterns
  - _Requirements: 1.1, 1.3, 2.1, 2.2_

- [x] 60. Create ID3v2 header parsing utilities

  - Implement ID3v2 header structure parsing (version, flags, size)
  - Add extended header parsing for v2.4
  - Include unsynchronization detection and handling
  - Write unit tests for various header configurations
  - _Requirements: 1.1, 8.1, 8.2_

- [x] 61. Create ID3v2 frame parsing utilities

  - Implement generic ID3v2 frame header parsing (ID, size, flags)
  - Add frame data extraction with encoding detection
  - Include frame flag handling (compression, encryption, grouping)
  - Write unit tests for frame parsing edge cases
  - _Requirements: 1.1, 8.1, 8.2_

- [x] 62. Implement ID3v2 text frame parsing

  - Create text frame parsing for TIT2, TPE1, TALB, etc.
  - Handle encoding byte and text extraction
  - Add null terminator handling for different encodings
  - Write unit tests for text frame parsing with various encodings
  - _Requirements: 1.1, 1.3, 3.2_

- [x] 63. Implement ID3v2 POPM frame parsing

  - Create POPM (rating) frame parsing with email and counter
  - Extract rating value and handle different email formats
  - Add rating scale conversion from 0-255 to 0-100
  - Write unit tests for POPM frame variations
  - _Requirements: 1.1, 1.3, 3.3_

- [x] 64. Implement ID3v2 APIC frame parsing

  - Create APIC (artwork) frame parsing with type and description
  - Extract MIME type, picture type, and image data
  - Implement lazy loading for image data
  - Write unit tests for APIC frame parsing
  - _Requirements: 1.1, 1.4, 7.1_

- [x] 65. Implement ID3v2 COMM frame parsing

  - Create COMM (comment) frame parsing with language and description
  - Handle encoding and extract comment text
  - Add language code processing
  - Write unit tests for COMM frame variations
  - _Requirements: 1.1, 1.3_

- [x] 66. Implement ID3v2 USLT frame parsing

  - Create USLT (lyrics) frame parsing with language and description
  - Handle encoding and extract lyrics text
  - Add language code processing
  - Write unit tests for USLT frame variations
  - _Requirements: 1.1, 1.3_

- [x] 67. Create Id3v24Codec class structure

  - Implement Id3v24Codec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 1.3, 10.1_

- [x] 68. Implement Id3v24Codec readFromContainer method

  - Create readFromContainer method parsing ID3v2.4 tags
  - Use header and frame parsing utilities
  - Convert frames to MetadataTag instances with provenance
  - Handle TDRC date field specific to v2.4
  - Handle TCON genre frame parsing with null-terminated strings for GenreTag
  - Parse multiple genres from single TCON frame using null delimiters
  - Write unit tests with real ID3v2.4 samples including multi-genre scenarios
  - _Requirements: 1.1, 1.3, 3.2, 4.1_

- [x] 69. Implement Id3v24Codec writeToContainer method

  - Create writeToContainer method building ID3v2.4 tags
  - Convert MetadataTag instances to appropriate frames
  - Handle UTF-8 encoding for v2.4
  - Handle GenreTag encoding to TCON frame with null-terminated strings
  - Encode multiple genres as single TCON frame with null delimiters
  - Build complete ID3v2.4 structure with header
  - Write unit tests for tag encoding with proper null-termination
  - _Requirements: 2.1, 2.2, 3.2_

- [x] 70. Create Id3v23Codec class structure

  - Implement Id3v23Codec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 1.3, 10.1_

- [x] 71. Implement Id3v23Codec readFromContainer method

  - Create readFromContainer method parsing ID3v2.3 tags
  - Handle TYER/TDAT/TIME frames for date instead of TDRC
  - Use UTF-16 encoding (no UTF-8 support in v2.3)
  - Handle TCON genre frame parsing with slash-separated strings for GenreTag
  - Parse multiple genres from single TCON frame using slash delimiters

  - Convert frames to MetadataTag instances with provenance
  - Write unit tests with real ID3v2.3 samples including multi-genre scenarios
  - _Requirements: 1.1, 1.3, 3.2, 4.1_

- [x] 72. Implement Id3v23Codec writeToContainer method

  - Create writeToContainer method building ID3v2.3 tags
  - Convert date fields to TYER/TDAT/TIME frames
  - Handle UTF-16 encoding requirements
  - Handle GenreTag encoding to TCON frame with slash-separated strings
  - Encode multiple genres as single TCON frame with slash delimiters
  - Build complete ID3v2.3 structure with header
  - Write unit tests for tag encoding with proper slash separation
  - _Requirements: 2.1, 2.2, 3.2_

- [x] 73. Create Id3v22Codec class structure

  - Implement Id3v22Codec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 1.3, 10.1_

- [x] 74. Implement Id3v22Codec readFromContainer method

  - Create readFromContainer method parsing ID3v2.2 tags
  - Handle 3-character frame IDs (TT2, TP1, TAL, etc.)
  - Use limited encoding support for v2.2
  - Convert frames to MetadataTag instances with provenance
  - Write unit tests with real ID3v2.2 samples
  - _Requirements: 1.1, 1.3, 4.1_

- [x] 75. Implement Id3v22Codec writeToContainer method

  - Create writeToContainer method building ID3v2.2 tags
  - Convert to 3-character frame IDs
  - Handle limited encoding options
  - Build complete ID3v2.2 structure with header
  - Write unit tests for tag encoding
  - _Requirements: 2.1, 2.2_

- [x] 76. Create ID3v1 genre lookup table

  - Implement standard ID3v1 genre table (0-255 values)
  - Add genre name to number conversion utilities
  - Include comprehensive genre list documentation
  - Write unit tests for genre lookup functionality
  - _Requirements: 1.1, 10.1_

- [x] 77. Create Id3v1Codec class structure

  - Implement Id3v1Codec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 5.4, 10.1_

- [x] 78. Implement Id3v1Codec readFromContainer method

  - Create readFromContainer method parsing 128-byte ID3v1 structure
  - Extract title, artist, album, year, comment fields at fixed offsets
  - Handle track number extraction from comment byte 29
  - Convert genre byte to genre name using lookup table
  - Write unit tests with various ID3v1 configurations
  - _Requirements: 1.1, 5.4, 10.1_

- [x] 79. Implement Id3v1Codec writeToContainer method

  - Create writeToContainer method building 128-byte ID3v1 structure
  - Apply 30-character truncation for text fields
  - Handle track number encoding in comment field
  - Convert genre name to genre byte
  - Write unit tests for constraint handling
  - _Requirements: 2.1, 2.2, 5.4_

- [x] 80. Create VorbisCommentsCodec class structure

  - Implement VorbisCommentsCodec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 10.2, 10.3_

- [x] 81. Implement Vorbis comment parsing utilities

  - Create utilities for parsing key=value comment pairs
  - Handle UTF-8 text decoding for all fields
  - Add case-insensitive key matching and standardization
  - Include multi-valued field support (multiple entries with same key)
  - Write unit tests for comment parsing variations
  - _Requirements: 1.1, 1.4, 3.1_

- [x] 82. Implement METADATA_BLOCK_PICTURE parsing

  - Create FLAC artwork parsing from METADATA_BLOCK_PICTURE blocks
  - Extract picture type, MIME type, description, and image data
  - Implement lazy loading for image data
  - Write unit tests for FLAC artwork handling
  - _Requirements: 1.4, 7.1, 10.2_

- [x] 83. Implement VorbisCommentsCodec readFromContainer method

  - Create readFromContainer method parsing Vorbis comments
  - Use comment parsing utilities and artwork handling
  - Convert comments to MetadataTag instances with provenance
  - Handle multiple GENRE fields for GenreTag creation
  - Handle mixed scenarios where some GENRE fields contain delimited values
  - Support both native multi-field and delimited single-field approaches
  - Handle both FLAC and OGG comment formats
  - Write unit tests with real Vorbis comment samples including delimiter variations
  - _Requirements: 1.1, 1.4, 3.1, 4.1_

- [x] 84. Implement VorbisCommentsCodec writeToContainer method

  - Create writeToContainer method building Vorbis comment structure
  - Convert MetadataTag instances to key=value pairs
  - Handle GenreTag encoding to multiple GENRE fields
  - Handle artwork encoding to METADATA_BLOCK_PICTURE
  - Build complete comment block with vendor string
  - Write unit tests for comment encoding
  - _Requirements: 2.1, 2.2, 1.4_

- [x] 85. Create MP4 atom parsing utilities

  - Implement MP4 atom header parsing (size, type)
  - Add atom navigation utilities for hierarchical structure
  - Include atom data extraction with type-specific handling
  - Write unit tests for atom parsing functionality
  - _Requirements: 1.1, 8.1, 10.6_

- [x] 86. Create Mp4AtomsCodec class structure

  - Implement Mp4AtomsCodec class implementing TagCodec interface
  - Add containerKind, containerVersion, and capability properties
  - Create constructor and basic class structure
  - Write unit tests for codec instantiation
  - _Requirements: 1.1, 10.6_

- [x] 87. Implement MP4 standard atom parsing

  - Create parsing for standard atoms (©nam, ©ART, trkn, disk)
  - Handle different data types (text, integers, binary)
  - Add covr atom parsing for artwork with type detection
  - Write unit tests for standard atom parsing
  - _Requirements: 1.1, 1.4, 10.6_

- [x] 88. Implement MP4 freeform atom parsing

  - Create parsing for freeform atoms (----:domain:name format)
  - Handle domain and name extraction
  - Add data type detection and conversion
  - Write unit tests for freeform atom parsing
  - _Requirements: 1.1, 10.6_

- [x] 89. Implement Mp4AtomsCodec readFromContainer method

  - Create readFromContainer method parsing MP4 ilst atoms
  - Use atom parsing utilities for standard and freeform atoms
  - Convert atoms to MetadataTag instances with provenance
  - Handle artwork lazy loading
  - Write unit tests with real MP4 samples
  - _Requirements: 1.1, 1.4, 4.1, 7.1_

- [x] 90. Implement Mp4AtomsCodec writeToContainer method

  - Create writeToContainer method building MP4 ilst structure
  - Convert MetadataTag instances to appropriate atoms
  - Handle freeform atom encoding for custom fields
  - Build complete ilst atom with proper hierarchy
  - Write unit tests for atom encoding
  - _Requirements: 2.1, 2.2, 1.4_

- [x] 91. Create CodecRegistry class structure

  - Implement CodecRegistry class managing codec and locator collections
  - Add codecList and containerLocatorList properties
  - Create constructor accepting codec and locator lists
  - Write unit tests for registry instantiation
  - _Requirements: 1.1, 1.2_

- [x] 92. Implement CodecRegistry lookup methods

  - Add findCodec method for lookup by container kind and version
  - Implement findLocator method for lookup by container kind
  - Handle null returns when codecs/locators not found
  - Write unit tests for lookup functionality
  - _Requirements: 1.1, 1.2_

- [x] 93. Create tag merging utilities

  - Implement utilities for merging tags from multiple containers
  - Add precedence-based conflict resolution for single-valued tags
  - Create multi-valued tag union logic with deduplication
  - Handle GenreTag merging by combining genre lists and deduplicating
  - Include provenance preservation during merge operations
  - Write unit tests for merge scenarios including GenreTag merging
  - _Requirements: 1.2, 1.3, 4.1, 4.2_

- [x] 94. Implement tag inference system

  - Create logic for inferring missing tags from available data
  - Add albumArtist inference from artist when missing
  - Implement date field derivation (year from dateRecorded)
  - Mark inferred tags with appropriate confidence level
  - Write unit tests for inference scenarios
  - _Requirements: 4.2, 4.3_

- [x] 95. Create rating normalization utilities

  - Implement rating scale conversion between 0-255 and 0-100
  - Add container-specific rating scaling logic
  - Handle rating conversion for different container capabilities
  - Write unit tests for rating normalization
  - _Requirements: 1.3, 3.3, 5.1_

- [x] 96. Implement date normalization utilities

  - Create date format normalization to ISO-8601 internally
  - Handle conversion from TYER/TDAT/TIME to TDRC format
  - Add date parsing and validation utilities
  - Write unit tests for date normalization scenarios
  - _Requirements: 1.3, 3.2, 5.1_

- [x] 97. Create text normalization utilities

  - Implement text encoding normalization and trimming
  - Add constraint-based truncation for length limits
  - Handle case normalization for Vorbis comment keys
  - Write unit tests for text normalization
  - _Requirements: 1.3, 5.1, 5.2_

- [x] 98. Implement numeric value normalization

  - Create value range clamping for numeric fields
  - Add validation for track numbers, disc numbers, BPM
  - Handle numeric constraint enforcement
  - Write unit tests for numeric normalization
  - _Requirements: 5.1, 5.2_

- [x] 99. Create MergePolicy class

  - Implement MergePolicy class with precedence and normalization logic
  - Add precedenceFor method returning container precedence order
  - Implement writeFanout method for target container selection
  - Add normalizeForTarget method for container-specific normalization
  - Write unit tests for merge policy functionality
  - _Requirements: 1.2, 1.3, 5.1, 10.1, 10.2, 10.3, 10.6_

- [x] 100. Implement isMultiValued utility

  - Create isMultiValued method checking if TagKey supports multiple values
  - Handle artwork, genre, and other multi-valued field detection
  - Add logic to distinguish between internally multi-valued (GenreTag) and container multi-valued fields
  - Add comprehensive documentation for multi-valued behavior
  - Write unit tests for multi-valued field detection

  - _Requirements: 1.4, 3.4_

- [x] 101. Create PhonicAudioFileImpl class structure

  - Implement PhonicAudioFileImpl class implementing PhonicAudioFile interface
  - Add formatStrategy, codecRegistry, mergePolicy properties
  - Create inMemoryTagsByKey map for tag storage
  - Add loadedContainersByKindAndVersion map for container caching
  - Include dirty flag for change tracking
  - Write unit tests for class instantiation
  - _Requirements: 1.1, 1.2, 2.1, 6.3_

- [x] 102. Implement container extraction and decoding

  - Create \_extractContainersAndDecode method in PhonicAudioFileImpl
  - Use format strategy precedence to locate and extract containers
  - Decode containers using appropriate codecs
  - Merge decoded tags into unified view with provenance
  - Write unit tests for container extraction
  - _Requirements: 1.1, 1.2, 4.1_

- [x] 103. Implement getTag method

  - Create getTag method returning first tag for given TagKey
  - Handle null returns when tag not found
  - Include comprehensive Dart documentation with examples
  - Write unit tests for tag retrieval scenarios
  - _Requirements: 1.1, 9.1, 9.2_

- [x] 104. Implement getTags method

  - Create getTags method returning all tags for given TagKey
  - Handle multi-valued tags like artwork
  - Return empty list when no tags found
  - Write unit tests for multi-valued tag retrieval
  - _Requirements: 1.1, 1.4, 9.1_

- [x] 105. Implement getAllTags method

  - Create getAllTags method returning all tags from all containers

  - Flatten tag collections while preserving provenance
  - Include comprehensive documentation
  - Write unit tests for complete tag retrieval
  - _Requirements: 1.1, 9.1_

- [x] 106. Implement setTag method

  - Create setTag method for adding/updating tags
  - Handle single-valued vs multi-valued tag logic
  - Set dirty flag and validate against constraints
  - Add comprehensive documentation with @throws annotations
  - Write unit tests for tag setting scenarios
  - _Requirements: 2.1, 5.1, 6.3, 9.1, 9.2_

- [x] 107. Implement removeTag method

  - Create removeTag method for removing all tags with given TagKey
  - Set dirty flag when tags are removed
  - Handle cases where tag doesn't exist
  - Write unit tests for tag removal scenarios
  - _Requirements: 2.1, 6.3, 9.1_

- [x] 108. Implement removeTagValue method

  - Create removeTagValue method for removing specific values from multi-valued tags
  - Handle artwork and other multi-valued field removal
  - Set dirty flag when values are removed
  - Write unit tests for specific value removal
  - _Requirements: 2.1, 6.3, 9.1_

- [x] 109. Implement isDirty property and markClean method

  - Add isDirty getter returning current dirty state
  - Implement markClean method resetting dirty flag

  - Include comprehensive documentation
  - Write unit tests for dirty state management
  - _Requirements: 6.3, 9.1_

- [x] 110. Create file encoding preparation utilities

  - Implement utilities for preparing tags for encoding
  - Add fan-out logic selecting target containers based on format strategy
  - Create capability filtering removing unsupported tags
  - Apply normalization for each target container

  - Write unit tests for encoding preparation
  - _Requirements: 2.1, 2.2, 2.3, 5.1_

- [x] 111. Implement container rebuilding logic

  - Create logic for rebuilding containers with updated tags
  - Use appropriate codecs for each container type
  - Preserve existing container bytes when possible
  - Handle unknown frame/atom preservation
  - Write unit tests for container rebuilding
  - _Requirements: 2.1, 2.2, 8.3_

- [x] 112. Implement file injection and assembly

  - Create logic for injecting updated containers back into file
  - Use container locators for proper positioning
  - Handle container order requirements for each format
  - Ensure atomic file operations
  - Write unit tests for file assembly
  - _Requirements: 2.1, 2.2, 6.2, 8.4_

- [x] 113. Implement encode method

  - Create encode method orchestrating complete file encoding
  - Use encoding preparation, rebuilding, and injection utilities
  - Clear dirty flags after successful encoding
  - Add validation after write to ensure integrity
  - Write comprehensive unit tests for encoding scenarios
  - _Requirements: 2.1, 2.2, 2.3, 6.2, 6.3, 8.4_

- [x] 114. Implement audioData property

  - Create audioData getter returning raw audio without containers
  - Strip all metadata containers from original file bytes
  - Handle different container removal for each format
  - Write unit tests for audio data extraction
  - _Requirements: 7.3_

- [x] 115. Implement dispose method


  - Create dispose method for explicit resource cleanup
  - Clear tag collections and container caches
  - Release any held resources
  - Write unit tests for disposal functionality
  - _Requirements: 7.5, 9.1_

- [ ] 116. Create Mp3AudioFile class

  - Implement Mp3AudioFile extending PhonicAudioFileImpl
  - Configure with Mp3FormatStrategy and appropriate codecs
  - Include ID3v2.4, ID3v2.3, ID3v2.2, and ID3v1 codecs
  - Add ID3v2 and ID3v1 locators
  - Write unit tests for MP3-specific behavior
  - _Requirements: 10.1, 10.4_

- [ ] 117. Create FlacAudioFile class

  - Implement FlacAudioFile extending PhonicAudioFileImpl
  - Configure with FlacFormatStrategy and Vorbis codec
  - Include VorbisLocator for FLAC comment blocks
  - Write unit tests for FLAC-specific behavior
  - _Requirements: 10.2_

- [ ] 118. Create OggAudioFile class

  - Implement OggAudioFile extending PhonicAudioFileImpl
  - Configure with OggFormatStrategy and Vorbis codec
  - Include OggVorbisLocator for OGG comment handling
  - Write unit tests for OGG-specific behavior
  - _Requirements: 10.3_

- [ ] 119. Create OpusAudioFile class

  - Implement OpusAudioFile extending PhonicAudioFileImpl
  - Configure with OpusFormatStrategy and Vorbis codec
  - Include appropriate locator for Opus comment handling
  - Write unit tests for Opus-specific behavior
  - _Requirements: 10.3_

- [ ] 120. Create Mp4AudioFile class

  - Implement Mp4AudioFile extending PhonicAudioFileImpl
  - Configure with Mp4FormatStrategy and MP4 atoms codec
  - Include Mp4Locator for ilst atom handling
  - Write unit tests for MP4-specific behavior
  - _Requirements: 10.6_-
    [ ] 121. Create M4aAudioFile class
  - Implement M4aAudioFile extending PhonicAudioFileImpl
  - Configure with Mp4FormatStrategy and MP4 atoms codec (same as MP4)
  - Include Mp4Locator for ilst atom handling
  - Write unit tests for M4A-specific behavior
  - _Requirements: 10.6_

- [ ] 122. Create format detection utilities

  - Implement file signature detection for different audio formats
  - Add MP3 frame sync detection and ID3 header checking
  - Create FLAC signature detection ("fLaC" magic bytes)
  - Add OGG signature detection ("OggS" magic bytes)
  - Implement MP4/M4A signature detection (ftyp atom)
  - Write unit tests for format detection accuracy
  - _Requirements: 1.1, 8.1_

- [ ] 123. Create Phonic factory class structure

  - Implement Phonic class with static factory methods
  - Add comprehensive class documentation
  - Include usage examples in documentation
  - Write unit tests for class structure
  - _Requirements: 1.1, 9.1_

- [ ] 124. Implement Phonic.fromFile method

  - Create fromFile static method reading file and detecting format
  - Use format detection utilities to determine audio type
  - Instantiate appropriate audio file class based on format
  - Handle file reading errors and unsupported formats
  - Write unit tests with various file types
  - _Requirements: 1.1, 8.1, 9.1_

- [ ] 125. Implement Phonic.fromBytes method

  - Create fromBytes static method with optional filename hint
  - Use format detection on byte content
  - Support filename extension as format hint when detection fails
  - Instantiate appropriate audio file class
  - Write unit tests for byte-based creation
  - _Requirements: 1.1, 8.1, 9.1_

- [ ] 126. Create AudioFileCache class structure

  - Implement AudioFileCache with WeakReference-based storage
  - Add maxCacheSize configuration
  - Include cache hit/miss tracking for performance monitoring
  - Write unit tests for cache structure
  - _Requirements: 7.4, 7.5_

- [ ] 127. Implement AudioFileCache methods

  - Add get method for cache retrieval with weak reference handling
  - Implement put method with cache size management
  - Create eviction logic for oldest entries when cache is full
  - Add clear method for cache cleanup
  - Write unit tests for cache operations
  - _Requirements: 7.4, 7.5_

- [ ] 128. Implement lazy artwork loading optimization

  - Optimize artwork loading to defer until actually accessed
  - Create artwork data streaming for large images
  - Add memory pressure handling for artwork caches
  - Implement artwork data compression when beneficial
  - Write performance tests for artwork memory usage
  - _Requirements: 7.1, 7.2_

- [ ] 129. Create memory-efficient tag storage

  - Optimize tag storage structures to minimize memory overhead
  - Use efficient data structures for tag collections
  - Implement string interning for common tag values
  - Add memory usage monitoring utilities
  - Write performance tests for tag storage efficiency
  - _Requirements: 7.5_

- [ ] 130. Implement streaming operations support

  - Create utilities for processing large collections without loading all files
  - Add batch processing capabilities for tag operations
  - Implement progress reporting for long-running operations
  - Create memory-bounded collection processing
  - Write performance tests for streaming operations
  - _Requirements: 7.4_

- [ ] 131. Create error recovery utilities

  - Implement graceful handling of corrupted containers
  - Add detailed error logging with byte offsets
  - Create container skip logic when parsing fails
  - Add error context preservation for debugging
  - Write unit tests for error recovery scenarios
  - _Requirements: 8.1, 8.2_

- [ ] 132. Implement unknown frame/atom preservation

  - Create logic for preserving unknown frames during ID3v2 writes
  - Add unknown atom preservation for MP4 containers
  - Implement safe preservation rules (avoid corrupting known structures)
  - Add configuration options for preservation behavior
  - Write unit tests for preservation functionality
  - _Requirements: 8.3_

- [ ] 133. Implement post-write validation

  - Create validation logic that parses written files for consistency
  - Add quick integrity checks after write operations
  - Implement rollback capabilities when validation fails
  - Create detailed validation error reporting
  - Write unit tests for validation scenarios
  - _Requirements: 8.4_

- [ ] 134. Add comprehensive method documentation

  - Document all public methods with detailed descriptions
  - Add parameter documentation with types and constraints
  - Include return value documentation with examples
  - Add @throws annotations for all possible exceptions
  - Create usage examples for complex methods
  - _Requirements: 9.1, 9.2, 9.3_

- [ ] 135. Add class-level documentation

  - Create comprehensive class documentation with purpose and usage
  - Add memory management guidance for each class
  - Include performance considerations and best practices
  - Create architectural overview documentation
  - Add thread safety information where relevant
  - _Requirements: 9.1, 9.4, 9.5_

- [ ] 136. Create API usage examples

  - Write comprehensive examples for common use cases
  - Create examples for each supported audio format
  - Add examples for error handling and edge cases
  - Include performance optimization examples
  - Create integration examples with real applications
  - _Requirements: 9.1, 9.5_

- [ ] 137. Write round-trip integration tests

  - Create tests that read → modify → write → read for all formats
  - Test tag preservation across write operations
  - Verify provenance information is maintained correctly
  - Test with real-world audio file samples
  - Include edge cases and boundary conditions
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 4.1_

- [ ] 138. Create cross-format consistency tests

  - Test that same logical tags behave consistently across formats
  - Verify rating normalization works correctly between containers
  - Test date handling consistency across ID3v2 versions
  - Verify artwork handling works across all supporting formats
  - Create tests for format-specific constraint handling
  - _Requirements: 1.3, 3.2, 3.3, 5.1, 5.2_

- [ ] 139. Write performance benchmark tests

  - Create memory usage benchmarks for loading thousands of files
  - Test processing speed for different operations and file sizes
  - Benchmark lazy loading effectiveness for artwork
  - Create cache performance tests
  - Add regression testing for performance improvements
  - _Requirements: 6.1, 6.2, 7.1, 7.2, 7.4, 7.5_

- [ ] 140. Create corruption handling tests

  - Test graceful handling of various types of file corruption
  - Create tests with malformed headers and containers
  - Test partial file scenarios and truncated data
  - Verify error reporting includes useful debugging information
  - Test recovery capabilities when some containers are corrupted
  - _Requirements: 8.1, 8.2, 8.3_

- [ ] 141. Write example applications

  - Create simple tag editor example application
  - Write batch tag processing example
  - Create artwork extraction and management example
  - Add format conversion example (preserving tags)
  - Include performance monitoring example
  - _Requirements: 9.1, 9.5_

- [ ] 142. Create comprehensive test data sets

  - Collect real-world audio files for each supported format
  - Create test files with various tag configurations
  - Add files with edge cases (empty tags, maximum lengths, etc.)
  - Include corrupted files for error handling tests
  - Create files with multiple container types (MP3 with both ID3v2 and ID3v1)
  - _Requirements: 1.1, 1.2, 8.1, 8.2_

- [ ] 143. Final integration and system testing
  - Run complete test suite across all implemented functionality
  - Verify all requirements are met by implementation
  - Test memory usage with large collections (1000+ files)
  - Perform stress testing with concurrent operations
  - Validate documentation completeness and accuracy
  - _Requirements: All requirements_
