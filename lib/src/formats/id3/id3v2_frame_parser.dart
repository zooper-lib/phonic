import 'dart:typed_data';

import '../../core/text_encoding.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';
import '../../utils/synchsafe_int.dart';
import '../../utils/text_encoding_utils.dart';

/// Utilities for parsing ID3v2 frames and frame headers.
///
/// This module provides functionality to parse ID3v2 frame headers and extract
/// frame data according to the ID3v2 specification. It supports all major
/// versions (2.2, 2.3, 2.4) and handles various frame flags including
/// compression, encryption, and grouping.
///
/// ## ID3v2 Frame Structure
///
/// ### ID3v2.4 Frame Header (10 bytes)
/// ```
/// Offset  Length  Description
/// 0       4       Frame ID (e.g., "TIT2", "TPE1")
/// 4       4       Frame size (synchsafe integer, excluding header)
/// 8       2       Frame flags
/// ```
///
/// ### ID3v2.3 Frame Header (10 bytes)
/// ```
/// Offset  Length  Description
/// 0       4       Frame ID (e.g., "TIT2", "TPE1")
/// 4       4       Frame size (regular integer, excluding header)
/// 8       2       Frame flags
/// ```
///
/// ### ID3v2.2 Frame Header (6 bytes)
/// ```
/// Offset  Length  Description
/// 0       3       Frame ID (e.g., "TT2", "TP1")
/// 3       3       Frame size (24-bit integer, excluding header)
/// ```
///
/// ## Frame Flags
///
/// ### ID3v2.4 Status Flags (first byte)
/// - Bit 6: Tag alter preservation (0 = preserve, 1 = discard)
/// - Bit 5: File alter preservation (0 = preserve, 1 = discard)
/// - Bit 4: Read only (0 = not read only, 1 = read only)
/// - Bits 3-0: Unused, must be 0
///
/// ### ID3v2.4 Format Flags (second byte)
/// - Bit 6: Grouping identity (0 = not grouped, 1 = grouped)
/// - Bit 3: Compression (0 = not compressed, 1 = compressed)
/// - Bit 2: Encryption (0 = not encrypted, 1 = encrypted)
/// - Bit 1: Unsynchronization (0 = not unsynchronized, 1 = unsynchronized)
/// - Bit 0: Data length indicator (0 = no indicator, 1 = indicator present)
///
/// ## Text Frame Encoding
///
/// Text frames start with an encoding byte that indicates the character encoding:
/// - 0x00: ISO-8859-1 (Latin-1)
/// - 0x01: UTF-16 with BOM
/// - 0x02: UTF-16BE without BOM (ID3v2.4 only)
/// - 0x03: UTF-8 (ID3v2.4 only)
///
/// ## Example Usage
///
/// ```dart
/// final frameBytes = Uint8List.fromList([
///   // Frame header
///   0x54, 0x49, 0x54, 0x32, // "TIT2"
///   0x00, 0x00, 0x00, 0x0C, // Size: 12 bytes
///   0x00, 0x00,             // No flags
///   // Frame data
///   0x03,                   // UTF-8 encoding
///   0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
///   0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64, // " World"
/// ]);
///
/// final frame = Id3v2FrameParser.parseFrame(frameBytes, 4); // ID3v2.4
/// print('Frame ID: ${frame.id}');
/// print('Size: ${frame.size}');
/// print('Text: ${Id3v2FrameParser.parseTextFrameData(frame.data)}');
/// ```

/// Represents the flags in an ID3v2 frame header.
///
/// Frame flags control how the frame should be processed and provide
/// information about the frame's format and preservation requirements.
class Id3v2FrameFlags {
  /// Whether the frame should be discarded if the tag is altered.
  final bool tagAlterPreservation;

  /// Whether the frame should be discarded if the file is altered.
  final bool fileAlterPreservation;

  /// Whether the frame is read-only.
  final bool readOnly;

  /// Whether the frame belongs to a group.
  final bool groupingIdentity;

  /// Whether the frame data is compressed.
  final bool compression;

  /// Whether the frame data is encrypted.
  final bool encryption;

