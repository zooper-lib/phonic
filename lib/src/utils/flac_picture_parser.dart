import 'dart:convert';
import 'dart:typed_data';

import '../core/artwork_data.dart';
import '../core/artwork_type.dart';
import '../utils/byte_reader.dart';
import '../utils/lazy_artwork_loader.dart';

/// Parser for FLAC METADATA_BLOCK_PICTURE blocks.
///
/// This class handles parsing of FLAC METADATA_BLOCK_PICTURE blocks which contain
/// embedded artwork data. The METADATA_BLOCK_PICTURE format is defined in the
/// FLAC specification and provides a standardized way to embed images in FLAC files.
///
/// ## METADATA_BLOCK_PICTURE Structure
///
/// The METADATA_BLOCK_PICTURE block has the following binary structure:
/// ```
/// <32> Picture type
/// <32> MIME type length
/// <n*8> MIME type string (UTF-8)
/// <32> Description length
/// <n*8> Description string (UTF-8)
/// <32> Picture width in pixels
/// <32> Picture height in pixels
/// <32> Color depth in bits-per-pixel
/// <32> Number of colors used (0 for non-indexed)
/// <32> Picture data length
/// <n*8> Picture data
/// ```
///
/// ## Picture Types
///
/// The picture type field uses the same values as ID3v2 APIC frames:
/// - 0x00: Other
/// - 0x01: 32x32 pixels 'file icon' (PNG only)
/// - 0x02: Other file icon
/// - 0x03: Cover (front)
/// - 0x04: Cover (back)
/// - 0x05: Leaflet page
/// - 0x06: Media (e.g. label side of CD)
/// - 0x07: Lead artist/lead performer/soloist
/// - 0x08: Artist/performer
/// - 0x09: Conductor
/// - 0x0A: Band/Orchestra
/// - 0x0B: Composer
/// - 0x0C: Lyricist/text writer
/// - 0x0D: Recording Location
/// - 0x0E: During recording
/// - 0x0F: During performance
/// - 0x10: Movie/video screen capture
/// - 0x11: A bright coloured fish
/// - 0x12: Illustration
/// - 0x13: Band/artist logotype
/// - 0x14: Publisher/Studio logotype
///
/// ## Usage Example
///
/// ```dart
/// final parser = FlacPictureParser();
/// final pictureBlockBytes = getMetadataBlockPictureBytes();
///
/// // Parse the picture block
/// final artworkData = parser.parsePictureBlock(pictureBlockBytes);
///
/// print('MIME Type: ${artworkData.mimeType}');
/// print('Type: ${artworkData.type}');
/// print('Description: ${artworkData.description}');
///
/// // Load the actual image data when needed
/// final imageBytes = await artworkData.data;
/// print('Image size: ${imageBytes.length} bytes');
/// ```
///
/// ## Memory Efficiency
///
/// The parser uses lazy loading for the actual image data through [LazyArtworkLoader].
/// This means:
/// - Metadata can be examined without loading the full image data
/// - Memory usage remains low when scanning large collections
/// - Image data is only loaded when actually needed
/// - Multiple references to the same artwork share the same loader
///
/// ## Error Handling
///
/// The parser validates the block structure and handles various error conditions:
/// - Insufficient data for required fields
/// - Invalid UTF-8 encoding in MIME type or description
/// - Malformed block structure
/// - Picture data bounds validation
///
/// ## Thread Safety
///
/// This class is stateless and thread-safe. Multiple threads can safely
/// use the same instance concurrently for parsing different picture blocks.
class FlacPictureParser {
  /// Creates a new FLAC picture parser instance.
  ///
  /// The parser is stateless and thread-safe, suitable for concurrent use
  /// across multiple files and operations.
  const FlacPictureParser();

  /// Parses a METADATA_BLOCK_PICTURE block and returns [ArtworkData].
  ///
  /// This method parses the complete METADATA_BLOCK_PICTURE structure including
  /// all metadata fields and creates a lazy loader for the image data.
  ///
  /// Parameters:
  /// - [blockBytes]: The raw METADATA_BLOCK_PICTURE block bytes
  ///
  /// Returns an [ArtworkData] object with parsed metadata and lazy image loading.
  ///
  /// Throws [FormatException] if the block is malformed or cannot be parsed.
  /// Throws [ArgumentError] if [blockBytes] is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final parser = FlacPictureParser();
  /// final artworkData = parser.parsePictureBlock(pictureBlockBytes);
  ///
  /// // Access metadata immediately
  /// print('MIME Type: ${artworkData.mimeType}');
  /// print('Description: ${artworkData.description}');
  ///
  /// // Load image data when needed
  /// final imageBytes = await artworkData.data;
  /// ```
  ArtworkData parsePictureBlock(Uint8List blockBytes) {
    if (blockBytes.isEmpty) {
      throw ArgumentError.value(blockBytes, 'blockBytes', 'Picture block bytes cannot be empty');
    }

    final reader = ByteReader(blockBytes);

    try {
      // Parse picture type (32-bit big-endian)
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for picture type field');
      }
      final pictureTypeValue = reader.readUint32(Endian.big);
      final artworkType = _mapPictureTypeToArtworkType(pictureTypeValue);

      // Parse MIME type length and string
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for MIME type length field');
      }
      final mimeTypeLength = reader.readUint32(Endian.big);

