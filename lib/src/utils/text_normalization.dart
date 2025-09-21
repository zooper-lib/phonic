import '../core/tag_semantics.dart';
import '../core/text_encoding.dart';
import 'text_encoding_utils.dart';

/// Utilities for text normalization and constraint handling.
///
/// This class provides methods for normalizing text content according to
/// container-specific constraints, encoding requirements, and format conventions.
/// It handles length limits, encoding compatibility, case normalization, and
/// whitespace trimming.
///
/// Usage:
/// ```dart
/// // Basic text normalization with length constraint
/// final normalized = TextNormalization.normalizeText(
///   'Very long title that exceeds limits',
///   maxLength: 30,
/// );
///
/// // Normalize for specific container constraints
/// final semantics = TagSemantics(maxTextLength: 30);
/// final constrained = TextNormalization.normalizeForConstraints(
///   'Long text',
///   semantics,
/// );
///
/// // Vorbis comment key normalization
/// final vorbisKey = TextNormalization.normalizeVorbisKey('Artist');
/// // Returns: 'ARTIST'
///
/// // Encoding-aware normalization
/// final latin1Safe = TextNormalization.normalizeForEncoding(
///   'Text with émojis 🎵',
///   TextEncoding.iso88591,
/// );
/// ```
class TextNormalization {
  /// Normalizes text content with basic trimming and optional length constraint.
  ///
  /// This method performs standard text normalization:
  /// - Trims leading and trailing whitespace
  /// - Normalizes internal whitespace (multiple spaces become single space)
  /// - Applies length truncation if specified
  /// - Preserves Unicode characters unless encoding constraints apply
  ///
  /// Parameters:
  /// - [text]: The input text to normalize
  /// - [maxLength]: Optional maximum length for truncation
  /// - [preserveWords]: If true, truncates at word boundaries when possible
  ///
  /// Returns the normalized text.
  ///
  /// Example:
  /// ```dart
  /// final result = TextNormalization.normalizeText(
  ///   '  Multiple   spaces   text  ',
  ///   maxLength: 20,
  /// );
  /// // Returns: 'Multiple spaces text'
  /// ```
  static String normalizeText(
    String text, {
    int? maxLength,
    bool preserveWords = false,
  }) {
    if (text.isEmpty) return text;

    // Trim leading and trailing whitespace
    String normalized = text.trim();

    // Normalize internal whitespace (collapse multiple spaces)
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Apply length constraint if specified
    if (maxLength != null && normalized.length > maxLength) {
      normalized = _truncateText(normalized, maxLength, preserveWords);
    }

    return normalized;
  }

  /// Normalizes text according to tag semantics constraints.
  ///
  /// This method applies normalization based on the semantic constraints
  /// defined for a specific tag type. It handles:
  /// - Maximum text length constraints
  /// - Encoding compatibility requirements
  /// - Format-specific normalization rules
  ///
  /// Parameters:
  /// - [text]: The input text to normalize
  /// - [semantics]: Tag semantics defining constraints
  /// - [preserveWords]: If true, truncates at word boundaries when possible
  ///
  /// Returns the normalized text that conforms to the constraints.
  ///
  /// Example:
  /// ```dart
  /// final semantics = TagSemantics(
  ///   maxTextLength: 30,
  ///   allowedEncodings: {'iso-8859-1'},
  /// );
  /// final result = TextNormalization.normalizeForConstraints(
  ///   'Long text with special characters',
  ///   semantics,
  /// );
  /// ```
  static String normalizeForConstraints(
    String text,
    TagSemantics semantics, {
    bool preserveWords = false,
  }) {
    String normalized = normalizeText(text);

    // Apply length constraint from semantics
    if (semantics.maxTextLength != null && normalized.length > semantics.maxTextLength!) {
      normalized = _truncateText(normalized, semantics.maxTextLength!, preserveWords);
    }

    // Apply encoding constraints if specified
    if (semantics.allowedEncodings != null && semantics.allowedEncodings!.isNotEmpty) {
      // Find the most restrictive encoding that's allowed
      final allowedEncodings = semantics.allowedEncodings!;

      if (allowedEncodings.contains('ASCII')) {
        normalized = normalizeForEncoding(normalized, TextEncoding.ascii);
      } else if (allowedEncodings.contains('ISO-8859-1')) {
        normalized = normalizeForEncoding(normalized, TextEncoding.iso88591);
      }
      // UTF-8 and UTF-16 can handle all characters, so no normalization needed
    }

    return normalized;
  }

  /// Normalizes text for compatibility with a specific text encoding.
  ///
  /// This method ensures the text can be safely encoded in the target encoding
  /// by replacing or removing incompatible characters. It handles:
  /// - ASCII compatibility (removes non-ASCII characters)
  /// - ISO-8859-1 compatibility (removes characters outside Latin-1 range)
  /// - UTF encodings (no changes needed)
  ///
  /// Parameters:
  /// - [text]: The input text to normalize
  /// - [encoding]: Target text encoding
  /// - [replacementChar]: Character to use for incompatible characters (default: '?')
  ///
  /// Returns text compatible with the specified encoding.
  ///
  /// Example:
  /// ```dart
  /// final result = TextNormalization.normalizeForEncoding(
  ///   'Café with émojis 🎵',
  ///   TextEncoding.ascii,
  /// );
  /// // Returns: 'Caf? with ?mojis ?'
  /// ```
  static String normalizeForEncoding(
    String text,
    TextEncoding encoding, {
    String replacementChar = '?',
  }) {
    switch (encoding) {
      case TextEncoding.ascii:
        return _normalizeToAscii(text, replacementChar);

      case TextEncoding.iso88591:
        return _normalizeToLatin1(text, replacementChar);

      case TextEncoding.utf8:
      case TextEncoding.utf16:
      case TextEncoding.utf16le:
      case TextEncoding.utf16be:
        // UTF encodings can handle all Unicode characters
        return text;
    }
  }

