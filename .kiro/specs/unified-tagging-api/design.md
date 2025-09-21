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

## Usage Examples

### Basic GenreTag Operations

```dart
// Creating a multi-genre tag
final multiGenreTag = GenreTag(['Rock', 'Alternative', 'Indie']);
print(multiGenreTag.value); // ['Rock', 'Alternative', 'Indie']

// Creating a single genre tag
final singleGenreTag = GenreTag.single('Jazz');
print(singleGenreTag.value); // ['Jazz']

// Automatic delimiter detection from various formats
final fromSemicolon = GenreTag.fromString('Rock;Alternative;Indie');
final fromSlash = GenreTag.fromString('Rock/Alternative/Indie');
final fromPipe = GenreTag.fromString('Rock|Alternative|Indie');
final fromComma = GenreTag.fromString('Rock, Alternative, Indie');
final fromBackslash = GenreTag.fromString('Rock\\Alternative\\Indie');
// All result in: ['Rock', 'Alternative', 'Indie']

// Container-specific encoding
final id3v24Encoded = multiGenreTag.toId3v24String();     // 'Rock\0Alternative\0Indie' (null-terminated)
final id3v23Encoded = multiGenreTag.toId3v23String();     // 'Rock/Alternative/Indie' (slash-separated)
final mp4Encoded = multiGenreTag.toEncodedString(';');    // 'Rock;Alternative;Indie' (semicolon for MP4)
final displayEncoded = multiGenreTag.toEncodedString(', '); // 'Rock, Alternative, Indie' (human readable)

// Working with provenance
final genreWithProvenance = GenreTag(['Electronic', 'Ambient']).withProvenance(
  TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
);

// Handling edge cases
final emptyGenre = GenreTag.fromString('');              // []
final singleFromString = GenreTag.fromString('Jazz');    // ['Jazz']
final withSpaces = GenreTag.fromString(' Rock ; Pop ; '); // ['Rock', 'Pop']
```

### Container Format Handling

```dart
// ID3v2.4 codec handling - uses null-terminated strings
class Id3v24Codec {
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    // ... parse TCON frame
    final genreBytes = parseTextFrameBytes('TCON');
    // ID3v2.4 uses null-terminated strings: 'Rock\0Alternative\0Indie'
    final genreStrings = _parseNullTerminatedStrings(genreBytes);
    final genreTag = GenreTag(genreStrings);
    return [genreTag];
  }

  Uint8List writeToContainer({required List<MetadataTag> tags}) {
    final genreTag = tags.whereType<GenreTag>().firstOrNull;
    if (genreTag != null) {
      // ID3v2.4 uses null-terminated strings
      final encodedGenre = genreTag.toId3v24String(); // 'Rock\0Alternative\0Indie'
      // ... write to TCON frame
    }
  }
}

// ID3v2.3 codec handling - uses slash-separated strings
class Id3v23Codec {
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    // ... parse TCON frame
    final genreString = parseTextFrame('TCON');
    // ID3v2.3 uses slash separation: 'Rock/Alternative/Indie'
    final genreTag = GenreTag.fromId3v23String(genreString);
    return [genreTag];
  }

  Uint8List writeToContainer({required List<MetadataTag> tags}) {
    final genreTag = tags.whereType<GenreTag>().firstOrNull;
    if (genreTag != null) {
      // ID3v2.3 uses slash separation
      final encodedGenre = genreTag.toId3v23String(); // 'Rock/Alternative/Indie'
      // ... write to TCON frame
    }
  }
}

// MP4 codec handling - similar to ID3v2 but with atom structure
class Mp4AtomsCodec {
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    // ... parse ©gen atom
    final genreString = parseAtomText('©gen');
    // Handle various delimiters from different MP4 taggers
    final genreTag = GenreTag.fromString(genreString);
    return [genreTag];
  }

  Uint8List writeToContainer({required List<MetadataTag> tags}) {
    final genreTag = tags.whereType<GenreTag>().firstOrNull;
    if (genreTag != null) {
      // Use semicolon for MP4 consistency
      final encodedGenre = genreTag.toEncodedString(';');
      // ... write to ©gen atom
    }
  }
}

// Vorbis codec handling - natively supports multiple values
class VorbisCommentsCodec {
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    final genreFields = parseComments().where((c) => c.key == 'GENRE');
    final genres = genreFields.map((c) => c.value).toList();

    // Handle case where some taggers put multiple genres in single field
    final allGenres = <String>[];
    for (final genreField in genres) {
      if (genreField.contains(';') || genreField.contains('/') ||
          genreField.contains('|') || genreField.contains(',')) {
        // Parse delimited genres within single field
        allGenres.addAll(GenreTag.fromString(genreField).value);
      } else {
        allGenres.add(genreField);
      }
    }

    return [GenreTag(allGenres)];
  }

  Uint8List writeToContainer({required List<MetadataTag> tags}) {
    final genreTag = tags.whereType<GenreTag>().firstOrNull;
    if (genreTag != null) {
      // Write separate GENRE=value fields (Vorbis native multi-value support)
      for (final genre in genreTag.value) {
        writeComment('GENRE', genre);
      }
    }
  }
}

// ID3v1 codec handling - single genre only
class Id3v1Codec {
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    final genreByte = containerBytes[127]; // Last byte is genre
    final genreName = _id3v1GenreTable[genreByte] ?? 'Unknown';
    return [GenreTag.single(genreName)];
  }

  Uint8List writeToContainer({required List<MetadataTag> tags}) {
    final genreTag = tags.whereType<GenreTag>().firstOrNull;
    if (genreTag != null && genreTag.value.isNotEmpty) {
      // Use first genre for ID3v1 (single genre limitation)
      final firstGenre = genreTag.value.first;
      final genreByte = _genreNameToId3v1Byte(firstGenre);
      // ... write genre byte to position 127
    }
  }
}
```

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

