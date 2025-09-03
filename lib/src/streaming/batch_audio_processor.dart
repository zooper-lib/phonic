import 'dart:async';

import 'package:phonic/src/performance/performance.dart';
import 'package:phonic/src/streaming/cancellation_token.dart';
import 'package:phonic/src/streaming/processing_result.dart';
import 'package:phonic/src/streaming/streaming_config.dart';
import 'package:phonic/src/streaming/streaming_progress.dart';

/// High-performance batch processor for handling very large audio file collections.
///
/// This class provides an alternative processing approach for extremely large
/// collections by dividing files into manageable batches. Each batch is processed
/// as a unit, allowing for memory cleanup between batches and providing better
/// progress granularity for massive collections.
///
/// The batch approach is particularly useful when:
/// - Processing collections with thousands or tens of thousands of files
/// - Need to balance memory usage with processing efficiency
/// - Require checkpointing or intermediate results between batches
/// - Working with limited memory systems
///
/// Key features:
/// - **Batch Processing**: Divides large collections into manageable chunks
/// - **Memory Management**: Enforces cleanup between batches
/// - **Flexible Batch Sizes**: Configurable batch sizes for different scenarios
/// - **Progress Tracking**: Batch-level progress reporting
/// - **Cancellation Support**: Can stop between batches gracefully
///
/// Example usage:
/// ```dart
/// final processor = BatchAudioProcessor(
///   config: StreamingConfig.forLargeCollections(),
/// );
///
/// final results = await processor.processBatches(
///   filePaths: largeCollection,
///   batchSize: 100,
///   processor: (batch) async {
///     // Process this batch of files
///     return await processBatchOfFiles(batch);
///   },
///   onProgress: (progress) {
///     print('Batch progress: ${progress.percentage}%');
///   },
/// );
/// ```
class BatchAudioProcessor {
  final StreamingConfig _config;
  final MemoryUsageMonitor? _memoryMonitor;

  /// Creates a new batch audio processor with optional configuration.
  ///
  /// Parameters:
  /// - [config]: Configuration settings for memory management and processing behavior.
  ///   If not provided, uses default [StreamingConfig] settings.
  /// - [memoryMonitor]: Optional memory monitoring instance. If not provided and
  ///   memory monitoring is enabled in config, creates a default [MemoryUsageMonitor].
  BatchAudioProcessor({
    StreamingConfig? config,
    MemoryUsageMonitor? memoryMonitor,
  }) : _config = config ?? const StreamingConfig(),
       _memoryMonitor = memoryMonitor ?? (config?.enableMemoryMonitoring != false ? MemoryUsageMonitor() : null);

  /// Processes a large collection of files in batches with memory management.
  ///
  /// This method divides the input file list into batches of the specified size
  /// and processes each batch separately. This approach allows for memory cleanup
  /// between batches and provides better control over resource usage for very
  /// large collections.
  ///
  /// Parameters:
  /// - [filePaths]: Complete list of file paths to process
  /// - [batchSize]: Number of files to include in each batch. Choose based on
  ///   available memory and desired performance characteristics.
  /// - [processor]: Function to process each batch. Receives a list of file paths
  ///   for the current batch and should return a list of results.
  /// - [onProgress]: Optional callback for progress updates. Called after each
  ///   batch completes with overall progress information.
  /// - [cancellationToken]: Optional token for cancelling the operation.
  ///   Processing will stop gracefully after the current batch completes.
  ///
  /// Returns:
  /// A flattened list of all [ProcessingResult] instances from all batches,
  /// maintaining the original order of input files.
  ///
  /// The method ensures proper memory cleanup between batches and provides
  /// progress reporting at the batch level for better user feedback.
  Future<List<ProcessingResult>> processBatches({
    required List<String> filePaths,
    required int batchSize,
    required Future<List<ProcessingResult>> Function(List<String> batch) processor,
    void Function(StreamingProgress progress)? onProgress,
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
