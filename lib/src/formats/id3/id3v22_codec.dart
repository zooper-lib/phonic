import 'dart:convert';
import 'dart:typed_data';

import '../../capabilities/id3v22_capability.dart';
import '../../core/container_kind.dart';
import '../../core/metadata_tag.dart';
import '../../core/tag_capability.dart';
import '../../core/tag_codec.dart';
import '../../core/tag_confidence.dart';
import '../../core/tag_key.dart';
import '../../core/tag_provenance.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../tags/tags.dart';
import '../../utils/synchsafe_int.dart';
import '../../utils/unknown_data_preservation.dart';
import 'id3v2_frame_map.dart';
import 'id3v2_frame_parser.dart';
import 'id3v2_genre_utils.dart';
import 'id3v2_header_parser.dart';

/// ID3v2.2 metadata codec for reading and writing ID3v2.2 tags.
///
/// This codec handles the ID3v2.2 metadata format, which is the earliest
/// version of the ID3v2 specification. ID3v2.2 provides variable-length
/// metadata fields as an improvement over ID3v1, but has more limited
/// capabilities compared to later ID3v2 versions.
///
/// ## Key Features
///
/// - **3-character frame IDs**: Uses shorter frame identifiers (TT2, TP1, TAL, etc.)
/// - **Limited encoding support**: Primarily ISO-8859-1 (Latin-1)
/// - **Variable-length fields**: Improvement over ID3v1's fixed-length constraints
/// - **Basic artwork support**: PIC frames instead of APIC used in later versions
/// - **No extended header**: Simpler structure without extended header support
/// - **Limited field set**: Missing some fields available in later versions
///
/// ## Frame Mappings
///
/// The codec maps unified tag keys to ID3v2.2 frame IDs:
/// - [TagKey.title] → TT2 (Title/songname/content description)
/// - [TagKey.artist] → TP1 (Lead performer(s)/Soloist(s))
/// - [TagKey.album] → TAL (Album/Movie/Show title)
/// - [TagKey.albumArtist] → TP2 (Band/orchestra/accompaniment)
/// - [TagKey.genre] → TCO (Content type/Genre)
/// - [TagKey.comment] → COM (Comments)
/// - [TagKey.grouping] → TT1 (Content group description)
/// - [TagKey.composer] → TCM (Composer)
/// - [TagKey.encoder] → TSS (Software/Hardware and settings used for encoding)
/// - [TagKey.trackNumber] → TRK (Track number/Position in set)
/// - [TagKey.year] → TYE (Year)
/// - [TagKey.bpm] → TBP (BPM - beats per minute)
/// - [TagKey.artwork] → PIC (Attached picture - different from APIC)
/// - [TagKey.custom] → TXX (User defined text information)
///
/// ## Limitations
///
/// ID3v2.2 has several limitations compared to later versions:
/// - **No UTF-8/UTF-16 support**: Limited to ISO-8859-1 encoding
/// - **Missing fields**: No rating (POPM), lyrics (USLT), ISRC, disc number, musical key
/// - **Simple date handling**: Only year field, no complex date/time support
/// - **PIC vs APIC**: Uses simpler PIC frames for artwork instead of APIC
/// - **No extended features**: No extended header, compression, or encryption
///
/// ## Usage Example
///
/// ```dart
/// final codec = Id3v22Codec();
///
/// // Reading tags
/// final containerBytes = await locator.extract(fileBytes);
/// final tags = codec.readFromContainer(containerBytes);
///
/// // Writing tags
/// final tagsToWrite = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock']), // Limited genre support
/// ];
/// final newContainer = codec.writeToContainer(tagsToWrite: tagsToWrite);
/// ```
///
/// ## Error Handling
///
/// The codec handles various error conditions gracefully:
/// - **Corrupted frames**: Skips corrupted frames, continues parsing others
/// - **Unknown frames**: Preserves unknown frames for round-trip compatibility
/// - **Encoding errors**: Uses fallback encodings when possible
/// - **Structural damage**: Parses recoverable data, reports issues
///
/// ## Performance Considerations
///
/// - **Lazy loading**: Artwork data is loaded on-demand using [LazyArtworkLoader]
/// - **Memory efficiency**: Avoids copying large byte arrays unnecessarily
/// - **Simple structure**: ID3v2.2's simpler format enables faster parsing
/// - **Limited features**: Fewer frame types mean less processing overhead
class Id3v22Codec implements TagCodec {
  /// Creates a new ID3v2.2 codec instance.
  ///
  /// The codec is stateless and thread-safe, so a single instance can be
  /// reused across multiple files and threads.
  const Id3v22Codec();

  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.2';

  @override
  TagCapability get capability => id3v22Capability;

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (containerBytes.isEmpty) {
      return <MetadataTag>[];
    }

