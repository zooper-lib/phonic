# Artwork Handling

This guide covers working with embedded artwork (album covers, images) in audio files using Phonic.

## Overview

Phonic provides sophisticated artwork handling with features including:

- Lazy loading for memory efficiency
- Multiple image support per file
- Automatic format detection
- Memory optimization and caching
- Streaming support for large images

## Artwork Data Structure

Artwork is represented by the `ArtworkData` class:

```dart
class ArtworkData {
  final String mimeType;           // Image format (image/jpeg, image/png, etc.)
  final ArtworkType type;          // Purpose/type of image
  final String? description;       // Optional description
  final Future<Uint8List> data;    // Lazy-loaded image data
}
```

## Artwork Types

The `ArtworkType` enum defines different image purposes:

```dart
enum ArtworkType {
  frontCover,           // Front cover (most common)
  backCover,            // Back cover
  leaflet,              // Leaflet/booklet page
  media,                // Media (CD/vinyl) image
  leadArtist,           // Lead artist photo
  artist,               // Artist photo
  conductor,            // Conductor photo
  band,                 // Band/group photo
  composer,             // Composer photo
  lyricist,             // Lyricist photo
  recordingLocation,    // Recording location
  duringRecording,      // During recording
  duringPerformance,    // During performance
  movieScreenCapture,   // Movie/video screen capture
  brightColoredFish,    // A bright colored fish (ID3v2 joke entry)
  illustration,         // Illustration
  bandLogotype,         // Band/artist logotype
  publisherLogotype,    // Publisher/studio logotype
}
```

## Reading Artwork

### Basic Artwork Access

```dart
// Get the primary artwork
final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
if (artworkTag != null) {
  final artwork = artworkTag.value;

  print('MIME type: ${artwork.mimeType}');
  print('Type: ${artwork.type}');
  print('Description: ${artwork.description ?? "None"}');

  // Load the actual image data (lazy-loaded)
  final imageData = await artwork.data;
  print('Image size: ${imageData.length} bytes');

  // Save to file
  await File('cover.jpg').writeAsBytes(imageData);
}
```

### Multiple Artwork Access

```dart
// Get all artwork tags
final artworkTags = audioFile.getTags(TagKey.artwork);

print('Found ${artworkTags.length} artwork images');

for (int i = 0; i < artworkTags.length; i++) {
  final artworkTag = artworkTags[i] as ArtworkTag;
  final artwork = artworkTag.value;

  print('Image ${i + 1}:');
  print('  Type: ${artwork.type}');
  print('  MIME: ${artwork.mimeType}');
  print('  Description: ${artwork.description ?? "None"}');

  // Save each image with a unique name
  final imageData = await artwork.data;
  final extension = _getExtensionFromMime(artwork.mimeType);
  await File('artwork_${i + 1}$extension').writeAsBytes(imageData);
}

String _getExtensionFromMime(String mimeType) {
  switch (mimeType.toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'image/gif':
      return '.gif';
    case 'image/webp':
      return '.webp';
    case 'image/bmp':
      return '.bmp';
    default:
      return '.img';
  }
}
```

### Filtering by Type

```dart
// Find specific artwork types
ArtworkData? findArtworkByType(PhonicAudioFile audioFile, ArtworkType targetType) {
  final artworkTags = audioFile.getTags(TagKey.artwork);

  for (final tag in artworkTags) {
    final artworkTag = tag as ArtworkTag;
    if (artworkTag.value.type == targetType) {
      return artworkTag.value;
    }
  }

  return null;
}

// Usage
final frontCover = findArtworkByType(audioFile, ArtworkType.frontCover);
final backCover = findArtworkByType(audioFile, ArtworkType.backCover);
final artistPhoto = findArtworkByType(audioFile, ArtworkType.artist);

if (frontCover != null) {
  final coverData = await frontCover.data;
  await File('front_cover.jpg').writeAsBytes(coverData);
}
```

## Adding Artwork

### From File

```dart
// Add front cover from file
final coverFile = File('album_cover.jpg');
final coverBytes = await coverFile.readAsBytes();

final artwork = ArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.frontCover,
  description: 'Album front cover',
  dataLoader: () async => coverBytes,
);

audioFile.setTag(ArtworkTag(artwork));
```

### With Lazy Loading

```dart
// Lazy loading - image data loaded only when needed
final artwork = ArtworkData(
  mimeType: MimeType.png.standardName,
  type: ArtworkType.frontCover,
  description: 'Album cover',
  dataLoader: () async {
    // This function is called only when data is accessed
    print('Loading artwork data...');
    return await File('cover.png').readAsBytes();
  },
);

audioFile.setTag(ArtworkTag(artwork));

// Image data is not loaded until here:
final imageData = await artwork.data;
```

### From Network

