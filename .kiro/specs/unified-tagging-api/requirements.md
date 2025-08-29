# Requirements Document

## Introduction

The Phonic library needs a unified tagging API that provides a single entry point for reading and writing metadata tags across different audio container formats (ID3v1, ID3v2.x, Vorbis Comments, MP4 atoms). Users should be able to work with a consistent set of logical fields without needing to understand the underlying container specifics, versions, or constraints.

## Requirements

### Requirement 1

**User Story:** As a developer using the Phonic library, I want to read metadata tags from any supported audio file format using a consistent API, so that I don't need to handle format-specific parsing logic.

#### Acceptance Criteria

1. WHEN I call getTag() on any supported audio file THEN the system SHALL return the tag value using the unified tag model
2. WHEN multiple containers exist in a file THEN the system SHALL apply precedence rules to return the highest-priority value
3. WHEN a tag exists in multiple formats THEN the system SHALL normalize the value to the unified model (e.g., rating 0-100)
4. WHEN I request multi-valued tags like artwork THEN the system SHALL return all values from all containers with provenance information

### Requirement 2

**User Story:** As a developer using the Phonic library, I want to write metadata tags to any supported audio file format using a consistent API, so that I can update tags without understanding container-specific encoding rules.

#### Acceptance Criteria

1. WHEN I call setTag() with a unified tag THEN the system SHALL write to appropriate containers based on fan-out policy
2. WHEN writing to multiple containers THEN the system SHALL normalize values according to each container's capabilities
3. WHEN a container doesn't support a tag THEN the system SHALL skip that container and continue with others
4. WHEN writing would cause data loss THEN the system SHALL provide visibility into what will be truncated or dropped

### Requirement 3

**User Story:** As a developer using the Phonic library, I want to work with a fixed set of logical tag fields, so that I have a predictable interface regardless of the underlying container format.

#### Acceptance Criteria

1. WHEN accessing tags THEN the system SHALL support these unified fields: title, artist, album, albumArtist, trackNumber, discNumber, year, dateRecorded, genre, comment, bpm, musicalKey, rating, lyrics, artwork, grouping, composer, encoder, isrc, custom
2. WHEN working with dates THEN the system SHALL normalize to ISO-8601 format internally
3. WHEN working with ratings THEN the system SHALL use 0-100 scale internally regardless of container format
4. WHEN working with text fields THEN the system SHALL handle encoding normalization transparently

### Requirement 4

**User Story:** As a developer using the Phonic library, I want to understand where tag data originated from, so that I can audit merges and make informed decisions about data quality.

#### Acceptance Criteria

1. WHEN reading tags THEN each tag SHALL include provenance information (container type, version, confidence level)
2. WHEN multiple containers provide the same tag THEN the system SHALL preserve all sources with their provenance
3. WHEN tags are inferred or derived THEN the system SHALL mark them with lower confidence
4. WHEN displaying tag information THEN I SHALL be able to access the complete provenance chain

### Requirement 5

**User Story:** As a developer using the Phonic library, I want the system to handle container-specific constraints automatically, so that I don't need to implement validation logic for each format.

#### Acceptance Criteria

1. WHEN writing tags THEN the system SHALL validate against container capabilities (length limits, value ranges, supported fields)
2. WHEN a tag exceeds container limits THEN the system SHALL apply appropriate truncation or scaling
3. WHEN a container doesn't support multi-values THEN the system SHALL handle single-value selection appropriately
4. WHEN writing ID3v1 tags THEN the system SHALL handle the 30-character limit and track number overlap with comment field

### Requirement 6

**User Story:** As a developer using the Phonic library, I want efficient file operations that minimize unnecessary rewrites, so that my application performs well with large audio collections.

#### Acceptance Criteria

1. WHEN reading files THEN the system SHALL load artwork and large payloads lazily
2. WHEN writing changes THEN the system SHALL only rewrite containers that have been modified
3. WHEN tracking changes THEN the system SHALL maintain dirty flags per tag key and per container
4. WHEN working with large MP4 files THEN the system SHALL handle atomic rewrites when moov precedes mdat

### Requirement 7

**User Story:** As a developer using the Phonic library, I want minimal memory usage when working with large audio collections, so that I can load thousands of songs into memory without performance degradation.

#### Acceptance Criteria

1. WHEN loading audio files THEN the system SHALL store only essential metadata in memory, not the full file contents
2. WHEN accessing artwork THEN the system SHALL load image data on-demand rather than keeping it in memory
3. WHEN caching raw audio data THEN the system SHALL defer loading until write operations are needed
4. WHEN working with collections THEN the system SHALL support streaming operations that don't require loading all files simultaneously
5. WHEN storing tag data THEN the system SHALL use efficient data structures that minimize memory overhead per file

### Requirement 8

**User Story:** As a developer using the Phonic library, I want the system to handle corrupt or partial tag data gracefully, so that my application remains stable when processing real-world audio files.

#### Acceptance Criteria

1. WHEN encountering corrupt containers THEN the system SHALL skip the corrupted container and continue processing others
2. WHEN parsing fails THEN the system SHALL log errors with byte offsets for debugging
3. WHEN writing tags THEN the system SHALL preserve unknown frames/atoms unless explicitly configured otherwise
4. WHEN validation fails after write THEN the system SHALL perform a quick parse to ensure file consistency

### Requirement 9

**User Story:** As a developer using the Phonic library, I want access to well-defined metadata classes that I can use in my application, so that I don't need to create my own tag representation classes.

#### Acceptance Criteria

1. WHEN using the library THEN the system SHALL provide public metadata tag classes (TitleTag, ArtistTag, RatingTag, etc.)
2. WHEN working with metadata objects THEN the system SHALL expose only the essential properties (value, key, provenance) without implementation details
3. WHEN creating tag instances THEN the system SHALL provide simple constructors that don't require knowledge of internal business logic
4. WHEN accessing tag data THEN the system SHALL provide type-safe access to tag values through strongly-typed classes
5. WHEN working with provenance THEN the system SHALL expose container source information without revealing parsing internals

### Requirement 10

**User Story:** As a developer using the Phonic library, I want format-specific precedence and fan-out policies that work correctly by default, so that I get expected behavior without complex configuration.

#### Acceptance Criteria

1. WHEN reading MP3 files THEN the system SHALL use precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
2. WHEN reading FLAC/OGG/OPUS files THEN the system SHALL use Vorbis Comments only
3. WHEN reading MP4/M4A files THEN the system SHALL use MP4 atoms only
4. WHEN writing MP3 files THEN the system SHALL target ID3v2.4 and optionally mirror safe subset to ID3v1
5. WHEN writing FLAC/OGG/OPUS files THEN the system SHALL write to Vorbis Comments only
6. WHEN writing MP4/M4A files THEN the system SHALL write to MP4 atoms only