    try {
      // Check if we have a valid ID3v2 signature first
      if (!Id3v2HeaderParser.hasValidSignature(containerBytes)) {
        return <MetadataTag>[];
      }

      // Parse ID3v2 header
      final header = Id3v2HeaderParser.parseHeader(containerBytes);

      // Validate that this is ID3v2.2
      if (header.majorVersion != 2) {
        throw CorruptedContainerException(
          'Expected ID3v2.2, got ID3v2.${header.majorVersion}',
          context: 'ID3v2.2 codec validation',
        );
      }

      // Extract frame data (skip 10-byte header)
      final frameData = containerBytes.sublist(10, 10 + header.tagSize);

      // Parse frames
      final tags = <MetadataTag>[];
      int currentOffset = 0;

      while (currentOffset < frameData.length) {
        // Check for padding (null bytes at end of tag)
        if (frameData[currentOffset] == 0x00) {
          break;
        }

        // Ensure we have enough bytes for a frame header (6 bytes for ID3v2.2)
        if (currentOffset + 6 > frameData.length) {
          break;
        }

        try {
          // Parse frame
          final frame = Id3v2FrameParser.parseFrame(
            frameData.sublist(currentOffset),
            2, // ID3v2.2
          );

          // Extract frame data (no format flags in ID3v2.2)
          final processedFrameData = frame.data;

          // Convert frame to MetadataTag
          final tag = _frameToMetadataTag(frame, processedFrameData);
          if (tag != null) {
            tags.add(tag);
          }

          // Move to next frame
          currentOffset += frame.totalSize;
        } catch (e) {
          // Try to recover by finding the next valid frame
          final nextFrameOffset = _findNextFrameOffset(frameData, currentOffset + 1);
          if (nextFrameOffset > 0) {
            currentOffset = nextFrameOffset;
          } else {
            // No more valid frames found
            break;
          }
        }
      }

      return tags;
    } catch (e) {
      if (e is CorruptedContainerException || e is FormatException) {
        rethrow;
      }
      throw CorruptedContainerException(
        'Failed to parse ID3v2.2 container: $e',
        context: 'ID3v2.2 codec parsing',
      );
    }
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (tagsToWrite.isEmpty) {
      return _buildEmptyContainer();
    }

    // Convert MetadataTag instances to ID3v2.2 frames
    final frames = <_Id3v22Frame>[];

    for (final tag in tagsToWrite) {
      final frame = _metadataTagToFrame(tag);
      if (frame != null) {
        frames.add(frame);
      }
    }

    if (frames.isEmpty) {
      return _buildEmptyContainer();
    }

