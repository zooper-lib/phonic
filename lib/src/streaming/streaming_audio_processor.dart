import 'dart:async';

import 'package:phonic/src/core/phonic.dart';
import 'package:phonic/src/core/phonic_audio_file.dart';
import 'package:phonic/src/performance/monitoring/memory_usage_monitor.dart';
import 'package:phonic/src/performance/monitoring/memory_usage_report.dart';
import 'package:phonic/src/streaming/cancellation_token.dart';
import 'package:phonic/src/streaming/processing_result.dart';
import 'package:phonic/src/streaming/streaming_config.dart';
import 'package:phonic/src/streaming/streaming_progress.dart';

/// Processor function type for streaming audio file operations.
///
/// This typedef defines the signature for functions that process individual
/// audio files in a streaming context. The function receives:
/// - [audioFile]: The loaded audio file instance
/// - [index]: Zero-based index of this file in the collection
/// - [total]: Total number of files being processed
///
/// Returns a [Future<ProcessingResult>] indicating success or failure.
typedef StreamingProcessor<T> =
    Future<ProcessingResult> Function(
      PhonicAudioFile audioFile,
      int index,
      int total,
    );

/// Callback function type for receiving progress updates during streaming operations.
///
/// This typedef defines the signature for progress callback functions that
/// receive [StreamingProgress] instances with current processing status.
typedef ProgressCallback = void Function(StreamingProgress progress);

/// High-performance streaming processor for large audio file collections.
///
/// This class provides memory-efficient processing of large collections of audio files
/// by implementing streaming techniques that keep memory usage bounded regardless of
/// collection size. It loads and processes files sequentially, with configurable
/// memory limits, progress reporting, and error handling.
///
/// Key features:
/// - **Memory Management**: Configurable memory limits and monitoring
/// - **Progress Tracking**: Real-time progress reporting with ETA calculations
/// - **Error Handling**: Graceful error handling with continue-on-error options
/// - **Cancellation Support**: Ability to cancel long-running operations
/// - **Performance Metrics**: Processing rate tracking and memory usage statistics
///
/// Example usage:
/// ```dart
/// final processor = StreamingAudioProcessor(
///   config: StreamingConfig.forLargeCollections(),
/// );
///
/// final results = await processor.processFiles(
///   filePaths: audioFiles,
///   processor: (audioFile, index, total) async {
///     // Process each audio file
///     final metadata = audioFile.metadata;
///     // ... do something with the file
///     return ProcessingResult.success();
///   },
///   onProgress: (progress) {
///     print('Progress: ${progress.percentage.toStringAsFixed(1)}%');
///   },
/// );
/// ```
class StreamingAudioProcessor {
  final StreamingConfig _config;
  final MemoryUsageMonitor? _memoryMonitor;

  /// Creates a new streaming audio processor with optional configuration.
  ///
  /// Parameters:
  /// - [config]: Configuration settings for memory management and processing behavior.
  ///   If not provided, uses default [StreamingConfig] settings.
  /// - [memoryMonitor]: Optional memory monitoring instance. If not provided and
  ///   memory monitoring is enabled in config, creates a default [MemoryUsageMonitor].
  StreamingAudioProcessor({
    StreamingConfig? config,
    MemoryUsageMonitor? memoryMonitor,
  }) : _config = config ?? const StreamingConfig(),
       _memoryMonitor = memoryMonitor ?? (config?.enableMemoryMonitoring != false ? MemoryUsageMonitor() : null);

  /// Processes a collection of audio files using memory-efficient streaming.
  ///
  /// This method processes files sequentially to maintain bounded memory usage,
  /// making it suitable for very large collections. Each file is loaded,
  /// processed, and then released from memory before moving to the next.
  ///
  /// Parameters:
  /// - [filePaths]: List of file paths to process sequentially
  /// - [processor]: Function to process each audio file. Receives the loaded
  ///   [PhonicAudioFile], current index, and total count.
  /// - [onProgress]: Optional callback for progress updates. Called according
  ///   to [StreamingConfig.progressReportInterval] settings.
  /// - [cancellationToken]: Optional token for cancelling the operation.
  ///   Processing will stop gracefully when cancelled.
  ///
  /// Returns:
  /// A list of [ProcessingResult] instances, one for each input file.
  /// Results are returned in the same order as the input file paths.
  ///
  /// Throws:
  /// May throw exceptions if fundamental issues occur (e.g., memory monitor
  /// initialization fails). Individual file processing errors are captured
  /// in the returned [ProcessingResult] instances.
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
          audioFile = await Phonic.fromFileAsync(filePath);

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
          audioFile = await Phonic.fromFileAsync(filePath);

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
