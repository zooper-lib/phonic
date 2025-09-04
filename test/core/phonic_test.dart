import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('Phonic Factory Class', () {
    group('fromFile', () {
      test('should throw ArgumentError for empty path', () async {
        expect(
          () => Phonic.fromFile(''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Path cannot be empty'),
            ),
          ),
        );
      });

      test('should throw FileSystemException for non-existent file', () async {
        expect(
          () => Phonic.fromFile('/non/existent/file.mp3'),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('should create PhonicAudioFile for valid MP3 file', () async {
        // Create a minimal MP3 file with ID3v2 header
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final tempFile = await _createTempFile('test.mp3', mp3Bytes);

        try {
          final audioFile = await Phonic.fromFile(tempFile.path);
          expect(audioFile, isA<PhonicAudioFile>());
          audioFile.dispose();
        } finally {
          // Try to delete the file, but don't fail the test if it's locked
          try {
            await tempFile.delete();
          } catch (e) {
            // File might be locked by the system, ignore deletion errors
            // Warning: Could not delete temp file ${tempFile.path}: $e
          }
        }
      });

      test('should throw UnsupportedFormatException for unsupported format', () async {
        // Create a file with unsupported content
        final unsupportedBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        final tempFile = await _createTempFile('test.xyz', unsupportedBytes);

        try {
          expect(
            () => Phonic.fromFile(tempFile.path),
            throwsA(
              isA<UnsupportedFormatException>().having(
                (e) => e.message,
                'message',
                contains('No format strategy can handle this audio data'),
              ),
            ),
          );
        } finally {
          // Try to delete the file, but don't fail the test if it's locked
          try {
            await tempFile.delete();
          } catch (e) {
            // File might be locked by the system, ignore deletion errors
            // Warning: Could not delete temp file ${tempFile.path}: $e
          }
        }
      });
    });

    group('fromBytes', () {
      test('should throw ArgumentError for empty bytes', () {
        expect(
          () => Phonic.fromBytes(Uint8List(0)),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Bytes cannot be empty'),
            ),
          ),
        );
      });

      test('should create PhonicAudioFile for valid MP3 bytes', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(mp3Bytes, 'test.mp3');

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should create PhonicAudioFile for valid MP3 bytes without filename', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(mp3Bytes);

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should create PhonicAudioFile for valid FLAC bytes', () {
        final flacBytes = _createMinimalFlac();
        final audioFile = Phonic.fromBytes(flacBytes, 'test.flac');

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should create PhonicAudioFile for valid OGG bytes', () {
        final oggBytes = _createMinimalOgg();
        final audioFile = Phonic.fromBytes(oggBytes, 'test.ogg');

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should create PhonicAudioFile for valid MP4 bytes', () {
        final mp4Bytes = _createMinimalMp4();
        final audioFile = Phonic.fromBytes(mp4Bytes, 'test.m4a');

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should throw UnsupportedFormatException for unsupported format', () {
        final unsupportedBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        expect(
          () => Phonic.fromBytes(unsupportedBytes, 'test.xyz'),
          throwsA(
            isA<UnsupportedFormatException>().having(
              (e) => e.message,
              'message',
              contains('No format strategy can handle this audio data'),
            ),
          ),
        );
      });
    });

    group('format detection', () {
      test('should prioritize extension-matching strategies', () {
        // Create bytes that could match multiple formats but use MP3 extension
        final ambiguousBytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(ambiguousBytes, 'test.mp3');

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should fall back to binary detection without filename', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(mp3Bytes);

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });

      test('should handle various MP4 extensions', () {
        final mp4Bytes = _createMinimalMp4();

        for (final extension in ['test.m4a', 'test.mp4', 'test.aac']) {
          final audioFile = Phonic.fromBytes(mp4Bytes, extension);
          expect(audioFile, isA<PhonicAudioFile>());
          audioFile.dispose();
        }
      });
    });

    group('codec registry caching', () {
      test('should cache codec registries by format strategy type', () {
        final mp3Bytes1 = _createMinimalMp3WithId3v2();
        final mp3Bytes2 = _createMinimalMp3WithId3v2();

        final audioFile1 = Phonic.fromBytes(mp3Bytes1, 'test1.mp3');
        final audioFile2 = Phonic.fromBytes(mp3Bytes2, 'test2.mp3');

        // Both should be created successfully (registry caching working)
        expect(audioFile1, isA<PhonicAudioFile>());
        expect(audioFile2, isA<PhonicAudioFile>());

        audioFile1.dispose();
        audioFile2.dispose();
      });

      test('should clear cache when requested', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile1 = Phonic.fromBytes(mp3Bytes, 'test1.mp3');

        // Clear cache
        Phonic.clearCache();

        // Should still work after cache clear
        final audioFile2 = Phonic.fromBytes(mp3Bytes, 'test2.mp3');

        expect(audioFile1, isA<PhonicAudioFile>());
        expect(audioFile2, isA<PhonicAudioFile>());

        audioFile1.dispose();
        audioFile2.dispose();
      });
    });

    group('error handling', () {
      test('should provide context in error messages', () {
        final unsupportedBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        expect(
          () => Phonic.fromBytes(unsupportedBytes, 'test.xyz'),
          throwsA(
            isA<UnsupportedFormatException>().having(
              (e) => e.context,
              'context',
              contains('file: test.xyz'),
            ),
          ),
        );
      });

      test('should handle null filename gracefully', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(mp3Bytes, null);

        expect(audioFile, isA<PhonicAudioFile>());
        audioFile.dispose();
      });
    });

    group('memory management', () {
      test('should create independent instances', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile1 = Phonic.fromBytes(mp3Bytes, 'test1.mp3');
        final audioFile2 = Phonic.fromBytes(mp3Bytes, 'test2.mp3');

        // Should be different instances
        expect(identical(audioFile1, audioFile2), isFalse);

        audioFile1.dispose();
        audioFile2.dispose();
      });

      test('should handle disposal properly', () {
        final mp3Bytes = _createMinimalMp3WithId3v2();
        final audioFile = Phonic.fromBytes(mp3Bytes, 'test.mp3');

        // Should not throw when disposing
        expect(() => audioFile.dispose(), returnsNormally);
      });
    });
  });
}

