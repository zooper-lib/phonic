import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/id3/id3.dart';
import 'package:phonic/src/utils/utils.dart';

void main() {
  group('Id3v2HeaderFlags', () {
    group('fromByte', () {
      test('parses ID3v2.2 flags correctly', () {
        // ID3v2.2: Only unsync (bit 7) and compression (bit 6) are defined
        final flags = Id3v2HeaderFlags.fromByte(0x80, 2); // Unsync only
        expect(flags.unsynchronization, isTrue);
        expect(flags.extendedHeader, isFalse); // Compression in v2.2
        expect(flags.experimental, isFalse);
        expect(flags.footer, isFalse);
        expect(flags.rawValue, equals(0x80));
      });

      test('parses ID3v2.2 compression flag', () {
        final flags = Id3v2HeaderFlags.fromByte(0x40, 2); // Compression
        expect(flags.unsynchronization, isFalse);
        expect(flags.extendedHeader, isTrue); // Compression mapped to extendedHeader
        expect(flags.experimental, isFalse);
        expect(flags.footer, isFalse);
      });

      test('parses ID3v2.3 flags correctly', () {
        final flags = Id3v2HeaderFlags.fromByte(0xE0, 3); // All v2.3 flags
        expect(flags.unsynchronization, isTrue);
        expect(flags.extendedHeader, isTrue);
        expect(flags.experimental, isTrue);
        expect(flags.footer, isFalse);
        expect(flags.rawValue, equals(0xE0));
      });

      test('parses ID3v2.4 flags correctly', () {
        final flags = Id3v2HeaderFlags.fromByte(0xF0, 4); // All v2.4 flags
        expect(flags.unsynchronization, isTrue);
        expect(flags.extendedHeader, isTrue);
        expect(flags.experimental, isTrue);
        expect(flags.footer, isTrue);
        expect(flags.rawValue, equals(0xF0));
      });

      test('throws on invalid ID3v2.2 reserved bits', () {
        expect(
          () => Id3v2HeaderFlags.fromByte(0x3F, 2), // Reserved bits set
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ID3v2.2 flags: reserved bits set'),
            ),
          ),
        );
      });

      test('throws on invalid ID3v2.3 reserved bits', () {
        expect(
          () => Id3v2HeaderFlags.fromByte(0x1F, 3), // Reserved bits set
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ID3v2.3 flags: reserved bits set'),
            ),
          ),
        );
      });

      test('throws on invalid ID3v2.4 reserved bits', () {
        expect(
          () => Id3v2HeaderFlags.fromByte(0x0F, 4), // Reserved bits set
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ID3v2.4 flags: reserved bits set'),
            ),
          ),
        );
      });

      test('throws on unsupported version', () {
        expect(
          () => Id3v2HeaderFlags.fromByte(0x00, 5),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Unsupported ID3v2 major version: 5'),
            ),
          ),
        );
      });
    });

    group('equality and toString', () {
      test('flags with same raw value are equal', () {
        final flags1 = Id3v2HeaderFlags.fromByte(0x80, 4);
        final flags2 = Id3v2HeaderFlags.fromByte(0x80, 4);
        expect(flags1, equals(flags2));
        expect(flags1.hashCode, equals(flags2.hashCode));
      });

      test('toString shows active flags', () {
        final flags = Id3v2HeaderFlags.fromByte(0xF0, 4);
        final str = flags.toString();
        expect(str, contains('unsync'));
        expect(str, contains('extended'));
        expect(str, contains('experimental'));
        expect(str, contains('footer'));
      });

      test('toString shows no flags when none are set', () {
        final flags = Id3v2HeaderFlags.fromByte(0x00, 4);
        final str = flags.toString();
        expect(str, equals('Id3v2HeaderFlags()'));
      });
    });
  });

  group('Id3v2Header', () {
    test('creates header with correct properties', () {
      final flags = Id3v2HeaderFlags.fromByte(0x80, 4);
      final header = Id3v2Header(
        majorVersion: 4,
        minorVersion: 0,
        flags: flags,
        tagSize: 1024,
      );

      expect(header.majorVersion, equals(4));
      expect(header.minorVersion, equals(0));
      expect(header.version, equals('4.0'));
      expect(header.flags, equals(flags));
      expect(header.tagSize, equals(1024));
      expect(header.hasExtendedHeader, isFalse);
      expect(header.isUnsynchronized, isTrue);
      expect(header.totalSize, equals(1034)); // 10 + 1024
    });

    test('calculates total size with footer', () {
      final flags = Id3v2HeaderFlags.fromByte(0x10, 4); // Footer flag
      final header = Id3v2Header(
        majorVersion: 4,
        minorVersion: 0,
        flags: flags,
        tagSize: 1024,
      );

      expect(header.totalSize, equals(1044)); // 10 + 1024 + 10
    });

    test('equality works correctly', () {
      final flags = Id3v2HeaderFlags.fromByte(0x00, 4);
      final header1 = Id3v2Header(
        majorVersion: 4,
        minorVersion: 0,
        flags: flags,
        tagSize: 1024,
      );
      final header2 = Id3v2Header(
        majorVersion: 4,
        minorVersion: 0,
        flags: flags,
        tagSize: 1024,
      );

      expect(header1, equals(header2));
      expect(header1.hashCode, equals(header2.hashCode));
    });

    test('toString provides useful information', () {
      final flags = Id3v2HeaderFlags.fromByte(0x80, 4);
      final header = Id3v2Header(
        majorVersion: 4,
        minorVersion: 0,
        flags: flags,
        tagSize: 1024,
      );

      final str = header.toString();
      expect(str, contains('version: 4.0'));
      expect(str, contains('tagSize: 1024'));
    });
  });

  group('Id3v2ExtendedHeader', () {
    test('creates extended header with correct properties', () {
      final extHeader = const Id3v2ExtendedHeader(
        size: 14,
        flagBytes: 1,
        flags: 0x60, // Update and CRC flags
        tagIsUpdate: true,
        crcDataPresent: true,
        tagRestrictions: false,
        crc32: 0x12345678,
      );

      expect(extHeader.size, equals(14));
      expect(extHeader.flagBytes, equals(1));
      expect(extHeader.flags, equals(0x60));
      expect(extHeader.tagIsUpdate, isTrue);
      expect(extHeader.crcDataPresent, isTrue);
      expect(extHeader.tagRestrictions, isFalse);
      expect(extHeader.crc32, equals(0x12345678));
    });

    test('equality works correctly', () {
      final extHeader1 = const Id3v2ExtendedHeader(
        size: 14,
        flagBytes: 1,
        flags: 0x60,
        tagIsUpdate: true,
        crcDataPresent: true,
        tagRestrictions: false,
        crc32: 0x12345678,
      );
      final extHeader2 = const Id3v2ExtendedHeader(
        size: 14,
        flagBytes: 1,
        flags: 0x60,
        tagIsUpdate: true,
        crcDataPresent: true,
        tagRestrictions: false,
        crc32: 0x12345678,
      );

      expect(extHeader1, equals(extHeader2));
      expect(extHeader1.hashCode, equals(extHeader2.hashCode));
    });

    test('toString shows active flags', () {
      final extHeader = const Id3v2ExtendedHeader(
        size: 14,
        flagBytes: 1,
        flags: 0x70,
        tagIsUpdate: true,
        crcDataPresent: true,
        tagRestrictions: true,
      );

      final str = extHeader.toString();
      expect(str, contains('update'));
      expect(str, contains('crc'));
      expect(str, contains('restrictions'));
    });
  });

  group('Id3v2HeaderParser', () {
    group('parseHeader', () {
      test('parses valid ID3v2.4 header', () {
        final headerBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x80, // Unsynchronization flag
          ...SynchsafeInt.encode(1024), // Tag size
        ]);

        final header = Id3v2HeaderParser.parseHeader(headerBytes);

        expect(header.majorVersion, equals(4));
        expect(header.minorVersion, equals(0));
        expect(header.version, equals('4.0'));
        expect(header.flags.unsynchronization, isTrue);
        expect(header.tagSize, equals(1024));
      });

      test('parses valid ID3v2.3 header', () {
        final headerBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x03, 0x00, // Version 2.3
          0x40, // Extended header flag
          ...SynchsafeInt.encode(2048), // Tag size
        ]);

        final header = Id3v2HeaderParser.parseHeader(headerBytes);

        expect(header.majorVersion, equals(3));
        expect(header.minorVersion, equals(0));
        expect(header.flags.extendedHeader, isTrue);
        expect(header.tagSize, equals(2048));
      });

      test('parses valid ID3v2.2 header', () {
        final headerBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x00, // Version 2.2
          0x00, // No flags
          ...SynchsafeInt.encode(512), // Tag size
        ]);

        final header = Id3v2HeaderParser.parseHeader(headerBytes);

        expect(header.majorVersion, equals(2));
        expect(header.minorVersion, equals(0));
        expect(header.flags.unsynchronization, isFalse);
        expect(header.tagSize, equals(512));
      });

      test('throws on insufficient bytes', () {
        final shortBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04]); // Only 4 bytes

        expect(
          () => Id3v2HeaderParser.parseHeader(shortBytes),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Insufficient bytes for ID3v2 header'),
            ),
          ),
        );
      });

      test('throws on invalid signature', () {
        final invalidBytes = Uint8List.fromList([
          0x4D, 0x50, 0x33, // "MP3" instead of "ID3"
          0x04, 0x00,
          0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(
          () => Id3v2HeaderParser.parseHeader(invalidBytes),
          throwsA(
            isA<CorruptedContainerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ID3v2 signature: expected "ID3", found "MP3"'),
            ),
          ),
        );
      });

      test('throws on unsupported version', () {
        final unsupportedBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x05, 0x00, // Version 2.5 (unsupported)
          0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(
          () => Id3v2HeaderParser.parseHeader(unsupportedBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Unsupported ID3v2 version: 5.0'),
            ),
          ),
        );
      });

      test('throws on invalid ID3v2.2 minor version', () {
        final invalidBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x02, 0x01, // Version 2.1 (invalid)
          0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);

        expect(
          () => Id3v2HeaderParser.parseHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ID3v2.2 minor version: 1'),
            ),
          ),
        );
      });

      test('handles maximum synchsafe size', () {
        final maxSizeBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          ...SynchsafeInt.encode(SynchsafeInt.maxValue), // Maximum size
        ]);

        final header = Id3v2HeaderParser.parseHeader(maxSizeBytes);
        expect(header.tagSize, equals(SynchsafeInt.maxValue));
      });

      test('handles zero size tag', () {
        final zeroSizeBytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x00, // Zero size
        ]);

        final header = Id3v2HeaderParser.parseHeader(zeroSizeBytes);
        expect(header.tagSize, equals(0));
      });
    });

    group('parseExtendedHeader', () {
      test('parses basic extended header', () {
        final extHeaderBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(6), // Size: 6 bytes
          0x01, // 1 flag byte
          0x00, // No flags set
        ]);

        final extHeader = Id3v2HeaderParser.parseExtendedHeader(extHeaderBytes);

        expect(extHeader.size, equals(6));
        expect(extHeader.flagBytes, equals(1));
        expect(extHeader.flags, equals(0x00));
        expect(extHeader.tagIsUpdate, isFalse);
        expect(extHeader.crcDataPresent, isFalse);
        expect(extHeader.tagRestrictions, isFalse);
      });

      test('parses extended header with CRC', () {
        final extHeaderBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(11), // Size: 11 bytes (6 + 5 for CRC)
          0x01, // 1 flag byte
          0x20, // CRC data present flag
          0x04, // CRC length: 4 bytes
          0x12, 0x34, 0x56, 0x78, // CRC-32 value
        ]);

        final extHeader = Id3v2HeaderParser.parseExtendedHeader(extHeaderBytes);

        expect(extHeader.size, equals(11));
        expect(extHeader.crcDataPresent, isTrue);
        expect(extHeader.crc32, equals(0x12345678));
      });

      test('parses extended header with restrictions', () {
        final extHeaderBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(8), // Size: 8 bytes (6 + 2 for restrictions)
          0x01, // 1 flag byte
          0x10, // Tag restrictions flag
          0x01, // Restrictions length: 1 byte
          0xC0, // Restrictions byte
        ]);

        final extHeader = Id3v2HeaderParser.parseExtendedHeader(extHeaderBytes);

        expect(extHeader.size, equals(8));
        expect(extHeader.tagRestrictions, isTrue);
        expect(extHeader.restrictionsByte, equals(0xC0));
      });

      test('parses extended header with all flags', () {
        final extHeaderBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(13), // Size: 13 bytes
          0x01, // 1 flag byte
          0x70, // Update, CRC, and restrictions flags
          0x04, // CRC length: 4 bytes
          0xAB, 0xCD, 0xEF, 0x01, // CRC-32 value
          0x01, // Restrictions length: 1 byte
          0x80, // Restrictions byte
        ]);

        final extHeader = Id3v2HeaderParser.parseExtendedHeader(extHeaderBytes);

        expect(extHeader.size, equals(13));
        expect(extHeader.tagIsUpdate, isTrue);
        expect(extHeader.crcDataPresent, isTrue);
        expect(extHeader.tagRestrictions, isTrue);
        expect(extHeader.crc32, equals(0xABCDEF01));
        expect(extHeader.restrictionsByte, equals(0x80));
      });

      test('throws on insufficient bytes', () {
        final shortBytes = Uint8List.fromList([0x00, 0x00, 0x00]); // Only 3 bytes

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(shortBytes),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Insufficient bytes for extended header'),
            ),
          ),
        );
      });

      test('throws on invalid size', () {
        final invalidBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(3), // Size too small
          0x01, // 1 flag byte
          0x00, // No flags
        ]);

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid extended header size: 3'),
            ),
          ),
        );
      });

      test('throws on invalid flag bytes count', () {
        final invalidBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(6), // Size: 6 bytes
          0x02, // 2 flag bytes (invalid for ID3v2.4)
          0x00, // Flags
        ]);

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid extended header flag bytes: 2'),
            ),
          ),
        );
      });

      test('throws on reserved flags set', () {
        final invalidBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(6), // Size: 6 bytes
          0x01, // 1 flag byte
          0x8F, // Reserved bits set
        ]);

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid extended header flags: reserved bits set'),
            ),
          ),
        );
      });

      test('throws when CRC flag set but no CRC data', () {
        final invalidBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(6), // Size: 6 bytes
          0x01, // 1 flag byte
          0x20, // CRC flag set
          // No CRC data follows
        ]);

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('CRC data flag set but insufficient bytes'),
            ),
          ),
        );
      });

      test('throws on invalid CRC length', () {
        final invalidBytes = Uint8List.fromList([
          ...SynchsafeInt.encode(10), // Size: 10 bytes (enough for CRC length check)
          0x01, // 1 flag byte
          0x20, // CRC flag set
          0x03, // Invalid CRC length (must be 4)
          0x12, 0x34, 0x56, 0x78, // 4 bytes of data
        ]);

        expect(
          () => Id3v2HeaderParser.parseExtendedHeader(invalidBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid CRC data length: 3'),
            ),
          ),
        );
      });
    });

    group('hasValidSignature', () {
      test('returns true for valid ID3v2 signature', () {
        final validBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00]);
        expect(Id3v2HeaderParser.hasValidSignature(validBytes), isTrue);
      });

      test('returns false for invalid signature', () {
        final invalidBytes = Uint8List.fromList([0x4D, 0x50, 0x33, 0x04, 0x00]);
        expect(Id3v2HeaderParser.hasValidSignature(invalidBytes), isFalse);
      });

      test('returns false for insufficient bytes', () {
        final shortBytes = Uint8List.fromList([0x49, 0x44]);
        expect(Id3v2HeaderParser.hasValidSignature(shortBytes), isFalse);
      });

      test('returns false for empty bytes', () {
        final emptyBytes = Uint8List(0);
        expect(Id3v2HeaderParser.hasValidSignature(emptyBytes), isFalse);
      });
    });

    group('detectUnsynchronization', () {
      test('returns true when header flag is set', () {
        final flags = Id3v2HeaderFlags.fromByte(0x80, 4); // Unsync flag
        final header = Id3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: flags,
          tagSize: 100,
        );
        final tagData = Uint8List.fromList([0x01, 0x02, 0x03]);

        expect(Id3v2HeaderParser.detectUnsynchronization(tagData, header), isTrue);
      });

      test('returns true when unsync pattern detected in data', () {
        final flags = Id3v2HeaderFlags.fromByte(0x00, 4); // No flags
        final header = Id3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: flags,
          tagSize: 100,
        );
        final tagData = Uint8List.fromList([0x01, 0xFF, 0x00, 0x03]); // Unsync pattern

        expect(Id3v2HeaderParser.detectUnsynchronization(tagData, header), isTrue);
      });

      test('returns false when no unsynchronization detected', () {
        final flags = Id3v2HeaderFlags.fromByte(0x00, 4); // No flags
        final header = Id3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: flags,
          tagSize: 100,
        );
        final tagData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

        expect(Id3v2HeaderParser.detectUnsynchronization(tagData, header), isFalse);
      });

      test('handles edge case with FF at end of data', () {
        final flags = Id3v2HeaderFlags.fromByte(0x00, 4); // No flags
        final header = Id3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: flags,
          tagSize: 100,
        );
        final tagData = Uint8List.fromList([0x01, 0x02, 0xFF]); // FF at end

        expect(Id3v2HeaderParser.detectUnsynchronization(tagData, header), isFalse);
      });

      test('handles empty tag data', () {
        final flags = Id3v2HeaderFlags.fromByte(0x00, 4); // No flags
        final header = Id3v2Header(
          majorVersion: 4,
          minorVersion: 0,
          flags: flags,
          tagSize: 0,
        );
        final tagData = Uint8List(0);

        expect(Id3v2HeaderParser.detectUnsynchronization(tagData, header), isFalse);
      });
    });

    group('edge cases and error handling', () {
      test('handles header at offset', () {
        final headerBytes = Uint8List.fromList([
          0xFF, 0xFF, // Padding
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // No flags
          0x00, 0x00, 0x00, 0x64, // Size: 100
        ]);

        // Parse from offset 2
        final headerAtOffset = headerBytes.sublist(2);
        final header = Id3v2HeaderParser.parseHeader(headerAtOffset);

        expect(header.majorVersion, equals(4));
        expect(header.tagSize, equals(100));
      });

      test('handles various flag combinations', () {
        final testCases = [
          (0x00, 4), // No flags
          (0x80, 4), // Unsync only
          (0x40, 4), // Extended header only
          (0x20, 4), // Experimental only
          (0x10, 4), // Footer only
          (0xF0, 4), // All flags
        ];

        for (final (flagsByte, version) in testCases) {
          final headerBytes = Uint8List.fromList([
            0x49, 0x44, 0x33, // "ID3"
            version, 0x00, // Version
            flagsByte, // Flags
            0x00, 0x00, 0x00, 0x64, // Size: 100
          ]);

          final header = Id3v2HeaderParser.parseHeader(headerBytes);
          expect(header.flags.rawValue, equals(flagsByte));
        }
      });

      test('handles all supported versions', () {
        final versions = [
          (2, 0),
          (3, 0),
          (4, 0),
        ];

        for (final (major, minor) in versions) {
          final headerBytes = Uint8List.fromList([
            0x49, 0x44, 0x33, // "ID3"
            major, minor, // Version
            0x00, // No flags
            0x00, 0x00, 0x00, 0x64, // Size: 100
          ]);

          final header = Id3v2HeaderParser.parseHeader(headerBytes);
          expect(header.majorVersion, equals(major));
          expect(header.minorVersion, equals(minor));
        }
      });
    });
  });
}
