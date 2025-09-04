import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/utils/locators/id3v2_locator.dart';
import 'package:phonic/src/utils/synchsafe_int.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v2Locator', () {
    late Id3v2Locator locator;

    setUp(() {
      locator = Id3v2Locator();
    });

    group('containerKind', () {
      test('should return id3v2 container kind', () {
        expect(locator.containerKind, equals(ContainerKind.id3v2));
      });
    });

    group('fileMatches', () {
      test('should return true for valid ID3v2 header', () {
        final validHeader = _createId3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: 0,
          size: 100,
        );
        final fileBytes = Uint8List.fromList([...validHeader, ...List.filled(100, 0)]);

        expect(locator.fileMatches(fileBytes), isTrue);
      });

      test('should return false for files too small', () {
        final tooSmall = Uint8List.fromList([0x49, 0x44, 0x33]); // Only 3 bytes
        expect(locator.fileMatches(tooSmall), isFalse);
      });

      test('should return false for empty files', () {
        final empty = Uint8List(0);
        expect(locator.fileMatches(empty), isFalse);
      });

      test('should return false for files without ID3 signature', () {
        final noSignature = Uint8List.fromList([
          0x00, 0x00, 0x00, // Not "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x00, 0x00, 0x00, 0x64, // Size (100)
        ]);
        expect(locator.fileMatches(noSignature), isFalse);
      });

      test('should return true for different ID3v2 versions', () {
        // Test ID3v2.2
        final v22Header = _createId3v2Header(majorVersion: 2, minorVersion: 0);
        final v22File = Uint8List.fromList([...v22Header, ...List.filled(100, 0)]);
        expect(locator.fileMatches(v22File), isTrue);

        // Test ID3v2.3
        final v23Header = _createId3v2Header(majorVersion: 3, minorVersion: 0);
        final v23File = Uint8List.fromList([...v23Header, ...List.filled(100, 0)]);
        expect(locator.fileMatches(v23File), isTrue);

        // Test ID3v2.4
        final v24Header = _createId3v2Header(majorVersion: 4, minorVersion: 0);
        final v24File = Uint8List.fromList([...v24Header, ...List.filled(100, 0)]);
        expect(locator.fileMatches(v24File), isTrue);
      });

      test('should return true even with various flags set', () {
        final headerWithFlags = _createId3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: 0x80, // Unsynchronization flag
          size: 100,
        );
        final fileBytes = Uint8List.fromList([...headerWithFlags, ...List.filled(100, 0)]);

        expect(locator.fileMatches(fileBytes), isTrue);
      });
    });

    group('extract', () {
      test('should extract complete ID3v2 tag with header and data', () {
        final tagSize = 100;
        final header = _createId3v2Header(size: tagSize);
        final tagData = List.filled(tagSize, 0x42); // Fill with 'B'
        final audioData = List.filled(1000, 0xFF); // Audio data
        final fileBytes = Uint8List.fromList([...header, ...tagData, ...audioData]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(10 + tagSize)); // Header + tag data
        expect(extracted.sublist(0, 10), equals(header));
        expect(extracted.sublist(10), equals(tagData));
      });

      test('should return null for files without ID3v2 signature', () {
        final invalidFile = Uint8List.fromList([0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64]);

        expect(locator.extract(invalidFile), isNull);
      });

      test('should return null for unsupported versions', () {
        // Test version 1.x (unsupported)
        final v1Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x01, 0x00, // Version 1.0 (unsupported)
          0x00, // Flags
          0x00, 0x00, 0x00, 0x64, // Size
        ]);
        final v1File = Uint8List.fromList([...v1Header, ...List.filled(100, 0)]);

        expect(locator.extract(v1File), isNull);

        // Test version 5.x (future, unsupported)
        final v5Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x05, 0x00, // Version 5.0 (unsupported)
          0x00, // Flags
          0x00, 0x00, 0x00, 0x64, // Size
        ]);
        final v5File = Uint8List.fromList([...v5Header, ...List.filled(100, 0)]);

        expect(locator.extract(v5File), isNull);
      });

      test('should return null for invalid synchsafe integers', () {
        final invalidSynchsafe = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x80, 0x00, 0x00, 0x64, // Invalid synchsafe (MSB set in first byte)
        ]);

        expect(locator.extract(invalidSynchsafe), isNull);
      });

      test('should return null for truncated files', () {
        final tagSize = 1000;
        final header = _createId3v2Header(size: tagSize);
        final incompleteData = List.filled(500, 0x42); // Only half the declared size
        final truncatedFile = Uint8List.fromList([...header, ...incompleteData]);

        expect(locator.extract(truncatedFile), isNull);
      });

      test('should handle zero-size tags', () {
        final header = _createId3v2Header(size: 0);
        final fileBytes = Uint8List.fromList([...header, ...List.filled(1000, 0xFF)]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(10)); // Just the header
        expect(extracted, equals(header));
      });

      test('should handle maximum synchsafe size', () {
        final maxSize = SynchsafeInt.maxValue;
        final header = _createId3v2Header(size: maxSize);
        final tagData = List.filled(maxSize, 0x42);
        final fileBytes = Uint8List.fromList([...header, ...tagData]);

        final extracted = locator.extract(fileBytes);

        expect(extracted, isNotNull);
        expect(extracted!.length, equals(10 + maxSize));
      });

      test('should extract different ID3v2 versions correctly', () {
        // Test each supported version
        for (final version in [2, 3, 4]) {
          final header = _createId3v2Header(majorVersion: version, size: 50);
          final tagData = List.filled(50, version); // Use version as fill byte
          final fileBytes = Uint8List.fromList([...header, ...tagData]);

          final extracted = locator.extract(fileBytes);

          expect(extracted, isNotNull, reason: 'Version 2.$version should be supported');
          expect(extracted!.length, equals(60)); // 10 + 50
          expect(extracted[3], equals(version)); // Check version in header
        }
      });
    });

    group('inject', () {
      test('should inject new ID3v2 tag at beginning of file', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        final newTagSize = 200;
        final newTag = _createCompleteId3v2Tag(size: newTagSize);

        final result = locator.inject(originalFile, newTag);

        expect(result.length, equals(newTag.length + audioData.length));
        expect(result.sublist(0, newTag.length), equals(newTag));
        expect(result.sublist(newTag.length), equals(audioData));
      });

      test('should replace existing ID3v2 tag', () {
        final oldTagSize = 100;
        final oldTag = _createCompleteId3v2Tag(size: oldTagSize);
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList([...oldTag, ...audioData]);

        final newTagSize = 200;
        final newTag = _createCompleteId3v2Tag(size: newTagSize);

        final result = locator.inject(originalFile, newTag);

        expect(result.length, equals(newTag.length + audioData.length));
        expect(result.sublist(0, newTag.length), equals(newTag));
        expect(result.sublist(newTag.length), equals(audioData));
      });

      test('should remove ID3v2 tag when containerBytes is null', () {
        final tagSize = 150;
        final tag = _createCompleteId3v2Tag(size: tagSize);
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList([...tag, ...audioData]);

        final result = locator.inject(originalFile, null);

        expect(result.length, equals(audioData.length));
        expect(result, equals(audioData));
      });

      test('should handle files without existing ID3v2 tags', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        // Remove tag (should return original file since no tag exists)
        final removedResult = locator.inject(originalFile, null);
        expect(removedResult, equals(originalFile));

        // Add tag
        final newTag = _createCompleteId3v2Tag(size: 100);
        final addedResult = locator.inject(originalFile, newTag);
        expect(addedResult.length, equals(newTag.length + audioData.length));
        expect(addedResult.sublist(0, newTag.length), equals(newTag));
        expect(addedResult.sublist(newTag.length), equals(audioData));
      });

      test('should handle invalid container bytes gracefully', () {
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList(audioData);

        // Try to inject invalid ID3v2 data (too short)
        final invalidTag = Uint8List.fromList([0x49, 0x44]); // Only "ID"
        final result1 = locator.inject(originalFile, invalidTag);
        expect(result1, equals(originalFile)); // Should return original file

        // Try to inject data without ID3 signature
        final noSignature = Uint8List.fromList([0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64]);
        final result2 = locator.inject(originalFile, noSignature);
        expect(result2, equals(originalFile)); // Should return original file
      });

      test('should handle tag size changes correctly', () {
        // Start with small tag
        final smallTag = _createCompleteId3v2Tag(size: 50);
        final audioData = List.filled(1000, 0xFF);
        final originalFile = Uint8List.fromList([...smallTag, ...audioData]);

        // Replace with larger tag
        final largeTag = _createCompleteId3v2Tag(size: 500);
        final result1 = locator.inject(originalFile, largeTag);
        expect(result1.length, equals(largeTag.length + audioData.length));
        expect(result1.sublist(largeTag.length), equals(audioData));

        // Replace with smaller tag
        final tinyTag = _createCompleteId3v2Tag(size: 10);
        final result2 = locator.inject(result1, tinyTag);
        expect(result2.length, equals(tinyTag.length + audioData.length));
        expect(result2.sublist(tinyTag.length), equals(audioData));
      });

      test('should preserve audio data integrity', () {
        final originalAudioData = List.generate(1000, (i) => i % 256);
        final tag = _createCompleteId3v2Tag(size: 100);
        final originalFile = Uint8List.fromList([...tag, ...originalAudioData]);

        final newTag = _createCompleteId3v2Tag(size: 200);
        final result = locator.inject(originalFile, newTag);

        final extractedAudioData = result.sublist(newTag.length);
        expect(extractedAudioData, equals(originalAudioData));
      });
    });

    group('edge cases and error handling', () {
      test('should handle files with only header and no tag data', () {
        final headerOnly = _createId3v2Header(size: 0);
        final fileBytes = Uint8List.fromList(headerOnly);

        expect(locator.fileMatches(fileBytes), isTrue);

        final extracted = locator.extract(fileBytes);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(10));
      });

      test('should handle corrupted synchsafe integers gracefully', () {
        final corruptedHeader = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0xFF, 0xFF, 0xFF, 0xFF, // All MSBs set (invalid synchsafe)
        ]);

        expect(locator.extract(corruptedHeader), isNull);
      });

      test('should handle very large declared sizes that exceed file length', () {
        final header = _createId3v2Header(size: 1000000); // 1MB declared
        final smallFile = Uint8List.fromList([...header, ...List.filled(100, 0)]); // Only 100 bytes actual

        expect(locator.extract(smallFile), isNull);
      });

      test('should handle minimum valid file size', () {
        final minimalTag = _createCompleteId3v2Tag(size: 0);
        expect(locator.fileMatches(minimalTag), isTrue);

        final extracted = locator.extract(minimalTag);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(10));
      });
    });
  });
}

/// Helper function to create a valid ID3v2 header with specified parameters.
List<int> _createId3v2Header({
  int majorVersion = 4,
  int minorVersion = 0,
  int flags = 0,
  int size = 100,
}) {
  final sizeBytes = SynchsafeInt.encode(size);

  return [
    0x49, 0x44, 0x33, // "ID3" signature
    majorVersion, minorVersion, // Version
    flags, // Flags
    ...sizeBytes, // Size as synchsafe integer
  ];
}

/// Helper function to create a complete ID3v2 tag (header + data) for testing.
Uint8List _createCompleteId3v2Tag({
  int majorVersion = 4,
  int minorVersion = 0,
  int flags = 0,
  int size = 100,
}) {
  final header = _createId3v2Header(
    majorVersion: majorVersion,
    minorVersion: minorVersion,
    flags: flags,
    size: size,
  );
  final tagData = List.filled(size, 0x42); // Fill with 'B'

  return Uint8List.fromList([...header, ...tagData]);
}
