import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/formats/vorbis/ogg_format_strategy.dart';

void main() {
  group('OggFormatStrategy', () {
    late OggFormatStrategy strategy;

    setUp(() {
      strategy = const OggFormatStrategy();
    });

    group('basic properties', () {
      test('returns correct media kind', () {
        expect(strategy.mediaKind, equals(MediaKind.ogg));
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
        expect(strategy.canHandle(Uint8List.fromList([0x4F, 0x67])), isFalse);
      });

      test('returns false for insufficient data for Vorbis check', () {
        final shortOggHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, // Version
          0x02, // Header type (first page of logical bitstream)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x01, 0x02, 0x03, 0x04, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0x01, // Number of segments
          0x1E, // Segment length (30 bytes)
          // But not enough data for Vorbis identification
        ]);
        expect(strategy.canHandle(shortOggHeader), isFalse);
      });

      test('detects OGG Vorbis signature and codec', () {
        final oggVorbisHeader = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, // Stream structure version
          0x02, // Header type flag (first page of logical bitstream)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x01, 0x02, 0x03, 0x04, // Stream serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence number
          0x00, 0x00, 0x00, 0x00, // Page checksum
          0x01, // Number of page segments
          0x1E, // Segment table (30 bytes in first segment)
          // Vorbis identification header
          0x01, // Packet type (identification)
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
          0x00, 0x00, 0x00, 0x00, // Vorbis version
          0x02, // Audio channels
          0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
          0x00, 0x00, 0x00, 0x00, // Bitrate maximum
          0x00, 0xEE, 0x02, 0x00, // Bitrate nominal (192000)
          0x00, 0x00, 0x00, 0x00, // Bitrate minimum
          0xB0, // Blocksize 0 and 1
          0x01, // Framing flag
        ]);
        expect(strategy.canHandle(oggVorbisHeader), isTrue);
      });

      test('detects minimal valid OGG Vorbis header', () {
        final minimalOggVorbis = Uint8List.fromList([
          // OGG page header (27 bytes)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version + header type
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x00, 0x00, 0x00, 0x00, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0x01, // Number of segments
          0x07, // Segment length (7 bytes for minimal Vorbis header)
          // Minimal Vorbis identification
          0x01, // Packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
        ]);
        expect(strategy.canHandle(minimalOggVorbis), isTrue);
      });

      test('rejects invalid OGG signature - wrong first byte', () {
        final invalidHeader = Uint8List.fromList([
          0x50, 0x67, 0x67, 0x53, // "PggS" - invalid first byte
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid OGG signature - wrong second byte', () {
        final invalidHeader = Uint8List.fromList([
          0x4F, 0x68, 0x67, 0x53, // "OhgS" - invalid second byte
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid OGG signature - wrong third byte', () {
        final invalidHeader = Uint8List.fromList([
          0x4F, 0x67, 0x68, 0x53, // "OghS" - invalid third byte
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid OGG signature - wrong fourth byte', () {
        final invalidHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x54, // "OggT" - invalid fourth byte
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects OGG with non-Vorbis codec (Opus)', () {
        final oggOpusHeader = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x13, // 19 bytes in segment
          // OpusHead header (not Vorbis)
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
          0x01, // Version
          0x02, // Channel count
          0x00, 0x00, // Pre-skip
          0x80, 0xBB, 0x00, 0x00, // Sample rate
          0x00, 0x00, // Output gain
          0x00, // Channel mapping family
        ]);
        expect(strategy.canHandle(oggOpusHeader), isFalse);
      });

      test('rejects OGG with invalid Vorbis packet type', () {
        final oggInvalidVorbis = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          // Invalid packet type (should be 0x01 for identification)
          0x02, // Wrong packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
        ]);
        expect(strategy.canHandle(oggInvalidVorbis), isFalse);
      });

      test('rejects OGG with invalid Vorbis string', () {
        final oggInvalidVorbisString = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, // Correct packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x78, // "vorbix" - invalid string
        ]);
        expect(strategy.canHandle(oggInvalidVorbisString), isFalse);
      });

      test('rejects completely different signature', () {
        final flacHeader = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" - FLAC signature
          0x00, 0x00, 0x00, 0x22,
        ]);
        expect(strategy.canHandle(flacHeader), isFalse);
      });

      test('rejects MP3 ID3 signature', () {
        final mp3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, 0x04, // "ID3" + version - MP3 ID3v2 header
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(mp3Header), isFalse);
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

      test('handles OGG with multiple segments', () {
        final oggMultiSegment = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x02, // Two segments
          0x07, 0x10, // Segment lengths: 7 and 16 bytes
          // First segment - Vorbis identification
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
          // Second segment - additional data
          0x00, 0x00, 0x00, 0x00, 0x02, 0x44, 0xAC, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEE, 0x02,
        ]);
        expect(strategy.canHandle(oggMultiSegment), isTrue);
      });

      test('handles parsing errors gracefully', () {
        // Create a malformed OGG header that might cause parsing errors
        final malformedOgg = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // Valid OGG signature
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0xFF, // Invalid number of segments (255)
          // Not enough data for 255 segments
        ]);
        expect(strategy.canHandle(malformedOgg), isFalse);
      });
    });

    group('detectFormat', () {
      test('returns OGG media kind for valid OGG Vorbis file', () {
        final oggVorbisHeader = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          // Vorbis identification
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.detectFormat(oggVorbisHeader), equals(MediaKind.ogg));
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

      test('throws UnsupportedFormatException for OGG without Vorbis', () {
        final oggWithoutVorbis = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // Valid OGG signature
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x08,
          // OpusHead instead of Vorbis
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64,
        ]);

        expect(
          () => strategy.detectFormat(oggWithoutVorbis),
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
              equals('OggFormatStrategy.detectFormat'),
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
              equals('File does not appear to be a valid OGG Vorbis format'),
            ),
          ),
        );
      });
    });

    group('OGG signature validation edge cases', () {
      test('validates exact byte values for OGG signature', () {
        // Test each byte of the signature individually
        final correctSignature = [0x4F, 0x67, 0x67, 0x53];

        for (int i = 0; i < 4; i++) {
          // Test with one byte changed
          final modifiedSignature = List<int>.from(correctSignature);
          modifiedSignature[i] = modifiedSignature[i] ^ 0x01; // Flip one bit

          final testData = Uint8List.fromList([
            ...modifiedSignature,
            0x00,
            0x02,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x01,
            0x07,
            0x01,
            0x76,
            0x6F,
            0x72,
            0x62,
            0x69,
            0x73,
          ]);

          expect(strategy.canHandle(testData), isFalse, reason: 'Modified byte $i should make signature invalid');
        }
      });

      test('handles case sensitivity correctly', () {
        // OGG signature is case-sensitive
        final lowercaseO = Uint8List.fromList([
          0x6F, 0x67, 0x67, 0x53, // "oggS" - lowercase 'o'
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(lowercaseO), isFalse);

        final lowercaseS = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x73, // "Oggs" - lowercase 's'
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(lowercaseS), isFalse);
      });

      test('handles truncated signatures', () {
        // Test with 1, 2, and 3 bytes of signature
        expect(strategy.canHandle(Uint8List.fromList([0x4F])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x4F, 0x67])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x4F, 0x67, 0x67])), isFalse);
      });

      test('validates Vorbis string case sensitivity', () {
        final wrongCaseVorbis = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // Valid OGG signature
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x56, 0x4F, 0x52, 0x42, 0x49, 0x53, // "VORBIS" - uppercase
        ]);
        expect(strategy.canHandle(wrongCaseVorbis), isFalse);
      });
    });

    group('performance and edge cases', () {
      test('handles minimum valid file size', () {
        final minimalOggVorbis = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(minimalOggVorbis), isTrue);
      });

      test('handles large OGG files efficiently', () {
        final largeOggFile = Uint8List(100000);
        // Set OGG Vorbis header at the beginning
        final header = [
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ];
        for (int i = 0; i < header.length; i++) {
          largeOggFile[i] = header[i];
        }

        expect(strategy.canHandle(largeOggFile), isTrue);
      });

      test('is stateless and reusable', () {
        final testData = Uint8List.fromList([
          0x4F,
          0x67,
          0x67,
          0x53,
          0x00,
          0x02,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x01,
          0x07,
          0x01,
          0x76,
          0x6F,
          0x72,
          0x62,
          0x69,
          0x73,
        ]);

        // Multiple calls should return same result
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.detectFormat(testData), equals(MediaKind.ogg));
        expect(strategy.detectFormat(testData), equals(MediaKind.ogg));
      });

      test('const constructor creates identical instances', () {
        const strategy1 = OggFormatStrategy();
        const strategy2 = OggFormatStrategy();

        expect(strategy1.mediaKind, equals(strategy2.mediaKind));
        expect(strategy1.precedence, equals(strategy2.precedence));
        expect(strategy1.fanout, equals(strategy2.fanout));
      });

      test('handles files with trailing data', () {
        final oggWithTrailing = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // OGG signature
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
          // Followed by lots of data...
          ...List.filled(1000, 0x00),
        ]);
        expect(strategy.canHandle(oggWithTrailing), isTrue);
      });

      test('differentiates from similar signatures', () {
        // Test signatures that start with 'O' but are not OGG
        final fakeSignatures = [
          [0x4F, 0x67, 0x67, 0x54], // "OggT"
          [0x4F, 0x67, 0x68, 0x53], // "OghS"
          [0x4F, 0x68, 0x67, 0x53], // "OhgS"
          [0x50, 0x67, 0x67, 0x53], // "PggS"
        ];

        for (final signature in fakeSignatures) {
          final testData = Uint8List.fromList([
            ...signature,
            0x00,
            0x02,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x01,
            0x07,
            0x01,
            0x76,
            0x6F,
            0x72,
            0x62,
            0x69,
            0x73,
          ]);
          expect(
            strategy.canHandle(testData),
            isFalse,
            reason: 'Signature ${signature.map((b) => b.toRadixString(16)).join(' ')} should not be detected as OGG',
          );
        }
      });
    });

    group('integration with OGG specification', () {
      test('validates against OGG specification requirements', () {
        // According to RFC 3533, OGG signature must be exactly "OggS"
        final specCompliantHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" as per RFC 3533
          0x00, // Stream structure version (must be 0)
          0x02, // Header type flag (first page of logical bitstream)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x12, 0x34, 0x56, 0x78, // Stream serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence number
          0x00, 0x00, 0x00, 0x00, // Page checksum
          0x01, // Number of page segments
          0x07, // Segment table
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // Vorbis identification
        ]);
        expect(strategy.canHandle(specCompliantHeader), isTrue);
      });

      test('handles different OGG page types', () {
        // Test with different header type flags
        final pageTypes = [
          0x00, // Continuation of packet
          0x01, // Fresh packet
          0x02, // First page of logical bitstream (BOS)
          0x04, // Last page of logical bitstream (EOS)
          0x06, // First and last page (BOS + EOS)
        ];

        for (final pageType in pageTypes) {
          final testData = Uint8List.fromList([
            0x4F, 0x67, 0x67, 0x53, // "OggS"
            0x00, // Version
            pageType, // Header type flag
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x01, 0x07,
            0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
          ]);
          expect(strategy.canHandle(testData), isTrue, reason: 'Should handle OGG page with header type $pageType');
        }
      });

      test('validates stream structure version', () {
        // OGG specification requires version to be 0
        final validVersion = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version 0 (required by spec)
          0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(validVersion), isTrue);

        // Test with invalid version (should still work as we don't validate version strictly)
        final invalidVersion = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x01, // Version 1 (not per spec, but we're lenient)
          0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x07,
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73,
        ]);
        expect(strategy.canHandle(invalidVersion), isTrue);
      });
    });
  });
}
