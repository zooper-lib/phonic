# Streaming Operations

This guide covers using Phonic's streaming capabilities to efficiently process large collections of audio files without loading everything into memory at once.

## Overview

Phonic provides powerful streaming operations for:

- Processing large music libraries
- Batch metadata operations
- Collection analysis and reporting
- Memory-efficient artwork handling
- Progress tracking and cancellation

## Core Streaming Classes

### StreamingAudioProcessor

The main class for streaming file operations:

```dart
final processor = StreamingAudioProcessor();
```

### BatchAudioProcessor

For processing files in controlled batches:

```dart
final batchProcessor = BatchAudioProcessor(
  batchSize: 50,
  memoryLimitMB: 100,
);
```

### CollectionAnalyzer

For analyzing audio collections:

```dart
final analyzer = CollectionAnalyzer();
```

## Basic Streaming Processing

### Simple File Processing

```dart
import 'package:phonic/phonic.dart';

Future<void> processAudioFiles() async {
  final processor = StreamingAudioProcessor();

  final audioFiles = [
    'music/album1/track1.mp3',
    'music/album1/track2.mp3',
    'music/album2/track1.flac',
    'music/album2/track2.flac',
    // ... many more files
  ];

  print('Processing ${audioFiles.length} files...');

  final results = await processor.processFiles(
    filePaths: audioFiles,
    processor: (audioFile, index, total) async {
      // Process each file individually
      final title = audioFile.getTag(TagKey.title);
      final artist = audioFile.getTag(TagKey.artist);
      final album = audioFile.getTag(TagKey.album);

      print('[$index/$total] ${title?.value ?? "Unknown"} by ${artist?.value ?? "Unknown"}');

      // Return success result
      return ProcessingResult.success();
    },
  );

  print('Processed ${results.successCount} files successfully');
  print('Failed: ${results.failureCount} files');
}
```

### With Configuration

```dart
Future<void> configuredProcessing() async {
  final config = StreamingConfig(
    batchSize: 25,
    maxConcurrency: 4,
    memoryLimitMB: 200,
    enableProgressReporting: true,
  );

  final processor = StreamingAudioProcessor(config: config);

  final results = await processor.processFiles(
    filePaths: await _discoverAudioFiles('music/'),
    processor: (audioFile, index, total) async {
      // Your processing logic here
      return await _processAudioFile(audioFile);
    },
  );
}

Future<List<String>> _discoverAudioFiles(String directory) async {
  final dir = Directory(directory);
  final files = <String>[];

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      final extension = path.extension(entity.path).toLowerCase();
      if (['.mp3', '.flac', '.ogg', '.opus', '.m4a', '.mp4'].contains(extension)) {
        files.add(entity.path);
      }
    }
  }

  return files;
}
```

## Batch Processing

### Memory-Controlled Batches

```dart
Future<void> batchProcessing() async {
  final batchProcessor = BatchAudioProcessor(
    batchSize: 50,                 // Process 50 files per batch
    memoryLimitMB: 100,           // Limit memory usage
    enableMemoryMonitoring: true,
  );

  final allFiles = await _discoverAudioFiles('large_music_library/');
  print('Found ${allFiles.length} audio files');

  await batchProcessor.processBatches(
    filePaths: allFiles,
    batchProcessor: (batch, batchIndex, totalBatches) async {
      print('Processing batch ${batchIndex + 1}/$totalBatches (${batch.length} files)');

      // Process files in current batch
      final results = <String, String>{};

      for (final audioFile in batch) {
        try {
          final title = audioFile.getTag(TagKey.title);
          final artist = audioFile.getTag(TagKey.artist);
          results[audioFile.toString()] = '${title?.value} by ${artist?.value}';
        } catch (e) {
          print('Error processing file: $e');
        }
      }

      // Optional: Save batch results
      await _saveBatchResults(batchIndex, results);

      return ProcessingResult.success();
    },
  );
}

Future<void> _saveBatchResults(int batchIndex, Map<String, String> results) async {
  final file = File('batch_results_$batchIndex.json');
  await file.writeAsString(jsonEncode(results));
}
```

### Batch Memory Monitoring

```dart
Future<void> monitoredBatchProcessing() async {
  final memoryMonitor = BatchMemoryMonitor(
    memoryLimitMB: 150,
    checkIntervalMs: 1000,
    enableGarbageCollection: true,
  );

  final processor = BatchAudioProcessor(
    batchSize: 30,
    memoryLimitMB: 100,
    memoryMonitor: memoryMonitor,
  );

  // Monitor memory usage during processing
  memoryMonitor.memoryPressureStream.listen((pressure) {
    if (pressure.isHighPressure) {
      print('High memory pressure detected: ${pressure.usagePercent.toStringAsFixed(1)}%');
    }
  });

  await processor.processBatches(
    filePaths: await _discoverAudioFiles('music/'),
    batchProcessor: (batch, batchIndex, totalBatches) async {
      // Process with automatic memory management
      return await _processBatchWithMonitoring(batch, memoryMonitor);
    },
  );

  memoryMonitor.dispose();
}
```

