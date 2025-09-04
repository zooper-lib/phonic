/// Represents a single memory usage measurement at a specific point in time.
///
/// A memory checkpoint captures the system's memory state at a particular moment
/// during processing, providing a snapshot that can be used for analysis,
/// comparison, and trend detection in memory usage patterns.
///
/// ## Memory Types Tracked
///
/// ### Resident Set Size (RSS)
/// The RSS memory represents the physical memory currently occupied by the process.
/// This includes:
/// - Code segments loaded in memory
/// - Data structures and variables
/// - Heap allocations that haven't been swapped out
/// - Shared libraries loaded by the process
///
/// ### Heap Usage
/// Heap usage represents memory allocated from the heap for dynamic allocations.
/// This is typically what developers think of as "program memory" and includes:
/// - Objects created with `new` or similar allocators
/// - Dynamic data structures (lists, maps, etc.)
/// - String allocations and other runtime data
///
/// ## Platform Availability
///
/// Memory measurement availability varies by platform:
/// - **Linux/macOS**: RSS memory generally available via system calls
/// - **Windows**: May require additional platform-specific APIs
/// - **Web/Embedded**: Limited or no memory information available
/// - **Heap Usage**: Not directly exposed by Dart runtime on most platforms
///
/// ## Usage in Analysis
///
/// Checkpoints are typically used to:
/// - Track memory growth over time during batch processing
/// - Identify memory usage patterns and spikes
/// - Detect potential memory leaks through trend analysis
/// - Compare memory usage between different processing strategies
/// - Generate reports and alerts based on memory thresholds
///
/// ## Example
///
/// ```dart
/// // Creating a checkpoint manually (typically done by monitors)
/// final checkpoint = MemoryCheckpoint(
///   label: 'after_processing_1000_files',
///   timestamp: DateTime.now(),
///   rssMemory: 157286400, // ~150MB
///   heapUsage: 89478485,  // ~85MB
/// );
///
/// print(checkpoint); // Human-readable output with formatted sizes
/// ```
class MemoryCheckpoint {
  /// A descriptive label identifying this measurement point.
  ///
  /// Labels provide context for when and why this checkpoint was created.
  /// They should be meaningful and consistent for effective analysis.
  ///
  /// ## Common Label Patterns
  ///
  /// - **Process stages**: "startup", "initialization_complete", "shutdown"
  /// - **Batch milestones**: "batch_start", "processed_1000", "batch_end"
  /// - **Memory events**: "before_gc", "after_cleanup", "peak_usage"
  /// - **Error conditions**: "out_of_memory_detected", "cleanup_failed"
  ///
  /// ## Example Labels
  ///
  /// ```dart
  /// "batch_start"                    // Beginning of processing
  /// "after_processing_1000_files"   // Milestone during processing
  /// "memory_cleanup_complete"       // After manual memory management
  /// "error_recovery_attempt"        // During error handling
  /// ```
  final String label;

  /// The timestamp when this memory measurement was taken.
  ///
  /// Used for temporal analysis of memory usage patterns and calculating
  /// memory growth rates over time. Should represent the actual measurement
  /// time rather than when the checkpoint object was instantiated.
  ///
  /// ## Precision Considerations
  ///
  /// - Use high-precision timestamps when available for accurate analysis
  /// - Consistent timezone handling is important for distributed systems
  /// - Consider using UTC timestamps to avoid daylight saving complications
  ///
  /// ## Analysis Applications
  ///
  /// ```dart
  /// // Calculate memory growth rate between checkpoints
  /// final timeDiff = checkpoint2.timestamp.difference(checkpoint1.timestamp);
  /// final memoryDiff = (checkpoint2.rssMemory ?? 0) - (checkpoint1.rssMemory ?? 0);
  /// final growthRate = memoryDiff / timeDiff.inMilliseconds; // bytes per ms
  /// ```
  final DateTime timestamp;

  /// Resident Set Size (RSS) memory usage in bytes, if available on this platform.
  ///
  /// RSS represents the physical memory currently occupied by the process.
  /// This includes code, data structures, heap allocations that aren't swapped,
  /// and shared libraries loaded by the process.
  ///
  /// ## Platform Availability
  ///
  /// - **Linux/macOS**: Usually available via `/proc/self/status` or `getrusage()`
  /// - **Windows**: Available through Windows API calls like `GetProcessMemoryInfo()`
  /// - **Web/Embedded**: Often null due to platform limitations
  /// - **Dart VM**: Platform-dependent, may require platform channels on mobile
  ///
  /// ## Interpretation Guidelines
  ///
  /// ```dart
  /// if (rssMemory != null) {
  ///   final rssInMB = rssMemory! / (1024 * 1024);
  ///   if (rssInMB > 500) {
  ///     print('High memory usage detected: ${rssInMB.toStringAsFixed(1)}MB');
  ///   }
  /// } else {
  ///   print('RSS memory information not available on this platform');
  /// }
  /// ```
  ///
  /// ## Important Notes
  ///
  /// - Value can fluctuate due to OS memory management and garbage collection
  /// - Shared libraries are included, so baseline memory varies between systems
  /// - May not immediately reflect heap allocations due to OS caching behaviors
  final int? rssMemory;

