import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';

void main() {
  group('Mp3FormatStrategy', () {
    late Mp3FormatStrategy strategy;

    setUp(() {
      strategy = const Mp3FormatStrategy();
    });

    group('basic properties', () {
      test('returns correct media kind', () {
        expect(strategy.mediaKind, equals(MediaKind.mp3));
      });

      test('returns correct precedence order', () {
        expect(
          strategy.precedence,
          equals([
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v2, '2.3'),
            (ContainerKind.id3v2, '2.2'),
            (ContainerKind.id3v1, 'v1'),
          ]),
        );
      });

      test('returns correct fanout targets', () {
        expect(
          strategy.fanout,
          equals([
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v1, 'v1'),
          ]),
        );
      });
    });

    group('canHandle', () {
      test('returns false for empty data', () {
        expect(strategy.canHandle(Uint8List(0)), isFalse);
      });

      test('returns false for insufficient data', () {
        expect(strategy.canHandle(Uint8List.fromList([0x49, 0x44])), isFalse);
      });

      test('detects ID3v2 header signature', () {
        final id3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size (synchsafe)
        ]);
        expect(strategy.canHandle(id3Header), isTrue);
      });

      test('detects ID3v2.3 header', () {
        final id3v23Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x03, 0x00, // Version 2.3
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size
        ]);
        expect(strategy.canHandle(id3v23Header), isTrue);
      });

      test('detects ID3v2.2 header', () {
        final id3v22Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x02, 0x00, // Version 2.2
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size
        ]);
        expect(strategy.canHandle(id3v22Header), isTrue);
      });

      test('rejects invalid ID3 signature', () {
        final invalidHeader = Uint8List.fromList([
          0x49, 0x44, 0x32, // "ID2" - invalid
          0x04, 0x00,
          0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('detects valid MP3 frame sync - MPEG 1 Layer III', () {
        final mp3Frame = Uint8List.fromList([
          0xFF, 0xFB, // Frame sync + MPEG 1 Layer III
          0x90, 0x00, // Valid bitrate and sampling rate
          // Additional bytes...
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(mp3Frame), isTrue);
      });

      test('detects valid MP3 frame sync - MPEG 2 Layer III', () {
        final mp3Frame = Uint8List.fromList([
          0xFF, 0xF3, // Frame sync + MPEG 2 Layer III
          0x44, 0x00, // Valid bitrate and sampling rate
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(mp3Frame), isTrue);
      });

      test('detects MP3 frame sync after initial bytes', () {
        final dataWithMp3Frame = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x00, // Some initial data
          0xFF, 0xFB, 0x90, 0x00, // Valid MP3 frame
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(dataWithMp3Frame), isTrue);
      });

      test('rejects invalid frame sync patterns', () {
        final invalidSync = Uint8List.fromList([
          0xFF, 0xE0, // Invalid - reserved version
          0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(invalidSync), isFalse);
      });

      test('rejects frame with reserved layer', () {
        final reservedLayer = Uint8List.fromList([
          0xFF, 0xF0, // Frame sync + reserved layer (00)
          0x90, 0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(reservedLayer), isFalse);
      });

      test('rejects frame with invalid bitrate', () {
        final invalidBitrate = Uint8List.fromList([
          0xFF, 0xFB, // Valid sync + version + layer
          0x00, 0x00, // Bitrate index 0 (invalid)
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(invalidBitrate), isFalse);
      });

      test('rejects frame with reserved sampling rate', () {
        final reservedSamplingRate = Uint8List.fromList([
          0xFF, 0xFB, // Valid sync + version + layer
          0x9C, 0x00, // Valid bitrate + reserved sampling rate (11)
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(reservedSamplingRate), isFalse);
      });

      test('handles file with both ID3 and MP3 frames', () {
        final id3AndMp3 = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          // ... ID3 data would be here ...
          0xFF, 0xFB, 0x90, 0x00, // MP3 frame
        ]);
        expect(strategy.canHandle(id3AndMp3), isTrue);
      });

      test('rejects completely unrelated data', () {
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

      test('handles large files efficiently', () {
        // Create a large buffer with MP3 frame near the end of search window
        final largeBuffer = Uint8List(10000);
        // Place valid MP3 frame at position 8000 (within 8KB search limit)
        largeBuffer[8000] = 0xFF;
        largeBuffer[8001] = 0xFB;
        largeBuffer[8002] = 0x90;
        largeBuffer[8003] = 0x00;

        expect(strategy.canHandle(largeBuffer), isTrue);
      });

      test('stops searching beyond 8KB limit', () {
        // Create a large buffer with MP3 frame beyond 8KB search limit
        final largeBuffer = Uint8List(20000);
        // Place valid MP3 frame at position 10000 (beyond 8KB search limit)
        largeBuffer[10000] = 0xFF;
        largeBuffer[10001] = 0xFB;
        largeBuffer[10002] = 0x90;
        largeBuffer[10003] = 0x00;

        expect(strategy.canHandle(largeBuffer), isFalse);
      });
    });

    group('detectFormat', () {
      test('returns MP3 media kind for valid ID3 file', () {
        final id3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.detectFormat(id3Header), equals(MediaKind.mp3));
      });

      test('returns MP3 media kind for valid MP3 frame', () {
        final mp3Frame = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
        ]);
        expect(strategy.detectFormat(mp3Frame), equals(MediaKind.mp3));
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
              equals('Mp3FormatStrategy.detectFormat'),
            ),
          ),
        );
      });
    });

    group('MP3 frame validation edge cases', () {
      test('validates different MPEG versions', () {
        // MPEG 1
        final mpeg1 = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        expect(strategy.canHandle(mpeg1), isTrue);

        // MPEG 2
        final mpeg2 = Uint8List.fromList([0xFF, 0xF3, 0x44, 0x00]);
        expect(strategy.canHandle(mpeg2), isTrue);

        // MPEG 2.5
        final mpeg25 = Uint8List.fromList([0xFF, 0xE3, 0x44, 0x00]);
        expect(strategy.canHandle(mpeg25), isTrue);
      });

      test('validates different layers', () {
        // Layer III (most common for MP3)
        final layer3 = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        expect(strategy.canHandle(layer3), isTrue);

        // Layer II
        final layer2 = Uint8List.fromList([0xFF, 0xFD, 0x90, 0x00]);
        expect(strategy.canHandle(layer2), isTrue);

        // Layer I
        final layer1 = Uint8List.fromList([0xFF, 0xFF, 0x90, 0x00]);
        expect(strategy.canHandle(layer1), isTrue);
      });

      test('validates different bitrates', () {
        // Test various valid bitrate indices (1-14)
        for (int bitrate = 1; bitrate <= 14; bitrate++) {
          final frame = Uint8List.fromList([
            0xFF, 0xFB,
            (bitrate << 4) | 0x04, // Bitrate in upper 4 bits + valid sampling rate
            0x00,
          ]);
          expect(strategy.canHandle(frame), isTrue, reason: 'Bitrate index $bitrate should be valid');
        }
      });

      test('validates different sampling rates', () {
        // Test valid sampling rate indices (0-2)
        for (int samplingRate = 0; samplingRate <= 2; samplingRate++) {
          final frame = Uint8List.fromList([
            0xFF, 0xFB,
            0x90 | (samplingRate << 2), // Valid bitrate + sampling rate
            0x00,
          ]);
          expect(strategy.canHandle(frame), isTrue, reason: 'Sampling rate index $samplingRate should be valid');
        }
      });

      test('handles padding and other flags', () {
        // Frame with padding bit set
        final withPadding = Uint8List.fromList([0xFF, 0xFB, 0x92, 0x00]);
        expect(strategy.canHandle(withPadding), isTrue);

        // Frame with private bit set
        final withPrivate = Uint8List.fromList([0xFF, 0xFB, 0x91, 0x00]);
        expect(strategy.canHandle(withPrivate), isTrue);

        // Frame with copyright bit set
        final withCopyright = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x08]);
        expect(strategy.canHandle(withCopyright), isTrue);

        // Frame with original bit set
        final withOriginal = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x04]);
        expect(strategy.canHandle(withOriginal), isTrue);
      });
    });

    group('performance and edge cases', () {
      test('handles minimum valid file size', () {
        final minimalMp3 = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        expect(strategy.canHandle(minimalMp3), isTrue);
      });

      test('handles files with trailing data', () {
        final mp3WithTrailing = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // Valid MP3 frame
          // Followed by lots of data...
          ...List.filled(1000, 0x00),
        ]);
        expect(strategy.canHandle(mp3WithTrailing), isTrue);
      });

      test('is stateless and reusable', () {
        final testData = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

        // Multiple calls should return same result
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.detectFormat(testData), equals(MediaKind.mp3));
        expect(strategy.detectFormat(testData), equals(MediaKind.mp3));
      });

      test('const constructor creates identical instances', () {
        const strategy1 = Mp3FormatStrategy();
        const strategy2 = Mp3FormatStrategy();

        expect(strategy1.mediaKind, equals(strategy2.mediaKind));
        expect(strategy1.precedence, equals(strategy2.precedence));
        expect(strategy1.fanout, equals(strategy2.fanout));
      });
    });
  });
}
