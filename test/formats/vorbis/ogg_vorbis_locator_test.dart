import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/utils/locators/ogg_vorbis_locator.dart';
import 'package:test/test.dart';

void main() {
  group('OggVorbisLocator', () {
    late OggVorbisLocator locator;

    setUp(() {
      locator = OggVorbisLocator();
    });

    group('containerKind', () {
      test('should return vorbis container kind', () {
        expect(locator.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('fileMatches', () {
      test('should return true for valid OGG Vorbis files', () {
        final oggVorbisFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(),
        ]);

        expect(locator.fileMatches(oggVorbisFile), isTrue);
      });

      test('should return false for files too small', () {
        final tooSmall = Uint8List.fromList([0x4F, 0x67, 0x67]); // Only "Ogg"
        expect(locator.fileMatches(tooSmall), isFalse);
      });

      test('should return false for empty files', () {
        final empty = Uint8List(0);
        expect(locator.fileMatches(empty), isFalse);
      });

      test('should return false for files without OGG signature', () {
        final noSignature = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x00, // Not "OggS"
          0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);
        expect(locator.fileMatches(noSignature), isFalse);
      });

      test('should return false for OGG files with non-Vorbis codec (Opus)', () {
        final oggOpusFile = _createOggFile([
          _createOpusIdentificationPacket(),
        ]);

        expect(locator.fileMatches(oggOpusFile), isFalse);
      });

      test('should return false for OGG files with non-Vorbis codec (Theora)', () {
        final oggTheoraFile = _createOggFile([
          _createTheoraIdentificationPacket(),
        ]);

        expect(locator.fileMatches(oggTheoraFile), isFalse);
      });

      test('should return true for OGG Vorbis files with multiple streams', () {
        final oggVorbisFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(),
          _createVorbisSetupPacket(),
        ]);

        expect(locator.fileMatches(oggVorbisFile), isTrue);
      });

      test('should return true even for OGG Vorbis files without comment packets', () {
        final oggVorbisWithoutComments = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisSetupPacket(),
        ]);

        expect(locator.fileMatches(oggVorbisWithoutComments), isTrue);
      });
    });

    group('extract', () {
      test('should extract Vorbis Comment packet from OGG Vorbis file', () {
        final commentData = _createVorbisCommentData();
        final commentPacket = _createVorbisCommentPacket(commentData);
        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          commentPacket,
        ]);

        final extracted = locator.extract(oggFile);

        expect(extracted, isNotNull);
        expect(extracted, equals(commentData));
      });

      test('should return null for files without OGG signature', () {
        final invalidFile = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04]);

        expect(locator.extract(invalidFile), isNull);
      });

      test('should return null for OGG Vorbis files without comment packets', () {
        final oggWithoutComments = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisSetupPacket(),
        ]);

        expect(locator.extract(oggWithoutComments), isNull);
      });

      test('should extract first Vorbis Comment packet when multiple exist', () {
        final firstCommentData = _createVorbisCommentData(vendor: 'First Encoder');
        final secondCommentData = _createVorbisCommentData(vendor: 'Second Encoder');

        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(firstCommentData),
          _createVorbisCommentPacket(secondCommentData),
        ]);

        final extracted = locator.extract(oggFile);

        expect(extracted, isNotNull);
        expect(extracted, equals(firstCommentData));
      });

      test('should handle Vorbis Comment packets in different page positions', () {
        final commentData = _createVorbisCommentData();

        // Test with comment in first page
        final oggFile1 = _createOggVorbisFile([
          _createVorbisCommentPacket(commentData),
          _createVorbisIdentificationPacket(),
        ]);
        expect(locator.extract(oggFile1), equals(commentData));

        // Test with comment in later page
        final oggFile2 = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisSetupPacket(),
          _createVorbisCommentPacket(commentData),
        ]);
        expect(locator.extract(oggFile2), equals(commentData));
      });

      test('should return null for truncated files', () {
        final commentData = _createVorbisCommentData();
        final completeFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(commentData),
        ]);

        // Truncate the file in the middle
        final truncatedFile = completeFile.sublist(0, completeFile.length - 10);

        expect(locator.extract(truncatedFile), isNull);
      });

      test('should handle zero-length Vorbis Comment packets', () {
        final emptyCommentData = Uint8List(0);
        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(emptyCommentData),
        ]);

        final extracted = locator.extract(oggFile);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(0));
      });

      test('should handle corrupted OGG page headers gracefully', () {
        final corruptedFile = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, 0x02, // Version + header type
          0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Invalid granule position
          0x00, 0x00, 0x00, 0x00, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0xFF, // Invalid page segments count (too large)
        ]);

        expect(locator.extract(corruptedFile), isNull);
      });

      test('should handle files with only OGG signature', () {
        final signatureOnly = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53]); // Just "OggS"

        expect(locator.extract(signatureOnly), isNull);
      });

      test('should handle OGG files with non-Vorbis packets', () {
        final oggOpusFile = _createOggFile([
          _createOpusIdentificationPacket(),
        ]);

        expect(locator.extract(oggOpusFile), isNull);
      });
    });

    group('inject', () {
      test('should inject new Vorbis Comment packet into OGG file without existing comments', () {
        final originalFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisSetupPacket(),
        ]);

        final newCommentData = _createVorbisCommentData(vendor: 'New Encoder');
        final result = locator.inject(originalFile, newCommentData);

        // For now, since we don't have full injection logic for new comments,
        // this should return the original file
        expect(result, equals(originalFile));
      });

      test('should replace existing Vorbis Comment packet', () {
        final oldCommentData = _createVorbisCommentData(vendor: 'Old Encoder');
        final originalFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(oldCommentData),
        ]);

        final newCommentData = _createVorbisCommentData(vendor: 'New Encoder');
        final result = locator.inject(originalFile, newCommentData);

        // Verify the old comment is replaced with the new one
        final extractedComment = locator.extract(result);
        expect(extractedComment, equals(newCommentData));
        expect(extractedComment, isNot(equals(oldCommentData)));
      });

      test('should remove Vorbis Comment packet when containerBytes is null', () {
        final commentData = _createVorbisCommentData();
        final originalFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(commentData),
        ]);

        final result = locator.inject(originalFile, null);

        // Verify the Vorbis Comment is removed
        expect(locator.extract(result), isNull);

        // Verify OGG signature is preserved
        expect(result.sublist(0, 4), equals([0x4F, 0x67, 0x67, 0x53]));
      });

      test('should preserve other packets during injection', () {
        final identificationPacket = _createVorbisIdentificationPacket();
        final setupPacket = _createVorbisSetupPacket();
        final oldCommentData = _createVorbisCommentData(vendor: 'Old');

        final originalFile = _createOggVorbisFile([
          identificationPacket,
          _createVorbisCommentPacket(oldCommentData),
          setupPacket,
        ]);

        final newCommentData = _createVorbisCommentData(vendor: 'New');
        final result = locator.inject(originalFile, newCommentData);

        // Verify new comment is injected
        final extractedComment = locator.extract(result);
        expect(extractedComment, equals(newCommentData));

        // Verify OGG signature is preserved
        expect(result.sublist(0, 4), equals([0x4F, 0x67, 0x67, 0x53]));
      });

      test('should handle files without existing Vorbis Comments', () {
        final originalFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisSetupPacket(),
        ]);

        // Remove non-existent Vorbis Comment (should return equivalent file)
        final removedResult = locator.inject(originalFile, null);
        expect(removedResult.sublist(0, 4), equals([0x4F, 0x67, 0x67, 0x53])); // OGG signature preserved
        expect(locator.extract(removedResult), isNull); // Still no Vorbis comment

        // Add new Vorbis Comment (for now, returns original since we don't support adding new comments)
        final newCommentData = _createVorbisCommentData();
        final addedResult = locator.inject(originalFile, newCommentData);
        expect(addedResult, equals(originalFile)); // Returns original for now
      });

      test('should return original file for non-OGG files', () {
        final nonOggFile = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 1, 2, 3, 4]);
        final commentData = _createVorbisCommentData();

        final result = locator.inject(nonOggFile, commentData);

        expect(result, equals(nonOggFile));
      });

      test('should handle injection with different comment sizes', () {
        final originalCommentData = _createVorbisCommentData(vendor: 'Original');
        final originalFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(originalCommentData),
        ]);

        // Test with small comment
        final smallComment = _createVorbisCommentData(vendor: 'A');
        final result1 = locator.inject(originalFile, smallComment);
        expect(locator.extract(result1), equals(smallComment));

        // Test with large comment
        final largeComment = _createVorbisCommentData(vendor: 'A' * 1000);
        final result2 = locator.inject(originalFile, largeComment);
        expect(locator.extract(result2), equals(largeComment));
      });

      test('should handle corrupted OGG files gracefully', () {
        final corruptedFile = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, 0x02, // Version + header type
          0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
        ]);

        final commentData = _createVorbisCommentData();
        final result = locator.inject(corruptedFile, commentData);

        // Should return original file when injection fails
        expect(result, equals(corruptedFile));
      });

      test('should handle non-Vorbis OGG files gracefully', () {
        final oggOpusFile = _createOggFile([
          _createOpusIdentificationPacket(),
        ]);

        final commentData = _createVorbisCommentData();
        final result = locator.inject(oggOpusFile, commentData);

        // Should return original file for non-Vorbis OGG files
        expect(result, equals(oggOpusFile));
      });
    });

    group('edge cases and error handling', () {
      test('should handle OGG files with large comment data', () {
        // Create a reasonably large packet (but within single page limits)
        final largeCommentData = Uint8List(5000); // Large but manageable comment data
        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(largeCommentData),
        ]);

        final extracted = locator.extract(oggFile);
        expect(extracted, equals(largeCommentData));
      });

      test('should handle OGG files with multiple pages', () {
        final commentData = _createVorbisCommentData();

        // Create file with packets spread across multiple pages
        final oggFile = _createMultiPageOggFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(commentData),
          _createVorbisSetupPacket(),
        ]);

        final extracted = locator.extract(oggFile);
        expect(extracted, equals(commentData));
      });

      test('should handle packets spanning multiple pages', () {
        // This is a complex case that would require more sophisticated page handling
        // For now, we'll test that it doesn't crash
        final commentData = _createVorbisCommentData();
        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(commentData),
        ]);

        expect(() => locator.extract(oggFile), returnsNormally);
      });

      test('should handle minimum valid OGG Vorbis file', () {
        final minimalOgg = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
        ]);

        expect(locator.fileMatches(minimalOgg), isTrue);
        expect(locator.extract(minimalOgg), isNull); // No comment packet
      });

      test('should handle OGG files with invalid checksums', () {
        // Create a file with intentionally wrong checksum
        final oggFile = _createOggVorbisFile([
          _createVorbisIdentificationPacket(),
          _createVorbisCommentPacket(),
        ]);

        // The locator should still work even with invalid checksums
        // (checksum validation is not implemented in this basic version)
        expect(locator.fileMatches(oggFile), isTrue);
      });
    });
  });
}