## Collection Analysis

### Metadata Analysis

```dart
Future<void> analyzeCollection() async {
  final analyzer = CollectionAnalyzer();

  final analysis = await analyzer.analyzeCollection(
    filePaths: await _discoverAudioFiles('music_library/'),
    includeArtwork: true,
    includeStatistics: true,
  );

  print('Collection Analysis Results:');
  print('============================');
  print('Total files: ${analysis.totalFiles}');
  print('Total size: ${(analysis.totalSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB');
  print('');

  // Format distribution
  print('Format Distribution:');
  for (final entry in analysis.formatDistribution.entries) {
    final percent = (entry.value / analysis.totalFiles * 100).toStringAsFixed(1);
    print('  ${entry.key}: ${entry.value} files (${percent}%)');
  }
  print('');

  // Quality analysis
  print('Quality Distribution:');
  for (final entry in analysis.qualityDistribution.entries) {
    print('  ${entry.key}: ${entry.value} files');
  }
  print('');

  // Metadata completeness
  print('Metadata Completeness:');
  final completeness = analysis.metadataCompleteness;
  print('  Title: ${(completeness.titlePercent).toStringAsFixed(1)}%');
  print('  Artist: ${(completeness.artistPercent).toStringAsFixed(1)}%');
  print('  Album: ${(completeness.albumPercent).toStringAsFixed(1)}%');
  print('  Genre: ${(completeness.genrePercent).toStringAsFixed(1)}%');
  print('  Artwork: ${(completeness.artworkPercent).toStringAsFixed(1)}%');

  // Issues found
  if (analysis.issues.isNotEmpty) {
    print('');
    print('Issues Found:');
    for (final issue in analysis.issues) {
      print('  ${issue.severity}: ${issue.description} (${issue.affectedFiles.length} files)');
    }
  }
}
```

### Duplicate Detection

```dart
Future<void> findDuplicates() async {
  final analyzer = CollectionAnalyzer();

  final duplicates = await analyzer.findDuplicates(
    filePaths: await _discoverAudioFiles('music/'),
    compareBy: [
      DuplicateCompareField.title,
      DuplicateCompareField.artist,
      DuplicateCompareField.duration,
    ],
    tolerancePercent: 95.0, // 95% similarity threshold
  );

  print('Found ${duplicates.length} potential duplicate groups:');

  for (int i = 0; i < duplicates.length; i++) {
    final group = duplicates[i];
    print('\\nDuplicate Group ${i + 1} (${group.files.length} files):');
    print('Similarity: ${group.similarity.toStringAsFixed(1)}%');

    for (final file in group.files) {
      print('  - ${path.basename(file.path)}');
      print('    Title: ${file.metadata.title ?? "Unknown"}');
      print('    Artist: ${file.metadata.artist ?? "Unknown"}');
      print('    Size: ${(file.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB');
    }
  }
}
```

## Progress Tracking and Cancellation

### Progress Reporting

```dart
Future<void> processWithProgress() async {
  final processor = StreamingAudioProcessor(
    config: StreamingConfig(enableProgressReporting: true),
  );

  // Create cancellation token for user control
  final cancellationToken = CancellationToken();

  // Listen to progress updates
  processor.progressStream.listen((progress) {
    final percent = (progress.processedCount / progress.totalCount * 100).toStringAsFixed(1);
    print('Progress: $percent% (${progress.processedCount}/${progress.totalCount})');
    print('Current: ${progress.currentFile}');
    print('Rate: ${progress.filesPerSecond.toStringAsFixed(1)} files/sec');
    print('ETA: ${progress.estimatedTimeRemaining}');
  });

  try {
    final results = await processor.processFiles(
      filePaths: await _discoverAudioFiles('music/'),
      processor: (audioFile, index, total) async {
        // Check for cancellation
        if (cancellationToken.isCancelled) {
          return ProcessingResult.cancelled();
        }

        // Simulate work
        await Future.delayed(const Duration(milliseconds: 100));

        return ProcessingResult.success();
      },
      cancellationToken: cancellationToken,
    );

    if (results.wasCancelled) {
      print('Processing was cancelled');
    } else {
      print('Processing completed successfully');
    }

  } on ProcessingCancelledException {
    print('Processing was cancelled by user');
  }
}
```

