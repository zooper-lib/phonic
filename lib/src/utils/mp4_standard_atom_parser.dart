import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/mp4/mp4_atom_map.dart';

import 'byte_reader.dart';
import 'mp4_atom_parser.dart';

/// Utility class for parsing MP4 standard atoms into metadata tags.
///
/// This class provides specialized parsing for standard MP4 atoms found in
/// the ilst (item list) container. It handles the various data types and
/// formats used by iTunes-style MP4 metadata atoms.
///
/// ## Supported Atom Types
///
/// ### Text Atoms
/// - ©nam (Title) - UTF-8 text
/// - ©ART (Artist) - UTF-8 text
/// - ©alb (Album) - UTF-8 text
/// - aART (Album Artist) - UTF-8 text
/// - ©gen (Genre) - UTF-8 text, semicolon-separated for multiple values
/// - ©cmt (Comment) - UTF-8 text
/// - ©grp (Grouping) - UTF-8 text
/// - ©wrt (Composer) - UTF-8 text
/// - ©too (Encoder) - UTF-8 text
/// - ©lyr (Lyrics) - UTF-8 text
/// - ©day (Date) - UTF-8 text in ISO-8601 format
///
/// ### Integer Atoms
/// - trkn (Track Number) - Binary format: [padding][track][total][padding]
/// - disk (Disc Number) - Binary format: [padding][disc][total][padding]
/// - tmpo (BPM) - 16-bit big-endian integer
///
/// ### Binary Atoms
/// - covr (Artwork) - JPEG or PNG image data with type detection
///
/// ## Data Format Details
///
/// ### Text Atoms
/// Text atoms contain UTF-8 encoded strings with a 4-byte type header:
/// ```
/// [type: 4 bytes][data: UTF-8 string]
/// ```
/// Type is typically 0x00000001 for UTF-8 text.
///
/// ### Track/Disc Numbers
/// Binary format with 8 bytes total:
/// ```
/// [padding: 2 bytes][number: 2 bytes][total: 2 bytes][padding: 2 bytes]
/// ```
/// All integers are big-endian. Padding bytes are typically zero.
///
/// ### BPM
/// 16-bit big-endian integer:
/// ```
/// [type: 4 bytes][bpm: 2 bytes][padding: 2 bytes]
/// ```
///
/// ### Artwork
/// Raw image data with MIME type detection:
/// ```
/// [type: 4 bytes][image data: variable length]
/// ```
/// Type indicates format: 0x0000000D for JPEG, 0x0000000E for PNG.
///
/// ## Usage Example
///
/// ```dart
/// // Parse individual atoms
/// final titleAtom = Mp4Atom.parse(reader);
/// final titleTag = Mp4StandardAtomParser.parseTextAtom(
///   titleAtom, TagKey.title, provenance
/// );
///
/// // Parse track number atom
/// final trkn = Mp4Atom.parse(reader);
/// final trackTag = Mp4StandardAtomParser.parseTrackNumberAtom(trkn, provenance);
///
/// // Parse artwork atom
/// final covr = Mp4Atom.parse(reader);
/// final artworkTag = Mp4StandardAtomParser.parseArtworkAtom(covr, provenance);
/// ```
class Mp4StandardAtomParser {
  /// Parses a text atom into a MetadataTag.
  ///
  /// Text atoms contain UTF-8 encoded strings with a 4-byte type prefix.
  /// The type is typically 0x00000001 for UTF-8 text data.
  ///
  /// Parameters:
  /// - [atom]: The MP4 atom containing text data
  /// - [tagKey]: The unified tag key for this text field
  /// - [provenance]: Provenance information for the tag
  ///
  /// Returns:
  /// - [MetadataTag] containing the parsed text value
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom format is invalid
  static MetadataTag parseTextAtom(
    Mp4Atom atom,
    TagKey tagKey,
    TagProvenance provenance,
  ) {
    // iTunes metadata atoms contain a nested 'data' atom with structure:
    // [size: 4 bytes][type: 4 bytes]['data'][flags: 8 bytes][text data]
    // Minimum size: 8 (data atom header) + 8 (flags) = 16 bytes
    if (atom.data.length < 16) {
      throw CorruptedContainerException(
        'Text atom too short: ${atom.data.length} bytes (minimum 16 for nested data atom)',
        byteOffset: atom.header.offset,
      );
    }

    final reader = ByteReader(atom.data);

    // Parse nested 'data' atom header
    reader.readUint32(); // 4 bytes: data atom size (not needed, we read to end)
    final dataAtomType = String.fromCharCodes(reader.readBytes(4)); // 4 bytes: type

    // Verify this is a 'data' atom
    if (dataAtomType != 'data') {
      throw CorruptedContainerException(
        'Expected nested "data" atom, found "$dataAtomType"',
        byteOffset: atom.header.offset,
      );
    }

    // Skip data atom flags (8 bytes: version + flags)
    reader.skip(8);

    // Read remaining data as UTF-8 text
    final textBytes = reader.readRemainingBytes();
    final text = utf8.decode(textBytes).trim();

    // Create appropriate tag type based on tag key
    switch (tagKey) {
      case TagKey.title:
        return TitleTag(text, provenance: provenance);
      case TagKey.artist:
        return ArtistTag(text, provenance: provenance);
      case TagKey.album:
        return AlbumTag(text, provenance: provenance);
      case TagKey.albumArtist:
        return AlbumArtistTag(text, provenance: provenance);
      case TagKey.genre:
        // Handle semicolon-separated genres for MP4
        return GenreTag.fromString(text, provenance: provenance);
      case TagKey.comment:
        return CommentTag(text, provenance: provenance);
      case TagKey.grouping:
        return GroupingTag(text, provenance: provenance);
      case TagKey.composer:
        return ComposerTag(text, provenance: provenance);
      case TagKey.encoder:
        return EncoderTag(text, provenance: provenance);
      case TagKey.lyrics:
        return LyricsTag(text, provenance: provenance);
      case TagKey.dateRecorded:
        return DateRecordedTag(text, provenance: provenance);
      case TagKey.year:
        // Extract year from date string if possible
        final yearMatch = RegExp(r'(\d{4})').firstMatch(text);
        if (yearMatch != null) {
          final year = int.tryParse(yearMatch.group(1)!);
          if (year != null) {
            return YearTag(year, provenance: provenance);
          }
        }
        // Fallback to custom tag if year parsing fails
        return CustomTag(text, provenance: provenance);
      default:
        return CustomTag(text, provenance: provenance);
    }
  }