  /// Whether unsynchronization is applied to the frame.
  final bool unsynchronization;

  /// Whether a data length indicator is present.
  final bool dataLengthIndicator;

  /// The raw status flags byte.
  final int statusFlags;

  /// The raw format flags byte.
  final int formatFlags;

  /// Creates ID3v2 frame flags from individual boolean values.
  const Id3v2FrameFlags({
    this.tagAlterPreservation = false,
    this.fileAlterPreservation = false,
    this.readOnly = false,
    this.groupingIdentity = false,
    this.compression = false,
    this.encryption = false,
    this.unsynchronization = false,
    this.dataLengthIndicator = false,
    required this.statusFlags,
    required this.formatFlags,
  });

  /// Creates ID3v2 frame flags by parsing flag bytes.
  ///
  /// The interpretation of flag bits depends on the ID3v2 version:
  /// - ID3v2.2: No flags (always returns default flags)
  /// - ID3v2.3: Different flag layout than v2.4
  /// - ID3v2.4: Full flag support as documented
  ///
  /// ## Parameters
  /// - [statusFlags]: The first flags byte (status flags)
  /// - [formatFlags]: The second flags byte (format flags)
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Throws
  /// - [FormatException] if reserved bits are set or invalid flags are detected
  factory Id3v2FrameFlags.fromBytes(int statusFlags, int formatFlags, int majorVersion) {
    switch (majorVersion) {
      case 2:
        // ID3v2.2: No frame flags
        return const Id3v2FrameFlags(
          statusFlags: 0,
          formatFlags: 0,
        );

      case 3:
        // ID3v2.3: Different flag layout
        // Status flags: bits 7, 6, 5 are defined
        if (statusFlags & 0x1F != 0) {
          throw FormatException(
            'Invalid ID3v2.3 status flags: reserved bits set (0x${statusFlags.toRadixString(16).padLeft(2, '0')})',
          );
        }
        // Format flags: bits 7, 6, 5 are defined
        if (formatFlags & 0x1F != 0) {
          throw FormatException(
            'Invalid ID3v2.3 format flags: reserved bits set (0x${formatFlags.toRadixString(16).padLeft(2, '0')})',
          );
        }

        return Id3v2FrameFlags(
          tagAlterPreservation: (statusFlags & 0x80) != 0,
          fileAlterPreservation: (statusFlags & 0x40) != 0,
          readOnly: (statusFlags & 0x20) != 0,
          compression: (formatFlags & 0x80) != 0,
          encryption: (formatFlags & 0x40) != 0,
          groupingIdentity: (formatFlags & 0x20) != 0,
          statusFlags: statusFlags,
          formatFlags: formatFlags,
        );

      case 4:
        // ID3v2.4: Full flag support
        // Status flags: bits 6, 5, 4 are defined, others must be 0
        if (statusFlags & 0x8F != 0) {
          throw FormatException(
            'Invalid ID3v2.4 status flags: reserved bits set (0x${statusFlags.toRadixString(16).padLeft(2, '0')})',
          );
        }
        // Format flags: bits 6, 3, 2, 1, 0 are defined, others must be 0
        if (formatFlags & 0xB0 != 0) {
          throw FormatException(
            'Invalid ID3v2.4 format flags: reserved bits set (0x${formatFlags.toRadixString(16).padLeft(2, '0')})',
          );
        }

        return Id3v2FrameFlags(
          tagAlterPreservation: (statusFlags & 0x40) != 0,
          fileAlterPreservation: (statusFlags & 0x20) != 0,
          readOnly: (statusFlags & 0x10) != 0,
          groupingIdentity: (formatFlags & 0x40) != 0,
          compression: (formatFlags & 0x08) != 0,
          encryption: (formatFlags & 0x04) != 0,
          unsynchronization: (formatFlags & 0x02) != 0,
          dataLengthIndicator: (formatFlags & 0x01) != 0,
          statusFlags: statusFlags,
          formatFlags: formatFlags,
        );

      default:
        throw FormatException('Unsupported ID3v2 major version: $majorVersion');
    }
  }

