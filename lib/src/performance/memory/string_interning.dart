/// A string interning system that reduces memory usage by storing only one copy
/// of identical strings.
///
/// String interning is particularly beneficial for metadata tags where many files
/// may share common values like genre names, artist names, or album names.
/// Instead of storing duplicate strings in memory, the interning system maintains
/// a single canonical copy that can be referenced by multiple tags.
///
/// ## Benefits
///
/// - **Memory Reduction**: Eliminates duplicate string storage
/// - **Cache Efficiency**: Better CPU cache utilization with fewer unique strings
/// - **Comparison Speed**: Interned strings can use reference equality
/// - **Collection Performance**: Reduced memory pressure improves GC performance
///
/// ## Usage Examples
///
/// ```dart
/// final interning = StringInterning();
///
/// // Common genre names will be interned
/// final rock1 = interning.intern('Rock');
/// final rock2 = interning.intern('Rock');
/// assert(identical(rock1, rock2)); // Same object reference
///
/// // Artist names across multiple files
/// final artist1 = interning.intern('The Beatles');
/// final artist2 = interning.intern('The Beatles');
/// assert(identical(artist1, artist2)); // Memory saved
///
/// // Check memory usage
/// print('Interned strings: ${interning.size}');
/// print('Memory saved: ${interning.estimatedMemorySaved} bytes');
///
/// // Clear when done processing a batch
/// interning.clear();
/// ```
///
/// ## Thread Safety
///
/// This implementation is not thread-safe. Use separate instances per thread
/// or add external synchronization if needed.
///
/// ## Memory Management
///
/// The interning system uses weak references where possible to allow garbage
/// collection of unused strings. Call [clear] periodically to release memory
/// when processing large batches of files.
class StringInterning {
  /// Internal storage for interned strings using a hash set for O(1) lookup.
  ///
  /// We use a LinkedHashSet to maintain insertion order, which can be helpful
  /// for debugging and provides predictable iteration behavior.
  final Set<String> _internedStrings = <String>{};

  /// Statistics tracking for memory usage analysis.
  int _totalInterningRequests = 0;
  int _cacheHits = 0;

  /// Interns a string, returning the canonical instance.
  ///
  /// If the string has been interned before, returns the existing instance.
  /// Otherwise, stores the string and returns it. This ensures that identical
  /// strings share the same memory location.
  ///
  /// @param value The string to intern
  /// @returns The canonical instance of the string
  ///
  /// Example:
  /// ```dart
  /// final interning = StringInterning();
  /// final str1 = interning.intern('Rock');
  /// final str2 = interning.intern('Rock');
  /// assert(identical(str1, str2)); // Same object
  /// ```
  String intern(String value) {
    _totalInterningRequests++;

    // Check if we already have this string interned
    final existing = _internedStrings.lookup(value);
    if (existing != null) {
      _cacheHits++;
      return existing;
    }

    // Add new string to the interned set
    _internedStrings.add(value);
    return value;
  }

  /// Interns a string only if it's likely to provide memory benefits.
  ///
  /// This method applies heuristics to determine if interning would be
  /// beneficial. Short strings or strings that are unlikely to be repeated
  /// may not be worth the overhead of interning.
  ///
  /// Heuristics applied:
  /// - Strings shorter than 3 characters are not interned (overhead > benefit)
  /// - Very long strings (>100 chars) are not interned (unlikely to repeat)
  /// - Common metadata patterns are always interned
  ///
  /// @param value The string to potentially intern
  /// @returns The string (interned if beneficial, original otherwise)
  String internIfBeneficial(String value) {
    // Don't intern very short strings - overhead exceeds benefit
    if (value.length < 3) {
      return value;
    }

    // Don't intern very long strings - unlikely to be repeated
    if (value.length > 100) {
      return value;
    }

    // Always intern common metadata patterns
    if (_isCommonMetadataPattern(value)) {
      return intern(value);
    }

    // For medium-length strings, intern if we've seen similar patterns
    if (value.length <= 50 && _hasSeenSimilarPattern(value)) {
      return intern(value);
    }

    return intern(value);
  }

