import 'dart:convert';
import 'dart:typed_data';

import '../../capabilities/vorbis_capability.dart';
import '../../core/artwork_data.dart';
import '../../core/container_kind.dart';
import '../../core/metadata_tag.dart';
import '../../core/tag_capability.dart';
import '../../core/tag_codec.dart';
import '../../core/tag_confidence.dart';
import '../../core/tag_key.dart';
import '../../core/tag_provenance.dart';
import '../../tags/tags.dart';
import '../../utils/flac_picture_parser.dart';
import '../../utils/unknown_data_preservation.dart';
import '../../utils/vorbis_comment_parser.dart';
import 'vorbis_comment_map.dart';

/// Vorbis Comments metadata codec for reading and writing Vorbis comment blocks.
///
/// This codec handles the Vorbis Comments metadata format used in FLAC, OGG Vorbis,
/// and Opus audio files. Vorbis Comments provide a simple key-value structure with
/// full UTF-8 Unicode support and native multi-valued field capabilities.
///
/// ## Key Features
///
/// - **UTF-8 encoding**: All text fields use UTF-8 encoding exclusively
/// - **Multi-valued fields**: Native support for multiple values per field name
/// - **No length limits**: Fields can contain arbitrary amounts of text
/// - **Case-insensitive keys**: Field names are case-insensitive by convention
/// - **Extensible**: Supports custom field names for application-specific metadata
/// - **Clean structure**: Simple key=value format without complex frame headers
///
/// ## Field Mappings
///
/// The codec maps unified tag keys to Vorbis comment field names:
/// - [TagKey.title] → TITLE
/// - [TagKey.artist] → ARTIST
/// - [TagKey.album] → ALBUM
/// - [TagKey.albumArtist] → ALBUMARTIST
/// - [TagKey.genre] → GENRE (supports multiple GENRE= entries)
/// - [TagKey.comment] → COMMENT
/// - [TagKey.grouping] → GROUPING
/// - [TagKey.composer] → COMPOSER
/// - [TagKey.encoder] → ENCODER
/// - [TagKey.isrc] → ISRC
/// - [TagKey.musicalKey] → KEY
/// - [TagKey.lyrics] → LYRICS
/// - [TagKey.trackNumber] → TRACKNUMBER
/// - [TagKey.discNumber] → DISCNUMBER
/// - [TagKey.dateRecorded] → DATE (ISO-8601 format)
/// - [TagKey.bpm] → BPM
/// - [TagKey.rating] → RATING (0-100 scale)
/// - [TagKey.artwork] → METADATA_BLOCK_PICTURE (FLAC) or base64 encoding (OGG)
///
/// ## Multi-Genre Support
///
/// Vorbis Comments handle multiple genres through native multi-value support:
/// ```
/// GENRE=Rock
/// GENRE=Alternative
/// GENRE=Indie
/// ```
///
/// This approach is cleaner than delimiter-based encoding used in other formats,
/// as it avoids parsing ambiguities and supports genres containing special characters.
///
/// ## Container Format Differences
///
/// - **FLAC**: Vorbis comments stored in VORBIS_COMMENT metadata block
/// - **OGG Vorbis**: Comments in the second OGG page header
/// - **Opus**: Comments in OpusHead packet structure
///
/// The codec abstracts these differences and works with the extracted comment
/// data regardless of the container format.
///
/// ## Usage Example
///
/// ```dart
/// final codec = VorbisCommentsCodec();
///
/// // Reading tags
/// final tags = codec.readFromContainer(commentBytes);
/// final genreTag = tags.whereType<GenreTag>().firstOrNull;
/// print('Genres: ${genreTag?.value}'); // ['Rock', 'Alternative', 'Indie']
///
/// // Writing tags
/// final tagsToWrite = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Electronic', 'Ambient']),
/// ];
/// final encodedBytes = codec.writeToContainer(tagsToWrite: tagsToWrite);
/// ```
///
/// ## Performance Characteristics
///
/// - **Memory efficient**: Processes comments incrementally without loading entire file
/// - **Lazy artwork**: Uses [LazyArtworkLoader] for METADATA_BLOCK_PICTURE data
/// - **UTF-8 optimized**: Single encoding reduces conversion overhead
/// - **Multi-value friendly**: Native support avoids delimiter parsing costs
class VorbisCommentsCodec implements TagCodec {
  /// Creates a new Vorbis Comments codec instance.
  ///
  /// The codec is stateless and thread-safe, suitable for concurrent use
  /// across multiple files and operations.
  const VorbisCommentsCodec();