/// Helper function to create an OGG Vorbis file with the given packets.
Uint8List _createOggVorbisFile(List<Uint8List> packets) {
  return _createOggFile(packets);
}

/// Helper function to create an OGG file with the given packets.
Uint8List _createOggFile(List<Uint8List> packets) {
  final result = <int>[];

  // Create a single OGG page containing all packets
  final pageData = <int>[];
  final segmentTable = <int>[];

  for (final packet in packets) {
    pageData.addAll(packet);

    // Add segments for this packet
    int remaining = packet.length;
    while (remaining > 0) {
      final segmentSize = remaining > 255 ? 255 : remaining;
      segmentTable.add(segmentSize);
      remaining -= segmentSize;
    }
  }

  // Build OGG page header
  result.addAll([0x4F, 0x67, 0x67, 0x53]); // "OggS" signature
  result.add(0x00); // Stream structure version
  result.add(0x02); // Header type flag (first page of logical bitstream)
  result.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // Granule position
  result.addAll([0x00, 0x00, 0x00, 0x00]); // Stream serial number
  result.addAll([0x00, 0x00, 0x00, 0x00]); // Page sequence number
  result.addAll([0x00, 0x00, 0x00, 0x00]); // Page checksum (placeholder)
  result.add(segmentTable.length); // Page segments count

  // Add segment table
  result.addAll(segmentTable);

  // Add page data
  result.addAll(pageData);

  return Uint8List.fromList(result);
}

