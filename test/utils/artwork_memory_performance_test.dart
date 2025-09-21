import 'dart:math' as math;
import 'dart:typed_data';

import 'package:phonic/src/core/artwork_cache.dart';
import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/optimized_artwork_data.dart';
import 'package:phonic/src/utils/lazy_artwork_loader.dart';
import 'package:phonic/src/utils/streaming_artwork_loader.dart';
import 'package:test/test.dart';

void main() {
  group('Artwork Memory Performance Tests', () {
    late Uint8List smallImageData;
    late Uint8List mediumImageData;
    late Uint8List largeImageData;
    late Uint8List veryLargeImageData;

    setUpAll(() {
      // Create test image data of various sizes
      smallImageData = _createTestImageData(50 * 1024); // 50KB
      mediumImageData = _createTestImageData(500 * 1024); // 500KB
      largeImageData = _createTestImageData(2 * 1024 * 1024); // 2MB
      veryLargeImageData = _createTestImageData(10 * 1024 * 1024); // 10MB
    });

    group('ArtworkCache Performance', () {
      test('handles memory pressure correctly', () async {
        final cache = ArtworkCache(
          maxMemoryBytes: 5 * 1024 * 1024, // 5MB limit
          enableMemoryPressureHandling: true,
        );

        // Add artwork that exceeds cache limit
        final artworks = <ArtworkData>[];
        for (int i = 0; i < 10; i++) {
          final artwork = ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Test artwork $i',
            dataLoader: () async => mediumImageData, // 500KB each
          );
          artworks.add(artwork);
          await cache.put('artwork_$i', artwork);
        }

        // Cache should have evicted some entries to stay under limit
        expect(cache.memoryUsageBytes, lessThanOrEqualTo(cache.maxMemoryBytes));
        expect(cache.size, lessThan(10)); // Some entries should be evicted

        // Verify cache still works for remaining entries
        var hitCount = 0;
        for (int i = 0; i < 10; i++) {
          final cached = await cache.get('artwork_$i');
          if (cached != null) {
            hitCount++;
            final data = await cached.data;
            expect(data.length, equals(mediumImageData.length));
          }
        }

        expect(hitCount, greaterThan(0)); // At least some entries should remain
        expect(cache.hitRate, greaterThan(0)); // Should have some hits
      });

      test('compression reduces memory usage significantly', () async {
        final cache = ArtworkCache(
          maxMemoryBytes: 50 * 1024 * 1024, // 50MB
          compressionThreshold: 100 * 1024, // 100KB
          enableCompression: true,
        );

        // Create compressible artwork data (repeated patterns compress well)
        final compressibleData = Uint8List(1024 * 1024); // 1MB
        for (int i = 0; i < compressibleData.length; i += 4) {
          compressibleData[i] = 0xFF;
          compressibleData[i + 1] = 0xD8;
          compressibleData[i + 2] = 0xFF;
          compressibleData[i + 3] = 0xE0;
        }

        final artwork = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Compressible artwork',
          dataLoader: () async => compressibleData,
        );

        await cache.put('compressible', artwork);

        // Compression should have saved significant space
        expect(cache.compressionRatio, greaterThan(50.0)); // At least 50% compression
        expect(cache.memoryUsageBytes, lessThan(compressibleData.length));

        // Verify data integrity after compression/decompression
        final cached = await cache.get('compressible');
        expect(cached, isNotNull);
        final retrievedData = await cached!.data;
        expect(retrievedData, equals(compressibleData));
      });

      test('eviction prioritizes large, old entries', () async {
        final cache = ArtworkCache(
          maxMemoryBytes: 5 * 1024 * 1024, // 5MB limit - enough for small + 2 large artworks
        );

        // Add small artwork first
        final smallArtwork = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.frontCover,
          dataLoader: () async => smallImageData,
        );
        await cache.put('small', smallArtwork);

        // Add large artwork that should trigger eviction
        final largeArtwork = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => largeImageData,
        );
        await cache.put('large', largeArtwork);

        // Access small artwork to make it recently used
        await cache.get('small');

        // Add another large artwork
        final largeArtwork2 = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.backCover,
          dataLoader: () async => largeImageData,
        );
        await cache.put('large2', largeArtwork2);

        // Small artwork should still be cached (recently accessed)
        final cachedSmall = await cache.get('small');
        expect(cachedSmall, isNotNull);

        // First large artwork should be evicted (older and larger)
        final cachedLarge = await cache.get('large');
        expect(cachedLarge, isNull);
      });

      test('performance metrics are accurate', () async {
        final cache = ArtworkCache(maxMemoryBytes: 10 * 1024 * 1024);

        // Perform various cache operations
        for (int i = 0; i < 20; i++) {
          final artwork = ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => mediumImageData,
          );
          await cache.put('artwork_$i', artwork);
        }

        // Generate some hits and misses
        for (int i = 0; i < 30; i++) {
          await cache.get('artwork_$i');
        }

        expect(cache.totalRequests, equals(30));
        expect(cache.hitCount + cache.missCount, equals(30));
        expect(cache.hitRate, greaterThan(0));
        expect(cache.hitRate, lessThanOrEqualTo(100));
        expect(cache.memoryUsagePercent, greaterThan(0));
        expect(cache.memoryUsagePercent, lessThanOrEqualTo(100));
      });
    });

    group('StreamingArtworkLoader Performance', () {
      test('processes large images without memory spikes', () async {
        final containerBytes = Uint8List.fromList([
          ...List.filled(1000, 0x00), // Header
          ...veryLargeImageData, // 10MB image
          ...List.filled(1000, 0xFF), // Footer
        ]);

        final loader = StreamingArtworkLoader(
          containerBytes: containerBytes,
          offset: 1000,
          length: veryLargeImageData.length,
          chunkSize: 64 * 1024, // 64KB chunks
        );

        var totalBytesProcessed = 0;
        var chunkCount = 0;
        var maxChunkSize = 0;

        await for (final chunk in loader.stream()) {
          totalBytesProcessed += chunk.length;
          chunkCount++;
          maxChunkSize = math.max(maxChunkSize, chunk.length);

          // Verify chunk size is reasonable
          expect(chunk.length, lessThanOrEqualTo(64 * 1024));
        }

        expect(totalBytesProcessed, equals(veryLargeImageData.length));
        expect(chunkCount, equals(loader.chunkCount));
        expect(maxChunkSize, lessThanOrEqualTo(64 * 1024));
      });

      test('progress tracking is accurate', () async {
        final loader = StreamingArtworkLoader(
          containerBytes: largeImageData,
          offset: 0,
          length: largeImageData.length,
          chunkSize: 32 * 1024, // 32KB chunks
        );

        var lastProgress = -1.0;
        var chunkIndex = 0;

        await for (final chunk in loader.streamWithProgress()) {
          expect(chunk.chunkIndex, equals(chunkIndex));
          expect(chunk.totalChunks, equals(loader.chunkCount));
          expect(chunk.progressPercent, greaterThan(lastProgress));
          expect(chunk.progressPercent, lessThanOrEqualTo(100.0));

          lastProgress = chunk.progressPercent;
          chunkIndex++;
        }

        expect(lastProgress, equals(100.0));
      });

      test('buffered streaming works correctly', () async {
        final loader = StreamingArtworkLoader(
          containerBytes: mediumImageData,
          offset: 0,
          length: mediumImageData.length,
          chunkSize: 16 * 1024, // 16KB chunks
        );

        final bufferSize = 64 * 1024; // 64KB buffer
        var totalBytes = 0;

        await for (final bufferedChunk in loader.bufferedStream(bufferSize)) {
          totalBytes += bufferedChunk.length;
          expect(bufferedChunk.length, lessThanOrEqualTo(bufferSize));
        }

        expect(totalBytes, equals(mediumImageData.length));
      });
    });

    group('OptimizedArtworkData Performance', () {
      test('chooses appropriate loading strategy based on size', () {
        final cache = ArtworkCache();

        // Small artwork - should use direct loading
        final smallOptimized = OptimizedArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.frontCover,
          dataLoader: () async => smallImageData,
          cache: cache,
          cacheKey: 'small',
        );

        expect(smallOptimized.shouldUseStreaming, isFalse);
        expect(smallOptimized.performanceMetrics.sizeCategory, equals('unknown'));
        expect(smallOptimized.performanceMetrics.recommendedStrategy, equals('cached'));

        // Large artwork with lazy loader - should use streaming
        final containerBytes = Uint8List.fromList([
          ...List.filled(100, 0x00),
          ...veryLargeImageData,
          ...List.filled(100, 0xFF),
        ]);

        final lazyLoader = LazyArtworkLoader(
          containerBytes,
          100,
          veryLargeImageData.length,
        );

        final largeOptimized = OptimizedArtworkData.fromLazyLoader(
          lazyLoader,
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          cache: cache,
          cacheKey: 'large',
        );

        expect(largeOptimized.shouldUseStreaming, isTrue);
        expect(largeOptimized.performanceMetrics.sizeCategory, equals('very_large'));
        expect(largeOptimized.performanceMetrics.recommendedStrategy, equals('streaming'));
      });

      test('streaming interface works for large artwork', () async {
        final containerBytes = Uint8List.fromList([
          ...List.filled(50, 0xAA),
          ...largeImageData,
          ...List.filled(50, 0xBB),
        ]);

        final lazyLoader = LazyArtworkLoader(containerBytes, 50, largeImageData.length);
        final optimized = OptimizedArtworkData.fromLazyLoader(
          lazyLoader,
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          streamingThreshold: 1024 * 1024, // 1MB threshold
        );

        expect(optimized.shouldUseStreaming, isTrue);

        final stream = optimized.streamData(chunkSize: 128 * 1024);
        expect(stream, isNotNull);

        var totalBytes = 0;
        await for (final chunk in stream!) {
          totalBytes += chunk.length;
        }

        expect(totalBytes, equals(largeImageData.length));
      });

      test('caching integration works correctly', () async {
        final cache = ArtworkCache(maxMemoryBytes: 10 * 1024 * 1024);

        final optimized = OptimizedArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => mediumImageData,
          cache: cache,
          cacheKey: 'test_artwork',
        );

        // First access should load and cache
        final data1 = await optimized.data;
        expect(data1, equals(mediumImageData));
        expect(cache.size, equals(1));

        // Second access should hit cache
        final initialHitCount = cache.hitCount;
        final data2 = await optimized.data;
        expect(data2, equals(mediumImageData));
        expect(cache.hitCount, equals(initialHitCount + 1));
      });
    });

    group('LazyArtworkLoader Compression', () {
      test('compression works when beneficial', () async {
        // Create highly compressible data
        final compressibleData = Uint8List(1024 * 1024);
        for (int i = 0; i < compressibleData.length; i += 8) {
          compressibleData.setRange(i, i + 8, [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
        }

        final containerBytes = Uint8List.fromList([
          ...List.filled(100, 0x00),
          ...compressibleData,
          ...List.filled(100, 0xFF),
        ]);

        final loader = LazyArtworkLoader(containerBytes, 100, compressibleData.length);
        final compressed = await loader.loadWithCompression();

        expect(compressed.isCompressed, isTrue);
        expect(compressed.compressedSize, lessThan(compressed.originalSize));
        expect(compressed.compressionRatio, lessThan(0.9));

        // Verify data integrity
        final decompressed = await compressed.decompress();
        expect(decompressed, equals(compressibleData));
      });

      test('skips compression when not beneficial', () async {
        // Use random data that won't compress well
        final randomData = Uint8List(1024);
        final random = math.Random(42);
        for (int i = 0; i < randomData.length; i++) {
          randomData[i] = random.nextInt(256);
        }

        final containerBytes = Uint8List.fromList([
          ...List.filled(50, 0x00),
          ...randomData,
          ...List.filled(50, 0xFF),
        ]);

        final loader = LazyArtworkLoader(containerBytes, 50, randomData.length);
        final compressed = await loader.loadWithCompression();

        expect(compressed.isCompressed, isFalse);
        expect(compressed.compressedSize, equals(compressed.originalSize));
        expect(compressed.compressionRatio, equals(1.0));
      });
    });

    group('Memory Usage Benchmarks', () {
      test('memory usage scales linearly with cache size', () async {
        final cache = ArtworkCache(maxMemoryBytes: 20 * 1024 * 1024);
        final artworkSizes = <int>[];

        // Add artwork of known sizes
        for (int i = 0; i < 10; i++) {
          final size = (i + 1) * 100 * 1024; // 100KB, 200KB, ..., 1MB
          final data = _createTestImageData(size);
          artworkSizes.add(size);

          final artwork = ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => data,
          );

          await cache.put('artwork_$i', artwork);
        }

        // Memory usage should be roughly proportional to total artwork size
        final expectedSize = artworkSizes.reduce((a, b) => a + b);
        final actualSize = cache.memoryUsageBytes;

        // Allow for some overhead but should be in the right ballpark
        expect(actualSize, greaterThan(expectedSize * 0.8));
        expect(actualSize, lessThan(expectedSize * 1.2));
      });

      test('streaming uses minimal memory regardless of image size', () async {
        final sizes = [1024 * 1024, 5 * 1024 * 1024, 10 * 1024 * 1024]; // 1MB, 5MB, 10MB

        for (final size in sizes) {
          final imageData = _createTestImageData(size);
          final loader = StreamingArtworkLoader(
            containerBytes: imageData,
            offset: 0,
            length: imageData.length,
            chunkSize: 64 * 1024,
          );

          var maxMemoryUsed = 0;
          await for (final chunk in loader.stream()) {
            maxMemoryUsed = math.max(maxMemoryUsed, chunk.length);
            // Simulate processing the chunk
            chunk.length; // Access to prevent optimization
          }

          // Memory usage should be bounded by chunk size regardless of total size
          expect(maxMemoryUsed, lessThanOrEqualTo(64 * 1024));
        }
      });
    });
  });
}

/// Creates test image data of the specified size with a realistic pattern.
Uint8List _createTestImageData(int size) {
  final data = Uint8List(size);
  final random = math.Random(42); // Fixed seed for reproducible tests

  // Create a pattern that's somewhat compressible but not trivial
  for (int i = 0; i < size; i++) {
    if (i % 1024 == 0) {
      // Add some structure every 1KB
      data[i] = 0xFF;
    } else if (i % 256 == 0) {
      // Add some structure every 256 bytes
      data[i] = 0x80;
    } else {
      // Fill with pseudo-random data
      data[i] = random.nextInt(256);
    }
  }

  return data;
}
