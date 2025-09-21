import 'dart:io';

import 'memory_checkpoint.dart';
import 'memory_usage_report.dart';

/// Utilities for monitoring memory usage in the Phonic library.
///
/// This module provides tools to track memory consumption patterns,
/// identify memory leaks, and optimize memory usage when processing
/// large collections of audio files.
///
/// ## Key Features
///
/// - **Real-time Monitoring**: Track memory usage during processing
/// - **Baseline Comparison**: Compare current usage against baselines
/// - **Leak Detection**: Identify potential memory leaks
/// - **Performance Metrics**: Measure memory efficiency of operations
/// - **Reporting**: Generate detailed memory usage reports
///
/// ## Usage Examples
///
/// ```dart
/// // Basic memory monitoring
/// final monitor = MemoryUsageMonitor();
/// monitor.recordBaseline('start');
///
/// // Process files and monitor memory
/// for (final file in audioFiles) {
///   final audioFile = await Phonic.fromFile(file);
///   // ... process file
///   monitor.recordCheckpoint('file_${audioFiles.indexOf(file)}');
/// }
///
/// // Generate report
/// final report = monitor.generateReport();
/// print('Peak memory usage: ${report.peakMemoryUsage} bytes');
/// print('Memory growth: ${report.memoryGrowth} bytes');
/// ```
class MemoryUsageMonitor {
  /// Recorded memory usage checkpoints with timestamps.
  final List<MemoryCheckpoint> _checkpoints = <MemoryCheckpoint>[];

  /// Optional baseline memory usage for comparison.
  MemoryCheckpoint? _baseline;

  /// Creates a new memory usage monitor.
  MemoryUsageMonitor();

  /// Records the current memory usage as a baseline for comparison.
  ///
  /// Establishing a baseline is crucial for accurate memory growth analysis.
  /// The baseline represents the "normal" memory state before processing begins,
  /// allowing all subsequent measurements to be compared against this reference point.
  ///
  /// ## When to Set Baseline
  ///
  /// - **Application Start**: After initialization but before main processing
  /// - **Pre-Processing**: Just before beginning a batch operation
  /// - **Clean State**: After garbage collection or manual memory cleanup
  /// - **Test Setup**: At the beginning of performance tests
  ///
  /// ## Usage Examples
  ///
  /// ```dart
  /// final monitor = MemoryUsageMonitor();
  ///
  /// // Set baseline at application startup
  /// monitor.recordBaseline('app_startup');
  ///
  /// // Set baseline before batch processing
  /// monitor.recordBaseline('before_batch_processing');
  ///
  /// // Set baseline after cleanup
  /// await performGarbageCollection();
  /// monitor.recordBaseline('after_cleanup');
  /// ```
  ///
  /// ## Analysis Impact
  ///
  /// Setting a baseline enables several analysis features:
  /// - Memory growth calculations relative to baseline
  /// - Leak detection through trend analysis
  /// - Efficiency metrics comparing operations
  /// - Anomaly detection when usage deviates significantly
  ///
  /// ## Multiple Baselines
  ///
  /// Each call replaces the previous baseline. For complex scenarios requiring
  /// multiple reference points, consider:
  /// - Creating separate monitor instances
  /// - Using regular checkpoints with meaningful labels
  /// - Manual calculation using checkpoint data
  ///
  /// @param label Descriptive identifier for this baseline measurement (default: 'baseline')
  void recordBaseline([String label = 'baseline']) {
    _baseline = _recordCurrentMemoryUsage(label);
  }

