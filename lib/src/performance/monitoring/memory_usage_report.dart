import 'memory_checkpoint.dart';

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
