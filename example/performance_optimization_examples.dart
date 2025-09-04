// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:phonic/phonic.dart';

/// Performance optimization examples for the Phonic library.
///
/// This example demonstrates various techniques for optimizing performance
/// when working with audio metadata, especially for large collections:
/// - Lazy loading strategies
/// - Memory-efficient batch processing
/// - Caching and resource management
/// - Streaming operations
/// - Performance monitoring and profiling
void main() async {
  print('Phonic Performance Optimization Examples');
  print('=======================================\n');

  // Example 1: Lazy loading and memory efficiency
  await lazyLoadingOptimization();

  // Example 2: Batch processing optimization
  await batchProcessingOptimization();

  // Example 3: Caching strategies
  await cachingStrategies();

  // Example 4: Resource management
  await resourceManagement();

  // Example 5: Performance monitoring
  await performanceMonitoring();

  // Example 6: Large collection handling
  await largeCollectionHandling();

  // Example 7: Memory pressure handling
  await memoryPressureHandling();
}

/// Demonstrates lazy loading optimization techniques.
Future<void> lazyLoadingOptimization() async {
  print('1. Lazy Loading Optimization');
  print('----------------------------');

  final stopwatch = Stopwatch()..start();

  try {
    // Create file with large artwork
    final audioFile = Phonic.fromBytes(_createMp3WithLargeArtwork(), 'large_artwork.mp3');

    print('File loaded in ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    // Access metadata without loading artwork
    final title = audioFile.getTag(TagKey.title);
    final artist = audioFile.getTag(TagKey.artist);
    final artworkTag = audioFile.getTag(TagKey.artwork);

    print('Metadata access in ${stopwatch.elapsedMilliseconds}ms');
    print('  Title: ${title?.value}');
    print('  Artist: ${artist?.value}');

    if (artworkTag != null) {
      final artwork = (artworkTag as ArtworkTag).value;
      print('  Artwork: ${artwork.mimeType}, ${artwork.type}');
      print('  (Image data not loaded yet - zero memory impact)');

      stopwatch.reset();
      // Load artwork data only when needed
      final imageData = await artwork.data;
      print('  Artwork loaded in ${stopwatch.elapsedMilliseconds}ms');
      print('  Image size: ${imageData.length} bytes');
    }

    // Demonstrate multiple artwork handling
    print('\nMultiple artwork optimization:');
    final allArtwork = audioFile.getTags(TagKey.artwork);
    print('Found ${allArtwork.length} artwork images');

    for (int i = 0; i < allArtwork.length; i++) {
      final artwork = (allArtwork[i] as ArtworkTag).value;
      print('  Artwork $i: ${artwork.type} (${artwork.mimeType})');
      // Only load specific artwork when needed
      if (artwork.type == ArtworkType.frontCover) {
        stopwatch.reset();
        final data = await artwork.data;
        print('    Front cover loaded: ${data.length} bytes in ${stopwatch.elapsedMilliseconds}ms');
      }
    }

    audioFile.dispose();
  } catch (e) {
    print('Error in lazy loading optimization: $e');
  }

  print('');
}

/// Demonstrates batch processing optimization techniques.
Future<void> batchProcessingOptimization() async {
  print('2. Batch Processing Optimization');
  print('--------------------------------');

  // Create a collection of test files
  final testFiles = List.generate(50, (i) => ('song_$i.mp3', _createTestMp3(i)));

  print('Processing ${testFiles.length} files...');

  // Technique 1: Sequential processing with proper disposal
  print('\nTechnique 1: Sequential processing');
  final stopwatch1 = Stopwatch()..start();
  var processedCount = 0;

  for (final (filename, bytes) in testFiles) {
    PhonicAudioFile? audioFile;
    try {
      audioFile = Phonic.fromBytes(bytes, filename);

      // Quick metadata extraction
      final title = audioFile.getTag(TagKey.title);
      final artist = audioFile.getTag(TagKey.artist);

      // Simulate processing
      if (title != null && artist != null) {
        processedCount++;
      }
    } finally {
      // Always dispose to free memory immediately
      audioFile?.dispose();
    }
  }

  stopwatch1.stop();
  print('  Processed $processedCount files in ${stopwatch1.elapsedMilliseconds}ms');
  print('  Average: ${(stopwatch1.elapsedMilliseconds / testFiles.length).toStringAsFixed(2)}ms per file');

  // Technique 2: Batch processing with memory monitoring
  print('\nTechnique 2: Batch processing with memory limits');
  final stopwatch2 = Stopwatch()..start();
  const batchSize = 10;
  var batchProcessedCount = 0;

  for (int i = 0; i < testFiles.length; i += batchSize) {
    final batch = testFiles.skip(i).take(batchSize).toList();
    final batchFiles = <PhonicAudioFile>[];

    try {
      // Load batch
      for (final (filename, bytes) in batch) {
        final audioFile = Phonic.fromBytes(bytes, filename);
        batchFiles.add(audioFile);
      }

      // Process batch
      for (final audioFile in batchFiles) {
        final title = audioFile.getTag(TagKey.title);
        if (title != null) batchProcessedCount++;
      }

      print('  Processed batch ${(i ~/ batchSize) + 1}: ${batch.length} files');
    } finally {
      // Dispose entire batch
      for (final audioFile in batchFiles) {
        audioFile.dispose();
      }
    }

    // Simulate memory pressure relief
    if (i % (batchSize * 3) == 0) {
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  stopwatch2.stop();
  print('  Batch processed $batchProcessedCount files in ${stopwatch2.elapsedMilliseconds}ms');

  // Technique 3: Streaming processing
  print('\nTechnique 3: Streaming processing');
  final stopwatch3 = Stopwatch()..start();
  var streamProcessedCount = 0;

  await for (final result in _processFilesAsStream(testFiles)) {
    if (result.success) {
      streamProcessedCount++;
    }

    // Progress reporting
    if (streamProcessedCount % 10 == 0) {
      print('  Streamed $streamProcessedCount files...');
    }
  }

  stopwatch3.stop();
  print('  Stream processed $streamProcessedCount files in ${stopwatch3.elapsedMilliseconds}ms');

  print('');
}

/// Demonstrates caching strategies for improved performance.
Future<void> cachingStrategies() async {
  print('3. Caching Strategies');
  print('--------------------');

  // Strategy 1: Codec registry caching (built into Phonic)
  print('Strategy 1: Codec registry caching');
  final stopwatch = Stopwatch()..start();

  // First file load - codec registry created
  final audioFile1 = Phonic.fromBytes(_createTestMp3(1), 'test1.mp3');
  final firstLoadTime = stopwatch.elapsedMilliseconds;
  audioFile1.dispose();

  stopwatch.reset();

  // Second file load - codec registry reused
  final audioFile2 = Phonic.fromBytes(_createTestMp3(2), 'test2.mp3');
  final secondLoadTime = stopwatch.elapsedMilliseconds;
  audioFile2.dispose();

  print('  First load: ${firstLoadTime}ms (codec registry created)');
  print('  Second load: ${secondLoadTime}ms (codec registry reused)');
  print('  Improvement: ${((firstLoadTime - secondLoadTime) / firstLoadTime * 100).toStringAsFixed(1)}%');

  // Strategy 2: Metadata caching for repeated access
  print('\nStrategy 2: Metadata caching simulation');
  final audioFile = Phonic.fromBytes(_createTestMp3(1), 'cached.mp3');

  stopwatch.reset();
  // First access - parsing required
  final title1 = audioFile.getTag(TagKey.title);
  final firstAccessTime = stopwatch.elapsedMilliseconds;

  stopwatch.reset();
  // Second access - cached result
  final title2 = audioFile.getTag(TagKey.title);
  final secondAccessTime = stopwatch.elapsedMilliseconds;

  print('  First access: ${firstAccessTime}ms (parsing)');
  print('  Second access: ${secondAccessTime}ms (cached)');
  print('  Same result: ${title1?.value == title2?.value}');

  audioFile.dispose();

  // Strategy 3: Format detection caching
  print('\nStrategy 3: Format detection optimization');
  final sameFormatFiles = List.generate(5, (i) => _createTestMp3(i));

  stopwatch.reset();
  for (int i = 0; i < sameFormatFiles.length; i++) {
    final audioFile = Phonic.fromBytes(sameFormatFiles[i], 'same_format_$i.mp3');
    audioFile.dispose();
  }
  final totalTime = stopwatch.elapsedMilliseconds;

  print('  Processed ${sameFormatFiles.length} same-format files in ${totalTime}ms');
  print('  Average per file: ${(totalTime / sameFormatFiles.length).toStringAsFixed(2)}ms');

  print('');
}

/// Demonstrates resource management best practices.
Future<void> resourceManagement() async {
  print('4. Resource Management');
  print('---------------------');

  // Pattern 1: RAII (Resource Acquisition Is Initialization) pattern
  print('Pattern 1: RAII with try-finally');
  PhonicAudioFile? audioFile;
  try {
    audioFile = Phonic.fromBytes(_createTestMp3(1), 'raii.mp3');

    // Use the resource
    final title = audioFile.getTag(TagKey.title);
    print('  Processed: ${title?.value}');
  } finally {
    // Always dispose, even if exception occurs
    audioFile?.dispose();
    print('  Resource properly disposed');
  }

  // Pattern 2: Resource pooling simulation
  print('\nPattern 2: Resource pooling');
  final resourcePool = <PhonicAudioFile>[];
  const poolSize = 5;

  // Pre-create resources
  for (int i = 0; i < poolSize; i++) {
    final resource = Phonic.fromBytes(_createTestMp3(i), 'pool_$i.mp3');
    resourcePool.add(resource);
  }
  print('  Created resource pool with $poolSize items');

  // Use resources from pool
  for (int i = 0; i < 10; i++) {
    final resource = resourcePool[i % poolSize];
    final title = resource.getTag(TagKey.title);
    print('  Used pooled resource: ${title?.value}');
  }

  // Cleanup pool
  for (final resource in resourcePool) {
    resource.dispose();
  }
  print('  Resource pool cleaned up');

  // Pattern 3: Lazy cleanup with weak references
  print('\nPattern 3: Lazy cleanup simulation');
  final weakReferences = <WeakReference<PhonicAudioFile>>[];

  // Create resources with weak references
  for (int i = 0; i < 3; i++) {
    final audioFile = Phonic.fromBytes(_createTestMp3(i), 'weak_$i.mp3');
    weakReferences.add(WeakReference(audioFile));

    // Simulate some processing
    final title = audioFile.getTag(TagKey.title);
    print('  Created weak reference for: ${title?.value}');
  }

  // Simulate garbage collection pressure
  print('  Simulating memory pressure...');

  // Check weak references
  var aliveCount = 0;
  for (final ref in weakReferences) {
    if (ref.target != null) {
      aliveCount++;
      ref.target!.dispose(); // Manual cleanup
    }
  }
  print('  Cleaned up $aliveCount remaining resources');

  print('');
}

/// Demonstrates performance monitoring techniques.
Future<void> performanceMonitoring() async {
  print('5. Performance Monitoring');
  print('------------------------');

  // Monitor 1: Operation timing
  print('Monitor 1: Operation timing');
  final operations = <String, int>{};

  PhonicAudioFile? audioFile;
  try {
    // Time file loading
    final stopwatch = Stopwatch()..start();
    audioFile = Phonic.fromBytes(_createMp3WithLargeArtwork(), 'monitor.mp3');
    operations['load'] = stopwatch.elapsedMilliseconds;

    // Time tag reading
    stopwatch.reset();
    final allTags = audioFile.getAllTags();
    operations['read_all_tags'] = stopwatch.elapsedMilliseconds;

    // Time tag modification
    stopwatch.reset();
    audioFile.setTag(const TitleTag('Modified Title'));
    audioFile.setTag(const ArtistTag('Modified Artist'));
    operations['modify_tags'] = stopwatch.elapsedMilliseconds;

    // Time encoding
    stopwatch.reset();
    final encoded = await audioFile.encode();
    operations['encode'] = stopwatch.elapsedMilliseconds;

    print('  Operation timings:');
    operations.forEach((operation, time) {
      print('    $operation: ${time}ms');
    });

    print('  Encoded size: ${encoded.length} bytes');
    print('  Tags processed: ${allTags.length}');
  } finally {
    audioFile?.dispose();
  }

  // Monitor 2: Memory usage tracking
  print('\nMonitor 2: Memory usage simulation');
  final memorySnapshots = <String, int>{};

  // Baseline
  memorySnapshots['baseline'] = _getSimulatedMemoryUsage();

  // Load multiple files
  final files = <PhonicAudioFile>[];
  for (int i = 0; i < 10; i++) {
    files.add(Phonic.fromBytes(_createTestMp3(i), 'memory_$i.mp3'));
  }
  memorySnapshots['after_loading'] = _getSimulatedMemoryUsage();

  // Process files
  for (final file in files) {
    file.setTag(TitleTag('Processed ${DateTime.now().millisecondsSinceEpoch}'));
  }
  memorySnapshots['after_processing'] = _getSimulatedMemoryUsage();

  // Cleanup
  for (final file in files) {
    file.dispose();
  }
  memorySnapshots['after_cleanup'] = _getSimulatedMemoryUsage();

  print('  Memory usage simulation:');
  memorySnapshots.forEach((phase, usage) {
    print('    $phase: ${usage}KB');
  });

  // Monitor 3: Throughput measurement
  print('\nMonitor 3: Throughput measurement');
  const testDuration = Duration(seconds: 2);
  final endTime = DateTime.now().add(testDuration);
  var operationCount = 0;

  while (DateTime.now().isBefore(endTime)) {
    PhonicAudioFile? testFile;
    try {
      testFile = Phonic.fromBytes(_createTestMp3(operationCount), 'throughput_$operationCount.mp3');
      final title = testFile.getTag(TagKey.title);
      if (title != null) operationCount++;
    } finally {
      testFile?.dispose();
    }
  }

  final throughput = operationCount / testDuration.inSeconds;
  print('  Processed $operationCount operations in ${testDuration.inSeconds}s');
  print('  Throughput: ${throughput.toStringAsFixed(1)} operations/second');

  print('');
}

/// Demonstrates handling of large audio collections.
Future<void> largeCollectionHandling() async {
  print('6. Large Collection Handling');
  print('----------------------------');

  const collectionSize = 100;
  print('Simulating collection of $collectionSize files...');

  // Strategy 1: Streaming with progress reporting
  print('\nStrategy 1: Streaming with progress');
  final stopwatch = Stopwatch()..start();
  var processedCount = 0;

  for (int i = 0; i < collectionSize; i++) {
    PhonicAudioFile? audioFile;
    try {
      audioFile = Phonic.fromBytes(_createTestMp3(i), 'collection_$i.mp3');

      // Quick metadata extraction
      final title = audioFile.getTag(TagKey.title);
      if (title != null) processedCount++;

      // Progress reporting
      if ((i + 1) % 20 == 0) {
        final elapsed = stopwatch.elapsedMilliseconds;
        final rate = (i + 1) / elapsed * 1000;
        print('  Progress: ${i + 1}/$collectionSize (${rate.toStringAsFixed(1)} files/sec)');
      }
    } finally {
      audioFile?.dispose();
    }
  }

  stopwatch.stop();
  print('  Completed: $processedCount files in ${stopwatch.elapsedMilliseconds}ms');

  // Strategy 2: Parallel processing simulation
  print('\nStrategy 2: Batch parallel processing');
  const batchSize = 10;
  final totalStopwatch = Stopwatch()..start();
  var batchProcessedCount = 0;

  for (int batchStart = 0; batchStart < collectionSize; batchStart += batchSize) {
    final batchEnd = (batchStart + batchSize).clamp(0, collectionSize);
    final batchStopwatch = Stopwatch()..start();

    // Process batch (simulating parallel processing)
    final batchResults = <String>[];
    for (int i = batchStart; i < batchEnd; i++) {
      PhonicAudioFile? audioFile;
      try {
        audioFile = Phonic.fromBytes(_createTestMp3(i), 'batch_$i.mp3');
        final title = audioFile.getTag(TagKey.title);
        if (title != null) {
          batchResults.add(title.value);
          batchProcessedCount++;
        }
      } finally {
        audioFile?.dispose();
      }
    }

    batchStopwatch.stop();
    print('  Batch ${(batchStart ~/ batchSize) + 1}: ${batchResults.length} files in ${batchStopwatch.elapsedMilliseconds}ms');
  }

  totalStopwatch.stop();
  print('  Total batch processing: $batchProcessedCount files in ${totalStopwatch.elapsedMilliseconds}ms');

  // Strategy 3: Index-based processing
  print('\nStrategy 3: Index-based metadata extraction');
  final metadataIndex = <String, Map<String, String>>{};
  final indexStopwatch = Stopwatch()..start();

  for (int i = 0; i < collectionSize ~/ 5; i++) {
    // Process subset for demo
    PhonicAudioFile? audioFile;
    try {
      final filename = 'indexed_$i.mp3';
      audioFile = Phonic.fromBytes(_createTestMp3(i), filename);

      // Extract key metadata for index
      final metadata = <String, String>{};
      final title = audioFile.getTag(TagKey.title);
      final artist = audioFile.getTag(TagKey.artist);

      if (title != null) metadata['title'] = title.value;
      if (artist != null) metadata['artist'] = artist.value;

      metadataIndex[filename] = metadata;
    } finally {
      audioFile?.dispose();
    }
  }

  indexStopwatch.stop();
  print('  Created index for ${metadataIndex.length} files in ${indexStopwatch.elapsedMilliseconds}ms');
  print('  Index size: ${metadataIndex.length} entries');

  print('');
}

/// Demonstrates memory pressure handling techniques.
Future<void> memoryPressureHandling() async {
  print('7. Memory Pressure Handling');
  print('---------------------------');

  // Technique 1: Aggressive disposal
  print('Technique 1: Aggressive disposal');
  const fileCount = 50;
  var maxMemoryUsage = 0;
  var currentMemoryUsage = 0;

  for (int i = 0; i < fileCount; i++) {
    PhonicAudioFile? audioFile;
    try {
      audioFile = Phonic.fromBytes(_createTestMp3(i), 'pressure_$i.mp3');
      currentMemoryUsage += 100; // Simulate memory usage
      maxMemoryUsage = maxMemoryUsage > currentMemoryUsage ? maxMemoryUsage : currentMemoryUsage;

      // Quick processing
      final title = audioFile.getTag(TagKey.title);
      if (title != null && i % 10 == 0) {
        print('  Processed: ${title.value}');
      }
    } finally {
      audioFile?.dispose();
      currentMemoryUsage -= 100; // Simulate memory release
    }
  }

  print('  Max memory usage: ${maxMemoryUsage}KB');
  print('  Final memory usage: ${currentMemoryUsage}KB');

  // Technique 2: Memory threshold monitoring
  print('\nTechnique 2: Memory threshold monitoring');
  const memoryThreshold = 500; // KB
  var filesProcessed = 0;
  var memoryCleanups = 0;
  currentMemoryUsage = 0;

  for (int i = 0; i < 30; i++) {
    PhonicAudioFile? audioFile;
    try {
      audioFile = Phonic.fromBytes(_createTestMp3(i), 'threshold_$i.mp3');
      currentMemoryUsage += 150; // Simulate larger memory usage

      // Check memory threshold
      if (currentMemoryUsage > memoryThreshold) {
        print('  Memory threshold exceeded: ${currentMemoryUsage}KB > ${memoryThreshold}KB');

        // Simulate cleanup
        await Future.delayed(const Duration(milliseconds: 1));
        currentMemoryUsage = currentMemoryUsage ~/ 2; // Simulate garbage collection
        memoryCleanups++;

        print('  Memory cleaned up to: ${currentMemoryUsage}KB');
      }

      final title = audioFile.getTag(TagKey.title);
      if (title != null) filesProcessed++;
    } finally {
      audioFile?.dispose();
      currentMemoryUsage -= 50; // Partial cleanup on disposal
    }
  }

  print('  Files processed: $filesProcessed');
  print('  Memory cleanups triggered: $memoryCleanups');

  // Technique 3: Lazy loading with memory budgets
  print('\nTechnique 3: Lazy loading with memory budgets');
  const memoryBudget = 1000; // KB
  var budgetUsed = 0;
  final deferredOperations = <Future<void>>[];

  for (int i = 0; i < 20; i++) {
    final estimatedCost = 100 + (i % 3) * 50; // Variable cost

    if (budgetUsed + estimatedCost > memoryBudget) {
      // Defer operation
      deferredOperations.add(_deferredProcessing(i));
      print('  Deferred file $i (would exceed budget)');
    } else {
      // Process immediately
      PhonicAudioFile? audioFile;
      try {
        audioFile = Phonic.fromBytes(_createTestMp3(i), 'budget_$i.mp3');
        budgetUsed += estimatedCost;

        final title = audioFile.getTag(TagKey.title);
        print('  Processed file $i: ${title?.value} (budget: ${budgetUsed}KB)');
      } finally {
        audioFile?.dispose();
      }
    }
  }

  print('  Deferred operations: ${deferredOperations.length}');
  print('  Budget utilization: ${(budgetUsed / memoryBudget * 100).toStringAsFixed(1)}%');

  // Process deferred operations
  print('  Processing deferred operations...');
  await Future.wait(deferredOperations);
  print('  All deferred operations completed');

  print('');
}

// Helper methods

Uint8List _createTestMp3(int index) {
  final id3Header = [
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x00, 0x20, // Size
  ];

  final titleFrame = [
    0x54, 0x49, 0x54, 0x32, // "TIT2"
    0x00, 0x00, 0x00, 0x10, // Size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Test Song $index'.codeUnits),
  ];

  final audioData = [
    0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
    ...List.filled(100, index % 256), // Unique audio data
  ];

  return Uint8List.fromList([...id3Header, ...titleFrame, ...audioData]);
}

Uint8List _createMp3WithLargeArtwork() {
  final basicMp3 = _createTestMp3(0);

  // Add large artwork frame
  final artworkFrame = [
    0x41, 0x50, 0x49, 0x43, // "APIC"
    0x00, 0x00, 0x10, 0x00, // Size (4KB artwork)
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('image/jpeg'.codeUnits),
    0x00, // Null terminator
    0x03, // Picture type (front cover)
    ...('Album Cover'.codeUnits),
    0x00, // Null terminator
    // Large image data
    0xFF, 0xD8, // JPEG header
    ...List.filled(4000, 0x80), // Large image data
    0xFF, 0xD9, // JPEG end
  ];

  return Uint8List.fromList([...basicMp3, ...artworkFrame]);
}

Stream<ProcessingResult> _processFilesAsStream(List<(String, Uint8List)> files) async* {
  for (final (filename, bytes) in files) {
    try {
      final audioFile = Phonic.fromBytes(bytes, filename);
      final title = audioFile.getTag(TagKey.title);
      audioFile.dispose();

      yield ProcessingResult(
        success: true,
        filename: filename,
        data: title?.value,
      );
    } catch (e) {
      yield ProcessingResult(
        success: false,
        filename: filename,
        error: e.toString(),
      );
    }

    // Yield control to allow other operations
    await Future.delayed(Duration.zero);
  }
}

int _getSimulatedMemoryUsage() {
  // Simulate memory usage calculation
  return DateTime.now().millisecondsSinceEpoch % 10000;
}

Future<void> _deferredProcessing(int index) async {
  // Simulate deferred processing
  await Future.delayed(const Duration(milliseconds: 10));
  print('    Completed deferred processing for file $index');
}

class ProcessingResult {
  final bool success;
  final String filename;
  final String? data;
  final String? error;

  ProcessingResult({
    required this.success,
    required this.filename,
    this.data,
    this.error,
  });
}
