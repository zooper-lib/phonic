# Best Practices

This guide provides recommendations and best practices for using Phonic effectively in your applications.

## Memory Management

### Resource Cleanup

Always dispose of audio file instances to free memory:

```dart
// ❌ Memory leak - missing dispose
Future<String> badExample(String filePath) async {
  final audioFile = await Phonic.fromFileAsync(filePath);
  final title = audioFile.getTag(TagKey.title);
  return title?.value ?? 'Unknown';
  // Missing: audioFile.dispose();
}

// ✅ Proper resource management
Future<String> goodExample(String filePath) async {
  final audioFile = await Phonic.fromFileAsync(filePath);
  try {
    final title = audioFile.getTag(TagKey.title);
    return title?.value ?? 'Unknown';
  } finally {
    audioFile.dispose();
  }
}

// ✅ Helper function for automatic cleanup
Future<T> withAudioFile<T>(
  String filePath,
  Future<T> Function(PhonicAudioFile) action,
) async {
  final audioFile = await Phonic.fromFileAsync(filePath);
  try {
    return await action(audioFile);
  } finally {
    audioFile.dispose();
  }
}
```

### Large Collection Processing

Use streaming operations for large collections:

```dart
// ❌ Loading everything into memory
Future<void> badBatchProcessing(List<String> filePaths) async {
  final allFiles = <PhonicAudioFile>[];

  // Loads all files at once - memory intensive
  for (final path in filePaths) {
    allFiles.add(await Phonic.fromFileAsync(path));
  }

  // Process all at once
  for (final file in allFiles) {
    // Process file...
    file.dispose();
  }
}

// ✅ Stream-based processing
Future<void> goodBatchProcessing(List<String> filePaths) async {
  final processor = StreamingAudioProcessor(
    config: StreamingConfig(
      batchSize: 50,
      memoryLimitMB: 100,
    ),
  );

  await processor.processFiles(
    filePaths: filePaths,
    processor: (audioFile, index, total) async {
      // Process one file at a time
      return ProcessingResult.success();
    },
  );
}
```

## Error Handling

### Defensive Programming

Always handle potential errors gracefully:

```dart
// ✅ Comprehensive error handling
Future<Map<String, String>> safeReadMetadata(String filePath) async {
  try {
    final audioFile = await Phonic.fromFileAsync(filePath);

    try {
      return {
        'title': audioFile.getTag(TagKey.title)?.value ?? '',
        'artist': audioFile.getTag(TagKey.artist)?.value ?? '',
        'album': audioFile.getTag(TagKey.album)?.value ?? '',
      };
    } finally {
      audioFile.dispose();
    }

  } on UnsupportedFormatException catch (e) {
    print('Unsupported format: ${e.message}');
    return {'error': 'Unsupported format'};

  } on CorruptedContainerException catch (e) {
    print('Corrupted file: ${e.message}');
    return {'error': 'Corrupted file'};

  } on FileSystemException catch (e) {
    print('File system error: ${e.message}');
    return {'error': 'File not accessible'};

  } catch (e) {
    print('Unexpected error: $e');
    return {'error': 'Unexpected error'};
  }
}
```

### Validation

Validate input before processing:

```dart
// ✅ Input validation
bool isValidAudioFile(String filePath) {
  // Check file exists
  if (!File(filePath).existsSync()) {
    return false;
  }

  // Check file extension
  final extension = path.extension(filePath).toLowerCase();
  const supportedExtensions = ['.mp3', '.flac', '.ogg', '.opus', '.m4a', '.mp4'];

  if (!supportedExtensions.contains(extension)) {
    return false;
  }

  // Check file size (not too small or too large)
  final stat = File(filePath).statSync();
  if (stat.size < 1024 || stat.size > 100 * 1024 * 1024) {
    return false;
  }

  return true;
}

// Use validation before processing
Future<void> processFileWithValidation(String filePath) async {
  if (!isValidAudioFile(filePath)) {
    print('Invalid audio file: $filePath');
    return;
  }

  // Safe to process
  await withAudioFile(filePath, (audioFile) async {
    // Process the file...
  });
}
```

## Performance Optimization

### Lazy Loading

Use lazy loading for expensive operations:

```dart
// ✅ Lazy artwork loading
class ArtworkInfo {
  final String mimeType;
  final ArtworkType type;
  final String? description;
  final Future<Uint8List> Function() _dataLoader;

  ArtworkInfo({
    required this.mimeType,
    required this.type,
    this.description,
    required Future<Uint8List> Function() dataLoader,
  }) : _dataLoader = dataLoader;

  // Data is loaded only when needed
  Future<Uint8List> get data => _dataLoader();
}

// Extract artwork info without loading image data
ArtworkInfo? getArtworkInfo(PhonicAudioFile audioFile) {
  final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
  if (artworkTag == null) return null;

  final artwork = artworkTag.value;
  return ArtworkInfo(
    mimeType: artwork.mimeType,
    type: artwork.type,
    description: artwork.description,
    dataLoader: () => artwork.data,
  );
}
```

