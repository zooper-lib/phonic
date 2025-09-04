import 'dart:convert';
import 'dart:typed_data';

import '../core/text_encoding.dart';

/// Utilities for text encoding detection and conversion.
///
/// This class provides methods for detecting character encodings in byte data
/// and converting text between different encodings. It handles BOM (Byte Order Mark)
/// detection for UTF-16 and provides robust encoding detection for common
/// metadata formats.
///
/// Usage:
/// ```dart
/// // Detect encoding from bytes
/// final bytes = utf8.encode('Hello World');
/// final encoding = TextEncodingUtils.detectEncoding(bytes);
///
/// // Convert between encodings
/// final utf16Bytes = TextEncodingUtils.convertEncoding(
///   'Hello World',
///   from: TextEncoding.utf8,
///   to: TextEncoding.utf16,
/// );
///
/// // Decode with automatic encoding detection
/// final text = TextEncodingUtils.decodeWithDetection(bytes);
/// ```
class TextEncodingUtils {
  /// UTF-16 Big Endian BOM (Byte Order Mark).
  static const List<int> utf16BeBom = [0xFE, 0xFF];

  /// UTF-16 Little Endian BOM (Byte Order Mark).
  static const List<int> utf16LeBom = [0xFF, 0xFE];

  /// UTF-8 BOM (Byte Order Mark).
  static const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

  /// Detects the text encoding of the given byte data.
  ///
  /// This method analyzes the byte sequence to determine the most likely
  /// character encoding. It checks for:
  /// 1. BOM (Byte Order Mark) presence for UTF-16 and UTF-8
  /// 2. UTF-8 byte sequence patterns
  /// 3. Falls back to ISO-8859-1 for other cases
  ///
  /// Returns the detected [TextEncoding], or [TextEncoding.iso88591] as fallback.
  ///
  /// Example:
  /// ```dart
  /// final utf8Bytes = utf8.encode('Hello 世界');
  /// final encoding = TextEncodingUtils.detectEncoding(utf8Bytes);
  /// // Returns TextEncoding.utf8
  /// ```
  static TextEncoding detectEncoding(Uint8List bytes) {
    if (bytes.isEmpty) {
      return TextEncoding.iso88591;
    }

    // Check for BOM first
    final bomEncoding = _detectBom(bytes);
    if (bomEncoding != null) {
      return bomEncoding;
    }

    // Check for UTF-16 without BOM first (before UTF-8) since UTF-16 with ASCII
    // characters can also be valid UTF-8
    if (_looksLikeUtf16(bytes)) {
      // Default to UTF-16LE as it's more common on little-endian systems
      return TextEncoding.utf16le;
    }

    // Check for UTF-8 patterns
    if (_isValidUtf8(bytes)) {
      return TextEncoding.utf8;
    }

    // Default to ISO-8859-1 (Latin-1) for compatibility
    return TextEncoding.iso88591;
  }

  /// Detects BOM (Byte Order Mark) in the byte data.
  ///
  /// Returns the corresponding [TextEncoding] if a BOM is found,
  /// or null if no BOM is detected.
  static TextEncoding? _detectBom(Uint8List bytes) {
    if (bytes.length >= 3 && _startsWith(bytes, utf8Bom)) {
      return TextEncoding.utf8;
    }

    if (bytes.length >= 2) {
      if (_startsWith(bytes, utf16BeBom)) {
        return TextEncoding.utf16be;
      }
      if (_startsWith(bytes, utf16LeBom)) {
        return TextEncoding.utf16le;
      }
    }

    return null;
  }

  /// Checks if the byte sequence starts with the given pattern.
  static bool _startsWith(Uint8List bytes, List<int> pattern) {
    if (bytes.length < pattern.length) return false;

    for (int i = 0; i < pattern.length; i++) {
      if (bytes[i] != pattern[i]) return false;
    }

    return true;
  }

  /// Validates if the byte sequence is valid UTF-8.
  ///
  /// This method checks UTF-8 byte sequence patterns according to the
  /// UTF-8 specification. It validates:
  /// - Single-byte characters (0xxxxxxx)
  /// - Multi-byte sequences (110xxxxx, 1110xxxx, 11110xxx)
  /// - Continuation bytes (10xxxxxx)
  static bool _isValidUtf8(Uint8List bytes) {
    int i = 0;

    while (i < bytes.length) {
      final byte = bytes[i];

      if (byte < 0x80) {
        // Single-byte character (0xxxxxxx)
        i++;
      } else if ((byte & 0xE0) == 0xC0) {
        // Two-byte sequence (110xxxxx 10xxxxxx)
        if (i + 1 >= bytes.length) return false;
        if ((bytes[i + 1] & 0xC0) != 0x80) return false;
        i += 2;
      } else if ((byte & 0xF0) == 0xE0) {
        // Three-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
        if (i + 2 >= bytes.length) return false;
        if ((bytes[i + 1] & 0xC0) != 0x80) return false;
        if ((bytes[i + 2] & 0xC0) != 0x80) return false;
        i += 3;
      } else if ((byte & 0xF8) == 0xF0) {
        // Four-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
        if (i + 3 >= bytes.length) return false;
        if ((bytes[i + 1] & 0xC0) != 0x80) return false;
        if ((bytes[i + 2] & 0xC0) != 0x80) return false;
        if ((bytes[i + 3] & 0xC0) != 0x80) return false;
        i += 4;
      } else {
        // Invalid UTF-8 start byte
        return false;
      }
    }

    return true;
  }

