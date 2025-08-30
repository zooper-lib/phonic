import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/formats/flac/flac_format_strategy.dart';

void main() {
  group('FlacFormatStrategy', () {
    late FlacFormatStrategy strategy;

    setUp(() {
      strategy = const FlacFormatStrategy();
    });

    group('basic properties', () {
      test('returns correct media kind', () {
        expect(strategy.mediaKind, equals(MediaKind.flac));
      });

      test('returns correct precedence order', () {
        expect(
          strategy.precedence,
          equals([
            (ContainerKind.vorbis, ''),
          ]),
        );
      });

      test('returns correct fanout targets', () {
        expect(
          strategy.fanout,
          equals([
            (ContainerKind.vorbis, ''),
          ]),
        );
      });
    });

    group('canHandle', () {
      test('returns false for empty data', () {
        expect(strategy.canHandle(Uint8List(0)), isFalse);
      });

      test('returns false for insufficient data', () {
        expect(strategy.canHandle(Uint8List.fromList([0x66, 0x4C])), isFalse);
      });

      test('detects FLAC signature', () {
        final flacHeader = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x00, // Metadata block header
          0x00, 0x00, 0x22, // STREAMINFO block size
          // STREAMINFO data would follow...
        ]);
        expect(strategy.canHandle(flacHeader), isTrue);
      });

      test('detects FLAC signature with minimal data', () {
        final minimalFlac = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature only
        ]);
        expect(strategy.canHandle(minimalFlac), isTrue);
      });

      test('rejects invalid FLAC signature - wrong first byte', () {
        final invalidHeader = Uint8List.fromList([
          0x65, 0x4C, 0x61, 0x43, // "eLaC" - invalid first byte
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid FLAC signature - wrong second byte', () {
        final invalidHeader = Uint8List.fromList([
          0x66, 0x4D, 0x61, 0x43, // "fMaC" - invalid second byte
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid FLAC signature - wrong third byte', () {
        final invalidHeader = Uint8List.fromList([
          0x66, 0x4C, 0x62, 0x43, // "fLbC" - invalid third byte
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid FLAC signature - wrong fourth byte', () {
        final invalidHeader = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x44, // "fLaD" - invalid fourth byte
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects completely different signature', () {
        final mp3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, // "ID3" + version - MP3 ID3v2 header
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(mp3Header), isFalse);
      });

      test('rejects OGG signature', () {
        final oggHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, 0x02, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(oggHeader), isFalse);
      });

      test('rejects MP4 signature', () {
        final mp4Header = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // "ftyp" box type
        ]);
        expect(strategy.canHandle(mp4Header), isFalse);
      });

      test('rejects random data', () {
        final randomData = Uint8List.fromList([
          0x00,
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
          0x08,
          0x09,
          0x0A,
          0x0B,
        ]);
        expect(strategy.canHandle(randomData), isFalse);
      });

      test('handles FLAC file with complete STREAMINFO block', () {
        final flacWithStreaminfo = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x00, // Last metadata block flag (0) + block type (STREAMINFO = 0)
          0x00, 0x00, 0x22, // Block length (34 bytes for STREAMINFO)
          // STREAMINFO block data (34 bytes)
          0x09, 0x60, // Min/max block size
          0x09, 0x60,
          0x00, 0x00, 0x00, // Min/max frame size
          0x00, 0x00, 0x00,
          0x0A, 0xC4, 0x42, // Sample rate (44100) + channels (2) + bits per sample (16)
          0x00, 0x00, 0x00, 0x00, 0x00, // Total samples
          // MD5 signature (16 bytes)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(flacWithStreaminfo), isTrue);
      });

      test('handles FLAC file with multiple metadata blocks', () {
        final flacWithMultipleBlocks = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x00, // STREAMINFO block (not last)
          0x00, 0x00, 0x22, // Block length
          // STREAMINFO data (34 bytes)
          ...List.filled(34, 0x00),
          0x04, // VORBIS_COMMENT block (not last)
          0x00, 0x00, 0x10, // Block length
          // VORBIS_COMMENT data (16 bytes)
          ...List.filled(16, 0x00),
          0x86, // PICTURE block (last block)
          0x00, 0x00, 0x08, // Block length
          // PICTURE data (8 bytes)
          ...List.filled(8, 0x00),
        ]);
        expect(strategy.canHandle(flacWithMultipleBlocks), isTrue);
      });
    });

    group('detectFormat', () {
      test('returns FLAC media kind for valid FLAC file', () {
        final flacHeader = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.detectFormat(flacHeader), equals(MediaKind.flac));
      });

      test('returns FLAC media kind for minimal FLAC signature', () {
        final minimalFlac = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" only
        ]);
        expect(strategy.detectFormat(minimalFlac), equals(MediaKind.flac));
      });

      test('throws UnsupportedFormatException for invalid data', () {
        final invalidData = Uint8List.fromList([
          0x00,
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
        ]);

        expect(
          () => strategy.detectFormat(invalidData),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('includes context in exception message', () {
        final invalidData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        expect(
          () => strategy.detectFormat(invalidData),
          throwsA(
            isA<UnsupportedFormatException>().having(
              (e) => e.context,
              'context',
              equals('FlacFormatStrategy.detectFormat'),
            ),
          ),
        );
      });

      test('includes correct error message', () {
        final invalidData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        expect(
          () => strategy.detectFormat(invalidData),
          throwsA(
            isA<UnsupportedFormatException>().having(
              (e) => e.message,
              'message',
              equals('File does not appear to be a valid FLAC format'),
            ),
          ),
        );
      });
    });

    group('FLAC signature validation edge cases', () {
      test('validates exact byte values for signature', () {
        // Test each byte of the signature individually
        final correctSignature = [0x66, 0x4C, 0x61, 0x43];

        for (int i = 0; i < 4; i++) {
          // Test with one byte changed
          final modifiedSignature = List<int>.from(correctSignature);
          modifiedSignature[i] = modifiedSignature[i] ^ 0x01; // Flip one bit

          final testData = Uint8List.fromList([
            ...modifiedSignature,
            0x00,
            0x00,
            0x00,
            0x00,
          ]);

          expect(strategy.canHandle(testData), isFalse, reason: 'Modified byte $i should make signature invalid');
        }
      });

      test('handles case sensitivity correctly', () {
        // FLAC signature is case-sensitive
        final lowercaseF = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x63, // "fLac" - lowercase 'c'
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(lowercaseF), isFalse);

        final uppercaseL = Uint8List.fromList([
          0x66, 0x6C, 0x61, 0x43, // "flac" - lowercase 'l'
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(uppercaseL), isFalse);
      });

      test('handles signature at different positions', () {
        // FLAC signature must be at the very beginning
        final signatureAtOffset = Uint8List.fromList([
          0x00, 0x00, // Some prefix data
          0x66, 0x4C, 0x61, 0x43, // "fLaC" at offset 2
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(signatureAtOffset), isFalse);
      });

      test('handles truncated signatures', () {
        // Test with 1, 2, and 3 bytes of signature
        expect(strategy.canHandle(Uint8List.fromList([0x66])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x66, 0x4C])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x66, 0x4C, 0x61])), isFalse);
      });
    });

    group('performance and edge cases', () {
      test('handles minimum valid file size', () {
        final minimalFlac = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]);
        expect(strategy.canHandle(minimalFlac), isTrue);
      });

      test('handles large FLAC files efficiently', () {
        final largeFlacFile = Uint8List(100000);
        // Set FLAC signature at the beginning
        largeFlacFile[0] = 0x66;
        largeFlacFile[1] = 0x4C;
        largeFlacFile[2] = 0x61;
        largeFlacFile[3] = 0x43;

        expect(strategy.canHandle(largeFlacFile), isTrue);
      });

      test('is stateless and reusable', () {
        final testData = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0x00, 0x00, 0x00, 0x22]);

        // Multiple calls should return same result
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.detectFormat(testData), equals(MediaKind.flac));
        expect(strategy.detectFormat(testData), equals(MediaKind.flac));
      });

      test('const constructor creates identical instances', () {
        const strategy1 = FlacFormatStrategy();
        const strategy2 = FlacFormatStrategy();

        expect(strategy1.mediaKind, equals(strategy2.mediaKind));
        expect(strategy1.precedence, equals(strategy2.precedence));
        expect(strategy1.fanout, equals(strategy2.fanout));
      });

      test('handles files with trailing data', () {
        final flacWithTrailing = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // FLAC signature
          0x00, 0x00, 0x00, 0x22, // STREAMINFO header
          // Followed by lots of data...
          ...List.filled(1000, 0x00),
        ]);
        expect(strategy.canHandle(flacWithTrailing), isTrue);
      });

      test('differentiates from similar signatures', () {
        // Test signatures that start with 'f' but are not FLAC
        final fakeSignatures = [
          [0x66, 0x4C, 0x61, 0x44], // "fLaD"
          [0x66, 0x4C, 0x62, 0x43], // "fLbC"
          [0x66, 0x4D, 0x61, 0x43], // "fMaC"
          [0x67, 0x4C, 0x61, 0x43], // "gLaC"
        ];

        for (final signature in fakeSignatures) {
          final testData = Uint8List.fromList([
            ...signature,
            0x00,
            0x00,
            0x00,
            0x00,
          ]);
          expect(
            strategy.canHandle(testData),
            isFalse,
            reason: 'Signature ${signature.map((b) => b.toRadixString(16)).join(' ')} should not be detected as FLAC',
          );
        }
      });
    });

    group('integration with FLAC specification', () {
      test('validates against FLAC specification requirements', () {
        // According to FLAC spec, signature must be exactly "fLaC"
        final specCompliantHeader = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" as per FLAC specification
          0x00, // STREAMINFO block (required first block)
          0x00, 0x00, 0x22, // STREAMINFO is always 34 bytes
        ]);
        expect(strategy.canHandle(specCompliantHeader), isTrue);
      });

      test('handles different metadata block types after signature', () {
        // Test with different first metadata block types
        final blockTypes = [
          0x00, // STREAMINFO (most common)
          0x01, // PADDING
          0x02, // APPLICATION
          0x03, // SEEKTABLE
          0x04, // VORBIS_COMMENT
          0x05, // CUESHEET
          0x06, // PICTURE
        ];

        for (final blockType in blockTypes) {
          final testData = Uint8List.fromList([
            0x66, 0x4C, 0x61, 0x43, // "fLaC"
            blockType, // Block type
            0x00, 0x00, 0x10, // Block size
            ...List.filled(16, 0x00), // Block data
          ]);
          expect(strategy.canHandle(testData), isTrue, reason: 'Should handle FLAC file with first block type $blockType');
        }
      });

      test('handles last metadata block flag variations', () {
        // Test with last block flag set and unset
        final withLastFlag = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x80, // Last block flag set (bit 7) + STREAMINFO (0)
          0x00, 0x00, 0x22, // Block size
        ]);
        expect(strategy.canHandle(withLastFlag), isTrue);

        final withoutLastFlag = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x00, // Last block flag not set + STREAMINFO (0)
          0x00, 0x00, 0x22, // Block size
        ]);
        expect(strategy.canHandle(withoutLastFlag), isTrue);
      });
    });
  });
}
