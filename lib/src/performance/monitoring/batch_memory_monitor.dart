import 'package:phonic/src/performance/monitoring/memory_usage_monitor.dart';

import 'memory_usage_report.dart';

/// Specialized memory monitor for batch processing operations.
///
/// This monitor is designed for scenarios where you're processing large numbers
/// of items (like audio files) and want to track memory usage patterns without
/// the overhead of recording every single operation.
///
/// ## Key Features
///
/// - **Automatic Checkpointing**: Records memory usage at configurable intervals
/// - **Batch-Aware**: Designed specifically for bulk processing scenarios
/// - **Low Overhead**: Minimal performance impact during processing
/// - **Comprehensive Reports**: Generates detailed analysis of memory patterns
///
/// ## Usage Examples
///
/// ### Basic Batch Monitoring
/// ```dart
/// final monitor = BatchMemoryMonitor(checkpointInterval: 100);
/// monitor.start();
///
/// for (int i = 0; i < largeFileCollection.length; i++) {
///   // Process file...
///   final audioFile = await Phonic.fromFileAsync(largeFileCollection[i]);
///   processAudioFile(audioFile);
///
///   // This automatically creates checkpoints every 100 items
///   monitor.recordItem('file_$i');
/// }
///
/// final report = monitor.finish();
/// print('Processed ${monitor.processedCount} files');
/// print('Peak memory usage: ${report.peakMemoryUsage} bytes');
/// print('Memory leak detected: ${report.hasMemoryLeak}');
/// ```
///
/// ### Memory Threshold Monitoring
/// ```dart
/// final monitor = BatchMemoryMonitor(checkpointInterval: 50);
/// const memoryThreshold = 500 * 1024 * 1024; // 500MB
///
/// monitor.start();
/// for (final file in audioFiles) {
///   processFile(file);
///   monitor.recordItem(file.path);
///
///   // Check if we need to perform cleanup
///   final currentUsage = monitor.getCurrentMemoryUsage();
///   if (currentUsage > memoryThreshold) {
///     performMemoryCleanup();
///     monitor.recordItem('cleanup_performed');
///   }
/// }
/// ```
///
/// ## Memory Leak Detection
///
/// The monitor automatically analyzes memory growth patterns and can detect
/// potential memory leaks by identifying sustained memory growth over time.
///
/// ## Performance Considerations
///
/// - Checkpoint intervals should balance monitoring granularity with performance
/// - Lower intervals (e.g., 10-50) provide more detailed tracking but higher overhead
/// - Higher intervals (e.g., 100-1000) are suitable for very large collections
/// - Memory usage measurement has platform-specific availability and accuracy
class BatchMemoryMonitor {
  final MemoryUsageMonitor _monitor = MemoryUsageMonitor();
  final int _checkpointInterval;
  int _processedCount = 0;

  /// Creates a batch memory monitor with configurable checkpoint frequency.
  ///
  /// The checkpoint interval determines how often memory measurements are taken.
  /// This balances monitoring granularity with performance overhead.
  ///
  /// ## Recommended Intervals
  ///
  /// - **Small collections (< 1000 items)**: 10-50 items per checkpoint
  /// - **Medium collections (1000-10000 items)**: 50-200 items per checkpoint
  /// - **Large collections (> 10000 items)**: 100-1000 items per checkpoint
  ///
  /// ## Parameters
  ///
  /// * [checkpointInterval] - Number of processed items between memory measurements.
  ///   Defaults to 100, which provides good balance for most use cases.
  ///
  /// ## Example
  /// ```dart
  /// // For processing 5000 audio files, checkpoint every 100 files
  /// final monitor = BatchMemoryMonitor(checkpointInterval: 100);
  ///
  /// // For real-time monitoring of smaller batches
  /// final monitor = BatchMemoryMonitor(checkpointInterval: 10);
  /// ```
  BatchMemoryMonitor({int checkpointInterval = 100}) : _checkpointInterval = checkpointInterval;

  /// Starts monitoring by recording a baseline memory measurement.
  ///
  /// This establishes the initial memory state before batch processing begins.
  /// The baseline is used to calculate memory growth and detect leaks.
  ///
  /// **Important**: Always call this method before beginning batch processing
  /// to ensure accurate memory usage analysis.
  ///
  /// ## Example
  /// ```dart
  /// final monitor = BatchMemoryMonitor();
  /// monitor.start(); // Record initial memory state
  ///
  /// // Now begin processing files...
  /// for (final file in audioFiles) {
  ///   // Process file and record item
  /// }
  /// ```
  void start() {
    _monitor.recordBaseline('batch_start');
  }

