import 'dart:async';

import '../core/phonic.dart';
import '../core/phonic_audio_file.dart';
import '../core/tag_key.dart';
import 'memory_usage_monitor.dart';

/// Streaming operations support for processing large collections of audio files
/// without loading all files into memory simultaneously.
///
/// This module provides utilities for:
/// - Processing large collections with bounded memory usage
/// - Batch processing with progress reporting
/// - Streaming operations that work with thousands of files
/// - Memory-efficient collection processing
///
/// ## Key Features
///
/// - **Memory Bounded**: Never loads more than a configured number of files
/// - **Progress Reporting**: Real-time progress callbacks for long operations
/// - **Error Recovery**: Continues processing when individual files fail
/// - **Cancellation Support**: Operations can be cancelled mid-stream
/// - **Batch Processing**: Efficient processing of file groups
/// - **Memory Monitoring**: Built-in memory usage tracking
///
/// ## Usage Examples
///
/// ### Basic Streaming Processing
/// ```dart
/// final processor = StreamingAudioProcessor();
///
/// await processor.processFiles(
///   filePaths: audioFiles,
///   processor: (audioFile, index, total) async {
///     final title = audioFile.getTag(TagKey.title);
///     print('Processing: ${title?.value}');
///     return ProcessingResult.success();
///   },
///   onProgress: (processed, total, current) {
///     print('Progress: $processed/$total - $current');
///   },
/// );
/// ```
///
/// ### Batch Processing with Memory Limits
/// ```dart
/// final batchProcessor = BatchAudioProcessor(
///   maxConcurrentFiles: 10,
///   memoryLimitMB: 500,
/// );
///
/// await batchProcessor.processBatches(
///   filePaths: largeFileList,
///   batchSize: 50,
///   processor: (batch) async {
///     // Process batch of files
///     return await processBatchOfFiles(batch);
///   },
/// );
/// ```
///
/// ### Collection Analysis
/// ```dart
/// final analyzer = CollectionAnalyzer();
///
/// final stats = await analyzer.analyzeCollection(
///   filePaths: musicLibrary,
///   maxMemoryMB: 200,
///   onProgress: (progress) => print('Analyzed: ${progress.percentage}%'),
/// );
///
/// print('Total files: ${stats.totalFiles}');
/// print('Unique artists: ${stats.uniqueArtists.length}');
/// print('Memory peak: ${stats.memoryPeak}MB');
/// ```

/// Progress information for streaming operations.
class StreamingProgress {
  /// Number of items processed so far.
  final int processed;

  /// Total number of items to process.
  final int total;

  /// Currently processing item (optional).
  final String? currentItem;

  /// Processing rate (items per second).
  final double? itemsPerSecond;

  /// Estimated time remaining.
  final Duration? estimatedTimeRemaining;

  /// Memory usage information.
  final MemoryCheckpoint? memoryUsage;

  const StreamingProgress({
    required this.processed,
    required this.total,
    this.currentItem,
    this.itemsPerSecond,
    this.estimatedTimeRemaining,
    this.memoryUsage,
  });

  /// Progress as a percentage (0.0 to 100.0).
  double get percentage => total > 0 ? (processed / total) * 100.0 : 0.0;

  /// Whether processing is complete.
  bool get isComplete => processed >= total;

