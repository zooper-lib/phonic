import 'dart:typed_data';

import '../../core/artwork_data.dart';
import '../../core/artwork_type.dart';
import '../../core/text_encoding.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';
import '../../utils/lazy_artwork_loader.dart';
import '../../utils/text_encoding_utils.dart';

/// Utilities for parsing ID3v2 APIC (Attached Picture) frames.
///
/// APIC frames contain artwork/image data with the following structure:
/// - Text encoding (1 byte)
/// - MIME type (null-terminated string)
/// - Picture type (1 byte)
/// - Description (null-terminated string in specified encoding)
/// - Picture data (remaining bytes)
///
/// ## ID3v2 APIC Frame Structure
///
/// ```
/// Offset  Length      Description
/// 0       1           Text encoding ($00 = ISO-8859-1, $01 = UTF-16, $02 = UTF-16BE, $03 = UTF-8)
/// 1       Variable    MIME type (null-terminated ISO-8859-1 string)
/// N       1           Picture type (see ArtworkType mapping)
/// N+1     Variable    Description (null-terminated string in specified encoding)
/// M       Variable    Picture data (actual image bytes)
/// ```
///
/// ## Picture Type Mapping
///
/// The APIC frame uses numeric picture type codes that map to [ArtworkType] values:
/// - 0x00: Other
/// - 0x01: 32x32 pixels 'file icon' (PNG only)
/// - 0x02: Other file icon
/// - 0x03: Cover (front) → [ArtworkType.frontCover]
/// - 0x04: Cover (back) → [ArtworkType.backCover]
/// - 0x05: Leaflet page → [ArtworkType.leaflet]
/// - 0x06: Media (e.g. label side of CD) → [ArtworkType.media]
/// - 0x07: Lead artist/lead performer/soloist → [ArtworkType.leadArtist]
/// - 0x08: Artist/performer → [ArtworkType.artist]
/// - 0x09: Conductor → [ArtworkType.conductor]
/// - 0x0A: Band/Orchestra → [ArtworkType.band]
/// - 0x0B: Composer → [ArtworkType.composer]
/// - 0x0C: Lyricist/text writer → [ArtworkType.lyricist]
/// - 0x0D: Recording Location → [ArtworkType.recordingLocation]
/// - 0x0E: During recording → [ArtworkType.duringRecording]
/// - 0x0F: During performance → [ArtworkType.duringPerformance]
/// - 0x10: Movie/video screen capture → [ArtworkType.movieScreenCapture]
/// - 0x11: A bright coloured fish → [ArtworkType.brightColoredFish]
/// - 0x12: Illustration → [ArtworkType.illustration]
/// - 0x13: Band/artist logotype → [ArtworkType.bandLogotype]
/// - 0x14: Publisher/Studio logotype → [ArtworkType.publisherLogotype]
///
/// ## Text Encoding Support
///
/// APIC frames support different text encodings for the description field:
/// - ID3v2.2/2.3: ISO-8859-1 ($00) and UTF-16 with BOM ($01)
/// - ID3v2.4: Additionally supports UTF-16BE ($02) and UTF-8 ($03)
///
/// The MIME type is always encoded in ISO-8859-1 regardless of the encoding byte.
///
/// ## Lazy Loading
///
/// The parser implements lazy loading for the actual image data to minimize
/// memory usage when scanning large collections. The image data is only
/// loaded when explicitly requested through the [ArtworkData.data] getter.
///
/// ## Example Usage
///
/// ```dart
/// final frameData = Uint8List.fromList([
///   0x00,                           // ISO-8859-1 encoding
///   0x69, 0x6D, 0x61, 0x67, 0x65, 0x2F, 0x6A, 0x70, 0x65, 0x67, 0x00, // "image/jpeg\0"
///   0x03,                           // Front cover
///   0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x63, 0x6F, 0x76, 0x65, 0x72, 0x00, // "Album cover\0"
///   0xFF, 0xD8, 0xFF, 0xE0, ...    // JPEG image data
/// ]);
///
/// final apic = Id3v2ApicFrameParser.parse(frameData, 4);
/// print('MIME Type: ${apic.artworkData.mimeType}');
/// print('Type: ${apic.artworkData.type}');
/// print('Description: ${apic.artworkData.description}');
///
/// // Load image data when needed
/// final imageBytes = await apic.artworkData.data;
/// print('Image size: ${imageBytes.length} bytes');
/// ```

/// Result of parsing APIC (Attached Picture) frame data.
class Id3v2ApicFrameData {
  /// The parsed artwork data with lazy loading support.
  final ArtworkData artworkData;