      if (mimeTypeLength > reader.remaining) {
        throw FormatException('MIME type length ($mimeTypeLength) exceeds remaining data (${reader.remaining})');
      }

      final mimeType = reader.readString(mimeTypeLength, utf8);
      if (mimeType.isEmpty) {
        throw const FormatException('MIME type cannot be empty');
      }

      // Parse description length and string
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for description length field');
      }
      final descriptionLength = reader.readUint32(Endian.big);

      if (descriptionLength > reader.remaining) {
        throw FormatException('Description length ($descriptionLength) exceeds remaining data (${reader.remaining})');
      }

      final description = descriptionLength > 0 ? reader.readString(descriptionLength, utf8) : null;

      // Parse picture width (32-bit big-endian)
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for picture width field');
      }
      reader.readUint32(Endian.big); // Skip picture width

      // Parse picture height (32-bit big-endian)
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for picture height field');
      }
      reader.readUint32(Endian.big); // Skip picture height

      // Parse color depth (32-bit big-endian)
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for color depth field');
      }
      reader.readUint32(Endian.big); // Skip color depth

      // Parse number of colors (32-bit big-endian)
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for number of colors field');
      }
      reader.readUint32(Endian.big); // Skip number of colors

      // Parse picture data length
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient data for picture data length field');
      }
      final pictureDataLength = reader.readUint32(Endian.big);

      if (pictureDataLength > reader.remaining) {
        throw FormatException('Picture data length ($pictureDataLength) exceeds remaining data (${reader.remaining})');
      }

      if (pictureDataLength == 0) {
        throw const FormatException('Picture data length cannot be zero');
      }

      // Create lazy loader for the picture data
      final pictureDataOffset = reader.position;
      final lazyLoader = LazyArtworkLoader(
        blockBytes,
        pictureDataOffset,
        pictureDataLength,
      );

      // Create and return ArtworkData with lazy loading
      return ArtworkData(
        mimeType: mimeType,
        type: artworkType,
        description: description?.isNotEmpty == true ? description : null,
        dataLoader: () => lazyLoader.load(),
      );
    } catch (e) {
      if (e is FormatException || e is ArgumentError) {
        rethrow;
      }
      throw FormatException('Failed to parse METADATA_BLOCK_PICTURE: $e');
    }
  }

  /// Maps FLAC picture type values to [ArtworkType] enum values.
  ///
  /// The FLAC specification uses the same picture type values as ID3v2 APIC frames.
  /// This method provides the mapping between numeric values and the enum.
  ///
  /// Parameters:
  /// - [pictureTypeValue]: The numeric picture type value from the FLAC block
  ///
  /// Returns the corresponding [ArtworkType] enum value.
  /// Returns [ArtworkType.frontCover] for unknown or invalid values.
  ArtworkType _mapPictureTypeToArtworkType(int pictureTypeValue) {
    switch (pictureTypeValue) {
      case 0x03:
        return ArtworkType.frontCover;
      case 0x04:
        return ArtworkType.backCover;
      case 0x05:
        return ArtworkType.leaflet;
      case 0x06:
        return ArtworkType.media;
      case 0x07:
        return ArtworkType.leadArtist;
      case 0x08:
        return ArtworkType.artist;
      case 0x09:
        return ArtworkType.conductor;
      case 0x0A:
        return ArtworkType.band;
      case 0x0B:
        return ArtworkType.composer;
      case 0x0C:
        return ArtworkType.lyricist;
      case 0x0D:
        return ArtworkType.recordingLocation;
      case 0x0E:
        return ArtworkType.duringRecording;
      case 0x0F:
        return ArtworkType.duringPerformance;
      case 0x10:
        return ArtworkType.movieScreenCapture;
      case 0x11:
        return ArtworkType.brightColoredFish;
      case 0x12:
        return ArtworkType.illustration;
      case 0x13:
        return ArtworkType.bandLogotype;
      case 0x14:
        return ArtworkType.publisherLogotype;
      default:
        // For unknown types, default to front cover
        return ArtworkType.frontCover;
    }
  }

  /// Maps [ArtworkType] enum values to FLAC picture type numeric values.
  ///
  /// This method provides the reverse mapping for encoding METADATA_BLOCK_PICTURE
  /// blocks when writing FLAC files.
  ///
  /// Parameters:
  /// - [artworkType]: The [ArtworkType] enum value to map
  ///
  /// Returns the corresponding numeric picture type value for FLAC.
  int mapArtworkTypeToFlacPictureType(ArtworkType artworkType) {
    switch (artworkType) {
      case ArtworkType.frontCover:
        return 0x03;
      case ArtworkType.backCover:
        return 0x04;
      case ArtworkType.leaflet:
        return 0x05;
      case ArtworkType.media:
        return 0x06;
      case ArtworkType.leadArtist:
        return 0x07;
      case ArtworkType.artist:
        return 0x08;
      case ArtworkType.conductor:
        return 0x09;
      case ArtworkType.band:
        return 0x0A;
      case ArtworkType.composer:
        return 0x0B;
      case ArtworkType.lyricist:
        return 0x0C;
      case ArtworkType.recordingLocation:
        return 0x0D;
      case ArtworkType.duringRecording:
        return 0x0E;
      case ArtworkType.duringPerformance:
        return 0x0F;
      case ArtworkType.movieScreenCapture:
        return 0x10;
      case ArtworkType.brightColoredFish:
        return 0x11;
      case ArtworkType.illustration:
        return 0x12;
      case ArtworkType.bandLogotype:
        return 0x13;
      case ArtworkType.publisherLogotype:
        return 0x14;
    }
  }

  /// Validates a METADATA_BLOCK_PICTURE block structure without full parsing.
  ///
  /// This method performs basic validation of the block structure to check
  /// if it appears to be a valid METADATA_BLOCK_PICTURE block. This is useful
  /// for quick validation without the overhead of full parsing.
  ///
  /// Parameters:
  /// - [blockBytes]: The raw METADATA_BLOCK_PICTURE block bytes
  ///
  /// Returns true if the block appears to be valid, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final parser = FlacPictureParser();
  /// if (parser.isValidPictureBlock(blockBytes)) {
  ///   final artworkData = parser.parsePictureBlock(blockBytes);
  ///   // Process artwork data
  /// }
  /// ```
  bool isValidPictureBlock(Uint8List blockBytes) {
    if (blockBytes.length < 32) {
      // Minimum size: 8 * 4-byte fields = 32 bytes (without any strings or data)
      return false;
    }

    try {
      final reader = ByteReader(blockBytes);

      // Check picture type (should be reasonable value)
      final pictureType = reader.readUint32(Endian.big);
      if (pictureType > 0x14) {
        return false; // Unknown picture type
      }

      // Check MIME type length and validate it's reasonable
      final mimeTypeLength = reader.readUint32(Endian.big);
      if (mimeTypeLength == 0 || mimeTypeLength > 100) {
        return false; // MIME type should be present and reasonable length
      }

      if (mimeTypeLength > reader.remaining) {
        return false; // MIME type length exceeds remaining data
      }

      // Skip MIME type string
      reader.skip(mimeTypeLength);

      // Check description length
      final descriptionLength = reader.readUint32(Endian.big);
      if (descriptionLength > reader.remaining) {
        return false; // Description length exceeds remaining data
      }

      // Skip description string
      reader.skip(descriptionLength);

      // Skip width, height, color depth, number of colors (4 * 4 bytes = 16 bytes)
      if (reader.remaining < 16) {
        return false;
      }
      reader.skip(16);

      // Check picture data length
      if (reader.remaining < 4) {
        return false;
      }
      final pictureDataLength = reader.readUint32(Endian.big);
      if (pictureDataLength == 0 || pictureDataLength != reader.remaining) {
        return false; // Picture data length should match remaining bytes
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extracts basic metadata from a METADATA_BLOCK_PICTURE block without creating [ArtworkData].
  ///
  /// This method provides a lightweight way to extract just the metadata fields
  /// without creating the full [ArtworkData] object or lazy loader. Useful for
  /// quick metadata inspection or filtering.
  ///
  /// Parameters:
  /// - [blockBytes]: The raw METADATA_BLOCK_PICTURE block bytes
  ///
  /// Returns a [FlacPictureMetadata] object with the extracted metadata.
  ///
  /// Throws [FormatException] if the block is malformed or cannot be parsed.
  ///
  /// Example:
  /// ```dart
  /// final parser = FlacPictureParser();
  /// final metadata = parser.extractMetadata(blockBytes);
  ///
  /// print('MIME Type: ${metadata.mimeType}');
  /// print('Type: ${metadata.artworkType}');
  /// print('Dimensions: ${metadata.width}x${metadata.height}');
  /// print('Data size: ${metadata.dataLength} bytes');
  /// ```
  FlacPictureMetadata extractMetadata(Uint8List blockBytes) {
    if (blockBytes.isEmpty) {
      throw ArgumentError.value(blockBytes, 'blockBytes', 'Picture block bytes cannot be empty');
    }

    final reader = ByteReader(blockBytes);

    try {
      // Parse picture type
      final pictureTypeValue = reader.readUint32(Endian.big);
      final artworkType = _mapPictureTypeToArtworkType(pictureTypeValue);

      // Parse MIME type
      final mimeTypeLength = reader.readUint32(Endian.big);
      final mimeType = reader.readString(mimeTypeLength, utf8);

      // Parse description
      final descriptionLength = reader.readUint32(Endian.big);
      final description = descriptionLength > 0 ? reader.readString(descriptionLength, utf8) : null;

      // Parse dimensions and color info
      final width = reader.readUint32(Endian.big);
      final height = reader.readUint32(Endian.big);
      final colorDepth = reader.readUint32(Endian.big);
      final numberOfColors = reader.readUint32(Endian.big);

      // Parse data length
      final dataLength = reader.readUint32(Endian.big);

      return FlacPictureMetadata(
        artworkType: artworkType,
        mimeType: mimeType,
        description: description?.isNotEmpty == true ? description : null,
        width: width,
        height: height,
        colorDepth: colorDepth,
        numberOfColors: numberOfColors,
        dataLength: dataLength,
      );
    } catch (e) {
      if (e is FormatException || e is ArgumentError) {
        rethrow;
      }
      throw FormatException('Failed to extract METADATA_BLOCK_PICTURE metadata: $e');
    }
  }
}

/// Metadata extracted from a FLAC METADATA_BLOCK_PICTURE block.
///
/// This class contains all the metadata fields from a METADATA_BLOCK_PICTURE
/// block without the actual image data. It's useful for quick metadata
/// inspection and filtering without the overhead of creating full [ArtworkData]
/// objects.
class FlacPictureMetadata {
  /// The artwork type classification.
  final ArtworkType artworkType;

  /// The MIME type of the image data.
  final String mimeType;

  /// Optional description of the artwork.
  final String? description;

  /// Picture width in pixels.
  final int width;

  /// Picture height in pixels.
  final int height;

  /// Color depth in bits per pixel.
  final int colorDepth;

  /// Number of colors used (0 for non-indexed images).
  final int numberOfColors;

  /// Length of the picture data in bytes.
  final int dataLength;

  /// Creates new FLAC picture metadata.
  const FlacPictureMetadata({
    required this.artworkType,
    required this.mimeType,
    this.description,
    required this.width,
    required this.height,
    required this.colorDepth,
    required this.numberOfColors,
    required this.dataLength,
  });

  /// Returns true if this is an indexed color image.
  bool get isIndexedColor => numberOfColors > 0;

  /// Returns true if this appears to be a vector image based on dimensions.
  bool get isPossiblyVector => width == 0 && height == 0;

  /// Returns a human-readable description of the color format.
  String get colorFormatDescription {
    if (isPossiblyVector) {
      return 'Vector';
    } else if (isIndexedColor) {
      return '$colorDepth-bit indexed ($numberOfColors colors)';
    } else {
      return '$colorDepth-bit';
    }
  }

  @override
  String toString() {
    return 'FlacPictureMetadata('
        'type: $artworkType, '
        'mimeType: $mimeType, '
        'dimensions: ${width}x$height, '
        'colorDepth: $colorDepth, '
        'dataLength: $dataLength'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlacPictureMetadata &&
        other.artworkType == artworkType &&
        other.mimeType == mimeType &&
        other.description == description &&
        other.width == width &&
        other.height == height &&
        other.colorDepth == colorDepth &&
        other.numberOfColors == numberOfColors &&
        other.dataLength == dataLength;
  }

  @override
  int get hashCode {
    return Object.hash(
      artworkType,
      mimeType,
      description,
      width,
      height,
      colorDepth,
      numberOfColors,
      dataLength,
    );
  }
}