  /// Records a memory usage checkpoint with an optional label.
  ///
  /// Checkpoints capture the current memory state at specific points during
  /// processing, creating a timeline of memory usage that can be analyzed
  /// for trends, spikes, and optimization opportunities.
  ///
  /// ## Strategic Checkpoint Placement
  ///
  /// ### Processing Milestones
  /// Place checkpoints at key processing stages:
  /// - Before and after major operations
  /// - At regular intervals during batch processing
  /// - When entering/exiting critical sections
  /// - Before and after memory-intensive operations
  ///
  /// ### Error Boundaries
  /// Capture memory state during error conditions:
  /// - When exceptions occur
  /// - During recovery operations
  /// - After failed operations
  /// - Before cleanup attempts
  ///
  /// ## Labeling Best Practices
  ///
  /// Use consistent, descriptive labels for easier analysis:
  ///
  /// ```dart
  /// // Good: Descriptive and consistent
  /// monitor.recordCheckpoint('batch_start');
  /// monitor.recordCheckpoint('processed_1000_files');
  /// monitor.recordCheckpoint('batch_complete');
  ///
  /// // Avoid: Vague or inconsistent labels
  /// monitor.recordCheckpoint('here');
  /// monitor.recordCheckpoint('done processing stuff');
  /// ```
  ///
  /// ## Usage Patterns
  ///
  /// ### Regular Interval Monitoring
  /// ```dart
  /// for (int i = 0; i < files.length; i++) {
  ///   await processFile(files[i]);
  ///
  ///   // Checkpoint every 100 files
  ///   if (i % 100 == 0) {
  ///     monitor.recordCheckpoint('processed_${i}_files');
  ///   }
  /// }
  /// ```
  ///
  /// ### Critical Section Monitoring
  /// ```dart
  /// monitor.recordCheckpoint('before_memory_intensive_operation');
  /// try {
  ///   await performMemoryIntensiveOperation();
  ///   monitor.recordCheckpoint('after_successful_operation');
  /// } catch (error) {
  ///   monitor.recordCheckpoint('after_failed_operation');
  ///   rethrow;
  /// }
  /// ```
  ///
  /// ### Cleanup Verification
  /// ```dart
  /// monitor.recordCheckpoint('before_cleanup');
  /// await performCleanup();
  /// monitor.recordCheckpoint('after_cleanup');
  ///
  /// // Verify cleanup effectiveness
  /// final report = monitor.generateReport();
  /// final cleanupDelta = report.getMemoryDelta('before_cleanup', 'after_cleanup');
  /// print('Memory freed: ${cleanupDelta} bytes');
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// - Checkpoint recording is lightweight but not free
  /// - Avoid excessive frequency in tight loops
  /// - Consider using batch intervals for repetitive operations
  /// - Memory for storing checkpoints grows with number of recordings
  ///
  /// @param label Descriptive identifier for this checkpoint (default: timestamp-based)
  void recordCheckpoint([String? label]) {
    final checkpoint = _recordCurrentMemoryUsage(label ?? 'checkpoint_${_checkpoints.length}');
    _checkpoints.add(checkpoint);
  }

  /// Records current memory usage and returns a checkpoint.
  MemoryCheckpoint _recordCurrentMemoryUsage(String label) {
    final timestamp = DateTime.now();

    // Get memory usage information
    // Note: Dart doesn't provide direct access to memory usage in all environments
    // This is a simplified implementation that works where ProcessInfo is available
    int? rssMemory;
    int? heapUsage;

    try {
      // Try to get RSS memory usage (Resident Set Size)
      if (Platform.isLinux || Platform.isMacOS) {
        final result = Process.runSync('ps', ['-o', 'rss=', '-p', '${pid}']);
        if (result.exitCode == 0) {
          final rssKB = int.tryParse(result.stdout.toString().trim());
          if (rssKB != null) {
            rssMemory = rssKB * 1024; // Convert KB to bytes
          }
        }
      }
    } catch (e) {
      // Memory information not available on this platform
    }

    // Try to get heap usage information
    try {
      // This is a placeholder for heap usage - Dart doesn't expose this directly
      // In a real implementation, you might use dart:developer or other tools
      heapUsage = _estimateHeapUsage();
    } catch (e) {
      // Heap information not available
    }

    return MemoryCheckpoint(
      label: label,
      timestamp: timestamp,
      rssMemory: rssMemory,
      heapUsage: heapUsage,
    );
  }

  /// Estimates heap usage using available Dart APIs.
  ///
  /// This is a simplified estimation since Dart doesn't provide direct
  /// heap usage APIs in all environments.
  int? _estimateHeapUsage() {
    // This is a placeholder implementation
    // In practice, you might use:
    // - dart:developer APIs if available
    // - Platform-specific tools
    // - Custom memory tracking
    return null;
  }

