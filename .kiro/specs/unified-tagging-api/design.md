# Design Document

## Overview

The Phonic unified tagging API provides a single entry point for reading and writing metadata across different audio container formats. The design follows a layered architecture with clear separation between the public API, unified tag model, container-specific codecs, and low-level parsing logic.

The system uses a capability-driven approach where each container format declares its supported fields and constraints, enabling automatic validation and normalization. Memory efficiency is achieved through lazy loading of large payloads and streaming-oriented operations.

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Public API Layer                         │
│  PhonicAudioFile, MetadataTag classes, Factory methods     │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                 Unified Tag Model Layer                     │
│     TagKey enum, MetadataTag hierarchy, Provenance         │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                Format Strategy Layer                        │
│   Mp3Strategy, FlacStrategy, Mp4Strategy (precedence)      │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                Container Codec Layer                        │
│  Id3v2Codec, Id3v1Codec, VorbisCodec, Mp4Codec           │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│              Container Locator Layer                        │
│   Id3v2Locator, Id3v1Locator, VorbisLocator, Mp4Locator   │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                 Binary Parsing Layer                        │
│        ByteReader, SynchsafeInt, TextDecoding              │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**Read Pipeline:**
1. Format detection → Container location → Codec parsing → Normalization → Merge with precedence
2. Lazy loading for artwork and large payloads
3. Provenance tracking throughout the pipeline

**Write Pipeline:**
1. Capability validation → Target selection → Normalization → Container encoding → File injection
2. Dirty tracking to minimize rewrites
3. Atomic operations for file consistency

## Components and Interfaces

### Public API Layer

```dart
// Factory for creating audio file instances
class Phonic {
  static Future<PhonicAudioFile> fromFile(String path);
  static PhonicAudioFile fromBytes(Uint8List bytes, String? filename);
}

// Main interface for tag operations
abstract class PhonicAudioFile {
  // Tag access by key
  MetadataTag? getTag(TagKey key);
  List<MetadataTag> getTags(TagKey key);
  List<MetadataTag> getAllTags();
  
  // Tag modification
  void setTag(MetadataTag tag);
  void removeTag(TagKey key);
  void removeTagValue(TagKey key, dynamic value); // For multi-valued tags
  
  // State management
  bool get isDirty;
  void markClean();
  
  // Serialization
  Future<Uint8List> encode();
  Uint8List get audioData;
  
  // Memory management
  void dispose();
}
```

### Unified Tag Model

```dart
// Base class for all metadata tags
sealed class MetadataTag<T> extends Equatable {
  final T value;
  final TagKey key;
  final TagProvenance provenance;
  
  const MetadataTag({
    required this.value,
    required this.key,
    this.provenance = const TagProvenance.none(),
  });
  
  MetadataTag<T> withProvenance(TagProvenance newProvenance);
  
  @override
  List<Object?> get props => [value, key, provenance];
}

// Concrete tag implementations
final class TitleTag extends MetadataTag<String> {
  const TitleTag(String value, {TagProvenance provenance = const TagProvenance.none()})
      : super(value: value, key: TagKey.title, provenance: provenance);
  
  @override
  TitleTag withProvenance(TagProvenance newProvenance) =>
      TitleTag(value, provenance: newProvenance);
}

final class ArtistTag extends MetadataTag<String> {
  const ArtistTag(String value, {TagProvenance provenance = const TagProvenance.none()})
      : super(value: value, key: TagKey.artist, provenance: provenance);
  
  @override
  ArtistTag withProvenance(TagProvenance newProvenance) =>
      ArtistTag(value, provenance: newProvenance);
}

final class RatingTag extends MetadataTag<int> {
  const RatingTag(int value, {TagProvenance provenance = const TagProvenance.none()})
      : super(value: value, key: TagKey.rating, provenance: provenance);
  
  @override
  RatingTag withProvenance(TagProvenance newProvenance) =>
      RatingTag(value, provenance: newProvenance);
}

final class ArtworkTag extends MetadataTag<ArtworkData> {
  const ArtworkTag(ArtworkData value, {TagProvenance provenance = const TagProvenance.none()})
      : super(value: value, key: TagKey.artwork, provenance: provenance);
  
  @override
  ArtworkTag withProvenance(TagProvenance newProvenance) =>
      ArtworkTag(value, provenance: newProvenance);
}

// Lazy-loaded artwork data
class ArtworkData extends Equatable {
  final String mimeType;
  final ArtworkType type;
  final String? description;
  final Future<Uint8List> _dataLoader;
  
  const ArtworkData({
    required this.mimeType,
    required this.type,
    this.description,
    required Future<Uint8List> dataLoader,
  }) : _dataLoader = dataLoader;
  
  Future<Uint8List> get data => _dataLoader;
  
  @override
  List<Object?> get props => [mimeType, type, description];
}

enum ArtworkType { frontCover, backCover, leaflet, media, leadArtist, artist, conductor, band, composer, lyricist, recordingLocation, duringRecording, duringPerformance, movieScreenCapture, brightColoredFish, illustration, bandLogotype, publisherLogotype }
```