  /// Parses a track number atom (trkn) into a TrackNumberTag.
  ///
  /// Track number atoms use binary format:
  /// [padding: 2 bytes][track: 2 bytes][total: 2 bytes][padding: 2 bytes]
  ///
  /// Parameters:
  /// - [atom]: The trkn atom containing track number data
  /// - [provenance]: Provenance information for the tag
  ///
  /// Returns:
  /// - [TrackNumberTag] containing the parsed track number
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom format is invalid
  static TrackNumberTag parseTrackNumberAtom(
    Mp4Atom atom,
    TagProvenance provenance,
  ) {
    // iTunes metadata atoms contain a nested 'data' atom with structure:
    // [size: 4 bytes][type: 4 bytes]['data'][flags: 8 bytes][binary data]
    // Minimum size: 8 (data atom header) + 8 (flags) + 8 (track data) = 24 bytes
    if (atom.data.length < 24) {
      throw CorruptedContainerException(
        'Track number atom too short: ${atom.data.length} bytes (minimum 24 for nested data atom)',
        byteOffset: atom.header.offset,
      );
    }

    final reader = ByteReader(atom.data);

    // Parse nested 'data' atom header
    reader.readUint32(); // 4 bytes: data atom size (not needed)
    final dataAtomType = String.fromCharCodes(reader.readBytes(4)); // 4 bytes: type

    // Verify this is a 'data' atom
    if (dataAtomType != 'data') {
      throw CorruptedContainerException(
        'Expected nested "data" atom, found "$dataAtomType"',
        byteOffset: atom.header.offset,
      );
    }

    // Skip data atom flags (8 bytes: version + flags)
    reader.skip(8);

    // Skip padding (2 bytes)
    reader.skip(2);

    // Read track number (2 bytes, big-endian)
    final trackNumber = reader.readUint16();

    // Skip total tracks and padding (4 bytes)
    // We only need the track number for the unified API

    return TrackNumberTag(trackNumber, provenance: provenance);
  }

