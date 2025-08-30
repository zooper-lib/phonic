import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/formats/mp4/mp4_format_strategy.dart';

void main() {
  group('Mp4FormatStrategy', () {
    late Mp4FormatStrategy strategy;

    setUp(() {
      strategy = const Mp4FormatStrategy();
    });

    group('basic properties', () {
      test('returns correct media kind', () {
        expect(strategy.mediaKind, equals(MediaKind.mp4));
      });

      test('returns correct precedence order', () {
        expect(
          strategy.precedence,
          equals([
            (ContainerKind.mp4, ''),
          ]),
        );
      });

      test('returns correct fanout targets', () {
        expect(
          strategy.fanout,
          equals([
            (ContainerKind.mp4, ''),
          ]),
        );
      });
    });

    group('canHandle', () {
      test('returns false for empty data', () {
        expect(strategy.canHandle(Uint8List(0)), isFalse);
      });

      test('returns false for insufficient data', () {
        expect(strategy.canHandle(Uint8List.fromList([0x00, 0x00])), isFalse);
      });

      test('returns false for insufficient data for ftyp check', () {
        final shortHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // "ftyp" signature
          // But not enough data for brands
        ]);
        expect(strategy.canHandle(shortHeader), isFalse);
      });

      test('detects MP4 ftyp signature with M4A brand', () {
        final m4aHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp" box type
          0x4D, 0x34, 0x41, 0x20, // Major brand: "M4A "
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x4D, 0x34, 0x41, 0x20, // Compatible brand: "M4A "
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
          0x00, 0x00, 0x00, 0x00, // Padding
        ]);
        expect(strategy.canHandle(m4aHeader), isTrue);
      });

      test('detects MP4 ftyp signature with mp41 brand', () {
        final mp4Header = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp" box type
          0x6D, 0x70, 0x34, 0x31, // Major brand: "mp41"
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
        ]);
        expect(strategy.canHandle(mp4Header), isTrue);
      });

      test('detects MP4 ftyp signature with isom brand', () {
        final isomHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x14, // Box size (20 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp" box type
          0x69, 0x73, 0x6F, 0x6D, // Major brand: "isom"
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
        ]);
        expect(strategy.canHandle(isomHeader), isTrue);
      });

      test('detects minimal valid MP4 header', () {
        final minimalMp4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // Box size (16 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp" box type
          0x6D, 0x70, 0x34, 0x31, // Major brand: "mp41"
          0x00, 0x00, 0x00, 0x00, // Minor version
        ]);
        expect(strategy.canHandle(minimalMp4), isTrue);
      });

      test('rejects invalid ftyp signature - wrong first byte', () {
        final invalidHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x67, 0x74, 0x79, 0x70, // "gtyp" - invalid first byte
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid ftyp signature - wrong second byte', () {
        final invalidHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x75, 0x79, 0x70, // "fuyp" - invalid second byte
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid ftyp signature - wrong third byte', () {
        final invalidHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x7A, 0x70, // "ftzp" - invalid third byte
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects invalid ftyp signature - wrong fourth byte', () {
        final invalidHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x71, // "ftyq" - invalid fourth byte
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(invalidHeader), isFalse);
      });

      test('rejects MP4 with unknown brands', () {
        final unknownBrandHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x14, // Box size (20 bytes)
          0x66, 0x74, 0x79, 0x70, // Valid "ftyp"
          0x58, 0x58, 0x58, 0x58, // Unknown major brand: "XXXX"
          0x00, 0x00, 0x00, 0x00,
          0x59, 0x59, 0x59, 0x59, // Unknown compatible brand: "YYYY"
        ]);
        expect(strategy.canHandle(unknownBrandHeader), isFalse);
      });

      test('rejects invalid box size - too small', () {
        final invalidSizeHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x0F, // Box size too small (15 bytes, minimum is 16)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(invalidSizeHeader), isFalse);
      });

      test('rejects invalid box size - larger than available data', () {
        final invalidSizeHeader = Uint8List.fromList([
          0x00, 0x00, 0x01, 0x00, // Box size 256 bytes, but only 20 bytes available
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(invalidSizeHeader), isFalse);
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

      test('rejects OGG signature', () {
        final oggHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" - OGG signature
          0x00, 0x02, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(oggHeader), isFalse);
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

      test('handles MP4 with multiple compatible brands', () {
        final multiCompatibleBrands = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x24, // Box size (36 bytes)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand: "isom"
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
          0x69, 0x73, 0x6F, 0x32, // Compatible brand: "iso2"
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
          0x6D, 0x70, 0x34, 0x32, // Compatible brand: "mp42"
          0x61, 0x76, 0x63, 0x31, // Compatible brand: "avc1"
        ]);
        expect(strategy.canHandle(multiCompatibleBrands), isTrue);
      });

      test('handles parsing errors gracefully', () {
        // Create a malformed MP4 header that might cause parsing errors
        final malformedMp4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // Valid box size (16 bytes)
          0x66, 0x74, 0x79, 0x70, // Valid ftyp signature
          0x4D, 0x34, 0x41, 0x20, // Valid major brand
          0x00, 0x00, 0x00, 0x00, // Minor version
          // But truncated compatible brands section
        ]);
        expect(strategy.canHandle(malformedMp4), isTrue); // Should still work with major brand
      });
    });

    group('detectFormat', () {
      test('returns M4A media kind for M4A files', () {
        final m4aHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20, // Major brand: "M4A "
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.detectFormat(m4aHeader), equals(MediaKind.m4a));
      });

      test('returns M4A media kind for M4B files', () {
        final m4bHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x42, 0x20, // Major brand: "M4B "
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x42, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.detectFormat(m4bHeader), equals(MediaKind.m4a));
      });

      test('returns M4A media kind for M4P files', () {
        final m4pHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x50, 0x20, // Major brand: "M4P "
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x50, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.detectFormat(m4pHeader), equals(MediaKind.m4a));
      });

      test('returns MP4 media kind for general MP4 files', () {
        final mp4Header = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x6D, 0x70, 0x34, 0x31, // Major brand: "mp41"
          0x00, 0x00, 0x00, 0x00,
          0x6D, 0x70, 0x34, 0x31,
          0x69, 0x73, 0x6F, 0x6D,
        ]);
        expect(strategy.detectFormat(mp4Header), equals(MediaKind.mp4));
      });

      test('returns M4A when M4A brand is in compatible brands', () {
        final mp4WithM4aCompat = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x1C, // Box size (28 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x69, 0x73, 0x6F, 0x6D, // Major brand: "isom"
          0x00, 0x00, 0x00, 0x00,
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
          0x4D, 0x34, 0x41, 0x20, // Compatible brand: "M4A " - should detect as M4A
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
        ]);
        expect(strategy.detectFormat(mp4WithM4aCompat), equals(MediaKind.m4a));
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

      test('throws UnsupportedFormatException for non-MP4 format', () {
        final flacData = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" signature
          0x00, 0x00, 0x00, 0x22,
        ]);

        expect(
          () => strategy.detectFormat(flacData),
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
              equals('Mp4FormatStrategy.detectFormat'),
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
              equals('File does not appear to be a valid MP4/M4A format'),
            ),
          ),
        );
      });
    });

    group('ftyp box validation edge cases', () {
      test('validates exact byte values for ftyp signature', () {
        // Test each byte of the signature individually
        final correctSignature = [0x66, 0x74, 0x79, 0x70];

        for (int i = 0; i < 4; i++) {
          // Test with one byte changed
          final modifiedSignature = List<int>.from(correctSignature);
          modifiedSignature[i] = modifiedSignature[i] ^ 0x01; // Flip one bit

          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x20, // Box size
            ...modifiedSignature,
            0x4D, 0x34, 0x41, 0x20, // M4A brand
            0x00, 0x00, 0x00, 0x00,
            0x4D, 0x34, 0x41, 0x20,
            0x6D, 0x70, 0x34, 0x31,
          ]);

          expect(strategy.canHandle(testData), isFalse, reason: 'Modified byte $i should make signature invalid');
        }
      });

      test('handles case sensitivity correctly', () {
        // ftyp signature is case-sensitive
        final uppercaseF = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x46, 0x74, 0x79, 0x70, // "Ftyp" - uppercase 'F'
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(uppercaseF), isFalse);

        final uppercaseP = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x66, 0x74, 0x79, 0x50, // "ftyP" - uppercase 'P'
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(uppercaseP), isFalse);
      });

      test('handles truncated signatures', () {
        // Test with 1, 2, and 3 bytes of signature
        expect(strategy.canHandle(Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74])), isFalse);
        expect(strategy.canHandle(Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79])), isFalse);
      });

      test('validates brand string case sensitivity', () {
        final wrongCaseBrand = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x66, 0x74, 0x79, 0x70, // Valid ftyp signature
          0x6D, 0x34, 0x61, 0x20, // "m4a " - lowercase (should be "M4A ")
          0x00, 0x00, 0x00, 0x00,
          0x6D, 0x34, 0x61, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);
        expect(strategy.canHandle(wrongCaseBrand), isFalse);
      });

      test('handles box size edge cases', () {
        // Test minimum valid box size (16 bytes)
        final minimalBox = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(minimalBox), isTrue);

        // Test box size exactly matching data length
        final exactSizeBox = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes (exact length)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(exactSizeBox), isTrue);
      });
    });

    group('brand detection comprehensive tests', () {
      test('recognizes all known MP4 brands', () {
        final knownBrands = [
          'M4A ', 'M4B ', 'M4P ', 'M4V ', // iTunes formats
          'mp41', 'mp42', 'mp71', // MPEG-4 versions
          'isom', 'iso2', // ISO Base Media
          'avc1', // H.264/AVC
          'qt  ', // QuickTime
          'dash', // DASH streaming
        ];

        for (final brand in knownBrands) {
          final brandBytes = brand.codeUnits;
          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x10, // 16 bytes
            0x66, 0x74, 0x79, 0x70,
            ...brandBytes, // Major brand
            0x00, 0x00, 0x00, 0x00,
          ]);

          expect(
            strategy.canHandle(testData),
            isTrue,
            reason: 'Should recognize brand "$brand"',
          );
        }
      });

      test('correctly identifies M4A-specific brands', () {
        final m4aBrands = ['M4A ', 'M4B ', 'M4P '];

        for (final brand in m4aBrands) {
          final brandBytes = brand.codeUnits;
          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x10, // 16 bytes
            0x66, 0x74, 0x79, 0x70,
            ...brandBytes,
            0x00, 0x00, 0x00, 0x00,
          ]);

          expect(
            strategy.detectFormat(testData),
            equals(MediaKind.m4a),
            reason: 'Brand "$brand" should be detected as M4A',
          );
        }
      });

      test('correctly identifies general MP4 brands', () {
        final mp4Brands = ['mp41', 'mp42', 'isom', 'avc1', 'qt  '];

        for (final brand in mp4Brands) {
          final brandBytes = brand.codeUnits;
          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x10, // 16 bytes
            0x66, 0x74, 0x79, 0x70,
            ...brandBytes,
            0x00, 0x00, 0x00, 0x00,
          ]);

          expect(
            strategy.detectFormat(testData),
            equals(MediaKind.mp4),
            reason: 'Brand "$brand" should be detected as MP4',
          );
        }
      });

      test('rejects unknown brands', () {
        final unknownBrands = ['UNKN', 'TEST', 'FAKE', 'XXXX'];

        for (final brand in unknownBrands) {
          final brandBytes = brand.codeUnits;
          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x14, // Box size (20 bytes)
            0x66, 0x74, 0x79, 0x70,
            ...brandBytes, // Unknown major brand
            0x00, 0x00, 0x00, 0x00,
            ...brandBytes, // Unknown compatible brand
          ]);

          expect(
            strategy.canHandle(testData),
            isFalse,
            reason: 'Should reject unknown brand "$brand"',
          );
        }
      });

      test('handles mixed known and unknown brands', () {
        final mixedBrands = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x1C, // Box size (28 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x55, 0x4E, 0x4B, 0x4E, // Unknown major brand: "UNKN"
          0x00, 0x00, 0x00, 0x00,
          0x55, 0x4E, 0x4B, 0x4E, // Unknown compatible brand: "UNKN"
          0x4D, 0x34, 0x41, 0x20, // Known compatible brand: "M4A "
          0x6D, 0x70, 0x34, 0x31, // Known compatible brand: "mp41"
        ]);
        expect(strategy.canHandle(mixedBrands), isTrue); // Should work due to known compatible brands
      });

      test('prioritizes M4A detection in compatible brands', () {
        final m4aInCompatible = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x1C, // Box size (28 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x6D, 0x70, 0x34, 0x31, // Major brand: "mp41" (general MP4)
          0x00, 0x00, 0x00, 0x00,
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
          0x4D, 0x34, 0x41, 0x20, // Compatible brand: "M4A " (should make it M4A)
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand: "isom"
        ]);
        expect(strategy.detectFormat(m4aInCompatible), equals(MediaKind.m4a));
      });
    });

    group('performance and edge cases', () {
      test('handles minimum valid file size', () {
        final minimalMp4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // Minimum box size (16 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(minimalMp4), isTrue);
      });

      test('handles large MP4 files efficiently', () {
        final largeMp4File = Uint8List(100000);
        // Set MP4 header at the beginning
        final header = [
          0x00,
          0x00,
          0x00,
          0x20,
          0x66,
          0x74,
          0x79,
          0x70,
          0x4D,
          0x34,
          0x41,
          0x20,
          0x00,
          0x00,
          0x00,
          0x00,
          0x4D,
          0x34,
          0x41,
          0x20,
          0x6D,
          0x70,
          0x34,
          0x31,
        ];
        for (int i = 0; i < header.length; i++) {
          largeMp4File[i] = header[i];
        }

        expect(strategy.canHandle(largeMp4File), isTrue);
      });

      test('is stateless and reusable', () {
        final testData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
        ]);

        // Multiple calls should return same result
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.canHandle(testData), isTrue);
        expect(strategy.detectFormat(testData), equals(MediaKind.m4a));
        expect(strategy.detectFormat(testData), equals(MediaKind.m4a));
      });

      test('const constructor creates identical instances', () {
        const strategy1 = Mp4FormatStrategy();
        const strategy2 = Mp4FormatStrategy();

        expect(strategy1.mediaKind, equals(strategy2.mediaKind));
        expect(strategy1.precedence, equals(strategy2.precedence));
        expect(strategy1.fanout, equals(strategy2.fanout));
      });

      test('handles files with trailing data', () {
        final mp4WithTrailing = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20,
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20,
          0x00, 0x00, 0x00, 0x00,
          0x4D, 0x34, 0x41, 0x20,
          0x6D, 0x70, 0x34, 0x31,
          // Followed by lots of data...
          ...List.filled(1000, 0x00),
        ]);
        expect(strategy.canHandle(mp4WithTrailing), isTrue);
      });

      test('differentiates from similar signatures', () {
        // Test signatures that start with similar bytes but are not MP4
        final fakeSignatures = [
          [0x66, 0x74, 0x79, 0x71], // "ftyq"
          [0x66, 0x74, 0x7A, 0x70], // "ftzp"
          [0x66, 0x75, 0x79, 0x70], // "fuyp"
          [0x67, 0x74, 0x79, 0x70], // "gtyp"
        ];

        for (final signature in fakeSignatures) {
          final testData = Uint8List.fromList([
            0x00,
            0x00,
            0x00,
            0x20,
            ...signature,
            0x4D,
            0x34,
            0x41,
            0x20,
            0x00,
            0x00,
            0x00,
            0x00,
            0x4D,
            0x34,
            0x41,
            0x20,
            0x6D,
            0x70,
            0x34,
            0x31,
          ]);
          expect(
            strategy.canHandle(testData),
            isFalse,
            reason: 'Signature ${signature.map((b) => b.toRadixString(16)).join(' ')} should not be detected as MP4',
          );
        }
      });

      test('handles zero-length compatible brands section', () {
        final noCompatibleBrands = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // Minimum size (no compatible brands)
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20, // Major brand only
          0x00, 0x00, 0x00, 0x00, // Minor version
        ]);
        expect(strategy.canHandle(noCompatibleBrands), isTrue);
      });

      test('handles odd number of compatible brand bytes gracefully', () {
        final oddBrandBytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x13, // 19 bytes (odd number after header)
          0x66, 0x74, 0x79, 0x70,
          0x69, 0x73, 0x6F, 0x6D, // Major brand: "isom"
          0x00, 0x00, 0x00, 0x00, // Minor version
          0x4D, 0x34, 0x41, // Incomplete compatible brand (only 3 bytes)
        ]);
        expect(strategy.canHandle(oddBrandBytes), isTrue); // Should work with major brand
      });
    });

    group('integration with MP4 specification', () {
      test('validates against MP4 specification requirements', () {
        // According to ISO/IEC 14496-12, ftyp box must be first box
        final specCompliantHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x1C, // Box size (28 bytes)
          0x66, 0x74, 0x79, 0x70, // Box type "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // Major brand "isom"
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand "isom"
          0x69, 0x73, 0x6F, 0x32, // Compatible brand "iso2"
          0x6D, 0x70, 0x34, 0x31, // Compatible brand "mp41"
        ]);
        expect(strategy.canHandle(specCompliantHeader), isTrue);
      });

      test('handles different minor versions', () {
        final versions = [0x00000000, 0x00000001, 0x00000200, 0x12345678];

        for (final version in versions) {
          final versionBytes = [
            (version >> 24) & 0xFF,
            (version >> 16) & 0xFF,
            (version >> 8) & 0xFF,
            version & 0xFF,
          ];

          final testData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x14, // Box size (20 bytes)
            0x66, 0x74, 0x79, 0x70,
            0x4D, 0x34, 0x41, 0x20, // Major brand
            ...versionBytes, // Minor version
            0x4D, 0x34, 0x41, 0x20, // Compatible brand
          ]);
          expect(strategy.canHandle(testData), isTrue, reason: 'Should handle minor version $version');
        }
      });

      test('validates box size calculation', () {
        // Test various valid box sizes
        final validSizes = [16, 20, 24, 28, 32, 64, 128];

        for (final size in validSizes) {
          final sizeBytes = [
            (size >> 24) & 0xFF,
            (size >> 16) & 0xFF,
            (size >> 8) & 0xFF,
            size & 0xFF,
          ];

          // Create data with exact size
          final testData = Uint8List(size);
          testData.setRange(0, 4, sizeBytes);
          testData.setRange(4, 8, [0x66, 0x74, 0x79, 0x70]); // ftyp
          testData.setRange(8, 12, [0x4D, 0x34, 0x41, 0x20]); // M4A brand
          testData.setRange(12, 16, [0x00, 0x00, 0x00, 0x00]); // Minor version

          expect(strategy.canHandle(testData), isTrue, reason: 'Should handle box size $size');
        }
      });

      test('handles QuickTime compatibility', () {
        final qtHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x14, // Box size (20 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x71, 0x74, 0x20, 0x20, // Major brand: "qt  " (QuickTime)
          0x00, 0x00, 0x00, 0x00,
          0x71, 0x74, 0x20, 0x20, // Compatible brand: "qt  "
        ]);
        expect(strategy.canHandle(qtHeader), isTrue);
        expect(strategy.detectFormat(qtHeader), equals(MediaKind.mp4));
      });

      test('handles DASH streaming format', () {
        final dashHeader = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // Box size (24 bytes)
          0x66, 0x74, 0x79, 0x70,
          0x64, 0x61, 0x73, 0x68, // Major brand: "dash"
          0x00, 0x00, 0x00, 0x00,
          0x64, 0x61, 0x73, 0x68, // Compatible brand: "dash"
          0x6D, 0x70, 0x34, 0x31, // Compatible brand: "mp41"
        ]);
        expect(strategy.canHandle(dashHeader), isTrue);
        expect(strategy.detectFormat(dashHeader), equals(MediaKind.mp4));
      });
    });

    group('brand string parsing edge cases', () {
      test('handles brands with spaces correctly', () {
        // Some brands like "M4A " have trailing spaces that are significant
        final brandWithSpace = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x20, // "M4A " with space
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(brandWithSpace), isTrue);
        expect(strategy.detectFormat(brandWithSpace), equals(MediaKind.m4a));

        // Same brand without space should not match
        final brandWithoutSpace = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes
          0x66, 0x74, 0x79, 0x70,
          0x4D, 0x34, 0x41, 0x00, // "M4A\0" without space
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(brandWithoutSpace), isFalse);
      });

      test('handles non-ASCII brand characters', () {
        final nonAsciiBrand = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes
          0x66, 0x74, 0x79, 0x70,
          0xFF, 0xFE, 0xFD, 0xFC, // Non-ASCII brand
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(nonAsciiBrand), isFalse);
      });

      test('handles string conversion errors gracefully', () {
        // Create data that might cause string conversion issues
        final problematicBrand = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // 16 bytes
          0x66, 0x74, 0x79, 0x70,
          0x00, 0x00, 0x00, 0x00, // Null bytes as brand
          0x00, 0x00, 0x00, 0x00,
        ]);
        expect(strategy.canHandle(problematicBrand), isFalse);
      });
    });
  });
}