### Interactive Cancellation

```dart
Future<void> processWithUserControl() async {
  final processor = StreamingAudioProcessor();
  final cancellationToken = CancellationToken();

  // Start processing in background
  final processingFuture = processor.processFiles(
    filePaths: await _discoverAudioFiles('large_library/'),
    processor: (audioFile, index, total) async {
      // Your processing logic
      return ProcessingResult.success();
    },
    cancellationToken: cancellationToken,
  );

  // Monitor user input for cancellation
  print('Processing started. Press Enter to cancel...');
  stdin.readLineSync(); // Wait for user input

  print('Cancelling processing...');
  cancellationToken.cancel();

  try {
    final results = await processingFuture;
    print('Cancelled. Processed ${results.successCount} files before cancellation.');
  } on ProcessingCancelledException {
    print('Processing was successfully cancelled');
  }
}
```

## Error Handling and Recovery

### Robust Processing

```dart
Future<void> robustProcessing() async {
  final processor = StreamingAudioProcessor();

  final results = await processor.processFiles(
    filePaths: await _discoverAudioFiles('music/'),
    processor: (audioFile, index, total) async {
      try {
        // Attempt to process file
        return await _processAudioFileWithValidation(audioFile);

      } on UnsupportedFormatException catch (e) {
        print('Skipping unsupported format: ${e.message}');
        return ProcessingResult.skipped('Unsupported format');

      } on CorruptedContainerException catch (e) {
        print('Skipping corrupted file: ${e.message}');
        return ProcessingResult.skipped('Corrupted file');

      } on FileSystemException catch (e) {
        print('File system error: ${e.message}');
        return ProcessingResult.error(e.message);

      } catch (e) {
        print('Unexpected error: $e');
        return ProcessingResult.error('Unexpected error: $e');
      }
    },
  );

  // Report final results
  print('Processing Summary:');
  print('  Successful: ${results.successCount}');
  print('  Skipped: ${results.skippedCount}');
  print('  Failed: ${results.failureCount}');

  if (results.errors.isNotEmpty) {
    print('\\nErrors encountered:');
    for (final error in results.errors.take(10)) { // Show first 10 errors
      print('  ${error.filePath}: ${error.message}');
    }

    if (results.errors.length > 10) {
      print('  ... and ${results.errors.length - 10} more errors');
    }
  }
}

Future<ProcessingResult> _processAudioFileWithValidation(PhonicAudioFile audioFile) async {
  // Validate required metadata
  final title = audioFile.getTag(TagKey.title);
  final artist = audioFile.getTag(TagKey.artist);

  if (title == null || title.value.trim().isEmpty) {
    return ProcessingResult.skipped('Missing title');
  }

  if (artist == null || artist.value.trim().isEmpty) {
    return ProcessingResult.skipped('Missing artist');
  }

  // Process the file
  // ... your processing logic here ...

  return ProcessingResult.success();
}
```

## Performance Optimization

### Optimized Configuration

```dart
Future<void> optimizedProcessing() async {
  // Determine optimal settings based on system resources
  final coreCount = Platform.numberOfProcessors;
  final memoryMB = _getAvailableMemoryMB();

  final config = StreamingConfig(
    batchSize: min(50, max(10, memoryMB ~/ 10)),  // Adaptive batch size
    maxConcurrency: max(2, coreCount - 1),        // Leave one core free
    memoryLimitMB: (memoryMB * 0.3).round(),      // Use 30% of available memory
    enableProgressReporting: true,
    enableMemoryMonitoring: true,
  );

  print('Optimized settings:');
  print('  Batch size: ${config.batchSize}');
  print('  Concurrency: ${config.maxConcurrency}');
  print('  Memory limit: ${config.memoryLimitMB} MB');

  final processor = StreamingAudioProcessor(config: config);

  // Process with optimized settings
  await processor.processFiles(
    filePaths: await _discoverAudioFiles('music/'),
    processor: (audioFile, index, total) async {
      return await _optimizedFileProcessing(audioFile);
    },
  );
}

int _getAvailableMemoryMB() {
  // Platform-specific memory detection would go here
  // For now, return a reasonable default
  return 2048; // 2GB default
}

Future<ProcessingResult> _optimizedFileProcessing(PhonicAudioFile audioFile) async {
  // Minimize memory allocations
  final tags = <TagKey, String>{};

  // Read only needed tags
  final title = audioFile.getTag(TagKey.title);
  if (title != null) tags[TagKey.title] = title.value;

  final artist = audioFile.getTag(TagKey.artist);
  if (artist != null) tags[TagKey.artist] = artist.value;

  // Process without creating large objects
  return ProcessingResult.success(data: tags);
}
```

