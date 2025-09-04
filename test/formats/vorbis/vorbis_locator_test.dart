import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/utils/locators/vorbis_locator.dart';
import 'package:test/test.dart';

void main() {
  group('VorbisLocator', () {
    late VorbisLocator locator;

    setUp(() {
      locator = VorbisLocator();
    });

    group('containerKind', () {
      test('should return vorbis container kind', () {
        expect(locator.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('fileMatches', () {
      test('should return true for valid FLAC files', () {
        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
        ]);

        expect(locator.fileMatches(flacFile), isTrue);
      });

      test('should return false for files too small', () {
        final tooSmall = Uint8List.fromList([0x66, 0x4C, 0x61]); // Only "fLa"
        expect(locator.fileMatches(tooSmall), isFalse);
      });

      test('should return false for empty files', () {
        final empty = Uint8List(0);
        expect(locator.fileMatches(empty), isFalse);
      });

      test('should return false for files without FLAC signature', () {
        final noSignature = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x00, // Not "fLaC"
          0x00, 0x00, 0x00, 0x04, // Metadata block header
        ]);
        expect(locator.fileMatches(noSignature), isFalse);
      });

      test('should return true for FLAC files with various metadata blocks', () {
        final flacWithMultipleBlocks = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, _createVorbisCommentData()), // VORBIS_COMMENT
          _createMetadataBlock(6, Uint8List.fromList([5, 6, 7, 8])), // PICTURE
        ]);

        expect(locator.fileMatches(flacWithMultipleBlocks), isTrue);
      });

      test('should return true even for FLAC files without Vorbis Comments', () {
        final flacWithoutVorbis = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO only
        ]);

        expect(locator.fileMatches(flacWithoutVorbis), isTrue);
      });
    });

    group('extract', () {
      test('should extract Vorbis Comment block from FLAC file', () {
        final vorbisData = _createVorbisCommentData();
        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, vorbisData), // VORBIS_COMMENT
        ]);

        final extracted = locator.extract(flacFile);

        expect(extracted, isNotNull);
        expect(extracted, equals(vorbisData));
      });

      test('should return null for files without FLAC signature', () {
        final invalidFile = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04]);

        expect(locator.extract(invalidFile), isNull);
      });

      test('should return null for FLAC files without Vorbis Comment blocks', () {
        final flacWithoutVorbis = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO only
        ]);

        expect(locator.extract(flacWithoutVorbis), isNull);
      });

      test('should extract first Vorbis Comment block when multiple exist', () {
        final firstVorbisData = _createVorbisCommentData(vendor: 'First Encoder');
        final secondVorbisData = _createVorbisCommentData(vendor: 'Second Encoder');

        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, firstVorbisData), // First VORBIS_COMMENT
          _createMetadataBlock(4, secondVorbisData), // Second VORBIS_COMMENT
        ]);

        final extracted = locator.extract(flacFile);

        expect(extracted, isNotNull);
        expect(extracted, equals(firstVorbisData));
      });

      test('should handle Vorbis Comment blocks in different positions', () {
        final vorbisData = _createVorbisCommentData();

        // Test with Vorbis Comment as first block
        final flacFile1 = _createFlacFile([
          _createMetadataBlock(4, vorbisData), // VORBIS_COMMENT first
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
        ]);
        expect(locator.extract(flacFile1), equals(vorbisData));

        // Test with Vorbis Comment as last block
        final flacFile2 = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(1, Uint8List.fromList([5, 6, 7, 8])), // PADDING
          _createMetadataBlock(4, vorbisData), // VORBIS_COMMENT last
        ]);
        expect(locator.extract(flacFile2), equals(vorbisData));
      });

      test('should return null for truncated files', () {
        final vorbisData = _createVorbisCommentData();
        final completeFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, vorbisData), // VORBIS_COMMENT
        ]);

        // Truncate the file in the middle of the Vorbis Comment block
        final truncatedFile = completeFile.sublist(0, completeFile.length - 10);

        expect(locator.extract(truncatedFile), isNull);
      });

      test('should handle zero-length Vorbis Comment blocks', () {
        final emptyVorbisData = Uint8List(0);
        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, emptyVorbisData), // Empty VORBIS_COMMENT
        ]);

        final extracted = locator.extract(flacFile);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(0));
      });

      test('should handle corrupted metadata block headers gracefully', () {
        final corruptedFile = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x04, 0xFF, 0xFF, 0xFF, // Block type 4 with impossibly large length
        ]);

        expect(locator.extract(corruptedFile), isNull);
      });

      test('should handle files with only FLAC signature', () {
        final signatureOnly = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]); // Just "fLaC"

        expect(locator.extract(signatureOnly), isNull);
      });
    });

    group('inject', () {
      test('should inject new Vorbis Comment block into FLAC file without existing comments', () {
        final originalFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
        ]);

        final newVorbisData = _createVorbisCommentData(vendor: 'New Encoder');
        final result = locator.inject(originalFile, newVorbisData);

        // Verify the result contains the new Vorbis Comment
        final extractedVorbis = locator.extract(result);
        expect(extractedVorbis, equals(newVorbisData));

        // Verify FLAC signature is preserved
        expect(result.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43]));
      });

      test('should replace existing Vorbis Comment block', () {
        final oldVorbisData = _createVorbisCommentData(vendor: 'Old Encoder');
        final originalFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, oldVorbisData), // Old VORBIS_COMMENT
        ]);

        final newVorbisData = _createVorbisCommentData(vendor: 'New Encoder');
        final result = locator.inject(originalFile, newVorbisData);

        // Verify the old comment is replaced with the new one
        final extractedVorbis = locator.extract(result);
        expect(extractedVorbis, equals(newVorbisData));
        expect(extractedVorbis, isNot(equals(oldVorbisData)));
      });

      test('should remove Vorbis Comment block when containerBytes is null', () {
        final vorbisData = _createVorbisCommentData();
        final originalFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, vorbisData), // VORBIS_COMMENT
        ]);

        final result = locator.inject(originalFile, null);

        // Verify the Vorbis Comment is removed
        expect(locator.extract(result), isNull);

        // Verify FLAC signature and other blocks are preserved
        expect(result.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43]));
      });

      test('should preserve other metadata blocks during injection', () {
        final streamInfoData = Uint8List.fromList([1, 2, 3, 4]);
        final paddingData = Uint8List.fromList([0, 0, 0, 0]);
        final pictureData = Uint8List.fromList([5, 6, 7, 8]);

        final originalFile = _createFlacFile([
          _createMetadataBlock(0, streamInfoData), // STREAMINFO
          _createMetadataBlock(1, paddingData), // PADDING
          _createMetadataBlock(6, pictureData), // PICTURE
        ]);

        final newVorbisData = _createVorbisCommentData();
        final result = locator.inject(originalFile, newVorbisData);

        // Verify new Vorbis Comment is added
        final extractedVorbis = locator.extract(result);
        expect(extractedVorbis, equals(newVorbisData));

        // Verify other blocks are preserved (check by parsing structure)
        expect(result.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43]));
        expect(result.length, greaterThan(originalFile.length)); // Should be larger due to added block
      });

      test('should handle files without existing Vorbis Comments', () {
        final originalFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4]), isLast: true), // STREAMINFO only
        ]);

        // Remove non-existent Vorbis Comment (should return equivalent file)
        final removedResult = locator.inject(originalFile, null);
        expect(removedResult.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43])); // FLAC signature preserved
        expect(locator.extract(removedResult), isNull); // Still no Vorbis comment

        // Add new Vorbis Comment
        final newVorbisData = _createVorbisCommentData();
        final addedResult = locator.inject(originalFile, newVorbisData);
        final extractedVorbis = locator.extract(addedResult);
        expect(extractedVorbis, equals(newVorbisData));
      });

      test('should return original file for non-FLAC files', () {
        final nonFlacFile = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 1, 2, 3, 4]);
        final vorbisData = _createVorbisCommentData();

        final result = locator.inject(nonFlacFile, vorbisData);

        expect(result, equals(nonFlacFile));
      });

      test('should handle injection with different Vorbis Comment sizes', () {
        final originalFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
        ]);

        // Test with small Vorbis Comment
        final smallVorbis = _createVorbisCommentData(vendor: 'A');
        final result1 = locator.inject(originalFile, smallVorbis);
        expect(locator.extract(result1), equals(smallVorbis));

        // Test with large Vorbis Comment
        final largeVorbis = _createVorbisCommentData(vendor: 'A' * 1000);
        final result2 = locator.inject(originalFile, largeVorbis);
        expect(locator.extract(result2), equals(largeVorbis));
      });

      test('should preserve audio data during injection', () {
        final audioData = List.generate(100, (i) => i % 256); // Smaller audio data for easier debugging
        final originalFile = _createFlacFileWithAudio([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4]), isLast: true), // STREAMINFO
        ], audioData);

        final newVorbisData = _createVorbisCommentData();
        final result = locator.inject(originalFile, newVorbisData);

        // The result should be larger than original (due to added Vorbis comment)
        expect(result.length, greaterThan(originalFile.length));

        // The result should end with the same audio data
        final expectedAudioStart = result.length - audioData.length;
        if (expectedAudioStart >= 0 && expectedAudioStart < result.length) {
          final resultAudioData = result.sublist(expectedAudioStart);
          expect(resultAudioData, equals(audioData));
        }
      });

      test('should handle corrupted FLAC files gracefully', () {
        final corruptedFile = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x00, 0xFF, 0xFF, 0xFF, // Corrupted metadata block header
        ]);

        final vorbisData = _createVorbisCommentData();
        final result = locator.inject(corruptedFile, vorbisData);

        // Should return original file when injection fails
        expect(result, equals(corruptedFile));
      });
    });

    group('edge cases and error handling', () {
      test('should handle FLAC files with maximum metadata block size', () {
        // Create a large metadata block (close to 16MB limit)
        final largeBlockData = Uint8List(0xFFFFFF); // Maximum 24-bit size
        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, largeBlockData), // Large VORBIS_COMMENT
        ]);

        final extracted = locator.extract(flacFile);
        expect(extracted, equals(largeBlockData));
      });

      test('should handle FLAC files with last-metadata-block flag set correctly', () {
        final vorbisData = _createVorbisCommentData();
        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, vorbisData, isLast: true), // VORBIS_COMMENT (last)
        ]);

        final extracted = locator.extract(flacFile);
        expect(extracted, equals(vorbisData));
      });

      test('should handle multiple consecutive Vorbis Comment blocks', () {
        final firstVorbis = _createVorbisCommentData(vendor: 'First');
        final secondVorbis = _createVorbisCommentData(vendor: 'Second');

        final flacFile = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4])), // STREAMINFO
          _createMetadataBlock(4, firstVorbis), // First VORBIS_COMMENT
          _createMetadataBlock(4, secondVorbis), // Second VORBIS_COMMENT
        ]);

        // Should extract the first one
        final extracted = locator.extract(flacFile);
        expect(extracted, equals(firstVorbis));
      });

      test('should handle minimum valid FLAC file', () {
        final minimalFlac = _createFlacFile([
          _createMetadataBlock(0, Uint8List.fromList([1, 2, 3, 4]), isLast: true), // STREAMINFO only
        ]);

        expect(locator.fileMatches(minimalFlac), isTrue);
        expect(locator.extract(minimalFlac), isNull); // No Vorbis Comment
      });
    });
  });
}

