import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/utils/locators/id3v1_locator.dart';

void main() {
  group('Id3v1Locator', () {
    late Id3v1Locator locator;

    setUp(() {
      locator = Id3v1Locator();
    });

    group('containerKind', () {
      test('should return id3v1 container kind', () {
        expect(locator.containerKind, equals(ContainerKind.id3v1));
      });
    });

    group('fileMatches', () {
      test('should return true for valid ID3v1 tag at file end', () {
        final audioData = List.filled(1000, 0xFF);
        final id3v1Tag = _createId3v1Tag();
        final fileBytes = Uint8List.fromList([...audioData, ...id3v1Tag]);

        expect(locator.fileMatches(fileBytes), isTrue);
      });

      test('should return false for files too small', () {
        final tooSmall = Uint8List.fromList(List.filled(127, 0)); // Only 127 bytes
        expect(locator.fileMatches(tooSmall), isFalse);
      });

      test('should return false for empty files', () {
        final empty = Uint8List(0);
        expect(locator.fileMatches(empty), isFalse);
      });

      test('should return false for files without TAG signature', () {
        final audioData = List.filled(1000, 0xFF);
        final invalidTag = List.filled(128, 0x00); // No "TAG" signature
        final fileBytes = Uint8List.fromList([...audioData, ...invalidTag]);

        expect(locator.fileMatches(fileBytes), isFalse);
      });

      test('should return false for files with partial TAG signature', () {
        final audioData = List.filled(1000, 0xFF);
        final partialTag = List.filled(128, 0x00);
        partialTag[0] = 0x54; // 'T'
        partialTag[1] = 0x41; // 'A'
        // Missing 'G' at position 2
        final fileBytes = Uint8List.fromList([...audioData, ...partialTag]);

        expect(locator.fileMatches(fileBytes), isFalse);
      });

      test('should return true for minimum valid file size (exactly 128 bytes)', () {
        final id3v1Tag = _createId3v1Tag();
        expect(locator.fileMatches(id3v1Tag), isTrue);
      });

      test('should return true for files with TAG signature in correct position', () {
        final audioData = List.filled(500, 0xAA);
        final id3v1Tag = _createId3v1Tag(
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          year: '2023',
          comment: 'Test Comment',
          track: 5,
          genre: 17, // Rock
        );
        final fileBytes = Uint8List.fromList([...audioData, ...id3v1Tag]);

        expect(locator.fileMatches(fileBytes), isTrue);
      });

      test('should return false for TAG signature in wrong position', () {
        final audioData = List.filled(1000, 0xFF);
        final tagInMiddle = List.filled(128, 0x00);
        tagInMiddle[0] = 0x54; // 'T'
        tagInMiddle[1] = 0x41; // 'A'
        tagInMiddle[2] = 0x47; // 'G'

        // Put TAG signature in middle, not at end
        final fileBytes = Uint8List.fromList([
          ...audioData.sublist(0, 500),
          ...tagInMiddle,
          ...audioData.sublist(500),
        ]);

        expect(locator.fileMatches(fileBytes), isFalse);
      });
    });

    group('extract', () {
      test('should extract complete ID3v1 tag from file end', () {
        final audioData = List.filled(1000, 0xFF);
        final id3v1Tag = _createId3v1Tag(
          title: 'Extract Test',
          artist: 'Test Artist',
          album: 'Test Album',
          year: '2023',
          comment: 'Test Comment',
          track: 10,
          genre: 1, // Classic Rock
        );
        final fileBytes = Uint8List.fromList([...audioData, ...id3v1Tag]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(128));
        expect(extracted, equals(id3v1Tag));

        // Verify TAG signature
        expect(extracted[0], equals(0x54)); // 'T'
        expect(extracted[1], equals(0x41)); // 'A'
        expect(extracted[2], equals(0x47)); // 'G'
      });

      test('should return null for files without ID3v1 signature', () {
        final audioData = List.filled(1000, 0xFF);
        final invalidTag = List.filled(128, 0x00); // No "TAG" signature
        final fileBytes = Uint8List.fromList([...audioData, ...invalidTag]);

        expect(locator.extract(fileBytes), isNull);
      });

      test('should return null for files too small', () {
        final tooSmall = Uint8List.fromList(List.filled(100, 0x42));
        expect(locator.extract(tooSmall), isNull);
      });

      test('should extract from minimum valid file (exactly 128 bytes)', () {
        final id3v1Tag = _createId3v1Tag();

        final extracted = locator.extract(id3v1Tag);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(128));
        expect(extracted, equals(id3v1Tag));
      });

      test('should extract ID3v1.0 format (no track number)', () {
        final audioData = List.filled(500, 0xCC);
        final id3v1Tag = _createId3v1Tag(
          title: 'No Track Song',
          artist: 'Artist Name',
          album: 'Album Name',
          year: '1999',
          comment: 'Full thirty character comment!', // 30 chars, no track
          track: null, // ID3v1.0 format
          genre: 12,
        );
        final fileBytes = Uint8List.fromList([...audioData, ...id3v1Tag]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(128));
        expect(extracted[125], isNot(equals(0))); // Comment continues (not zero separator)
        expect(extracted[126], isNot(equals(0))); // Comment continues
      });

      test('should extract ID3v1.1 format (with track number)', () {
        final audioData = List.filled(500, 0xDD);
        final id3v1Tag = _createId3v1Tag(
          title: 'Track Song',
          artist: 'Artist Name',
          album: 'Album Name',
          year: '2000',
          comment: 'Short comment', // Less than 28 chars
          track: 7, // ID3v1.1 format
          genre: 5,
        );
        final fileBytes = Uint8List.fromList([...audioData, ...id3v1Tag]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(128));
        expect(extracted[125], equals(0)); // Zero separator
        expect(extracted[126], equals(7)); // Track number
      });

      test('should handle various genre values', () {
        for (final genre in [0, 17, 255]) {
          final id3v1Tag = _createId3v1Tag(genre: genre);
          final extracted = locator.extract(id3v1Tag);

          expect(extracted, isNotNull);
          expect(extracted![127], equals(genre));
        }
      });

      test('should preserve all tag data exactly', () {
        final originalTag = _createId3v1Tag(
          title: 'Exact Preservation Test Song',
          artist: 'Exact Artist Name Here',
          album: 'Exact Album Name Here',
          year: '2023',
          comment: 'Exact comment text',
          track: 15,
          genre: 42,
        );

        final extracted = locator.extract(originalTag);

        expect(extracted, isNotNull);
        expect(extracted, equals(originalTag));

        // Verify specific fields are preserved
        final titleBytes = extracted!.sublist(3, 33);
        final artistBytes = extracted.sublist(33, 63);
        final albumBytes = extracted.sublist(63, 93);
        final yearBytes = extracted.sublist(93, 97);

        expect(_extractNullTerminatedString(titleBytes), equals('Exact Preservation Test Song'));
        expect(_extractNullTerminatedString(artistBytes), equals('Exact Artist Name Here'));
        expect(_extractNullTerminatedString(albumBytes), equals('Exact Album Name Here'));
        expect(_extractNullTerminatedString(yearBytes), equals('2023'));
      });
    });

    group('inject', () {
      test('should inject new ID3v1 tag at end of file without existing tag', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        final newTag = _createId3v1Tag(
          title: 'New Song',
          artist: 'New Artist',
          album: 'New Album',
          year: '2023',
          comment: 'New Comment',
          track: 1,
          genre: 17,
        );

        final result = locator.inject(originalFile, newTag);

        expect(result.length, equals(audioData.length + 128));
        expect(result.sublist(0, audioData.length), equals(audioData));
        expect(result.sublist(audioData.length), equals(newTag));
      });

      test('should replace existing ID3v1 tag', () {
        final audioData = List.filled(1000, 0xFF);
        final oldTag = _createId3v1Tag(
          title: 'Old Song',
          artist: 'Old Artist',
          genre: 1,
        );
        final originalFile = Uint8List.fromList([...audioData, ...oldTag]);

        final newTag = _createId3v1Tag(
          title: 'New Song',
          artist: 'New Artist',
          genre: 17,
        );

        final result = locator.inject(originalFile, newTag);

        expect(result.length, equals(audioData.length + 128));
        expect(result.sublist(0, audioData.length), equals(audioData));
        expect(result.sublist(audioData.length), equals(newTag));
        expect(result.sublist(audioData.length), isNot(equals(oldTag)));
      });

      test('should remove ID3v1 tag when containerBytes is null', () {
        final audioData = List.filled(1000, 0xFF);
        final tag = _createId3v1Tag(
          title: 'Remove Me',
          artist: 'Remove Artist',
          genre: 5,
        );
        final originalFile = Uint8List.fromList([...audioData, ...tag]);

        final result = locator.inject(originalFile, null);

        expect(result.length, equals(audioData.length));
        expect(result, equals(audioData));
      });

      test('should handle files without existing ID3v1 tags', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        // Remove tag (should return original file since no tag exists)
        final removedResult = locator.inject(originalFile, null);
        expect(removedResult, equals(originalFile));

        // Add tag
        final newTag = _createId3v1Tag(title: 'Added Song');
        final addedResult = locator.inject(originalFile, newTag);
        expect(addedResult.length, equals(audioData.length + 128));
        expect(addedResult.sublist(0, audioData.length), equals(audioData));
        expect(addedResult.sublist(audioData.length), equals(newTag));
      });

      test('should handle invalid container bytes gracefully', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        // Try to inject invalid ID3v1 data (too short)
        final invalidTag = Uint8List.fromList([0x54, 0x41, 0x47]); // Only "TAG"
        final result1 = locator.inject(originalFile, invalidTag);
        expect(result1, equals(originalFile)); // Should return original file

        // Try to inject data without TAG signature
        final noSignature = Uint8List.fromList(List.filled(128, 0x00));
        final result2 = locator.inject(originalFile, noSignature);
        expect(result2, equals(originalFile)); // Should return original file

        // Try to inject data that's too long
        final tooLong = Uint8List.fromList(List.filled(200, 0x42));
        final result3 = locator.inject(originalFile, tooLong);
        expect(result3, equals(originalFile)); // Should return original file
      });

      test('should preserve audio data integrity during replacement', () {
        final originalAudioData = List.generate(1000, (i) => i % 256);
        final oldTag = _createId3v1Tag(title: 'Old');
        final originalFile = Uint8List.fromList([...originalAudioData, ...oldTag]);

        final newTag = _createId3v1Tag(title: 'New');
        final result = locator.inject(originalFile, newTag);

        final extractedAudioData = result.sublist(0, originalAudioData.length);
        expect(extractedAudioData, equals(originalAudioData));
      });

      test('should handle minimum file size (tag only)', () {
        final originalTag = _createId3v1Tag(title: 'Original');
        final newTag = _createId3v1Tag(title: 'Replacement');

        final result = locator.inject(originalTag, newTag);

        expect(result.length, equals(128));
        expect(result, equals(newTag));
        expect(result, isNot(equals(originalTag)));
      });

      test('should handle multiple inject operations', () {
        final audioData = List.filled(500, 0xAA);
        var currentFile = Uint8List.fromList(audioData);

        // First injection
        final tag1 = _createId3v1Tag(title: 'First', track: 1);
        currentFile = locator.inject(currentFile, tag1);
        expect(currentFile.length, equals(500 + 128));

        // Second injection (replacement)
        final tag2 = _createId3v1Tag(title: 'Second', track: 2);
        currentFile = locator.inject(currentFile, tag2);
        expect(currentFile.length, equals(500 + 128)); // Same size

        // Verify final state
        final extracted = locator.extract(currentFile);
        expect(extracted, equals(tag2));
        expect(extracted, isNot(equals(tag1)));
      });

      test('should handle edge case with exactly 128-byte audio file', () {
        final audioData = List.filled(128, 0xBB);
        final originalFile = Uint8List.fromList(audioData);

        final tag = _createId3v1Tag(title: 'Edge Case');
        final result = locator.inject(originalFile, tag);

        expect(result.length, equals(256)); // 128 + 128
        expect(result.sublist(0, 128), equals(audioData));
        expect(result.sublist(128), equals(tag));
      });
    });

    group('edge cases and error handling', () {
      test('should handle files with TAG signature but invalid structure', () {
        final audioData = List.filled(1000, 0xFF);
        final fakeTag = List.filled(128, 0x00);
        fakeTag[0] = 0x54; // 'T'
        fakeTag[1] = 0x41; // 'A'
        fakeTag[2] = 0x47; // 'G'
        // Rest is zeros, which is technically valid

        final fileBytes = Uint8List.fromList([...audioData, ...fakeTag]);

        expect(locator.fileMatches(fileBytes), isTrue);

        final extracted = locator.extract(fileBytes);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(128));
      });

      test('should handle files with binary data that might contain TAG', () {
        // Create audio data that contains "TAG" in the middle
        final audioData = List.filled(1000, 0xFF);
        audioData[500] = 0x54; // 'T'
        audioData[501] = 0x41; // 'A'
        audioData[502] = 0x47; // 'G'

        // But no TAG at the end
        final fileBytes = Uint8List.fromList(audioData);

        expect(locator.fileMatches(fileBytes), isFalse);
        expect(locator.extract(fileBytes), isNull);
      });

      test('should handle maximum field lengths correctly', () {
        final maxTag = _createId3v1Tag(
          title: 'A' * 30, // Maximum title length
          artist: 'B' * 30, // Maximum artist length
          album: 'C' * 30, // Maximum album length
          year: '2023', // 4 characters
          comment: 'D' * 28, // Maximum comment with track
          track: 255, // Maximum track number
          genre: 255, // Maximum genre
        );

        expect(locator.fileMatches(maxTag), isTrue);

        final extracted = locator.extract(maxTag);
        expect(extracted, isNotNull);
        expect(extracted, equals(maxTag));
      });

      test('should handle null bytes in text fields', () {
        final tagWithNulls = _createId3v1Tag(
          title: 'Song\x00\x00\x00', // Null-terminated title
          artist: 'Artist\x00', // Null-terminated artist
          comment: 'Comment\x00\x00', // Null-terminated comment
          track: 5,
        );

        expect(locator.fileMatches(tagWithNulls), isTrue);

        final extracted = locator.extract(tagWithNulls);
        expect(extracted, isNotNull);
        expect(extracted, equals(tagWithNulls));
      });

      test('should handle non-ASCII characters in Latin-1 range', () {
        final latinTag = _createId3v1Tag(
          title: 'Café Münchën', // Latin-1 characters
          artist: 'Naïve Artïst',
          album: 'Albüm Nämë',
        );

        expect(locator.fileMatches(latinTag), isTrue);

        final extracted = locator.extract(latinTag);
        expect(extracted, isNotNull);
        expect(extracted, equals(latinTag));
      });
    });

    group('ID3v1.0 vs ID3v1.1 format detection', () {
      test('should handle ID3v1.0 format (30-character comment, no track)', () {
        final id3v10Tag = _createId3v1Tag(
          comment: 'This is exactly thirty chars!!', // Exactly 30 chars
          track: null, // No track number
        );

        final extracted = locator.extract(id3v10Tag);
        expect(extracted, isNotNull);

        // In ID3v1.0, bytes 125-126 are part of comment
        expect(extracted![125], isNot(equals(0))); // Not zero separator
        expect(extracted[126], isNot(equals(0))); // Not track number
      });

      test('should handle ID3v1.1 format (28-character comment, with track)', () {
        final id3v11Tag = _createId3v1Tag(
          comment: 'Short comment', // Less than 28 chars
          track: 12, // Track number present
        );

        final extracted = locator.extract(id3v11Tag);
        expect(extracted, isNotNull);

        // In ID3v1.1, byte 125 is zero, byte 126 is track
        expect(extracted![125], equals(0)); // Zero separator
        expect(extracted[126], equals(12)); // Track number
      });

      test('should handle ambiguous case (28 chars + zero + track)', () {
        final ambiguousTag = _createId3v1Tag(
          comment: 'Exactly twenty-eight char', // Exactly 28 chars
          track: 8,
        );

        final extracted = locator.extract(ambiguousTag);
        expect(extracted, isNotNull);

        // Should be treated as ID3v1.1
        expect(extracted![125], equals(0)); // Zero separator
        expect(extracted[126], equals(8)); // Track number
      });
    });
  });
}