  /// Whether any format flags are set that affect frame data parsing.
  bool get hasFormatFlags => compression || encryption || unsynchronization || dataLengthIndicator;

  @override
  String toString() {
    final parts = <String>[];
    if (tagAlterPreservation) parts.add('tag-alter');
    if (fileAlterPreservation) parts.add('file-alter');
    if (readOnly) parts.add('read-only');
    if (groupingIdentity) parts.add('grouped');
    if (compression) parts.add('compressed');
    if (encryption) parts.add('encrypted');
    if (unsynchronization) parts.add('unsync');
    if (dataLengthIndicator) parts.add('data-length');
    return 'Id3v2FrameFlags(${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2FrameFlags && runtimeType == other.runtimeType && statusFlags == other.statusFlags && formatFlags == other.formatFlags;

  @override
  int get hashCode => Object.hash(statusFlags, formatFlags);
}

/// Represents a parsed ID3v2 frame.
///
/// An ID3v2 frame contains a header with metadata about the frame
/// (ID, size, flags) and the actual frame data payload.
class Id3v2Frame {
  /// The frame identifier (e.g., "TIT2", "TPE1", "TT2").
  final String id;

  /// The size of the frame data in bytes (excluding the header).
  final int size;

  /// The frame flags containing processing instructions.
  final Id3v2FrameFlags flags;

  /// The raw frame data payload.
  final Uint8List data;

  /// The ID3v2 major version this frame was parsed from.
  final int majorVersion;

  /// Creates an ID3v2 frame with the specified properties.
  const Id3v2Frame({
    required this.id,
    required this.size,
    required this.flags,
    required this.data,
    required this.majorVersion,
  });

  /// The total size of the frame including the header.
  int get totalSize {
    switch (majorVersion) {
      case 2:
        return 6 + size; // 6-byte header + data
      case 3:
      case 4:
        return 10 + size; // 10-byte header + data
      default:
        throw StateError('Invalid major version: $majorVersion');
    }
  }

  /// Whether this frame contains text data.
  bool get isTextFrame {
    if (majorVersion == 2) {
      // ID3v2.2 text frames start with 'T' (except TXX)
      return id.startsWith('T') && id != 'TXX';
    } else {
      // ID3v2.3/2.4 text frames start with 'T' (except TXXX)
      return id.startsWith('T') && id != 'TXXX';
    }
  }

  /// Whether this frame contains URL data.
  bool get isUrlFrame {
    if (majorVersion == 2) {
      // ID3v2.2 URL frames start with 'W' (except WXX)
      return id.startsWith('W') && id != 'WXX';
    } else {
      // ID3v2.3/2.4 URL frames start with 'W' (except WXXX)
      return id.startsWith('W') && id != 'WXXX';
    }
  }

  /// Whether this frame contains user-defined text data.
  bool get isUserTextFrame {
    return (majorVersion == 2 && id == 'TXX') || (majorVersion >= 3 && id == 'TXXX');
  }

  /// Whether this frame contains user-defined URL data.
  bool get isUserUrlFrame {
    return (majorVersion == 2 && id == 'WXX') || (majorVersion >= 3 && id == 'WXXX');
  }

  @override
  String toString() {
    return 'Id3v2Frame(id: $id, size: $size, flags: $flags, version: $majorVersion)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2Frame &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          size == other.size &&
          flags == other.flags &&
          majorVersion == other.majorVersion;

  @override
  int get hashCode => Object.hash(id, size, flags, majorVersion);
}

/// Result of parsing text frame data with encoding information.
class Id3v2TextFrameData {
  /// The decoded text content.
  final String text;

  /// The text encoding used in the frame.
  final TextEncoding encoding;

  /// The raw encoding byte from the frame.
  final int encodingByte;

  /// Creates text frame data with the specified properties.
  const Id3v2TextFrameData({
    required this.text,
    required this.encoding,
    required this.encodingByte,
  });