  /// The text encoding used for the description field.
  final int encodingByte;

  /// The raw picture type byte from the frame.
  final int pictureTypeByte;

  /// Creates APIC frame data with the specified properties.
  const Id3v2ApicFrameData({
    required this.artworkData,
    required this.encodingByte,
    required this.pictureTypeByte,
  });

  @override
  String toString() {
    return 'Id3v2ApicFrameData(mimeType: ${artworkData.mimeType}, '
        'type: ${artworkData.type}, description: "${artworkData.description}", '
        'encoding: 0x${encodingByte.toRadixString(16).padLeft(2, '0')}, '
        'pictureType: 0x${pictureTypeByte.toRadixString(16).padLeft(2, '0')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2ApicFrameData &&
          runtimeType == other.runtimeType &&
          artworkData == other.artworkData &&
          encodingByte == other.encodingByte &&
          pictureTypeByte == other.pictureTypeByte;

  @override
  int get hashCode => Object.hash(artworkData, encodingByte, pictureTypeByte);
}

/// Parser for ID3v2 APIC (Attached Picture) frames.
class Id3v2ApicFrameParser {
  /// Maps ID3v2 APIC picture type bytes to [ArtworkType] enum values.
  static const Map<int, ArtworkType> _pictureTypeMap = {
    0x03: ArtworkType.frontCover,
    0x04: ArtworkType.backCover,
    0x05: ArtworkType.leaflet,
    0x06: ArtworkType.media,
    0x07: ArtworkType.leadArtist,
    0x08: ArtworkType.artist,
    0x09: ArtworkType.conductor,
    0x0A: ArtworkType.band,
    0x0B: ArtworkType.composer,
    0x0C: ArtworkType.lyricist,
    0x0D: ArtworkType.recordingLocation,
    0x0E: ArtworkType.duringRecording,
    0x0F: ArtworkType.duringPerformance,
    0x10: ArtworkType.movieScreenCapture,
    0x11: ArtworkType.brightColoredFish,
    0x12: ArtworkType.illustration,
    0x13: ArtworkType.bandLogotype,
    0x14: ArtworkType.publisherLogotype,
  };

  /// Maps [ArtworkType] enum values back to ID3v2 APIC picture type bytes.
  static const Map<ArtworkType, int> _artworkTypeMap = {
    ArtworkType.frontCover: 0x03,
    ArtworkType.backCover: 0x04,
    ArtworkType.leaflet: 0x05,
    ArtworkType.media: 0x06,
    ArtworkType.leadArtist: 0x07,
    ArtworkType.artist: 0x08,
    ArtworkType.conductor: 0x09,
    ArtworkType.band: 0x0A,
    ArtworkType.composer: 0x0B,
    ArtworkType.lyricist: 0x0C,
    ArtworkType.recordingLocation: 0x0D,
    ArtworkType.duringRecording: 0x0E,
    ArtworkType.duringPerformance: 0x0F,
    ArtworkType.movieScreenCapture: 0x10,
    ArtworkType.brightColoredFish: 0x11,
    ArtworkType.illustration: 0x12,
    ArtworkType.bandLogotype: 0x13,
    ArtworkType.publisherLogotype: 0x14,
  };

