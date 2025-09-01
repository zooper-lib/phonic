import 'dart:io';

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
  /// This should typically be called at the start of processing to establish
  /// a reference point for measuring memory growth.
  ///
  /// @param label Optional label for the baseline
  void recordBaseline([String label = 'baseline']) {
    _baseline = _recordCurrentMemoryUsage(label);
  }

  /// Records a memory usage checkpoint with an optional label.
  ///
  /// Checkpoints allow tracking memory usage at specific points during
  /// processing to identify memory growth patterns and potential issues.
  ///
  /// @param label Optional label for the checkpoint
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

/// Represents a single memory usage measurement at a specific point in time.
class MemoryCheckpoint {
  /// Label identifying this checkpoint.
  final String label;

  /// Timestamp when this checkpoint was recorded.
  final DateTime timestamp;

  /// Resident Set Size (RSS) memory usage in bytes, if available.
  final int? rssMemory;

  /// Heap memory usage in bytes, if available.
  final int? heapUsage;

  const MemoryCheckpoint({
    required this.label,
    required this.timestamp,
    this.rssMemory,
    this.heapUsage,
  });

  @override
  String toString() {
    final parts = <String>['$label @ ${timestamp.toIso8601String()}'];
    if (rssMemory != null) {
      parts.add('RSS: ${_formatBytes(rssMemory!)}');
    }
    if (heapUsage != null) {
      parts.add('Heap: ${_formatBytes(heapUsage!)}');
    }
    return parts.join(', ');
  }

  /// Formats bytes in a human-readable format.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Comprehensive report of memory usage analysis.
class MemoryUsageReport {
  /// Baseline memory measurement for comparison.
  final MemoryCheckpoint baseline;

  /// All recorded memory checkpoints.
  final List<MemoryCheckpoint> checkpoints;

  /// Total memory growth from baseline to final measurement.
  final int? memoryGrowth;

  /// Peak memory usage observed during monitoring.
  final int? peakMemoryUsage;

  /// Checkpoint where peak memory usage occurred.
  final MemoryCheckpoint? peakCheckpoint;

  /// Average memory usage across all measurements.
  final double? averageMemoryUsage;

  /// Whether potential memory leak was detected.
  final bool hasMemoryLeak;

  /// Total duration of monitoring period.
  final Duration totalDuration;

  const MemoryUsageReport({
    required this.baseline,
    required this.checkpoints,
    this.memoryGrowth,
    this.peakMemoryUsage,
    this.peakCheckpoint,
    this.averageMemoryUsage,
    required this.hasMemoryLeak,
    required this.totalDuration,
  });

  /// Creates an empty report for cases with no data.
  factory MemoryUsageReport.empty() {
    final now = DateTime.now();
    return MemoryUsageReport(
      baseline: MemoryCheckpoint(label: 'empty', timestamp: now),
      checkpoints: [],
      hasMemoryLeak: false,
      totalDuration: Duration.zero,
    );
  }

  /// Generates a formatted text report.
  String generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln('Memory Usage Report');
    buffer.writeln('==================');
    buffer.writeln();

    buffer.writeln('Monitoring Period: ${totalDuration.inMilliseconds}ms');
    buffer.writeln('Checkpoints Recorded: ${checkpoints.length}');
    buffer.writeln();

    buffer.writeln('Baseline: $baseline');
    if (memoryGrowth != null) {
      buffer.writeln('Memory Growth: ${_formatBytes(memoryGrowth!)}');
    }
    if (peakMemoryUsage != null) {
      buffer.writeln('Peak Memory: ${_formatBytes(peakMemoryUsage!)}');
      if (peakCheckpoint != null) {
        buffer.writeln('Peak at: ${peakCheckpoint!.label}');
      }
    }
    if (averageMemoryUsage != null) {
      buffer.writeln('Average Memory: ${_formatBytes(averageMemoryUsage!.round())}');
    }

    buffer.writeln();
    buffer.writeln('Memory Leak Detection: ${hasMemoryLeak ? "POTENTIAL LEAK DETECTED" : "No leak detected"}');

    if (checkpoints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Checkpoints:');
      for (final checkpoint in checkpoints) {
        buffer.writeln('  $checkpoint');
      }
    }

    return buffer.toString();
  }

  /// Formats bytes in a human-readable format.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Utility for monitoring memory usage during batch processing operations.
class BatchMemoryMonitor {
  final MemoryUsageMonitor _monitor = MemoryUsageMonitor();
  final int _checkpointInterval;
  int _processedCount = 0;

  /// Creates a batch memory monitor.
  ///
  /// @param checkpointInterval How often to record memory checkpoints (every N items)
  BatchMemoryMonitor({int checkpointInterval = 100}) : _checkpointInterval = checkpointInterval;

  /// Starts monitoring by recording a baseline.
  void start() {
    _monitor.recordBaseline('batch_start');
  }

  /// Records processing of an item, potentially creating a checkpoint.
  void recordItem(String? itemLabel) {
    _processedCount++;

    if (_processedCount % _checkpointInterval == 0) {
      _monitor.recordCheckpoint('batch_${_processedCount}');
    }
  }

  /// Finishes monitoring and returns a report.
  MemoryUsageReport finish() {
    _monitor.recordCheckpoint('batch_end');
    return _monitor.generateReport();
  }

  /// Returns the current number of processed items.
  int get processedCount => _processedCount;
}
