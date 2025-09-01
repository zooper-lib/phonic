// ignore_for_file: avoid_print

import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/utils/memory_efficient_tag_storage.dart';
import 'package:phonic/src/utils/memory_usage_monitor.dart';
import 'package:phonic/src/utils/string_interning.dart';

/// Example demonstrating memory-efficient tag storage capabilities.
///
/// This example shows how the memory-efficient tag storage system can
/// significantly reduce memory usage when processing large collections
/// of audio files with common metadata values.
void main() {
  print('Memory-Efficient Tag Storage Example');
  print('=====================================\n');

  // Example 1: Basic string interning
  demonstrateStringInterning();

  // Example 2: Memory-efficient tag storage
  demonstrateMemoryEfficientStorage();

  // Example 3: Batch processing with memory monitoring
  demonstrateBatchProcessingWithMonitoring();

  // Example 4: Performance comparison
  demonstratePerformanceComparison();
}

/// Demonstrates basic string interning functionality.
void demonstrateStringInterning() {
  print('1. String Interning Example');
  print('---------------------------');

  final interning = StringInterning();

  // Simulate common metadata values
  final commonGenres = ['Rock', 'Pop', 'Jazz', 'Classical', 'Electronic'];
  final commonArtists = ['The Beatles', 'Pink Floyd', 'Led Zeppelin'];

  print('Interning common metadata values...');

  // Intern the same values multiple times (simulating multiple files)
  for (int i = 0; i < 100; i++) {
    for (final genre in commonGenres) {
      interning.intern(genre);
    }
    for (final artist in commonArtists) {
      interning.intern(artist);
    }
  }

  final stats = interning.statistics;
  print('Results:');
  print('  - Total requests: ${stats['totalRequests']}');
  print('  - Cache hits: ${stats['cacheHits']}');
  print('  - Unique strings: ${stats['uniqueStrings']}');
  print('  - Hit ratio: ${(((stats['hitRatio'] as num?) ?? 0.0) * 100).toStringAsFixed(1)}%');
  print('  - Estimated memory saved: ${stats['estimatedMemorySaved']} bytes');
  print('');
}

/// Demonstrates memory-efficient tag storage.
void demonstrateMemoryEfficientStorage() {
  print('2. Memory-Efficient Tag Storage Example');
  print('---------------------------------------');

  // Create storage with string interning enabled
  final storage = MemoryEfficientTagStorage(useInterning: true);

  // Simulate processing multiple files with overlapping metadata
  final commonMetadata = {
    'artists': ['The Beatles', 'Pink Floyd', 'Led Zeppelin', 'Queen'],
    'albums': ['Abbey Road', 'The Wall', 'Led Zeppelin IV', 'A Night at the Opera'],
    'genres': ['Rock', 'Progressive Rock', 'Hard Rock', 'Classic Rock'],
  };

  print('Processing 50 simulated audio files...');

  for (int fileIndex = 0; fileIndex < 50; fileIndex++) {
    // Create tags with overlapping values
    final tags = <MetadataTag>[
      TitleTag('Song $fileIndex'),
      ArtistTag(commonMetadata['artists']![fileIndex % 4]),
      AlbumTag(commonMetadata['albums']![fileIndex % 4]),
      GenreTag([commonMetadata['genres']![fileIndex % 4]]),
      TrackNumberTag((fileIndex % 12) + 1),
      YearTag(1970 + (fileIndex % 30)),
    ];

    // Store tags for this file (in real usage, you'd process one file at a time)
    storage.clear();
    storage.storeTags(tags);

    // Verify data integrity
    assert(storage.getTag(TagKey.title)?.value == 'Song $fileIndex');
    assert(storage.tagCount == 6);
  }

  final memStats = storage.memoryStatistics;
  print('Results:');
  print('  - Files processed: 50');
  print('  - String interning enabled: ${memStats['stringInterningEnabled']}');
  print('  - Interning effectiveness: ${(((memStats['interningEffectiveness'] as num?) ?? 0.0) * 100).toStringAsFixed(1)}%');
  print('  - Estimated memory usage per file: ${memStats['estimatedMemoryUsage']} bytes');
  print('');
}

