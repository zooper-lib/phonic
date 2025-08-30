import 'dart:typed_data';

import '../../core/text_encoding.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';
import '../../utils/text_encoding_utils.dart';

/// Utilities for parsing ID3v2 COMM (Comment) frames.
///
/// COMM frames contain comment information with the following structure:
/// - Text encoding (1 byte)
/// - Language (3 bytes, ISO 639-2 language code)
/// - Short content description (null-terminated string in specified encoding)
/// - The actual text (string in specified encoding, not null-terminated)
///
/// ## ID3v2 COMM Frame Structure
///
/// ```
/// Offset  Length      Description
/// 0       1           Text encoding ($00 = ISO-8859-1, $01 = UTF-16, $02 = UTF-16BE, $03 = UTF-8)
/// 1       3           Language (ISO 639-2 language code, e.g., "eng", "fre")
/// 4       Variable    Short content description (null-terminated string in specified encoding)
/// N       Variable    The actual text (string in specified encoding, not null-terminated)
/// ```
///
/// ## Text Encoding Support
///
/// COMM frames support different text encodings for both description and text fields:
/// - ID3v2.2/2.3: ISO-8859-1 ($00) and UTF-16 with BOM ($01)
/// - ID3v2.4: Additionally supports UTF-16BE ($02) and UTF-8 ($03)
///
/// ## Language Codes
///
/// The language field uses ISO 639-2 three-character language codes:
/// - "eng" for English
/// - "fre" for French
/// - "ger" for German
/// - "spa" for Spanish
/// - "xxx" for unknown/unspecified language
///
/// ## Content Description
///
/// The short content description field allows multiple COMM frames to coexist
/// with different purposes (e.g., "Album Notes", "Track Info", "Lyrics").
/// An empty description is allowed and common for general comments.
///
/// ## Example Usage
///
/// ```dart
/// final frameData = Uint8List.fromList([
///   0x03,                           // UTF-8 encoding
///   0x65, 0x6E, 0x67,               // "eng" (English)
///   0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x4E, 0x6F, 0x74, 0x65, 0x73, 0x00, // "Album Notes\0"
///   0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x67, 0x72, 0x65, 0x61, 0x74, 0x20, 0x61, 0x6C, 0x62, 0x75, 0x6D, // "This is a great album"
/// ]);
///
/// final comm = Id3v2CommFrameParser.parse(frameData, 4);
/// print('Language: ${comm.language}');
/// print('Description: ${comm.description}');
/// print('Text: ${comm.text}');
/// ```

/// Result of parsing COMM (Comment) frame data.
class Id3v2CommFrameData {
  /// The comment text content.
  final String text;

  /// The ISO 639-2 language code (3 characters).
  final String language;

  /// The short content description.
  final String description;

  /// The text encoding used in the frame.
  final TextEncoding encoding;

  /// The raw encoding byte from the frame.
  final int encodingByte;

  /// Creates COMM frame data with the specified properties.
  const Id3v2CommFrameData({
    required this.text,
    required this.language,
    required this.description,
    required this.encoding,
    required this.encodingByte,
  });