  /// Parses an APIC (Attached Picture) frame from frame data.
  ///
  /// APIC frames contain artwork/image data with the following structure:
  /// - Text encoding (1 byte)
  /// - MIME type (null-terminated string)
  /// - Picture type (1 byte)
  /// - Description (null-terminated string in specified encoding)
  /// - Picture data (remaining bytes)
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  /// - [majorVersion]: The ID3v2 major version (2, 3, or 4) for encoding validation
  ///
  /// ## Returns
  /// An [Id3v2ApicFrameData] object containing the parsed artwork information
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is too short for a valid APIC frame
  /// - [CorruptedContainerException] if the frame format is invalid
  /// - [FormatException] if the encoding byte is invalid for the version
  ///
  /// ## Example
  /// ```dart
  /// final apicData = Uint8List.fromList([
  ///   0x00,                           // ISO-8859-1 encoding
  ///   0x69, 0x6D, 0x61, 0x67, 0x65, 0x2F, 0x6A, 0x70, 0x65, 0x67, 0x00, // "image/jpeg\0"
  ///   0x03,                           // Front cover
  ///   0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x63, 0x6F, 0x76, 0x65, 0x72, 0x00, // "Album cover\0"
  ///   0xFF, 0xD8, 0xFF, 0xE0, ...    // JPEG image data
  /// ]);
  /// final apic = Id3v2ApicFrameParser.parse(apicData, 4);
  /// print('MIME Type: ${apic.artworkData.mimeType}'); // "image/jpeg"
  /// print('Type: ${apic.artworkData.type}'); // ArtworkType.frontCover
  /// print('Description: ${apic.artworkData.description}'); // "Album cover"
  /// ```
  static Id3v2ApicFrameData parse(Uint8List frameData, int majorVersion) {
    if (frameData.length < 4) {
      throw ArgumentError.value(
        frameData.length,
        'frameData.length',
        'APIC frame data must be at least 4 bytes (encoding + MIME type + picture type + description)',
      );
    }

    final reader = ByteReader(frameData);

    // Parse text encoding byte
    final encodingByte = reader.readUint8();
    _validateEncodingByte(encodingByte, majorVersion);

    // Parse MIME type (always ISO-8859-1, null-terminated)
    final mimeType = _parseNullTerminatedString(reader, isIso88591: true);
    if (mimeType.isEmpty) {
      throw const CorruptedContainerException(
        'APIC frame MIME type cannot be empty',
        context: 'ID3v2 APIC frame parsing',
      );
    }

    // Parse picture type byte
    if (reader.remaining < 1) {
      throw const CorruptedContainerException(
        'APIC frame missing picture type byte',
        context: 'ID3v2 APIC frame parsing',
      );
    }
    final pictureTypeByte = reader.readUint8();

    // Parse description (null-terminated string in specified encoding)
    final description = _parseDescriptionString(reader, encodingByte);

    // Remaining bytes are the picture data
    if (reader.remaining == 0) {
      throw const CorruptedContainerException(
        'APIC frame missing picture data',
        context: 'ID3v2 APIC frame parsing',
      );
    }

    // Create lazy loader for the picture data
    final pictureDataOffset = reader.position;
    final pictureDataLength = reader.remaining;
    final lazyLoader = LazyArtworkLoader(
      frameData,
      pictureDataOffset,
      pictureDataLength,
    );

    // Map picture type byte to ArtworkType
    final artworkType = _pictureTypeMap[pictureTypeByte] ?? ArtworkType.frontCover;

    // Create ArtworkData with lazy loading
    final artworkData = ArtworkData(
      mimeType: mimeType,
      type: artworkType,
      description: description.isEmpty ? null : description,
      dataLoader: () => lazyLoader.load(),
    );

    return Id3v2ApicFrameData(
      artworkData: artworkData,
      encodingByte: encodingByte,
      pictureTypeByte: pictureTypeByte,
    );
  }

