/// Utilities for parsing and encoding genre information in ID3v2 tags.
///
/// This utility class provides specialized functions for handling genre data
/// in ID3v2 TCON (Content Type) frames across different ID3v2 versions.
/// Each version has specific encoding requirements:
///
/// - **ID3v2.4**: Uses null-terminated strings for multiple genres
/// - **ID3v2.3/v2.2**: Uses slash-separated strings for multiple genres
/// - **Generic**: Supports automatic delimiter detection for other formats
///
/// The utilities handle edge cases like mixed delimiters, escaped characters,
/// and malformed data while maintaining compatibility with the ID3v2 specification.
///
/// ## Usage Examples
///
/// ```dart
/// // Parse ID3v2.4 null-terminated genre string
/// final genres24 = Id3v2GenreUtils.parseId3v24Genres('Rock\0Alternative\0Indie');
/// // Result: ['Rock', 'Alternative', 'Indie']
///
/// // Parse ID3v2.3 slash-separated genre string
/// final genres23 = Id3v2GenreUtils.parseId3v23Genres('Rock/Alternative/Indie');
/// // Result: ['Rock', 'Alternative', 'Indie']
///
/// // Generic parsing with automatic delimiter detection
/// final genres = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock;Pop;Jazz');
/// // Result: ['Rock', 'Pop', 'Jazz']
///
/// // Encode genres for ID3v2.4
/// final encoded24 = Id3v2GenreUtils.encodeId3v24Genres(['Rock', 'Alternative']);
/// // Result: 'Rock\0Alternative'
///
/// // Encode genres for ID3v2.3
/// final encoded23 = Id3v2GenreUtils.encodeId3v23Genres(['Rock', 'Alternative']);
/// // Result: 'Rock/Alternative'
/// ```
class Id3v2GenreUtils {
  /// Private constructor to prevent instantiation of utility class.
  Id3v2GenreUtils._();

  /// Common delimiters used in genre strings, ordered by detection priority.
  ///
  /// The order reflects the priority for delimiter detection:
  /// 1. Null terminator (\0) - ID3v2.4 standard
  /// 2. Slash (/) - ID3v2.3/v2.2 standard
  /// 3. Semicolon (;) - Common in MP4 and other formats
  /// 4. Pipe (|) - Used by some legacy systems
  /// 5. Comma (,) - Human-readable format
  /// 6. Backslash (\) - Some legacy systems
  static const List<String> _commonDelimiters = ['\0', '/', ';', '|', ',', '\\'];