### Provenance System

```dart
class TagProvenance extends Equatable {
  final ContainerKind containerKind;
  final String containerVersion;
  final TagConfidence confidence;
  
  const TagProvenance(this.containerKind, this.containerVersion, this.confidence);
  const TagProvenance.none()
      : containerKind = ContainerKind.none,
        containerVersion = "",
        confidence = TagConfidence.certain;
  
  @override
  List<Object?> get props => [containerKind, containerVersion, confidence];
}

enum TagConfidence { certain, inferred, derived }
enum ContainerKind { none, id3v2, id3v1, vorbis, mp4 }
```

### Capability System

```dart
class TagCapability {
  final ContainerKind containerKind;
  final String containerVersion;
  final Map<TagKey, TagSemantics> semanticsByKey;
  
  const TagCapability({
    required this.containerKind,
    required this.containerVersion,
    required this.semanticsByKey,
  });
  
  bool supports(TagKey key) => semanticsByKey.containsKey(key);
  TagSemantics semantics(TagKey key) => 
      semanticsByKey[key] ?? const TagSemantics();
}

class TagSemantics {
  final bool multiValued;
  final int? maxTextLength;
  final num? minValue;
  final num? maxValue;
  final Set<String>? allowedEncodings;
  
  const TagSemantics({
    this.multiValued = false,
    this.maxTextLength,
    this.minValue,
    this.maxValue,
    this.allowedEncodings,
  });
}
```

### Format Strategy Pattern

```dart
abstract class FormatStrategy {
  MediaKind get mediaKind;
  List<ContainerKind> get containerOrderForInjection;
  List<(ContainerKind, String)> get precedence;
  List<(ContainerKind, String)> get fanout;
  
  bool canHandle(Uint8List fileBytes);
  MediaKind detectFormat(Uint8List fileBytes);
}

class Mp3FormatStrategy implements FormatStrategy {
  @override
  MediaKind get mediaKind => MediaKind.mp3;
  
  @override
  List<(ContainerKind, String)> get precedence => [
    (ContainerKind.id3v2, "2.4"),
    (ContainerKind.id3v2, "2.3"),
    (ContainerKind.id3v2, "2.2"),
    (ContainerKind.id3v1, "v1"),
  ];
  
  @override
  List<(ContainerKind, String)> get fanout => [
    (ContainerKind.id3v2, "2.4"),
    (ContainerKind.id3v1, "v1"),
  ];
  
  @override
  bool canHandle(Uint8List fileBytes) {
    // Check for MP3 frame sync or ID3 header
    return _hasId3Header(fileBytes) || _hasMp3FrameSync(fileBytes);
  }
}
```

### Container Codec Interface

