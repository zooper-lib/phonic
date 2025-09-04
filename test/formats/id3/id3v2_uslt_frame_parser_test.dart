import 'dart:typed_data';

import 'package:phonic/src/core/text_encoding.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v2_uslt_frame_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v2UsltFrameParser', () {
    group('parse', () {
      test('parses basic USLT frame with ISO-8859-1 encoding', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x56, 0x65, 0x72, 0x73, 0x65, 0x20, 0x31, 0x00, // "Verse 1\0"
          // "Hello world, this is a test lyric"
          0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x2C, 0x20,
          0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0x65, 0x73,
          0x74, 0x20, 0x6C, 0x79, 0x72, 0x69, 0x63,
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('eng'));
        expect(uslt.descriptor, equals('Verse 1'));
        expect(uslt.lyrics, equals('Hello world, this is a test lyric'));
        expect(uslt.encoding, equals(TextEncoding.iso88591));
        expect(uslt.encodingByte, equals(0x00));
      });

      test('parses USLT frame with UTF-8 encoding', () {
        final frameData = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x43, 0x68, 0x6F, 0x72, 0x75, 0x73, 0x00, // "Chorus\0"
          // "♪ Music with special characters ♫"
          0xE2, 0x99, 0xAA, 0x20, 0x4D, 0x75, 0x73, 0x69, 0x63, 0x20, 0x77, 0x69, 0x74, 0x68, 0x20,
          0x73, 0x70, 0x65, 0x63, 0x69, 0x61, 0x6C, 0x20, 0x63, 0x68, 0x61, 0x72, 0x61, 0x63, 0x74,
          0x65, 0x72, 0x73, 0x20, 0xE2, 0x99, 0xAB,
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('eng'));
        expect(uslt.descriptor, equals('Chorus'));
        expect(uslt.lyrics, equals('♪ Music with special characters ♫'));
        expect(uslt.encoding, equals(TextEncoding.utf8));
        expect(uslt.encodingByte, equals(0x03));
      });

      test('parses USLT frame with UTF-16 encoding', () {
        final frameData = Uint8List.fromList([
          0x01, // UTF-16 with BOM encoding
          0x66, 0x72, 0x65, // "fre" (French)
          // UTF-16 BOM + "Bridge" + null terminator
          0xFF, 0xFE, 0x42, 0x00, 0x72, 0x00, 0x69, 0x00, 0x64, 0x00, 0x67, 0x00, 0x65, 0x00,
          0x00, 0x00, // null terminator for UTF-16
          // UTF-16 BOM + "Bonjour le monde"
          0xFF, 0xFE, 0x42, 0x00, 0x6F, 0x00, 0x6E, 0x00, 0x6A, 0x00, 0x6F, 0x00, 0x75, 0x00,
          0x72, 0x00, 0x20, 0x00, 0x6C, 0x00, 0x65, 0x00, 0x20, 0x00, 0x6D, 0x00, 0x6F, 0x00,
          0x6E, 0x00, 0x64, 0x00, 0x65, 0x00,
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('fre'));
        expect(uslt.descriptor, equals('Bridge'));
        expect(uslt.lyrics, equals('Bonjour le monde'));
        expect(uslt.encoding, equals(TextEncoding.utf16));
        expect(uslt.encodingByte, equals(0x01));
      });

      test('parses USLT frame with UTF-16BE encoding (ID3v2.4 only)', () {
        final frameData = Uint8List.fromList([
          0x02, // UTF-16BE encoding
          0x67, 0x65, 0x72, // "ger" (German)
          // UTF-16BE "Strophe" + null terminator
          0x00, 0x53, 0x00, 0x74, 0x00, 0x72, 0x00, 0x6F, 0x00, 0x70, 0x00, 0x68, 0x00, 0x65,
          0x00, 0x00, // null terminator for UTF-16BE
          // UTF-16BE "Hallo Welt"
          0x00, 0x48, 0x00, 0x61, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, 0x20,
          0x00, 0x57, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x74,
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('ger'));
        expect(uslt.descriptor, equals('Strophe'));
        expect(uslt.lyrics, equals('Hallo Welt'));
        expect(uslt.encoding, equals(TextEncoding.utf16be));
        expect(uslt.encodingByte, equals(0x02));
      });

      test('parses USLT frame with empty descriptor', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x00, // Empty descriptor with null terminator
          0x4C, 0x79, 0x72, 0x69, 0x63, 0x73, 0x20, 0x68, 0x65, 0x72, 0x65, // "Lyrics here"
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('eng'));
        expect(uslt.descriptor, equals(''));
        expect(uslt.lyrics, equals('Lyrics here'));
        expect(uslt.encoding, equals(TextEncoding.iso88591));
      });

      test('parses USLT frame with empty lyrics', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x49, 0x6E, 0x73, 0x74, 0x72, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x61, 0x6C, 0x00, // "Instrumental\0"
          // Empty lyrics (no bytes after descriptor)
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('eng'));
        expect(uslt.descriptor, equals('Instrumental'));
        expect(uslt.lyrics, equals(''));
        expect(uslt.encoding, equals(TextEncoding.iso88591));
      });

      test('parses USLT frame with unknown language code', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x78, 0x78, 0x78, // "xxx" (unknown language)
          0x00, // Empty descriptor
          0x55, 0x6E, 0x6B, 0x6E, 0x6F, 0x77, 0x6E, 0x20, 0x6C, 0x61, 0x6E, 0x67, 0x75, 0x61, 0x67, 0x65, // "Unknown language"
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('xxx'));
        expect(uslt.descriptor, equals(''));
        expect(uslt.lyrics, equals('Unknown language'));
      });

      test('parses USLT frame with multiline lyrics', () {
        final frameData = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x46, 0x75, 0x6C, 0x6C, 0x20, 0x4C, 0x79, 0x72, 0x69, 0x63, 0x73, 0x00, // "Full Lyrics\0"
          // "Line 1\nLine 2\nLine 3"
          0x4C, 0x69, 0x6E, 0x65, 0x20, 0x31, 0x0A,
          0x4C, 0x69, 0x6E, 0x65, 0x20, 0x32, 0x0A,
          0x4C, 0x69, 0x6E, 0x65, 0x20, 0x33,
        ]);

        final uslt = Id3v2UsltFrameParser.parse(frameData, 4);

        expect(uslt.language, equals('eng'));
        expect(uslt.descriptor, equals('Full Lyrics'));
        expect(uslt.lyrics, equals('Line 1\nLine 2\nLine 3'));
        expect(uslt.encoding, equals(TextEncoding.utf8));
      });

      test('throws ArgumentError for frame data too short', () {
        final frameData = Uint8List.fromList([0x00, 0x65, 0x6E]); // Only 3 bytes

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('USLT frame data must be at least 5 bytes'),
            ),
          ),
        );
      });

      test('throws ArgumentError for missing language code', () {
        final frameData = Uint8List.fromList([0x00, 0x65]); // Missing language bytes

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('USLT frame data must be at least 5 bytes'),
            ),
          ),
        );
      });

      test('throws CorruptedContainerException for invalid language code', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x31, 0x32, 0x33, // "123" (invalid language code)
          0x00, // Empty descriptor
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 4),
          throwsA(
            isA<CorruptedContainerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid language code: "123"'),
            ),
          ),
        );
      });

      test('throws FormatException for invalid encoding byte', () {
        final frameData = Uint8List.fromList([
          0x04, // Invalid encoding byte
          0x65, 0x6E, 0x67, // "eng"
          0x00, // Empty descriptor
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 4),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid text encoding byte: 0x04'),
            ),
          ),
        );
      });

      test('throws FormatException for UTF-16BE encoding in ID3v2.3', () {
        final frameData = Uint8List.fromList([
          0x02, // UTF-16BE encoding (not supported in v2.3)
          0x65, 0x6E, 0x67, // "eng"
          0x00, 0x00, // Empty descriptor
          0x00, 0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74, // "Test" in UTF-16BE
        ]);

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 3),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4'),
            ),
          ),
        );
      });

      test('throws FormatException for UTF-8 encoding in ID3v2.3', () {
        final frameData = Uint8List.fromList([
          0x03, // UTF-8 encoding (not supported in v2.3)
          0x65, 0x6E, 0x67, // "eng"
          0x00, // Empty descriptor
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 3),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Encoding 0x03 (UTF-8) is only supported in ID3v2.4'),
            ),
          ),
        );
      });

      test('handles corrupted UTF-16 descriptor gracefully', () {
        final frameData = Uint8List.fromList([
          0x01, // UTF-16 encoding
          0x65, 0x6E, 0x67, // "eng"
          0xFF, 0xFE, 0x41, // Incomplete UTF-16 descriptor (missing second byte)
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2UsltFrameParser.parse(frameData, 4),
          throwsA(isA<CorruptedContainerException>()),
        );
      });
    });

    group('isValid', () {
      test('returns true for valid USLT frame data', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Hello world lyrics',
          language: 'eng',
          descriptor: 'Verse 1',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isTrue);
      });

      test('returns false for invalid language code (too short)', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'en', // Too short
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isFalse);
      });

      test('returns false for invalid language code (too long)', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'english', // Too long
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isFalse);
      });

      test('returns false for invalid language code (contains numbers)', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'en1', // Contains number
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isFalse);
      });

      test('returns false for descriptor containing null bytes', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: 'Test\x00Descriptor', // Contains null byte
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isFalse);
      });

      test('returns false for invalid encoding byte', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x04, // Invalid encoding byte
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isFalse);
      });

      test('returns true for unknown language code (xxx)', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'xxx', // Unknown language is valid
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isTrue);
      });

      test('returns true for empty descriptor', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: '', // Empty descriptor is valid
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isTrue);
      });

      test('returns true for empty lyrics', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: '', // Empty lyrics is valid
          language: 'eng',
          descriptor: 'Instrumental',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2UsltFrameParser.isValid(usltData), isTrue);
      });
    });

    group('encode', () {
      test('encodes USLT frame data with ISO-8859-1 encoding', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'This is a test lyric',
          language: 'eng',
          descriptor: 'Verse 1',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        final encoded = Id3v2UsltFrameParser.encode(usltData, 4);

        final expected = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x56, 0x65, 0x72, 0x73, 0x65, 0x20, 0x31, // "Verse 1"
          0x00, // Null terminator for descriptor
          0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0x65, 0x73, 0x74, 0x20, 0x6C, 0x79, 0x72, 0x69, 0x63, // "This is a test lyric"
        ]);

        expect(encoded, equals(expected));
      });

      test('encodes USLT frame data with UTF-8 encoding', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: '♪ Great song!',
          language: 'eng',
          descriptor: 'Chorus',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final encoded = Id3v2UsltFrameParser.encode(usltData, 4);

        final expected = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x43, 0x68, 0x6F, 0x72, 0x75, 0x73, // "Chorus"
          0x00, // Null terminator for descriptor
          0xE2, 0x99, 0xAA, 0x20, 0x47, 0x72, 0x65, 0x61, 0x74, 0x20, 0x73, 0x6F, 0x6E, 0x67, 0x21, // "♪ Great song!"
        ]);

        expect(encoded, equals(expected));
      });

      test('encodes USLT frame data with empty descriptor', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'General lyrics',
          language: 'eng',
          descriptor: '',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        final encoded = Id3v2UsltFrameParser.encode(usltData, 4);

        final expected = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x00, // Null terminator for empty descriptor
          0x47, 0x65, 0x6E, 0x65, 0x72, 0x61, 0x6C, 0x20, 0x6C, 0x79, 0x72, 0x69, 0x63, 0x73, // "General lyrics"
        ]);

        expect(encoded, equals(expected));
      });

      test('encodes USLT frame data with UTF-16 encoding', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test',
          language: 'eng',
          descriptor: 'Bridge',
          encoding: TextEncoding.utf16,
          encodingByte: 0x01,
        );

        final encoded = Id3v2UsltFrameParser.encode(usltData, 4);

        // Should start with encoding byte, language, then UTF-16 encoded descriptor and lyrics
        expect(encoded[0], equals(0x01)); // UTF-16 encoding
        expect(encoded[1], equals(0x65)); // 'e'
        expect(encoded[2], equals(0x6E)); // 'n'
        expect(encoded[3], equals(0x67)); // 'g'
        // The rest would be UTF-16 encoded "Bridge" + null terminator + "Test"
        expect(encoded.length, greaterThan(20)); // Should be longer due to UTF-16 encoding
      });

      test('throws ArgumentError for invalid USLT data', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'invalid', // Invalid language code
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(
          () => Id3v2UsltFrameParser.encode(usltData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Invalid USLT frame data'),
            ),
          ),
        );
      });

      test('throws FormatException for unsupported encoding in version', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(
          () => Id3v2UsltFrameParser.encode(usltData, 3), // UTF-8 not supported in v2.3
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Encoding 0x03 (UTF-8) is only supported in ID3v2.4'),
            ),
          ),
        );
      });
    });

    group('round-trip encoding/decoding', () {
      test('preserves data through encode/decode cycle with ISO-8859-1', () {
        final originalData = const Id3v2UsltFrameData(
          lyrics: 'Original lyrics content',
          language: 'eng',
          descriptor: 'Test Descriptor',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        final encoded = Id3v2UsltFrameParser.encode(originalData, 4);
        final decoded = Id3v2UsltFrameParser.parse(encoded, 4);

        expect(decoded.lyrics, equals(originalData.lyrics));
        expect(decoded.language, equals(originalData.language));
        expect(decoded.descriptor, equals(originalData.descriptor));
        expect(decoded.encoding, equals(originalData.encoding));
        expect(decoded.encodingByte, equals(originalData.encodingByte));
      });

      test('preserves data through encode/decode cycle with UTF-8', () {
        final originalData = const Id3v2UsltFrameData(
          lyrics: '♪ Unicode lyrics with émojis 🎵',
          language: 'fre',
          descriptor: 'Spécial',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final encoded = Id3v2UsltFrameParser.encode(originalData, 4);
        final decoded = Id3v2UsltFrameParser.parse(encoded, 4);

        expect(decoded.lyrics, equals(originalData.lyrics));
        expect(decoded.language, equals(originalData.language));
        expect(decoded.descriptor, equals(originalData.descriptor));
        expect(decoded.encoding, equals(originalData.encoding));
        expect(decoded.encodingByte, equals(originalData.encodingByte));
      });

      test('preserves multiline lyrics through encode/decode cycle', () {
        final originalData = const Id3v2UsltFrameData(
          lyrics: 'Line 1\nLine 2\nLine 3\n\nLine 5',
          language: 'eng',
          descriptor: 'Full Song',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final encoded = Id3v2UsltFrameParser.encode(originalData, 4);
        final decoded = Id3v2UsltFrameParser.parse(encoded, 4);

        expect(decoded.lyrics, equals(originalData.lyrics));
        expect(decoded.language, equals(originalData.language));
        expect(decoded.descriptor, equals(originalData.descriptor));
      });
    });

    group('Id3v2UsltFrameData', () {
      test('toString() truncates long lyrics', () {
        final usltData = Id3v2UsltFrameData(
          lyrics: 'A' * 100, // 100 character string
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final string = usltData.toString();
        expect(string, contains('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA...'));
        expect(string, contains('language: "eng"'));
        expect(string, contains('descriptor: "Test"'));
      });

      test('toString() shows full lyrics when short', () {
        final usltData = const Id3v2UsltFrameData(
          lyrics: 'Short lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final string = usltData.toString();
        expect(string, contains('lyrics: "Short lyrics"'));
        expect(string, isNot(contains('...')));
      });

      test('equality works correctly', () {
        final usltData1 = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final usltData2 = const Id3v2UsltFrameData(
          lyrics: 'Test lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final usltData3 = const Id3v2UsltFrameData(
          lyrics: 'Different lyrics',
          language: 'eng',
          descriptor: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(usltData1, equals(usltData2));
        expect(usltData1, isNot(equals(usltData3)));
        expect(usltData1.hashCode, equals(usltData2.hashCode));
      });
    });
  });
}