  /// Parses genre information from ID3v2.4 TCON frame data.
  ///
  /// ID3v2.4 uses null-terminated strings to separate multiple genres within
  /// a single TCON frame. This method specifically handles the ID3v2.4 format
  /// and provides robust parsing with error handling.
  ///
  /// Features:
  /// - Handles null-terminated genre strings
  /// - Filters empty genres
  /// - Trims whitespace from individual genres
  /// - Handles malformed data gracefully
  ///
  /// @param genreString The raw genre string from ID3v2.4 TCON frame
  /// @returns List of individual genre strings, empty list if input is invalid
  ///
  /// Example:
  /// ```dart
  /// final genres = Id3v2GenreUtils.parseId3v24Genres('Rock\0Alternative\0Indie\0');
  /// // Result: ['Rock', 'Alternative', 'Indie']
  ///
  /// // Handles edge cases
  /// final empty = Id3v2GenreUtils.parseId3v24Genres('');
  /// // Result: []
  ///
  /// final single = Id3v2GenreUtils.parseId3v24Genres('Jazz');
  /// // Result: ['Jazz']
  /// ```
  static List<String> parseId3v24Genres(String genreString) {
    if (genreString.isEmpty) return <String>[];

    // Split by null terminators and clean up
    // Use String.fromCharCode(0) instead of '\0' for proper null character handling
    final nullChar = String.fromCharCode(0);
    return genreString.split(nullChar).map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).toList();
  }

  /// Parses genre information from ID3v2.3/v2.2 TCON frame data.
  ///
  /// ID3v2.3 and v2.2 use slash-separated strings to separate multiple genres
  /// within a single TCON frame. This method handles the slash-separated format
  /// with proper escaping and edge case handling.
  ///
  /// Features:
  /// - Handles slash-separated genre strings
  /// - Supports escaped slashes (\\/) in genre names
  /// - Filters empty genres
  /// - Trims whitespace from individual genres
  /// - Handles malformed data gracefully
  ///
  /// @param genreString The raw genre string from ID3v2.3/v2.2 TCON frame
  /// @returns List of individual genre strings, empty list if input is invalid
  ///
  /// Example:
  /// ```dart
  /// final genres = Id3v2GenreUtils.parseId3v23Genres('Rock/Alternative/Indie');
  /// // Result: ['Rock', 'Alternative', 'Indie']
  ///
  /// // Handles escaped slashes
  /// final escaped = Id3v2GenreUtils.parseId3v23Genres('Rock\\/Roll/Pop');
  /// // Result: ['Rock/Roll', 'Pop']
  ///
  /// final single = Id3v2GenreUtils.parseId3v23Genres('Jazz');
  /// // Result: ['Jazz']
  /// ```
  static List<String> parseId3v23Genres(String genreString) {
    if (genreString.isEmpty) return <String>[];

    // Handle escaped slashes by temporarily replacing them
    const String escapeMarker = '\uE000'; // Private use area character
    final String processedString = genreString.replaceAll('\\/', escapeMarker);

    // Split by unescaped slashes and restore escaped ones
    return processedString.split('/').map((genre) => genre.replaceAll(escapeMarker, '/').trim()).where((genre) => genre.isNotEmpty).toList();
  }

  /// Parses genre information using automatic delimiter detection.
  ///
  /// This method analyzes the input string to determine the most likely
  /// delimiter and then parses the genres accordingly. It's useful for
  /// handling genre data from unknown sources or mixed formats.
  ///
  /// Detection algorithm:
  /// 1. Check for null terminators first (ID3v2.4 format)
  /// 2. Analyze frequency of common delimiters
  /// 3. Use the most frequent delimiter for splitting
  /// 4. Handle escaped delimiters where possible
  /// 5. Fall back to single genre if no delimiters detected
  ///
  /// @param genreString The genre string with unknown delimiter format
  /// @returns List of individual genre strings
  ///
  /// Example:
  /// ```dart
  /// // Automatic detection of semicolon delimiter
  /// final genres1 = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock;Pop;Jazz');
  /// // Result: ['Rock', 'Pop', 'Jazz']
  ///
  /// // Automatic detection of comma delimiter
  /// final genres2 = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock, Pop, Jazz');
  /// // Result: ['Rock', 'Pop', 'Jazz']
  ///
  /// // Single genre (no delimiters)
  /// final single = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Electronic');
  /// // Result: ['Electronic']
  /// ```
  static List<String> parseGenresWithDelimiterDetection(String genreString) {
    if (genreString.trim().isEmpty) return <String>[];

    // Handle null-terminated strings (ID3v2.4) with highest priority
    if (genreString.contains('\0')) {
      return parseId3v24Genres(genreString);
    }

    // Analyze delimiter frequency
    final DelimiterAnalysis analysis = _analyzeDelimiters(genreString);

    // If no significant delimiter found, treat as single genre
    if (analysis.bestDelimiter.isEmpty || analysis.maxCount == 0) {
      return [genreString.trim()];
    }

    // Parse using the detected delimiter
    return _parseWithDelimiter(genreString, analysis.bestDelimiter);
  }

  /// Encodes a list of genres for ID3v2.4 TCON frame.
  ///
  /// Creates a null-terminated string suitable for ID3v2.4 TCON frames.
  /// Multiple genres are separated by null terminators according to the
  /// ID3v2.4 specification.
  ///
  /// @param genres List of genre strings to encode
  /// @returns Null-terminated string for ID3v2.4 TCON frame
  ///
  /// Example:
  /// ```dart
  /// final encoded = Id3v2GenreUtils.encodeId3v24Genres(['Rock', 'Alternative', 'Indie']);
  /// // Result: 'Rock\0Alternative\0Indie'
  ///
  /// final single = Id3v2GenreUtils.encodeId3v24Genres(['Jazz']);
  /// // Result: 'Jazz'
  ///
  /// final empty = Id3v2GenreUtils.encodeId3v24Genres([]);
  /// // Result: ''
  /// ```
  static String encodeId3v24Genres(List<String> genres) {
    if (genres.isEmpty) return '';
    // Use String.fromCharCode(0) instead of '\0' for proper null character handling
    final nullChar = String.fromCharCode(0);
    return genres.where((genre) => genre.isNotEmpty).join(nullChar);
  }

  /// Encodes a list of genres for ID3v2.3/v2.2 TCON frame.
  ///
  /// Creates a slash-separated string suitable for ID3v2.3 and v2.2 TCON frames.
  /// Multiple genres are separated by forward slashes, with proper escaping
  /// of slashes within genre names.
  ///
  /// @param genres List of genre strings to encode
  /// @returns Slash-separated string for ID3v2.3/v2.2 TCON frame
  ///
  /// Example:
  /// ```dart
  /// final encoded = Id3v2GenreUtils.encodeId3v23Genres(['Rock', 'Alternative', 'Indie']);
  /// // Result: 'Rock/Alternative/Indie'
  ///
  /// // Handles slashes in genre names
  /// final escaped = Id3v2GenreUtils.encodeId3v23Genres(['Rock/Roll', 'Pop']);
  /// // Result: 'Rock\\/Roll/Pop'
  ///
  /// final single = Id3v2GenreUtils.encodeId3v23Genres(['Jazz']);
  /// // Result: 'Jazz'
  /// ```
  static String encodeId3v23Genres(List<String> genres) {
    if (genres.isEmpty) return '';

    // Escape slashes in individual genre names
    final List<String> escapedGenres = genres.where((genre) => genre.isNotEmpty).map((genre) => genre.replaceAll('/', '\\/')).toList();

    return escapedGenres.join('/');
  }

  /// Analyzes a string to determine the most likely delimiter.
  ///
  /// This method counts occurrences of common delimiters and returns
  /// analysis results including the best delimiter and its frequency.
  ///
  /// @param input The string to analyze
  /// @returns DelimiterAnalysis containing the best delimiter and count
  static DelimiterAnalysis _analyzeDelimiters(String input) {
    String bestDelimiter = '';
    int maxCount = 0;

    // Skip null terminator as it's handled separately
    for (final delimiter in _commonDelimiters.skip(1)) {
      final int count = delimiter.allMatches(input).length;
      if (count > maxCount) {
        maxCount = count;
        bestDelimiter = delimiter;
      }
    }

    return DelimiterAnalysis(bestDelimiter, maxCount);
  }

  /// Parses a string using the specified delimiter.
  ///
  /// Handles delimiter-specific parsing logic including escape sequences
  /// where applicable.
  ///
  /// @param input The string to parse
  /// @param delimiter The delimiter to use for splitting
  /// @returns List of parsed genre strings
  static List<String> _parseWithDelimiter(String input, String delimiter) {
    switch (delimiter) {
      case '/':
        return parseId3v23Genres(input);
      case '\\':
        // Handle backslash delimiter (some legacy systems)
        return input.split('\\').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).toList();
      default:
        // Generic delimiter handling
        return input.split(delimiter).map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).toList();
    }
  }
}

/// Analysis result for delimiter detection.
///
/// Contains information about the most likely delimiter found in a string
/// and its frequency of occurrence.
class DelimiterAnalysis {
  /// The delimiter that appears most frequently in the analyzed string.
  final String bestDelimiter;

  /// The number of times the best delimiter appears in the string.
  final int maxCount;

  /// Creates a new DelimiterAnalysis instance.
  ///
  /// @param bestDelimiter The most frequent delimiter found
  /// @param maxCount The frequency of the best delimiter
  const DelimiterAnalysis(this.bestDelimiter, this.maxCount);

  @override
  String toString() => 'DelimiterAnalysis(delimiter: "$bestDelimiter", count: $maxCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DelimiterAnalysis && runtimeType == other.runtimeType && bestDelimiter == other.bestDelimiter && maxCount == other.maxCount;

  @override
  int get hashCode => bestDelimiter.hashCode ^ maxCount.hashCode;
}