  @override
  ContainerKind get containerKind => ContainerKind.vorbis;

  @override
  String get containerVersion => '';

  @override
  TagCapability get capability => vorbisCapability;

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (containerBytes.isEmpty) {
      return [];
    }

    final parser = const VorbisCommentParser();
    final tags = <MetadataTag>[];

    try {
      // Parse all Vorbis comments from the container
      final comments = parser.parseComments(containerBytes);

      if (comments.isEmpty) {
        return [];
      }

      // Group comments by field name for easier processing
      final groupedComments = parser.groupCommentsByField(comments);

      // Create provenance for all tags from this container
      final provenance = TagProvenance(
        containerKind,
        containerVersion,
        TagConfidence.certain,
      );

      // Process each supported field type
      for (final entry in groupedComments.entries) {
        final fieldName = entry.key;
        final values = entry.value;

        if (values.isEmpty) continue;

        // Map field names to tag creation
        switch (fieldName) {
          case 'TITLE':
            tags.add(TitleTag(values.first, provenance: provenance));
            break;

          case 'ARTIST':
            tags.add(ArtistTag(values.first, provenance: provenance));
            break;

          case 'ALBUM':
            tags.add(AlbumTag(values.first, provenance: provenance));
            break;

          case 'ALBUMARTIST':
            tags.add(AlbumArtistTag(values.first, provenance: provenance));
            break;

          case 'TRACKNUMBER':
            final trackNumber = int.tryParse(values.first);
            if (trackNumber != null && trackNumber > 0) {
              tags.add(TrackNumberTag(trackNumber, provenance: provenance));
            }
            break;

          case 'DISCNUMBER':
            final discNumber = int.tryParse(values.first);
            if (discNumber != null && discNumber > 0) {
              tags.add(DiscNumberTag(discNumber, provenance: provenance));
            }
            break;

          case 'DATE':
            tags.add(DateRecordedTag(values.first, provenance: provenance));
            break;

          case 'GENRE':
            // Handle multiple GENRE fields for GenreTag creation
            final allGenres = <String>[];

            for (final genreValue in values) {
              // Skip empty or whitespace-only genre values
              if (genreValue.trim().isEmpty) {
                continue;
              }

              // Handle mixed scenarios where some GENRE fields contain delimited values
              if (genreValue.contains(';') || genreValue.contains('/') || genreValue.contains('|') || genreValue.contains(',') || genreValue.contains('\\')) {
                // Parse delimited genres within single field
                final parsedGenres = GenreTag.fromString(genreValue);
                allGenres.addAll(parsedGenres.value);
              } else {
                // Single genre value
                allGenres.add(genreValue);
              }
            }

            if (allGenres.isNotEmpty) {
              tags.add(GenreTag(allGenres, provenance: provenance));
            }
            break;

          case 'COMMENT':
            tags.add(CommentTag(values.first, provenance: provenance));
            break;

          case 'BPM':
            final bpm = int.tryParse(values.first);
            if (bpm != null && bpm >= BpmTag.minBpm && bpm <= BpmTag.maxBpm) {
              tags.add(BpmTag(bpm, provenance: provenance));
            }
            break;

          case 'KEY':
            tags.add(MusicalKeyTag(values.first, provenance: provenance));
            break;

          case 'RATING':
            final rating = int.tryParse(values.first);
            if (rating != null && rating >= RatingTag.minRating && rating <= RatingTag.maxRating) {
              tags.add(RatingTag(rating, provenance: provenance));
            }
            break;

          case 'LYRICS':
            tags.add(LyricsTag(values.first, provenance: provenance));
            break;

          case 'GROUPING':
            tags.add(GroupingTag(values.first, provenance: provenance));
            break;

          case 'COMPOSER':
            tags.add(ComposerTag(values.first, provenance: provenance));
            break;

          case 'ENCODER':
            tags.add(EncoderTag(values.first, provenance: provenance));
            break;

          case 'ISRC':
            tags.add(IsrcTag(values.first, provenance: provenance));
            break;

          default:
            // Handle custom fields that don't map to standard tags
            if (!VorbisCommentMap.isStandardField(fieldName)) {
              // Create custom tags for non-standard fields
              for (final value in values) {
                tags.add(CustomTag(value, provenance: provenance));
              }
            }
            break;
        }
      }

      return tags;
    } catch (e) {
      // Return empty list on parsing errors to maintain graceful degradation
      return [];
    }
  }

  /// Parses METADATA_BLOCK_PICTURE blocks from FLAC files.
  ///
  /// This method handles parsing of FLAC METADATA_BLOCK_PICTURE blocks which contain
  /// embedded artwork data. It creates [ArtworkTag] instances with lazy loading
  /// for memory efficiency.
  ///
  /// Parameters:
  /// - [pictureBlockBytes]: The raw METADATA_BLOCK_PICTURE block bytes
  ///
  /// Returns an [ArtworkTag] with the parsed artwork data and lazy loading.
  ///
  /// Throws [FormatException] if the picture block is malformed.
  ///
  /// Example:
  /// ```dart
  /// final codec = VorbisCommentsCodec();
  /// final pictureBlockBytes = getMetadataBlockPictureBytes();
  /// final artworkTag = codec.parseMetadataBlockPicture(pictureBlockBytes);
  ///
  /// print('Artwork type: ${artworkTag.value.type}');
  /// print('MIME type: ${artworkTag.value.mimeType}');
  ///
  /// // Load image data when needed
  /// final imageBytes = await artworkTag.value.data;
  /// ```
  ArtworkTag parseMetadataBlockPicture(Uint8List pictureBlockBytes) {
    const parser = FlacPictureParser();
    final artworkData = parser.parsePictureBlock(pictureBlockBytes);

    return ArtworkTag(artworkData);
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (tagsToWrite.isEmpty) {
      // Create minimal Vorbis comment block with just vendor string
      return _buildVorbisCommentBlock([]);
    }

    // Convert MetadataTag instances to key=value pairs
    final comments = <String>[];

    for (final tag in tagsToWrite) {
      final commentStrings = _tagToCommentStrings(tag);
      comments.addAll(commentStrings);
    }

    // Build complete comment block with vendor string
    return _buildVorbisCommentBlock(comments);
  }

  /// Converts a MetadataTag to one or more Vorbis comment strings.
  ///
  /// This method handles the conversion of unified tag types to their
  /// corresponding Vorbis comment field names and formats. Some tags
  /// may generate multiple comment strings (e.g., GenreTag with multiple genres).
  ///
  /// Parameters:
  /// - [tag]: The MetadataTag to convert
  ///
  /// Returns a list of comment strings in "KEY=VALUE" format.
  List<String> _tagToCommentStrings(MetadataTag tag) {
    if (tag.key == TagKey.title) {
      return ['TITLE=${tag.value}'];
    } else if (tag.key == TagKey.artist) {
      return ['ARTIST=${tag.value}'];
    } else if (tag.key == TagKey.album) {
      return ['ALBUM=${tag.value}'];
    } else if (tag.key == TagKey.albumArtist) {
      return ['ALBUMARTIST=${tag.value}'];
    } else if (tag.key == TagKey.trackNumber) {
      return ['TRACKNUMBER=${tag.value}'];
    } else if (tag.key == TagKey.discNumber) {
      return ['DISCNUMBER=${tag.value}'];
    } else if (tag.key == TagKey.dateRecorded) {
      return ['DATE=${tag.value}'];
    } else if (tag.key == TagKey.genre) {
      // Handle GenreTag encoding to multiple GENRE fields
      if (tag is GenreTag) {
        return tag.value.map((genre) => 'GENRE=$genre').toList();
      }
      return ['GENRE=${tag.value}'];
    } else if (tag.key == TagKey.comment) {
      return ['COMMENT=${tag.value}'];
    } else if (tag.key == TagKey.bpm) {
      return ['BPM=${tag.value}'];
    } else if (tag.key == TagKey.musicalKey) {
      return ['KEY=${tag.value}'];
    } else if (tag.key == TagKey.rating) {
      return ['RATING=${tag.value}'];
    } else if (tag.key == TagKey.lyrics) {
      return ['LYRICS=${tag.value}'];
    } else if (tag.key == TagKey.grouping) {
      return ['GROUPING=${tag.value}'];
    } else if (tag.key == TagKey.composer) {
      return ['COMPOSER=${tag.value}'];
    } else if (tag.key == TagKey.encoder) {
      return ['ENCODER=${tag.value}'];
    } else if (tag.key == TagKey.isrc) {
      return ['ISRC=${tag.value}'];
    } else if (tag.key == TagKey.year) {
      // Map year to DATE field for Vorbis comments
      return ['DATE=${tag.value}'];
    } else if (tag.key == TagKey.artwork) {
      // Artwork is handled separately via METADATA_BLOCK_PICTURE
      // This is not encoded as a regular comment field
      return [];
    } else if (tag.key == TagKey.custom) {
      // Custom tags use the value directly as field name
      if (tag is CustomTag) {
        // For custom tags, we need a way to determine the field name
        // Since CustomTag doesn't store the field name separately,
        // we'll use a generic CUSTOM field for now
        return ['CUSTOM=${tag.value}'];
      }
      return ['CUSTOM=${tag.value}'];
    } else {
      // Unknown tag key, skip it
      return [];
    }
  }

  /// Builds a complete Vorbis comment block from a list of comment strings.
  ///
  /// This method creates the binary structure required for Vorbis comments:
  /// - Vendor string length and content
  /// - User comment list length
  /// - Individual comment lengths and content
  ///
  /// Parameters:
  /// - [comments]: List of comment strings in "KEY=VALUE" format
  ///
  /// Returns the complete Vorbis comment block as bytes.
  Uint8List _buildVorbisCommentBlock(List<String> comments) {
    final buffer = <int>[];

    // Use a standard vendor string for Phonic library
    const vendorString = 'Phonic Dart Library';
    final vendorBytes = utf8.encode(vendorString);

    // Write vendor string length (little-endian)
    buffer.addAll(_uint32ToLittleEndianBytes(vendorBytes.length));

    // Write vendor string
    buffer.addAll(vendorBytes);

    // Write user comment list length (little-endian)
    buffer.addAll(_uint32ToLittleEndianBytes(comments.length));

    // Write each comment
    for (final comment in comments) {
      final commentBytes = utf8.encode(comment);

      // Write comment length (little-endian)
      buffer.addAll(_uint32ToLittleEndianBytes(commentBytes.length));

      // Write comment content
      buffer.addAll(commentBytes);
    }

    return Uint8List.fromList(buffer);
  }

  /// Encodes artwork data to METADATA_BLOCK_PICTURE format.
  ///
  /// This method creates a FLAC METADATA_BLOCK_PICTURE block from [ArtworkData].
  /// The resulting block can be embedded in FLAC files or base64-encoded for
  /// OGG formats.
  ///
  /// Parameters:
  /// - [artworkData]: The artwork data to encode
  ///
  /// Returns the METADATA_BLOCK_PICTURE block as bytes.
  ///
  /// Throws [ArgumentError] if the artwork data is invalid.
  ///
  /// Example:
  /// ```dart
  /// final codec = VorbisCommentsCodec();
  /// final artworkTag = ArtworkTag(artworkData);
  /// final pictureBlock = await codec.encodeMetadataBlockPicture(artworkData);
  /// ```
  Future<Uint8List> encodeMetadataBlockPicture(ArtworkData artworkData) async {
    final buffer = <int>[];
    const parser = FlacPictureParser();

    // Get the picture type value
    final pictureTypeValue = parser.mapArtworkTypeToFlacPictureType(artworkData.type);

    // Write picture type (32-bit big-endian)
    buffer.addAll(_uint32ToBigEndianBytes(pictureTypeValue));

    // Write MIME type
    final mimeTypeBytes = utf8.encode(artworkData.mimeType);
    buffer.addAll(_uint32ToBigEndianBytes(mimeTypeBytes.length));
    buffer.addAll(mimeTypeBytes);

    // Write description
    final description = artworkData.description ?? '';
    final descriptionBytes = utf8.encode(description);
    buffer.addAll(_uint32ToBigEndianBytes(descriptionBytes.length));
    buffer.addAll(descriptionBytes);

    // Write picture dimensions (set to 0 for unknown)
    buffer.addAll(_uint32ToBigEndianBytes(0)); // width
    buffer.addAll(_uint32ToBigEndianBytes(0)); // height
    buffer.addAll(_uint32ToBigEndianBytes(0)); // color depth
    buffer.addAll(_uint32ToBigEndianBytes(0)); // number of colors

    // Load and write picture data
    final pictureData = await artworkData.data;
    buffer.addAll(_uint32ToBigEndianBytes(pictureData.length));
    buffer.addAll(pictureData);

    return Uint8List.fromList(buffer);
  }

  /// Converts a 32-bit unsigned integer to little-endian bytes.
  ///
  /// Vorbis comments use little-endian byte order for all length fields.
  ///
  /// Parameters:
  /// - [value]: The 32-bit unsigned integer to convert
  ///
  /// Returns a list of 4 bytes in little-endian order.
  List<int> _uint32ToLittleEndianBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  /// Converts a 32-bit unsigned integer to big-endian bytes.
  ///
  /// METADATA_BLOCK_PICTURE uses big-endian byte order for all fields.
  ///
  /// Parameters:
  /// - [value]: The 32-bit unsigned integer to convert
  ///
  /// Returns a list of 4 bytes in big-endian order.
  List<int> _uint32ToBigEndianBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