  /// Parses a disc number atom (disk) into a DiscNumberTag.
  ///
  /// Disc number atoms use the same binary format as track numbers:
  /// [padding: 2 bytes][disc: 2 bytes][total: 2 bytes][padding: 2 bytes]
  ///
  /// Parameters:
  /// - [atom]: The disk atom containing disc number data
  /// - [provenance]: Provenance information for the tag
  ///
  /// Returns:
  /// - [DiscNumberTag] containing the parsed disc number
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom format is invalid
  static DiscNumberTag parseDiscNumberAtom(
    Mp4Atom atom,
    TagProvenance provenance,
  ) {
    // iTunes metadata atoms contain a nested 'data' atom with structure:
    // [size: 4 bytes][type: 4 bytes]['data'][flags: 8 bytes][binary data]
    // Minimum size: 8 (data atom header) + 8 (flags) + 8 (disc data) = 24 bytes
    if (atom.data.length < 24) {
      throw CorruptedContainerException(
        'Disc number atom too short: ${atom.data.length} bytes (minimum 24 for nested data atom)',
        byteOffset: atom.header.offset,
      );
    }

    final reader = ByteReader(atom.data);

    // Parse nested 'data' atom header
    reader.readUint32(); // 4 bytes: data atom size (not needed)
    final dataAtomType = String.fromCharCodes(reader.readBytes(4)); // 4 bytes: type

    // Verify this is a 'data' atom
    if (dataAtomType != 'data') {
      throw CorruptedContainerException(
        'Expected nested "data" atom, found "$dataAtomType"',
        byteOffset: atom.header.offset,
      );
    }

    // Skip data atom flags (8 bytes: version + flags)
    reader.skip(8);

    // Skip padding (2 bytes)
    reader.skip(2);

    // Read disc number (2 bytes, big-endian)
    final discNumber = reader.readUint16();

    // Skip total discs and padding (4 bytes)
    // We only need the disc number for the unified API

    return DiscNumberTag(discNumber, provenance: provenance);
  }

  /// Parses a BPM atom (tmpo) into a BpmTag.
  ///
  /// BPM atoms contain a 16-bit big-endian integer:
  /// [type: 4 bytes][bpm: 2 bytes][padding: 2 bytes]
  ///
  /// Parameters:
  /// - [atom]: The tmpo atom containing BPM data
  /// - [provenance]: Provenance information for the tag
  ///
  /// Returns:
  /// - [BpmTag] containing the parsed BPM value
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom format is invalid
  static BpmTag parseBpmAtom(
    Mp4Atom atom,
    TagProvenance provenance,
  ) {
    // iTunes metadata atoms contain a nested 'data' atom with structure:
    // [size: 4 bytes][type: 4 bytes]['data'][flags: 8 bytes][bpm: 2 bytes][padding: 2 bytes]
    // Minimum size: 8 (data atom header) + 8 (flags) + 2 (bpm) = 18 bytes
    if (atom.data.length < 18) {
      throw CorruptedContainerException(
        'BPM atom too short: ${atom.data.length} bytes (minimum 18 for nested data atom)',
        byteOffset: atom.header.offset,
      );
    }

    final reader = ByteReader(atom.data);

    // Parse nested 'data' atom header
    reader.readUint32(); // 4 bytes: data atom size (not needed)
    final dataAtomType = String.fromCharCodes(reader.readBytes(4)); // 4 bytes: type

    // Verify this is a 'data' atom
    if (dataAtomType != 'data') {
      throw CorruptedContainerException(
        'Expected nested "data" atom, found "$dataAtomType"',
        byteOffset: atom.header.offset,
      );
    }

    // Skip data atom flags (8 bytes: version + flags)
    reader.skip(8);

    // Read BPM value (2 bytes, big-endian)
    final bpm = reader.readUint16();

    return BpmTag(bpm, provenance: provenance);
  }

  /// Parses an artwork atom (covr) into an ArtworkTag.
  ///
  /// Artwork atoms contain raw image data with type detection:
  /// [type: 4 bytes][image data: variable length]
  ///
  /// Type values:
  /// - 0x0000000D: JPEG image
  /// - 0x0000000E: PNG image
  ///
  /// Parameters:
  /// - [atom]: The covr atom containing artwork data
  /// - [provenance]: Provenance information for the tag
  /// - [containerBytes]: Full container bytes for lazy loading
  ///
  /// Returns:
  /// - [ArtworkTag] containing the parsed artwork with lazy loading
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom format is invalid
  static ArtworkTag parseArtworkAtom(
    Mp4Atom atom,
    TagProvenance provenance,
    Uint8List containerBytes,
  ) {
    // iTunes metadata atoms contain a nested 'data' atom with structure:
    // [size: 4 bytes][type: 4 bytes]['data'][flags: 8 bytes][image data]
    // Minimum size: 8 (data atom header) + 8 (flags) = 16 bytes
    if (atom.data.length < 16) {
      throw CorruptedContainerException(
        'Artwork atom too short: ${atom.data.length} bytes (minimum 16 for nested data atom)',
        byteOffset: atom.header.offset,
      );
    }

    final reader = ByteReader(atom.data);

    // Parse nested 'data' atom header
    reader.readUint32(); // 4 bytes: data atom size (not needed)
    final dataAtomType = String.fromCharCodes(reader.readBytes(4)); // 4 bytes: type

    // Verify this is a 'data' atom
    if (dataAtomType != 'data') {
      throw CorruptedContainerException(
        'Expected nested "data" atom, found "$dataAtomType"',
        byteOffset: atom.header.offset,
      );
    }

    // Read type field from flags to determine image format (first 4 bytes of flags)
    final typeValue = reader.readUint32();

    // Skip remaining flags (4 bytes)
    reader.skip(4);

    // Read the image data
    final imageData = reader.readRemainingBytes();

    // Determine MIME type from type value
    String mimeType;
    switch (typeValue) {
      case 0x0000000D:
        mimeType = 'image/jpeg';
        break;
      case 0x0000000E:
        mimeType = 'image/png';
        break;
      default:
        // Try to detect format from image data
        mimeType = _detectImageMimeType(imageData);
    }

    // Create artwork data with simple async loader
    final artworkData = ArtworkData(
      mimeType: mimeType,
      type: ArtworkType.frontCover, // MP4 doesn't specify artwork type
      description: null, // MP4 covr atoms don't include descriptions
      dataLoader: () async => imageData,
    );

    return ArtworkTag(artworkData, provenance: provenance);
  }

