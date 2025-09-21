import 'dart:typed_data';

import '../../core/container_kind.dart';
import '../../core/container_locator.dart';
import '../synchsafe_int.dart';

/// Container locator for ID3v2 metadata tags in audio files.
///
/// ID3v2 tags are typically located at the beginning of audio files (especially MP3)
/// and consist of a 10-byte header followed by variable-length frame data.
/// The header contains a signature, version information, flags, and the total size
/// of the tag data.
///
/// ## ID3v2 Header Structure
///
/// ```
/// Offset  Length  Description
/// 0       3       File identifier "ID3"
/// 3       2       Version (major.minor, e.g., 0x04 0x00 for v2.4)
/// 5       1       Flags (unsynchronization, extended header, etc.)
/// 6       4       Size (synchsafe integer, excludes header)
/// ```
///
/// ## Supported Versions
///
/// This locator supports ID3v2.2, ID3v2.3, and ID3v2.4 tags. Version detection
/// is performed during extraction to ensure proper handling of version-specific
/// features like synchsafe integers and extended headers.
///
/// ## Usage Examples
///
/// ```dart
/// final locator = Id3v2Locator();
/// final fileBytes = await File('song.mp3').readAsBytes();
///
/// // Check if file contains ID3v2 tag
/// if (locator.fileMatches(fileBytes)) {
///   // Extract the tag for parsing
///   final tagBytes = locator.extract(fileBytes);
///
///   if (tagBytes != null) {
///     // Parse with appropriate codec...
///     final codec = Id3v24Codec();
///     final tags = codec.readFromContainer(tagBytes);
///   }
/// }
///
/// // Inject new ID3v2 tag
/// final newTagBytes = codec.writeToContainer(tags: updatedTags);
/// final updatedFile = locator.inject(fileBytes, newTagBytes);
/// ```
///
/// ## Memory Efficiency
///
/// The locator minimizes memory usage by:
/// - Only reading the header bytes needed for detection and size calculation
/// - Extracting only the tag portion of the file, not the entire audio data
/// - Validating header structure before attempting full extraction
///
/// ## Error Handling
///
/// The locator handles various error conditions gracefully:
/// - Files too small to contain valid ID3v2 headers
/// - Corrupted headers with invalid signatures or sizes
/// - Truncated files where the declared tag size exceeds available data
/// - Invalid synchsafe integers in size fields
///
/// See also:
/// - [Id3v24Codec], [Id3v23Codec], [Id3v22Codec] for parsing extracted tag data
/// - [SynchsafeInt] for handling ID3v2 size encoding
/// - [ContainerLocator] for the base interface
class Id3v2Locator extends ContainerLocator {
  /// The minimum size required for a valid ID3v2 header (10 bytes).
  static const int headerSize = 10;

  /// The ID3v2 file identifier signature ("ID3" in ASCII).
  static const List<int> id3Signature = [0x49, 0x44, 0x33]; // "ID3"

  @override
  ContainerKind get containerKind => ContainerKind.id3v2;

  @override
  bool fileMatches(Uint8List fileBytes) {
    // Check minimum file size for ID3v2 header
    if (fileBytes.length < headerSize) {
      return false;
    }

    // Check for "ID3" signature at the beginning
    return fileBytes[0] == id3Signature[0] && fileBytes[1] == id3Signature[1] && fileBytes[2] == id3Signature[2];
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    // Verify file contains ID3v2 tag
    if (!fileMatches(fileBytes)) {
      return null;
    }

    try {
      // Parse the header to get tag size
      final header = fileBytes.sublist(0, headerSize);

      // Extract version information (bytes 3-4)
      final majorVersion = header[3];
      // final minorVersion = header[4]; // Not used in current implementation

      // Validate version (support v2.2, v2.3, v2.4)
      if (majorVersion < 2 || majorVersion > 4) {
        return null; // Unsupported version
      }

      // Extract flags (byte 5)
      // final flags = header[5]; // Not used in current implementation

      // Extract size (bytes 6-9) - synchsafe integer
      final sizeBytes = header.sublist(6, 10);

      // Validate synchsafe format
      if (!SynchsafeInt.isValidBytes(sizeBytes)) {
        return null; // Invalid synchsafe integer
      }

      final tagSize = SynchsafeInt.decodeBytes(sizeBytes);

      // Calculate total tag length (header + tag data)
      final totalTagLength = headerSize + tagSize;

      // Check if file has enough bytes for the complete tag
      if (fileBytes.length < totalTagLength) {
        return null; // Truncated file
      }

      // Extract the complete ID3v2 tag (header + data)
      return fileBytes.sublist(0, totalTagLength);
    } catch (e) {
      // Handle any parsing errors (invalid synchsafe integers, etc.)
      return null;
    }
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Find the start of audio data by removing any existing ID3v2 tag
    int audioDataStart = 0;

    if (fileMatches(fileBytes)) {
      // Extract existing tag to determine where audio data starts
      final existingTag = extract(fileBytes);
      if (existingTag != null) {
        audioDataStart = existingTag.length;
      }
    }

    // Get the audio data (everything after the ID3v2 tag)
    final audioData = fileBytes.sublist(audioDataStart);

    // If no new container bytes provided, just return audio data (remove tag)
    if (containerBytes == null) {
      return audioData;
    }

    // Validate the new container bytes have a valid ID3v2 header
    if (containerBytes.length < headerSize || !_hasValidId3v2Header(containerBytes)) {
      // If invalid, just return original file
      return fileBytes;
    }

    // Combine new ID3v2 tag with audio data
    return Uint8List.fromList([...containerBytes, ...audioData]);
  }

  /// Validates that the provided bytes start with a valid ID3v2 header.
  ///
  /// This method performs basic validation of the header structure without
  /// extracting the full tag. It checks:
  /// - Minimum length requirement
  /// - ID3 signature presence
  /// - Valid version numbers
  /// - Valid synchsafe size encoding
  ///
  /// ## Parameters
  /// - [bytes]: The bytes to validate as an ID3v2 header
  ///
  /// ## Returns
  /// `true` if the bytes start with a valid ID3v2 header, `false` otherwise.
  bool _hasValidId3v2Header(Uint8List bytes) {
    if (bytes.length < headerSize) {
      return false;
    }

    // Check ID3 signature
    if (bytes[0] != id3Signature[0] || bytes[1] != id3Signature[1] || bytes[2] != id3Signature[2]) {
      return false;
    }

    // Check version (support v2.2, v2.3, v2.4)
    final majorVersion = bytes[3];
    if (majorVersion < 2 || majorVersion > 4) {
      return false;
    }

    // Check synchsafe size
    final sizeBytes = bytes.sublist(6, 10);
    return SynchsafeInt.isValidBytes(sizeBytes);
  }
}
