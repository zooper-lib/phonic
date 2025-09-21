import 'package:phonic/src/performance/monitoring/memory_checkpoint.dart';

/// Represents progress information for streaming audio file operations.
///
/// This class provides detailed progress tracking for long-running operations
/// that process collections of audio files. It includes processing counts,
/// performance metrics, memory usage tracking, and time estimates.
///
/// Example usage:
/// ```dart
/// void onProgress(StreamingProgress progress) {
///   print('Progress: ${progress.percentage.toStringAsFixed(1)}%');
///   print('Processing: ${progress.currentItem}');
///   print('Rate: ${progress.itemsPerSecond} files/sec');
/// }
/// ```
class StreamingProgress {
  /// Number of audio files processed successfully so far.
  final int processed;

  /// Total number of audio files to be processed in the collection.
  final int total;

  /// Path or name of the audio file currently being processed.
  ///
  /// This field is optional and may be null if not provided by the processor.
  final String? currentItem;

  /// Processing rate measured in files per second.
  ///
  /// This metric helps estimate performance and is calculated based on
  /// the elapsed time since processing started.
  final double? itemsPerSecond;

  /// Estimated time remaining to complete all processing.
  ///
  /// This estimate is based on the current processing rate and may vary
  /// as the operation progresses.
  final Duration? estimatedTimeRemaining;

  /// Current memory usage information captured at this progress point.
  ///
  /// This information is only available if memory monitoring is enabled
  /// in the streaming configuration.
  final MemoryCheckpoint? memoryUsage;

  /// Creates a new progress tracking instance.
  ///
  /// The [processed] and [total] parameters are required to calculate
  /// completion percentage. Other fields are optional and provide
  /// additional context for progress monitoring.
  const StreamingProgress({
    required this.processed,
    required this.total,
    this.currentItem,
    this.itemsPerSecond,
    this.estimatedTimeRemaining,
    this.memoryUsage,
  });

  /// Progress completion as a percentage from 0.0 to 100.0.
  ///
  /// Returns 0.0 if [total] is zero to avoid division by zero.
  double get percentage => total > 0 ? (processed / total) * 100.0 : 0.0;

  /// Whether the processing operation is complete.
  ///
  /// Returns true when [processed] equals or exceeds [total].
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