## Common Use Cases

### Library Organization

```dart
Future<void> organizeLibrary() async {
  final processor = StreamingAudioProcessor();

  await processor.processFiles(
    filePaths: await _discoverAudioFiles('unsorted_music/'),
    processor: (audioFile, index, total) async {
      try {
        // Extract metadata
        final artist = audioFile.getTag(TagKey.artist)?.value ?? 'Unknown Artist';
        final album = audioFile.getTag(TagKey.album)?.value ?? 'Unknown Album';
        final title = audioFile.getTag(TagKey.title)?.value ?? 'Unknown Title';
        final track = audioFile.getTag(TagKey.trackNumber);

        // Create organized file path
        final safeName = _sanitizeFilename(title);
        final trackPrefix = track != null ? '${track.value.toString().padLeft(2, '0')} - ' : '';
        final newFilename = '$trackPrefix$safeName.mp3';

        final newDir = Directory('organized_music/${_sanitizeFilename(artist)}/${_sanitizeFilename(album)}');
        await newDir.create(recursive: true);

        final newPath = path.join(newDir.path, newFilename);

        // Save to new location
        final encodedData = await audioFile.encode();
        await File(newPath).writeAsBytes(encodedData);

        print('Organized: $newPath');
        return ProcessingResult.success();

      } catch (e) {
        return ProcessingResult.error('Failed to organize: $e');
      }
    },
  );
}

String _sanitizeFilename(String filename) {
  // Remove illegal filename characters
  return filename
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
}
```

### Metadata Validation and Cleanup

```dart
Future<void> validateAndCleanMetadata() async {
  final issues = <String>[];
  final processor = StreamingAudioProcessor();

  await processor.processFiles(
    filePaths: await _discoverAudioFiles('music/'),
    processor: (audioFile, index, total) async {
      var wasModified = false;
      final filePath = audioFile.toString(); // This would need to be passed in

      // Validate and clean title
      final titleTag = audioFile.getTag(TagKey.title);
      if (titleTag != null) {
        final cleanTitle = _cleanText(titleTag.value);
        if (cleanTitle != titleTag.value) {
          audioFile.setTag(TitleTag(cleanTitle));
          wasModified = true;
        }
      } else {
        issues.add('$filePath: Missing title');
      }

      // Validate and clean artist
      final artistTag = audioFile.getTag(TagKey.artist);
      if (artistTag != null) {
        final cleanArtist = _cleanText(artistTag.value);
        if (cleanArtist != artistTag.value) {
          audioFile.setTag(ArtistTag(cleanArtist));
          wasModified = true;
        }
      } else {
        issues.add('$filePath: Missing artist');
      }

      // Normalize genres
      final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
      if (genreTag != null) {
        final normalizedGenres = genreTag.value
            .map(_normalizeGenre)
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList();

        if (!_listsEqual(normalizedGenres, genreTag.value)) {
          audioFile.setTag(GenreTag(normalizedGenres));
          wasModified = true;
        }
      }

      // Save if modified
      if (wasModified) {
        try {
          final encodedData = await audioFile.encode();
          // Would need to save back to original file
          return ProcessingResult.success(data: 'Modified');
        } catch (e) {
          return ProcessingResult.error('Failed to save: $e');
        }
      }

      return ProcessingResult.success();
    },
  );

  // Report issues found
  if (issues.isNotEmpty) {
    print('\\nIssues found:');
    for (final issue in issues) {
      print('  $issue');
    }
  }
}

String _cleanText(String text) {
  return text
      .trim()
      .replaceAll(RegExp(r'\\s+'), ' ')  // Normalize whitespace
      .replaceAll(RegExp(r'[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]'), ''); // Remove control chars
}

String _normalizeGenre(String genre) {
  final normalized = {
    'rock': 'Rock',
    'pop': 'Pop',
    'jazz': 'Jazz',
    'blues': 'Blues',
    'electronic': 'Electronic',
    'classical': 'Classical',
    'country': 'Country',
    'hip-hop': 'Hip-Hop',
    'hip hop': 'Hip-Hop',
    'r&b': 'R&B',
    'rnb': 'R&B',
  };

  return normalized[genre.toLowerCase()] ?? genre;
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

## Next Steps

- **[Performance Optimization](performance-optimization.md)** - Advanced memory and performance tuning
- **[Error Handling](error-handling.md)** - Robust error handling strategies
- **[Examples](examples.md)** - Complete streaming operation examples