  /// Checks if the byte sequence looks like UTF-16 encoding.
  ///
  /// This heuristic looks for patterns typical of UTF-16:
  /// - Alternating null bytes (for ASCII text in UTF-16)
  /// - Even length (UTF-16 uses 2-byte units)
  static bool _looksLikeUtf16(Uint8List bytes) {
    if (bytes.length < 4 || bytes.length % 2 != 0) {
      return false;
    }

    // Count null bytes and their positions
    int nullCount = 0;
    int evenNulls = 0;
    int oddNulls = 0;

    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        nullCount++;
        if (i % 2 == 0) {
          evenNulls++;
        } else {
          oddNulls++;
        }
      }
    }

    // If we have a significant number of null bytes in a pattern,
    // it's likely UTF-16
    final nullRatio = nullCount / bytes.length;

    // Look for alternating null pattern (common in ASCII text encoded as UTF-16)
    // Need at least 40% null bytes and a clear alternating pattern
    if (nullRatio >= 0.4 && (evenNulls > oddNulls * 3 || oddNulls > evenNulls * 3)) {
      return true;
    }

    return false;
  }

  /// Converts text from one encoding to another.
  ///
  /// This method encodes the input text using the source encoding,
  /// then decodes it using the target encoding.
  ///
  /// Parameters:
  /// - [text]: The input text to convert
  /// - [from]: Source text encoding
  /// - [to]: Target text encoding
  /// - [includeBom]: Whether to include BOM for UTF-16 output (default: true)
  ///
  /// Returns the converted text as bytes.
  ///
  /// Example:
  /// ```dart
  /// final utf16Bytes = TextEncodingUtils.convertEncoding(
  ///   'Hello World',
  ///   from: TextEncoding.utf8,
  ///   to: TextEncoding.utf16le,
  /// );
  /// ```
  static Uint8List convertEncoding(
    String text, {
    required TextEncoding from,
    required TextEncoding to,
    bool includeBom = true,
  }) {
    // If converting to the same encoding, just encode directly
    if (from == to) {
      return encodeText(text, to, includeBom: includeBom);
    }

    // For conversion, we assume the input text is already properly decoded
    // and just need to encode it in the target encoding
    return encodeText(text, to, includeBom: includeBom);
  }

  /// Encodes text using the specified encoding.
  ///
  /// Parameters:
  /// - [text]: The text to encode
  /// - [encoding]: Target text encoding
  /// - [includeBom]: Whether to include BOM for UTF-16 (default: true)
  ///
  /// Returns the encoded text as bytes.
  static Uint8List encodeText(
    String text,
    TextEncoding encoding, {
    bool includeBom = true,
  }) {
    List<int> bytes;

    switch (encoding) {
      case TextEncoding.utf8:
        bytes = utf8.encode(text);
        if (includeBom) {
          bytes = [...utf8Bom, ...bytes];
        }
        break;

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
        bytes = _encodeUtf16Le(text);
        if (includeBom) {
          bytes = [...utf16LeBom, ...bytes];
        }
        break;

      case TextEncoding.utf16be:
        bytes = _encodeUtf16Be(text);
        if (includeBom) {
          bytes = [...utf16BeBom, ...bytes];
        }
        break;

      case TextEncoding.iso88591:
        bytes = latin1.encode(text);
        break;

      case TextEncoding.ascii:
        bytes = ascii.encode(text);
        break;
    }

    return Uint8List.fromList(bytes);
  }

  /// Decodes bytes using the specified encoding.
  ///
  /// Parameters:
  /// - [bytes]: The bytes to decode
  /// - [encoding]: Source text encoding
  /// - [removeBom]: Whether to remove BOM if present (default: true)
  ///
  /// Returns the decoded text.
  static String decodeText(
    Uint8List bytes,
    TextEncoding encoding, {
    bool removeBom = true,
  }) {
    Uint8List processedBytes = bytes;

    // Remove BOM if requested and present
    if (removeBom) {
      processedBytes = _removeBom(bytes, encoding);
    }

    switch (encoding) {
      case TextEncoding.utf8:
        return utf8.decode(processedBytes);

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
        return _decodeUtf16Le(processedBytes);

      case TextEncoding.utf16be:
        return _decodeUtf16Be(processedBytes);

      case TextEncoding.iso88591:
        return latin1.decode(processedBytes);

      case TextEncoding.ascii:
        return ascii.decode(processedBytes);
    }
  }

  /// Decodes bytes with automatic encoding detection.
  ///
  /// This method first detects the encoding using [detectEncoding],
  /// then decodes the text using the detected encoding.
  ///
  /// Returns the decoded text.
  static String decodeWithDetection(Uint8List bytes) {
    final encoding = detectEncoding(bytes);
    return decodeText(bytes, encoding);
  }

  /// Removes BOM from the beginning of byte data if present.
  static Uint8List _removeBom(Uint8List bytes, TextEncoding encoding) {
    switch (encoding) {
      case TextEncoding.utf8:
        if (_startsWith(bytes, utf8Bom)) {
          return bytes.sublist(utf8Bom.length);
        }
        break;

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
        if (_startsWith(bytes, utf16LeBom)) {
          return bytes.sublist(utf16LeBom.length);
        }
        break;

      case TextEncoding.utf16be:
        if (_startsWith(bytes, utf16BeBom)) {
          return bytes.sublist(utf16BeBom.length);
        }
        break;

      case TextEncoding.iso88591:
      case TextEncoding.ascii:
        // These encodings don't use BOM
        break;
    }

    return bytes;
  }

  /// Encodes text as UTF-16 Little Endian.
  static List<int> _encodeUtf16Le(String text) {
    final codeUnits = text.codeUnits;
    final bytes = <int>[];

    for (final codeUnit in codeUnits) {
      // UTF-16 LE: low byte first, high byte second
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }

    return bytes;
  }

  /// Encodes text as UTF-16 Big Endian.
  static List<int> _encodeUtf16Be(String text) {
    final codeUnits = text.codeUnits;
    final bytes = <int>[];

    for (final codeUnit in codeUnits) {
      // UTF-16 BE: high byte first, low byte second
      bytes.add((codeUnit >> 8) & 0xFF);
      bytes.add(codeUnit & 0xFF);
    }

    return bytes;
  }

  /// Decodes UTF-16 Little Endian bytes to text.
  static String _decodeUtf16Le(Uint8List bytes) {
    if (bytes.length % 2 != 0) {
      throw ArgumentError('UTF-16 byte array must have even length');
    }

    final codeUnits = <int>[];

    for (int i = 0; i < bytes.length; i += 2) {
      // UTF-16 LE: low byte first, high byte second
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      codeUnits.add(codeUnit);
    }

    return String.fromCharCodes(codeUnits);
  }

  /// Decodes UTF-16 Big Endian bytes to text.
  static String _decodeUtf16Be(Uint8List bytes) {
    if (bytes.length % 2 != 0) {
      throw ArgumentError('UTF-16 byte array must have even length');
    }

    final codeUnits = <int>[];

    for (int i = 0; i < bytes.length; i += 2) {
      // UTF-16 BE: high byte first, low byte second
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      codeUnits.add(codeUnit);
    }

    return String.fromCharCodes(codeUnits);
  }

  /// Checks if the given text can be encoded in the specified encoding.
  ///
  /// This method attempts to encode the text and returns true if successful,
  /// false if the encoding would result in data loss or errors.
  static bool canEncode(String text, TextEncoding encoding) {
    try {
      switch (encoding) {
        case TextEncoding.utf8:
        case TextEncoding.utf16:
        case TextEncoding.utf16le:
        case TextEncoding.utf16be:
          // UTF encodings can handle all Unicode characters
          return true;

        case TextEncoding.iso88591:
          // Check if all characters are in Latin-1 range (0-255)
          return text.codeUnits.every((codeUnit) => codeUnit <= 255);

        case TextEncoding.ascii:
          // Check if all characters are in ASCII range (0-127)
          return text.codeUnits.every((codeUnit) => codeUnit <= 127);
      }
    } catch (e) {
      return false;
    }
  }

  /// Returns the byte length of text when encoded in the specified encoding.
  ///
  /// This is useful for calculating buffer sizes or checking length constraints
  /// without actually performing the encoding.
  static int getEncodedLength(String text, TextEncoding encoding, {bool includeBom = false}) {
    int baseLength;

    switch (encoding) {
      case TextEncoding.utf8:
        baseLength = utf8.encode(text).length;
        if (includeBom) baseLength += utf8Bom.length;
        break;

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
      case TextEncoding.utf16be:
        baseLength = text.length * 2; // 2 bytes per character for BMP characters
        if (includeBom) baseLength += 2;
        break;

      case TextEncoding.iso88591:
      case TextEncoding.ascii:
        baseLength = text.length; // 1 byte per character
        break;
    }

    return baseLength;
  }
}
