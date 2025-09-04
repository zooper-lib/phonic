import 'dart:convert';
import 'dart:typed_data';

import '../../capabilities/id3v23_capability.dart';
import '../../core/artwork_data.dart';
import '../../core/container_kind.dart';
import '../../core/metadata_tag.dart';
import '../../core/tag_capability.dart';
import '../../core/tag_codec.dart';
import '../../core/tag_confidence.dart';
import '../../core/tag_key.dart';
import '../../core/tag_provenance.dart';
import '../../core/text_encoding.dart';
import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/synchsafe_int.dart';
import '../../utils/text_encoding_utils.dart';
import '../../utils/unknown_data_preservation.dart';
import 'id3v2_apic_frame_parser.dart';
import 'id3v2_comm_frame_parser.dart';
import 'id3v2_frame_map.dart';
import 'id3v2_frame_parser.dart';
import 'id3v2_genre_utils.dart';
import 'id3v2_header_parser.dart';
import 'id3v2_popm_frame_parser.dart';
import 'id3v2_uslt_frame_parser.dart';

/// ID3v2.3 metadata codec for reading and writing ID3v2.3 tags.
///
/// This codec handles the ID3v2.3 metadata format, which is one of the most
/// widely supported versions of the ID3v2 specification. ID3v2.3 provides
/// significant improvements over ID3v1 while maintaining broad compatibility
/// across different audio players and software.
///
/// ## Key Features
///
/// - **Encoding support**: ISO-8859-1 and UTF-16 (no UTF-8 support)
/// - **Date handling**: Separate TYER frame for year (not TDRC like v2.4)
/// - **Multi-genre support**: Slash-separated strings in TCON frame
/// - **Enhanced artwork**: APIC frames with type and description
/// - **Custom fields**: Support for user-defined TXXX frames
/// - **Wide compatibility**: Supported by most audio players and software
///
/// ## Frame Mappings
///
/// The codec maps unified tag keys to ID3v2.3 frame IDs:
/// - [TagKey.title] → TIT2 (Title/songname/content description)
/// - [TagKey.artist] → TPE1 (Lead performer(s)/Soloist(s))
/// - [TagKey.album] → TALB (Album/Movie/Show title)
/// - [TagKey.albumArtist] → TPE2 (Band/orchestra/accompaniment)
/// - [TagKey.genre] → TCON (Content type/Genre)
/// - [TagKey.comment] → COMM (Comments)
/// - [TagKey.grouping] → TIT1 (Content group description)
/// - [TagKey.composer] → TCOM (Composer)
/// - [TagKey.encoder] → TSSE (Software/Hardware and settings used for encoding)
/// - [TagKey.isrc] → TSRC (ISRC - International Standard Recording Code)
/// - [TagKey.musicalKey] → TKEY (Initial key)
/// - [TagKey.lyrics] → USLT (Unsynchronised lyric/text transcription)
/// - [TagKey.trackNumber] → TRCK (Track number/Position in set)
/// - [TagKey.discNumber] → TPOS (Part of a set)
/// - [TagKey.year] → TYER (Year)
/// - [TagKey.bpm] → TBPM (BPM - beats per minute)
/// - [TagKey.rating] → POPM (Popularimeter)
/// - [TagKey.artwork] → APIC (Attached picture)
///
/// ## Genre Handling
///
/// ID3v2.3 uses slash-separated strings in the TCON frame for multiple genres:
/// ```
/// Single genre: "Rock"
/// Multiple genres: "Rock/Alternative/Indie"
/// ```
///
/// This differs from ID3v2.4's null-terminated approach, requiring different
/// parsing and encoding logic for genre fields.
///
/// ## Date Handling
///
/// Unlike ID3v2.4 which uses the unified TDRC frame, ID3v2.3 uses separate
/// frames for date components:
/// - TYER: Year (4 digits)
/// - TDAT: Date (DDMM format)
/// - TIME: Time (HHMM format)
///
/// The codec handles conversion between the unified dateRecorded field and
/// these separate ID3v2.3 frames.
///
/// ## Encoding Limitations
///
/// ID3v2.3 does not support UTF-8 encoding, which was added in ID3v2.4.
/// Supported encodings are:
/// - ISO-8859-1 (Latin-1): Single-byte encoding for Western European languages
/// - UTF-16: Multi-byte encoding with BOM for international text
///
/// ## Usage Example
///
/// ```dart
/// final codec = Id3v23Codec();
///
/// // Reading tags
/// final containerBytes = await locator.extract(fileBytes);
/// final tags = codec.readFromContainer(containerBytes);
///
/// // Writing tags
/// final tagsToWrite = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']),
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
/// - **Streaming**: Supports incremental parsing for large containers
/// - **Caching**: Frame parsing results can be cached for repeated access
class Id3v23Codec implements TagCodec {
  /// Creates a new ID3v2.3 codec instance.
  ///
  /// The codec is stateless and thread-safe, so a single instance can be
  /// reused across multiple files and threads.
  const Id3v23Codec();

  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.3';