  @override
  String toString() {
    return 'Id3v2TextFrameData(text: "$text", encoding: $encoding)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2TextFrameData && runtimeType == other.runtimeType && text == other.text && encoding == other.encoding && encodingByte == other.encodingByte;

  @override
  int get hashCode => Object.hash(text, encoding, encodingByte);
}

/// Utilities for parsing ID3v2 frames and frame data.
class Id3v2FrameParser {
  /// Minimum frame header size for ID3v2.2 (6 bytes).
  static const int minFrameHeaderSize = 6;

  /// Frame header size for ID3v2.3 and ID3v2.4 (10 bytes).
  static const int standardFrameHeaderSize = 10;

  /// Parses an ID3v2 frame from the provided bytes.
  ///
  /// This method parses the frame header and extracts the frame data
  /// according to the specified ID3v2 version. It handles version-specific
  /// differences in header format and flag interpretation.
  ///
  /// ## Parameters
  /// - [bytes]: The byte data containing the frame at the beginning
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  /// - [offset]: Starting position in the bytes (default: 0)
  ///
  /// ## Returns
  /// A parsed [Id3v2Frame] object containing header and data
  ///
  /// ## Throws
  /// - [ArgumentError] if [bytes] is too short for a frame header
  /// - [CorruptedContainerException] if the frame format is invalid
  /// - [FormatException] if the frame flags are invalid
  ///
  /// ## Example
  /// ```dart
  /// final frameBytes = Uint8List.fromList([
  ///   0x54, 0x49, 0x54, 0x32, // "TIT2"
  ///   0x00, 0x00, 0x00, 0x0C, // Size: 12 bytes
  ///   0x00, 0x00,             // No flags
  ///   0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F, // UTF-8 "Hello"
  /// ]);
  /// final frame = Id3v2FrameParser.parseFrame(frameBytes, 4);
  /// ```
  static Id3v2Frame parseFrame(Uint8List bytes, int majorVersion, [int offset = 0]) {
    final expectedHeaderSize = majorVersion == 2 ? minFrameHeaderSize : standardFrameHeaderSize;

    if (bytes.length < offset + expectedHeaderSize) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Insufficient bytes for ID3v2.$majorVersion frame header: '
            'need ${offset + expectedHeaderSize}, got ${bytes.length}',
      );
    }

    final reader = ByteReader(bytes);
    reader.seek(offset);

    // Parse frame ID
    final String frameId;
    if (majorVersion == 2) {
      // ID3v2.2 uses 3-character frame IDs
      final idBytes = reader.readBytes(3);
      frameId = String.fromCharCodes(idBytes);

      // Validate frame ID characters (should be alphanumeric)
      if (!_isValidFrameId(frameId, majorVersion)) {
        throw CorruptedContainerException(
          'Invalid ID3v2.2 frame ID: "$frameId"',
          byteOffset: offset,
          context: 'ID3v2 frame parsing',
        );
      }
    } else {
      // ID3v2.3/2.4 use 4-character frame IDs
      final idBytes = reader.readBytes(4);
      frameId = String.fromCharCodes(idBytes);

      // Validate frame ID characters (should be alphanumeric)
      if (!_isValidFrameId(frameId, majorVersion)) {
        throw CorruptedContainerException(
          'Invalid ID3v2.$majorVersion frame ID: "$frameId"',
          byteOffset: offset,
          context: 'ID3v2 frame parsing',
        );
      }
    }

    // Parse frame size
    final int frameSize;
    if (majorVersion == 2) {
      // ID3v2.2 uses 24-bit size (3 bytes, big-endian)
      final sizeBytes = reader.readBytes(3);
      frameSize = (sizeBytes[0] << 16) | (sizeBytes[1] << 8) | sizeBytes[2];
    } else if (majorVersion == 3) {
      // ID3v2.3 uses regular 32-bit integer
      frameSize = reader.readUint32();
    } else {
      // ID3v2.4 uses synchsafe integer
      final sizeBytes = reader.readBytes(4);
      frameSize = SynchsafeInt.decodeBytes(sizeBytes);
    }