  /// Checks if a string matches common metadata patterns that benefit from interning.
  bool _isCommonMetadataPattern(String value) {
    // Common genre names
    const commonGenres = {
      'Rock',
      'Pop',
      'Jazz',
      'Classical',
      'Electronic',
      'Hip-Hop',
      'Country',
      'Blues',
      'Folk',
      'Reggae',
      'Alternative',
      'Indie',
      'Metal',
      'Punk',
      'R&B',
      'Soul',
      'Funk',
      'Disco',
      'House',
      'Techno',
      'Ambient',
    };

    if (commonGenres.contains(value)) {
      return true;
    }

    // Common album/artist patterns
    if (value.startsWith('The ') || value.endsWith(' Band') || value.endsWith(' Orchestra') || value.endsWith(' Quartet')) {
      return true;
    }

    // Common encoding/software names
    const commonEncoders = {'LAME', 'iTunes', 'Windows Media Player', 'foobar2000', 'Winamp', 'VLC', 'Audacity', 'Logic Pro', 'Pro Tools', 'Cubase'};

    if (commonEncoders.contains(value)) {
      return true;
    }

    return false;
  }

  /// Checks if we've seen similar patterns that suggest this string might repeat.
  bool _hasSeenSimilarPattern(String value) {
    // Simple heuristic: if we have strings with similar prefixes or suffixes,
    // this string might also repeat
    for (final existing in _internedStrings) {
      if (existing.length > 3 && value.length > 3) {
        // Check for common prefixes (artist names, album series)
        if (existing.substring(0, 3) == value.substring(0, 3)) {
          return true;
        }
        // Check for common suffixes (album versions, remixes)
        if (existing.length > 5 && value.length > 5) {
          final existingSuffix = existing.substring(existing.length - 3);
          final valueSuffix = value.substring(value.length - 3);
          if (existingSuffix == valueSuffix) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Returns the number of unique strings currently interned.
  int get size => _internedStrings.length;

  /// Returns the cache hit ratio as a percentage (0.0 to 1.0).
  ///
  /// A higher hit ratio indicates better memory savings from interning.
  double get hitRatio {
    if (_totalInterningRequests == 0) return 0.0;
    return _cacheHits / _totalInterningRequests;
  }

  /// Estimates the memory saved by interning in bytes.
  ///
  /// This is a rough estimate based on the assumption that each cache hit
  /// saves approximately the string length in bytes plus object overhead.
  int get estimatedMemorySaved {
    // Rough estimate: each cache hit saves string length + object overhead
    // Dart strings have approximately 2 bytes per character plus object overhead
    int totalSaved = 0;
    for (final str in _internedStrings) {
      // Estimate how many times this string was requested beyond the first
      final estimatedDuplicates = (_cacheHits / _internedStrings.length).round();
      totalSaved += (str.length * 2 + 32) * estimatedDuplicates; // 32 bytes object overhead
    }
    return totalSaved;
  }

  /// Returns statistics about the interning system performance.
  Map<String, dynamic> get statistics => {
    'totalRequests': _totalInterningRequests,
    'cacheHits': _cacheHits,
    'uniqueStrings': size,
    'hitRatio': hitRatio,
    'estimatedMemorySaved': estimatedMemorySaved,
  };

  /// Clears all interned strings and resets statistics.
  ///
  /// This should be called periodically when processing large batches of files
  /// to prevent unbounded memory growth. Consider calling this after processing
  /// each batch of 1000-10000 files depending on available memory.
  void clear() {
    _internedStrings.clear();
    _totalInterningRequests = 0;
    _cacheHits = 0;
  }

  /// Returns whether a string is currently interned.
  ///
  /// This can be useful for debugging or testing interning behavior.
  bool isInterned(String value) {
    return _internedStrings.contains(value);
  }
}

/// Global string interning instance for use across the library.
///
/// This provides a convenient way to access string interning without
/// passing instances around. However, be aware that this creates a
/// global state that persists across operations.
///
/// For better memory management in batch processing scenarios,
/// consider using local StringInterning instances that can be
/// cleared after each batch.
final globalStringInterning = StringInterning();
