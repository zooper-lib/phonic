/// Memory usage monitoring and analysis tools for audio processing applications.
///
/// This module provides comprehensive memory monitoring capabilities for tracking
/// memory usage patterns, detecting potential leaks, and optimizing performance
/// during large-scale audio file processing operations.
///
/// ## Core Components
///
/// ### Memory Usage Tracking
/// - [MemoryUsageMonitor] - Detailed memory usage tracking with checkpoints
/// - [MemoryCheckpoint] - Individual memory usage snapshots
/// - [MemoryReport] - Comprehensive analysis of memory usage patterns
///
/// ### Batch Processing Monitoring
/// - [BatchMemoryMonitor] - Specialized monitoring for batch operations
/// - Automated checkpoint creation at configurable intervals
/// - Memory leak detection and growth pattern analysis
///
/// ## Usage Examples
///
/// ### Basic Memory Monitoring
/// ```dart
/// final monitor = MemoryUsageMonitor();
/// monitor.recordBaseline('processing_start');
///
/// // Process audio files...
/// for (int i = 0; i < files.length; i++) {
///   processAudioFile(files[i]);
///
///   if (i % 100 == 0) {
///     monitor.recordCheckpoint('batch_$i');
///   }
/// }
///
/// final report = monitor.generateReport();
/// print('Peak memory usage: ${report.peakMemoryUsage} bytes');
/// print('Memory growth: ${report.memoryGrowth} bytes');
/// print('Potential leak detected: ${report.potentialLeakDetected}');
/// ```
///
/// ### Batch Processing Monitoring
/// ```dart
/// final batchMonitor = BatchMemoryMonitor(checkpointInterval: 50);
/// batchMonitor.start();
///
/// for (int i = 0; i < largeCollection.length; i++) {
///   processFile(largeCollection[i]);
///   batchMonitor.recordItem('file_$i');
/// }
///
/// final report = batchMonitor.finish();
/// print('Processing completed: ${batchMonitor.processedCount} files');
/// print('Memory checkpoints: ${report.checkpoints.length}');
/// print('Total duration: ${report.totalDuration}');
/// ```
///
/// ### Memory Threshold Monitoring
/// ```dart
/// final monitor = MemoryUsageMonitor();
/// const memoryThreshold = 100 * 1024 * 1024; // 100MB
///
/// while (hasMoreFiles) {
///   processNextFile();
///
///   final currentUsage = monitor.getCurrentMemoryUsage();
///   if (currentUsage.rssMemory > memoryThreshold) {
///     // Trigger cleanup or throttling
///     performMemoryCleanup();
///     monitor.recordCheckpoint('cleanup_triggered');
///   }
/// }
/// ```
library phonic.performance.monitoring;

// Export only the main user-facing classes, not internal data structures
export 'memory_usage_monitor.dart';