  /// Normalizes a Vorbis comment key to standard format.
  ///
  /// Vorbis comment keys are case-insensitive but conventionally stored
  /// in uppercase. This method:
  /// - Converts to uppercase
  /// - Trims whitespace
  /// - Validates key format (letters, numbers, underscore only)
  ///
  /// Parameters:
  /// - [key]: The Vorbis comment key to normalize
  ///
  /// Returns the normalized key in uppercase format.
  ///
  /// Throws [ArgumentError] if the key contains invalid characters.
  ///
  /// Example:
  /// ```dart
  /// final normalized = TextNormalization.normalizeVorbisKey('artist');
  /// // Returns: 'ARTIST'
  ///
  /// final custom = TextNormalization.normalizeVorbisKey('my_custom_field');
  /// // Returns: 'MY_CUSTOM_FIELD'
  /// ```
  static String normalizeVorbisKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError('Vorbis comment key cannot be empty');
    }

    // Trim and convert to uppercase
    final normalized = key.trim().toUpperCase();

    // Validate key format - only letters, numbers, and underscores allowed
    if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(normalized)) {
      throw ArgumentError(
        'Invalid Vorbis comment key: "$key". '
        'Keys must contain only letters, numbers, and underscores.',
      );
    }

    return normalized;
  }

  /// Calculates the byte length of text when encoded in the specified encoding.
  ///
  /// This method is useful for checking length constraints before encoding,
  /// especially for multi-byte encodings where character count doesn't
  /// directly correspond to byte count.
  ///
  /// Parameters:
  /// - [text]: The text to measure
  /// - [encoding]: Target text encoding
  /// - [includeBom]: Whether to include BOM in the calculation
  ///
  /// Returns the byte length of the encoded text.
  ///
  /// Example:
  /// ```dart
  /// final byteLength = TextNormalization.getEncodedByteLength(
  ///   'Hello 世界',
  ///   TextEncoding.utf8,
  /// );
  /// // Returns: 11 (5 ASCII + 6 for Chinese characters)
  /// ```
  static int getEncodedByteLength(
    String text,
    TextEncoding encoding, {
    bool includeBom = false,
  }) {
    return TextEncodingUtils.getEncodedLength(text, encoding, includeBom: includeBom);
  }

  /// Truncates text to fit within a byte length constraint for a specific encoding.
  ///
  /// This method is particularly useful for formats with byte-based length limits
  /// rather than character-based limits. It ensures the truncated text can be
  /// safely encoded without exceeding the byte limit.
  ///
  /// Parameters:
  /// - [text]: The text to truncate
  /// - [maxBytes]: Maximum byte length allowed
  /// - [encoding]: Target text encoding
  /// - [preserveWords]: If true, truncates at word boundaries when possible
  ///
  /// Returns text that fits within the byte constraint.
  ///
  /// Example:
  /// ```dart
  /// final result = TextNormalization.truncateToByteLength(
  ///   'Hello 世界 from the world',
  ///   maxBytes: 15,
  ///   encoding: TextEncoding.utf8,
  /// );
  /// // Returns: 'Hello 世界' (exactly 11 bytes in UTF-8)
  /// ```
  static String truncateToByteLength(
    String text,
    int maxBytes,
    TextEncoding encoding, {
    bool preserveWords = false,
  }) {
    if (text.isEmpty || maxBytes <= 0) return '';

    // Quick check - if current text fits, return as-is
    if (getEncodedByteLength(text, encoding) <= maxBytes) {
      return text;
    }

    // Build result character by character to avoid breaking multi-byte sequences
    final buffer = StringBuffer();
    int currentBytes = 0;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final charBytes = getEncodedByteLength(char, encoding);

      if (currentBytes + charBytes <= maxBytes) {
        buffer.writeCharCode(rune);
        currentBytes += charBytes;
      } else {
        break;
      }
    }

    String result = buffer.toString();

    // If preserveWords is true, try to truncate at word boundary
    if (preserveWords && result.isNotEmpty) {
      final lastSpaceIndex = result.lastIndexOf(' ');
      if (lastSpaceIndex > 0 && lastSpaceIndex > result.length * 0.7) {
        // Only use word boundary if it doesn't remove too much text
        result = result.substring(0, lastSpaceIndex);
      }
    }

    return result;
  }

  /// Truncates text to the specified character length.
  ///
  /// Internal helper method that handles text truncation with optional
  /// word boundary preservation.
  static String _truncateText(String text, int maxLength, bool preserveWords) {
    if (text.length <= maxLength) return text;

    String truncated = text.substring(0, maxLength);

    if (preserveWords && truncated.isNotEmpty) {
      final lastSpaceIndex = truncated.lastIndexOf(' ');
      // Only use word boundary if it doesn't remove too much text (more than 30%)
      if (lastSpaceIndex > 0 && lastSpaceIndex > maxLength * 0.7) {
        truncated = truncated.substring(0, lastSpaceIndex);
      }
    }

    return truncated;
  }

  /// Normalizes text to ASCII-compatible format.
  ///
  /// Replaces non-ASCII characters with the specified replacement character.
  static String _normalizeToAscii(String text, String replacementChar) {
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      if (rune <= 127) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write(replacementChar);
      }
    }

    return buffer.toString();
  }

  /// Normalizes text to ISO-8859-1 (Latin-1) compatible format.
  ///
  /// Replaces characters outside the Latin-1 range with the specified replacement character.
  static String _normalizeToLatin1(String text, String replacementChar) {
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      if (rune <= 255) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write(replacementChar);
      }
    }

    return buffer.toString();
  }
}