  @override
  String toString() {
    return 'Id3v2CommFrameData(text: "$text", language: "$language", '
        'description: "$description", encoding: $encoding)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2CommFrameData &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          language == other.language &&
          description == other.description &&
          encoding == other.encoding &&
          encodingByte == other.encodingByte;

  @override
  int get hashCode => Object.hash(text, language, description, encoding, encodingByte);
}

/// Parser for ID3v2 COMM (Comment) frames.
class Id3v2CommFrameParser {
  /// Parses a COMM (Comment) frame from frame data.
  ///
  /// COMM frames contain comment information with the following structure:
  /// - Text encoding (1 byte)
  /// - Language (3 bytes, ISO 639-2 language code)
  /// - Short content description (null-terminated string in specified encoding)
  /// - The actual text (string in specified encoding, not null-terminated)
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4) for encoding validation
  ///
  /// ## Returns
  /// An [Id3v2CommFrameData] object containing the parsed comment information
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is too short for a valid COMM frame
  /// - [CorruptedContainerException] if the frame format is invalid
  /// - [FormatException] if the encoding byte is invalid for the version
  ///
  /// ## Example
  /// ```dart
  /// final commData = Uint8List.fromList([
  ///   0x03,                           // UTF-8 encoding
  ///   0x65, 0x6E, 0x67,               // "eng" (English)
  ///   0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x4E, 0x6F, 0x74, 0x65, 0x73, 0x00, // "Album Notes\0"
  ///   0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x67, 0x72, 0x65, 0x61, 0x74, 0x20, 0x61, 0x6C, 0x62, 0x75, 0x6D, // "This is a great album"
  /// ]);
  /// final comm = Id3v2CommFrameParser.parse(commData, 4);
  /// print('Language: ${comm.language}'); // "eng"
  /// print('Description: ${comm.description}'); // "Album Notes"
  /// print('Text: ${comm.text}'); // "This is a great album"
  /// ```
  static Id3v2CommFrameData parse(Uint8List frameData, int majorVersion) {
    if (frameData.length < 5) {
      throw ArgumentError.value(
        frameData.length,
        'frameData.length',
        'COMM frame data must be at least 5 bytes (encoding + language + description + text)',
      );
    }

    final reader = ByteReader(frameData);

    // Parse text encoding byte
    final encodingByte = reader.readUint8();
    final encoding = _validateAndMapEncoding(encodingByte, majorVersion);

    // Parse language code (3 bytes, ISO 639-2)
    if (reader.remaining < 3) {
      throw const CorruptedContainerException(
        'COMM frame missing language code',
        context: 'ID3v2 COMM frame parsing',
      );
    }
    final languageBytes = reader.readBytes(3);
    final language = String.fromCharCodes(languageBytes);

    // Validate language code format (should be 3 ASCII characters)
    if (!_isValidLanguageCode(language)) {
      throw CorruptedContainerException(
        'Invalid language code: "$language" (expected 3 ASCII characters)',
        context: 'ID3v2 COMM frame parsing',
      );
    }

    // Parse short content description (null-terminated string in specified encoding)
    final description = _parseNullTerminatedString(reader, encoding);

    // Parse the actual comment text (remaining bytes, not null-terminated)
    final textBytes = reader.readRemainingBytes();
    String text;
    try {
      text = _decodeText(textBytes, encoding);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode COMM frame text with encoding $encoding: $e',
        context: 'ID3v2 COMM frame parsing',
      );
    }