```dart
import 'dart:io' as io;

// Download and embed artwork from URL
Future<ArtworkData> downloadArtwork(String url) async {
  final client = HttpClient();

  return ArtworkData(
    mimeType: MimeType.jpeg.standardName,
    type: ArtworkType.frontCover,
    description: 'Downloaded from $url',
    dataLoader: () async {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
        return Uint8List.fromList(bytes);
      } else {
        throw Exception('Failed to download artwork: ${response.statusCode}');
      }
    },
  );
}

// Usage
final artwork = await downloadArtwork('https://example.com/cover.jpg');
audioFile.setTag(ArtworkTag(artwork));
```

### Multiple Images

```dart
// Add multiple artwork images
final frontCover = ArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.frontCover,
  description: 'Front cover',
  dataLoader: () => File('front.jpg').readAsBytes(),
);

final backCover = ArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.backCover,
  description: 'Back cover',
  dataLoader: () => File('back.jpg').readAsBytes(),
);

final artistPhoto = ArtworkData(
  mimeType: MimeType.png.standardName,
  type: ArtworkType.artist,
  description: 'Artist photo',
  dataLoader: () => File('artist.png').readAsBytes(),
);

// Add all artwork
audioFile.setTag(ArtworkTag(frontCover));
audioFile.setTag(ArtworkTag(backCover));
audioFile.setTag(ArtworkTag(artistPhoto));
```

## Memory Optimization

### Artwork Cache

Use `ArtworkCache` for memory-efficient artwork handling:

```dart
// Create cache with memory limits
final artworkCache = ArtworkCache(
  maxMemoryBytes: 50 * 1024 * 1024,  // 50MB limit
  compressionThreshold: 512 * 1024,   // Compress images > 512KB
  enableMemoryPressureHandling: true,
  enableCompression: true,
);

// Cache frequently accessed artwork
await artworkCache.put('album_cover', artwork);

// Retrieve from cache (automatically decompressed)
final cachedArtwork = await artworkCache.get('album_cover');
if (cachedArtwork != null) {
  final imageData = await cachedArtwork.data;
  // Use image data...
}

// Monitor cache performance
print('Cache hit rate: ${artworkCache.hitRate.toStringAsFixed(1)}%');
print('Memory usage: ${(artworkCache.memoryUsageBytes / 1024 / 1024).toStringAsFixed(1)} MB');
print('Compression saved: ${artworkCache.compressionRatio.toStringAsFixed(1)}% space');
```

### Optimized Artwork Data

`OptimizedArtworkData` automatically chooses the best loading strategy:

```dart
// Optimized artwork with cache integration
final optimized = OptimizedArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.frontCover,
  description: 'Album cover',
  dataLoader: () => File('large_cover.jpg').readAsBytes(),
  cache: artworkCache,
  cacheKey: 'album_cover',
);

// Automatically determines whether to use caching or streaming
print('Should use streaming: ${optimized.shouldUseStreaming}');
print('Recommended strategy: ${optimized.performanceMetrics.recommendedStrategy}');

audioFile.setTag(ArtworkTag(optimized));
```

## Streaming Large Images

For very large images, use streaming to avoid memory pressure:

```dart
// Create lazy loader for large embedded image
final containerBytes = await File('song_with_large_artwork.mp3').readAsBytes();
final lazyLoader = LazyArtworkLoader(
  containerBytes,
  artworkOffset: 1000,    // Offset where artwork starts
  artworkLength: 8 * 1024 * 1024, // 8MB artwork
);

// Create streaming loader
final streamingLoader = lazyLoader.createStreamingLoader(
  chunkSize: 256 * 1024, // Process in 256KB chunks
);

print('Processing ${streamingLoader.chunkCount} chunks');

// Process artwork in chunks
final processedChunks = <Uint8List>[];
await for (final chunk in streamingLoader.streamWithProgress()) {
  print('Progress: ${chunk.progressPercent.toStringAsFixed(1)}%');

  // Process chunk (e.g., save to temporary file)
  processedChunks.add(chunk.data);

  if (chunk.isLastChunk) {
    print('Streaming complete');
  }
}

// Reassemble complete image
final completeImage = Uint8List.fromList(
  processedChunks.expand((chunk) => chunk).toList(),
);
```

## Format Compatibility

Different audio formats have varying levels of artwork support:

| Format      | Artwork Support | Max Size (practical) | Multiple Images |
| ----------- | --------------- | -------------------- | --------------- |
| MP3 (ID3v2) | Full            | ~16MB                | Yes             |
| FLAC        | Full            | Large                | Yes             |
| OGG Vorbis  | Full            | Large                | Yes             |
| MP4/M4A     | Good            | ~16MB                | Limited         |
| ID3v1       | None            | -                    | -               |

```dart
Future<ArtworkData> resizeArtwork(ArtworkData originalArtwork, int maxSize) async {
  return ArtworkData(
    mimeType: originalArtwork.mimeType,
    type: originalArtwork.type,
    description: '${originalArtwork.description} (resized to ${maxSize}px)',
    dataLoader: () async {
      final originalData = await originalArtwork.data;

      final image = img.decodeImage(originalData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize maintaining aspect ratio
      final resized = img.copyResize(
        image,
        width: image.width > image.height ? maxSize : null,
        height: image.height >= image.width ? maxSize : null,
      );

      // Encode with original format
      Uint8List encodedData;
      if (originalArtwork.mimeType.contains('png')) {
        encodedData = Uint8List.fromList(img.encodePng(resized));
      } else {
        encodedData = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      }

      return encodedData;
    },
  );
}
```

