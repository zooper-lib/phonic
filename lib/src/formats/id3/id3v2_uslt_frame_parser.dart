import 'dart:typed_data';

import '../../core/text_encoding.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';
import '../../utils/text_encoding_utils.dart';

/// Utilities for parsing ID3v2 USLT (Unsynchronised Lyrics/Text Transcription) frames.
///
/// USLT frames contain lyrics information with the following structure:
/// - Text encoding (1 byte)
/// - Language (3 bytes, ISO 639-2 language code)
/// - Content descriptor (null-terminated string in specified encoding)
/// - Lyrics/text (string in specified encoding, not null-terminated)
///
/// ## ID3v2 USLT Frame Structure
///
/// ```
/// Offset  Length      Description
/// 0       1           Text encoding ($00 = ISO-8859-1, $01 = UTF-16, $02 = UTF-16BE, $03 = UTF-8)
/// 1       3           Language (ISO 639-2 language code, e.g., "eng", "fre")
/// 4       Variable    Content descriptor (null-terminated string in specified encoding)
/// N       Variable    Lyrics/text (string in specified encoding, not null-terminated)
/// ```
///
/// ## Text Encoding Support
///
/// USLT frames support different text encodings for both descriptor and lyrics fields:
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
/// ## Content Descriptor
///
/// The content descriptor field allows multiple USLT frames to coexist
/// with different purposes (e.g., "Verse 1", "Chorus", "Full Lyrics").
/// An empty descriptor is allowed and common for general lyrics.
///
/// ## Example Usage
///
/// ```dart
/// final frameData = Uint8List.fromList([
///   0x03,                           // UTF-8 encoding
///   0x65, 0x6E, 0x67,               // "eng" (English)
///   0x56, 0x65, 0x72, 0x73, 0x65, 0x20, 0x31, 0x00, // "Verse 1\0"
///   0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, // "Hello world"
/// ]);
///
/// final uslt = Id3v2UsltFrameParser.parse(frameData, 4);
/// print('Language: ${uslt.language}');
/// print('Descriptor: ${uslt.descriptor}');
/// print('Lyrics: ${uslt.lyrics}');
/// ```

/// Result of parsing USLT (Unsynchronised Lyrics/Text Transcription) frame data.
class Id3v2UsltFrameData {
  /// The lyrics/text content.
  final String lyrics;

  /// The ISO 639-2 language code (3 characters).
  final String language;

  /// The content descriptor.
  final String descriptor;

  /// The text encoding used in the frame.
  final TextEncoding encoding;

  /// The raw encoding byte from the frame.
  final int encodingByte;

  /// Creates USLT frame data with the specified properties.
  const Id3v2UsltFrameData({
    required this.lyrics,
    required this.language,
    required this.descriptor,
    required this.encoding,
    required this.encodingByte,
  });

