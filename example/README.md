# Phonic Library Examples

This directory contains comprehensive examples demonstrating how to use the Phonic audio metadata library in various scenarios. Each example file focuses on different aspects of the library and provides practical, real-world usage patterns.

## Example Files Overview

### 1. Basic Usage Examples (`basic_usage_example.dart`)

**Purpose**: Demonstrates the fundamental operations of the Phonic library.

**What you'll learn**:
- Loading audio files from different sources
- Reading various types of metadata tags (text, numeric, multi-valued)
- Modifying and updating tag values
- Working with provenance information
- Saving changes back to files
- Proper resource management and disposal

**Key concepts covered**:
- `Phonic.fromFileAsync()` and `Phonic.fromBytes()` factory methods
- Tag reading with `getTag()` and `getTags()`
- Tag modification with `setTag()`
- Multi-valued tags like `GenreTag`
- Artwork handling with lazy loading
- Batch processing patterns

**Run with**: `dart run example/basic_usage_example.dart`

### 2. Format-Specific Examples (`format_specific_examples.dart`)

**Purpose**: Shows how the unified API works consistently across different audio formats while handling format-specific features.

**What you'll learn**:
- MP3 format with multiple ID3 versions (v1, v2.2, v2.3, v2.4)
- FLAC format with Vorbis Comments
- OGG Vorbis format handling
- Opus format support
- MP4/M4A format with iTunes-style atoms
- Format detection and capability checking
- Cross-format compatibility and conversion scenarios

**Key concepts covered**:
- Format precedence rules (ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1 for MP3)
- Container-specific encoding (null-terminated vs slash-separated genres)
- Format capabilities and constraints
- Automatic format detection
- Cross-format metadata transfer

**Run with**: `dart run example/format_specific_examples.dart`

### 3. Error Handling Examples (`error_handling_examples.dart`)

**Purpose**: Demonstrates robust error handling and recovery strategies for various failure scenarios.

**What you'll learn**:
- Handling unsupported file formats
- Dealing with corrupted container data
- Tag validation error recovery
- File system error handling
- Memory constraint management
- Recovery strategies and graceful degradation

**Key concepts covered**:
- `UnsupportedFormatException` handling
- `CorruptedContainerException` recovery
- `TagValidationException` correction
- Partial data extraction from damaged files
- Batch processing error tolerance
- Resource cleanup in error scenarios

**Run with**: `dart run example/error_handling_examples.dart`

### 4. Performance Optimization Examples (`performance_optimization_examples.dart`)

**Purpose**: Shows techniques for optimizing performance when working with large audio collections.

**What you'll learn**:
- Lazy loading strategies for artwork and large payloads
- Memory-efficient batch processing
- Caching and resource management
- Performance monitoring and profiling
- Large collection handling techniques
- Memory pressure management

**Key concepts covered**:
- Lazy artwork loading with `ArtworkData`
- Batch processing with proper disposal
- Resource pooling patterns
- Memory usage monitoring
- Throughput optimization
- Streaming processing patterns

**Run with**: `dart run example/performance_optimization_examples.dart`

### 5. Integration Examples (`integration_examples.dart`)

**Purpose**: Demonstrates how to integrate Phonic into real-world applications and systems.

**What you'll learn**:
- Music library management system integration
- Audio file conversion pipeline implementation
- Metadata synchronization service patterns
- Streaming media application integration
- Content management system usage
- Audio analysis pipeline integration
- Backup and restore system implementation

**Key concepts covered**:
- Library management patterns
- Conversion workflow implementation
- Metadata synchronization strategies
- Streaming application architecture
- Content processing pipelines
- Analysis and reporting systems
- Backup/restore mechanisms

**Run with**: `dart run example/integration_examples.dart`

### 6. Existing Specialized Examples

The following examples were already present and demonstrate specific optimization features:

#### `artwork_optimization_example.dart`
- Advanced artwork caching with compression
- Streaming large artwork data
- Memory-efficient image handling
- Performance optimization for artwork operations

#### `memory_efficiency_example.dart`
- String interning for common metadata values
- Memory-efficient tag storage
- Batch processing with memory monitoring
- Performance comparison between approaches

#### `streaming_operations_example.dart`
- Streaming processing for large collections
- Progress reporting and cancellation
- Memory usage monitoring
- Collection analysis patterns

## Getting Started

### Prerequisites

Ensure you have the Phonic library added to your `pubspec.yaml`:

```yaml
dependencies:
  phonic: ^0.0.1
```

### Running Examples

Each example can be run independently:

```bash
# Basic usage
dart run example/basic_usage_example.dart

# Format-specific features
dart run example/format_specific_examples.dart

# Error handling
dart run example/error_handling_examples.dart

# Performance optimization
dart run example/performance_optimization_examples.dart

# Integration patterns
dart run example/integration_examples.dart

# Specialized examples
dart run example/artwork_optimization_example.dart
dart run example/memory_efficiency_example.dart
dart run example/streaming_operations_example.dart
```

