// ignore_for_file: avoid_print

import 'dart:typed_data';

import '../lib/src/core/artwork_cache.dart';
import '../lib/src/core/artwork_data.dart';
import '../lib/src/core/artwork_type.dart';
import '../lib/src/core/optimized_artwork_data.dart';
import '../lib/src/utils/lazy_artwork_loader.dart';

/// Example demonstrating the lazy artwork loading optimization features.
///
/// This example shows how to use the new artwork optimization features:
/// - ArtworkCache for memory-efficient caching with compression
/// - StreamingArtworkLoader for processing large images in chunks
/// - OptimizedArtworkData for intelligent loading strategy selection
/// - LazyArtworkLoader with compression support
void main() async {
  print('Artwork Optimization Example');
  print('============================\n');

  // Create a global artwork cache with memory pressure handling
  final artworkCache = ArtworkCache(
    maxMemoryBytes: 50 * 1024 * 1024, // 50MB limit
    compressionThreshold: 512 * 1024, // Compress images > 512KB
    enableMemoryPressureHandling: true,
    enableCompression: true,
  );

  print('Created artwork cache with 50MB limit and compression enabled\n');

  // Example 1: Basic caching with compression
  await _demonstrateBasicCaching(artworkCache);

  // Example 2: Streaming large artwork
  await _demonstrateStreaming();

  // Example 3: Optimized artwork data with smart strategy selection
  await _demonstrateOptimizedArtwork(artworkCache);

  // Example 4: Lazy loading with compression
  await _demonstrateLazyLoadingWithCompression();

  // Show final cache statistics
  print('\nFinal Cache Statistics:');
  print('Cache size: ${artworkCache.size} entries');
  print('Memory usage: ${(artworkCache.memoryUsageBytes / 1024 / 1024).toStringAsFixed(2)} MB');
  print('Memory usage: ${artworkCache.memoryUsagePercent.toStringAsFixed(1)}% of limit');
  print('Hit rate: ${artworkCache.hitRate.toStringAsFixed(1)}%');
  print('Compression ratio: ${artworkCache.compressionRatio.toStringAsFixed(1)}%');
}

/// Demonstrates basic artwork caching with compression.
Future<void> _demonstrateBasicCaching(ArtworkCache cache) async {
  print('Example 1: Basic Caching with Compression');
  print('------------------------------------------');

  // Create compressible artwork data (repeated patterns compress well)
  final compressibleData = _createCompressibleImageData(1024 * 1024); // 1MB
  print('Created compressible artwork data: ${compressibleData.length} bytes');

  final artwork = ArtworkData(
    mimeType: 'image/jpeg',
    type: ArtworkType.frontCover,
    description: 'Album cover with compression',
    dataLoader: () async => compressibleData,
  );

  // Cache the artwork (compression happens automatically)
  await cache.put('album_cover', artwork);
  print('Cached artwork with automatic compression');

  // Retrieve from cache
  final cached = await cache.get('album_cover');
  if (cached != null) {
    final retrievedData = await cached.data;
    print('Retrieved from cache: ${retrievedData.length} bytes');
    print('Data integrity verified: ${retrievedData.length == compressibleData.length}');
  }

  print('Cache memory usage: ${(cache.memoryUsageBytes / 1024).toStringAsFixed(1)} KB');
  print('Compression saved: ${(cache.compressionRatio).toStringAsFixed(1)}% space\n');
}

/// Demonstrates streaming for large artwork.
Future<void> _demonstrateStreaming() async {
  print('Example 2: Streaming Large Artwork');
  print('-----------------------------------');

  // Create large artwork data (10MB)
  final largeImageData = _createTestImageData(10 * 1024 * 1024);
  print('Created large artwork: ${(largeImageData.length / 1024 / 1024).toStringAsFixed(1)} MB');

  // Create container with artwork embedded
  final containerBytes = Uint8List.fromList([
    ...List.filled(1000, 0x00), // Header
    ...largeImageData,
    ...List.filled(1000, 0xFF), // Footer
  ]);

  final lazyLoader = LazyArtworkLoader(containerBytes, 1000, largeImageData.length);
  final streamingLoader = lazyLoader.createStreamingLoader(chunkSize: 256 * 1024); // 256KB chunks

  print('Processing artwork in ${streamingLoader.chunkCount} chunks of ${(streamingLoader.chunkSize / 1024).toStringAsFixed(0)} KB each');

  var processedBytes = 0;
  var chunkCount = 0;

  await for (final chunk in streamingLoader.streamWithProgress()) {
    processedBytes += chunk.data.length;
    chunkCount++;

    // Simulate processing each chunk
    await Future.delayed(const Duration(milliseconds: 10));

    if (chunkCount % 10 == 0 || chunk.isLastChunk) {
      print(
        'Progress: ${chunk.progressPercent.toStringAsFixed(1)}% '
        '(${(processedBytes / 1024 / 1024).toStringAsFixed(1)} MB processed)',
      );
    }
  }

  print('Streaming complete: processed ${chunkCount} chunks\n');
}

