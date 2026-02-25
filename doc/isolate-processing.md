# Isolate-Based Processing

This guide covers using Phonic's isolate-based processing methods for non-blocking metadata extraction in Flutter and Dart applications.

## Overview

Phonic provides isolate-based factory methods that process audio file metadata in background isolates, preventing UI blocking and enabling parallel processing of multiple files.

## When to Use Isolates

### ✅ Use Isolate Methods When:

- **UI responsiveness is critical** - Flutter apps where blocking the main thread causes UI jank
- **Processing large files** - Audio files >10MB where processing takes >20ms
- **Batch processing** - Processing multiple files where parallel execution provides benefits
- **Background processing** - Operations that can benefit from running on separate CPU cores

### ❌ Use Standard Methods When:

- **Small files** - Files <1MB where isolate overhead outweighs benefits
- **CLI tools** - Command-line applications where blocking is acceptable
- **Single operations** - One-off metadata reads where simplicity is preferred
- **Immediate error handling** - When you need synchronous exception handling

## API Methods

### `fromFileInIsolate(String path)`

Loads an audio file and extracts metadata in a background isolate.

```dart
// Load file in background
final audioFile = await Phonic.fromFileInIsolate('/music/song.mp3');

// Access metadata normally - same API as standard method
final title = audioFile.getTag(TagKey.title);
print('Title: ${title?.value}');

// Clean up
audioFile.dispose();
```

### `fromBytesInIsolate(Uint8List bytes, [String? filename])`

Processes audio bytes and extracts metadata in a background isolate.

```dart
// From network
final response = await http.get(audioUrl);
final audioFile = await Phonic.fromBytesInIsolate(
  response.bodyBytes,
  'downloaded.mp3',
);

// From database
final audioData = await database.getAudioBlob(id);
final audioFile = await Phonic.fromBytesInIsolate(audioData);
```

## Usage Examples

### Basic Usage

```dart
import 'package:phonic/phonic.dart';

Future<void> extractMetadata(String filePath) async {
  // Process in background isolate
  final audioFile = await Phonic.fromFileInIsolate(filePath);
  
  // Access tags normally
  final title = audioFile.getTag(TagKey.title);
  final artist = audioFile.getTag(TagKey.artist);
  
  print('Title: ${title?.value}');
  print('Artist: ${artist?.value}');
  
  audioFile.dispose();
}
```

### Batch Processing

Process multiple files in parallel:

```dart
Future<List<String>> extractTitlesFromFiles(List<String> filePaths) async {
  // Create futures for parallel processing
  final futures = filePaths.map((path) async {
    final audioFile = await Phonic.fromFileInIsolate(path);
    final title = audioFile.getTag(TagKey.title);
    audioFile.dispose();
    return title?.value ?? 'Unknown';
  });
  
  // Wait for all to complete
  return await Future.wait(futures);
}
```

### Flutter UI Integration

Keep your Flutter UI responsive:

```dart
class MusicLibraryScreen extends StatefulWidget {
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  List<SongMetadata> _songs = [];
  bool _loading = false;
  
  Future<void> _loadMusicLibrary() async {
    setState(() => _loading = true);
    
    final files = await _discoverAudioFiles();
    
    // Process in parallel without blocking UI
    final futures = files.map((file) async {
      final audioFile = await Phonic.fromFileInIsolate(file.path);
      final metadata = SongMetadata(
        title: audioFile.getTag(TagKey.title)?.value ?? 'Unknown',
        artist: audioFile.getTag(TagKey.artist)?.value ?? 'Unknown',
        album: audioFile.getTag(TagKey.album)?.value ?? 'Unknown',
      );
      audioFile.dispose();
      return metadata;
    });
    
    final songs = await Future.wait(futures);
    
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading 
        ? CircularProgressIndicator()
        : ListView.builder(
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          ),
    );
  }
}
```

### Smart Processing Strategy

Choose method based on file size:

```dart
Future<PhonicAudioFile> loadAudioFile(String path) async {
  final file = File(path);
  final fileSize = await file.length();
  
  // Use isolate for large files, standard for small files
  if (fileSize > 100 * 1024) { // >100KB
    print('Using isolate for large file');
    return Phonic.fromFileInIsolate(path);
  } else {
    print('Using standard method for small file');
    return Phonic.fromFileAsync(path);
  }
}
```

### Error Handling

Error handling works the same as standard methods:

```dart
Future<void> processAudioFile(String path) async {
  try {
    final audioFile = await Phonic.fromFileInIsolate(path);
    
    // Process metadata...
    
    audioFile.dispose();
  } on FileSystemException catch (e) {
    print('File error: ${e.message}');
  } on UnsupportedFormatException catch (e) {
    print('Unsupported format: ${e.message}');
  } catch (e) {
    print('Unexpected error: $e');
  }
}
```

