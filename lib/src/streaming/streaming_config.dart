/// Configuration settings for streaming audio file operations.
///
/// This class provides comprehensive configuration options for memory management,
/// error handling, progress reporting, and performance tuning when processing
/// large collections of audio files.
///
/// The class includes factory constructors for common use cases:
/// - [StreamingConfig.forLargeCollections()] - optimized for memory efficiency
/// - [StreamingConfig.forFastProcessing()] - optimized for speed
///
/// Example usage:
/// ```dart
/// // Default configuration
/// final config = StreamingConfig();
///
/// // Custom configuration for memory-constrained environments
/// final config = StreamingConfig(
///   maxConcurrentFiles: 5,
///   memoryLimitMB: 100,
///   continueOnError: false,
/// );
/// ```
class StreamingConfig {
  /// Maximum number of audio files to keep loaded in memory simultaneously.
  ///
  /// This setting helps control memory usage by limiting concurrent file handles.
  /// Lower values reduce memory usage but may impact processing speed.
  final int maxConcurrentFiles;

  /// Maximum memory usage limit in megabytes for the streaming operation.
  ///
  /// When memory monitoring is enabled, the system will attempt to stay
  /// under this limit by managing file loading and cleanup.
  final int memoryLimitMB;

  /// Whether to continue processing remaining files when individual files fail.
  ///
  /// When true, processing errors on individual files won't stop the entire
  /// operation. When false, the first error will halt all processing.
  final bool continueOnError;

  /// Interval for reporting progress updates (number of processed files).
  ///
  /// Progress callbacks will be triggered after processing this many files.
  /// Smaller values provide more frequent updates but may impact performance.
  final int progressReportInterval;

  /// Interval for memory monitoring checks (number of processed files).
  ///
  /// Memory usage will be checked and recorded after processing this many files.
  /// Only relevant when memory monitoring is enabled.
  final int memoryMonitorInterval;

  /// Whether to enable detailed memory usage monitoring during processing.
  ///
  /// When enabled, the system tracks memory usage patterns and can provide
  /// detailed memory statistics. Adds minimal overhead but provides valuable
  /// diagnostic information.
  final bool enableMemoryMonitoring;

  /// Creates a new streaming configuration with the specified settings.
  const StreamingConfig({
    this.maxConcurrentFiles = 10,
    this.memoryLimitMB = 500,
    this.continueOnError = true,
    this.progressReportInterval = 10,
    this.memoryMonitorInterval = 50,
    this.enableMemoryMonitoring = true,
  });

  /// Creates a configuration optimized for processing large collections efficiently.
  ///
  /// This preset uses conservative memory settings and frequent monitoring
  /// to handle very large audio file collections without running out of memory.
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

  /// Creates a configuration optimized for fast processing speed.
  ///
  /// This preset uses higher memory limits and less frequent monitoring
  /// to maximize processing throughput for systems with ample memory.
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