  @override
  String toString() {
    return 'Id3v2UsltFrameData(lyrics: "${lyrics.length > 50 ? '${lyrics.substring(0, 50)}...' : lyrics}", '
        'language: "$language", descriptor: "$descriptor", encoding: $encoding)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2UsltFrameData &&
          runtimeType == other.runtimeType &&
          lyrics == other.lyrics &&
          language == other.language &&
          descriptor == other.descriptor &&
          encoding == other.encoding &&
          encodingByte == other.encodingByte;

  @override
  int get hashCode => Object.hash(lyrics, language, descriptor, encoding, encodingByte);
}

/// Parser for ID3v2 USLT (Unsynchronised Lyrics/Text Transcription) frames.
class Id3v2UsltFrameParser {
  /// Parses a USLT (Unsynchronised Lyrics/Text Transcription) frame from frame data.
  ///
  /// USLT frames contain lyrics information with the following structure:
  /// - Text encoding (1 byte)
  /// - Language (3 bytes, ISO 639-2 language code)
  /// - Content descriptor (null-terminated string in specified encoding)
  /// - Lyrics/text (string in specified encoding, not null-terminated)
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4) for encoding validation
  ///
  /// ## Returns
  /// An [Id3v2UsltFrameData] object containing the parsed lyrics information
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is too short for a valid USLT frame
  /// - [CorruptedContainerException] if the frame format is invalid
  /// - [FormatException] if the encoding byte is invalid for the version
  ///
  /// ## Example
  /// ```dart
  /// final usltData = Uint8List.fromList([
  ///   0x03,                           // UTF-8 encoding
  ///   0x65, 0x6E, 0x67,               // "eng" (English)
  ///   0x56, 0x65, 0x72, 0x73, 0x65, 0x20, 0x31, 0x00, // "Verse 1\0"
  ///   0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, // "Hello world"
  /// ]);
  /// final uslt = Id3v2UsltFrameParser.parse(usltData, 4);
  /// print('Language: ${uslt.language}'); // "eng"
  /// print('Descriptor: ${uslt.descriptor}'); // "Verse 1"
  /// print('Lyrics: ${uslt.lyrics}'); // "Hello world"
  /// ```
  static Id3v2UsltFrameData parse(Uint8List frameData, int majorVersion) {
    if (frameData.length < 5) {
      throw ArgumentError.value(
        frameData.length,
        'frameData.length',
        'USLT frame data must be at least 5 bytes (encoding + language + descriptor + lyrics)',
      );
    }

    final reader = ByteReader(frameData);

    // Parse text encoding byte
    final encodingByte = reader.readUint8();
    final encoding = _validateAndMapEncoding(encodingByte, majorVersion);

    // Parse language code (3 bytes, ISO 639-2)
    if (reader.remaining < 3) {
      throw const CorruptedContainerException(
        'USLT frame missing language code',
        context: 'ID3v2 USLT frame parsing',
      );
    }
    final languageBytes = reader.readBytes(3);
    final language = String.fromCharCodes(languageBytes);

    // Validate language code format (should be 3 ASCII characters)
    if (!_isValidLanguageCode(language)) {
      throw CorruptedContainerException(
        'Invalid language code: "$language" (expected 3 ASCII characters)',
        context: 'ID3v2 USLT frame parsing',
      );
    }

    // Parse content descriptor (null-terminated string in specified encoding)
    final descriptor = _parseNullTerminatedString(reader, encoding);

    // Parse the actual lyrics text (remaining bytes, not null-terminated)
    final lyricsBytes = reader.readRemainingBytes();
    String lyrics;
    try {
      lyrics = _decodeText(lyricsBytes, encoding);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode USLT frame lyrics with encoding $encoding: $e',
        context: 'ID3v2 USLT frame parsing',
      );
    }

    return Id3v2UsltFrameData(
      lyrics: lyrics,
      language: language,
      descriptor: descriptor,
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
        context: 'ID3v2 USLT frame parsing',
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
        context: 'ID3v2 USLT frame parsing',
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
        context: 'ID3v2 USLT frame parsing',
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
        context: 'ID3v2 USLT frame parsing',
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

  /// Validates that a USLT frame data structure is valid.
  ///
  /// ## Parameters
  /// - [usltData]: The USLT frame data to validate
  ///
  /// ## Returns
  /// `true` if the data is valid, `false` otherwise
  static bool isValid(Id3v2UsltFrameData usltData) {
    // Language code must be exactly 3 characters
    if (!_isValidLanguageCode(usltData.language)) {
      return false;
    }

    // Descriptor should not contain null bytes (they're used as terminators)
    if (usltData.descriptor.contains('\x00')) {
      return false;
    }

    // Encoding byte should be valid
    if (usltData.encodingByte < 0 || usltData.encodingByte > 3) {
      return false;
    }

    return true;
  }

  /// Encodes USLT frame data back to bytes for writing to ID3v2 tags.
  ///
  /// ## Parameters
  /// - [usltData]: The USLT frame data to encode
  /// - [majorVersion]: The ID3v2 major version for encoding compatibility
  ///
  /// ## Returns
  /// The encoded frame data as bytes
  ///
  /// ## Throws
  /// - [ArgumentError] if the USLT data is invalid
  /// - [FormatException] if the encoding is not supported in the version
  static Uint8List encode(Id3v2UsltFrameData usltData, int majorVersion) {
    if (!isValid(usltData)) {
      throw ArgumentError('Invalid USLT frame data: $usltData');
    }

    // Validate encoding for version
    _validateAndMapEncoding(usltData.encodingByte, majorVersion);

    final bytes = <int>[];

    // Add encoding byte
    bytes.add(usltData.encodingByte);

    // Add language code (3 bytes)
    bytes.addAll(usltData.language.codeUnits);

    // Add descriptor (null-terminated in specified encoding)
    final descriptorBytes = _encodeString(usltData.descriptor, usltData.encoding);
    bytes.addAll(descriptorBytes);

    // Add null terminator for descriptor
    _addNullTerminator(bytes, usltData.encoding);

    // Add lyrics text (not null-terminated)
    final lyricsBytes = _encodeString(usltData.lyrics, usltData.encoding);
    bytes.addAll(lyricsBytes);

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
