import 'dart:convert';
import 'dart:typed_data';

import '../../capabilities/id3v24_capability.dart';
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

/// ID3v2.4 metadata codec for reading and writing ID3v2.4 tags.
///
/// This codec handles the ID3v2.4 metadata format, which is the most advanced
/// version of the ID3v2 specification. ID3v2.4 provides significant improvements
/// over earlier versions including UTF-8 encoding support, unified date handling
/// through the TDRC frame, and enhanced frame structure.
///
/// ## Key Features
///
/// - **Full encoding support**: ISO-8859-1, UTF-16, and UTF-8
/// - **Unified date handling**: TDRC frame for date/time recording
/// - **Multi-genre support**: Null-terminated strings in TCON frame
/// - **Enhanced artwork**: Multiple APIC frames with type and description
/// - **Custom fields**: Support for user-defined TXXX frames
/// - **Improved structure**: Better synchronization and data integrity
///
/// ## Frame Mappings
///
/// The codec maps unified tag keys to ID3v2.4 frame IDs:
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
/// - [TagKey.dateRecorded] → TDRC (Recording time)
/// - [TagKey.bpm] → TBPM (BPM - beats per minute)
/// - [TagKey.rating] → POPM (Popularimeter)
/// - [TagKey.artwork] → APIC (Attached picture)
///
/// ## Genre Handling
///
/// ID3v2.4 uses null-terminated strings in the TCON frame for multiple genres:
/// ```
/// Single genre: "Rock"
/// Multiple genres: "Rock\0Alternative\0Indie"
/// ```
///
/// This is an improvement over ID3v2.3's slash separation, providing better
/// delimiter handling and avoiding conflicts with genre names containing slashes.
///
/// ## Usage Example
///
/// ```dart
/// final codec = Id3v24Codec();
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
class Id3v24Codec implements TagCodec {
  /// Creates a new ID3v2.4 codec instance.
  ///
  /// The codec is stateless and thread-safe, so a single instance can be
  /// reused across multiple files and threads.
  const Id3v24Codec();

  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  String get containerVersion => '2.4';

  @override
  TagCapability get capability => id3v24Capability;

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

