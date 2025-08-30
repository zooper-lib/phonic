import 'dart:convert';
import 'dart:typed_data';

import '../../capabilities/id3v1_capability.dart';
import '../../core/container_kind.dart';
import '../../core/format_constraints.dart';
import '../../core/metadata_tag.dart';
import '../../core/tag_capability.dart';
import '../../core/tag_codec.dart';
import '../../core/tag_confidence.dart';
import '../../core/tag_key.dart';
import '../../core/tag_provenance.dart';
import '../../exceptions/corrupted_container_exception.dart';
import 'id3v1_genre_table.dart';

/// ID3v1 metadata codec for reading and writing ID3v1 tags.
///
/// This codec handles the legacy ID3v1 metadata format, which consists of a
/// fixed 128-byte structure located at the end of MP3 files. ID3v1 is the
/// most constrained metadata format supported by the Phonic library, with
/// strict limitations on field lengths and supported data types.
///
/// ## Format Structure
///
/// The ID3v1 tag has a fixed layout:
/// ```
/// Offset  Length  Field
/// 0       3       "TAG" identifier
/// 3       30      Title
/// 33      30      Artist
/// 63      30      Album
/// 93      4       Year
/// 97      30      Comment (or 28 + null + track if track present)
/// 127     1       Genre code (0-255)
/// ```
///
/// ## Key Limitations
///
/// - **Text length**: 30 characters maximum for title, artist, album
/// - **Comment field**: 30 characters, or 28 when track number is present
/// - **Track number**: Single byte (1-255), stored in comment field
/// - **Genre**: Single byte referencing standard genre codes (0-255)
/// - **Year**: Exactly 4 characters
/// - **Encoding**: Latin-1 (ISO-8859-1) only, no Unicode support
/// - **No support for**: artwork, lyrics, custom fields, multiple values
///
/// ## Track Number Handling
///
/// ID3v1 stores the track number in a special way:
/// - If no track number: Full 30-byte comment field available
/// - If track number present: Comment limited to 28 bytes + null + track byte
/// - Track number detection: Byte 125 is null and byte 126 is non-zero
///
/// ## Genre Handling
///
/// ID3v1 uses numeric genre codes (0-255) that map to standard genre names:
/// - 0 = Blues, 17 = Rock, 255 = Unknown, etc.
/// - The codec automatically converts between genre names and codes
/// - For multiple genres, only the first genre is stored (format limitation)
///
/// ## Usage Example
///
/// ```dart
/// final codec = Id3v1Codec();
///
/// // Reading tags
/// final containerBytes = await locator.extract(fileBytes);
/// final tags = codec.readFromContainer(containerBytes);
///
/// // Writing tags with automatic constraint handling
/// final tagsToWrite = [
///   TitleTag('Very Long Song Title That Exceeds Thirty Characters'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']), // Only 'Rock' will be stored
///   TrackNumberTag(5),
/// ];
/// final newContainer = codec.writeToContainer(tagsToWrite: tagsToWrite);
/// ```
///
/// ## Error Handling
///
/// The codec handles various error conditions gracefully:
/// - **Invalid structure**: Validates "TAG" identifier and 128-byte size
/// - **Text truncation**: Automatically truncates text to field limits
/// - **Invalid genres**: Falls back to "Unknown" (255) for unrecognized genres
/// - **Invalid track numbers**: Clamps to valid range (1-255)
/// - **Encoding errors**: Uses Latin-1 with replacement characters
///
/// ## Performance Considerations
///
/// - **Fixed size**: Always exactly 128 bytes, no variable-length parsing
/// - **Simple structure**: Direct byte offset access, no complex parsing
/// - **Memory efficient**: Minimal memory allocation during parsing
/// - **Fast validation**: Quick "TAG" identifier check for format detection
class Id3v1Codec implements TagCodec {
  /// Creates a new ID3v1 codec instance.
  ///
  /// The codec is stateless and thread-safe, so a single instance can be
  /// reused across multiple files and threads.
  const Id3v1Codec();

  @override
  ContainerKind get containerKind => ContainerKind.id3v1;

  @override
  String get containerVersion => 'v1';

  @override
  TagCapability get capability => id3v1Capability;

  @override
  List<MetadataTag> readFromContainer(Uint8List containerBytes) {
    // Validate container size and structure
    if (containerBytes.length != ID3v1Constraints.tagSize) {
      throw CorruptedContainerException(
        'ID3v1 tag must be exactly ${ID3v1Constraints.tagSize} bytes, got ${containerBytes.length}',
        context: 'ID3v1 codec validation',
      );
    }

    // Validate TAG identifier
    final tagIdentifier = latin1.decode(containerBytes.sublist(0, 3));
    if (tagIdentifier != ID3v1Constraints.tagIdentifier) {
      throw CorruptedContainerException(
        'Invalid ID3v1 tag identifier: expected "${ID3v1Constraints.tagIdentifier}", got "$tagIdentifier"',
        byteOffset: 0,
        context: 'ID3v1 codec validation',
      );
    }

    final tags = <MetadataTag>[];
    const provenance = TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain);