    // Validate frame size
    if (frameSize < 0) {
      throw CorruptedContainerException(
        'Invalid frame size: $frameSize (cannot be negative)',
        byteOffset: offset + (majorVersion == 2 ? 3 : 4),
        context: 'ID3v2 frame parsing',
      );
    }

    // Parse frame flags
    Id3v2FrameFlags flags;
    if (majorVersion == 2) {
      // ID3v2.2 has no frame flags
      flags = const Id3v2FrameFlags(statusFlags: 0, formatFlags: 0);
    } else {
      // ID3v2.3/2.4 have 2-byte flags
      final statusFlags = reader.readUint8();
      final formatFlags = reader.readUint8();
      flags = Id3v2FrameFlags.fromBytes(statusFlags, formatFlags, majorVersion);
    }

    // Validate that we have enough bytes for the frame data
    if (reader.remaining < frameSize) {
      throw CorruptedContainerException(
        'Insufficient bytes for frame data: need $frameSize, got ${reader.remaining}',
        byteOffset: reader.position,
        context: 'ID3v2 frame parsing',
      );
    }

    // Extract frame data
    final frameData = reader.readBytes(frameSize);

    return Id3v2Frame(
      id: frameId,
      size: frameSize,
      flags: flags,
      data: frameData,
      majorVersion: majorVersion,
    );
  }

  /// Parses text frame data and extracts the text content with encoding information.
  ///
  /// Text frames in ID3v2 start with an encoding byte that indicates the
  /// character encoding used for the text data. This method handles all
  /// supported encodings and version-specific differences, with proper
  /// null terminator handling for each encoding type.
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Returns
  /// An [Id3v2TextFrameData] object containing the decoded text and encoding info
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is empty
  /// - [FormatException] if the encoding byte is invalid for the version
  /// - [CorruptedContainerException] if text decoding fails
  ///
  /// ## Example
  /// ```dart
  /// final frameData = Uint8List.fromList([
  ///   0x03, // UTF-8 encoding
  ///   0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
  /// ]);
  /// final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);
  /// print(textData.text); // "Hello"
  /// print(textData.encoding); // TextEncoding.utf8
  /// ```
  static Id3v2TextFrameData parseTextFrameData(Uint8List frameData, int majorVersion) {
    if (frameData.isEmpty) {
      throw ArgumentError.value(frameData.length, 'frameData.length', 'Frame data cannot be empty');
    }

    final reader = ByteReader(frameData);
    final encodingByte = reader.readUint8();

    // Map encoding byte to TextEncoding based on version
    final TextEncoding encoding;
    switch (encodingByte) {
      case 0x00:
        encoding = TextEncoding.iso88591;
        break;
      case 0x01:
        encoding = TextEncoding.utf16; // UTF-16 with BOM
        break;
      case 0x02:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        encoding = TextEncoding.utf16be;
        break;
      case 0x03:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x03 (UTF-8) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        encoding = TextEncoding.utf8;
        break;
      default:
        throw FormatException(
          'Invalid text encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')} '
          'for ID3v2.$majorVersion',
        );
    }

    // Read the remaining bytes as text data
    final textBytes = reader.readRemainingBytes();