  /// Detects the MIME type of image data by examining the file signature.
  ///
  /// This method examines the first few bytes of image data to determine
  /// the image format when the MP4 type field doesn't provide clear
  /// format information.
  ///
  /// Parameters:
  /// - [imageData]: The raw image data bytes
  ///
  /// Returns:
  /// - String containing the detected MIME type
  static String _detectImageMimeType(Uint8List imageData) {
    if (imageData.length < 4) {
      return 'application/octet-stream'; // Unknown format
    }

    // Check for JPEG signature (FF D8 FF)
    if (imageData[0] == 0xFF && imageData[1] == 0xD8 && imageData[2] == 0xFF) {
      return 'image/jpeg';
    }

    // Check for PNG signature (89 50 4E 47)
    if (imageData.length >= 8 && imageData[0] == 0x89 && imageData[1] == 0x50 && imageData[2] == 0x4E && imageData[3] == 0x47) {
      return 'image/png';
    }

    // Check for GIF signature (47 49 46)
    if (imageData[0] == 0x47 && imageData[1] == 0x49 && imageData[2] == 0x46) {
      return 'image/gif';
    }

    // Check for BMP signature (42 4D)
    if (imageData[0] == 0x42 && imageData[1] == 0x4D) {
      return 'image/bmp';
    }

    // Check for WebP signature (52 49 46 46 ... 57 45 42 50)
    if (imageData.length >= 12 &&
        imageData[0] == 0x52 &&
        imageData[1] == 0x49 &&
        imageData[2] == 0x46 &&
        imageData[3] == 0x46 &&
        imageData[8] == 0x57 &&
        imageData[9] == 0x45 &&
        imageData[10] == 0x42 &&
        imageData[11] == 0x50) {
      return 'image/webp';
    }

    // Default to JPEG if no signature matches (most common in MP4)
    return 'image/jpeg';
  }

  /// Parses a standard MP4 atom into a MetadataTag based on its type.
  ///
  /// This method serves as a dispatcher that routes atoms to the appropriate
  /// specialized parsing method based on the atom's 4-character type identifier.
  ///
  /// Parameters:
  /// - [atom]: The MP4 atom to parse
  /// - [provenance]: Provenance information for the tag
  /// - [containerBytes]: Full container bytes for lazy loading (artwork only)
  ///
  /// Returns:
  /// - [MetadataTag] containing the parsed data, or null if atom type is unsupported
  static MetadataTag? parseStandardAtom(
    Mp4Atom atom,
    TagProvenance provenance,
    Uint8List containerBytes,
  ) {
    final atomType = atom.header.type;
    final tagKey = Mp4AtomMap.getTagKey(atomType);

    if (tagKey == null) {
      return null; // Unsupported atom type
    }

    try {
      switch (atomType) {
        // Text atoms
        case '©nam':
        case '©ART':
        case '©alb':
        case 'aART':
        case '©gen':
        case '©cmt':
        case '©grp':
        case '©wrt':
        case '©too':
        case '©lyr':
        case '©day':
          return parseTextAtom(atom, tagKey, provenance);

        // Binary number atoms
        case 'trkn':
          return parseTrackNumberAtom(atom, provenance);
        case 'disk':
          return parseDiscNumberAtom(atom, provenance);
        case 'tmpo':
          return parseBpmAtom(atom, provenance);

        // Artwork atoms
        case 'covr':
          return parseArtworkAtom(atom, provenance, containerBytes);

        default:
          return null; // Unsupported atom type
      }
    } catch (e) {
      // Re-throw with additional context
      if (e is CorruptedContainerException) {
        rethrow;
      } else {
        throw CorruptedContainerException(
          'Failed to parse MP4 atom "$atomType": $e',
          byteOffset: atom.header.offset,
        );
      }
    }
  }

  /// Private constructor to prevent instantiation.
  Mp4StandardAtomParser._();
}