## Common Patterns and Best Practices

### 1. Resource Management

Always dispose of `PhonicAudioFile` instances to free resources:

```dart
PhonicAudioFile? audioFile;
try {
  audioFile = await Phonic.fromFileAsync('song.mp3');
  // Use audioFile...
} finally {
  audioFile?.dispose();
}
```

### 2. Error Handling

Use specific exception types for targeted error handling:

```dart
try {
  final audioFile = await Phonic.fromFileAsync('song.mp3');
  // Process file...
} on UnsupportedFormatException catch (e) {
  // Handle unsupported format
} on FileSystemException catch (e) {
  // Handle file access errors
} on TagValidationException catch (e) {
  // Handle validation errors
}
```

### 3. Batch Processing

Process files in batches to manage memory usage:

```dart
const batchSize = 10;
for (int i = 0; i < files.length; i += batchSize) {
  final batch = files.skip(i).take(batchSize);
  final batchFiles = <PhonicAudioFile>[];
  
  try {
    // Load batch
    for (final file in batch) {
      batchFiles.add(await Phonic.fromFileAsync(file));
    }
    
    // Process batch...
  } finally {
    // Dispose entire batch
    for (final audioFile in batchFiles) {
      audioFile.dispose();
    }
  }
}
```

### 4. Lazy Loading

Take advantage of lazy loading for artwork and large data:

```dart
final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
if (artworkTag != null) {
  // Access metadata without loading image
  print('Type: ${artworkTag.value.type}');
  print('MIME: ${artworkTag.value.mimeType}');
  
  // Load image data only when needed
  final imageData = await artworkTag.value.data;
  print('Size: ${imageData.length} bytes');
}
```

### 5. Multi-valued Tags

Handle multi-valued tags like genres properly:

```dart
// Create multi-genre tag
final genres = GenreTag(['Rock', 'Alternative', 'Indie']);

// Parse from various formats
final fromString = GenreTag.fromString('Rock;Alternative;Indie');
final fromId3v24 = GenreTag.fromId3v24String('Rock\0Alternative\0Indie');
final fromId3v23 = GenreTag.fromId3v23String('Rock/Alternative/Indie');

// Format-specific encoding
final id3v24Format = genres.toId3v24String(); // 'Rock\0Alternative\0Indie'
final id3v23Format = genres.toId3v23String(); // 'Rock/Alternative/Indie'
final mp4Format = genres.toEncodedString(';'); // 'Rock;Alternative;Indie'
```

## Format Support Matrix

| Format | Container Types | Supported Features |
|--------|----------------|-------------------|
| MP3 | ID3v1, ID3v2.2, ID3v2.3, ID3v2.4 | All standard tags, artwork, custom fields |
| FLAC | Vorbis Comments | All standard tags, artwork, native multi-values |
| OGG Vorbis | Vorbis Comments | All standard tags, artwork, UTF-8 support |
| Opus | Vorbis Comments | All standard tags, optimized for speech |
| MP4/M4A | iTunes atoms | All standard tags, artwork, freeform atoms |

## Performance Considerations

### Memory Usage
- Artwork is loaded lazily to minimize memory impact
- Use batch processing for large collections
- Dispose of files promptly to free resources
- Consider streaming patterns for very large datasets

### Processing Speed
- Format detection is optimized for common cases
- Codec registries are cached per format
- Repeated operations on the same format are faster
- Use appropriate batch sizes (10-50 files typically optimal)

### Storage Efficiency
- Only modified containers are rewritten during encoding
- Compression is available for artwork caching
- Metadata changes don't require full file rewrites
- Incremental processing reduces I/O overhead

## Troubleshooting

### Common Issues

1. **Memory Usage Growing**: Ensure you're disposing of `PhonicAudioFile` instances
2. **Slow Performance**: Use batch processing and avoid loading unnecessary artwork
3. **Format Detection Fails**: Provide filename hints when using `fromBytes()`
4. **Tag Validation Errors**: Check value ranges and format constraints
5. **Corrupted Files**: Use error handling to skip problematic files gracefully

### Debug Tips

- Enable verbose logging to trace format detection
- Use provenance information to understand tag sources
- Monitor memory usage during batch operations
- Test with various file formats and sizes
- Validate tag values before setting them

## Contributing

When adding new examples:

1. Focus on practical, real-world scenarios
2. Include comprehensive error handling
3. Demonstrate best practices for resource management
4. Provide clear documentation and comments
5. Test with various audio formats and edge cases

## Additional Resources

- [Phonic Library Documentation](../README.md)
- [API Reference](../doc/api/)
- [Format Specifications](../doc/formats/)
- [Performance Guide](../doc/performance/)
- [Migration Guide](../doc/migration/)