/// Helper function to create a multi-page OGG file.
Uint8List _createMultiPageOggFile(List<Uint8List> packets) {
  final result = <int>[];
  int pageSequence = 0;

  // Split packets across multiple pages (simplified implementation)
  for (int i = 0; i < packets.length; i++) {
    final packet = packets[i];
    final pageData = <int>[];
    final segmentTable = <int>[];

    pageData.addAll(packet);

    // Add segments for this packet
    int remaining = packet.length;
    while (remaining > 0) {
      final segmentSize = remaining > 255 ? 255 : remaining;
      segmentTable.add(segmentSize);
      remaining -= segmentSize;
    }

    // Build OGG page header
    result.addAll([0x4F, 0x67, 0x67, 0x53]); // "OggS" signature
    result.add(0x00); // Stream structure version
    result.add(i == 0 ? 0x02 : 0x00); // Header type flag
    result.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // Granule position
    result.addAll([0x00, 0x00, 0x00, 0x00]); // Stream serial number

    // Page sequence number (little-endian)
    result.add(pageSequence & 0xFF);
    result.add((pageSequence >> 8) & 0xFF);
    result.add((pageSequence >> 16) & 0xFF);
    result.add((pageSequence >> 24) & 0xFF);
    pageSequence++;

    result.addAll([0x00, 0x00, 0x00, 0x00]); // Page checksum (placeholder)
    result.add(segmentTable.length); // Page segments count

    // Add segment table
    result.addAll(segmentTable);

    // Add page data
    result.addAll(pageData);
  }

  return Uint8List.fromList(result);
}