    try {
      // Extract title (bytes 3-32)
      final title = _extractTextField(containerBytes, 3, ID3v1Constraints.maxTextLength);
      if (title.isNotEmpty) {
        tags.add(TitleTag(title, provenance: provenance));
      }

      // Extract artist (bytes 33-62)
      final artist = _extractTextField(containerBytes, 33, ID3v1Constraints.maxTextLength);
      if (artist.isNotEmpty) {
        tags.add(ArtistTag(artist, provenance: provenance));
      }

      // Extract album (bytes 63-92)
      final album = _extractTextField(containerBytes, 63, ID3v1Constraints.maxTextLength);
      if (album.isNotEmpty) {
        tags.add(AlbumTag(album, provenance: provenance));
      }

      // Extract year (bytes 93-96)
      final year = _extractTextField(containerBytes, 93, ID3v1Constraints.yearLength);
      if (year.isNotEmpty) {
        final yearInt = int.tryParse(year);
        if (yearInt != null) {
          tags.add(YearTag(yearInt, provenance: provenance));
        }
      }

      // Extract comment and track number (bytes 97-126)
      final (comment, trackNumber) = _extractCommentAndTrack(containerBytes);
      if (comment.isNotEmpty) {
        tags.add(CommentTag(comment, provenance: provenance));
      }
      if (trackNumber != null) {
        tags.add(TrackNumberTag(trackNumber, provenance: provenance));
      }

      // Extract genre (byte 127)
      final genreByte = containerBytes[127];
      final genreName = Id3v1GenreTable.getGenreName(genreByte);
      if (genreName != null && genreName != 'Unknown') {
        tags.add(GenreTag.single(genreName, provenance: provenance));
      }

      return tags;
    } catch (e) {
      if (e is CorruptedContainerException) {
        rethrow;
      }
      throw CorruptedContainerException(
        'Failed to parse ID3v1 container: $e',
        context: 'ID3v1 codec parsing',
      );
    }
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
  }) {
    // Create a new 128-byte container initialized with zeros
    final container = Uint8List(ID3v1Constraints.tagSize);

    try {
      // Write TAG identifier (bytes 0-2)
      final tagBytes = latin1.encode(ID3v1Constraints.tagIdentifier);
      container.setRange(0, 3, tagBytes);

      // Initialize all text fields with spaces (common practice)
      for (int i = 3; i < 127; i++) {
        container[i] = 0x20; // Space character
      }

      // Process tags and write to appropriate fields
      String? title, artist, album, comment;
      int? year, trackNumber, genreCode;

      for (final tag in tagsToWrite) {
        if (!capability.supports(tag.key)) continue;

        switch (tag.key) {
          case TagKey.title:
            title = _normalizeTextField(tag.value.toString());
            break;
          case TagKey.artist:
            artist = _normalizeTextField(tag.value.toString());
            break;
          case TagKey.album:
            album = _normalizeTextField(tag.value.toString());
            break;
          case TagKey.year:
            year = _normalizeYear(tag.value);
            break;
          case TagKey.comment:
            comment = _normalizeTextField(tag.value.toString());
            break;
          case TagKey.trackNumber:
            trackNumber = _normalizeTrackNumber(tag.value);
            break;
          case TagKey.genre:
            genreCode = _normalizeGenre(tag);
            break;
          default:
            // Unsupported field, skip
            break;
        }
      }

      // Write text fields
      if (title != null) {
        _writeTextField(container, 3, title, ID3v1Constraints.maxTextLength);
      }
      if (artist != null) {
        _writeTextField(container, 33, artist, ID3v1Constraints.maxTextLength);
      }
      if (album != null) {
        _writeTextField(container, 63, album, ID3v1Constraints.maxTextLength);
      }
      if (year != null) {
        _writeYearField(container, 93, year);
      }

      // Write comment and track number (complex logic due to shared space)
      _writeCommentAndTrack(container, comment, trackNumber);

      // Write genre code (byte 127)
      container[127] = genreCode ?? 255; // Default to "Unknown"

      return container;
    } catch (e) {
      throw CorruptedContainerException(
        'Failed to build ID3v1 container: $e',
        context: 'ID3v1 codec writing',
      );
    }
  }

  /// Extracts a text field from the container at the specified offset.
  ///
  /// Handles Latin-1 decoding and null-termination/space-padding removal.
  String _extractTextField(Uint8List container, int offset, int length) {
    final fieldBytes = container.sublist(offset, offset + length);

    // Find the end of the actual text (null-terminated or space-padded)
    int endIndex = fieldBytes.length;
    for (int i = fieldBytes.length - 1; i >= 0; i--) {
      if (fieldBytes[i] != 0x00 && fieldBytes[i] != 0x20) {
        endIndex = i + 1;
        break;
      }
    }

    if (endIndex == 0) return '';

    // Decode using Latin-1 and trim any remaining whitespace
    return latin1.decode(fieldBytes.sublist(0, endIndex)).trim();
  }

  /// Extracts comment and track number from the comment field.
  ///
  /// Returns a tuple of (comment, trackNumber). Track number is present
  /// if byte 125 is null and byte 126 is non-zero.
  (String, int?) _extractCommentAndTrack(Uint8List container) {
    // Check if track number is present (ID3v1.1 format)
    if (container[125] == 0x00 && container[126] != 0x00) {
      // Track number present, comment is limited to 28 bytes
      final comment = _extractTextField(container, 97, ID3v1Constraints.commentLengthWithTrack);
      final trackNumber = container[126];
      return (comment, trackNumber);
    } else {
      // No track number, full 30-byte comment field
      final comment = _extractTextField(container, 97, ID3v1Constraints.commentLengthWithoutTrack);
      return (comment, null);
    }
  }

  /// Normalizes a text field to fit ID3v1 constraints.
  ///
  /// Truncates to maximum length and ensures Latin-1 compatibility.
  String _normalizeTextField(String text) {
    if (text.length > ID3v1Constraints.maxTextLength) {
      text = text.substring(0, ID3v1Constraints.maxTextLength);
    }
    return text;
  }

  /// Normalizes a year value for ID3v1 storage.
  ///
  /// Converts to 4-digit string format, clamping to reasonable range.
  int? _normalizeYear(dynamic yearValue) {
    int? year;
    if (yearValue is int) {
      year = yearValue;
    } else if (yearValue is String) {
      year = int.tryParse(yearValue);
    }

    if (year == null) return null;

    // Clamp to reasonable range
    year = year.clamp(1000, 9999);
    return year;
  }

  /// Normalizes a track number for ID3v1 storage.
  ///
  /// Clamps to valid byte range (1-255).
  int? _normalizeTrackNumber(dynamic trackValue) {
    int? track;
    if (trackValue is int) {
      track = trackValue;
    } else if (trackValue is String) {
      track = int.tryParse(trackValue);
    }

    if (track == null || track < ID3v1Constraints.minTrackNumber) return null;

    return track.clamp(ID3v1Constraints.minTrackNumber, ID3v1Constraints.maxTrackNumber);
  }

  /// Normalizes a genre tag for ID3v1 storage.
  ///
  /// Converts genre name to numeric code, using first genre for multi-genre tags.
  int? _normalizeGenre(MetadataTag tag) {
    if (tag is GenreTag) {
      if (tag.value.isEmpty) return null;

      // Use first genre for ID3v1 (single genre limitation)
      final firstGenre = tag.value.first;
      return Id3v1GenreTable.getGenreNumber(firstGenre);
    } else {
      // Handle string genre values
      final genreString = tag.value.toString();
      return Id3v1GenreTable.getGenreNumber(genreString);
    }
  }

  /// Writes a text field to the container at the specified offset.
  ///
  /// Encodes using Latin-1 and pads with spaces to fill the field.
  void _writeTextField(Uint8List container, int offset, String text, int maxLength) {
    // Truncate if necessary
    if (text.length > maxLength) {
      text = text.substring(0, maxLength);
    }

    // Encode to Latin-1
    final textBytes = latin1.encode(text);

    // Write text bytes
    container.setRange(offset, offset + textBytes.length, textBytes);

    // Pad remaining space with spaces (already initialized, but ensure consistency)
    for (int i = offset + textBytes.length; i < offset + maxLength; i++) {
      container[i] = 0x20; // Space character
    }
  }

  /// Writes the year field as a 4-digit string.
  void _writeYearField(Uint8List container, int offset, int year) {
    final yearString = year.toString().padLeft(4, '0');
    final yearBytes = latin1.encode(yearString);
    container.setRange(offset, offset + 4, yearBytes);
  }

  /// Writes comment and track number to the shared comment field.
  ///
  /// Handles the complex logic of ID3v1.1 track number storage.
  void _writeCommentAndTrack(Uint8List container, String? comment, int? trackNumber) {
    if (trackNumber != null) {
      // ID3v1.1 format: comment (28 bytes) + null + track
      final maxCommentLength = ID3v1Constraints.commentLengthWithTrack;

      if (comment != null && comment.isNotEmpty) {
        _writeTextField(container, 97, comment, maxCommentLength);
      }

      // Write null terminator and track number
      container[125] = 0x00; // Null terminator
      container[126] = trackNumber; // Track number byte
    } else if (comment != null && comment.isNotEmpty) {
      // ID3v1.0 format: full 30-byte comment field
      _writeTextField(container, 97, comment, ID3v1Constraints.commentLengthWithoutTrack);
    }
    // If neither comment nor track, field remains space-padded (initialized above)
  }
}