### Caching

Implement caching for frequently accessed data:

```dart
// ✅ Metadata caching
class MetadataCache {
  final Map<String, Map<String, String>> _cache = {};
  final int maxEntries;

  MetadataCache({this.maxEntries = 1000});

  Future<Map<String, String>> getMetadata(String filePath) async {
    // Check cache first
    if (_cache.containsKey(filePath)) {
      return _cache[filePath]!;
    }

    // Load from file
    final metadata = await withAudioFile(filePath, (audioFile) async {
      return {
        'title': audioFile.getTag(TagKey.title)?.value ?? '',
        'artist': audioFile.getTag(TagKey.artist)?.value ?? '',
        'album': audioFile.getTag(TagKey.album)?.value ?? '',
      };
    });

    // Cache result
    _cache[filePath] = metadata;

    // Limit cache size
    if (_cache.length > maxEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    return metadata;
  }

  void clear() => _cache.clear();
}
```

## Metadata Best Practices

### Consistent Data Format

Maintain consistent metadata formats:

```dart
// ✅ Consistent metadata formatting
class MetadataFormatter {
  static String formatTitle(String title) {
    return title.trim()
        .replaceAll(RegExp(r'\\s+'), ' ')  // Normalize whitespace
        .split(' ')
        .map(_capitalizeWord)
        .join(' ');
  }

  static String formatArtist(String artist) {
    // Handle featuring artists consistently
    return artist.trim()
        .replaceAll(RegExp(r'\\bfeat\\.?\\s', caseSensitive: false), 'feat. ')
        .replaceAll(RegExp(r'\\bft\\.?\\s', caseSensitive: false), 'feat. ');
  }

  static List<String> formatGenres(List<String> genres) {
    return genres
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .map(_normalizeGenre)
        .toSet()  // Remove duplicates
        .toList();
  }

  static String _capitalizeWord(String word) {
    if (word.isEmpty) return word;

    // Don't capitalize certain words unless they're the first word
    const lowercaseWords = {'a', 'an', 'and', 'at', 'by', 'for', 'in', 'of', 'on', 'the', 'to'};

    if (lowercaseWords.contains(word.toLowerCase())) {
      return word.toLowerCase();
    }

    return word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();
  }

  static String _normalizeGenre(String genre) {
    const genreMap = {
      'rock': 'Rock',
      'pop': 'Pop',
      'jazz': 'Jazz',
      'blues': 'Blues',
      'electronic': 'Electronic',
      'hip-hop': 'Hip-Hop',
      'hip hop': 'Hip-Hop',
      'r&b': 'R&B',
      'rnb': 'R&B',
    };

    return genreMap[genre.toLowerCase()] ?? genre;
  }
}

// Apply consistent formatting
Future<void> normalizeMetadata(PhonicAudioFile audioFile) async {
  final title = audioFile.getTag(TagKey.title);
  if (title != null) {
    final formatted = MetadataFormatter.formatTitle(title.value);
    if (formatted != title.value) {
      audioFile.setTag(TitleTag(formatted));
    }
  }

  final artist = audioFile.getTag(TagKey.artist);
  if (artist != null) {
    final formatted = MetadataFormatter.formatArtist(artist.value);
    if (formatted != artist.value) {
      audioFile.setTag(ArtistTag(formatted));
    }
  }

  final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
  if (genreTag != null) {
    final formatted = MetadataFormatter.formatGenres(genreTag.value);
    if (!_listsEqual(formatted, genreTag.value)) {
      audioFile.setTag(GenreTag(formatted));
    }
  }
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

### Field Validation

Phonic automatically validates metadata values when creating tags:

```dart
// ✅ Built-in validation - these will throw ValidationException for invalid values
try {
  audioFile.setTag(RatingTag(150)); // Error - rating must be 0-100
} catch (e) {
  print('Validation failed: $e');
}

try {
  audioFile.setTag(YearTag(1800)); // Error - year must be reasonable
} catch (e) {
  print('Invalid year: $e');
}