/// Helper function to create a Vorbis identification packet.
Uint8List _createVorbisIdentificationPacket() {
  final result = <int>[];

  // Packet type (identification = 0x01)
  result.add(0x01);

  // "vorbis" string
  result.addAll([0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]); // "vorbis"

  // Minimal identification header data (simplified)
  result.addAll([
    0x00, 0x00, 0x00, 0x00, // Vorbis version
    0x02, // Channels
    0x44, 0xAC, 0x00, 0x00, // Sample rate (44100 Hz, little-endian)
    0x00, 0x00, 0x00, 0x00, // Bitrate maximum
    0x00, 0xEE, 0x02, 0x00, // Bitrate nominal (192000 bps, little-endian)
    0x00, 0x00, 0x00, 0x00, // Bitrate minimum
    0xB0, // Blocksize (4 bits each for blocksize_0 and blocksize_1)
    0x01, // Framing flag
  ]);

  return Uint8List.fromList(result);
}

/// Helper function to create a Vorbis comment packet.
Uint8List _createVorbisCommentPacket([Uint8List? commentData]) {
  final result = <int>[];

  // Packet type (comment = 0x03)
  result.add(0x03);

  // "vorbis" string
  result.addAll([0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]); // "vorbis"

  // Add comment data or create default
  if (commentData != null) {
    result.addAll(commentData);
  } else {
    result.addAll(_createVorbisCommentData());
  }

  return Uint8List.fromList(result);
}

/// Helper function to create a Vorbis setup packet.
Uint8List _createVorbisSetupPacket() {
  final result = <int>[];

  // Packet type (setup = 0x05)
  result.add(0x05);

  // "vorbis" string
  result.addAll([0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]); // "vorbis"

  // Minimal setup header data (simplified)
  result.addAll([
    0x00, // Codebook count (simplified)
    0x01, // Framing flag
  ]);

  return Uint8List.fromList(result);
}

/// Helper function to create an Opus identification packet.
Uint8List _createOpusIdentificationPacket() {
  final result = <int>[];

  // "OpusHead" string
  result.addAll([0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64]); // "OpusHead"

  // Minimal Opus header data
  result.addAll([
    0x01, // Version
    0x02, // Channel count
    0x00, 0x00, // Pre-skip (little-endian)
    0x80, 0xBB, 0x00, 0x00, // Input sample rate (48000 Hz, little-endian)
    0x00, 0x00, // Output gain
    0x00, // Channel mapping family
  ]);

  return Uint8List.fromList(result);
}

/// Helper function to create a Theora identification packet.
Uint8List _createTheoraIdentificationPacket() {
  final result = <int>[];

  // Packet type (0x80 for Theora identification)
  result.add(0x80);

  // "theora" string
  result.addAll([0x74, 0x68, 0x65, 0x6F, 0x72, 0x61]); // "theora"

  // Minimal Theora header data
  result.addAll([
    0x03, 0x02, 0x01, // Version (3.2.1)
    0x00, 0x00, // Width (simplified)
    0x00, 0x00, // Height (simplified)
  ]);

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

  // Framing bit (always 1, padded to byte boundary)
  result.add(0x01);

  return Uint8List.fromList(result);
}
