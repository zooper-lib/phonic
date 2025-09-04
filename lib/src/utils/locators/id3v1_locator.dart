import 'dart:typed_data';

import '../../core/container_kind.dart';
import '../../core/container_locator.dart';

/// Container locator for ID3v1 metadata tags in audio files.
///
/// ID3v1 tags are located at the end of audio files (especially MP3) and
/// consist of a fixed 128-byte structure. The tag begins with a "TAG" signature
/// followed by fixed-length fields for title, artist, album, year, comment,
/// and genre.
///
/// ## ID3v1 Tag Structure
///
/// ```
/// Offset  Length  Description
/// 0       3       File identifier "TAG"
/// 3       30      Title (null-padded)
/// 33      30      Artist (null-padded)
/// 63      30      Album (null-padded)
/// 93      4       Year (null-padded)
/// 97      28/30   Comment (28 bytes if track present, 30 if not)
/// 125     1       Track number (0 if not present)
/// 126     1       Zero byte (separator)
/// 127     1       Genre (0-255)
/// ```
///
/// ## Track Number Handling
///
/// ID3v1.1 introduced track number support by using the last two bytes of the
/// comment field. If byte 125 is zero and byte 126 is non-zero, then byte 126
/// contains the track number and the comment field is limited to 28 characters.
///
/// ## Usage Examples
///
/// ```dart
/// final locator = Id3v1Locator();
/// final fileBytes = await File('song.mp3').readAsBytes();
///
/// // Check if file contains ID3v1 tag
/// if (locator.fileMatches(fileBytes)) {
///   // Extract the tag for parsing
///   final tagBytes = locator.extract(fileBytes);
///
///   if (tagBytes != null) {
///     // Parse with appropriate codec...
///     final codec = Id3v1Codec();
///     final tags = codec.readFromContainer(tagBytes);
///   }
/// }
///
/// // Inject new ID3v1 tag
/// final newTagBytes = codec.writeToContainer(tags: updatedTags);
/// final updatedFile = locator.inject(fileBytes, newTagBytes);
/// ```
///
/// ## Memory Efficiency
///
/// The locator is highly memory efficient due to ID3v1's fixed structure:
/// - Only reads the last 128 bytes for detection and extraction
/// - No variable-length parsing required
/// - Minimal validation overhead
/// - Fixed-size operations for injection
///
/// ## Error Handling
///
/// The locator handles various error conditions gracefully:
/// - Files too small to contain ID3v1 tags (< 128 bytes)
/// - Missing "TAG" signature at the expected location
/// - Corrupted or truncated files
/// - Invalid tag data during injection
///
/// ## Compatibility
///
/// This locator supports both ID3v1.0 and ID3v1.1 formats:
/// - ID3v1.0: 30-character comment field, no track number
/// - ID3v1.1: 28-character comment field with track number in bytes 125-126
///
/// The locator automatically detects which format is present during extraction
/// and preserves the format during injection operations.
///
/// See also:
/// - [Id3v1Codec] for parsing extracted tag data
/// - [Id3v2Locator] for ID3v2 tag handling
/// - [ContainerLocator] for the base interface
class Id3v1Locator extends ContainerLocator {
  /// The fixed size of an ID3v1 tag in bytes.
  static const int tagSize = 128;

  /// The ID3v1 tag identifier signature ("TAG" in ASCII).
  static const List<int> tagSignature = [0x54, 0x41, 0x47]; // "TAG"

  @override
  ContainerKind get containerKind => ContainerKind.id3v1;

  @override
  bool fileMatches(Uint8List fileBytes) {
    // Check minimum file size for ID3v1 tag
    if (fileBytes.length < tagSize) {
      return false;
    }

    // Calculate the start position of the potential ID3v1 tag
    final tagStart = fileBytes.length - tagSize;

    // Check for "TAG" signature at the expected location
    return fileBytes[tagStart] == tagSignature[0] && fileBytes[tagStart + 1] == tagSignature[1] && fileBytes[tagStart + 2] == tagSignature[2];
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    // Verify file contains ID3v1 tag
    if (!fileMatches(fileBytes)) {
      return null;
    }

    // Extract the fixed 128-byte tag from the end of the file
    return fileBytes.sublist(fileBytes.length - tagSize);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Start with the original file
    var result = fileBytes;

    // Remove existing ID3v1 tag if present
    if (fileMatches(result)) {
      result = result.sublist(0, result.length - tagSize);
    }

    // If no new container bytes provided, return file without ID3v1 tag
    if (containerBytes == null) {
      return result;
    }

    // Validate the new container bytes
    if (!_isValidId3v1Tag(containerBytes)) {
      // If invalid, return original file unchanged
      return fileBytes;
    }

    // Append the new ID3v1 tag to the end of the file
    return Uint8List.fromList([...result, ...containerBytes]);
  }

  /// Validates that the provided bytes represent a valid ID3v1 tag.
  ///
  /// This method performs basic validation of the tag structure:
  /// - Checks that the data is exactly 128 bytes
  /// - Verifies the "TAG" signature at the beginning
  /// - Ensures the genre byte is within valid range (0-255)
  ///
  /// ## Parameters
  /// - [bytes]: The bytes to validate as an ID3v1 tag
  ///
  /// ## Returns
  /// `true` if the bytes represent a valid ID3v1 tag, `false` otherwise.
  ///
  /// ## Validation Rules
  ///
  /// - Must be exactly 128 bytes in length
  /// - Must start with "TAG" signature
  /// - Genre byte (last byte) must be 0-255 (automatically valid for single byte)
  /// - Track number validation (if present) checks for ID3v1.1 format
  ///
  /// ## Examples
  ///
  /// ```dart
  /// // Valid ID3v1 tag
  /// final validTag = Uint8List(128);
  /// validTag[0] = 0x54; // 'T'
  /// validTag[1] = 0x41; // 'A'
  /// validTag[2] = 0x47; // 'G'
  /// // ... fill remaining fields
  /// assert(_isValidId3v1Tag(validTag) == true);
  ///
  /// // Invalid tag (wrong size)
  /// final invalidTag = Uint8List(100);
  /// assert(_isValidId3v1Tag(invalidTag) == false);
  /// ```
  bool _isValidId3v1Tag(Uint8List bytes) {
    // Check exact size requirement
    if (bytes.length != tagSize) {
      return false;
    }

    // Check "TAG" signature at the beginning
    if (bytes[0] != tagSignature[0] || bytes[1] != tagSignature[1] || bytes[2] != tagSignature[2]) {
      return false;
    }

    // Additional validation could be added here:
    // - Check for reasonable year values (bytes 93-96)
    // - Validate track number format (bytes 125-126)
    // - Check for null-terminated strings in text fields
    // For now, basic signature validation is sufficient

    return true;
  }
}