  /// Heap memory usage in bytes, if available from the runtime.
  ///
  /// Heap usage represents dynamic memory allocations made by the program.
  /// This includes objects created with constructors, dynamic data structures,
  /// and runtime allocations, but excludes static/code memory.
  ///
  /// ## Availability Limitations
  ///
  /// Heap usage information is limited in Dart:
  /// - **Dart VM**: No direct public API for heap usage measurement
  /// - **Web**: Browser memory APIs are restricted for security
  /// - **Custom Implementation**: May require platform-specific native code
  ///
  /// ## When Available
  ///
  /// ```dart
  /// if (heapUsage != null) {
  ///   final heapInMB = heapUsage! / (1024 * 1024);
  ///   print('Heap usage: ${heapInMB.toStringAsFixed(1)}MB');
  ///
  ///   // Compare to RSS to estimate non-heap memory
  ///   if (rssMemory != null) {
  ///     final nonHeapMB = (rssMemory! - heapUsage!) / (1024 * 1024);
  ///     print('Non-heap (code/stack/etc): ${nonHeapMB.toStringAsFixed(1)}MB');
  ///   }
  /// } else {
  ///   print('Heap usage information not available');
  /// }
  /// ```
  ///
  /// ## Implementation Notes
  ///
  /// - Usually null in standard Dart applications
  /// - May require custom native extensions for accurate measurement
  /// - Garbage collection timing affects measurements significantly
  final int? heapUsage;

  /// Creates a new memory checkpoint with the specified parameters.
  ///
  /// ## Parameters
  ///
  /// **label**: A descriptive identifier for this measurement point.
  /// Should be meaningful for analysis (e.g., "batch_start", "after_1000_files").
  /// Labels help identify specific points in processing when reviewing memory reports.
  ///
  /// **timestamp**: The exact moment when this measurement was taken.
  /// Used for temporal analysis and calculating time-based memory growth rates.
  /// Should reflect the actual measurement time, not when the checkpoint object was created.
  ///
  /// **rssMemory**: Resident Set Size in bytes, or null if unavailable.
  /// Represents physical memory currently used by the process.
  /// Platform-dependent availability - may be null on web or embedded platforms.
  ///
  /// **heapUsage**: Heap memory usage in bytes, or null if unavailable.
  /// Represents dynamic memory allocations on the heap.
  /// Limited availability in Dart - typically null unless custom measurement is implemented.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Typical usage by monitoring systems
  /// final checkpoint = MemoryCheckpoint(
  ///   label: 'batch_processing_milestone_500',
  ///   timestamp: DateTime.now(),
  ///   rssMemory: await _getRssMemory(), // Platform-specific implementation
  ///   heapUsage: null, // Often unavailable in Dart
  /// );
  /// ```
  ///
  /// ## Implementation Notes
  ///
  /// - Both memory values accept null to handle platform limitations gracefully
  /// - Labels should follow a consistent naming convention for easier analysis
  /// - Timestamps should be as precise as possible for accurate trend analysis
  const MemoryCheckpoint({
    required this.label,
    required this.timestamp,
    this.rssMemory,
    this.heapUsage,
  });

  /// Returns a human-readable string representation of this memory checkpoint.
  ///
  /// The output includes the checkpoint label, formatted timestamp, and
  /// available memory measurements in human-readable units (KB, MB, GB).
  ///
  /// ## Output Format
  ///
  /// ```
  /// after_processing_1000 @ 2024-01-15T14:30:45.123456, RSS: 150.5MB, Heap: 85.2MB
  /// ```
  ///
  /// ## Handling Missing Data
  ///
  /// When memory values are unavailable, they're omitted from the output:
  ///
  /// ```
  /// web_platform_measurement @ 2024-01-15T14:30:45.123456
  /// ```
  ///
  /// ## Usage in Logging
  ///
  /// ```dart
  /// final checkpoint = MemoryCheckpoint(
  ///   label: 'critical_section_start',
  ///   timestamp: DateTime.now(),
  ///   rssMemory: 157286400, // ~150MB
  ///   heapUsage: null,
  /// );
  ///
  /// log.info('Memory checkpoint: $checkpoint');
  /// // Output: Memory checkpoint: critical_section_start @ 2024-01-15T14:30:45.123456, RSS: 150.0MB
  /// ```
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

  /// Formats bytes into a human-readable string representation.
  ///
  /// Automatically selects the most appropriate unit (B, KB, MB, GB) based on
  /// the magnitude of the byte value, keeping the output concise and readable.
  ///
  /// ## Unit Selection Rules
  ///
  /// - **Bytes (B)**: Values less than 1,024 bytes
  /// - **Kilobytes (KB)**: Values from 1,024 bytes to 1MB - 1 byte
  /// - **Megabytes (MB)**: Values from 1MB to 1GB - 1 byte
  /// - **Gigabytes (GB)**: Values 1GB and above
  ///
  /// ## Precision
  ///
  /// Decimal values are shown with one decimal place for clarity:
  ///
  /// ```dart
  /// _formatBytes(1536);      // "1.5KB"
  /// _formatBytes(2097152);   // "2.0MB"
  /// _formatBytes(1073741824); // "1.0GB"
  /// _formatBytes(512);       // "512B" (no decimal for bytes)
  /// ```
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
