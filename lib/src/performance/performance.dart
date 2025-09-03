/// High-performance utilities for efficient audio metadata processing.
///
/// This module provides advanced performance optimization tools designed for
/// applications that need to process large collections of audio files efficiently.
/// The tools focus on memory optimization, monitoring, and resource management.
///
/// ## Modules
///
/// ### Memory Optimization
/// - **String Interning**: Eliminates duplicate string storage in metadata
/// - **Tag Storage**: Memory-efficient storage with compact data structures
/// - **Object Pooling**: Reusable storage instances for batch processing
///
/// ### Performance Monitoring
/// - **Memory Tracking**: Detailed memory usage analysis and leak detection
/// - **Batch Monitoring**: Specialized tools for large-scale processing
/// - **Performance Metrics**: Throughput and efficiency measurements
///
/// ## When to Use Performance Tools
///
/// These tools are designed for scenarios where standard APIs may not provide
/// sufficient performance characteristics:
///
/// ### Large Collections (1000+ files)
/// ```dart
/// import 'package:phonic/performance.dart';
///
/// final pool = TagStoragePool(useInterning: true);
/// final monitor = BatchMemoryMonitor(checkpointInterval: 100);
///
/// monitor.start();
/// for (final audioFile in largeCollection) {
///   final storage = pool.acquire();
///   storage.storeTags(audioFile.getAllTags());
///
///   // Process efficiently...
///
///   pool.release(storage);
///   monitor.recordItem(audioFile.path);
/// }
///
/// final report = monitor.finish();
/// print('Processed ${monitor.processedCount} files');
/// print('Memory efficiency: ${pool.statistics['reuseRatio'] * 100}%');
/// ```
///
/// ### Memory-Constrained Environments
/// ```dart
/// import 'package:phonic/performance.dart';
///
/// final interning = StringInterning();
/// final memoryMonitor = MemoryUsageMonitor();
///
/// memoryMonitor.recordBaseline('start');
/// for (final file in files) {
///   // Intern common metadata values
///   final artist = interning.internIfBeneficial(file.artist);
///   final genre = interning.internIfBeneficial(file.genre);
///
///   if (memoryMonitor.getCurrentMemoryUsage().rssMemory > threshold) {
///     interning.clear(); // Release interned strings
///     memoryMonitor.recordCheckpoint('cleanup');
///   }
/// }
/// ```
///
/// ### Custom Processing Pipelines
/// ```dart
/// import 'package:phonic/performance.dart';
///
/// class CustomProcessor {
///   final _storage = MemoryEfficientTagStorage(useInterning: true);
///   final _monitor = MemoryUsageMonitor();
///
///   void processCustom(PhonicAudioFile audioFile) {
///     _monitor.recordCheckpoint('process_start');
///     _storage.storeTags(audioFile.getAllTags());
///
///     // Custom processing logic...
///
///     _monitor.recordCheckpoint('process_end');
///   }
///
///   MemoryReport getPerformanceReport() => _monitor.generateReport();
/// }
/// ```
library phonic.performance;

export 'memory/memory.dart';
export 'monitoring/monitoring.dart';