try {
  audioFile.setTag(TrackNumberTag(-1)); // Error - track must be positive
} catch (e) {
  print('Invalid track number: $e');
}
```

**Automatic Validation Rules:**

- **Rating**: Must be 0-100
- **Year**: Must be 1900 to current year + 1
- **Track/Disc numbers**: Must be positive integers
- **BPM**: Must be positive, typically 1-300
- **Text fields**: Automatically cleaned of control characters
- **Genres**: Individual genres limited to reasonable length

### Tag Validation Checking

```dart
// Check if a tag would be valid before setting
final tag = audioFile.getTag(TagKey.rating) as RatingTag?;
if (tag != null) {
  // Rating is guaranteed to be 0-100 due to built-in validation
  print('Rating: ${tag.value}/100');
}
```

## Error Handling

Phonic handles validation errors automatically:

```dart
// ✅ Built-in error handling
try {
  final audioFile = await Phonic.openFile('song.mp3');

  // These operations are automatically validated
  audioFile.setTag(TitleTag('Song Title'));
  audioFile.setTag(RatingTag(95)); // Automatically validated 0-100
  audioFile.setTag(YearTag(2024)); // Automatically validated range

  await audioFile.save();

} catch (ValidationException e) {
  print('Validation error: ${e.message}');
} catch (PhonicException e) {
  print('Phonic error: ${e.message}');
}
```

## Artwork Optimization

### Size Management

Phonic provides built-in artwork optimization options:

```dart
// ✅ Use optimized artwork loading for large images
final artwork = OptimizedArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.frontCover,
  description: 'Album cover',
  dataLoader: () => File('large_cover.jpg').readAsBytes(),
  // Phonic automatically handles caching and memory management
);

audioFile.setTag(ArtworkTag(artwork));
```

**Built-in Optimization Features:**

- **Lazy Loading**: Images loaded only when accessed
- **Automatic Caching**: Frequently accessed images cached in memory
- **Memory Management**: Large images automatically streamed
- **Format Detection**: MIME types detected automatically

### Artwork Size Considerations

```dart
final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
if (artworkTag != null) {
  // Phonic provides size information without loading the full image
  final imageData = await artworkTag.value.data;
  final sizeKB = (imageData.length / 1024).round();

  if (sizeKB > 1000) { // > 1MB
    print('Large artwork detected: ${sizeKB}KB');
  }
}
```

## Batch Operations

Use Phonic's built-in batch processing for multiple files:

```dart
// ✅ Efficient batch operations using StreamingAudioProcessor
final processor = StreamingAudioProcessor();

await processor.processFiles(
  filePaths: audioFiles,
  processor: (audioFile, index, total) async {
    // Apply consistent metadata across files
    audioFile.setTag(AlbumTag('My Album'));
    audioFile.setTag(AlbumArtistTag('Various Artists'));

    return ProcessingResult.success();
  },
);
```

## Cross-Format Compatibility

### Universal Metadata Approach

Use core tags that work across all formats:

```dart
// ✅ Use basic tags supported by all formats
final basicTags = {
  'title': 'Song Title',
  'artist': 'Artist Name',
  'album': 'Album Name',
  'year': 2024,
  'trackNumber': 5,
  'genre': ['Rock'],
};

// Apply basic metadata
audioFile.setTag(TitleTag(basicTags['title'] as String));
audioFile.setTag(ArtistTag(basicTags['artist'] as String));
audioFile.setTag(AlbumTag(basicTags['album'] as String));
audioFile.setTag(YearTag(basicTags['year'] as int));
audioFile.setTag(TrackNumberTag(basicTags['trackNumber'] as int));
audioFile.setTag(GenreTag(basicTags['genre'] as List<String>));
```

### Format-Specific Features

Check format capabilities before using advanced features:

```dart
// Check if format supports advanced features
final allTags = audioFile.getAllTags();
final hasId3v2 = allTags.any((tag) =>
    tag.provenance.containerKind == ContainerKind.id3v2);

if (hasId3v2) {
  // ID3v2 supports advanced features
  audioFile.setTag(BpmTag(120));
  audioFile.setTag(MusicalKeyTag('C major'));
  audioFile.setTag(LyricsTag('Song lyrics...'));
} else {
  print('Format has limited feature support - using basic metadata only');
}
```

````

## Testing and Quality Assurance

### Metadata Verification

Verify metadata integrity using Phonic's built-in validation:

```dart
// ✅ Built-in verification through tag access
final audioFile = await Phonic.openFile('song.mp3');

try {
  // Read back the values - Phonic validates on read
  final title = audioFile.getTag(TagKey.title)?.value;
  final artist = audioFile.getTag(TagKey.artist)?.value;
  final album = audioFile.getTag(TagKey.album)?.value;

  // Values are automatically validated and normalized
  print('Verified metadata:');
  print('  Title: $title');
  print('  Artist: $artist');
  print('  Album: $album');

} catch (PhonicException e) {
  print('Metadata validation failed: ${e.message}');
} finally {
  audioFile.dispose();
}
````

````

### Performance Monitoring

Monitor performance for optimization opportunities:

