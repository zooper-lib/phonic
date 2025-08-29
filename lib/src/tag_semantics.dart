import 'text_encoding.dart';

/// Defines the semantic constraints and capabilities for a specific tag field
/// within a particular container format.
///
/// [TagSemantics] encapsulates the rules and limitations that apply to a
/// metadata tag field in a specific container format. This includes whether
/// the field supports multiple values, text length restrictions, numeric
/// value ranges, and encoding constraints.
///
/// This class is used by the capability system to validate tag values before
/// writing and to normalize values when reading from different container formats.
///
/// Example usage:
/// ```dart
/// // Define semantics for ID3v1 title field (30 character limit)
/// const id3v1TitleSemantics = TagSemantics(
///   maxTextLength: 30,
///   multiValued: false,
/// );
///
/// // Define semantics for Vorbis genre field (supports multiple values)
/// const vorbisGenreSemantics = TagSemantics(
///   multiValued: true,
///   allowedEncodings: {TextEncoding.utf8.standardName},
/// );
///
/// // Define semantics for ID3v2 rating field (0-255 range)
/// const id3v2RatingSemantics = TagSemantics(
///   minValue: 0,
///   maxValue: 255,
///   multiValued: false,
/// );
/// ```
class TagSemantics {
  /// Whether this tag field supports multiple values.
  ///
  /// When `true`, the field can contain multiple distinct values (e.g.,
  /// multiple genre entries in Vorbis comments). When `false`, only a
  /// single value is supported, though that value may contain multiple
  /// items encoded within it (e.g., slash-separated genres in ID3v2.3).
  ///
  /// Examples:
  /// - Vorbis GENRE field: `multiValued = true` (multiple GENRE= entries)
  /// - ID3v2 TCON frame: `multiValued = false` (single frame with encoded content)
  final bool multiValued;

  /// Maximum allowed length for text-based tag values.
  ///
  /// Specifies the maximum number of characters allowed in text fields.
  /// This constraint is particularly important for legacy formats like
  /// ID3v1 which have strict length limitations. When `null`, no length
  /// restriction is enforced.
  ///
  /// Examples:
  /// - ID3v1 title: `maxTextLength = 30`
  /// - ID3v1 comment with track: `maxTextLength = 28`
  /// - ID3v2/Vorbis fields: `maxTextLength = null` (no practical limit)
  final int? maxTextLength;

  /// Minimum allowed value for numeric tag fields.
  ///
  /// Defines the lower bound for numeric values such as track numbers,
  /// ratings, or BPM values. When `null`, no minimum constraint is enforced.
  /// This is used for validation before writing tags to ensure values
  /// fall within the supported range for the target format.
  ///
  /// Examples:
  /// - Track number: `minValue = 1`
  /// - Rating: `minValue = 0`
  /// - BPM: `minValue = 1`
  final num? minValue;

  /// Maximum allowed value for numeric tag fields.
  ///
  /// Defines the upper bound for numeric values. This is particularly
  /// important for formats with limited numeric ranges, such as ID3v1
  /// track numbers (1-255) or ID3v2 POPM ratings (0-255). When `null`,
  /// no maximum constraint is enforced.
  ///
  /// Examples:
  /// - ID3v1 track number: `maxValue = 255`
  /// - ID3v2 POMP rating: `maxValue = 255`
  /// - Unified rating scale: `maxValue = 100`
  final num? maxValue;

  /// Set of allowed text encodings for this field.
  ///
  /// Specifies which character encodings are supported by the container
  /// format for this field. This is used to determine appropriate encoding
  /// when writing tags and to handle encoding detection when reading.
  /// When `null`, no encoding restrictions are enforced.
  ///
  /// Common encoding sets:
  /// - ID3v2.3: `{TextEncoding.iso88591.standardName, TextEncoding.utf16.standardName}`
  /// - ID3v2.4: `{TextEncoding.iso88591.standardName, TextEncoding.utf16.standardName, TextEncoding.utf8.standardName}`
  /// - Vorbis: `{TextEncoding.utf8.standardName}`
  /// - MP4: `{TextEncoding.utf8.standardName}`
  final Set<String>? allowedEncodings;

  /// Creates a new [TagSemantics] instance with the specified constraints.
  ///
  /// All parameters are optional and default to permissive values:
  /// - [multiValued] defaults to `false` (single value)
  /// - [maxTextLength] defaults to `null` (no length limit)
  /// - [minValue] defaults to `null` (no minimum)
  /// - [maxValue] defaults to `null` (no maximum)
  /// - [allowedEncodings] defaults to `null` (no encoding restrictions)
  ///
  /// Example:
  /// ```dart
  /// // Permissive semantics (no restrictions)
  /// const openSemantics = TagSemantics();
  ///
  /// // Restrictive semantics for ID3v1 text field
  /// const id3v1Semantics = TagSemantics(
  ///   maxTextLength: 30,
  ///   allowedEncodings: {TextEncoding.iso88591.standardName},
  /// );
  ///
  /// // Multi-valued field with UTF-8 encoding
  /// const vorbisSemantics = TagSemantics(
  ///   multiValued: true,
  ///   allowedEncodings: {TextEncoding.utf8.standardName},
  /// );
  /// ```
  const TagSemantics({
    this.multiValued = false,
    this.maxTextLength,
    this.minValue,
    this.maxValue,
    this.allowedEncodings,
  });

  /// Returns `true` if this field has any text length restrictions.
  bool get hasTextLengthLimit => maxTextLength != null;

  /// Returns `true` if this field has numeric value range restrictions.
  bool get hasValueRange => minValue != null || maxValue != null;

  /// Returns `true` if this field has encoding restrictions.
  bool get hasEncodingRestrictions => allowedEncodings != null;