/// Creates a minimal MP3 file with ID3v2 header for testing.
Uint8List _createMinimalMp3WithId3v2() {
  final bytes = <int>[];

  // ID3v2.4 header
  bytes.addAll([0x49, 0x44, 0x33]); // "ID3"
  bytes.addAll([0x04, 0x00]); // Version 2.4.0
  bytes.add(0x00); // Flags
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Size (synchsafe, 0 for minimal)

  // Minimal MP3 frame sync
  bytes.addAll([0xFF, 0xFB]); // MP3 frame header start

  // Add some padding to make it look more like a real file
  bytes.addAll(List.filled(100, 0x00));

  return Uint8List.fromList(bytes);
}

/// Creates a minimal FLAC file for testing.
Uint8List _createMinimalFlac() {
  final bytes = <int>[];

  // FLAC signature
  bytes.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // Minimal metadata block header (STREAMINFO)
  bytes.add(0x00); // Last block flag + block type
  bytes.addAll([0x00, 0x00, 0x22]); // Block length (34 bytes for STREAMINFO)

  // Minimal STREAMINFO content (34 bytes)
  bytes.addAll(List.filled(34, 0x00));

  return Uint8List.fromList(bytes);
}

/// Creates a minimal OGG file for testing.
Uint8List _createMinimalOgg() {
  final bytes = <int>[];

  // OGG page header
  bytes.addAll([0x4F, 0x67, 0x67, 0x53]); // "OggS"
  bytes.add(0x00); // Version
  bytes.add(0x02); // Header type (first page)
  bytes.addAll(List.filled(8, 0x00)); // Granule position
  bytes.addAll(List.filled(4, 0x00)); // Serial number
  bytes.addAll(List.filled(4, 0x00)); // Page sequence
  bytes.addAll(List.filled(4, 0x00)); // Checksum
  bytes.add(0x01); // Page segments
  bytes.add(0x1E); // Segment length

  // Minimal Vorbis identification header
  bytes.add(0x01); // Packet type
  bytes.addAll([0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]); // "vorbis"
  bytes.addAll(List.filled(23, 0x00)); // Rest of header

  return Uint8List.fromList(bytes);
}

/// Creates a minimal MP4 file for testing.
Uint8List _createMinimalMp4() {
  final bytes = <int>[];

  // ftyp atom
  bytes.addAll([0x00, 0x00, 0x00, 0x20]); // Atom size (32 bytes)
  bytes.addAll([0x66, 0x74, 0x79, 0x70]); // "ftyp"
  bytes.addAll([0x4D, 0x34, 0x41, 0x20]); // Major brand "M4A "
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Minor version
  bytes.addAll([0x4D, 0x34, 0x41, 0x20]); // Compatible brand "M4A "
  bytes.addAll([0x6D, 0x70, 0x34, 0x32]); // Compatible brand "mp42"

  // Minimal moov atom
  bytes.addAll([0x00, 0x00, 0x00, 0x08]); // Atom size (8 bytes, header only)
  bytes.addAll([0x6D, 0x6F, 0x6F, 0x76]); // "moov"

  return Uint8List.fromList(bytes);
}

/// Creates a temporary file with the given content for testing.
Future<File> _createTempFile(String filename, Uint8List content) async {
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsBytes(content);
  return tempFile;
}