```dart
// ✅ Performance monitoring
class PerformanceMonitor {
  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, List<int>> _timings = {};

  void startTiming(String operation) {
    _stopwatch.reset();
    _stopwatch.start();
  }

  void endTiming(String operation) {
    _stopwatch.stop();
    _timings.putIfAbsent(operation, () => []).add(_stopwatch.elapsedMilliseconds);
  }

  void printStats() {
    print('Performance Statistics:');
    for (final entry in _timings.entries) {
      final times = entry.value;
      final avg = times.reduce((a, b) => a + b) / times.length;
      final min = times.reduce((a, b) => a < b ? a : b);
      final max = times.reduce((a, b) => a > b ? a : b);

      print('${entry.key}:');
      print('  Count: ${times.length}');
      print('  Average: ${avg.toStringAsFixed(1)}ms');
      print('  Min: ${min}ms');
      print('  Max: ${max}ms');
    }
  }
}

// Use performance monitoring
final monitor = PerformanceMonitor();

Future<void> monitoredOperation(String filePath) async {
  monitor.startTiming('file_load');
  final audioFile = await Phonic.fromFileAsync(filePath);
  monitor.endTiming('file_load');

  try {
    monitor.startTiming('tag_read');
    final metadata = {
      'title': audioFile.getTag(TagKey.title)?.value,
      'artist': audioFile.getTag(TagKey.artist)?.value,
    };
    monitor.endTiming('tag_read');

    monitor.startTiming('tag_write');
    audioFile.setTag(TitleTag('New Title'));
    monitor.endTiming('tag_write');

    monitor.startTiming('encode');
    final bytes = await audioFile.encode();
    monitor.endTiming('encode');

  } finally {
    audioFile.dispose();
  }
}

// Print performance statistics
monitor.printStats();
````

## Documentation and Code Organization

### Clear API Usage

Document your usage patterns:

```dart
/// Audio metadata service with consistent error handling and resource management.
class AudioMetadataService {
  final MetadataCache _cache;
  final PerformanceMonitor _monitor;

  AudioMetadataService()
    : _cache = MetadataCache(maxEntries: 1000),
      _monitor = PerformanceMonitor();

  /// Reads basic metadata from an audio file.
  ///
  /// Returns null if the file cannot be read or is not supported.
  /// Uses caching to improve performance for repeated access.
  Future<UniversalMetadata?> readMetadata(String filePath) async {
    try {
      _monitor.startTiming('read_metadata');

      return await withAudioFile(filePath, (audioFile) async {
        return UniversalMetadata(
          title: audioFile.getTag(TagKey.title)?.value ?? 'Unknown',
          artist: audioFile.getTag(TagKey.artist)?.value ?? 'Unknown',
          album: audioFile.getTag(TagKey.album)?.value ?? 'Unknown',
          year: (audioFile.getTag(TagKey.year) as YearTag?)?.value,
          trackNumber: (audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value,
          genres: (audioFile.getTag(TagKey.genre) as GenreTag?)?.value ?? [],
        );
      });

    } catch (e) {
      print('Failed to read metadata from $filePath: $e');
      return null;
    } finally {
      _monitor.endTiming('read_metadata');
    }
  }

  /// Updates metadata in an audio file.
  ///
  /// Returns true if successful, false otherwise.
  /// Validates metadata before writing and verifies after writing.
  Future<bool> updateMetadata(String filePath, UniversalMetadata metadata) async {
    try {
      _monitor.startTiming('update_metadata');

      return await withAudioFile(filePath, (audioFile) async {
        // Apply metadata
        metadata.applyTo(audioFile);

        // Save changes
        if (audioFile.isDirty) {
          final bytes = await audioFile.encode();
          await File(filePath).writeAsBytes(bytes);
          audioFile.markClean();

          // Verify write
          return await verifyMetadataWrite(filePath, metadata);
        }

        return true;
      });

    } catch (e) {
      print('Failed to update metadata for $filePath: $e');
      return false;
    } finally {
      _monitor.endTiming('update_metadata');
    }
  }

  /// Cleans up resources and prints performance statistics.
  void dispose() {
    _cache.clear();
    _monitor.printStats();
  }
}
```

## Summary Checklist

✅ **Always dispose audio file instances**  
✅ **Use try-finally or helper functions for resource management**  
✅ **Handle all relevant exception types**  
✅ **Validate input before processing**  
✅ **Use streaming for large collections**  
✅ **Implement caching for frequently accessed data**  
✅ **Normalize and validate metadata**  
✅ **Optimize artwork size and embedding decisions**  
✅ **Design for cross-format compatibility**  
✅ **Monitor performance and optimize bottlenecks**  
✅ **Document your API usage patterns**  
✅ **Verify metadata integrity after writing**

Following these best practices will help you build robust, efficient, and maintainable applications using Phonic.
