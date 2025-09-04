// ignore_for_file: avoid_print

import 'package:phonic/phonic.dart';

/// Example demonstrating streaming operations for processing large collections
/// of audio files without loading all files into memory simultaneously.
void main() async {
  print('Phonic Streaming Operations Example');
  print('===================================\n');

  // Example 1: Basic streaming processing
  await basicStreamingExample();

  // Example 2: Batch processing with memory limits
  await batchProcessingExample();

  // Example 3: Collection analysis
  await collectionAnalysisExample();

  // Example 4: Progress reporting and cancellation
  await progressAndCancellationExample();
}

/// Demonstrates basic streaming processing of audio files.
Future<void> basicStreamingExample() async {
  print('1. Basic Streaming Processing');
  print('-----------------------------');

  // Create a streaming processor with default configuration
  final processor = StreamingAudioProcessor();

  // Simulate a list of audio files (in practice, these would be real file paths)
  final audioFiles = [
    'music/song1.mp3',
    'music/song2.flac',
    'music/song3.m4a',
    'music/song4.ogg',
  ];

  print('Processing ${audioFiles.length} files...');

  try {
    final results = await processor.processFiles(
      filePaths: audioFiles,
      processor: (audioFile, index, total) async {
        // Process each audio file
        final title = audioFile.getTag(TagKey.title);
        final artist = audioFile.getTag(TagKey.artist);

        print('  [$index/$total] ${title?.value ?? "Unknown"} by ${artist?.value ?? "Unknown"}');

        // Simulate some processing work
        await Future.delayed(const Duration(milliseconds: 100));

        return ProcessingResult.success(data: 'Processed ${title?.value}');
      },
      onProgress: (progress) {
        print(
          '  Progress: ${progress.percentage.toStringAsFixed(1)}% '
          '(${progress.processed}/${progress.total})',
        );
      },
    );

    final successCount = results.where((r) => r.success).length;
    final errorCount = results.where((r) => !r.success).length;

    print('Completed: $successCount successful, $errorCount errors\n');
  } catch (e) {
    print('Error during processing: $e\n');
  }
}

/// Demonstrates batch processing with memory management.
Future<void> batchProcessingExample() async {
  print('2. Batch Processing with Memory Limits');
  print('--------------------------------------');

  // Create a batch processor with memory constraints
  final batchProcessor = BatchAudioProcessor(
    config: StreamingConfig.forLargeCollections(),
  );

  // Simulate a large collection of files
  final largeCollection = List.generate(20, (i) => 'music/batch_song_$i.mp3');

  print('Processing ${largeCollection.length} files in batches...');

  try {
    final results = await batchProcessor.processBatches(
      filePaths: largeCollection,
      batchSize: 5, // Process 5 files at a time
      processor: (batch) async {
        print('  Processing batch of ${batch.length} files...');

        // Simulate batch processing
        final batchResults = <ProcessingResult>[];
        for (final filePath in batch) {
          // Simulate processing each file in the batch
          await Future.delayed(const Duration(milliseconds: 50));
          batchResults.add(ProcessingResult.success(data: 'Processed $filePath'));
        }

        return batchResults;
      },
      onProgress: (progress) {
        print('  Batch Progress: ${progress.percentage.toStringAsFixed(1)}%');
      },
    );

    print('Batch processing completed: ${results.length} files processed\n');
  } catch (e) {
    print('Error during batch processing: $e\n');
  }
}

/// Demonstrates collection analysis for gathering statistics.
Future<void> collectionAnalysisExample() async {
  print('3. Collection Analysis');
  print('---------------------');

  final analyzer = CollectionAnalyzer();

  // Simulate analyzing a music library
  final musicLibrary = [
    'library/rock/song1.mp3',
    'library/jazz/song2.flac',
    'library/classical/song3.m4a',
    'library/electronic/song4.ogg',
  ];

  print('Analyzing collection of ${musicLibrary.length} files...');

  try {
    final stats = await analyzer.analyzeCollection(
      filePaths: musicLibrary,
      maxMemoryMB: 200, // Limit memory usage
      onProgress: (progress) {
        print('  Analysis Progress: ${progress.percentage.toStringAsFixed(1)}%');
      },
    );

    print('Analysis Results:');
    print('  Total Files: ${stats.totalFiles}');
    print('  Files with Title: ${stats.filesWithTitle}');
    print('  Files with Artist: ${stats.filesWithArtist}');
    print('  Files with Album: ${stats.filesWithAlbum}');
    print('  Unique Artists: ${stats.uniqueArtists.length}');
    print('  Unique Albums: ${stats.uniqueAlbums.length}');
    print('  Unique Genres: ${stats.uniqueGenres.length}');
    print('  Errors: ${stats.errorCount}');

    if (stats.memoryPeak != null) {
      print('  Peak Memory Usage: ${_formatBytes(stats.memoryPeak!)}');
    }
  } catch (e) {
    print('Error during analysis: $e\n');
  }
}

/// Demonstrates progress reporting and operation cancellation.
Future<void> progressAndCancellationExample() async {
  print('4. Progress Reporting and Cancellation');
  print('--------------------------------------');

  final processor = StreamingAudioProcessor(
    config: const StreamingConfig(
      progressReportInterval: 2, // Report progress every 2 files
      enableMemoryMonitoring: true,
    ),
  );

  final cancellationToken = CancellationToken();

  // Simulate a long-running operation
  final manyFiles = List.generate(10, (i) => 'music/long_song_$i.mp3');

  print('Starting long-running operation (will cancel after 3 files)...');

  // Cancel the operation after a delay
  Timer(const Duration(milliseconds: 350), () {
    print('  Cancelling operation...');
    cancellationToken.cancel();
  });

  try {
    await for (final result in processor.processFilesAsStream(
      filePaths: manyFiles,
      processor: (audioFile, index, total) async {
        print('  Processing file $index...');

        // Simulate processing time
        await Future.delayed(const Duration(milliseconds: 100));

        return ProcessingResult.success();
      },
      onProgress: (progress) {
        print('  Progress: ${progress.processed}/${progress.total} files');
        if (progress.itemsPerSecond != null) {
          print('    Rate: ${progress.itemsPerSecond!.toStringAsFixed(1)} files/sec');
        }
        if (progress.estimatedTimeRemaining != null) {
          print('    ETA: ${progress.estimatedTimeRemaining}');
        }
      },
      cancellationToken: cancellationToken,
    )) {
      if (result.success) {
        print('    ✓ File processed successfully');
      } else {
        print('    ✗ File processing failed: ${result.error}');
      }
    }

    print('Operation completed (may have been cancelled)\n');
  } catch (e) {
    print('Error during streaming: $e\n');
  }

  // Show memory usage report
  final memoryReport = processor.getMemoryReport();
  if (memoryReport != null) {
    print('Memory Usage Report:');
    print('  Checkpoints: ${memoryReport.checkpoints.length}');
    if (memoryReport.memoryGrowth != null) {
      print('  Memory Growth: ${_formatBytes(memoryReport.memoryGrowth!)}');
    }
    if (memoryReport.peakMemoryUsage != null) {
      print('  Peak Usage: ${_formatBytes(memoryReport.peakMemoryUsage!)}');
    }
    print('  Memory Leak Detected: ${memoryReport.hasMemoryLeak}');
  }
}

/// Formats bytes in a human-readable format.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
}

/// Timer implementation for demonstration purposes.
class Timer {
  Timer(Duration duration, void Function() callback) {
    Future.delayed(duration, callback);
  }
}
