part of '../core/metadata_tag.dart';

/// Represents a genre metadata tag for audio files.
///
/// GenreTag contains the musical genre or style of the track as a list of strings,
/// supporting multiple genres per track. This tag handles automatic delimiter
/// detection when parsing genre strings and provides format-specific encoding
/// methods for different container types.
///
/// Format mappings:
/// - ID3v2.4: TCON frame with null-terminated strings ('Rock\0Alternative\0Indie')
/// - ID3v2.3/v2.2: TCON frame with slash-separated strings ('Rock/Alternative/Indie')
/// - Vorbis: Multiple GENRE fields (one per genre)
/// - MP4: ©gen atom with semicolon-separated strings ('Rock;Alternative;Indie')
/// - ID3v1: Single genre byte mapped to standard genre name
///
/// Example usage:
/// ```dart
/// // Create a multi-genre tag
/// final multiGenre = GenreTag(['Rock', 'Alternative', 'Indie']);
///
/// // Create a single genre tag
/// final singleGenre = GenreTag.single('Jazz');
///
/// // Parse from various delimited formats
/// final fromSemicolon = GenreTag.fromString('Rock;Alternative;Indie');
/// final fromSlash = GenreTag.fromString('Rock/Alternative/Indie');
/// final fromComma = GenreTag.fromString('Rock, Alternative, Indie');
///
/// // Format-specific parsing
/// final fromId3v24 = GenreTag.fromId3v24String('Rock\0Alternative\0Indie');
/// final fromId3v23 = GenreTag.fromId3v23String('Rock/Alternative/Indie');
///
/// // Format-specific encoding
/// final id3v24Encoded = multiGenre.toId3v24String();     // 'Rock\0Alternative\0Indie'
/// final id3v23Encoded = multiGenre.toId3v23String();     // 'Rock/Alternative/Indie'
/// final mp4Encoded = multiGenre.toEncodedString(';');    // 'Rock;Alternative;Indie'
/// final displayEncoded = multiGenre.toEncodedString(', '); // 'Rock, Alternative, Indie'
/// ```
///
/// The GenreTag automatically handles:
/// - Delimiter detection with null-terminator priority
/// - Whitespace trimming and empty value filtering
/// - Format-specific encoding for different container types
/// - Single and multi-genre scenarios
final class GenreTag extends MetadataTag<List<String>> {
  /// Creates a new GenreTag with the specified list of genres.
  ///
  /// @param value List of genre strings, must not be null but can be empty
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = GenreTag(['Rock', 'Alternative']);
  /// ```
  GenreTag(
    List<String> value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: List.unmodifiable(value),
         key: TagKey.genre,
         provenance: provenance,
       );

