/// Text encoding enumeration for metadata containers.
///
/// This enum defines the standard character encodings supported by various
/// audio metadata formats. Using an enum provides better type safety and
/// IDE support compared to string constants.
///
/// Usage:
/// ```dart
/// // Check encoding support
/// if (semantics.supportsEncoding(TextEncoding.utf8)) {
///   // UTF-8 is supported
/// }
///
/// // Get encoding name
/// final encodingName = TextEncoding.iso88591.name;
/// ```
enum TextEncoding {
  /// ISO-8859-1 (Latin-1) encoding.
  ///
  /// This is the default encoding for ID3v1 and is supported by most
  /// ID3v2 versions. It covers Western European characters but has
  /// limited Unicode support.
  ///
  /// Used by:
  /// - ID3v1: Only supported encoding
  /// - ID3v2.3: Default encoding, always supported
  /// - ID3v2.4: Supported as fallback encoding
  iso88591('ISO-8859-1'),

  /// UTF-8 encoding.
  ///
  /// Unicode Transformation Format 8-bit is the most common Unicode
  /// encoding, supporting all Unicode characters with variable-length
  /// encoding (1-4 bytes per character).
  ///
  /// Used by:
  /// - ID3v2.4: Preferred encoding for text frames
  /// - Vorbis Comments: Only supported encoding
  /// - MP4: Standard encoding for text atoms
  /// - ID3v2.3: Not supported
  /// - ID3v1: Not supported
  utf8('UTF-8'),

  /// UTF-16 encoding (with BOM).
  ///
  /// Unicode Transformation Format 16-bit uses 2 or 4 bytes per character
  /// and includes a Byte Order Mark (BOM) to indicate endianness.
  ///
  /// Used by:
  /// - ID3v2.3: Primary Unicode encoding
  /// - ID3v2.4: Supported Unicode encoding
  /// - ID3v1: Not supported
  /// - Vorbis: Not supported (UTF-8 only)
  /// - MP4: Not commonly used (UTF-8 preferred)
  utf16('UTF-16'),

  /// UTF-16BE (Big Endian) encoding without BOM.
  ///
  /// UTF-16 with explicit big-endian byte order, used in some
  /// ID3v2 implementations that don't include a BOM.
  utf16be('UTF-16BE'),

  /// UTF-16LE (Little Endian) encoding without BOM.
  ///
  /// UTF-16 with explicit little-endian byte order, used in some
  /// ID3v2 implementations that don't include a BOM.
  utf16le('UTF-16LE'),

  /// ASCII encoding (7-bit).
  ///
  /// Basic ASCII character set (0-127), subset of ISO-8859-1.
  /// Rarely used directly but sometimes referenced for compatibility.
  ascii('ASCII');

  /// Creates a TextEncoding with the specified standard name.
  const TextEncoding(this.standardName);

  /// The standard name of this encoding (e.g., 'UTF-8', 'ISO-8859-1').
  ///
  /// This name follows the standard encoding names used by Dart's
  /// encoding libraries and is suitable for use with codec operations.
  final String standardName;

  /// Returns the standard name of this encoding.
  ///
  /// This is equivalent to accessing [standardName] directly but provides
  /// a more explicit method name for clarity.
  String get name => standardName;

  /// Returns a set of all encoding names as strings.
  ///
  /// This is useful for validation or when working with APIs that expect
  /// string-based encoding names.
  static Set<String> get allNames => values.map((e) => e.standardName).toSet();

  /// Finds a TextEncoding by its standard name.
  ///
  /// Returns the matching TextEncoding enum value, or null if no match is found.
  /// The comparison is case-sensitive.
  ///
  /// Example:
  /// ```dart
  /// final encoding = TextEncoding.fromName('UTF-8'); // Returns TextEncoding.utf8
  /// final invalid = TextEncoding.fromName('utf-8');  // Returns null (case sensitive)
  /// ```
  static TextEncoding? fromName(String name) {
    for (final encoding in values) {
      if (encoding.standardName == name) {
        return encoding;
      }
    }
    return null;
  }

  /// Returns true if this encoding supports Unicode characters.
  ///
  /// Unicode-capable encodings can represent the full range of Unicode
  /// characters, while legacy encodings like ISO-8859-1 are limited
  /// to specific character sets.
  bool get isUnicode {
    switch (this) {
      case TextEncoding.utf8:
      case TextEncoding.utf16:
      case TextEncoding.utf16be:
      case TextEncoding.utf16le:
        return true;
      case TextEncoding.iso88591:
      case TextEncoding.ascii:
        return false;
    }
  }

  /// Returns true if this encoding uses variable-length character representation.
  ///
  /// Variable-length encodings like UTF-8 use different numbers of bytes
  /// for different characters, while fixed-length encodings use the same
  /// number of bytes for all characters in their supported range.
  bool get isVariableLength {
    switch (this) {
      case TextEncoding.utf8:
        return true;
      case TextEncoding.utf16:
      case TextEncoding.utf16be:
      case TextEncoding.utf16le:
      case TextEncoding.iso88591:
      case TextEncoding.ascii:
        return false;
    }
  }

  @override
  String toString() => standardName;
}