    // Decode the text using the specified encoding with proper null terminator handling
    String text;
    try {
      text = _decodeTextWithNullHandling(textBytes, encoding);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode text frame data with encoding $encoding: $e',
        context: 'ID3v2 text frame parsing',
      );
    }

    return Id3v2TextFrameData(
      text: text,
      encoding: encoding,
      encodingByte: encodingByte,
    );
  }

  /// Parses a standard text frame (TIT2, TPE1, TALB, etc.) from frame data.
  ///
  /// This is a convenience method for parsing common text frames that contain
  /// a single text string with encoding. It handles all the encoding detection
  /// and null terminator processing automatically.
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Returns
  /// The decoded text string
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is empty
  /// - [FormatException] if the encoding byte is invalid for the version
  /// - [CorruptedContainerException] if text decoding fails
  ///
  /// ## Example
  /// ```dart
  /// // Parse a TIT2 (title) frame
  /// final titleText = Id3v2FrameParser.parseStandardTextFrame(tit2FrameData, 4);
  /// print('Title: $titleText');
  /// ```
  static String parseStandardTextFrame(Uint8List frameData, int majorVersion) {
    final textFrameData = parseTextFrameData(frameData, majorVersion);
    return textFrameData.text;
  }

  /// Parses multiple text values from a single frame (used for frames that can contain multiple values).
  ///
  /// Some text frames can contain multiple values separated by null terminators.
  /// This method properly handles the separation based on the encoding type.
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Returns
  /// A list of decoded text strings
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is empty
  /// - [FormatException] if the encoding byte is invalid for the version
  /// - [CorruptedContainerException] if text decoding fails
  ///
  /// ## Example
  /// ```dart
  /// // Parse a frame that might contain multiple values
  /// final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);
  /// for (final value in values) {
  ///   print('Value: $value');
  /// }
  /// ```
  static List<String> parseMultiValueTextFrame(Uint8List frameData, int majorVersion) {
    if (frameData.isEmpty) {
      throw ArgumentError.value(frameData.length, 'frameData.length', 'Frame data cannot be empty');
    }

    final reader = ByteReader(frameData);
    final encodingByte = reader.readUint8();

    // Map encoding byte to TextEncoding based on version
    final TextEncoding encoding;
    switch (encodingByte) {
      case 0x00:
        encoding = TextEncoding.iso88591;
        break;
      case 0x01:
        encoding = TextEncoding.utf16; // UTF-16 with BOM
        break;
      case 0x02:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        encoding = TextEncoding.utf16be;
        break;
      case 0x03:
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x03 (UTF-8) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        encoding = TextEncoding.utf8;
        break;
      default:
        throw FormatException(
          'Invalid text encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')} '
          'for ID3v2.$majorVersion',
        );
    }

    // Read the remaining bytes as text data
    final textBytes = reader.readRemainingBytes();

    // Decode multiple text values with proper null terminator handling
    List<String> values;
    try {
      values = _decodeMultipleTextValues(textBytes, encoding);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to decode multi-value text frame data with encoding $encoding: $e',
        context: 'ID3v2 text frame parsing',
      );
    }

    return values;
  }

  /// Extracts frame data after processing format flags.
  ///
  /// This method handles frame format flags such as compression, encryption,
  /// and unsynchronization. It processes the frame data according to the
  /// flags and returns the actual payload data.
  ///
  /// ## Parameters
  /// - [frame]: The parsed frame with flags and raw data
  ///
  /// ## Returns
  /// The processed frame data as bytes
  ///
  /// ## Throws
  /// - [UnsupportedError] if compression or encryption is used (not yet implemented)
  /// - [CorruptedContainerException] if data processing fails
  ///
  /// ## Example
  /// ```dart
  /// final frame = Id3v2FrameParser.parseFrame(frameBytes, 4);
  /// final processedData = Id3v2FrameParser.extractFrameData(frame);
  /// ```
  static Uint8List extractFrameData(Id3v2Frame frame) {
    Uint8List data = frame.data;
    final reader = ByteReader(data);

    // Process format flags in order
    if (frame.flags.dataLengthIndicator) {
      // Skip the data length indicator (4 bytes synchsafe integer)
      if (reader.remaining < 4) {
        throw const CorruptedContainerException(
          'Data length indicator flag set but insufficient bytes',
          context: 'ID3v2 frame data extraction',
        );
      }
      reader.skip(4); // Skip the length indicator
      data = reader.readRemainingBytes();
    }

    if (frame.flags.unsynchronization) {
      // Remove unsynchronization (0xFF 0x00 -> 0xFF)
      data = _removeUnsynchronization(data);
    }

    if (frame.flags.encryption) {
      throw UnsupportedError(
        'Encrypted frames are not supported (frame: ${frame.id})',
      );
    }

    if (frame.flags.compression) {
      throw UnsupportedError(
        'Compressed frames are not supported (frame: ${frame.id})',
      );
    }

    if (frame.flags.groupingIdentity) {
      // Skip the group identifier byte
      if (data.isEmpty) {
        throw const CorruptedContainerException(
          'Grouping identity flag set but no group identifier byte',
          context: 'ID3v2 frame data extraction',
        );
      }
      data = data.sublist(1);
    }

    return data;
  }

  /// Detects the text encoding used in a text frame.
  ///
  /// This method examines the first byte of frame data to determine
  /// the text encoding, with validation for version compatibility.
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Returns
  /// The detected [TextEncoding]
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is empty
  /// - [FormatException] if the encoding is invalid for the version
  static TextEncoding detectFrameTextEncoding(Uint8List frameData, int majorVersion) {
    if (frameData.isEmpty) {
      throw ArgumentError.value(frameData.length, 'frameData.length', 'Frame data cannot be empty');
    }

    final encodingByte = frameData[0];

    switch (encodingByte) {
      case 0x00:
        return TextEncoding.iso88591;
      case 0x01:
        return TextEncoding.utf16;
      case 0x02:
        if (majorVersion < 4) {
          throw const FormatException(
            'UTF-16BE encoding (0x02) is only supported in ID3v2.4',
          );
        }
        return TextEncoding.utf16be;
      case 0x03:
        if (majorVersion < 4) {
          throw const FormatException(
            'UTF-8 encoding (0x03) is only supported in ID3v2.4',
          );
        }
        return TextEncoding.utf8;
      default:
        throw FormatException(
          'Invalid text encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')}',
        );
    }
  }

  /// Validates that a frame ID contains only valid characters.
  ///
  /// Frame IDs should contain only uppercase letters and digits.
  /// ID3v2.2 uses 3-character IDs, while ID3v2.3/2.4 use 4-character IDs.
  static bool _isValidFrameId(String frameId, int majorVersion) {
    final expectedLength = majorVersion == 2 ? 3 : 4;

    if (frameId.length != expectedLength) {
      return false;
    }

    // Check that all characters are uppercase letters or digits
    for (int i = 0; i < frameId.length; i++) {
      final char = frameId.codeUnitAt(i);
      final isUpperLetter = char >= 0x41 && char <= 0x5A; // A-Z
      final isDigit = char >= 0x30 && char <= 0x39; // 0-9

      if (!isUpperLetter && !isDigit) {
        return false;
      }
    }

    return true;
  }

  /// Removes unsynchronization from frame data.
  ///
  /// Unsynchronization replaces 0xFF 0x00 patterns with 0xFF to prevent
  /// false MP3 frame sync detection. This method reverses that process.
  static Uint8List _removeUnsynchronization(Uint8List data) {
    final result = <int>[];

    for (int i = 0; i < data.length; i++) {
      result.add(data[i]);

      // If we find 0xFF followed by 0x00, skip the 0x00
      if (data[i] == 0xFF && i + 1 < data.length && data[i + 1] == 0x00) {
        i++; // Skip the 0x00 byte
      }
    }

    return Uint8List.fromList(result);
  }

  /// Decodes text with proper null terminator handling for different encodings.
  ///
  /// This method handles null terminators correctly for each encoding type:
  /// - ISO-8859-1 and UTF-8: Single null byte (0x00)
  /// - UTF-16: Double null bytes (0x00 0x00)
  ///
  /// ## Parameters
  /// - [textBytes]: The raw text bytes to decode
  /// - [encoding]: The text encoding to use
  ///
  /// ## Returns
  /// The decoded text string with null terminators removed
  static String _decodeTextWithNullHandling(Uint8List textBytes, TextEncoding encoding) {
    if (textBytes.isEmpty) {
      return '';
    }

    // Remove null terminators based on encoding type
    Uint8List processedBytes;
    switch (encoding) {
      case TextEncoding.iso88591:
      case TextEncoding.utf8:
      case TextEncoding.ascii:
        // Single-byte encodings: remove trailing null bytes
        processedBytes = _removeTrailingNullBytes(textBytes, 1);
        break;

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
      case TextEncoding.utf16be:
        // UTF-16 encodings: remove trailing null byte pairs
        processedBytes = _removeTrailingNullBytes(textBytes, 2);
        break;
    }

    // Decode the text using the specified encoding
    final text = TextEncodingUtils.decodeText(processedBytes, encoding);

    // Additional cleanup: remove any remaining null characters that might have been decoded
    return text.replaceAll('\x00', '');
  }

  /// Decodes multiple text values separated by null terminators.
  ///
  /// This method splits text data on null terminators appropriate for the encoding:
  /// - ISO-8859-1 and UTF-8: Split on single null byte (0x00)
  /// - UTF-16: Split on double null bytes (0x00 0x00)
  ///
  /// ## Parameters
  /// - [textBytes]: The raw text bytes containing multiple values
  /// - [encoding]: The text encoding to use
  ///
  /// ## Returns
  /// A list of decoded text strings
  static List<String> _decodeMultipleTextValues(Uint8List textBytes, TextEncoding encoding) {
    if (textBytes.isEmpty) {
      return [];
    }

    final values = <String>[];

    switch (encoding) {
      case TextEncoding.iso88591:
      case TextEncoding.utf8:
      case TextEncoding.ascii:
        // Single-byte encodings: split on null bytes
        final segments = _splitOnNullBytes(textBytes, 1);
        for (final segment in segments) {
          if (segment.isNotEmpty) {
            final text = TextEncodingUtils.decodeText(segment, encoding);
            if (text.isNotEmpty) {
              values.add(text);
            }
          }
        }
        break;

      case TextEncoding.utf16:
      case TextEncoding.utf16le:
      case TextEncoding.utf16be:
        // UTF-16 encodings: split on double null bytes
        final segments = _splitOnNullBytes(textBytes, 2);
        for (final segment in segments) {
          if (segment.isNotEmpty) {
            final text = TextEncodingUtils.decodeText(segment, encoding);
            final cleanText = text.replaceAll('\x00', '');
            if (cleanText.isNotEmpty) {
              values.add(cleanText);
            }
          }
        }
        break;
    }

    return values;
  }

  /// Removes trailing null bytes from the end of a byte array.
  ///
  /// ## Parameters
  /// - [bytes]: The byte array to process
  /// - [nullSize]: The size of null terminators (1 for single-byte, 2 for UTF-16)
  ///
  /// ## Returns
  /// A new byte array with trailing null bytes removed
  static Uint8List _removeTrailingNullBytes(Uint8List bytes, int nullSize) {
    if (bytes.isEmpty) {
      return bytes;
    }

    int endIndex = bytes.length;

    // Remove trailing null bytes
    while (endIndex >= nullSize) {
      bool isNull = true;
      for (int i = 0; i < nullSize; i++) {
        if (bytes[endIndex - nullSize + i] != 0) {
          isNull = false;
          break;
        }
      }

      if (isNull) {
        endIndex -= nullSize;
      } else {
        break;
      }
    }

    return bytes.sublist(0, endIndex);
  }

  /// Splits a byte array on null byte sequences.
  ///
  /// ## Parameters
  /// - [bytes]: The byte array to split
  /// - [nullSize]: The size of null terminators (1 for single-byte, 2 for UTF-16)
  ///
  /// ## Returns
  /// A list of byte arrays split on null terminators
  static List<Uint8List> _splitOnNullBytes(Uint8List bytes, int nullSize) {
    if (bytes.isEmpty) {
      return [];
    }

    final segments = <Uint8List>[];
    int startIndex = 0;

    int i = 0;
    while (i <= bytes.length - nullSize) {
      // Check if we found a null terminator
      bool isNull = true;
      for (int j = 0; j < nullSize; j++) {
        if (bytes[i + j] != 0) {
          isNull = false;
          break;
        }
      }

      if (isNull) {
        // Found null terminator, add segment if it's not empty
        if (i > startIndex) {
          segments.add(bytes.sublist(startIndex, i));
        }
        startIndex = i + nullSize;
        i += nullSize; // Skip the null bytes
      } else {
        i++;
      }
    }

    // Add the remaining segment if any
    if (startIndex < bytes.length) {
      segments.add(bytes.sublist(startIndex));
    }

    return segments;
  }
}