```dart
abstract class TagCodec {
  ContainerKind get containerKind;
  String get containerVersion;
  TagCapability get capability;
  
  List<MetadataTag> readFromContainer(Uint8List containerBytes);
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
  });
}

class Id3v24Codec implements TagCodec {
  @override
  ContainerKind get containerKind => ContainerKind.id3v2;
  
  @override
  String get containerVersion => "2.4";
  
  @override
  TagCapability get capability => _id3v24Capability;
  
  @override
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    final reader = ByteReader(containerBytes);
    final header = _parseId3v2Header(reader);
    final frames = _parseFrames(reader, header);
    return _framesToTags(frames);
  }
  
  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
  }) {
    final frames = _tagsToFrames(tagsToWrite);
    return _buildId3v2Container(frames);
  }
}
```

### Memory Management

```dart
class LazyArtworkLoader {
  final Uint8List _containerBytes;
  final int _offset;
  final int _length;
  
  const LazyArtworkLoader(this._containerBytes, this._offset, this._length);
  
  Future<Uint8List> load() async {
    // Extract artwork data on demand
    return _containerBytes.sublist(_offset, _offset + _length);
  }
}

class AudioFileCache {
  final Map<String, WeakReference<PhonicAudioFile>> _cache = {};
  final int _maxCacheSize;
  
  AudioFileCache({int maxCacheSize = 1000}) : _maxCacheSize = maxCacheSize;
  
  PhonicAudioFile? get(String path) {
    final ref = _cache[path];
    return ref?.target;
  }
  
  void put(String path, PhonicAudioFile file) {
    if (_cache.length >= _maxCacheSize) {
      _evictOldest();
    }
    _cache[path] = WeakReference(file);
  }
}
```

## Data Models

### Core Enums and Constants

```dart
enum TagKey {
  title, artist, album, albumArtist, trackNumber, discNumber,
  year, dateRecorded, genre, comment, bpm, musicalKey, rating,
  lyrics, artwork, grouping, composer, encoder, isrc, custom
}

enum MediaKind { mp3, flac, ogg, opus, m4a, mp4 }

class TagConstants {
  static const int ratingMin = 0;
  static const int ratingMax = 100;
  static const int id3v1MaxLength = 30;
  static const int id3v1CommentMaxLength = 28; // when track present
}
```

### Container Mapping Tables

```dart
class Id3v2FrameMap {
  static const Map<TagKey, String> v24 = {
    TagKey.title: "TIT2",
    TagKey.artist: "TPE1",
    TagKey.album: "TALB",
    TagKey.albumArtist: "TPE2",
    TagKey.trackNumber: "TRCK",
    TagKey.discNumber: "TPOS",
    TagKey.dateRecorded: "TDRC",
    TagKey.genre: "TCON",
    TagKey.comment: "COMM",
    TagKey.bpm: "TBPM",
    TagKey.musicalKey: "TKEY",
    TagKey.rating: "POPM",
    TagKey.lyrics: "USLT",
    TagKey.artwork: "APIC",
    TagKey.grouping: "TIT1",
    TagKey.composer: "TCOM",
    TagKey.encoder: "TSSE",
    TagKey.isrc: "TSRC",
  };
  
  static const Map<TagKey, String> v23 = {
    ...v24,
    TagKey.year: "TYER", // v2.3 uses separate year field
  };
}

class VorbisCommentMap {
  static const Map<TagKey, String> keys = {
    TagKey.title: "TITLE",
    TagKey.artist: "ARTIST",
    TagKey.album: "ALBUM",
    TagKey.albumArtist: "ALBUMARTIST",
    TagKey.trackNumber: "TRACKNUMBER",
    TagKey.discNumber: "DISCNUMBER",
    TagKey.dateRecorded: "DATE",
    TagKey.genre: "GENRE",
    TagKey.comment: "COMMENT",
    TagKey.bpm: "BPM",
    TagKey.musicalKey: "KEY",
    TagKey.rating: "RATING",
    TagKey.lyrics: "LYRICS",
    TagKey.grouping: "GROUPING",
    TagKey.composer: "COMPOSER",
    TagKey.encoder: "ENCODER",
    TagKey.isrc: "ISRC",
  };
}
```

