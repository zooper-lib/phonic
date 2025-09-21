import 'dart:typed_data';

import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';
import '../../utils/synchsafe_int.dart';

/// Utilities for parsing ID3v2 headers and extended headers.
///
/// This module provides functionality to parse ID3v2 tag headers according to
/// the ID3v2 specification. It supports all major versions (2.2, 2.3, 2.4)
/// and handles various header flags including unsynchronization, extended headers,
/// and experimental indicators.
///
/// ## ID3v2 Header Structure
///
/// The ID3v2 header is 10 bytes long and has the following structure:
/// ```
/// Offset  Length  Description
/// 0       3       "ID3" signature
/// 3       1       Major version (2, 3, or 4)
/// 4       1       Minor version (always 0)
/// 5       1       Flags byte
/// 6       4       Tag size (synchsafe integer, excluding header)
/// ```
///
/// ## Header Flags (ID3v2.4)
///
/// - Bit 7: Unsynchronization (0 = not used, 1 = used)
/// - Bit 6: Extended header (0 = not present, 1 = present)
/// - Bit 5: Experimental indicator (0 = stable, 1 = experimental)
/// - Bit 4: Footer present (0 = not present, 1 = present)
/// - Bits 3-0: Unused, must be 0
///
/// ## Extended Header (ID3v2.4)
///
/// When present, the extended header follows immediately after the main header:
/// ```
/// Offset  Length  Description
/// 0       4       Extended header size (synchsafe integer)
/// 4       1       Number of flag bytes
/// 5       1       Extended flags
/// 6       ...     Flag data (variable length)
/// ```
///
/// ## Example Usage
///
/// ```dart
/// final bytes = Uint8List.fromList([
///   0x49, 0x44, 0x33, // "ID3"
///   0x04, 0x00,       // Version 2.4
///   0x80,             // Flags (unsynchronization)
///   0x00, 0x00, 0x1F, 0x76, // Size (4086 bytes)
/// ]);
///
/// final header = Id3v2HeaderParser.parseHeader(bytes);
/// print('Version: ${header.majorVersion}.${header.minorVersion}');
/// print('Size: ${header.tagSize} bytes');
/// print('Unsynchronized: ${header.flags.unsynchronization}');
/// ```

/// Represents the flags byte in an ID3v2 header.
///
/// The flags byte contains various boolean indicators that affect how the
/// tag should be processed. Different ID3v2 versions support different flags.
class Id3v2HeaderFlags {
  /// Whether unsynchronization is applied to the entire tag.
  ///
  /// Unsynchronization prevents false MP3 frame sync patterns by encoding
  /// 0xFF bytes followed by bytes with the MSB set.
  final bool unsynchronization;

  /// Whether an extended header is present after the main header.
  ///
  /// Extended headers contain additional metadata about the tag structure
  /// and processing requirements.
  final bool extendedHeader;

  /// Whether this tag is experimental (ID3v2.4 only).
  ///
  /// Experimental tags may use non-standard features and should be handled
  /// with caution by applications.
  final bool experimental;

  /// Whether a footer is present at the end of the tag (ID3v2.4 only).
  ///
  /// The footer is a copy of the header with "3DI" signature instead of "ID3"
  /// and allows for appending tags to files.
  final bool footer;

  /// The raw flags byte value.
  final int rawValue;

  /// Creates ID3v2 header flags from individual boolean values.
  const Id3v2HeaderFlags({
    this.unsynchronization = false,
    this.extendedHeader = false,
    this.experimental = false,
    this.footer = false,
    required this.rawValue,
  });

