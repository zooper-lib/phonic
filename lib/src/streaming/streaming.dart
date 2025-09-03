/// Comprehensive streaming utilities for memory-efficient audio file processing.
///
/// This library provides a complete set of tools for processing large collections
/// of audio files in a memory-efficient manner. The streaming approach ensures
/// that memory usage remains bounded regardless of collection size, making it
/// suitable for processing thousands or tens of thousands of audio files.
///
/// ## Core Components
///
/// ### Processors
/// - [StreamingAudioProcessor] - Sequential file-by-file processing
/// - [BatchAudioProcessor] - Batch-based processing for very large collections
/// - [CollectionAnalyzer] - Specialized analyzer for gathering collection statistics
///
/// ### Configuration and Control
/// - [StreamingConfig] - Configuration for memory limits and processing behavior
/// - [CancellationToken] - Cancellation mechanism for long-running operations
///
/// ### Progress and Results
/// - [StreamingProgress] - Real-time progress information with ETA calculations
/// - [ProcessingResult] - Individual file processing results
/// - [CollectionStats] - Comprehensive collection analysis statistics
///
/// ## Usage Examples
///
/// ### Basic Streaming Processing
/// ```dart
/// final processor = StreamingAudioProcessor();
/// final results = await processor.processFiles(
///   filePaths: audioFiles,
///   processor: (audioFile, index, total) async {
///     // Process each file
///     return ProcessingResult.success();
///   },
/// );
/// ```
///
/// ### Collection Analysis
/// ```dart
/// final analyzer = CollectionAnalyzer();
/// final stats = await analyzer.analyzeCollection(filePaths: audioFiles);
/// print('Found ${stats.uniqueArtists.length} unique artists');
/// ```
///
/// ### Batch Processing for Large Collections
/// ```dart
/// final batchProcessor = BatchAudioProcessor();
/// final results = await batchProcessor.processBatches(
///   filePaths: largeCollection,
///   batchSize: 100,
///   processor: (batch) async => await processBatch(batch),
/// );
/// ```
library streaming;

export 'batch_audio_processor.dart';
export 'cancellation_token.dart';
export 'collection_analyzer.dart';
export 'collection_stats.dart';
export 'processing_result.dart';
export 'streaming_audio_processor.dart';
export 'streaming_config.dart';
export 'streaming_progress.dart';