/// Demonstrates batch processing with memory monitoring.
void demonstrateBatchProcessingWithMonitoring() {
  print('3. Batch Processing with Memory Monitoring');
  print('-----------------------------------------');

  final batchMonitor = BatchMemoryMonitor(checkpointInterval: 25);
  final storagePool = TagStoragePool(useInterning: true);

  batchMonitor.start();

  print('Processing 100 files with memory monitoring...');

  // Simulate processing a batch of files
  for (int fileIndex = 0; fileIndex < 100; fileIndex++) {
    // Acquire storage from pool
    final storage = storagePool.acquire();

    // Create realistic metadata
    final tags = <MetadataTag>[
      TitleTag('Track ${fileIndex + 1}'),
      ArtistTag('Artist ${(fileIndex ~/ 10) + 1}'),
      AlbumTag('Album ${(fileIndex ~/ 20) + 1}'),
      GenreTag(['Genre${(fileIndex % 5) + 1}']),
      TrackNumberTag((fileIndex % 15) + 1),
    ];

    storage.storeTags(tags);

    // Simulate some processing work
    final _ = storage.getAllTags();

    // Return storage to pool
    storagePool.release(storage);

    // Record processing
    batchMonitor.recordItem('file_$fileIndex');
  }

  final report = batchMonitor.finish();
  final poolStats = storagePool.statistics;

  print('Results:');
  print('  - Files processed: ${batchMonitor.processedCount}');
  print('  - Checkpoints recorded: ${report.checkpoints.length}');
  print('  - Total processing time: ${report.totalDuration.inMilliseconds}ms');
  print('  - Storage instances created: ${poolStats['totalCreated']}');
  print('  - Storage instances reused: ${poolStats['totalReused']}');
  print('  - Pool reuse ratio: ${(((poolStats['reuseRatio'] as num?) ?? 0.0) * 100).toStringAsFixed(1)}%');
  print('');
}

/// Demonstrates performance comparison between different approaches.
void demonstratePerformanceComparison() {
  print('4. Performance Comparison');
  print('------------------------');

  const fileCount = 1000;
  final commonValues = ['Rock', 'Pop', 'Jazz', 'The Beatles', 'Pink Floyd'];

  // Test 1: Without interning
  final stopwatch1 = Stopwatch()..start();
  final storageWithoutInterning = MemoryEfficientTagStorage(useInterning: false);

  for (int i = 0; i < fileCount; i++) {
    final tags = <MetadataTag>[
      TitleTag('Song $i'),
      ArtistTag(commonValues[i % commonValues.length]),
      GenreTag([commonValues[i % commonValues.length]]),
    ];
    storageWithoutInterning.clear();
    storageWithoutInterning.storeTags(tags);
  }

  stopwatch1.stop();
  final stats1 = storageWithoutInterning.memoryStatistics;

  // Test 2: With interning
  final stopwatch2 = Stopwatch()..start();
  final storageWithInterning = MemoryEfficientTagStorage(useInterning: true);

  for (int i = 0; i < fileCount; i++) {
    final tags = <MetadataTag>[
      TitleTag('Song $i'),
      ArtistTag(commonValues[i % commonValues.length]),
      GenreTag([commonValues[i % commonValues.length]]),
    ];
    storageWithInterning.clear();
    storageWithInterning.storeTags(tags);
  }

  stopwatch2.stop();
  final stats2 = storageWithInterning.memoryStatistics;

  print('Processing $fileCount files:');
  print('');
  print('Without String Interning:');
  print('  - Processing time: ${stopwatch1.elapsedMilliseconds}ms');
  print('  - Memory usage: ${stats1['estimatedMemoryUsage']} bytes');
  print('');
  print('With String Interning:');
  print('  - Processing time: ${stopwatch2.elapsedMilliseconds}ms');
  print('  - Memory usage: ${stats2['estimatedMemoryUsage']} bytes');
  print('  - Interning effectiveness: ${(((stats2['interningEffectiveness'] as num?) ?? 0.0) * 100).toStringAsFixed(1)}%');
  print('');

  final timeDiff = stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds;
  final memoryDiff = (stats1['estimatedMemoryUsage'] as int) - (stats2['estimatedMemoryUsage'] as int);

  print('Improvements with interning:');
  print('  - Time difference: ${timeDiff}ms');
  print('  - Memory saved: $memoryDiff bytes');
  print('  - Memory reduction: ${memoryDiff > 0 ? ((memoryDiff / (stats1['estimatedMemoryUsage'] as int)) * 100).toStringAsFixed(1) : 0}%');
}