  /// Creates ID3v2 header flags by parsing a flags byte.
  ///
  /// The interpretation of flag bits depends on the ID3v2 version:
  /// - ID3v2.2: Only unsynchronization (bit 7) and compression (bit 6) are defined
  /// - ID3v2.3: Unsynchronization (bit 7), extended header (bit 6), experimental (bit 5)
  /// - ID3v2.4: All flags are defined
  ///
  /// ## Parameters
  /// - [flagsByte]: The raw flags byte from the header
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4)
  ///
  /// ## Throws
  /// - [FormatException] if reserved bits are set or invalid flags are detected
  factory Id3v2HeaderFlags.fromByte(int flagsByte, int majorVersion) {
    // Validate that reserved bits are not set
    switch (majorVersion) {
      case 2:
        // ID3v2.2: Only bits 7 and 6 are defined (unsync and compression)
        if (flagsByte & 0x3F != 0) {
          throw FormatException(
            'Invalid ID3v2.2 flags: reserved bits set (0x${flagsByte.toRadixString(16).padLeft(2, '0')})',
          );
        }
        return Id3v2HeaderFlags(
          unsynchronization: (flagsByte & 0x80) != 0,
          extendedHeader: (flagsByte & 0x40) != 0, // Compression in v2.2
          rawValue: flagsByte,
        );

      case 3:
        // ID3v2.3: Bits 7, 6, 5 are defined, bits 4-0 must be 0
        if (flagsByte & 0x1F != 0) {
          throw FormatException(
            'Invalid ID3v2.3 flags: reserved bits set (0x${flagsByte.toRadixString(16).padLeft(2, '0')})',
          );
        }
        return Id3v2HeaderFlags(
          unsynchronization: (flagsByte & 0x80) != 0,
          extendedHeader: (flagsByte & 0x40) != 0,
          experimental: (flagsByte & 0x20) != 0,
          rawValue: flagsByte,
        );

      case 4:
        // ID3v2.4: Bits 7, 6, 5, 4 are defined, bits 3-0 must be 0
        if (flagsByte & 0x0F != 0) {
          throw FormatException(
            'Invalid ID3v2.4 flags: reserved bits set (0x${flagsByte.toRadixString(16).padLeft(2, '0')})',
          );
        }
        return Id3v2HeaderFlags(
          unsynchronization: (flagsByte & 0x80) != 0,
          extendedHeader: (flagsByte & 0x40) != 0,
          experimental: (flagsByte & 0x20) != 0,
          footer: (flagsByte & 0x10) != 0,
          rawValue: flagsByte,
        );

      default:
        throw FormatException('Unsupported ID3v2 major version: $majorVersion');
    }
  }

  @override
  String toString() {
    final parts = <String>[];
    if (unsynchronization) parts.add('unsync');
    if (extendedHeader) parts.add('extended');
    if (experimental) parts.add('experimental');
    if (footer) parts.add('footer');
    return 'Id3v2HeaderFlags(${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Id3v2HeaderFlags && runtimeType == other.runtimeType && rawValue == other.rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

/// Represents a parsed ID3v2 header.
///
/// The ID3v2 header contains essential information about the tag structure,
/// version, flags, and size. This class provides a structured representation
/// of the 10-byte header that appears at the beginning of every ID3v2 tag.
class Id3v2Header {
  /// The ID3v2 major version (2, 3, or 4).
  final int majorVersion;

  /// The ID3v2 minor version (typically 0).
  final int minorVersion;

  /// The header flags containing processing instructions.
  final Id3v2HeaderFlags flags;

  /// The size of the tag data following the header, in bytes.
  ///
  /// This size excludes the 10-byte header itself and any footer.
  /// The size is encoded as a synchsafe integer in the header.
  final int tagSize;

  /// Creates an ID3v2 header with the specified properties.
  const Id3v2Header({
    required this.majorVersion,
    required this.minorVersion,
    required this.flags,
    required this.tagSize,
  });

  /// The full version string (e.g., "2.4", "2.3").
  String get version => '$majorVersion.$minorVersion';

  /// Whether this header indicates an extended header is present.
  bool get hasExtendedHeader => flags.extendedHeader;

  /// Whether unsynchronization is applied to the tag data.
  bool get isUnsynchronized => flags.unsynchronization;

  /// The total size of the tag including the header (and footer if present).
  int get totalSize {
    var size = 10 + tagSize; // Header + tag data
    if (flags.footer) {
      size += 10; // Footer is same size as header
    }
    return size;
  }

  @override
  String toString() {
    return 'Id3v2Header(version: $version, flags: $flags, tagSize: $tagSize)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2Header &&
          runtimeType == other.runtimeType &&
          majorVersion == other.majorVersion &&
          minorVersion == other.minorVersion &&
          flags == other.flags &&
          tagSize == other.tagSize;

  @override
  int get hashCode => Object.hash(majorVersion, minorVersion, flags, tagSize);
}

/// Represents an ID3v2.4 extended header.
///
/// Extended headers provide additional metadata about the tag structure
/// and processing requirements. They are optional and indicated by the
/// extended header flag in the main header.
class Id3v2ExtendedHeader {
  /// The size of the extended header, including the size field itself.
  final int size;

  /// The number of flag bytes that follow.
  final int flagBytes;

  /// The extended flags byte.
  final int flags;

  /// Whether the tag is an update of a previous tag.
  final bool tagIsUpdate;

  /// Whether CRC-32 data is present.
  final bool crcDataPresent;

  /// Whether tag restrictions are present.
  final bool tagRestrictions;

  /// The CRC-32 value if present.
  final int? crc32;

  /// The tag restrictions byte if present.
  final int? restrictionsByte;

  /// Creates an ID3v2 extended header with the specified properties.
  const Id3v2ExtendedHeader({
    required this.size,
    required this.flagBytes,
    required this.flags,
    required this.tagIsUpdate,
    required this.crcDataPresent,
    required this.tagRestrictions,
    this.crc32,
    this.restrictionsByte,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (tagIsUpdate) parts.add('update');
    if (crcDataPresent) parts.add('crc');
    if (tagRestrictions) parts.add('restrictions');
    return 'Id3v2ExtendedHeader(size: $size, flags: ${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2ExtendedHeader &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          flagBytes == other.flagBytes &&
          flags == other.flags &&
          crc32 == other.crc32 &&
          restrictionsByte == other.restrictionsByte;

  @override
  int get hashCode => Object.hash(size, flagBytes, flags, crc32, restrictionsByte);
}

/// Utilities for parsing ID3v2 headers and extended headers.
class Id3v2HeaderParser {
  /// The expected ID3v2 signature bytes.
  static const List<int> id3Signature = [0x49, 0x44, 0x33]; // "ID3"

  /// The minimum size of an ID3v2 header (10 bytes).
  static const int headerSize = 10;

  /// Parses an ID3v2 header from the beginning of the provided bytes.
  ///
  /// This method validates the ID3v2 signature, version, and flags before
  /// parsing the tag size. It supports all major ID3v2 versions (2.2, 2.3, 2.4).
  ///
  /// ## Parameters
  /// - [bytes]: The byte data containing the ID3v2 header at the beginning
  ///
  /// ## Returns
  /// A parsed [Id3v2Header] object containing all header information
  ///
  /// ## Throws
  /// - [ArgumentError] if [bytes] is too short to contain a header
  /// - [CorruptedContainerException] if the signature is invalid
  /// - [FormatException] if the version or flags are invalid
  ///
  /// ## Example
  /// ```dart
  /// final headerBytes = Uint8List.fromList([
  ///   0x49, 0x44, 0x33, // "ID3"
  ///   0x04, 0x00,       // Version 2.4
  ///   0x00,             // No flags
  ///   0x00, 0x00, 0x1F, 0x76, // Size: 4086 bytes
  /// ]);
  /// final header = Id3v2HeaderParser.parseHeader(headerBytes);
  /// ```
  static Id3v2Header parseHeader(Uint8List bytes) {
    if (bytes.length < headerSize) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Insufficient bytes for ID3v2 header: need $headerSize, got ${bytes.length}',
      );
    }

    final reader = ByteReader(bytes);

    // Validate signature
    final signature = reader.readBytes(3);
    if (!_isValidSignature(signature)) {
      final found = String.fromCharCodes(signature);
      throw CorruptedContainerException(
        'Invalid ID3v2 signature: expected "ID3", found "$found"',
        byteOffset: 0,
        context: 'ID3v2 header parsing',
      );
    }

    // Parse version
    final majorVersion = reader.readUint8();
    final minorVersion = reader.readUint8();

    // Validate version
    if (majorVersion < 2 || majorVersion > 4) {
      throw FormatException(
        'Unsupported ID3v2 version: $majorVersion.$minorVersion '
        '(supported versions: 2.2, 2.3, 2.4)',
      );
    }

    if (majorVersion == 2 && minorVersion != 0) {
      throw FormatException(
        'Invalid ID3v2.2 minor version: $minorVersion (must be 0)',
      );
    }

    // Parse flags
    final flagsByte = reader.readUint8();
    final flags = Id3v2HeaderFlags.fromByte(flagsByte, majorVersion);

    // Parse tag size (synchsafe integer)
    final sizeBytes = reader.readBytes(4);
    final tagSize = SynchsafeInt.decodeBytes(sizeBytes);

    return Id3v2Header(
      majorVersion: majorVersion,
      minorVersion: minorVersion,
      flags: flags,
      tagSize: tagSize,
    );
  }

  /// Parses an ID3v2.4 extended header from the provided bytes.
  ///
  /// Extended headers are only supported in ID3v2.4 and provide additional
  /// metadata about the tag structure. This method should only be called
  /// when the main header indicates an extended header is present.
  ///
  /// ## Parameters
  /// - [bytes]: The byte data containing the extended header
  /// - [offset]: The starting position of the extended header (default: 0)
  ///
  /// ## Returns
  /// A parsed [Id3v2ExtendedHeader] object
  ///
  /// ## Throws
  /// - [ArgumentError] if [bytes] is too short for an extended header
  /// - [FormatException] if the extended header format is invalid
  ///
  /// ## Example
  /// ```dart
  /// // Assuming extendedHeaderBytes contains the extended header data
  /// final extHeader = Id3v2HeaderParser.parseExtendedHeader(extendedHeaderBytes);
  /// print('Extended header size: ${extHeader.size}');
  /// print('CRC present: ${extHeader.crcDataPresent}');
  /// ```
  static Id3v2ExtendedHeader parseExtendedHeader(Uint8List bytes, [int offset = 0]) {
    if (bytes.length < offset + 6) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Insufficient bytes for extended header: need at least ${offset + 6}, got ${bytes.length}',
      );
    }

    final reader = ByteReader(bytes);
    reader.seek(offset);

    // Parse extended header size (synchsafe integer)
    final sizeBytes = reader.readBytes(4);
    final size = SynchsafeInt.decodeBytes(sizeBytes);

    // Validate minimum size
    if (size < 6) {
      throw FormatException(
        'Invalid extended header size: $size (minimum is 6 bytes)',
      );
    }

    // Parse number of flag bytes
    final flagBytes = reader.readUint8();
    if (flagBytes != 1) {
      throw FormatException(
        'Invalid extended header flag bytes: $flagBytes (must be 1 for ID3v2.4)',
      );
    }

    // Parse extended flags
    final flags = reader.readUint8();

    // Validate that only defined flags are set
    if (flags & 0x8F != 0) {
      throw FormatException(
        'Invalid extended header flags: reserved bits set (0x${flags.toRadixString(16).padLeft(2, '0')})',
      );
    }

    final tagIsUpdate = (flags & 0x40) != 0;
    final crcDataPresent = (flags & 0x20) != 0;
    final tagRestrictions = (flags & 0x10) != 0;

    int? crc32;
    int? restrictionsByte;

    // Parse optional flag data
    if (tagIsUpdate) {
      // Tag is an update flag has no data
    }

    if (crcDataPresent) {
      if (reader.remaining < 5) {
        throw const FormatException('CRC data flag set but insufficient bytes for CRC-32');
      }
      final crcLength = reader.readUint8();
      if (crcLength != 4) {
        throw FormatException('Invalid CRC data length: $crcLength (must be 4)');
      }
      crc32 = reader.readUint32();
    }

    if (tagRestrictions) {
      if (reader.remaining < 1) {
        throw const FormatException('Tag restrictions flag set but no restrictions byte');
      }
      final restrictionsLength = reader.readUint8();
      if (restrictionsLength != 1) {
        throw FormatException('Invalid restrictions data length: $restrictionsLength (must be 1)');
      }
      restrictionsByte = reader.readUint8();
    }

    return Id3v2ExtendedHeader(
      size: size,
      flagBytes: flagBytes,
      flags: flags,
      tagIsUpdate: tagIsUpdate,
      crcDataPresent: crcDataPresent,
      tagRestrictions: tagRestrictions,
      crc32: crc32,
      restrictionsByte: restrictionsByte,
    );
  }

  /// Checks if the provided bytes contain a valid ID3v2 signature.
  ///
  /// This is a quick validation method that only checks the first 3 bytes
  /// for the "ID3" signature without parsing the full header.
  ///
  /// ## Parameters
  /// - [bytes]: The byte data to check
  ///
  /// ## Returns
  /// True if the bytes start with a valid ID3v2 signature
  ///
  /// ## Example
  /// ```dart
  /// final hasId3 = Id3v2HeaderParser.hasValidSignature(fileBytes);
  /// if (hasId3) {
  ///   final header = Id3v2HeaderParser.parseHeader(fileBytes);
  /// }
  /// ```
  static bool hasValidSignature(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return _isValidSignature(bytes.sublist(0, 3));
  }

  /// Detects if unsynchronization is applied to the tag data.
  ///
  /// This method analyzes the tag data to determine if unsynchronization
  /// has been applied. Unsynchronized data contains special encoding to
  /// prevent false MP3 frame sync patterns.
  ///
  /// ## Parameters
  /// - [tagData]: The tag data bytes to analyze
  /// - [header]: The parsed header containing unsynchronization flag
  ///
  /// ## Returns
  /// True if unsynchronization is detected in the data
  ///
  /// ## Example
  /// ```dart
  /// final isUnsync = Id3v2HeaderParser.detectUnsynchronization(tagData, header);
  /// if (isUnsync) {
  ///   // Handle unsynchronized data
  /// }
  /// ```
  static bool detectUnsynchronization(Uint8List tagData, Id3v2Header header) {
    // If the header flag is set, trust it
    if (header.flags.unsynchronization) {
      return true;
    }

    // For ID3v2.4, unsynchronization can be applied per frame
    // Look for the unsynchronization pattern: 0xFF 0x00
    for (int i = 0; i < tagData.length - 1; i++) {
      if (tagData[i] == 0xFF && tagData[i + 1] == 0x00) {
        return true;
      }
    }

    return false;
  }

  /// Validates that the signature bytes match the expected ID3v2 signature.
  static bool _isValidSignature(Uint8List signature) {
    if (signature.length != 3) return false;
    for (int i = 0; i < 3; i++) {
      if (signature[i] != id3Signature[i]) return false;
    }
    return true;
  }
}