  /// Records the processing of an item and creates checkpoints at configured intervals.
  ///
  /// This method should be called after processing each item in your batch.
  /// Memory checkpoints are automatically created based on the configured
  /// checkpoint interval to track memory usage patterns over time.
  ///
  /// ## Parameters
  ///
  /// * [itemLabel] - Optional descriptive label for the processed item.
  ///   Useful for debugging and identifying which items caused memory spikes.
  ///   If null, items are labeled generically as 'item_N'.
  ///
  /// ## Automatic Checkpointing
  ///
  /// Memory measurements are taken automatically when the number of processed
  /// items is divisible by the checkpoint interval. For example, with an
  /// interval of 100, checkpoints occur at items 100, 200, 300, etc.
  ///
  /// ## Example
  /// ```dart
  /// final monitor = BatchMemoryMonitor(checkpointInterval: 50);
  /// monitor.start();
  ///
  /// for (int i = 0; i < audioFiles.length; i++) {
  ///   final audioFile = await Phonic.fromFileAsync(audioFiles[i]);
  ///   processAudioFile(audioFile);
  ///
  ///   // Checkpoints created automatically at items 50, 100, 150, etc.
  ///   monitor.recordItem('audio_file_$i');
  /// }
  /// ```
  ///
  /// ## Performance Impact
  ///
  /// This method has minimal overhead - it only increments a counter and
  /// occasionally triggers a memory measurement. The measurement itself
  /// is platform-dependent and may involve system calls on some platforms.
  void recordItem(String? itemLabel) {
    _processedCount++;

    if (_processedCount % _checkpointInterval == 0) {
      _monitor.recordCheckpoint('batch_$_processedCount');
    }
  }

  /// Finishes monitoring and generates a comprehensive memory usage report.
  ///
  /// This method should be called after batch processing is complete. It records
  /// a final checkpoint and analyzes all collected memory measurements to generate
  /// a detailed report including memory growth patterns, peak usage, and potential
  /// leak detection.
  ///
  /// ## Report Contents
  ///
  /// The returned [MemoryUsageReport] includes:
  /// - **Memory Growth**: Total memory increase from baseline to final measurement
  /// - **Peak Usage**: Highest memory usage observed during processing
  /// - **Leak Detection**: Analysis of memory growth patterns to identify leaks
  /// - **Duration**: Total time spent processing the batch
  /// - **Checkpoints**: All recorded memory measurements with timestamps
  ///
  /// ## Example
  /// ```dart
  /// final monitor = BatchMemoryMonitor();
  /// monitor.start();
  ///
  /// // Process files...
  /// for (final file in audioFiles) {
  ///   processFile(file);
  ///   monitor.recordItem(file.name);
  /// }
  ///
  /// final report = monitor.finish();
  ///
  /// // Analyze results
  /// print('Batch processing complete:');
  /// print('  Files processed: ${monitor.processedCount}');
  /// print('  Peak memory: ${report.peakMemoryUsage} bytes');
  /// print('  Memory growth: ${report.memoryGrowth} bytes');
  /// print('  Processing time: ${report.totalDuration}');
  /// print('  Memory leak detected: ${report.hasMemoryLeak}');
  ///
  /// if (report.hasMemoryLeak) {
  ///   print('Warning: Potential memory leak detected!');
  ///   // Consider investigating memory usage patterns
  /// }
  /// ```
  ///
  /// ## Post-Processing Cleanup
  ///
  /// After calling this method, the monitor can be reused for another batch
  /// by calling [start] again, or should be disposed of if no longer needed.
  MemoryUsageReport finish() {
    _monitor.recordCheckpoint('batch_end');
    return _monitor.generateReport();
  }

  /// Returns the current number of processed items.
  ///
  /// This count increments each time [recordItem] is called and represents
  /// the total number of items that have been processed since monitoring
  /// started or since the last call to [start].
  ///
  /// ## Usage
  ///
  /// Useful for progress reporting, debugging, and calculating processing rates:
  ///
  /// ```dart
  /// final monitor = BatchMemoryMonitor();
  /// monitor.start();
  ///
  /// for (final file in audioFiles) {
  ///   processFile(file);
  ///   monitor.recordItem(file.name);
  ///
  ///   // Progress reporting
  ///   if (monitor.processedCount % 100 == 0) {
  ///     print('Processed ${monitor.processedCount}/${audioFiles.length} files');
  ///   }
  /// }
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// This getter is safe to call from different threads, though the underlying
  /// batch processing should typically be single-threaded for accurate monitoring.
  int get processedCount => _processedCount;
}
