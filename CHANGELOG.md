## [Unreleased]

### Fixed

- Fixed critical MP4 decoding bug where iTunes-style metadata atoms were not being read correctly
  - Fixed parser to properly handle nested 'data' atom structure (16-byte offset: 8-byte header + 8-byte version/flags)
  - Fixed encoder to create correct nested 'data' atom structure for iTunes compatibility
  - Fixed Mp4Locator to properly extract/inject child atoms instead of full ilst container
  - Corrected Mp4Capability to mark genres as multi-valued (semicolon-delimited) instead of single-valued
  - All 358 MP4 format tests now passing
  - Real-world MP4 files now decode correctly with all metadata preserved

### Added

- Silence audio tool improvements:
  - Added Linux/macOS bash script (`tools/silence_audio.sh`) equivalent to PowerShell version
  - Single file mode support with `-i`/`--input` and `-o`/`--output` flags for both scripts
  - MP4 format support (extracts audio stream and preserves metadata)
  - Help command (`-h`/`--help`) with usage examples
  - Comprehensive documentation in `doc/silence-audio-tool.md`
  - Support for 8 audio formats: MP3, M4A, AAC, FLAC, OGG, OPUS, WAV, MP4
- Public validator API for form integration and input validation
- `TagValidator<T>` base class with `validate()`, `validateOrThrow()`, and `formatErrorMessage()` methods
- Numeric validators: `RatingValidator`, `BpmValidator`, `YearValidator`, `TrackNumberValidator`, `DiscNumberValidator`
- Date validator: `DateRecordedValidator` with comprehensive ISO-8601 format validation
- Text validators: `TitleValidator`, `ArtistValidator`, `AlbumValidator` for required field validation
- `TagValidators` convenience class providing static access to all validators
- Static validator constants on tag classes (e.g., `TitleTag.validator`, `RatingTag.validator`)
- `reactive_forms` integration support via `Validators.delegate()`
- Comprehensive validator test suite with 153+ tests covering all validators
- Automatic value normalization (trimming whitespace) in text validators

## [1.1.2] - 2025-09-21

### Fixed

- Fixed bug where corrupted text data from legacy containers (especially ID3v1) was being displayed as strange characters
- Enhanced merge policy to automatically filter out corrupted text tags containing excessive null bytes or non-printable characters
- Album and other text fields now properly return null instead of displaying corrupted data
- Improved data quality by preventing corrupted metadata from reaching the user

## [1.1.1] - 2025-09-21

### Fixed

- Fixed bug where year tags were not being derived from dateRecorded fields when explicit year tags were missing
- Added automatic tag inference integration to derive missing metadata tags from available data
- Year tags are now automatically derived with `TagConfidence.derived` provenance when only dateRecorded is present
- AlbumArtist tags are now automatically inferred with `TagConfidence.inferred` provenance when only artist is present

## [1.1.0] - 2025-09-04

### Added

- JSON serialization support for all metadata tags with provenance preservation
- Individual `toJson()` and `fromJson()` methods for each metadata tag type
- Centralized provenance conversion in `TagProvenance` class

## [1.0.0] - 2025-09-04

### Added

- Initial release of Phonic audio metadata library
- Support for MP3 files with ID3v1, ID3v2.2, ID3v2.3, and ID3v2.4 tags
- Support for FLAC files with Vorbis Comments
- Support for OGG Vorbis files with Vorbis Comments
- Support for Opus files with Vorbis Comments
- Support for MP4/M4A files with iTunes-compatible atoms
- Unified API for reading and writing metadata across all supported formats
- Automatic format detection and capability handling
- 50+ metadata tag types including title, artist, album, genre, artwork, and more
- Multi-valued tag support (genres, artists, composers)
- Lazy loading artwork system with memory optimization
- Advanced artwork handling with multiple types (front cover, back cover, artist photo, etc.)
- Streaming operations for batch processing large collections
- Memory-efficient processing with automatic resource management
- Tag provenance tracking to identify metadata sources
- Cross-format metadata conversion with intelligent mapping
- Comprehensive validation system with format-specific constraints
- Error handling with typed exceptions
- Unknown data preservation during tag operations
- Performance optimization utilities (string interning, caching)
- Progress tracking and cancellation support for long operations
- Collection analysis tools for music library management
- 145 comprehensive test files covering all formats and edge cases
- Complete documentation with guides and examples
- 7 example files demonstrating common usage patterns

### Dependencies

- `convert: ^3.1.2`
- `equatable: ^2.0.7`
- `collection: ^1.18.0`