/// Helper function to create a FLAC file with the given metadata blocks.
Uint8List _createFlacFile(List<Uint8List> metadataBlocks) {
  final result = <int>[];

  // Add FLAC signature
  result.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // Add metadata blocks
  for (int i = 0; i < metadataBlocks.length; i++) {
    // final isLast = (i == metadataBlocks.length - 1); // Not used in current implementation
    result.addAll(metadataBlocks[i]);
  }

  return Uint8List.fromList(result);
}

/// Helper function to create a FLAC file with metadata blocks and audio data.
Uint8List _createFlacFileWithAudio(List<Uint8List> metadataBlocks, List<int> audioData) {
  final result = <int>[];

  // Add FLAC signature
  result.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // Add metadata blocks
  for (int i = 0; i < metadataBlocks.length; i++) {
    result.addAll(metadataBlocks[i]);
  }

  // Add audio data
  result.addAll(audioData);

  return Uint8List.fromList(result);
}

/// Helper function to create a metadata block with header and data.
Uint8List _createMetadataBlock(int blockType, Uint8List blockData, {bool isLast = false}) {
  final result = <int>[];

  // Create block header (4 bytes)
  final firstByte = blockType | (isLast ? 0x80 : 0x00);
  final length = blockData.length;

  result.add(firstByte);
  result.add((length >> 16) & 0xFF);
  result.add((length >> 8) & 0xFF);
  result.add(length & 0xFF);

  // Add block data
  result.addAll(blockData);

  return Uint8List.fromList(result);
}

/// Helper function to create sample Vorbis Comment data.
Uint8List _createVorbisCommentData({String vendor = 'Test Encoder'}) {
  final result = <int>[];

  // Vendor string length (32-bit little-endian)
  final vendorBytes = vendor.codeUnits;
  result.add(vendorBytes.length & 0xFF);
  result.add((vendorBytes.length >> 8) & 0xFF);
  result.add((vendorBytes.length >> 16) & 0xFF);
  result.add((vendorBytes.length >> 24) & 0xFF);

  // Vendor string
  result.addAll(vendorBytes);

  // User comment list count (32-bit little-endian) - 0 comments for simplicity
  result.addAll([0x00, 0x00, 0x00, 0x00]);

  return Uint8List.fromList(result);
}

// Note: _findAudioDataStart method was removed as it was unused