final class GenreTag extends MetadataTag<List<String>> {
  const GenreTag(List<String> value, {TagProvenance provenance = const TagProvenance.none()})
      : super(value: value, key: TagKey.genre, provenance: provenance);

  /// Convenience constructor for single genre
  GenreTag.single(String genre, {TagProvenance provenance = const TagProvenance.none()})
      : this([genre], provenance: provenance);

  /// Creates GenreTag from delimited string with automatic delimiter detection
  GenreTag.fromString(String genreString, {TagProvenance provenance = const TagProvenance.none()})
      : this(_parseGenreString(genreString), provenance: provenance);

  /// Creates GenreTag from ID3v2.4 null-terminated string
  GenreTag.fromId3v24String(String genreString, {TagProvenance provenance = const TagProvenance.none()})
      : this(genreString.split('\0').where((g) => g.isNotEmpty).toList(), provenance: provenance);

  /// Creates GenreTag from ID3v2.3 slash-separated string
  GenreTag.fromId3v23String(String genreString, {TagProvenance provenance = const TagProvenance.none()})
      : this(genreString.split('/').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
              provenance: provenance);

  /// Encodes genres using the specified delimiter
  String toEncodedString([String delimiter = ';']) => value.join(delimiter);

  /// Encodes genres for ID3v2.4 using null-terminated strings
  String toId3v24String() => value.join('\0');

  /// Encodes genres for ID3v2.3 using slash separation
  String toId3v23String() => value.join('/');

  /// Parses genre string with automatic delimiter detection
  static List<String> _parseGenreString(String genreString) {
    if (genreString.trim().isEmpty) return [];

    // Handle null-terminated strings (ID3v2.4)
    if (genreString.contains('\0')) {
      return genreString.split('\0').where((g) => g.isNotEmpty).toList();
    }

    // Common delimiters used by different systems
    final delimiters = ['/', ';', '|', ',', '\\'];

    // Find the most likely delimiter by counting occurrences
    String bestDelimiter = '/'; // default to slash (ID3v2.3 standard)
    int maxCount = 0;

    for (final delimiter in delimiters) {
      final count = delimiter.allMatches(genreString).length;
      if (count > maxCount) {
        maxCount = count;
        bestDelimiter = delimiter;
      }
    }

    // If no delimiters found, treat as single genre
    if (maxCount == 0) {
      return [genreString.trim()];
    }

    // Split by the best delimiter and clean up
    return genreString
        .split(bestDelimiter)
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
  }