## Removing Artwork

### Remove All Artwork

```dart
// Remove all embedded artwork
audioFile.removeTag(TagKey.artwork);

// Verify removal
final remainingArtwork = audioFile.getTags(TagKey.artwork);
print('Remaining artwork: ${remainingArtwork.length} images');
```

### Remove Specific Artwork

```dart
// Remove artwork by type
void removeArtworkByType(PhonicAudioFile audioFile, ArtworkType typeToRemove) {
  final artworkTags = audioFile.getTags(TagKey.artwork);

  // Find artwork to remove
  final toRemove = artworkTags.where((tag) {
    final artworkTag = tag as ArtworkTag;
    return artworkTag.value.type == typeToRemove;
  }).toList();

  // Remove each matching artwork
  for (final tag in toRemove) {
    final artworkTag = tag as ArtworkTag;
    audioFile.removeTagValue(TagKey.artwork, artworkTag.value);
  }

  print('Removed ${toRemove.length} ${typeToRemove} images');
}

// Usage
removeArtworkByType(audioFile, ArtworkType.backCover);
```

## Best Practices

### Memory Management

```dart
// Process artwork efficiently for large collections
Future<void> processArtworkBatch(List<String> audioFiles) async {
  final artworkCache = ArtworkCache(maxMemoryBytes: 100 * 1024 * 1024);

  try {
    for (final filePath in audioFiles) {
      final audioFile = await Phonic.fromFile(filePath);

      try {
        // Process artwork with cache
        final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
        if (artworkTag != null) {
          // Use cache key based on file
          final cacheKey = 'artwork_${filePath.hashCode}';
          await artworkCache.put(cacheKey, artworkTag.value);
        }
      } finally {
        audioFile.dispose();
      }

      // Clear cache periodically to manage memory
      if (artworkCache.memoryUsagePercent > 80) {
        artworkCache.clear();
      }
    }
  } finally {
    artworkCache.dispose();
  }
}
```

### Format Compatibility

```dart
// Check format artwork support
void checkArtworkSupport(PhonicAudioFile audioFile) {
  final allTags = audioFile.getAllTags();
  final hasId3v1Only = allTags.any((tag) =>
    tag.provenance.containerKind == ContainerKind.id3v1
  ) && !allTags.any((tag) =>
    tag.provenance.containerKind == ContainerKind.id3v2
  );

  if (hasId3v1Only) {
    print('Warning: ID3v1 does not support embedded artwork');
    print('Consider adding ID3v2 tags for artwork support');
  }
}
```

### File Size Management

```dart
// Monitor file size impact of artwork
void analyzeArtworkImpact(PhonicAudioFile audioFile) async {
  final originalSize = audioFile.audioData.length;

  final artworkTags = audioFile.getTags(TagKey.artwork);
  var totalArtworkSize = 0;

  for (final tag in artworkTags) {
    final artworkTag = tag as ArtworkTag;
    final artworkData = await artworkTag.value.data;
    totalArtworkSize += artworkData.length;
  }

  final artworkPercent = (totalArtworkSize / originalSize * 100);

  print('File size: ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB');
  print('Artwork size: ${(totalArtworkSize / 1024 / 1024).toStringAsFixed(1)} MB');
  print('Artwork percentage: ${artworkPercent.toStringAsFixed(1)}%');

  if (artworkPercent > 50) {
    print('Warning: Artwork takes up significant portion of file size');
  }
}
```

## Error Handling

```dart
Future<void> safeArtworkAccess(PhonicAudioFile audioFile) async {
  try {
    final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
    if (artworkTag != null) {
      final artwork = artworkTag.value;

      // Validate MIME type
      if (!_isValidImageMimeType(artwork.mimeType)) {
        print('Warning: Unsupported MIME type: ${artwork.mimeType}');
        return;
      }

      // Load data with timeout
      final imageData = await artwork.data.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Artwork loading timed out'),
      );

      // Validate image data
      if (imageData.isEmpty) {
        print('Warning: Empty artwork data');
        return;
      }

      // Process successfully
      print('Loaded artwork: ${imageData.length} bytes');

    } else {
      print('No artwork found');
    }
  } on TimeoutException catch (e) {
    print('Artwork loading timeout: ${e.message}');
  } on Exception catch (e) {
    print('Error accessing artwork: $e');
  }
}

bool _isValidImageMimeType(String mimeType) {
  const validTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/tiff',
  ];
  return validTypes.contains(mimeType.toLowerCase());
}
```

## Next Steps

- **[Streaming Operations](streaming-operations.md)** - Process large collections with artwork
- **[Performance Optimization](performance-optimization.md)** - Advanced memory management
- **[Examples](examples.md)** - Practical artwork handling examples
