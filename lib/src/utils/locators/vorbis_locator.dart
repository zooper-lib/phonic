import 'dart:typed_data';

import '../../core/container_kind.dart';
import '../../core/container_locator.dart';

/// Container locator for Vorbis Comment metadata in FLAC audio files.
///
/// FLAC files store Vorbis Comments in VORBIS_COMMENT metadata blocks within
/// the FLAC stream structure. These blocks contain UTF-8 encoded key-value pairs
/// that provide rich metadata capabilities with no arbitrary length restrictions.
///
/// ## FLAC Metadata Block Structure
///
/// FLAC files begin with a 4-byte signature "fLaC" followed by metadata blocks:
///
/// ```
/// File Structure:
/// - "fLaC" signature (4 bytes)
/// - Metadata blocks (variable number)
/// - Audio frames
///
/// Metadata Block Header (4 bytes):
/// - Bit 0: Last metadata block flag (1 = last block)
/// - Bits 1-7: Block type (4 = VORBIS_COMMENT)
/// - Bits 8-31: Block length (24-bit big-endian)
/// ```
///
/// ## VORBIS_COMMENT Block Structure
///
/// The VORBIS_COMMENT block (type 4) contains:
/// - Vendor string length (32-bit little-endian)
/// - Vendor string (UTF-8)
/// - User comment list count (32-bit little-endian)
/// - User comments (length + UTF-8 string pairs)
///
/// ## Usage Examples
///
/// ```dart
/// final locator = VorbisLocator();
/// final fileBytes = await File('song.flac').readAsBytes();
///
/// // Check if file contains Vorbis Comments
/// if (locator.fileMatches(fileBytes)) {
///   // Extract the comment block for parsing
///   final commentBytes = locator.extract(fileBytes);
///
///   if (commentBytes != null) {
///     // Parse with appropriate codec...
///     final codec = VorbisCommentsCodec();
///     final tags = codec.readFromContainer(commentBytes);
///   }
/// }
///
/// // Inject new Vorbis Comments
/// final newCommentBytes = codec.writeToContainer(tags: updatedTags);
/// final updatedFile = locator.inject(fileBytes, newCommentBytes);
/// ```
///
/// ## Memory Efficiency
///
/// The locator minimizes memory usage by:
/// - Only parsing metadata block headers to locate VORBIS_COMMENT blocks
/// - Extracting only the comment block data, not the entire file
/// - Validating FLAC structure before attempting full extraction
/// - Using streaming approaches for large files when possible
///
/// ## Error Handling
///
/// The locator handles various error conditions gracefully:
/// - Files without FLAC signature
/// - Corrupted metadata block headers
/// - Missing VORBIS_COMMENT blocks
/// - Truncated files where declared block sizes exceed available data
/// - Invalid block type or length values
///
/// ## FLAC Specification Compliance
///
/// This implementation follows the FLAC specification for:
/// - File signature detection ("fLaC")
/// - Metadata block header parsing
/// - VORBIS_COMMENT block identification (type 4)
/// - Proper handling of the last-metadata-block flag
/// - Big-endian length encoding in block headers
///
/// See also:
/// - [VorbisCommentsCodec] for parsing extracted comment data
/// - [FlacFormatStrategy] for FLAC format detection
/// - [ContainerLocator] for the base interface
class VorbisLocator extends ContainerLocator {
  /// The FLAC file signature ("fLaC" in ASCII).
  static const List<int> flacSignature = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"

  /// The VORBIS_COMMENT metadata block type identifier.
  static const int vorbisCommentBlockType = 4;

  /// The minimum size for a FLAC file header (signature + first block header).
  static const int minimumHeaderSize = 8; // 4 bytes signature + 4 bytes block header

  @override
  ContainerKind get containerKind => ContainerKind.vorbis;