## Error Handling

### Exception Hierarchy

```dart
abstract class PhonicException implements Exception {
  final String message;
  final String? context;
  
  const PhonicException(this.message, {this.context});
  
  @override
  String toString() => context != null 
      ? 'PhonicException: $message (Context: $context)'
      : 'PhonicException: $message';
}

class UnsupportedFormatException extends PhonicException {
  const UnsupportedFormatException(String message, {String? context})
      : super(message, context: context);
}

class CorruptedContainerException extends PhonicException {
  final int? byteOffset;
  
  const CorruptedContainerException(String message, {this.byteOffset, String? context})
      : super(message, context: context);
}

class TagValidationException extends PhonicException {
  final TagKey tagKey;
  final String reason;
  
  const TagValidationException(this.tagKey, this.reason, {String? context})
      : super('Tag validation failed for $tagKey: $reason', context: context);
}
```

### Error Recovery Strategy

```dart
class ErrorRecoveryPolicy {
  final bool skipCorruptedContainers;
  final bool preserveUnknownFrames;
  final bool validateAfterWrite;
  
  const ErrorRecoveryPolicy({
    this.skipCorruptedContainers = true,
    this.preserveUnknownFrames = true,
    this.validateAfterWrite = true,
  });
}

class ParseResult<T> {
  final T? value;
  final List<PhonicException> errors;
  final List<String> warnings;
  
  const ParseResult({this.value, this.errors = const [], this.warnings = const []});
  
  bool get isSuccess => value != null && errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}
```

## Testing Strategy

### Unit Testing Approach

1. **Tag Model Tests**: Verify equality, provenance handling, and type safety
2. **Codec Tests**: Test parsing and encoding for each container format with real-world samples
3. **Capability Tests**: Validate constraint enforcement and normalization rules
4. **Strategy Tests**: Verify precedence and fan-out policies work correctly
5. **Memory Tests**: Ensure lazy loading and cache behavior work as expected

### Integration Testing

1. **Round-trip Tests**: Read → Modify → Write → Read cycles for all supported formats
2. **Cross-format Tests**: Verify consistent behavior across different container types
3. **Performance Tests**: Memory usage and processing time with large collections
4. **Corruption Tests**: Graceful handling of malformed or partial files

### Test Data Strategy

```dart
class TestAssets {
  static const String mp3WithId3v24 = 'assets/test/sample_id3v24.mp3';
  static const String mp3WithId3v23 = 'assets/test/sample_id3v23.mp3';
  static const String mp3WithId3v1 = 'assets/test/sample_id3v1.mp3';
  static const String flacWithVorbis = 'assets/test/sample_vorbis.flac';
  static const String m4aWithAtoms = 'assets/test/sample_atoms.m4a';
  static const String corruptedMp3 = 'assets/test/corrupted.mp3';
  
  // Generate test files with known metadata for verification
  static Future<Uint8List> generateTestMp3WithTags(List<MetadataTag> tags);
}
```

### Performance Benchmarks

```dart
class PerformanceBenchmarks {
  static Future<void> benchmarkMemoryUsage() async {
    // Test loading 1000+ files and measure memory consumption
  }
  
  static Future<void> benchmarkReadPerformance() async {
    // Measure tag reading speed across different formats
  }
  
  static Future<void> benchmarkWritePerformance() async {
    // Measure tag writing speed and file size impact
  }
  
  static Future<void> benchmarkLazyLoading() async {
    // Verify artwork loading doesn't impact initial load time
  }
}
```

## Documentation Strategy

### Dart Documentation Requirements

All public APIs must include comprehensive Dart documentation with:

1. **Method Documentation**:
   - Clear description of what the method does
   - Parameter descriptions with types and constraints
   - Return value descriptions
   - Exception documentation using `@throws` annotations
   - Usage examples with `@example` blocks
   - Performance considerations where relevant

2. **Class Documentation**:
   - Purpose and role in the system
   - Usage patterns and best practices
   - Memory management considerations
   - Thread safety information

