import 'dart:typed_data';

import 'package:phonic/src/core/text_encoding.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v2_comm_frame_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v2CommFrameParser', () {
    group('parse', () {
      test('parses basic COMM frame with ISO-8859-1 encoding', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x4E, 0x6F, 0x74, 0x65, 0x73, 0x00, // "Album Notes\0"
          0x54,
          0x68,
          0x69,
          0x73,
          0x20,
          0x69,
          0x73,
          0x20,
          0x61,
          0x20,
          0x67,
          0x72,
          0x65,
          0x61,
          0x74,
          0x20,
          0x61,
          0x6C,
          0x62,
          0x75,
          0x6D, // "This is a great album"
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals('This is a great album'));
        expect(result.language, equals('eng'));
        expect(result.description, equals('Album Notes'));
        expect(result.encoding, equals(TextEncoding.iso88591));
        expect(result.encodingByte, equals(0x00));
      });

      test('parses COMM frame with UTF-8 encoding', () {
        final frameData = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x54, 0x72, 0x61, 0x63, 0x6B, 0x20, 0x49, 0x6E, 0x66, 0x6F, 0x00, // "Track Info\0"
          0xE2, 0x99, 0xAA, 0x20, 0x47, 0x72, 0x65, 0x61, 0x74, 0x20, 0x73, 0x6F, 0x6E, 0x67, 0x21, // "♪ Great song!"
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals('♪ Great song!'));
        expect(result.language, equals('eng'));
        expect(result.description, equals('Track Info'));
        expect(result.encoding, equals(TextEncoding.utf8));
        expect(result.encodingByte, equals(0x03));
      });

      test('parses COMM frame with UTF-16 encoding', () {
        final frameData = Uint8List.fromList([
          0x01, // UTF-16 with BOM encoding
          0x66, 0x72, 0x65, // "fre" (French)
          0xFF, 0xFE, 0x4E, 0x00, 0x6F, 0x00, 0x74, 0x00, 0x65, 0x00, 0x73, 0x00, 0x00, 0x00, // "Notes\0" in UTF-16LE
          0xFF,
          0xFE,
          0x43,
          0x00,
          0x27,
          0x00,
          0x65,
          0x00,
          0x73,
          0x00,
          0x74,
          0x00,
          0x20,
          0x00,
          0x75,
          0x00,
          0x6E,
          0x00,
          0x20,
          0x00,
          0x62,
          0x00,
          0x6F,
          0x00,
          0x6E,
          0x00,
          0x20,
          0x00,
          0x61,
          0x00,
          0x6C,
          0x00,
          0x62,
          0x00,
          0x75,
          0x00,
          0x6D,
          0x00, // "C'est un bon album" in UTF-16LE
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals("C'est un bon album"));
        expect(result.language, equals('fre'));
        expect(result.description, equals('Notes'));
        expect(result.encoding, equals(TextEncoding.utf16));
        expect(result.encodingByte, equals(0x01));
      });

      test('parses COMM frame with UTF-16BE encoding (ID3v2.4 only)', () {
        final frameData = Uint8List.fromList([
          0x02, // UTF-16BE encoding
          0x67, 0x65, 0x72, // "ger" (German)
          0x00, 0x4B, 0x00, 0x6F, 0x00, 0x6D, 0x00, 0x6D, 0x00, 0x65, 0x00, 0x6E, 0x00, 0x74, 0x00, 0x61, 0x00, 0x72, 0x00, 0x00, // "Kommentar\0" in UTF-16BE
          0x00,
          0x44,
          0x00,
          0x69,
          0x00,
          0x65,
          0x00,
          0x73,
          0x00,
          0x20,
          0x00,
          0x69,
          0x00,
          0x73,
          0x00,
          0x74,
          0x00,
          0x20,
          0x00,
          0x65,
          0x00,
          0x69,
          0x00,
          0x6E,
          0x00,
          0x20,
          0x00,
          0x67,
          0x00,
          0x75,
          0x00,
          0x74,
          0x00,
          0x65,
          0x00,
          0x73,
          0x00,
          0x20,
          0x00,
          0x4C,
          0x00,
          0x69,
          0x00,
          0x65,
          0x00,
          0x64, // "Dies ist ein gutes Lied" in UTF-16BE
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals('Dies ist ein gutes Lied'));
        expect(result.language, equals('ger'));
        expect(result.description, equals('Kommentar'));
        expect(result.encoding, equals(TextEncoding.utf16be));
        expect(result.encodingByte, equals(0x02));
      });

      test('parses COMM frame with empty description', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x00, // Empty description (just null terminator)
          0x47, 0x65, 0x6E, 0x65, 0x72, 0x61, 0x6C, 0x20, 0x63, 0x6F, 0x6D, 0x6D, 0x65, 0x6E, 0x74, // "General comment"
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals('General comment'));
        expect(result.language, equals('eng'));
        expect(result.description, equals(''));
        expect(result.encoding, equals(TextEncoding.iso88591));
      });

      test('parses COMM frame with empty text', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng" (English)
          0x44, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x00, // "Description\0"
          // No text content (empty)
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals(''));
        expect(result.language, equals('eng'));
        expect(result.description, equals('Description'));
        expect(result.encoding, equals(TextEncoding.iso88591));
      });

      test('parses COMM frame with unknown language code', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x78, 0x78, 0x78, // "xxx" (unknown language)
          0x00, // Empty description
          0x55, 0x6E, 0x6B, 0x6E, 0x6F, 0x77, 0x6E, 0x20, 0x6C, 0x61, 0x6E, 0x67, 0x75, 0x61, 0x67, 0x65, // "Unknown language"
        ]);

        final result = Id3v2CommFrameParser.parse(frameData, 4);

        expect(result.text, equals('Unknown language'));
        expect(result.language, equals('xxx'));
        expect(result.description, equals(''));
        expect(result.encoding, equals(TextEncoding.iso88591));
      });

      test('throws ArgumentError for frame data too short', () {
        final frameData = Uint8List.fromList([0x00, 0x65, 0x6E]); // Only 3 bytes

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('COMM frame data must be at least 5 bytes'),
            ),
          ),
        );
      });

      test('throws ArgumentError for frame data too short for language code', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, // Only 2 bytes of language code (total 3 bytes, less than minimum 5)
        ]);

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('COMM frame data must be at least 5 bytes'),
            ),
          ),
        );
      });

      test('throws CorruptedContainerException for invalid language code', () {
        final frameData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x31, 0x32, 0x33, // "123" (invalid language code)
          0x00, // Empty description
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 4),
          throwsA(
            isA<CorruptedContainerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid language code: "123"'),
            ),
          ),
        );
      });

      test('throws FormatException for invalid encoding in ID3v2.3', () {
        final frameData = Uint8List.fromList([
          0x03, // UTF-8 encoding (not supported in ID3v2.3)
          0x65, 0x6E, 0x67, // "eng"
          0x00, // Empty description
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 3),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Encoding 0x03 (UTF-8) is only supported in ID3v2.4'),
            ),
          ),
        );
      });

      test('throws FormatException for UTF-16BE encoding in ID3v2.3', () {
        final frameData = Uint8List.fromList([
          0x02, // UTF-16BE encoding (not supported in ID3v2.3)
          0x65, 0x6E, 0x67, // "eng"
          0x00, 0x00, // Empty description
          0x00, 0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74, // "Test" in UTF-16BE
        ]);

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 3),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Encoding 0x02 (UTF-16BE) is only supported in ID3v2.4'),
            ),
          ),
        );
      });

      test('throws FormatException for invalid encoding byte', () {
        final frameData = Uint8List.fromList([
          0x04, // Invalid encoding byte
          0x65, 0x6E, 0x67, // "eng"
          0x00, // Empty description
          0x54, 0x65, 0x73, 0x74, // "Test"
        ]);

        expect(
          () => Id3v2CommFrameParser.parse(frameData, 4),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid text encoding byte: 0x04'),
            ),
          ),
        );
      });
    });

    group('isValid', () {
      test('returns true for valid COMM frame data', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: 'eng',
          description: 'Album Notes',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2CommFrameParser.isValid(commData), isTrue);
      });

      test('returns false for invalid language code length', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: 'en', // Too short
          description: 'Album Notes',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2CommFrameParser.isValid(commData), isFalse);
      });

      test('returns false for invalid language code characters', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: '123', // Numbers not allowed
          description: 'Album Notes',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2CommFrameParser.isValid(commData), isFalse);
      });

      test('returns false for description containing null bytes', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: 'eng',
          description: 'Album\x00Notes', // Contains null byte
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2CommFrameParser.isValid(commData), isFalse);
      });

      test('returns false for invalid encoding byte', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: 'eng',
          description: 'Album Notes',
          encoding: TextEncoding.utf8,
          encodingByte: 0x04, // Invalid encoding byte
        );

        expect(Id3v2CommFrameParser.isValid(commData), isFalse);
      });

      test('returns true for unknown language code "xxx"', () {
        final commData = const Id3v2CommFrameData(
          text: 'Great album!',
          language: 'xxx', // Unknown language is valid
          description: 'Album Notes',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(Id3v2CommFrameParser.isValid(commData), isTrue);
      });
    });

    group('encode', () {
      test('encodes COMM frame data with ISO-8859-1 encoding', () {
        final commData = const Id3v2CommFrameData(
          text: 'This is a great album',
          language: 'eng',
          description: 'Album Notes',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        final encoded = Id3v2CommFrameParser.encode(commData, 4);

        final expected = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x4E, 0x6F, 0x74, 0x65, 0x73, // "Album Notes"
          0x00, // Null terminator for description
          0x54,
          0x68,
          0x69,
          0x73,
          0x20,
          0x69,
          0x73,
          0x20,
          0x61,
          0x20,
          0x67,
          0x72,
          0x65,
          0x61,
          0x74,
          0x20,
          0x61,
          0x6C,
          0x62,
          0x75,
          0x6D, // "This is a great album"
        ]);

        expect(encoded, equals(expected));
      });

      test('encodes COMM frame data with UTF-8 encoding', () {
        final commData = const Id3v2CommFrameData(
          text: '♪ Great song!',
          language: 'eng',
          description: 'Track Info',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        final encoded = Id3v2CommFrameParser.encode(commData, 4);

        final expected = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x54, 0x72, 0x61, 0x63, 0x6B, 0x20, 0x49, 0x6E, 0x66, 0x6F, // "Track Info"
          0x00, // Null terminator for description
          0xE2, 0x99, 0xAA, 0x20, 0x47, 0x72, 0x65, 0x61, 0x74, 0x20, 0x73, 0x6F, 0x6E, 0x67, 0x21, // "♪ Great song!"
        ]);

        expect(encoded, equals(expected));
      });

      test('encodes COMM frame data with empty description', () {
        final commData = const Id3v2CommFrameData(
          text: 'General comment',
          language: 'eng',
          description: '',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        final encoded = Id3v2CommFrameParser.encode(commData, 4);

        final expected = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng"
          // Empty description (no bytes)
          0x00, // Null terminator for description
          0x47, 0x65, 0x6E, 0x65, 0x72, 0x61, 0x6C, 0x20, 0x63, 0x6F, 0x6D, 0x6D, 0x65, 0x6E, 0x74, // "General comment"
        ]);

        expect(encoded, equals(expected));
      });

      test('throws ArgumentError for invalid COMM data', () {
        final commData = const Id3v2CommFrameData(
          text: 'Test',
          language: '123', // Invalid language code
          description: 'Test',
          encoding: TextEncoding.iso88591,
          encodingByte: 0x00,
        );

        expect(
          () => Id3v2CommFrameParser.encode(commData, 4),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Invalid COMM frame data'),
            ),
          ),
        );
      });

      test('throws FormatException for unsupported encoding in version', () {
        final commData = const Id3v2CommFrameData(
          text: 'Test',
          language: 'eng',
          description: 'Test',
          encoding: TextEncoding.utf8,
          encodingByte: 0x03,
        );

        expect(
          () => Id3v2CommFrameParser.encode(commData, 3), // ID3v2.3 doesn't support UTF-8
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

    group('round-trip parsing', () {
      test('parses and encodes back to identical bytes for ISO-8859-1', () {
        final originalData = Uint8List.fromList([
          0x00, // ISO-8859-1 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x41, 0x6C, 0x62, 0x75, 0x6D, 0x20, 0x4E, 0x6F, 0x74, 0x65, 0x73, 0x00, // "Album Notes\0"
          0x54,
          0x68,
          0x69,
          0x73,
          0x20,
          0x69,
          0x73,
          0x20,
          0x61,
          0x20,
          0x67,
          0x72,
          0x65,
          0x61,
          0x74,
          0x20,
          0x61,
          0x6C,
          0x62,
          0x75,
          0x6D, // "This is a great album"
        ]);

        final parsed = Id3v2CommFrameParser.parse(originalData, 4);
        final encoded = Id3v2CommFrameParser.encode(parsed, 4);

        expect(encoded, equals(originalData));
      });

      test('parses and encodes back to identical bytes for UTF-8', () {
        final originalData = Uint8List.fromList([
          0x03, // UTF-8 encoding
          0x65, 0x6E, 0x67, // "eng"
          0x54, 0x72, 0x61, 0x63, 0x6B, 0x20, 0x49, 0x6E, 0x66, 0x6F, 0x00, // "Track Info\0"
          0xE2, 0x99, 0xAA, 0x20, 0x47, 0x72, 0x65, 0x61, 0x74, 0x20, 0x73, 0x6F, 0x6E, 0x67, 0x21, // "♪ Great song!"
        ]);

        final parsed = Id3v2CommFrameParser.parse(originalData, 4);
        final encoded = Id3v2CommFrameParser.encode(parsed, 4);

        expect(encoded, equals(originalData));
      });
    });
  });
}