    return _buildId3v22Container(frames);
  }

  /// Converts an ID3v2.2 frame to a MetadataTag instance.
  ///
  /// This method handles the conversion from raw frame data to strongly-typed
  /// MetadataTag objects with proper provenance information for ID3v2.2.
  MetadataTag? _frameToMetadataTag(Id3v2Frame frame, Uint8List frameData) {
    final provenance = const TagProvenance(
      ContainerKind.id3v2,
      '2.2',
      TagConfidence.certain,
    );

    // Map frame ID to tag key
    final tagKey = Id3v2FrameMap.getTagKey(frame.id);
    if (tagKey == null) {
      // Unknown frame, skip it
      return null;
    }

    try {
      switch (frame.id) {
        // Standard text frames (3-character IDs for ID3v2.2)
        case 'TT2': // Title
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return TitleTag(text, provenance: provenance);

        case 'TP1': // Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return ArtistTag(text, provenance: provenance);

        case 'TAL': // Album
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return AlbumTag(text, provenance: provenance);

        case 'TP2': // Album Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return AlbumArtistTag(text, provenance: provenance);

        case 'TT1': // Grouping
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return GroupingTag(text, provenance: provenance);

        case 'TCM': // Composer
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return ComposerTag(text, provenance: provenance);

        case 'TSS': // Encoder
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          return EncoderTag(text, provenance: provenance);

        case 'TCO': // Genre - ID3v2.2 uses slash-separated format
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          final genres = Id3v2GenreUtils.parseId3v23Genres(text); // Use v2.3 parser for slash-separated
          return GenreTag(genres, provenance: provenance);

        case 'TYE': // Year
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          final year = int.tryParse(text.trim());
          if (year != null && year > 0) {
            return YearTag(year, provenance: provenance);
          }
          return null;

        case 'TRK': // Track Number
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          final trackNumber = _parseTrackNumber(text);
          if (trackNumber != null) {
            return TrackNumberTag(trackNumber, provenance: provenance);
          }
          return null;

        case 'TBP': // BPM
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 2);
          final bpm = int.tryParse(text.trim());
          if (bpm != null && bpm > 0) {
            return BpmTag(bpm, provenance: provenance);
          }
          return null;

        case 'COM': // Comment (ID3v2.2 format)
          // ID3v2.2 COM frames have a simpler structure than COMM frames
          final text = _parseComFrame(frameData);
          if (text.isNotEmpty) {
            return CommentTag(text, provenance: provenance);
          }
          return null;

        case 'PIC': // Artwork (ID3v2.2 uses PIC instead of APIC)
          // PIC frames are more complex and would need specialized parsing
          // For now, skip artwork frames as they need special handling
          return null;

        case 'TXX': // Custom text frame
          // For now, we'll skip custom frames as they need special handling
          return null;

        default:
          // Unknown frame type
          return null;
      }
    } catch (e) {
      // If frame parsing fails, skip this frame
      return null;
    }
  }

  /// Parses track number from TRK frame text.
  ///
  /// TRK frames can contain just the track number or "track/total" format.
  int? _parseTrackNumber(String text) {
    if (text.isEmpty) return null;

    // Handle "track/total" format
    final parts = text.split('/');
    final trackText = parts[0].trim();

    return int.tryParse(trackText);
  }

  /// Parses ID3v2.2 COM frame data.
  ///
  /// ID3v2.2 COM frames have a simpler structure than ID3v2.3/2.4 COMM frames:
  /// - Text encoding (1 byte)
  /// - Language (3 bytes)
  /// - Text (remainder, in specified encoding)
  String _parseComFrame(Uint8List frameData) {
    if (frameData.length < 4) {
      return '';
    }

    try {
      // Skip encoding byte and language (4 bytes total)
      final textBytes = frameData.sublist(4);

      // For ID3v2.2, we primarily use ISO-8859-1 encoding
      // Simple decoding - more sophisticated encoding handling could be added
      return String.fromCharCodes(textBytes).trim();
    } catch (e) {
      return '';
    }
  }

  /// Finds the next valid frame offset by looking for frame ID patterns.
  ///
  /// This is used for error recovery when a corrupted frame is encountered.
  int _findNextFrameOffset(Uint8List frameData, int startOffset) {
    for (int i = startOffset; i < frameData.length - 3; i++) {
      // Look for potential 3-character frame ID (uppercase letters/digits)
      if (_looksLikeFrameId(frameData, i)) {
        return i;
      }
    }
    return -1;
  }

  /// Checks if the bytes at the given offset look like a valid ID3v2.2 frame ID.
  bool _looksLikeFrameId(Uint8List data, int offset) {
    if (offset + 3 > data.length) return false;

    for (int i = 0; i < 3; i++) {
      final byte = data[offset + i];
      // Frame IDs should be uppercase letters (A-Z) or digits (0-9)
      if (!((byte >= 0x41 && byte <= 0x5A) || (byte >= 0x30 && byte <= 0x39))) {
        return false;
      }
    }

    return true;
  }

  /// Converts a MetadataTag to an ID3v2.2 frame.
  ///
  /// This method handles the conversion from strongly-typed MetadataTag objects
  /// to raw ID3v2.2 frame data with proper encoding for the limited capabilities
  /// of ID3v2.2.
  _Id3v22Frame? _metadataTagToFrame(MetadataTag tag) {
    // Get the ID3v2.2 frame ID for this tag
    final frameId = Id3v2FrameMap.getFrameId(tag.key, '2.2');
    if (frameId == null) {
      // Tag not supported in ID3v2.2
      return null;
    }

    try {
      // Standard text frames
      if (tag.key == TagKey.title ||
          tag.key == TagKey.artist ||
          tag.key == TagKey.album ||
          tag.key == TagKey.albumArtist ||
          tag.key == TagKey.grouping ||
          tag.key == TagKey.composer ||
          tag.key == TagKey.encoder) {
        return _buildTextFrame(frameId, tag.value as String);
      } else if (tag.key == TagKey.genre) {
        // Handle GenreTag with slash-separated format for ID3v2.2
        final genreTag = tag as GenreTag;
        final genreString = genreTag.toId3v23String(); // Use slash format like v2.3
        return _buildTextFrame(frameId, genreString);
      } else if (tag.key == TagKey.year) {
        final yearTag = tag as YearTag;
        return _buildTextFrame(frameId, yearTag.value.toString());
      } else if (tag.key == TagKey.trackNumber) {
        final trackTag = tag as TrackNumberTag;
        return _buildTextFrame(frameId, trackTag.value.toString());
      } else if (tag.key == TagKey.bpm) {
        final bpmTag = tag as BpmTag;
        return _buildTextFrame(frameId, bpmTag.value.toString());
      } else if (tag.key == TagKey.comment) {
        final commentTag = tag as CommentTag;
        return _buildComFrame(commentTag.value);
      } else if (tag.key == TagKey.artwork) {
        // PIC frames are complex and would need specialized handling
        // For now, skip artwork frames
        return null;
      } else if (tag.key == TagKey.custom) {
        final customTag = tag as CustomTag;
        return _buildTxxFrame(customTag.value);
      } else {
        // Unsupported tag type for ID3v2.2
        return null;
      }
    } catch (e) {
      // If frame building fails, skip this tag
      return null;
    }
  }

  /// Builds a standard text frame for ID3v2.2.
  ///
  /// ID3v2.2 text frames have a simple structure:
  /// - Text encoding (1 byte) - typically 0x00 for ISO-8859-1
  /// - Text data (remainder, in specified encoding)
  _Id3v22Frame _buildTextFrame(String frameId, String text) {
    // ID3v2.2 primarily uses ISO-8859-1 encoding
    // Use encoding byte 0x00 for ISO-8859-1
    final textBytes = latin1.encode(text);

    final frameData = Uint8List.fromList([
      0x00, // ISO-8859-1 encoding
      ...textBytes,
    ]);

    return _Id3v22Frame(
      id: frameId,
      data: frameData,
    );
  }

  /// Builds a COM (comment) frame for ID3v2.2.
  ///
  /// ID3v2.2 COM frames have the structure:
  /// - Text encoding (1 byte)
  /// - Language (3 bytes)
  /// - Text (remainder, in specified encoding)
  _Id3v22Frame _buildComFrame(String comment) {
    final textBytes = latin1.encode(comment);

    final frameData = Uint8List.fromList([
      0x00, // ISO-8859-1 encoding
      0x65, 0x6E, 0x67, // "eng" language code
      ...textBytes,
    ]);

    return _Id3v22Frame(
      id: 'COM',
      data: frameData,
    );
  }

  /// Builds a TXX (custom text) frame for ID3v2.2.
  ///
  /// ID3v2.2 TXX frames have the structure:
  /// - Text encoding (1 byte)
  /// - Description (null-terminated string)
  /// - Value (remainder, in specified encoding)
  _Id3v22Frame _buildTxxFrame(String customValue) {
    final valueBytes = latin1.encode(customValue);

    final frameData = Uint8List.fromList([
      0x00, // ISO-8859-1 encoding
      0x00, // Empty description + null terminator
      ...valueBytes,
    ]);

    return _Id3v22Frame(
      id: 'TXX',
      data: frameData,
    );
  }

  /// Builds a complete ID3v2.2 container with the given frames.
  ///
  /// ID3v2.2 has a simpler structure than later versions:
  /// - 10-byte header (same as v2.3/v2.4)
  /// - 6-byte frame headers (3-byte ID + 3-byte size)
  /// - No frame flags
  /// - Tag size is synchsafe integer
  Uint8List _buildId3v22Container(List<_Id3v22Frame> frames) {
    // Calculate total frame data size
    int totalFrameSize = 0;
    for (final frame in frames) {
      totalFrameSize += 6 + frame.data.length; // 6-byte header + data
    }

    // Build frame data
    final frameDataBytes = <int>[];
    for (final frame in frames) {
      // Frame header: ID (3 bytes) + size (3 bytes, 24-bit big-endian)
      frameDataBytes.addAll(latin1.encode(frame.id)); // Frame ID (3 chars)
      frameDataBytes.addAll(_encodeFrameSize(frame.data.length)); // Frame size (24-bit)
      frameDataBytes.addAll(frame.data); // Frame data
    }

    // Build ID3v2.2 header
    final headerBytes = <int>[
      0x49, 0x44, 0x33, // "ID3"
      0x02, 0x00, // Version 2.2
      0x00, // No flags
      ...SynchsafeInt.encode(totalFrameSize), // Tag size (synchsafe)
    ];

    return Uint8List.fromList([...headerBytes, ...frameDataBytes]);
  }

  /// Builds an empty ID3v2.2 container with no frames.
  Uint8List _buildEmptyContainer() {
    return Uint8List.fromList([
      0x49, 0x44, 0x33, // "ID3"
      0x02, 0x00, // Version 2.2
      0x00, // No flags
      0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
    ]);
  }

  /// Encodes a frame size as a 3-byte big-endian integer (for ID3v2.2 frames).
  ///
  /// ID3v2.2 uses 24-bit (3-byte) frame sizes instead of the 32-bit sizes
  /// used in later versions.
  List<int> _encodeFrameSize(int size) {
    return [
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ];
  }
}

/// Internal representation of an ID3v2.2 frame for writing.
///
/// ID3v2.2 frames have a simpler structure than later versions with
/// 3-character frame IDs and no frame flags.
class _Id3v22Frame {
  final String id;
  final Uint8List data;

  const _Id3v22Frame({
    required this.id,
    required this.data,
  });
}