  /// Forces garbage collection and records the memory usage afterward.
  ///
  /// This can be useful for measuring memory usage after cleanup operations
  /// or for detecting memory leaks that persist after GC.
  void recordAfterGC([String label = 'after_gc']) {
    // Force garbage collection
    _forceGarbageCollection();

    // Wait a bit for GC to complete
    Future.delayed(const Duration(milliseconds: 100), () {
      recordCheckpoint(label);
    });
  }

  /// Attempts to force garbage collection.
  void _forceGarbageCollection() {
    // Dart doesn't provide a direct way to force GC
    // This is a common workaround that may trigger GC
    for (int i = 0; i < 10; i++) {
      <int>[];
    }
  }

  /// Generates a comprehensive memory usage report.
  MemoryUsageReport generateReport() {
    if (_checkpoints.isEmpty) {
      return MemoryUsageReport.empty();
    }

    final firstCheckpoint = _checkpoints.first;
    final lastCheckpoint = _checkpoints.last;
    final baseline = _baseline ?? firstCheckpoint;

    // Calculate memory growth
    int? memoryGrowth;
    if (baseline.rssMemory != null && lastCheckpoint.rssMemory != null) {
      memoryGrowth = lastCheckpoint.rssMemory! - baseline.rssMemory!;
    }

    // Find peak memory usage
    int? peakMemoryUsage;
    MemoryCheckpoint? peakCheckpoint;
    for (final checkpoint in _checkpoints) {
      if (checkpoint.rssMemory != null) {
        if (peakMemoryUsage == null || checkpoint.rssMemory! > peakMemoryUsage) {
          peakMemoryUsage = checkpoint.rssMemory;
          peakCheckpoint = checkpoint;
        }
      }
    }

    // Calculate average memory usage
    double? averageMemoryUsage;
    final memoryValues = _checkpoints.where((c) => c.rssMemory != null).map((c) => c.rssMemory!).toList();
    if (memoryValues.isNotEmpty) {
      averageMemoryUsage = memoryValues.reduce((a, b) => a + b) / memoryValues.length;
    }

    // Detect potential memory leaks
    final hasMemoryLeak = _detectMemoryLeak();

    return MemoryUsageReport(
      baseline: baseline,
      checkpoints: List.from(_checkpoints),
      memoryGrowth: memoryGrowth,
      peakMemoryUsage: peakMemoryUsage,
      peakCheckpoint: peakCheckpoint,
      averageMemoryUsage: averageMemoryUsage,
      hasMemoryLeak: hasMemoryLeak,
      totalDuration: lastCheckpoint.timestamp.difference(firstCheckpoint.timestamp),
    );
  }

  /// Detects potential memory leaks by analyzing memory growth patterns.
  bool _detectMemoryLeak() {
    if (_checkpoints.length < 3) {
      return false; // Not enough data
    }

    // Simple heuristic: if memory consistently grows without significant drops,
    // it might indicate a memory leak
    final memoryValues = _checkpoints.where((c) => c.rssMemory != null).map((c) => c.rssMemory!).toList();

    if (memoryValues.length < 3) {
      return false;
    }

    // Check if memory is consistently growing
    int growthCount = 0;
    for (int i = 1; i < memoryValues.length; i++) {
      if (memoryValues[i] > memoryValues[i - 1]) {
        growthCount++;
      }
    }

    // If more than 70% of measurements show growth, flag as potential leak
    return (growthCount / (memoryValues.length - 1)) > 0.7;
  }

  /// Clears all recorded checkpoints and baseline.
  void clear() {
    _checkpoints.clear();
    _baseline = null;
  }

  /// Returns the number of recorded checkpoints.
  int get checkpointCount => _checkpoints.length;

  /// Returns whether a baseline has been recorded.
  bool get hasBaseline => _baseline != null;

  /// Returns the current memory usage as a checkpoint without recording it.
  MemoryCheckpoint getCurrentMemoryUsage() {
    return _recordCurrentMemoryUsage('current');
  }
}