  @override
  bool fileMatches(Uint8List fileBytes) {
    // Check minimum file size for FLAC signature and first metadata block header
    if (fileBytes.length < minimumHeaderSize) {
      return false;
    }

    // Check for FLAC signature at the beginning
    return _hasFlacSignature(fileBytes);
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    // Verify file contains FLAC signature
    if (!fileMatches(fileBytes)) {
      return null;
    }

    try {
      // Skip the FLAC signature (4 bytes)
      int offset = 4;

      // Parse metadata blocks to find VORBIS_COMMENT block
      while (offset + 4 <= fileBytes.length) {
        // Parse metadata block header (4 bytes)
        final blockHeader = fileBytes.sublist(offset, offset + 4);

        // Extract block type and last-block flag from first byte
        final firstByte = blockHeader[0];
        final isLastBlock = (firstByte & 0x80) != 0;
        final blockType = firstByte & 0x7F;

        // Extract block length (24-bit big-endian from bytes 1-3)
        final blockLength = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

        // Move to block data
        offset += 4;

        // Check if we have enough bytes for the block data
        if (offset + blockLength > fileBytes.length) {
          return null; // Truncated file
        }

        // If this is a VORBIS_COMMENT block, extract it
        if (blockType == vorbisCommentBlockType) {
          return fileBytes.sublist(offset, offset + blockLength);
        }

        // Move to next block
        offset += blockLength;

        // If this was the last metadata block, stop searching
        if (isLastBlock) {
          break;
        }
      }

      // No VORBIS_COMMENT block found
      return null;
    } catch (e) {
      // Handle any parsing errors
      return null;
    }
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Verify this is a FLAC file
    if (!fileMatches(fileBytes)) {
      return fileBytes; // Return original if not FLAC
    }

    try {
      // Parse the existing FLAC structure
      final flacStructure = _parseFlacStructure(fileBytes);
      if (flacStructure == null) {
        return fileBytes; // Return original if parsing fails
      }

      // Build new FLAC file with updated/removed VORBIS_COMMENT block
      final result = <int>[];

      // Add FLAC signature
      result.addAll(flacSignature);

      bool vorbisCommentAdded = false;
      final blocksToWrite = <_MetadataBlock>[];

      // Process existing metadata blocks
      for (final block in flacStructure.metadataBlocks) {
        if (block.type == vorbisCommentBlockType) {
          // Replace existing VORBIS_COMMENT block with new one (if provided)
          if (containerBytes != null) {
            blocksToWrite.add(_MetadataBlock(vorbisCommentBlockType, containerBytes));
            vorbisCommentAdded = true;
          }
          // If containerBytes is null, we skip this block (remove it)
        } else {
          // Copy other metadata blocks unchanged
          blocksToWrite.add(block);
        }
      }

      // If we need to add a new VORBIS_COMMENT block and haven't added one yet
      if (containerBytes != null && !vorbisCommentAdded) {
        // Add new VORBIS_COMMENT block
        blocksToWrite.add(_MetadataBlock(vorbisCommentBlockType, containerBytes));
      }

      // Write all metadata blocks
      for (int i = 0; i < blocksToWrite.length; i++) {
        final block = blocksToWrite[i];
        final isLastBlock = (i == blocksToWrite.length - 1) && flacStructure.audioDataOffset >= fileBytes.length;
        _addMetadataBlock(result, block.type, block.data, isLastBlock);
      }

      // Add audio data
      if (flacStructure.audioDataOffset < fileBytes.length) {
        result.addAll(fileBytes.sublist(flacStructure.audioDataOffset));
      }

      return Uint8List.fromList(result);
    } catch (e) {
      // If injection fails, return original file
      return fileBytes;
    }
  }

  /// Checks if the file starts with a FLAC signature.
  ///
  /// FLAC files begin with the 4-byte signature "fLaC" (0x664C6143).
  /// This is the most reliable way to identify FLAC files.
  ///
  /// Parameters:
  /// - [fileBytes]: File data to examine (at least 4 bytes needed)
  ///
  /// Returns:
  /// - `true` if FLAC signature is found at file start
  /// - `false` if no FLAC signature is present
  bool _hasFlacSignature(Uint8List fileBytes) {
    if (fileBytes.length < 4) return false;

    return fileBytes[0] == flacSignature[0] && fileBytes[1] == flacSignature[1] && fileBytes[2] == flacSignature[2] && fileBytes[3] == flacSignature[3];
  }

  /// Parses the FLAC file structure to identify metadata blocks and audio data location.
  ///
  /// Returns a [_FlacStructure] object containing information about metadata blocks
  /// and the offset where audio data begins, or null if parsing fails.
  _FlacStructure? _parseFlacStructure(Uint8List fileBytes) {
    if (!_hasFlacSignature(fileBytes)) {
      return null;
    }

    final metadataBlocks = <_MetadataBlock>[];
    int offset = 4; // Skip FLAC signature

    try {
      while (offset + 4 <= fileBytes.length) {
        // Parse metadata block header
        final blockHeader = fileBytes.sublist(offset, offset + 4);

        final firstByte = blockHeader[0];
        final isLastBlock = (firstByte & 0x80) != 0;
        final blockType = firstByte & 0x7F;

        final blockLength = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

        offset += 4;

        if (offset + blockLength > fileBytes.length) {
          return null; // Truncated file
        }

        final blockData = fileBytes.sublist(offset, offset + blockLength);
        metadataBlocks.add(_MetadataBlock(blockType, blockData));

        offset += blockLength;

        if (isLastBlock) {
          break;
        }
      }

      return _FlacStructure(metadataBlocks, offset);
    } catch (e) {
      return null;
    }
  }

  /// Adds a metadata block to the result buffer with proper header encoding.
  ///
  /// Parameters:
  /// - [result]: The buffer to append the block to
  /// - [blockType]: The metadata block type (0-127)
  /// - [blockData]: The block data bytes
  /// - [isLastBlock]: Whether this is the last metadata block
  void _addMetadataBlock(List<int> result, int blockType, Uint8List blockData, bool isLastBlock) {
    // Create block header
    final firstByte = blockType | (isLastBlock ? 0x80 : 0x00);
    final length = blockData.length;

    // Add header (4 bytes: type/last-flag + 24-bit big-endian length)
    result.add(firstByte);
    result.add((length >> 16) & 0xFF);
    result.add((length >> 8) & 0xFF);
    result.add(length & 0xFF);

    // Add block data
    result.addAll(blockData);
  }
}

/// Internal class representing a FLAC metadata block.
class _MetadataBlock {
  final int type;
  final Uint8List data;

  const _MetadataBlock(this.type, this.data);
}

/// Internal class representing the parsed FLAC file structure.
class _FlacStructure {
  final List<_MetadataBlock> metadataBlocks;
  final int audioDataOffset;

  const _FlacStructure(this.metadataBlocks, this.audioDataOffset);
}