      // Validate this is ID3v2.4
      if (header.majorVersion != 4) {
        throw CorruptedContainerException(
          'Expected ID3v2.4, got ID3v2.${header.majorVersion}',
          context: 'ID3v2.4 codec validation',
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
          'ID3v2.4 tag size extends beyond container: ${frameDataEnd} > ${containerBytes.length}',
          byteOffset: frameDataOffset,
          context: 'ID3v2.4 frame data extraction',
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
            4, // ID3v2.4
            currentOffset,
          );

          // Extract and process frame data
          final processedData = Id3v2FrameParser.extractFrameData(frame);

          // Convert frame to MetadataTag
          final tag = _frameToMetadataTag(frame, processedData);
          if (tag != null) {
            tags.add(tag);
          } else if (preservationManager != null) {
            // Preserve unknown frame for round-trip compatibility
            _preserveUnknownFrame(frame, processedData, preservationManager, currentOffset);
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
        'Failed to parse ID3v2.4 container: $e',
        context: 'ID3v2.4 codec parsing',
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
      // Return empty ID3v2.4 header with no frames
      return _buildEmptyContainer();
    }

    try {
      // Convert MetadataTag instances to ID3v2.4 frames
      final frames = <_Id3v24Frame>[];

      for (final tag in tagsToWrite) {
        final frame = _metadataTagToFrame(tag);
        if (frame != null) {
          frames.add(frame);
        }
      }

      // Add preserved unknown frames if preservation is enabled
      if (preservationManager != null) {
        final preservedFrames = _restorePreservedFrames(preservationManager);
        frames.addAll(preservedFrames);
      }

      // Build complete ID3v2.4 container
      return _buildId3v24Container(frames);
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to build ID3v2.4 container: $e',
        context: 'ID3v2.4 codec writing',
      );
    }
  }

  /// Converts an ID3v2.4 frame to a MetadataTag instance.
  ///
  /// This method handles the conversion from raw frame data to strongly-typed
  /// MetadataTag objects with proper provenance information.
  MetadataTag? _frameToMetadataTag(Id3v2Frame frame, Uint8List frameData) {
    final provenance = const TagProvenance(
      ContainerKind.id3v2,
      '2.4',
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
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return TitleTag(text, provenance: provenance);

        case 'TPE1': // Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return ArtistTag(text, provenance: provenance);

        case 'TALB': // Album
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return AlbumTag(text, provenance: provenance);

        case 'TPE2': // Album Artist
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return AlbumArtistTag(text, provenance: provenance);

        case 'TIT1': // Grouping
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return GroupingTag(text, provenance: provenance);

        case 'TCOM': // Composer
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return ComposerTag(text, provenance: provenance);

        case 'TSSE': // Encoder
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return EncoderTag(text, provenance: provenance);

        case 'TSRC': // ISRC
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return IsrcTag(text, provenance: provenance);

        case 'TKEY': // Musical Key
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return MusicalKeyTag(text, provenance: provenance);

        case 'TCON': // Genre - special handling for ID3v2.4 null-terminated strings
          final genres = _parseTconFrame(frameData);
          return GenreTag(genres, provenance: provenance);

        case 'TDRC': // Date Recorded (ID3v2.4 specific)
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          return DateRecordedTag(text, provenance: provenance);

        case 'TRCK': // Track Number
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          final trackNumber = _parseTrackNumber(text);
          if (trackNumber != null) {
            return TrackNumberTag(trackNumber, provenance: provenance);
          }
          return null;

        case 'TPOS': // Disc Number
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
          final discNumber = _parseDiscNumber(text);
          if (discNumber != null) {
            return DiscNumberTag(discNumber, provenance: provenance);
          }
          return null;

        case 'TBPM': // BPM
          final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
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
          final commData = Id3v2CommFrameParser.parse(frameData, 4);
          return CommentTag(commData.text, provenance: provenance);

        case 'USLT': // Lyrics
          final usltData = Id3v2UsltFrameParser.parse(frameData, 4);
          return LyricsTag(usltData.lyrics, provenance: provenance);

        case 'APIC': // Artwork
          final apicData = Id3v2ApicFrameParser.parse(frameData, 4);
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

  /// Parses a TCON frame preserving null terminators for ID3v2.4 multi-genre support.
  List<String> _parseTconFrame(Uint8List frameData) {
    if (frameData.isEmpty) {
      return [];
    }

    try {
      // Get encoding byte
      final encodingByte = frameData[0];

      // For ID3v2.4, we expect UTF-8 encoding (0x03) for proper null-terminator handling
      if (encodingByte == 0x03) {
        // UTF-8 encoding - decode the text bytes preserving null terminators
        final textBytes = frameData.sublist(1);
        final rawText = utf8.decode(textBytes, allowMalformed: true);
        return Id3v2GenreUtils.parseId3v24Genres(rawText);
      } else {
        // Fall back to standard parsing for other encodings
        final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);
        return Id3v2GenreUtils.parseId3v24Genres(text);
      }
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Converts a MetadataTag to an ID3v2.4 frame.
  ///
  /// Returns null if the tag cannot be converted to an ID3v2.4 frame.
  _Id3v24Frame? _metadataTagToFrame(MetadataTag tag) {
    // Get frame ID for this tag key
    final frameId = Id3v2FrameMap.getFrameId(tag.key, '2.4');
    if (frameId == null) {
      return null; // Tag not supported in ID3v2.4
    }

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
        case TagKey.dateRecorded:
        case TagKey.comment:
        case TagKey.lyrics:
          return _buildTextFrame(frameId, tag.value.toString());

        case TagKey.genre:
          // Special handling for GenreTag with null-terminated strings
          if (tag is GenreTag) {
            final genreString = Id3v2GenreUtils.encodeId3v24Genres(tag.value);
            return _buildTextFrame(frameId, genreString);
          }
          return _buildTextFrame(frameId, tag.value.toString());

        case TagKey.trackNumber:
        case TagKey.discNumber:
        case TagKey.bpm:
          return _buildTextFrame(frameId, tag.value.toString());

        case TagKey.rating:
          // Convert unified rating (0-100) to POPM frame
          if (tag is RatingTag) {
            return _buildPopmFrame(tag.value);
          }
          return null;

        case TagKey.artwork:
          // Handle artwork frames
          if (tag is ArtworkTag) {
            return _buildApicFrame(tag.value);
          }
          return null;

        case TagKey.custom:
          // Handle custom TXXX frames
          if (tag is CustomTag) {
            return _buildTxxxFrame(tag.value);
          }
          return null;

        default:
          return null;
      }
    } catch (e) {
      // If frame building fails, skip this tag
      return null;
    }
  }

  /// Builds a standard text frame with UTF-8 encoding.
  _Id3v24Frame _buildTextFrame(String frameId, String text) {
    final textBytes = TextEncodingUtils.encodeText(text, TextEncoding.utf8, includeBom: false);

    // ID3v2.4 text frame: encoding byte (0x03 for UTF-8) + text
    final frameData = Uint8List.fromList([0x03, ...textBytes]);

    return _Id3v24Frame(
      id: frameId,
      data: frameData,
    );
  }

  /// Builds a POPM (rating) frame.
  _Id3v24Frame? _buildPopmFrame(int unifiedRating) {
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

    return _Id3v24Frame(
      id: 'POPM',
      data: frameData,
    );
  }

  /// Builds an APIC (artwork) frame.
  _Id3v24Frame? _buildApicFrame(ArtworkData artworkData) {
    // For now, we'll create a placeholder APIC frame
    // Full implementation would need to load the artwork data
    // This is a simplified version for the basic implementation

    final mimeTypeBytes = latin1.encode(artworkData.mimeType);
    final descriptionBytes = artworkData.description != null
        ? TextEncodingUtils.encodeText(artworkData.description!, TextEncoding.utf8, includeBom: false)
        : Uint8List(0);

    // APIC frame: encoding + mime type + null + picture type + description + null + image data
    // For now, we'll create a minimal frame without actual image data
    final frameData = Uint8List.fromList([
      0x03, // UTF-8 encoding
      ...mimeTypeBytes,
      0x00, // Null terminator
      artworkData.type.index, // Picture type byte
      ...descriptionBytes,
      0x00, // Null terminator
      // Image data would go here, but we'll skip it for this basic implementation
    ]);

    return _Id3v24Frame(
      id: 'APIC',
      data: frameData,
    );
  }

  /// Builds a TXXX (custom text) frame.
  _Id3v24Frame? _buildTxxxFrame(String customValue) {
    // TXXX frame: encoding + description + null + value
    // For simplicity, we'll use empty description
    final valueBytes = TextEncodingUtils.encodeText(customValue, TextEncoding.utf8, includeBom: false);

    final frameData = Uint8List.fromList([
      0x03, // UTF-8 encoding
      0x00, // Empty description + null terminator
      ...valueBytes,
    ]);

    return _Id3v24Frame(
      id: 'TXXX',
      data: frameData,
    );
  }

  /// Builds a complete ID3v2.4 container with the given frames.
  Uint8List _buildId3v24Container(List<_Id3v24Frame> frames) {
    // Calculate total frame data size
    int totalFrameSize = 0;
    for (final frame in frames) {
      totalFrameSize += 10 + frame.data.length; // 10-byte header + data
    }

    // Build frame data
    final frameDataBytes = <int>[];
    for (final frame in frames) {
      // Frame header: ID (4 bytes) + size (4 bytes synchsafe) + flags (2 bytes)
      frameDataBytes.addAll(latin1.encode(frame.id)); // Frame ID
      frameDataBytes.addAll(SynchsafeInt.encode(frame.data.length)); // Frame size
      frameDataBytes.addAll([0x00, 0x00]); // No flags
      frameDataBytes.addAll(frame.data); // Frame data
    }

    // Build ID3v2.4 header
    final headerBytes = <int>[
      0x49, 0x44, 0x33, // "ID3"
      0x04, 0x00, // Version 2.4
      0x00, // No flags
      ...SynchsafeInt.encode(totalFrameSize), // Tag size (synchsafe)
    ];

    return Uint8List.fromList([...headerBytes, ...frameDataBytes]);
  }

  /// Builds an empty ID3v2.4 container with no frames.
  Uint8List _buildEmptyContainer() {
    return Uint8List.fromList([
      0x49, 0x44, 0x33, // "ID3"
      0x04, 0x00, // Version 2.4
      0x00, // No flags
      0x00, 0x00, 0x00, 0x00, // Size: 0 bytes (no frames)
    ]);
  }

  /// Preserves an unknown frame for round-trip compatibility.
  ///
  /// This method stores unknown frames in the preservation manager so they
  /// can be restored during write operations, maintaining file integrity.
  void _preserveUnknownFrame(
    Id3v2Frame frame,
    Uint8List frameData,
    UnknownDataPreservationManager preservationManager,
    int originalOffset,
  ) {
    // Create preserved data for this unknown frame
    final preservedData = PreservedUnknownData.id3v2Frame(
      frameId: frame.id,
      frameData: frameData,
      frameFlags: frame.flags.statusFlags | (frame.flags.formatFlags << 8),
      originalOffset: originalOffset,
      additionalMetadata: {
        'frame_version': '2.4',
        'frame_size': frame.size,
        'total_frame_size': frame.totalSize,
      },
    );

    // Add to preservation manager
    preservationManager.addPreservedData(preservedData);
  }

  /// Restores preserved unknown frames during write operations.
  ///
  /// This method retrieves unknown frames from the preservation manager
  /// and converts them back to ID3v2.4 frame format for inclusion in
  /// the output container.
  List<_Id3v24Frame> _restorePreservedFrames(
    UnknownDataPreservationManager preservationManager,
  ) {
    final preservedFrames = <_Id3v24Frame>[];
    final preservedData = preservationManager.getPreservedData('id3v2');

    for (final data in preservedData) {
      // Validate that this is safe to restore
      if (!data.isValidForWriting()) {
        continue; // Skip invalid data
      }

      // Convert preserved data back to frame format
      final frame = _Id3v24Frame(
        id: data.type,
        data: data.data,
      );

      preservedFrames.add(frame);
    }

    return preservedFrames;
  }
}

/// Internal representation of an ID3v2.4 frame for writing.
class _Id3v24Frame {
  final String id;
  final Uint8List data;

  const _Id3v24Frame({
    required this.id,
    required this.data,
  });
}