  /// Validates that the encoding byte is valid for the specified ID3v2 version.
  static void _validateEncodingByte(int encodingByte, int majorVersion) {
    switch (encodingByte) {
      case 0x00: // ISO-8859-1
      case 0x01: // UTF-16 with BOM
        // Supported in all versions
        break;
      case 0x02: // UTF-16BE
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        break;
      case 0x03: // UTF-8
        if (majorVersion < 4) {
          throw FormatException(
            'Encoding 0x03 (UTF-8) is only supported in ID3v2.4, got version $majorVersion',
          );
        }
        break;
      default:
        throw FormatException(
          'Invalid text encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')} '
          'for ID3v2.$majorVersion',
        );
    }
  }

  /// Parses a null-terminated string from the byte reader.
  static String _parseNullTerminatedString(ByteReader reader, {bool isIso88591 = false}) {
    final bytes = <int>[];

    while (reader.remaining > 0) {
      final byte = reader.readUint8();
      if (byte == 0) {
        break; // Found null terminator
      }
      bytes.add(byte);
    }

    if (isIso88591) {
      // MIME type is always ISO-8859-1
      return String.fromCharCodes(bytes);
    } else {
      // For other strings, assume ISO-8859-1 as fallback
      return String.fromCharCodes(bytes);
    }
  }

  /// Parses the description string using the specified text encoding.
  static String _parseDescriptionString(ByteReader reader, int encodingByte) {
    switch (encodingByte) {
      case 0x00: // ISO-8859-1
        return _parseNullTerminatedString(reader, isIso88591: true);

      case 0x01: // UTF-16 with BOM
        return _parseUtf16String(reader);

      case 0x02: // UTF-16BE
        return _parseUtf16BeString(reader);

      case 0x03: // UTF-8
        return _parseUtf8String(reader);

      default:
        throw FormatException(
          'Invalid encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')}',
        );
    }
  }

  /// Parses a UTF-16 string with BOM from the byte reader.
  static String _parseUtf16String(ByteReader reader) {
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
        'Failed to decode UTF-16 description: $e',
        context: 'ID3v2 APIC frame parsing',
      );
    }
  }

  /// Parses a UTF-16BE string from the byte reader.
  static String _parseUtf16BeString(ByteReader reader) {
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
        'Failed to decode UTF-16BE description: $e',
        context: 'ID3v2 APIC frame parsing',
      );
    }
  }

  /// Parses a UTF-8 string from the byte reader.
  static String _parseUtf8String(ByteReader reader) {
    final bytes = <int>[];

    // Read until we find null terminator
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
        'Failed to decode UTF-8 description: $e',
        context: 'ID3v2 APIC frame parsing',
      );
    }
  }

  /// Validates that an APIC frame data structure is valid.
  ///
  /// ## Parameters
  /// - [apicData]: The APIC frame data to validate
  ///
  /// ## Returns
  /// `true` if the data is valid, `false` otherwise
  static bool isValid(Id3v2ApicFrameData apicData) {
    // MIME type should not be empty
    if (apicData.artworkData.mimeType.isEmpty) {
      return false;
    }

    // MIME type should not contain null bytes
    if (apicData.artworkData.mimeType.contains('\x00')) {
      return false;
    }

    // Description should not contain null bytes (they're used as terminators)
    if (apicData.artworkData.description?.contains('\x00') == true) {
      return false;
    }

    // Encoding byte should be valid
    if (apicData.encodingByte < 0 || apicData.encodingByte > 3) {
      return false;
    }

    return true;
  }

  /// Encodes APIC frame data back to bytes for writing to ID3v2 tags.
  ///
  /// ## Parameters
  /// - [apicData]: The APIC frame data to encode
  /// - [majorVersion]: The ID3v2 major version for encoding compatibility
  ///
  /// ## Returns
  /// The encoded frame data as bytes
  ///
  /// ## Throws
  /// - [ArgumentError] if the APIC data is invalid
  /// - [FormatException] if the encoding is not supported in the version
  static Future<Uint8List> encode(Id3v2ApicFrameData apicData, int majorVersion) async {
    if (!isValid(apicData)) {
      throw ArgumentError('Invalid APIC frame data: $apicData');
    }

    _validateEncodingByte(apicData.encodingByte, majorVersion);

    final bytes = <int>[];

    // Add encoding byte
    bytes.add(apicData.encodingByte);

    // Add MIME type (always ISO-8859-1, null-terminated)
    bytes.addAll(apicData.artworkData.mimeType.codeUnits);
    bytes.add(0); // Null terminator

    // Add picture type byte
    bytes.add(apicData.pictureTypeByte);

    // Add description (null-terminated in specified encoding)
    final description = apicData.artworkData.description ?? '';
    final descriptionBytes = _encodeDescriptionString(description, apicData.encodingByte);
    bytes.addAll(descriptionBytes);

    // Add null terminator for description
    if (apicData.encodingByte == 0x01 || apicData.encodingByte == 0x02) {
      // UTF-16 uses 2-byte null terminator
      bytes.add(0);
      bytes.add(0);
    } else {
      // ISO-8859-1 and UTF-8 use 1-byte null terminator
      bytes.add(0);
    }

    // Add picture data
    final pictureData = await apicData.artworkData.data;
    bytes.addAll(pictureData);

    return Uint8List.fromList(bytes);
  }

  /// Encodes a description string using the specified text encoding.
  static List<int> _encodeDescriptionString(String description, int encodingByte) {
    switch (encodingByte) {
      case 0x00: // ISO-8859-1
        return description.codeUnits;

      case 0x01: // UTF-16 with BOM
        return TextEncodingUtils.encodeText(description, TextEncoding.utf16).toList();

      case 0x02: // UTF-16BE
        return TextEncodingUtils.encodeText(description, TextEncoding.utf16be).toList();

      case 0x03: // UTF-8
        return TextEncodingUtils.encodeText(description, TextEncoding.utf8, includeBom: false).toList();

      default:
        throw FormatException(
          'Invalid encoding byte: 0x${encodingByte.toRadixString(16).padLeft(2, '0')}',
        );
    }
  }

  /// Gets the picture type byte for the specified [ArtworkType].
  ///
  /// Returns 0x00 (Other) if the artwork type is not recognized.
  static int getPictureTypeByte(ArtworkType artworkType) {
    return _artworkTypeMap[artworkType] ?? 0x00;
  }

  /// Gets the [ArtworkType] for the specified picture type byte.
  ///
  /// Returns [ArtworkType.frontCover] if the picture type is not recognized.
  static ArtworkType getArtworkType(int pictureTypeByte) {
    return _pictureTypeMap[pictureTypeByte] ?? ArtworkType.frontCover;
  }
}