  /// Convenience constructor for creating a single-genre tag.
  ///
  /// This constructor simplifies the common case of having only one genre
  /// by automatically wrapping the single genre string in a list.
  ///
  /// @param genre The single genre string
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = GenreTag.single('Jazz');
  /// // Equivalent to: GenreTag(['Jazz'])
  /// ```
  GenreTag.single(
    String genre, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : this([genre], provenance: provenance);

  /// Creates a GenreTag from a delimited string with automatic delimiter detection.
  ///
  /// This constructor automatically detects the delimiter used in the input string
  /// and splits it into individual genres. The detection algorithm prioritizes
  /// null terminators (ID3v2.4 format) and then analyzes common delimiters.
  ///
  /// Supported delimiters (in detection priority order):
  /// - Null terminator (\0) - ID3v2.4 format
  /// - Slash (/) - ID3v2.3 format and common usage
  /// - Semicolon (;) - MP4 format and some systems
  /// - Pipe (|) - Some legacy systems
  /// - Comma (,) - Human-readable format
  /// - Backslash (\) - Some legacy systems
  ///
  /// @param genreString The delimited genre string to parse
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final fromSemicolon = GenreTag.fromString('Rock;Alternative;Indie');
  /// final fromSlash = GenreTag.fromString('Rock/Alternative/Indie');
  /// final fromComma = GenreTag.fromString('Rock, Alternative, Indie');
  /// // All result in: ['Rock', 'Alternative', 'Indie']
  /// ```
  GenreTag.fromString(
    String genreString, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : this(_parseGenreString(genreString), provenance: provenance);

  /// Creates a GenreTag from an ID3v2.4 null-terminated string.
  ///
  /// ID3v2.4 uses null-terminated strings in TCON frames to separate multiple
  /// genres. This constructor specifically handles this format.
  ///
  /// @param genreString The null-terminated genre string from ID3v2.4
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = GenreTag.fromId3v24String('Rock\0Alternative\0Indie');
  /// // Results in: ['Rock', 'Alternative', 'Indie']
  /// ```
  GenreTag.fromId3v24String(
    String genreString, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : this(
         genreString.split(String.fromCharCode(0)).where((g) => g.isNotEmpty).toList(),
         provenance: provenance,
       );

  /// Creates a GenreTag from an ID3v2.3 slash-separated string.
  ///
  /// ID3v2.3 and v2.2 use slash-separated strings in TCON frames to separate
  /// multiple genres. This constructor specifically handles this format.
  ///
  /// @param genreString The slash-separated genre string from ID3v2.3/v2.2
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = GenreTag.fromId3v23String('Rock/Alternative/Indie');
  /// // Results in: ['Rock', 'Alternative', 'Indie']
  /// ```
  GenreTag.fromId3v23String(
    String genreString, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : this(
         genreString.split('/').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
         provenance: provenance,
       );

  /// Encodes the genres using the specified delimiter.
  ///
  /// This method provides a generic way to encode multiple genres into a
  /// single string using any delimiter. This is useful for formats that
  /// don't have specific encoding requirements or for display purposes.
  ///
  /// @param delimiter The delimiter to use between genres (defaults to semicolon)
  /// @returns A string with genres separated by the specified delimiter
  ///
  /// Example:
  /// ```dart
  /// final genres = GenreTag(['Rock', 'Alternative', 'Indie']);
  /// final semicolon = genres.toEncodedString(';');    // 'Rock;Alternative;Indie'
  /// final comma = genres.toEncodedString(', ');       // 'Rock, Alternative, Indie'
  /// final pipe = genres.toEncodedString('|');         // 'Rock|Alternative|Indie'
  /// ```
  String toEncodedString([String delimiter = ';']) => value.join(delimiter);

  /// Encodes the genres for ID3v2.4 using null-terminated strings.
  ///
  /// ID3v2.4 TCON frames use null terminators to separate multiple genres.
  /// This method formats the genres according to this specification.
  ///
  /// @returns A string with genres separated by null terminators
  ///
  /// Example:
  /// ```dart
  /// final genres = GenreTag(['Rock', 'Alternative', 'Indie']);
  /// final encoded = genres.toId3v24String(); // 'Rock\0Alternative\0Indie'
  /// ```
  String toId3v24String() => value.join(String.fromCharCode(0));

  /// Encodes the genres for ID3v2.3/v2.2 using slash separation.
  ///
  /// ID3v2.3 and v2.2 TCON frames use forward slashes to separate multiple
  /// genres. This method formats the genres according to this specification.
  ///
  /// @returns A string with genres separated by forward slashes
  ///
  /// Example:
  /// ```dart
  /// final genres = GenreTag(['Rock', 'Alternative', 'Indie']);
  /// final encoded = genres.toId3v23String(); // 'Rock/Alternative/Indie'
  /// ```
  String toId3v23String() => value.join('/');

  /// Parses a genre string with automatic delimiter detection.
  ///
  /// This static method implements the core delimiter detection algorithm
  /// used by the [fromString] constructor. It prioritizes null terminators
  /// and then analyzes the frequency of common delimiters to determine
  /// the most likely separator.
  ///
  /// Detection algorithm:
  /// 1. Check for null terminators first (ID3v2.4 format)
  /// 2. Count occurrences of common delimiters: /, ;, |, ,, \
  /// 3. Use the most frequent delimiter for splitting
  /// 4. Default to slash (/) if no delimiters found with multiple occurrences
  /// 5. Treat as single genre if no delimiters detected
  /// 6. Trim whitespace and filter empty values
  ///
  /// @param genreString The input string to parse
  /// @returns A list of individual genre strings
  static List<String> _parseGenreString(String genreString) {
    if (genreString.trim().isEmpty) return [];

    // Handle null-terminated strings (ID3v2.4) with highest priority
    final nullChar = String.fromCharCode(0);
    if (genreString.contains(nullChar)) {
      return genreString.split(nullChar).where((g) => g.isNotEmpty).toList();
    }

    // Common delimiters used by different systems
    final delimiters = ['/', ';', '|', ',', '\\'];

    // Find the most likely delimiter by counting occurrences
    String bestDelimiter = '/'; // default to slash (ID3v2.3 standard)
    int maxCount = 0;

    for (final delimiter in delimiters) {
      final count = delimiter.allMatches(genreString).length;
      if (count > maxCount) {
        maxCount = count;
        bestDelimiter = delimiter;
      }
    }

    // If no delimiters found, treat as single genre
    if (maxCount == 0) {
      return [genreString.trim()];
    }

    // Split by the best delimiter and clean up
    return genreString.split(bestDelimiter).map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
  }

  /// Creates a new GenreTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the genre tag while preserving the genre list. This is commonly
  /// used during tag processing operations where the same genres need
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new GenreTag instance with the same genres but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = GenreTag(['Rock', 'Alternative']);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  GenreTag withProvenance(TagProvenance newProvenance) {
    return GenreTag(value, provenance: newProvenance);
  }
}