3. **Enum and Constant Documentation**:
   - Meaning of each value
   - When to use each option
   - Relationships between values

### Documentation Examples

```dart
/// Represents metadata for an audio file with unified access across container formats.
/// 
/// This class provides a format-agnostic interface for reading and writing
/// audio metadata tags. It handles the complexity of different container
/// formats (ID3v1, ID3v2.x, Vorbis Comments, MP4 atoms) internally.
/// 
/// Memory usage is optimized through lazy loading of large payloads like
/// artwork data. The instance maintains dirty state tracking to minimize
/// file rewrites during save operations.
/// 
/// Example usage:
/// ```dart
/// final audioFile = await Phonic.fromFile('song.mp3');
/// final title = audioFile.getTag(TagKey.title)?.value as String?;
/// audioFile.setTag(TitleTag('New Title'));
/// await File('output.mp3').writeAsBytes(await audioFile.encode());
/// ```
abstract class PhonicAudioFile {
  /// Retrieves the first tag with the specified [key].
  /// 
  /// Returns `null` if no tag with the given key exists.
  /// For multi-valued tags like artwork, use [getTags] to retrieve all values.
  /// 
  /// The returned tag includes provenance information indicating which
  /// container and version it originated from.
  /// 
  /// @param key The tag key to search for
  /// @returns The first matching tag or null if not found
  /// @throws ArgumentError if [key] is null
  MetadataTag? getTag(TagKey key);
  
  /// Sets or updates a tag value.
  /// 
  /// For single-valued tags, this replaces any existing value.
  /// For multi-valued tags like artwork, this adds to the existing values.
  /// 
  /// The tag will be written to appropriate containers based on the file
  /// format's fan-out policy during the next [encode] operation.
  /// 
  /// @param tag The tag to set, must not be null
  /// @throws TagValidationException if the tag value violates container constraints
  /// @throws ArgumentError if [tag] is null
  /// 
  /// Example:
  /// ```dart
  /// audioFile.setTag(TitleTag('My Song'));
  /// audioFile.setTag(RatingTag(85)); // 0-100 scale
  /// ```
  void setTag(MetadataTag tag);
}

/// Confidence level indicating the reliability of tag data.
/// 
/// This enum helps distinguish between explicitly stored values and
/// values that have been inferred or derived from other sources.
enum TagConfidence {
  /// The tag was explicitly found and parsed from a container.
  /// This represents the highest confidence level.
  certain,
  
  /// The tag value was inferred from other available information.
  /// For example, albumArtist derived from artist when missing.
  inferred,
  
  /// The tag value was calculated or transformed from other data.
  /// For example, year extracted from a full ISO-8601 date.
  derived,
}
```

### Exception Documentation Standards

```dart
/// Base exception for all Phonic library errors.
/// 
/// All exceptions thrown by the library extend this class to provide
/// consistent error handling patterns.
abstract class PhonicException implements Exception {
  /// Human-readable error message describing what went wrong.
  final String message;
  
  /// Optional context information about where the error occurred.
  /// May include file paths, byte offsets, or container information.
  final String? context;
  
  const PhonicException(this.message, {this.context});
}

/// Thrown when attempting to parse an unsupported or unrecognized file format.
/// 
/// This exception indicates that the file format detection failed or
/// the detected format is not supported by the current codec registry.
/// 
/// Common causes:
/// - File is not an audio file
/// - Audio format is not supported (e.g., WMA, AAC without container)
/// - File is corrupted beyond recognition
class UnsupportedFormatException extends PhonicException {
  /// Creates an exception for unsupported file formats.
  /// 
  /// @param message Description of the unsupported format
  /// @param context Optional context like file path or detected format
  const UnsupportedFormatException(String message, {String? context})
      : super(message, context: context);
}
```

This design provides a robust, extensible foundation for the unified tagging API while maintaining clean separation of concerns, efficient memory usage patterns, and comprehensive documentation standards.