/// Demonstrates optimized artwork data with smart strategy selection.
Future<void> _demonstrateOptimizedArtwork(ArtworkCache cache) async {
  print('Example 3: Optimized Artwork with Smart Strategy Selection');
  print('----------------------------------------------------------');

  // Small artwork - should use cached strategy
  final smallImageData = _createTestImageData(50 * 1024); // 50KB
  final smallOptimized = OptimizedArtworkData(
    mimeType: 'image/png',
    type: ArtworkType.frontCover,
    description: 'Small album cover',
    dataLoader: () async => smallImageData,
    cache: cache,
    cacheKey: 'small_cover',
  );

  print('Small artwork (${(smallImageData.length / 1024).toStringAsFixed(0)} KB):');
  print('  Should use streaming: ${smallOptimized.shouldUseStreaming}');
  print('  Recommended strategy: ${smallOptimized.performanceMetrics.recommendedStrategy}');

  // Large artwork - should use streaming strategy
  final largeImageData = _createTestImageData(8 * 1024 * 1024); // 8MB
  final containerBytes = Uint8List.fromList([
    ...List.filled(100, 0xAA),
    ...largeImageData,
    ...List.filled(100, 0xBB),
  ]);

  final lazyLoader = LazyArtworkLoader(containerBytes, 100, largeImageData.length);
  final largeOptimized = OptimizedArtworkData.fromLazyLoader(
    lazyLoader,
    mimeType: 'image/jpeg',
    type: ArtworkType.frontCover,
    description: 'Large high-res cover',
    cache: cache,
    cacheKey: 'large_cover',
  );

  print('Large artwork (${(largeImageData.length / 1024 / 1024).toStringAsFixed(1)} MB):');
  print('  Should use streaming: ${largeOptimized.shouldUseStreaming}');
  print('  Recommended strategy: ${largeOptimized.performanceMetrics.recommendedStrategy}');
  print('  Size category: ${largeOptimized.performanceMetrics.sizeCategory}');

  // Load small artwork (uses cache)
  final smallData = await smallOptimized.data;
  print('Loaded small artwork: ${smallData.length} bytes');

  // Stream large artwork
  final stream = largeOptimized.streamData(chunkSize: 512 * 1024);
  if (stream != null) {
    var streamedBytes = 0;
    await for (final chunk in stream) {
      streamedBytes += chunk.length;
      if (streamedBytes >= 2 * 1024 * 1024) break; // Process first 2MB only for demo
    }
    print('Streamed first ${(streamedBytes / 1024 / 1024).toStringAsFixed(1)} MB of large artwork\n');
  }
}

/// Demonstrates lazy loading with compression.
Future<void> _demonstrateLazyLoadingWithCompression() async {
  print('Example 4: Lazy Loading with Compression');
  print('-----------------------------------------');

  // Create highly compressible data
  final compressibleData = _createCompressibleImageData(2 * 1024 * 1024); // 2MB
  final containerBytes = Uint8List.fromList([
    ...List.filled(200, 0x00),
    ...compressibleData,
    ...List.filled(200, 0xFF),
  ]);

  final lazyLoader = LazyArtworkLoader(containerBytes, 200, compressibleData.length);

  print('Original artwork size: ${(compressibleData.length / 1024 / 1024).toStringAsFixed(2)} MB');

  // Load with compression
  final compressed = await lazyLoader.loadWithCompression();

  print('Compressed: ${compressed.isCompressed}');
  if (compressed.isCompressed) {
    print('Compressed size: ${(compressed.compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('Compression ratio: ${(compressed.compressionRatio * 100).toStringAsFixed(1)}%');
    print('Space saved: ${(compressed.bytesSaved / 1024 / 1024).toStringAsFixed(2)} MB');

    // Verify data integrity
    final decompressed = await compressed.decompress();
    final integrityCheck = decompressed.length == compressibleData.length;
    print('Data integrity verified: $integrityCheck');
  } else {
    print('Compression not beneficial for this data');
  }

  print('');
}

/// Creates test image data with a realistic but compressible pattern.
Uint8List _createTestImageData(int size) {
  final data = Uint8List(size);

  // Create a pattern with some structure (partially compressible)
  for (int i = 0; i < size; i++) {
    if (i % 1024 == 0) {
      data[i] = 0xFF; // Marker every 1KB
    } else if (i % 256 == 0) {
      data[i] = 0x80; // Marker every 256 bytes
    } else {
      data[i] = (i % 256); // Gradient pattern
    }
  }

  return data;
}

/// Creates highly compressible image data (repeated patterns).
Uint8List _createCompressibleImageData(int size) {
  final data = Uint8List(size);

  // Create highly repetitive pattern that compresses very well
  final pattern = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]; // JPEG-like header repeated

  for (int i = 0; i < size; i++) {
    data[i] = pattern[i % pattern.length];
  }

  return data;
}
