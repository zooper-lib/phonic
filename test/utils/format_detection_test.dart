import 'dart:typed_data';

import 'package:phonic/src/utils/format_detection.dart';
import 'package:test/test.dart';

void main() {
  group('FormatDetection', () {
    group('MP3 Detection', () {
      test('detects MP3 with ID3v2 header', () {
        // Create MP3 file with ID3v2 header
        final mp3WithId3v2 = Uint8List.fromList([
          // ID3v2 header: "ID3" + version + flags + size
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size (synchsafe)
          // Some additional data
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(FormatDetection.isMp3(mp3WithId3v2), isTrue);
      });

      test('detects MP3 with frame sync pattern', () {
        // Create MP3 file with valid frame sync
        final mp3WithFrameSync = Uint8List.fromList([
          // MP3 frame header with sync pattern
          0xFF, 0xFB, // Frame sync + version/layer/protection
          0x90, 0x00, // Bitrate/sampling/padding/private/mode/mode_ext/copyright/original/emphasis
          // Some additional frame data
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(FormatDetection.isMp3(mp3WithFrameSync), isTrue);
      });

      test('rejects non-MP3 data', () {
        final nonMp3Data = Uint8List.fromList([
          0x00,
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
        ]);

        expect(FormatDetection.isMp3(nonMp3Data), isFalse);
      });

      test('rejects insufficient data', () {
        final shortData = Uint8List.fromList([0x49, 0x44]); // Too short

        expect(FormatDetection.isMp3(shortData), isFalse);
      });

      test('rejects invalid MP3 frame header', () {
        // Invalid frame header (reserved version)
        // 0xFF 0xE2 = 11111111 11100010
        // Sync: 11111111 111 (OK)
        // Version: 00 (MPEG Version 2.5, valid)
        // Layer: 01 (Layer III, valid)
        // Protection: 0 (CRC, valid)
        // Let's use a truly invalid header with reserved version (01)
        final invalidMp3 = Uint8List.fromList([
          0xFF, 0xEA, // Frame sync with reserved version (01): 11111111 11101010
          0x90, 0x00,
        ]);

        expect(FormatDetection.isMp3(invalidMp3), isFalse);
      });

      test('detects MP3 frame sync in middle of file', () {
        // MP3 frame sync not at the beginning
        final mp3WithOffset = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x00, // Some padding
          0xFF, 0xFB, 0x90, 0x00, // Valid MP3 frame
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(FormatDetection.isMp3(mp3WithOffset), isTrue);
      });
    });

    group('FLAC Detection', () {
      test('detects FLAC with correct signature', () {
        final flacData = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x00, 0x00, 0x00, 0x22, // Metadata block header
          // Additional FLAC data
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(FormatDetection.isFlac(flacData), isTrue);
      });

      test('rejects non-FLAC data', () {
        final nonFlacData = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x44, // "fLaD" (incorrect)
          0x00, 0x00, 0x00, 0x22,
        ]);

        expect(FormatDetection.isFlac(nonFlacData), isFalse);
      });

      test('rejects insufficient data', () {
        final shortData = Uint8List.fromList([0x66, 0x4C]); // Too short

        expect(FormatDetection.isFlac(shortData), isFalse);
      });
    });

    group('OGG Detection', () {
      test('detects OGG with correct signature', () {
        final oggData = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version
          0x02, // Header type
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x00, 0x00, 0x00, 0x00, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0x01, // Page segments
          0x1E, // Segment length
          // Vorbis identification header
          0x01, // Packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
        ]);

        expect(FormatDetection.isOgg(oggData), isTrue);
      });

      test('detects OGG Vorbis specifically', () {
        final oggVorbisData = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version
          0x02, // Header type
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x00, 0x00, 0x00, 0x00, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0x01, // Page segments
          0x1E, // Segment length
          // Vorbis identification header
          0x01, // Packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
          0x00, 0x00, 0x00, 0x00, // Version
          0x02, // Channels
          0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
        ]);

        expect(FormatDetection.isOgg(oggVorbisData), isTrue);
        expect(FormatDetection.isOggVorbis(oggVorbisData), isTrue);
      });

      test('detects Opus specifically', () {
        final opusData = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, // Version
          0x02, // Header type
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x00, 0x00, 0x00, 0x00, // Serial number
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x00, 0x00, 0x00, 0x00, // Checksum
          0x01, // Page segments
          0x13, // Segment length
          // Opus identification header
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
          0x01, // Version
          0x02, // Channel count
          0x00, 0x0F, // Pre-skip
          0x80, 0xBB, 0x00, 0x00, // Sample rate
        ]);

        expect(FormatDetection.isOgg(opusData), isTrue);
        expect(FormatDetection.isOpus(opusData), isTrue);
      });

      test('rejects non-OGG data', () {
        final nonOggData = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x54, // "OggT" (incorrect)
          0x00, 0x02,
        ]);

        expect(FormatDetection.isOgg(nonOggData), isFalse);
      });

      test('rejects insufficient data', () {
        final shortData = Uint8List.fromList([0x4F, 0x67]); // Too short

        expect(FormatDetection.isOgg(shortData), isFalse);
      });

      test('rejects OGG without Vorbis header for isOggVorbis', () {
        final oggWithoutVorbis = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x06,
          0x01, // Wrong packet type
          0x6F, 0x74, 0x68, 0x65, 0x72, // "other"
        ]);

        expect(FormatDetection.isOgg(oggWithoutVorbis), isTrue);
        expect(FormatDetection.isOggVorbis(oggWithoutVorbis), isFalse);
      });

      test('rejects OGG without Opus header for isOpus', () {
        final oggWithoutOpus = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x08,
          0x4F, 0x74, 0x68, 0x65, 0x72, 0x48, 0x64, 0x72, // "OtherHdr"
        ]);

        expect(FormatDetection.isOgg(oggWithoutOpus), isTrue);
        expect(FormatDetection.isOpus(oggWithoutOpus), isFalse);
      });
    });

    group('MP4 Detection', () {
      test('detects MP4 with ftyp box', () {
        final mp4Data = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand "isom"
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand "isom"
          0x69, 0x73, 0x6F, 0x32, // Compatible brand "iso2"
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
          0x6D, 0x70, 0x34, 0x32, // Compatible brand "mp42"
        ]);

        expect(FormatDetection.isMp4(mp4Data), isTrue);
      });

      test('detects M4A specifically', () {
        final m4aData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x4D, 0x34, 0x41, 0x20, // Major brand "M4A "
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x4D, 0x34, 0x41, 0x20, // Compatible brand "M4A "
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand "isom"
          0x00, 0x00, 0x00, 0x00, // Padding
        ]);

        expect(FormatDetection.isMp4(m4aData), isTrue);
        expect(FormatDetection.isM4a(m4aData), isTrue);
      });

      test('detects M4A by compatible brand', () {
        final m4aByCompatible = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand "isom"
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x4D, 0x34, 0x41, 0x20, // Compatible brand "M4A " (indicates audio)
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
          0x69, 0x73, 0x6F, 0x32, // Compatible brand "iso2"
          0x00, 0x00, 0x00, 0x00, // Padding
        ]);

        expect(FormatDetection.isMp4(m4aByCompatible), isTrue);
        expect(FormatDetection.isM4a(m4aByCompatible), isTrue);
      });

      test('rejects MP4 without M4A brands for isM4a', () {
        final mp4VideoOnly = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x1C, // Box size (28 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand "isom"
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x32, // Compatible brand "iso2"
          0x61, 0x76, 0x63, 0x31, // Compatible brand "avc1" (video)
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
        ]);

        expect(FormatDetection.isMp4(mp4VideoOnly), isTrue);
        expect(FormatDetection.isM4a(mp4VideoOnly), isFalse);
      });

      test('rejects non-MP4 data', () {
        final nonMp4Data = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x66, 0x74, 0x79, 0x71, // "ftyq" (incorrect)
          0x69, 0x73, 0x6F, 0x6D,
        ]);

        expect(FormatDetection.isMp4(nonMp4Data), isFalse);
      });

      test('rejects insufficient data', () {
        final shortData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x66, 0x74, // Too short
        ]);

        expect(FormatDetection.isMp4(shortData), isFalse);
      });

      test('handles malformed ftyp box gracefully', () {
        final malformedMp4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x08, // Box size too small
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          // Missing required data
        ]);

        expect(FormatDetection.isMp4(malformedMp4), isFalse);
        expect(FormatDetection.isM4a(malformedMp4), isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles empty data', () {
        final emptyData = Uint8List(0);

        expect(FormatDetection.isMp3(emptyData), isFalse);
        expect(FormatDetection.isFlac(emptyData), isFalse);
        expect(FormatDetection.isOgg(emptyData), isFalse);
        expect(FormatDetection.isMp4(emptyData), isFalse);
        expect(FormatDetection.isM4a(emptyData), isFalse);
      });

      test('handles single byte data', () {
        final singleByte = Uint8List.fromList([0xFF]);

        expect(FormatDetection.isMp3(singleByte), isFalse);
        expect(FormatDetection.isFlac(singleByte), isFalse);
        expect(FormatDetection.isOgg(singleByte), isFalse);
        expect(FormatDetection.isMp4(singleByte), isFalse);
        expect(FormatDetection.isM4a(singleByte), isFalse);
      });

      test('handles corrupted data gracefully', () {
        final corruptedData = Uint8List.fromList([
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
        ]);

        // Should not crash, just return false
        expect(FormatDetection.isMp3(corruptedData), isFalse);
        expect(FormatDetection.isFlac(corruptedData), isFalse);
        expect(FormatDetection.isOgg(corruptedData), isFalse);
        expect(FormatDetection.isMp4(corruptedData), isFalse);
        expect(FormatDetection.isM4a(corruptedData), isFalse);
      });

      test('handles large data efficiently', () {
        // Create a large buffer with MP3 signature at the beginning
        final largeData = Uint8List(1024 * 1024); // 1MB
        largeData.setRange(0, 3, [0x49, 0x44, 0x33]); // "ID3"

        // Should detect quickly without processing entire buffer
        expect(FormatDetection.isMp3(largeData), isTrue);
      });
    });

    group('Format Precedence', () {
      test('MP3 detection prioritizes ID3v2 over frame sync', () {
        // File with both ID3v2 header and frame sync later
        final mp3WithBoth = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" header
          0x04, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x10,
          // Some ID3v2 data
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          // MP3 frame sync later in file
          0xFF, 0xFB, 0x90, 0x00,
        ]);

        expect(FormatDetection.isMp3(mp3WithBoth), isTrue);
      });

      test('OGG detection works for both Vorbis and Opus', () {
        // Both should be detected as OGG containers
        final oggVorbis = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          // ... (abbreviated for brevity)
        ]);

        final oggOpus = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          // ... (abbreviated for brevity)
        ]);

        expect(FormatDetection.isOgg(oggVorbis), isTrue);
        expect(FormatDetection.isOgg(oggOpus), isTrue);
      });
    });
  });
}