  @override
  GenreTag withProvenance(TagProvenance newProvenance) =>
      GenreTag(value, provenance: newProvenance);
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

// Example capability definitions showing genre as multi-valued
const vorbisCapability = TagCapability(
  containerKind: ContainerKind.vorbis,
  containerVersion: '',
  semanticsByKey: {
    TagKey.genre: TagSemantics(multiValued: true), // Vorbis supports multiple GENRE fields
    TagKey.artwork: TagSemantics(multiValued: true), // Multiple artwork blocks
    // ... other fields
  },
);

const id3v24Capability = TagCapability(
  containerKind: ContainerKind.id3v2,
  containerVersion: '2.4',
  semanticsByKey: {
    TagKey.genre: TagSemantics(multiValued: false), // ID3v2.4 uses single TCON with null-terminated strings
    TagKey.artwork: TagSemantics(multiValued: true), // Multiple APIC frames
    // ... other fields
  },
);

const id3v23Capability = TagCapability(
  containerKind: ContainerKind.id3v2,
  containerVersion: '2.3',
  semanticsByKey: {
    TagKey.genre: TagSemantics(multiValued: false), // ID3v2.3 uses single TCON with slash-separated strings
    TagKey.artwork: TagSemantics(multiValued: true), // Multiple APIC frames
    // ... other fields
  },
);
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

### Genre Handling Strategy

The GenreTag implementation supports multiple genres with format-specific encoding/decoding, maintaining compatibility with the actual ID3v2 specifications and other container formats:

```dart
// Internal representation: List<String> for easy access
final genres = GenreTag(['Rock', 'Alternative', 'Indie']);

// Format-specific parsing
final fromId3v24 = GenreTag.fromId3v24String("Rock\0Alternative\0Indie");  // ID3v2.4 null-terminated
final fromId3v23 = GenreTag.fromId3v23String("Rock/Alternative/Indie");    // ID3v2.3 slash-separated
final fromGeneric = GenreTag.fromString("Rock;Alternative;Indie");         // Auto-detection

// All result in: ['Rock', 'Alternative', 'Indie']

// Format-specific encoding
final id3v24Encoded = genres.toId3v24String();    // "Rock\0Alternative\0Indie"
final id3v23Encoded = genres.toId3v23String();    // "Rock/Alternative/Indie"
final mp4Encoded = genres.toEncodedString(';');   // "Rock;Alternative;Indie"
final humanEncoded = genres.toEncodedString(', '); // "Rock, Alternative, Indie"

// Convenience for single genre
final singleGenre = GenreTag.single('Jazz');
```

**ID3v2 Version Differences:**

- **ID3v2.4**: Uses null-terminated strings in TCON frame (`Rock\0Alternative\0Indie`)
- **ID3v2.3/v2.2**: Uses slash-separated strings in TCON frame (`Rock/Alternative/Indie`)
- **Automatic Detection**: `fromString()` detects null terminators first, then falls back to delimiter analysis

**Delimiter Detection Algorithm:**

1. Check for null terminators first (ID3v2.4 format)
2. Scan input string for common delimiters: `/`, `;`, `|`, `,`, `\`
3. Count occurrences of each delimiter
4. Use the most frequent delimiter for splitting (defaults to `/` for ID3v2.3 compatibility)
5. If no delimiters found, treat as single genre
6. Trim whitespace and filter empty values

**Container Format Mapping:**

- **ID3v2.4**: TCON frame stores null-terminated strings (`Rock\0Alternative\0Indie`)
- **ID3v2.3/v2.2**: TCON frame stores slash-separated genres (`Rock/Alternative/Indie`)
- **Vorbis**: Multiple GENRE fields supported natively (one per genre)
- **MP4**: ©gen atom stores semicolon-separated genres (`Rock;Alternative`)
- **ID3v1**: Single genre byte mapped to standard genre name
- **Legacy Systems**: Various delimiters automatically detected and parsed

**Benefits:**

- Users can access individual genres without manual parsing
- Automatic detection handles files from different tagging systems
- Container codecs handle encoding/decoding with appropriate delimiters
- Maintains backward compatibility with single-genre systems
- Supports both multi-valued and single-valued container formats
- Robust parsing handles mixed or inconsistent delimiter usage

**Backward Compatibility:**

- Existing code expecting `String` genre values will need updates
- Migration path: `GenreTag.single(oldStringValue)` for single genres
- Container formats continue to work with existing files
- API breaking change requires major version bump
- Automatic parsing handles legacy files with various delimiter formats

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

````dart
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
````

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
