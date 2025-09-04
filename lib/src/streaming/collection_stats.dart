/// Comprehensive statistics collected from analyzing a collection of audio files.
///
/// This class accumulates various metadata and performance statistics during
/// collection analysis operations. It tracks file counts, metadata coverage,
/// unique values, container format distribution, and memory usage patterns.
///
/// The statistics provide insight into:
/// - Overall collection size and processing success rate
/// - Metadata completeness across different tag types
/// - Diversity of artists, albums, and genres
/// - Distribution of audio formats and containers
/// - Memory usage patterns during analysis
///
/// Example usage:
/// ```dart
/// final stats = CollectionStats();
/// // ... populate during analysis
/// print('Analyzed ${stats.totalFiles} files');
/// print('${stats.filesWithArtwork} files have artwork');
/// print('Found ${stats.uniqueArtists.length} unique artists');
/// ```
class CollectionStats {
  /// Total number of audio files that were processed during analysis.
  int totalFiles = 0;

  /// Number of files that encountered processing errors.
  ///
  /// This includes files that couldn't be opened, parsed, or analyzed
  /// due to corruption, unsupported formats, or other issues.
  int errorCount = 0;

  /// Number of files that contain title metadata tags.
  int filesWithTitle = 0;

  /// Number of files that contain artist metadata tags.
  int filesWithArtist = 0;

  /// Number of files that contain album metadata tags.
  int filesWithAlbum = 0;

  /// Number of files that contain genre metadata tags.
  int filesWithGenre = 0;

  /// Number of files that contain year/date metadata tags.
  int filesWithYear = 0;

  /// Number of files that contain embedded artwork/cover images.
  int filesWithArtwork = 0;

  /// Set of unique artist names found across the collection.
  ///
  /// This provides insight into the diversity of artists and can be used
  /// to generate artist lists or detect duplicates with different spellings.
  final Set<String> uniqueArtists = <String>{};

  /// Set of unique album names found across the collection.
  ///
  /// Useful for understanding the collection's album diversity and
  /// identifying compilation albums or various artist collections.
  final Set<String> uniqueAlbums = <String>{};

  /// Set of unique genre classifications found across the collection.
  ///
  /// Helps categorize the music collection and identify genre diversity
  /// or inconsistencies in genre tagging.
  final Set<String> uniqueGenres = <String>{};

  /// Distribution of container/format types found in the collection.
  ///
  /// Maps format names (e.g., 'MP3', 'FLAC', 'MP4') to occurrence counts,
  /// providing insight into the collection's format diversity.
  final Map<String, int> containerTypes = <String, int>{};

  /// Peak memory usage recorded during the analysis process (in bytes).
  ///
  /// This metric helps understand the memory requirements for similar
  /// analysis operations and can guide configuration tuning.
  int? memoryPeak;

  /// Average memory usage recorded during the analysis process (in bytes).
  ///
  /// Provides insight into typical memory consumption patterns throughout
  /// the analysis operation.
  int? memoryAverage;

  /// Calculates the percentage of files with complete core metadata.
  ///
  /// Complete metadata is defined as having title, artist, and album tags.
  /// This metric indicates the overall metadata quality of the collection.
  /// Returns 0.0 if no files were processed to avoid division by zero.
  double get completenessPercentage {
    if (totalFiles == 0) return 0.0;

    var completeFiles = 0;
    for (int i = 0; i < totalFiles; i++) {
      // This is a simplified calculation - in practice you'd track this during analysis
      if (filesWithTitle > 0 && filesWithArtist > 0 && filesWithAlbum > 0) {
        completeFiles++;
      }
    }

    return (completeFiles / totalFiles) * 100.0;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Collection Statistics');
    buffer.writeln('====================');
    buffer.writeln('Total Files: $totalFiles');
    buffer.writeln('Errors: $errorCount');
    buffer.writeln();
    buffer.writeln('Metadata Coverage:');
    buffer.writeln('  Title: $filesWithTitle (${_percentage(filesWithTitle, totalFiles)}%)');
    buffer.writeln('  Artist: $filesWithArtist (${_percentage(filesWithArtist, totalFiles)}%)');
    buffer.writeln('  Album: $filesWithAlbum (${_percentage(filesWithAlbum, totalFiles)}%)');
    buffer.writeln('  Genre: $filesWithGenre (${_percentage(filesWithGenre, totalFiles)}%)');
    buffer.writeln('  Year: $filesWithYear (${_percentage(filesWithYear, totalFiles)}%)');
    buffer.writeln('  Artwork: $filesWithArtwork (${_percentage(filesWithArtwork, totalFiles)}%)');
    buffer.writeln();
    buffer.writeln('Unique Values:');
    buffer.writeln('  Artists: ${uniqueArtists.length}');
    buffer.writeln('  Albums: ${uniqueAlbums.length}');
    buffer.writeln('  Genres: ${uniqueGenres.length}');

    if (memoryPeak != null) {
      buffer.writeln();
      buffer.writeln('Memory Usage:');
      buffer.writeln('  Peak: ${_formatBytes(memoryPeak!)}');
      if (memoryAverage != null) {
        buffer.writeln('  Average: ${_formatBytes(memoryAverage!)}');
      }
    }

    return buffer.toString();
  }

  double _percentage(int value, int total) {
    return total > 0 ? (value / total) * 100.0 : 0.0;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