/// Helper function to create a valid ID3v1 tag with specified fields.
///
/// Creates a 128-byte ID3v1 tag with the "TAG" signature and properly
/// formatted fields. Handles both ID3v1.0 (no track) and ID3v1.1 (with track)
/// formats automatically based on whether a track number is provided.
///
/// ## Parameters
///
/// - [title]: Song title (max 30 chars, null-padded)
/// - [artist]: Artist name (max 30 chars, null-padded)
/// - [album]: Album name (max 30 chars, null-padded)
/// - [year]: Year string (max 4 chars, null-padded)
/// - [comment]: Comment text (max 30 chars for ID3v1.0, max 28 for ID3v1.1)
/// - [track]: Track number (null for ID3v1.0, 1-255 for ID3v1.1)
/// - [genre]: Genre code (0-255)
///
/// ## Returns
///
/// A [Uint8List] containing a valid 128-byte ID3v1 tag.
Uint8List _createId3v1Tag({
  String title = 'Test Title',
  String artist = 'Test Artist',
  String album = 'Test Album',
  String year = '2023',
  String comment = 'Test Comment',
  int? track,
  int genre = 17, // Rock
}) {
  final tag = Uint8List(128);

  // TAG signature
  tag[0] = 0x54; // 'T'
  tag[1] = 0x41; // 'A'
  tag[2] = 0x47; // 'G'

  // Helper function to write null-padded string
  void writeField(String text, int offset, int maxLength) {
    final bytes = text.codeUnits.take(maxLength).toList();
    for (int i = 0; i < maxLength; i++) {
      tag[offset + i] = i < bytes.length ? bytes[i] : 0;
    }
  }

  // Write fields
  writeField(title, 3, 30); // Title (30 bytes)
  writeField(artist, 33, 30); // Artist (30 bytes)
  writeField(album, 63, 30); // Album (30 bytes)
  writeField(year, 93, 4); // Year (4 bytes)

  // Comment field handling (ID3v1.0 vs ID3v1.1)
  if (track != null) {
    // ID3v1.1 format: 28-byte comment + zero + track
    writeField(comment, 97, 28);
    tag[125] = 0; // Zero separator
    tag[126] = track; // Track number
  } else {
    // ID3v1.0 format: 30-byte comment (fills bytes 97-126)
    writeField(comment, 97, 30);
    // Note: writeField will pad with zeros if comment is shorter than 30 chars
    // For ID3v1.0, we want to ensure bytes 125-126 are NOT zero+track pattern
    // If comment is shorter than 30 chars, writeField will pad with zeros
    // We need to ensure byte 125 is not zero to distinguish from ID3v1.1
    if (comment.length < 30) {
      // If comment doesn't fill all 30 bytes, ensure byte 125 is non-zero
      if (tag[125] == 0) {
        tag[125] = 0x20; // Space character
      }
    }
  }

  // Genre
  tag[127] = genre;

  return tag;
}

/// Helper function to extract null-terminated string from byte array.
///
/// Reads bytes until a null terminator (0x00) is found or the end of the
/// array is reached. Converts the bytes to a string using Latin-1 encoding
/// (which is compatible with ASCII and extended ASCII used in ID3v1).
///
/// ## Parameters
///
/// - [bytes]: The byte array to read from
///
/// ## Returns
///
/// The extracted string, or empty string if no valid characters found.
String _extractNullTerminatedString(Uint8List bytes) {
  int length = 0;
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0) break;
    length++;
  }

  if (length == 0) return '';

  return String.fromCharCodes(bytes.sublist(0, length));
}
