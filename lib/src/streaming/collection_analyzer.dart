import 'package:phonic/src/core/phonic_audio_file.dart';
import 'package:phonic/src/core/tag_key.dart';

import 'cancellation_token.dart';
import 'collection_stats.dart';
import 'processing_result.dart';
import 'streaming_audio_processor.dart';
import 'streaming_config.dart';

/// Specialized analyzer for gathering comprehensive statistics from audio file collections.
///
/// This class provides high-level analysis capabilities for audio file collections,
/// extracting metadata statistics, format information, and quality metrics. It uses
/// streaming processing techniques to handle large collections efficiently without
/// overwhelming system memory.
///
/// The analyzer collects various statistics including:
/// - **Metadata Coverage**: Counts of files with different tag types
/// - **Content Diversity**: Unique artists, albums, and genres
/// - **Format Distribution**: Container format usage across the collection
/// - **Quality Metrics**: Completeness percentages and error rates
/// - **Performance Data**: Memory usage patterns during analysis
///
/// Example usage:
/// ```dart
/// final analyzer = CollectionAnalyzer(
///   config: StreamingConfig.forLargeCollections(),
/// );
///
/// final stats = await analyzer.analyzeCollection(
///   filePaths: musicFiles,
///   onProgress: (progress) {
///     print('Analyzing: ${progress.percentage.toStringAsFixed(1)}%');
///   },
/// );
///
/// print('Found ${stats.uniqueArtists.length} artists');
/// print('${stats.filesWithArtwork} files have artwork');
/// ```
class CollectionAnalyzer {
  final StreamingConfig _config;

  /// Creates a new collection analyzer with optional configuration.
  ///
  /// If no [config] is provided, uses [StreamingConfig.forLargeCollections()]
  /// which is optimized for memory efficiency during analysis operations.
  CollectionAnalyzer({StreamingConfig? config}) : _config = config ?? StreamingConfig.forLargeCollections();

  /// Analyzes a collection of audio files and returns comprehensive statistics.
  ///
  /// This method processes each audio file in the collection to extract metadata
  /// and format information, accumulating statistics about the overall collection.
  /// Uses streaming techniques to handle large collections efficiently.
  ///
  /// Parameters:
  /// - [filePaths]: List of audio file paths to analyze
  /// - [maxMemoryMB]: Optional memory limit override. If provided, creates a
  ///   temporary configuration with this memory limit.
  /// - [onProgress]: Optional callback for progress updates during analysis
  /// - [cancellationToken]: Optional token for cancelling the analysis operation
  ///
  /// Returns:
  /// A [CollectionStats] instance containing comprehensive statistics about
  /// the analyzed collection, including metadata coverage, unique values,
  /// format distribution, and memory usage information.
  ///
  /// The analysis process is non-destructive and only reads file metadata
  /// without modifying any files.
  Future<CollectionStats> analyzeCollection({
    required List<String> filePaths,
    int? maxMemoryMB,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final config = maxMemoryMB != null
        ? StreamingConfig(
            maxConcurrentFiles: _config.maxConcurrentFiles,
            memoryLimitMB: maxMemoryMB,
            continueOnError: _config.continueOnError,
            progressReportInterval: _config.progressReportInterval,
            memoryMonitorInterval: _config.memoryMonitorInterval,
            enableMemoryMonitoring: true,
          )
        : _config;

    final processor = StreamingAudioProcessor(config: config);
    final stats = CollectionStats();

    await processor.processFiles(
      filePaths: filePaths,
      processor: (audioFile, index, total) async {
        try {
          // Gather statistics from the audio file
          _analyzeFile(audioFile, stats);
          return ProcessingResult.success();
        } catch (e) {
          stats.errorCount++;
          return ProcessingResult.failure(
            e is Exception ? e : Exception(e.toString()),
          );
        }
      },
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );

    // Get memory usage report
    final memoryReport = processor.getMemoryReport();
    if (memoryReport != null) {
      stats.memoryPeak = memoryReport.peakMemoryUsage;
      stats.memoryAverage = memoryReport.averageMemoryUsage?.round();
    }

    return stats;
  }

  /// Analyzes a single audio file and updates statistics.
  void _analyzeFile(PhonicAudioFile audioFile, CollectionStats stats) {
    stats.totalFiles++;

    // Analyze tags
    final allTags = audioFile.getAllTags();
    for (final tag in allTags) {
      switch (tag.key) {
        case TagKey.title:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithTitle++;
          }
          break;
        case TagKey.artist:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithArtist++;
            stats.uniqueArtists.add(tag.value.toString());
          }
          break;
        case TagKey.album:
          if (tag.value != null && tag.value.toString().isNotEmpty) {
            stats.filesWithAlbum++;
            stats.uniqueAlbums.add(tag.value.toString());
          }
          break;
        case TagKey.genre:
          if (tag.value != null) {
            stats.filesWithGenre++;
            if (tag.value is List<String>) {
              stats.uniqueGenres.addAll(tag.value as List<String>);
            } else {
              stats.uniqueGenres.add(tag.value.toString());
            }
          }
          break;
        case TagKey.year:
          if (tag.value != null) {
            stats.filesWithYear++;
          }
          break;
        case TagKey.artwork:
          stats.filesWithArtwork++;
          break;
        default:
          // Count other tags
          break;
      }
    }

    // Track container types
    for (final tag in allTags) {
      final containerKind = tag.provenance.containerKind.name;
      stats.containerTypes[containerKind] = (stats.containerTypes[containerKind] ?? 0) + 1;
    }
  }
}