  /// Returns `true` if this field has any constraints defined.
  bool get hasConstraints => hasTextLengthLimit || hasValueRange || hasEncodingRestrictions || multiValued;

  /// Validates whether the given text length is within the allowed limit.
  ///
  /// Returns `true` if [length] is within the [maxTextLength] constraint,
  /// or if no length limit is defined. Returns `false` if the length
  /// exceeds the maximum allowed length.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(maxTextLength: 30);
  /// print(semantics.isValidTextLength(25)); // true
  /// print(semantics.isValidTextLength(35)); // false
  /// ```
  bool isValidTextLength(int length) {
    return maxTextLength == null || length <= maxTextLength!;
  }

  /// Validates whether the given numeric value is within the allowed range.
  ///
  /// Returns `true` if [value] falls within the [minValue] and [maxValue]
  /// constraints, or if no range constraints are defined. Returns `false`
  /// if the value is outside the allowed range.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(minValue: 0, maxValue: 100);
  /// print(semantics.isValidValue(50));  // true
  /// print(semantics.isValidValue(-5)); // false
  /// print(semantics.isValidValue(150)); // false
  /// ```
  bool isValidValue(num value) {
    if (minValue != null && value < minValue!) return false;
    if (maxValue != null && value > maxValue!) return false;
    return true;
  }

  /// Validates whether the given encoding is allowed for this field.
  ///
  /// Returns `true` if [encoding] is in the [allowedEncodings] set,
  /// or if no encoding restrictions are defined. Returns `false` if
  /// the encoding is not allowed.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(allowedEncodings: {
  ///   TextEncoding.utf8.standardName,
  ///   TextEncoding.utf16.standardName
  /// });
  /// print(semantics.isValidEncoding(TextEncoding.utf8.standardName));     // true
  /// print(semantics.isValidEncoding(TextEncoding.iso88591.standardName)); // false
  /// ```
  bool isValidEncoding(String encoding) {
    return allowedEncodings == null || allowedEncodings!.contains(encoding);
  }

  /// Validates whether the given [TextEncoding] is allowed for this field.
  ///
  /// This is a convenience method that works with the [TextEncoding] enum
  /// instead of raw strings. Returns `true` if the encoding's standard name
  /// is in the [allowedEncodings] set, or if no encoding restrictions are defined.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(allowedEncodings: {
  ///   TextEncoding.utf8.standardName,
  ///   TextEncoding.utf16.standardName
  /// });
  /// print(semantics.supportsEncoding(TextEncoding.utf8));     // true
  /// print(semantics.supportsEncoding(TextEncoding.iso88591)); // false
  /// ```
  bool supportsEncoding(TextEncoding encoding) {
    return isValidEncoding(encoding.standardName);
  }

  /// Clamps the given numeric value to fit within the allowed range.
  ///
  /// If [value] is below [minValue], returns [minValue].
  /// If [value] is above [maxValue], returns [maxValue].
  /// Otherwise, returns [value] unchanged.
  ///
  /// If no range constraints are defined, returns [value] unchanged.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(minValue: 0, maxValue: 100);
  /// print(semantics.clampValue(-10)); // 0
  /// print(semantics.clampValue(50));  // 50
  /// print(semantics.clampValue(150)); // 100
  /// ```
  num clampValue(num value) {
    num result = value;
    if (minValue != null && result < minValue!) result = minValue!;
    if (maxValue != null && result > maxValue!) result = maxValue!;
    return result;
  }

  /// Truncates the given text to fit within the maximum length constraint.
  ///
  /// If [text] exceeds [maxTextLength], returns a substring of the first
  /// [maxTextLength] characters. Otherwise, returns [text] unchanged.
  ///
  /// If no length constraint is defined, returns [text] unchanged.
  ///
  /// Note: This method counts Unicode code units, not grapheme clusters.
  /// For proper Unicode handling with complex characters, consider using
  /// a more sophisticated text processing library.
  ///
  /// Example:
  /// ```dart
  /// const semantics = TagSemantics(maxTextLength: 10);
  /// print(semantics.truncateText('Hello World!')); // 'Hello Worl'
  /// print(semantics.truncateText('Short'));        // 'Short'
  /// ```
  String truncateText(String text) {
    if (maxTextLength == null || text.length <= maxTextLength!) {
      return text;
    }
    return text.substring(0, maxTextLength!);
  }

  @override
  String toString() {
    final constraints = <String>[];

    if (multiValued) constraints.add('multiValued');
    if (maxTextLength != null) constraints.add('maxLength: $maxTextLength');
    if (minValue != null) constraints.add('minValue: $minValue');
    if (maxValue != null) constraints.add('maxValue: $maxValue');
    if (allowedEncodings != null) {
      constraints.add('encodings: {${allowedEncodings!.join(', ')}}');
    }

    if (constraints.isEmpty) {
      return 'TagSemantics(no constraints)';
    }

    return 'TagSemantics(${constraints.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TagSemantics) return false;

    return multiValued == other.multiValued &&
        maxTextLength == other.maxTextLength &&
        minValue == other.minValue &&
        maxValue == other.maxValue &&
        _setEquals(allowedEncodings, other.allowedEncodings);
  }

  @override
  int get hashCode {
    // Create a consistent hash for sets by sorting elements
    int? encodingsHash;
    if (allowedEncodings != null) {
      final sortedEncodings = allowedEncodings!.toList()..sort();
      encodingsHash = Object.hashAll(sortedEncodings);
    }

    return Object.hash(
      multiValued,
      maxTextLength,
      minValue,
      maxValue,
      encodingsHash,
    );
  }

  /// Helper method to compare two sets for equality, handling null values.
  static bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
