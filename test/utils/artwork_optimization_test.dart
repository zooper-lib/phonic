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
  group('Artwork Optimization Tests', () {
    late Uint8List testImageData;
    late Uint8List largeImageData;

    setUpAll(() {
      // Create test image data
      testImageData = _createTestImageData(100 * 1024); // 100KB
      largeImageData = _createTestImageData(6 * 1024 * 1024); // 6MB
    });

    group('ArtworkCache', () {
      test('basic caching functionality works', () async {
        final cache = ArtworkCache(maxMemoryBytes: 10 * 1024 * 1024);

        final artwork = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Test artwork',
          dataLoader: () async => testImageData,
        );

        // Cache the artwork
        await cache.put('test', artwork);
        expect(cache.size, equals(1));

        // Retrieve from cache
        final cached = await cache.get('test');
        expect(cached, isNotNull);

        final data = await cached!.data;
        expect(data.length, equals(testImageData.length));
      });

      test('memory pressure handling works', () async {
        final cache = ArtworkCache(
          maxMemoryBytes: 1024 * 1024, // 1MB limit
          enableMemoryPressureHandling: true,
        );

        // Add artwork that exceeds cache limit
        for (int i = 0; i < 5; i++) {
          final artwork = ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            dataLoader: () async => testImageData, // 100KB each
          );
          await cache.put('artwork_$i', artwork);
        }

        // Cache should have evicted some entries
        expect(cache.memoryUsageBytes, lessThanOrEqualTo(cache.maxMemoryBytes));
      });

      test('compression reduces memory usage', () async {
        final cache = ArtworkCache(
          maxMemoryBytes: 50 * 1024 * 1024,
          compressionThreshold: 50 * 1024, // 50KB
          enableCompression: true,
        );

        // Create compressible data (repeated patterns)
        final compressibleData = Uint8List(500 * 1024); // 500KB
        for (int i = 0; i < compressibleData.length; i += 4) {
          compressibleData[i] = 0xFF;
          compressibleData[i + 1] = 0xD8;
          compressibleData[i + 2] = 0xFF;
          compressibleData[i + 3] = 0xE0;
        }

        final artwork = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => compressibleData,
        );

        await cache.put('compressible', artwork);

        // Should have achieved some compression
        expect(cache.compressionRatio, greaterThan(0.0));
        expect(cache.memoryUsageBytes, lessThan(compressibleData.length));
      });
    });

    group('StreamingArtworkLoader', () {
      test('processes data in chunks', () async {
        final loader = StreamingArtworkLoader(
          containerBytes: largeImageData,
          offset: 0,
          length: largeImageData.length,
          chunkSize: 64 * 1024, // 64KB chunks
        );

        var totalBytesProcessed = 0;
        var chunkCount = 0;

        await for (final chunk in loader.stream()) {
          totalBytesProcessed += chunk.length;
          chunkCount++;
          expect(chunk.length, lessThanOrEqualTo(64 * 1024));
        }

        expect(totalBytesProcessed, equals(largeImageData.length));
        expect(chunkCount, equals(loader.chunkCount));
      });

      test('progress tracking works', () async {
        final loader = StreamingArtworkLoader(
          containerBytes: testImageData,
          offset: 0,
          length: testImageData.length,
          chunkSize: 32 * 1024,
        );

        var lastProgress = -1.0;

        await for (final chunk in loader.streamWithProgress()) {
          expect(chunk.progressPercent, greaterThan(lastProgress));
          expect(chunk.progressPercent, lessThanOrEqualTo(100.0));
          lastProgress = chunk.progressPercent;
        }

        expect(lastProgress, greaterThanOrEqualTo(95.0)); // Allow for rounding
      });
    });

    group('OptimizedArtworkData', () {
      test('chooses appropriate strategy based on size', () {
        final cache = ArtworkCache();

        // Small artwork
        final smallOptimized = OptimizedArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.frontCover,
          dataLoader: () async => testImageData,
          cache: cache,
          cacheKey: 'small',
        );

        expect(smallOptimized.shouldUseStreaming, isFalse);

        // Large artwork with lazy loader
        final containerBytes = Uint8List.fromList([
          ...List.filled(100, 0x00),
          ...largeImageData,
          ...List.filled(100, 0xFF),
        ]);

        final lazyLoader = LazyArtworkLoader(
          containerBytes,
          100,
          largeImageData.length,
        );

        final largeOptimized = OptimizedArtworkData.fromLazyLoader(
          lazyLoader,
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          cache: cache,
          cacheKey: 'large',
        );

        expect(largeOptimized.shouldUseStreaming, isTrue);
      });

      test('streaming interface works', () async {
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

      test('caching integration works', () async {
        final cache = ArtworkCache(maxMemoryBytes: 10 * 1024 * 1024);

        final optimized = OptimizedArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          dataLoader: () async => testImageData,
          cache: cache,
          cacheKey: 'test_artwork',
        );

        // First access should load and cache
        final data1 = await optimized.data;
        expect(data1, equals(testImageData));
        expect(cache.size, equals(1));

        // Second access should hit cache
        final initialHitCount = cache.hitCount;
        final data2 = await optimized.data;
        expect(data2, equals(testImageData));
        expect(cache.hitCount, equals(initialHitCount + 1));
      });
    });

    group('LazyArtworkLoader Compression', () {
      test('compression works when beneficial', () async {
        // Create compressible data
        final compressibleData = Uint8List(100 * 1024);
        for (int i = 0; i < compressibleData.length; i += 8) {
          compressibleData.setRange(i, math.min(i + 8, compressibleData.length), [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
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