## Performance Characteristics

### Overhead

- **Isolate spawn**: ~5-10ms
- **Data transfer**: Minimal for metadata (bytes are shared where possible)
- **Reconstruction**: ~1-2ms

### Breakeven Point

Isolate methods become beneficial when:
- Processing time >20ms (typically files >10MB)
- Processing multiple files in parallel
- UI responsiveness is critical

### Benchmarks

Typical performance on modern hardware:

| File Size | Standard | Isolate | Benefit |
|-----------|----------|---------|---------|
| 1MB       | 5ms      | 15ms    | -10ms (overhead) |
| 10MB      | 50ms     | 45ms    | +5ms (slight gain) |
| 50MB      | 250ms    | 180ms   | +70ms (28% faster) |
| 10 files (parallel) | 500ms | 180ms | +320ms (64% faster) |

## Implementation Details

### Processing Flow

1. **Request Creation**: Package file bytes and filename
2. **Isolate Execution**: Spawn background isolate
3. **Format Detection**: Detect audio format in isolate
4. **Tag Extraction**: Parse and decode metadata
5. **Serialization**: Convert tags to transferable format
6. **Transfer**: Send simplified tag data back
7. **Reconstruction**: Rebuild PhonicAudioFile in main isolate

### Data Transfer

The isolate methods transfer:
- ✅ Original file bytes (shared memory, zero-copy where supported)
- ✅ Tag keys and primitive values (strings, ints, lists)
- ❌ NOT transferred: Artwork data (uses lazy loading from original bytes)
- ❌ NOT transferred: Internal codec state (reconstructed)

### Artwork Handling

Artwork tags use lazy loading and remain as loaders referencing the original file bytes, avoiding expensive data transfer:

```dart
final audioFile = await Phonic.fromFileInIsolate('song.mp3');
final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;

// Artwork data loads on-demand from original bytes
final imageBytes = await artworkTag?.value.data;
```

## API Compatibility

The isolate methods return the exact same `PhonicAudioFile` interface:

```dart
// These are functionally identical after loading:
final audioFile1 = await Phonic.fromFileAsync('song.mp3');
final audioFile2 = await Phonic.fromFileInIsolate('song.mp3');

// Both support the same operations:
audioFile1.getTag(TagKey.title);
audioFile2.getTag(TagKey.title);

audioFile1.setTag(TitleTag('New Title'));
audioFile2.setTag(TitleTag('New Title'));

await audioFile1.encode();
await audioFile2.encode();
```

## Best Practices

### 1. Use for Large Collections

```dart
// ✅ Good: Parallel processing of collection
Future<void> processLibrary(List<String> files) async {
  final futures = files.map((f) => Phonic.fromFileInIsolate(f));
  final audioFiles = await Future.wait(futures);
  // Process audioFiles...
}
```

### 2. Don't Overuse for Small Files

```dart
// ❌ Bad: Isolate overhead not justified
final smallFile = await Phonic.fromFileInIsolate('small.mp3'); // 50KB

// ✅ Good: Use standard method for small files
final smallFile = await Phonic.fromFileAsync('small.mp3');
```

### 3. Dispose Properly

```dart
// ✅ Good: Always dispose
Future<void> processSong(String path) async {
  final audioFile = await Phonic.fromFileInIsolate(path);
  try {
    // Use audioFile...
  } finally {
    audioFile.dispose(); // Always cleanup
  }
}
```

### 4. Handle Errors Appropriately

```dart
// ✅ Good: Handle specific exceptions
try {
  final audioFile = await Phonic.fromFileInIsolate(path);
  // Process...
} on UnsupportedFormatException {
  // Skip unsupported file
} on FileSystemException {
  // Handle file access error
}
```

## Migration Guide

### From Standard Methods

Migrating is straightforward - just add `InIsolate` to the method name:

```dart
// Before
final audioFile = await Phonic.fromFileAsync(path);

// After
final audioFile = await Phonic.fromFileInIsolate(path);
```

Everything else stays the same!

### Gradual Adoption

You can mix both approaches:

```dart
// Use standard for synchronous reads
final config = await Phonic.fromFileAsync('config.mp3');

// Use isolate for user-initiated operations
final userFile = await Phonic.fromFileInIsolate(userSelectedPath);
```

## See Also

- [Getting Started](getting-started.md) - Basic Phonic usage
- [Performance Optimization](best-practices.md#performance-optimization) - General performance tips
- [Streaming Operations](streaming-operations.md) - Batch processing patterns
- [Examples](../example/isolate_processing_example.dart) - Complete code examples