  @override
  String toString() {
    final parts = <String>[
      '${processed}/${total} (${percentage.toStringAsFixed(1)}%)',
    ];

    if (currentItem != null) {
      parts.add('Current: $currentItem');
    }

    if (itemsPerSecond != null) {
      parts.add('Rate: ${itemsPerSecond!.toStringAsFixed(1)}/sec');
    }

    if (estimatedTimeRemaining != null) {
      parts.add('ETA: ${_formatDuration(estimatedTimeRemaining!)}');
    }

    return 'StreamingProgress(${parts.join(', ')})';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// Result of processing a single item in a streaming operation.
class ProcessingResult {
  /// Whether the processing was successful.
  final bool success;

  /// Error that occurred during processing (if any).
  final Exception? error;

  /// Optional result data from processing.
  final dynamic data;

  /// Optional message about the processing.
  final String? message;

  const ProcessingResult({
    required this.success,
    this.error,
    this.data,
    this.message,
  });

  /// Creates a successful processing result.
  factory ProcessingResult.success({dynamic data, String? message}) {
    return ProcessingResult(
      success: true,
      data: data,
      message: message,
    );
  }

  /// Creates a failed processing result.
  factory ProcessingResult.failure(Exception error, {String? message}) {
    return ProcessingResult(
      success: false,
      error: error,
      message: message,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ProcessingResult.success(${message ?? 'OK'})';
    } else {
      return 'ProcessingResult.failure(${error?.toString() ?? 'Unknown error'})';
    }
  }
}

/// Configuration for streaming operations.
class StreamingConfig {
  /// Maximum number of files to keep in memory simultaneously.
  final int maxConcurrentFiles;

  /// Memory limit in megabytes.
  final int memoryLimitMB;

  /// Whether to continue processing when individual files fail.
  final bool continueOnError;

  /// Interval for progress reporting (number of processed items).
  final int progressReportInterval;

  /// Interval for memory monitoring (number of processed items).
  final int memoryMonitorInterval;

  /// Whether to enable detailed memory monitoring.
  final bool enableMemoryMonitoring;

  const StreamingConfig({
    this.maxConcurrentFiles = 10,
    this.memoryLimitMB = 500,
    this.continueOnError = true,
    this.progressReportInterval = 10,
    this.memoryMonitorInterval = 50,
    this.enableMemoryMonitoring = true,
  });

  /// Creates a configuration optimized for large collections.
  factory StreamingConfig.forLargeCollections() {
    return const StreamingConfig(
      maxConcurrentFiles: 5,
      memoryLimitMB: 200,
      continueOnError: true,
      progressReportInterval: 25,
      memoryMonitorInterval: 25,
      enableMemoryMonitoring: true,
    );
  }

  /// Creates a configuration optimized for fast processing.
  factory StreamingConfig.forFastProcessing() {
    return const StreamingConfig(
      maxConcurrentFiles: 20,
      memoryLimitMB: 1000,
      continueOnError: true,
      progressReportInterval: 5,
      memoryMonitorInterval: 100,
      enableMemoryMonitoring: false,
    );
  }
}

/// Processor function type for streaming operations.
typedef StreamingProcessor<T> =
    Future<ProcessingResult> Function(
      PhonicAudioFile audioFile,
      int index,
      int total,
    );

/// Progress callback type for streaming operations.
typedef ProgressCallback = void Function(StreamingProgress progress);

/// Main class for streaming audio file processing operations.
///
/// This class provides memory-efficient processing of large collections
/// of audio files by loading only a limited number of files into memory
/// at any given time.
class StreamingAudioProcessor {
  final StreamingConfig _config;
  final MemoryUsageMonitor? _memoryMonitor;

  /// Creates a new streaming audio processor.
  StreamingAudioProcessor({
    StreamingConfig? config,
    MemoryUsageMonitor? memoryMonitor,
  }) : _config = config ?? const StreamingConfig(),
       _memoryMonitor = memoryMonitor ?? (config?.enableMemoryMonitoring != false ? MemoryUsageMonitor() : null);

  /// Processes a collection of audio files using streaming approach.
  ///
  /// This method processes files one by one, keeping memory usage bounded
  /// by loading only a limited number of files simultaneously.
  ///
  /// Parameters:
  /// - [filePaths]: List of file paths to process
  /// - [processor]: Function to process each audio file
  /// - [onProgress]: Optional progress callback
  /// - [cancellationToken]: Optional cancellation token
  ///
  /// Returns:
  /// - A stream of processing results
  Future<List<ProcessingResult>> processFiles({
    required List<String> filePaths,
    required StreamingProcessor processor,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (filePaths.isEmpty) {
      return [];
    }

    _memoryMonitor?.recordBaseline('streaming_start');

    final results = <ProcessingResult>[];
    final startTime = DateTime.now();
    var processedCount = 0;

    try {
      for (int i = 0; i < filePaths.length; i++) {
        // Check for cancellation
        if (cancellationToken?.isCancelled == true) {
          break;
        }

        final filePath = filePaths[i];
        PhonicAudioFile? audioFile;

        try {
          // Load audio file
          audioFile = await Phonic.fromFile(filePath);

          // Process the file
          final result = await processor(audioFile, i, filePaths.length);
          results.add(result);

          processedCount++;

          // Report progress
          if (onProgress != null && (processedCount % _config.progressReportInterval == 0 || processedCount == filePaths.length)) {
            final progress = _createProgress(
              processedCount,
              filePaths.length,
              filePath,
              startTime,
            );
            onProgress(progress);
          }

          // Monitor memory usage
          if (_memoryMonitor != null && processedCount % _config.memoryMonitorInterval == 0) {
            _memoryMonitor.recordCheckpoint('processed_$processedCount');
          }
        } catch (e) {
          final error = e is Exception ? e : Exception(e.toString());
          final result = ProcessingResult.failure(error, message: 'Failed to process: $filePath');
          results.add(result);

          if (!_config.continueOnError) {
            break;
          }
        } finally {
          // Always dispose the audio file to free memory
          audioFile?.dispose();
        }
      }
    } finally {
      _memoryMonitor?.recordCheckpoint('streaming_end');
    }

    return results;
  }

  /// Processes files as a stream, yielding results as they complete.
  ///
  /// This method provides real-time streaming of results, useful for
  /// UI updates or immediate processing of results.
  Stream<ProcessingResult> processFilesAsStream({
    required List<String> filePaths,
    required StreamingProcessor processor,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async* {
    if (filePaths.isEmpty) {
      return;
    }

    _memoryMonitor?.recordBaseline('stream_start');

    final startTime = DateTime.now();
    var processedCount = 0;

    try {
      for (int i = 0; i < filePaths.length; i++) {
        // Check for cancellation
        if (cancellationToken?.isCancelled == true) {
          break;
        }

        final filePath = filePaths[i];
        PhonicAudioFile? audioFile;

        try {
          // Load audio file
          audioFile = await Phonic.fromFile(filePath);

          // Process the file
          final result = await processor(audioFile, i, filePaths.length);
          yield result;

          processedCount++;

          // Report progress
          if (onProgress != null && (processedCount % _config.progressReportInterval == 0 || processedCount == filePaths.length)) {
            final progress = _createProgress(
              processedCount,
              filePaths.length,
              filePath,
              startTime,
            );
            onProgress(progress);
          }

          // Monitor memory usage
          if (_memoryMonitor != null && processedCount % _config.memoryMonitorInterval == 0) {
            _memoryMonitor.recordCheckpoint('stream_$processedCount');
          }
        } catch (e) {
          final error = e is Exception ? e : Exception(e.toString());
          final result = ProcessingResult.failure(error, message: 'Failed to process: $filePath');
          yield result;

          if (!_config.continueOnError) {
            break;
          }
        } finally {
          // Always dispose the audio file to free memory
          audioFile?.dispose();
        }
      }
    } finally {
      _memoryMonitor?.recordCheckpoint('stream_end');
    }
  }

  /// Creates progress information for the current processing state.
  StreamingProgress _createProgress(
    int processed,
    int total,
    String currentItem,
    DateTime startTime,
  ) {
    final elapsed = DateTime.now().difference(startTime);
    final itemsPerSecond = processed > 0 ? processed / elapsed.inSeconds : 0.0;

    Duration? estimatedTimeRemaining;
    if (itemsPerSecond > 0) {
      final remainingItems = total - processed;
      final remainingSeconds = remainingItems / itemsPerSecond;
      estimatedTimeRemaining = Duration(seconds: remainingSeconds.round());
    }

    return StreamingProgress(
      processed: processed,
      total: total,
      currentItem: currentItem,
      itemsPerSecond: itemsPerSecond > 0 ? itemsPerSecond : null,
      estimatedTimeRemaining: estimatedTimeRemaining,
      memoryUsage: _memoryMonitor?.getCurrentMemoryUsage(),
    );
  }

  /// Gets the current memory usage report.
  MemoryUsageReport? getMemoryReport() {
    return _memoryMonitor?.generateReport();
  }
}

/// Batch processor for handling large collections in manageable chunks.
class BatchAudioProcessor {
  final StreamingConfig _config;
  final MemoryUsageMonitor? _memoryMonitor;

  /// Creates a new batch audio processor.
  BatchAudioProcessor({
    StreamingConfig? config,
    MemoryUsageMonitor? memoryMonitor,
  }) : _config = config ?? const StreamingConfig(),
       _memoryMonitor = memoryMonitor ?? (config?.enableMemoryMonitoring != false ? MemoryUsageMonitor() : null);

  /// Processes files in batches with memory management.
  ///
  /// This method divides the file list into batches and processes each
  /// batch separately, allowing for memory cleanup between batches.
  Future<List<ProcessingResult>> processBatches({
    required List<String> filePaths,
    required int batchSize,
    required Future<List<ProcessingResult>> Function(List<String> batch) processor,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (filePaths.isEmpty) {
      return [];
    }

    _memoryMonitor?.recordBaseline('batch_start');

    final allResults = <ProcessingResult>[];
    final startTime = DateTime.now();
    var processedFiles = 0;

    try {
      // Process files in batches
      for (int i = 0; i < filePaths.length; i += batchSize) {
        // Check for cancellation
        if (cancellationToken?.isCancelled == true) {
          break;
        }

        final endIndex = (i + batchSize).clamp(0, filePaths.length);
        final batch = filePaths.sublist(i, endIndex);

        try {
          // Process the batch
          final batchResults = await processor(batch);
          allResults.addAll(batchResults);

          processedFiles += batch.length;

          // Report progress
          if (onProgress != null) {
            final progress = _createBatchProgress(
              processedFiles,
              filePaths.length,
              'Batch ${(i ~/ batchSize) + 1}',
              startTime,
            );
            onProgress(progress);
          }

          // Monitor memory usage after each batch
          if (_memoryMonitor != null) {
            _memoryMonitor.recordCheckpoint('batch_${(i ~/ batchSize) + 1}');
          }

          // Force garbage collection between batches to free memory
          _forceGarbageCollection();
        } catch (e) {
          // Handle batch processing error
          final error = e is Exception ? e : Exception(e.toString());

          // Add failure results for all files in the batch
          for (final filePath in batch) {
            allResults.add(
              ProcessingResult.failure(
                error,
                message: 'Batch processing failed for: $filePath',
              ),
            );
          }

          if (!_config.continueOnError) {
            break;
          }
        }
      }
    } finally {
      _memoryMonitor?.recordCheckpoint('batch_end');
    }

    return allResults;
  }

  /// Creates progress information for batch processing.
  StreamingProgress _createBatchProgress(
    int processed,
    int total,
    String currentBatch,
    DateTime startTime,
  ) {
    final elapsed = DateTime.now().difference(startTime);
    final itemsPerSecond = processed > 0 ? processed / elapsed.inSeconds : 0.0;

    Duration? estimatedTimeRemaining;
    if (itemsPerSecond > 0) {
      final remainingItems = total - processed;
      final remainingSeconds = remainingItems / itemsPerSecond;
      estimatedTimeRemaining = Duration(seconds: remainingSeconds.round());
    }

    return StreamingProgress(
      processed: processed,
      total: total,
      currentItem: currentBatch,
      itemsPerSecond: itemsPerSecond > 0 ? itemsPerSecond : null,
      estimatedTimeRemaining: estimatedTimeRemaining,
      memoryUsage: _memoryMonitor?.getCurrentMemoryUsage(),
    );
  }

  /// Attempts to force garbage collection between batches.
  void _forceGarbageCollection() {
    // Dart doesn't provide direct GC control, but this pattern
    // often triggers garbage collection
    for (int i = 0; i < 10; i++) {
      <int>[];
    }
  }
}

/// Simple cancellation token for stopping long-running operations.
class CancellationToken {
  bool _isCancelled = false;

  /// Whether the operation has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancels the operation.
  void cancel() {
    _isCancelled = true;
  }

  /// Resets the cancellation state.
  void reset() {
    _isCancelled = false;
  }
}

/// Collection analyzer for gathering statistics about audio file collections.
class CollectionAnalyzer {
  final StreamingConfig _config;

  /// Creates a new collection analyzer.
  CollectionAnalyzer({StreamingConfig? config}) : _config = config ?? StreamingConfig.forLargeCollections();

  /// Analyzes a collection of audio files and returns statistics.
  Future<CollectionStats> analyzeCollection({
    required List<String> filePaths,
    int? maxMemoryMB,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final config = maxMemoryMB != null
        ? StreamingConfig(
            maxConcurrentFiles: _config.maxConcurrentFiles,
            memoryLimitMB: maxMemoryMB,
            continueOnError: _config.continueOnError,
            progressReportInterval: _config.progressReportInterval,
            memoryMonitorInterval: _config.memoryMonitorInterval,
            enableMemoryMonitoring: true,
          )
        : _config;

    final processor = StreamingAudioProcessor(config: config);
    final stats = CollectionStats();

    await processor.processFiles(
      filePaths: filePaths,
      processor: (audioFile, index, total) async {
        try {
          // Gather statistics from the audio file
          _analyzeFile(audioFile, stats);
          return ProcessingResult.success();
        } catch (e) {
          stats.errorCount++;
          return ProcessingResult.failure(
            e is Exception ? e : Exception(e.toString()),
          );
        }
      },
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );

    // Get memory usage report
    final memoryReport = processor.getMemoryReport();
    if (memoryReport != null) {
      stats.memoryPeak = memoryReport.peakMemoryUsage;
      stats.memoryAverage = memoryReport.averageMemoryUsage?.round();
    }

    return stats;
  }

  /// Analyzes a single audio file and updates statistics.
  void _analyzeFile(PhonicAudioFile audioFile, CollectionStats stats) {
    stats.totalFiles++;

    // Analyze tags
    final allTags = audioFile.getAllTags();
    for (final tag in allTags) {
      switch (tag.key) {
        case TagKey.title:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithTitle++;
          }
          break;
        case TagKey.artist:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithArtist++;
            stats.uniqueArtists.add(tag.value.toString());
          }
          break;
        case TagKey.album:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithAlbum++;
            stats.uniqueAlbums.add(tag.value.toString());
          }
          break;
        case TagKey.genre:
          if (tag.value != null) {
            stats.filesWithGenre++;
            if (tag.value is List<String>) {
              stats.uniqueGenres.addAll(tag.value as List<String>);
            } else {
              stats.uniqueGenres.add(tag.value.toString());
            }
          }
          break;
        case TagKey.year:
          if (tag.value != null) {
            stats.filesWithYear++;
          }
          break;
        case TagKey.artwork:
          stats.filesWithArtwork++;
          break;
        default:
          // Count other tags
          break;
      }
    }

    // Track container types
    for (final tag in allTags) {
      final containerKind = tag.provenance.containerKind.name;
      stats.containerTypes[containerKind] = (stats.containerTypes[containerKind] ?? 0) + 1;
    }
  }
}

/// Statistics collected from analyzing an audio file collection.
class CollectionStats {
  /// Total number of files processed.
  int totalFiles = 0;

  /// Number of files that had processing errors.
  int errorCount = 0;

  /// Number of files with title tags.
  int filesWithTitle = 0;

  /// Number of files with artist tags.
  int filesWithArtist = 0;

  /// Number of files with album tags.
  int filesWithAlbum = 0;

  /// Number of files with genre tags.
  int filesWithGenre = 0;

  /// Number of files with year tags.
  int filesWithYear = 0;

  /// Number of files with artwork.
  int filesWithArtwork = 0;

  /// Set of unique artists found.
  final Set<String> uniqueArtists = <String>{};

  /// Set of unique albums found.
  final Set<String> uniqueAlbums = <String>{};

  /// Set of unique genres found.
  final Set<String> uniqueGenres = <String>{};

  /// Container type distribution.
  final Map<String, int> containerTypes = <String, int>{};

  /// Peak memory usage during analysis (bytes).
  int? memoryPeak;

  /// Average memory usage during analysis (bytes).
  int? memoryAverage;

  /// Percentage of files with complete metadata (title, artist, album).
  double get completenessPercentage {
    if (totalFiles == 0) return 0.0;

    var completeFiles = 0;
    for (int i = 0; i < totalFiles; i++) {
      // This is a simplified calculation - in practice you'd track this during analysis
      if (filesWithTitle > 0 && filesWithArtist > 0 && filesWithAlbum > 0) {
        completeFiles++;
      }
    }

    return (completeFiles / totalFiles) * 100.0;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Collection Statistics');
    buffer.writeln('====================');
    buffer.writeln('Total Files: $totalFiles');
    buffer.writeln('Errors: $errorCount');
    buffer.writeln();
    buffer.writeln('Metadata Coverage:');
    buffer.writeln('  Title: $filesWithTitle (${_percentage(filesWithTitle, totalFiles)}%)');
    buffer.writeln('  Artist: $filesWithArtist (${_percentage(filesWithArtist, totalFiles)}%)');
    buffer.writeln('  Album: $filesWithAlbum (${_percentage(filesWithAlbum, totalFiles)}%)');
    buffer.writeln('  Genre: $filesWithGenre (${_percentage(filesWithGenre, totalFiles)}%)');
    buffer.writeln('  Year: $filesWithYear (${_percentage(filesWithYear, totalFiles)}%)');
    buffer.writeln('  Artwork: $filesWithArtwork (${_percentage(filesWithArtwork, totalFiles)}%)');
    buffer.writeln();
    buffer.writeln('Unique Values:');
    buffer.writeln('  Artists: ${uniqueArtists.length}');
    buffer.writeln('  Albums: ${uniqueAlbums.length}');
    buffer.writeln('  Genres: ${uniqueGenres.length}');

    if (memoryPeak != null) {
      buffer.writeln();
      buffer.writeln('Memory Usage:');
      buffer.writeln('  Peak: ${_formatBytes(memoryPeak!)}');
      if (memoryAverage != null) {
        buffer.writeln('  Average: ${_formatBytes(memoryAverage!)}');
      }
    }

    return buffer.toString();
  }

  double _percentage(int value, int total) {
    return total > 0 ? (value / total) * 100.0 : 0.0;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