    return Id3v2CommFrameData(
      text: text,
      language: language,
      description: description,
      encoding: encoding,
      encodingByte: encodingByte,
    );
  }

  /// Validates and maps the encoding byte to a TextEncoding enum.
  static TextEncoding _validateAndMapEncoding(int encodingByte, int majorVersion) {
    switch (encodingByte) {
      case 0x00:
        return TextEncoding.iso88591;
      case 0x01:
        return TextEncoding.utf16; // UTF-16 with BOM
      case 0x02:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        return TextEncoding.utf16be;
      case 0x03:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x03 (UTF-8) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        return TextEncoding.utf8;
      default:
        throw FormatException(
          'Invalid text encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')} '
          'for ID3v2.$majorVersion',
        );
    }
  }

  /// Validates that a language code is in the correct format.
  static bool _isValidLanguageCode(String language) {
    if (language.length != 3) return false;

    // Check that all characters are ASCII letters or 'x' (for "xxx" unknown language)
    for (int i = 0; i < 3; i++) {
      final char = language.codeUnitAt(i);
      if (!((char >= 0x41 && char <= 0x5A) || // A-Z
          (char >= 0x61 && char <= 0x7A) || // a-z
          char == 0x78)) {
        // 'x'
        return false;
      }
    }

    return true;
  }

  /// Parses a null-terminated string using the specified encoding.
  static String _parseNullTerminatedString(ByteReader reader, TextEncoding encoding) {
    switch (encoding) {
      case TextEncoding.iso88591:
        return _parseIso88591NullTerminated(reader);
      case TextEncoding.utf16:
        return _parseUtf16NullTerminated(reader);
      case TextEncoding.utf16be:
        return _parseUtf16BeNullTerminated(reader);
      case TextEncoding.utf16le:
        return _parseUtf16LeNullTerminated(reader);
      case TextEncoding.utf8:
        return _parseUtf8NullTerminated(reader);
      case TextEncoding.ascii:
        return _parseIso88591NullTerminated(reader); // ASCII is subset of ISO-8859-1
    }
  }

  /// Parses an ISO-8859-1 null-terminated string.
  static String _parseIso88591NullTerminated(ByteReader reader) {
    final bytes = <int>[];

    while (reader.remaining > 0) {
      final byte = reader.readUint8();
      if (byte == 0) {
        break; // Found null terminator
      }
      bytes.add(byte);
    }

    return String.fromCharCodes(bytes);
  }

  /// Parses a UTF-16 null-terminated string (with BOM).
  static String _parseUtf16NullTerminated(ByteReader reader) {
    final bytes = <int>[];

    // Read until we find null terminator (0x00 0x00 for UTF-16)
    while (reader.remaining >= 2) {
      final byte1 = reader.readUint8();
      final byte2 = reader.readUint8();

      if (byte1 == 0 && byte2 == 0) {
        break; // Found null terminator
      }

      bytes.add(byte1);
      bytes.add(byte2);
    }

    if (bytes.isEmpty) {
      return '';
    }

    try {
      return TextEncodingUtils.decodeText(Uint8List.fromList(bytes), TextEncoding.utf16);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode UTF-16 string: $e',
        context: 'ID3v2 COMM frame parsing',
      );
    }
  }

  /// Parses a UTF-16BE null-terminated string.
  static String _parseUtf16BeNullTerminated(ByteReader reader) {
    final bytes = <int>[];

    // Read until we find null terminator (0x00 0x00 for UTF-16BE)
    while (reader.remaining >= 2) {
      final byte1 = reader.readUint8();
      final byte2 = reader.readUint8();

      if (byte1 == 0 && byte2 == 0) {
        break; // Found null terminator
      }

      bytes.add(byte1);
      bytes.add(byte2);
    }

    if (bytes.isEmpty) {
      return '';
    }

    try {
      return TextEncodingUtils.decodeText(Uint8List.fromList(bytes), TextEncoding.utf16be);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode UTF-16BE string: $e',
        context: 'ID3v2 COMM frame parsing',
      );
    }
  }

  /// Parses a UTF-16LE null-terminated string.
  static String _parseUtf16LeNullTerminated(ByteReader reader) {
    final bytes = <int>[];

    // Read until we find null terminator (0x00 0x00 for UTF-16LE)
    while (reader.remaining >= 2) {
      final byte1 = reader.readUint8();
      final byte2 = reader.readUint8();

      if (byte1 == 0 && byte2 == 0) {
        break; // Found null terminator
      }

      bytes.add(byte1);
      bytes.add(byte2);
    }

    if (bytes.isEmpty) {
      return '';
    }

    try {
      return TextEncodingUtils.decodeText(Uint8List.fromList(bytes), TextEncoding.utf16le);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode UTF-16LE string: $e',
        context: 'ID3v2 COMM frame parsing',
      );
    }
  }

  /// Parses a UTF-8 null-terminated string.
  static String _parseUtf8NullTerminated(ByteReader reader) {
    final bytes = <int>[];

    while (reader.remaining > 0) {
      final byte = reader.readUint8();
      if (byte == 0) {
        break; // Found null terminator
      }
      bytes.add(byte);
    }

    if (bytes.isEmpty) {
      return '';
    }

    try {
      return TextEncodingUtils.decodeText(Uint8List.fromList(bytes), TextEncoding.utf8);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode UTF-8 string: $e',
        context: 'ID3v2 COMM frame parsing',
      );
    }
  }

  /// Decodes text bytes using the specified encoding.
  static String _decodeText(Uint8List bytes, TextEncoding encoding) {
    if (bytes.isEmpty) {
      return '';
    }

    return TextEncodingUtils.decodeText(bytes, encoding);
  }

  /// Validates that a COMM frame data structure is valid.
  ///
  /// ## Parameters
  /// - [commData]: The COMM frame data to validate
  ///
  /// ## Returns
  /// `true` if the data is valid, `false` otherwise
  static bool isValid(Id3v2CommFrameData commData) {
    // Language code must be exactly 3 characters
    if (!_isValidLanguageCode(commData.language)) {
      return false;
    }

    // Description should not contain null bytes (they're used as terminators)
    if (commData.description.contains('\x00')) {
      return false;
    }

    // Encoding byte should be valid
    if (commData.encodingByte < 0 || commData.encodingByte > 3) {
      return false;
    }

    return true;
  }

  /// Encodes COMM frame data back to bytes for writing to ID3v2 tags.
  ///
  /// ## Parameters
  /// - [commData]: The COMM frame data to encode
  /// - [majorVersion]: The ID3v2 major version for encoding compatibility
  ///
  /// ## Returns
  /// The encoded frame data as bytes
  ///
  /// ## Throws
  /// - [ArgumentError] if the COMM data is invalid
  /// - [FormatException] if the encoding is not supported in the version
  static Uint8List encode(Id3v2CommFrameData commData, int majorVersion) {
    if (!isValid(commData)) {
      throw ArgumentError('Invalid COMM frame data: $commData');
    }

    // Validate encoding for version
    _validateAndMapEncoding(commData.encodingByte, majorVersion);

    final bytes = <int>[];

    // Add encoding byte
    bytes.add(commData.encodingByte);

    // Add language code (3 bytes)
    bytes.addAll(commData.language.codeUnits);

    // Add description (null-terminated in specified encoding)
    final descriptionBytes = _encodeString(commData.description, commData.encoding);
    bytes.addAll(descriptionBytes);

    // Add null terminator for description
    _addNullTerminator(bytes, commData.encoding);

    // Add comment text (not null-terminated)
    final textBytes = _encodeString(commData.text, commData.encoding);
    bytes.addAll(textBytes);

    return Uint8List.fromList(bytes);
  }

  /// Encodes a string using the specified text encoding.
  static List<int> _encodeString(String text, TextEncoding encoding) {
    switch (encoding) {
      case TextEncoding.iso88591:
        return text.codeUnits;
      case TextEncoding.utf16:
        return TextEncodingUtils.encodeText(text, TextEncoding.utf16).toList();
      case TextEncoding.utf16be:
        return TextEncodingUtils.encodeText(text, TextEncoding.utf16be).toList();
      case TextEncoding.utf16le:
        return TextEncodingUtils.encodeText(text, TextEncoding.utf16le).toList();
      case TextEncoding.utf8:
        return TextEncodingUtils.encodeText(text, TextEncoding.utf8, includeBom: false).toList();
      case TextEncoding.ascii:
        return text.codeUnits; // ASCII is subset of ISO-8859-1
    }
  }

  /// Adds the appropriate null terminator for the specified encoding.
  static void _addNullTerminator(List<int> bytes, TextEncoding encoding) {
    switch (encoding) {
      case TextEncoding.iso88591:
      case TextEncoding.utf8:
      case TextEncoding.ascii:
        bytes.add(0); // Single null byte
        break;
      case TextEncoding.utf16:
      case TextEncoding.utf16be:
      case TextEncoding.utf16le:
        bytes.add(0); // Two null bytes for UTF-16
        bytes.add(0);
        break;
    }
  }
}