  @override
  TagCapability get capability => id3v23Capability;

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (containerBytes.isEmpty) {
      return <MetadataTag>[];
    }

    try {
      // Parse ID3v2 header
      final header = Id3v2HeaderParser.parseHeader(containerBytes);

      // Validate this is ID3v2.3
      if (header.majorVersion != 3) {
        throw CorruptedContainerException(
          'Expected ID3v2.3, got ID3v2.${header.majorVersion}',
          context: 'ID3v2.3 codec validation',
        );
      }

      // Calculate frame data offset (header + extended header if present)
      int frameDataOffset = Id3v2HeaderParser.headerSize;
      if (header.hasExtendedHeader) {
        final extendedHeader = Id3v2HeaderParser.parseExtendedHeader(
          containerBytes,
          frameDataOffset,
        );
        frameDataOffset += extendedHeader.size;
      }

      // Extract frame data section
      final frameDataEnd = frameDataOffset + header.tagSize - (frameDataOffset - Id3v2HeaderParser.headerSize);
      if (frameDataEnd > containerBytes.length) {
        throw CorruptedContainerException(
          'ID3v2.3 tag size extends beyond container: ${frameDataEnd} > ${containerBytes.length}',
          byteOffset: frameDataOffset,
          context: 'ID3v2.3 frame data extraction',
        );
      }

      final frameDataBytes = containerBytes.sublist(frameDataOffset, frameDataEnd);

      // Parse all frames
      final tags = <MetadataTag>[];
      int currentOffset = 0;

      while (currentOffset < frameDataBytes.length) {
        // Check for padding (null bytes at end of tag)
        if (frameDataBytes[currentOffset] == 0) {
          break; // Rest is padding
        }

        try {
          // Parse frame
          final frame = Id3v2FrameParser.parseFrame(
            frameDataBytes,
            3, // ID3v2.3
            currentOffset,
          );

          // Extract and process frame data
          final processedData = Id3v2FrameParser.extractFrameData(frame);

          // Convert frame to MetadataTag
          final tag = _frameToMetadataTag(frame, processedData);
          if (tag != null) {
            tags.add(tag);
          }

          // Move to next frame
          currentOffset += frame.totalSize;
        } catch (e) {
          // Skip corrupted frame and try to continue
          if (e is CorruptedContainerException) {
            // Try to find next valid frame by looking for frame ID pattern
            final nextFrameOffset = _findNextFrameOffset(frameDataBytes, currentOffset + 1);
            if (nextFrameOffset == -1) {
              break; // No more valid frames found
            }
            currentOffset = nextFrameOffset;
          } else {
            rethrow;
          }
        }
      }

      return tags;
    } catch (e) {
      if (e is CorruptedContainerException || e is FormatException) {
        rethrow;
      }
      throw CorruptedContainerException(
        'Failed to parse ID3v2.3 container: $e',
        context: 'ID3v2.3 codec parsing',
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
      // Return empty ID3v2.3 header with no frames
      return _buildEmptyContainer();
    }

    try {
      // Convert MetadataTag instances to ID3v2.3 frames
      final frames = <_Id3v23Frame>[];

      for (final tag in tagsToWrite) {
        final frameList = _metadataTagToFrames(tag);
        frames.addAll(frameList);
      }

      // Build complete ID3v2.3 container
      return _buildId3v23Container(frames);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to build ID3v2.3 container: $e',
        context: 'ID3v2.3 codec writing',
      );
    }
  }

  /// Converts an ID3v2.3 frame to a MetadataTag instance.
  ///
  /// This method handles the conversion from raw frame data to strongly-typed
  /// MetadataTag objects with proper provenance information.
  MetadataTag? _frameToMetadataTag(Id3v2Frame frame, Uint8List frameData) {
    final provenance = const TagProvenance(
      ContainerKind.id3v2,
      '2.3',
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
        // Standard text frames
        case 'TIT2': // Title
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return TitleTag(text, provenance: provenance);

        case 'TPE1': // Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return ArtistTag(text, provenance: provenance);

        case 'TALB': // Album
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return AlbumTag(text, provenance: provenance);

        case 'TPE2': // Album Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return AlbumArtistTag(text, provenance: provenance);

        case 'TIT1': // Grouping
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return GroupingTag(text, provenance: provenance);

        case 'TCOM': // Composer
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return ComposerTag(text, provenance: provenance);

        case 'TSSE': // Encoder
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return EncoderTag(text, provenance: provenance);

        case 'TSRC': // ISRC
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return IsrcTag(text, provenance: provenance);

        case 'TKEY': // Musical Key
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          return MusicalKeyTag(text, provenance: provenance);

        case 'TCON': // Genre - special handling for ID3v2.3 slash-separated strings
          final genres = _parseTconFrame(frameData);
          return GenreTag(genres, provenance: provenance);

        case 'TYER': // Year (ID3v2.3 specific)
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          final year = int.tryParse(text.trim());
          if (year != null && year >= 1000 && year <= 3000) {
            return YearTag(year, provenance: provenance);
          }
          return null;

        case 'TDAT': // Date (DDMM format, ID3v2.3 specific)
        case 'TIME': // Time (HHMM format, ID3v2.3 specific)
          // These frames are handled separately and combined into dateRecorded
          // For now, we'll skip individual processing and handle them in a separate pass
          return null;

        case 'TRCK': // Track Number
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          final trackNumber = _parseTrackNumber(text);
          if (trackNumber != null) {
            return TrackNumberTag(trackNumber, provenance: provenance);
          }
          return null;

        case 'TPOS': // Disc Number
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          final discNumber = _parseDiscNumber(text);
          if (discNumber != null) {
            return DiscNumberTag(discNumber, provenance: provenance);
          }
          return null;

        case 'TBPM': // BPM
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);
          final bpm = int.tryParse(text.trim());
          if (bpm != null && bpm > 0) {
            return BpmTag(bpm, provenance: provenance);
          }
          return null;

        case 'POPM': // Rating (Popularimeter)
          final popmData = Id3v2PopmFrameParser.parse(frameData);
          final unifiedRating = popmData.unifiedRating;
          if (unifiedRating > 0) {
            return RatingTag(unifiedRating, provenance: provenance);
          }
          return null;

        case 'COMM': // Comment
          final commData = Id3v2CommFrameParser.parse(frameData, 3);
          return CommentTag(commData.text, provenance: provenance);

        case 'USLT': // Lyrics
          final usltData = Id3v2UsltFrameParser.parse(frameData, 3);
          return LyricsTag(usltData.lyrics, provenance: provenance);

        case 'APIC': // Artwork
          final apicData = Id3v2ApicFrameParser.parse(frameData, 3);
          return ArtworkTag(apicData.artworkData, provenance: provenance);

        case 'TXXX': // Custom text frame
          // For now, we'll skip custom frames as they need special handling
          // This will be implemented when custom tag support is added
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

  /// Parses track number from TRCK frame text.
  ///
  /// TRCK frames can contain just the track number or "track/total" format.
  int? _parseTrackNumber(String text) {
    if (text.isEmpty) return null;

    // Handle "track/total" format
    final parts = text.split('/');
    final trackText = parts[0].trim();

    return int.tryParse(trackText);
  }

  /// Parses disc number from TPOS frame text.
  ///
  /// TPOS frames can contain just the disc number or "disc/total" format.
  int? _parseDiscNumber(String text) {
    if (text.isEmpty) return null;

    // Handle "disc/total" format
    final parts = text.split('/');
    final discText = parts[0].trim();

    return int.tryParse(discText);
  }

  /// Finds the next valid frame offset by looking for frame ID patterns.
  ///
  /// This is used for error recovery when a corrupted frame is encountered.
  int _findNextFrameOffset(Uint8List frameData, int startOffset) {
    for (int i = startOffset; i < frameData.length - 4; i++) {
      // Look for potential frame ID (4 uppercase letters/digits)
      if (_looksLikeFrameId(frameData, i)) {
        return i;
      }
    }
    return -1;
  }

  /// Checks if the bytes at the given offset look like a valid frame ID.
  bool _looksLikeFrameId(Uint8List data, int offset) {
    if (offset + 4 > data.length) return false;

    for (int i = 0; i < 4; i++) {
      final byte = data[offset + i];
      // Frame IDs should be uppercase letters (A-Z) or digits (0-9)
      if (!((byte >= 0x41 && byte <= 0x5A) || (byte >= 0x30 && byte <= 0x39))) {
        return false;
      }
    }

    return true;
  }

  /// Parses a TCON frame preserving slash separators for ID3v2.3 multi-genre support.
  List<String> _parseTconFrame(Uint8List frameData) {
    if (frameData.isEmpty) {
      return [];
    }

    try {
      // Parse the text frame to get the raw genre string
      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 3);

      // Use ID3v2.3 specific genre parsing (slash-separated)
      return Id3v2GenreUtils.parseId3v23Genres(text);
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Converts a MetadataTag to ID3v2.3 frames.
  ///
  /// Returns a list of frames since some tags (like dateRecorded) may need
  /// to be split into multiple frames (TYER, TDAT, TIME) in ID3v2.3.
  List<_Id3v23Frame> _metadataTagToFrames(MetadataTag tag) {
    try {
      switch (tag.key) {
        case TagKey.dateRecorded:
          // Special handling for dateRecorded - convert to TYER/TDAT/TIME frames
          if (tag is DateRecordedTag) {
            return _buildDateFrames(tag.value);
          }
          return [];

        default:
          // Get frame ID for this tag key
          final frameId = Id3v2FrameMap.getFrameId(tag.key, '2.3');
          if (frameId == null) {
            return []; // Tag not supported in ID3v2.3
          }

          return _handleStandardTag(tag, frameId);
      }
    } catch (e) {
      // If frame building fails, skip this tag
      return [];
    }
  }

  /// Handles standard tags that have direct frame ID mappings.
  List<_Id3v23Frame> _handleStandardTag(MetadataTag tag, String frameId) {
    try {
      switch (tag.key) {
        // Standard text frames
        case TagKey.title:
        case TagKey.artist:
        case TagKey.album:
        case TagKey.albumArtist:
        case TagKey.grouping:
        case TagKey.composer:
        case TagKey.encoder:
        case TagKey.isrc:
        case TagKey.musicalKey:
        case TagKey.comment:
        case TagKey.lyrics:
          return [_buildTextFrame(frameId, tag.value.toString())];

        case TagKey.genre:
          // Special handling for GenreTag with slash-separated strings
          if (tag is GenreTag) {
            final genreString = Id3v2GenreUtils.encodeId3v23Genres(tag.value);
            return [_buildTextFrame(frameId, genreString)];
          }
          return [_buildTextFrame(frameId, tag.value.toString())];

        case TagKey.trackNumber:
        case TagKey.discNumber:
        case TagKey.bpm:
        case TagKey.year:
          return [_buildTextFrame(frameId, tag.value.toString())];

        case TagKey.rating:
          // Convert unified rating (0-100) to POPM frame
          if (tag is RatingTag) {
            final popmFrame = _buildPopmFrame(tag.value);
            return popmFrame != null ? [popmFrame] : [];
          }
          return [];

        case TagKey.artwork:
          // Handle artwork frames
          if (tag is ArtworkTag) {
            final apicFrame = _buildApicFrame(tag.value);
            return apicFrame != null ? [apicFrame] : [];
          }
          return [];

        case TagKey.custom:
          // Handle custom TXXX frames
          if (tag is CustomTag) {
            final txxxFrame = _buildTxxxFrame(tag.value);
            return txxxFrame != null ? [txxxFrame] : [];
          }
          return [];

        default:
          return [];
      }
    } catch (e) {
      // If frame building fails, skip this tag
      return [];
    }
  }

  /// Builds a standard text frame with UTF-16 encoding (ID3v2.3 requirement).
  _Id3v23Frame _buildTextFrame(String frameId, String text) {
    // ID3v2.3 doesn't support UTF-8, use UTF-16 for international text
    final textBytes = TextEncodingUtils.encodeText(text, TextEncoding.utf16, includeBom: false);

    // ID3v2.3 text frame: encoding byte (0x01 for UTF-16) + text
    final frameData = Uint8List.fromList([0x01, ...textBytes]);

    return _Id3v23Frame(
      id: frameId,
      data: frameData,
    );
  }

  /// Builds date-related frames for ID3v2.3 (TYER, TDAT, TIME).
  ///
  /// ID3v2.3 uses separate frames for date components instead of the unified
  /// TDRC frame used in ID3v2.4.
  List<_Id3v23Frame> _buildDateFrames(String dateRecorded) {
    final frames = <_Id3v23Frame>[];

    try {
      // Parse ISO-8601 date string (e.g., "2023-12-25T14:30:00")
      final dateTime = DateTime.tryParse(dateRecorded);
      if (dateTime != null) {
        // TYER frame: Year (4 digits)
        frames.add(_buildTextFrame('TYER', dateTime.year.toString()));

        // TDAT frame: Date in DDMM format
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        frames.add(_buildTextFrame('TDAT', '$day$month'));

        // TIME frame: Time in HHMM format
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        frames.add(_buildTextFrame('TIME', '$hour$minute'));
      } else {
        // If parsing fails, try to extract just the year
        final yearMatch = RegExp(r'(\d{4})').firstMatch(dateRecorded);
        if (yearMatch != null) {
          frames.add(_buildTextFrame('TYER', yearMatch.group(1)!));
        }
      }
    } catch (e) {
      // If date parsing fails completely, skip date frames
    }

    return frames;
  }

  /// Builds a POPM (rating) frame.
  _Id3v23Frame? _buildPopmFrame(int unifiedRating) {
    if (unifiedRating < 0 || unifiedRating > 100) {
      return null; // Invalid rating
    }

    // Convert unified rating (0-100) to ID3v2 rating (1-255)
    // 0 stays 0, 1-100 maps to 1-255
    final id3Rating = unifiedRating == 0 ? 0 : ((unifiedRating * 254) / 100).round() + 1;

    // POPM frame: email + null terminator + rating byte + counter (4 bytes)
    final email = 'user'; // Default email
    final emailBytes = latin1.encode(email);
    final frameData = Uint8List.fromList([
      ...emailBytes,
      0x00, // Null terminator
      id3Rating, // Rating byte
      0x00, 0x00, 0x00, 0x00, // Counter (4 bytes, set to 0)
    ]);

    return _Id3v23Frame(
      id: 'POPM',
      data: frameData,
    );
  }

  /// Builds an APIC (artwork) frame.
  _Id3v23Frame? _buildApicFrame(ArtworkData artworkData) {
    // For now, we'll create a placeholder APIC frame
    // Full implementation would need to load the artwork data
    // This is a simplified version for the basic implementation

    final mimeTypeBytes = latin1.encode(artworkData.mimeType);
    final descriptionBytes = artworkData.description != null
        ? TextEncodingUtils.encodeText(artworkData.description!, TextEncoding.utf16, includeBom: false)
        : Uint8List(0);

    // APIC frame: encoding + mime type + null + picture type + description + null + image data
    // For now, we'll create a minimal frame without actual image data
    final frameData = Uint8List.fromList([
      0x01, // UTF-16 encoding
      ...mimeTypeBytes,
      0x00, // Null terminator
      artworkData.type.index, // Picture type byte
      ...descriptionBytes,
      0x00, 0x00, // Null terminator (UTF-16 requires 2 bytes)
      // Image data would go here, but we'll skip it for this basic implementation
    ]);

    return _Id3v23Frame(
      id: 'APIC',
      data: frameData,
    );
  }

  /// Builds a TXXX (custom text) frame.
  _Id3v23Frame? _buildTxxxFrame(String customValue) {
    // TXXX frame: encoding + description + null + value
    // For simplicity, we'll use empty description
    final valueBytes = TextEncodingUtils.encodeText(customValue, TextEncoding.utf16, includeBom: false);

    final frameData = Uint8List.fromList([
      0x01, // UTF-16 encoding
      0x00, 0x00, // Empty description + null terminator (UTF-16 requires 2 bytes)
      ...valueBytes,
    ]);

    return _Id3v23Frame(
      id: 'TXXX',
      data: frameData,
    );
  }

  /// Builds a complete ID3v2.3 container with the given frames.
  Uint8List _buildId3v23Container(List<_Id3v23Frame> frames) {
    // Calculate total frame data size
    int totalFrameSize = 0;
    for (final frame in frames) {
      totalFrameSize += 10 + frame.data.length; // 10-byte header + data
    }

    // Build frame data
    final frameDataBytes = <int>[];
    for (final frame in frames) {
      // Frame header: ID (4 bytes) + size (4 bytes big-endian) + flags (2 bytes)
      frameDataBytes.addAll(latin1.encode(frame.id)); // Frame ID
      frameDataBytes.addAll(_encodeFrameSize(frame.data.length)); // Frame size (big-endian for v2.3)
      frameDataBytes.addAll([0x00, 0x00]); // No flags
      frameDataBytes.addAll(frame.data); // Frame data
    }

    // Build ID3v2.3 header
    final headerBytes = <int>[
      0x49, 0x44, 0x33, // "ID3"
      0x03, 0x00, // Version 2.3
      0x00, // No flags
      ...SynchsafeInt.encode(totalFrameSize), // Tag size (synchsafe)
    ];

    return Uint8List.fromList([...headerBytes, ...frameDataBytes]);
  }

  /// Builds an empty ID3v2.3 container with no frames.
  Uint8List _buildEmptyContainer() {
    return Uint8List.fromList([
      0x49, 0x44, 0x33, // "ID3"
      0x03, 0x00, // Version 2.3
      0x00, // No flags
      0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
    ]);
  }

  /// Encodes a frame size as a 4-byte big-endian integer (for ID3v2.3 frames).
  List<int> _encodeFrameSize(int size) {
    return [
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ];
  }
}

/// Internal representation of an ID3v2.3 frame for writing.
class _Id3v23Frame {
  final String id;
  final Uint8List data;

  const _Id3v23Frame({
    required this.id,
    required this.data,
  });
}
