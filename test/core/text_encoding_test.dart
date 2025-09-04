import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/core/text_encoding.dart';
import 'package:phonic/src/utils/text_encoding_utils.dart';
import 'package:test/test.dart';

void main() {
  group('TextEncodingUtils', () {
    group('BOM Detection', () {
      test('detects UTF-8 BOM', () {
        final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('detects UTF-16 BE BOM', () {
        final bytes = Uint8List.fromList([0xFE, 0xFF, 0x00, 0x48, 0x00, 0x65]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf16be));
      });

      test('detects UTF-16 LE BOM', () {
        final bytes = Uint8List.fromList([0xFF, 0xFE, 0x48, 0x00, 0x65, 0x00]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf16le));
      });

      test('handles empty bytes', () {
        final bytes = Uint8List(0);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.iso88591));
      });
    });

    group('UTF-8 Detection', () {
      test('detects valid UTF-8 without BOM', () {
        final text = 'Hello 世界 🌍';
        final bytes = Uint8List.fromList(utf8.encode(text));
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('detects ASCII as UTF-8', () {
        final bytes = Uint8List.fromList('Hello World'.codeUnits);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('rejects invalid UTF-8 sequences', () {
        // Invalid UTF-8: continuation byte without start byte
        final bytes = Uint8List.fromList([0x80, 0x81, 0x82]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.iso88591));
      });

      test('validates multi-byte UTF-8 sequences', () {
        // Valid 2-byte sequence: é (U+00E9)
        final bytes = Uint8List.fromList([0xC3, 0xA9]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('validates 3-byte UTF-8 sequences', () {
        // Valid 3-byte sequence: 世 (U+4E16)
        final bytes = Uint8List.fromList([0xE4, 0xB8, 0x96]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('validates 4-byte UTF-8 sequences', () {
        // Valid 4-byte sequence: 🌍 (U+1F30D)
        final bytes = Uint8List.fromList([0xF0, 0x9F, 0x8C, 0x8D]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });

      test('rejects incomplete UTF-8 sequences', () {
        // Incomplete 2-byte sequence
        final bytes = Uint8List.fromList([0xC3]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.iso88591));
      });
    });

    group('UTF-16 Detection', () {
      test('detects UTF-16 LE pattern without BOM', () {
        // "Hello World" in UTF-16 LE without BOM (more null bytes for better detection)
        final bytes = Uint8List.fromList([
          0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, // "Hello"
          0x20, 0x00, 0x57, 0x00, 0x6F, 0x00, 0x72, 0x00, 0x6C, 0x00, 0x64, 0x00, // " World"
        ]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf16le));
      });

      test('rejects odd-length byte arrays', () {
        final bytes = Uint8List.fromList([0x48, 0x00, 0x65]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8)); // Falls back to UTF-8 for ASCII-like content
      });

      test('rejects arrays without null byte pattern', () {
        final bytes = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C]);
        final encoding = TextEncodingUtils.detectEncoding(bytes);
        expect(encoding, equals(TextEncoding.utf8));
      });
    });

    group('Text Encoding', () {
      const testText = 'Hello World';

      test('encodes UTF-8 with BOM', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.utf8);
        expect(bytes.sublist(0, 3), equals(TextEncodingUtils.utf8Bom));
        expect(bytes.sublist(3), equals(utf8.encode(testText)));
      });

      test('encodes UTF-8 without BOM', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.utf8, includeBom: false);
        expect(bytes, equals(utf8.encode(testText)));
      });

      test('encodes UTF-16 LE with BOM', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.utf16le);
        expect(bytes.sublist(0, 2), equals(TextEncodingUtils.utf16LeBom));

        // Check the encoded text part
        final textBytes = bytes.sublist(2);
        expect(textBytes.length, equals(testText.length * 2));

        // Verify first character 'H' (0x48)
        expect(textBytes[0], equals(0x48)); // Low byte
        expect(textBytes[1], equals(0x00)); // High byte
      });

      test('encodes UTF-16 BE with BOM', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.utf16be);
        expect(bytes.sublist(0, 2), equals(TextEncodingUtils.utf16BeBom));

        // Check the encoded text part
        final textBytes = bytes.sublist(2);
        expect(textBytes.length, equals(testText.length * 2));

        // Verify first character 'H' (0x48)
        expect(textBytes[0], equals(0x00)); // High byte
        expect(textBytes[1], equals(0x48)); // Low byte
      });

      test('encodes ISO-8859-1', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.iso88591);
        expect(bytes, equals(latin1.encode(testText)));
      });

      test('encodes ASCII', () {
        final bytes = TextEncodingUtils.encodeText(testText, TextEncoding.ascii);
        expect(bytes, equals(ascii.encode(testText)));
      });
    });

    group('Text Decoding', () {
      const testText = 'Hello World';

      test('decodes UTF-8 with BOM', () {
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf8Bom, ...utf8.encode(testText)]);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf8);
        expect(decoded, equals(testText));
      });

      test('decodes UTF-8 without BOM removal', () {
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf8Bom, ...utf8.encode(testText)]);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf8, removeBom: false);
        // Dart's UTF-8 decoder automatically handles BOM, so the result is the same
        expect(decoded, equals(testText));
      });

      test('decodes UTF-16 LE with BOM', () {
        final textBytes = <int>[];
        for (final codeUnit in testText.codeUnits) {
          textBytes.add(codeUnit & 0xFF);
          textBytes.add((codeUnit >> 8) & 0xFF);
        }
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf16LeBom, ...textBytes]);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf16le);
        expect(decoded, equals(testText));
      });

      test('decodes UTF-16 BE with BOM', () {
        final textBytes = <int>[];
        for (final codeUnit in testText.codeUnits) {
          textBytes.add((codeUnit >> 8) & 0xFF);
          textBytes.add(codeUnit & 0xFF);
        }
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf16BeBom, ...textBytes]);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf16be);
        expect(decoded, equals(testText));
      });

      test('decodes ISO-8859-1', () {
        final bytes = Uint8List.fromList(latin1.encode(testText));
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.iso88591);
        expect(decoded, equals(testText));
      });

      test('throws on invalid UTF-16 length', () {
        final bytes = Uint8List.fromList([0x48, 0x00, 0x65]); // Odd length
        expect(
          () => TextEncodingUtils.decodeText(bytes, TextEncoding.utf16le),
          throwsArgumentError,
        );
      });
    });

    group('Automatic Detection and Decoding', () {
      test('decodes UTF-8 with BOM automatically', () {
        const text = 'Hello 世界';
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf8Bom, ...utf8.encode(text)]);
        final decoded = TextEncodingUtils.decodeWithDetection(bytes);
        expect(decoded, equals(text));
      });

      test('decodes UTF-16 LE with BOM automatically', () {
        const text = 'Hello World';
        final textBytes = <int>[];
        for (final codeUnit in text.codeUnits) {
          textBytes.add(codeUnit & 0xFF);
          textBytes.add((codeUnit >> 8) & 0xFF);
        }
        final bytes = Uint8List.fromList([...TextEncodingUtils.utf16LeBom, ...textBytes]);
        final decoded = TextEncodingUtils.decodeWithDetection(bytes);
        expect(decoded, equals(text));
      });

      test('decodes UTF-8 without BOM automatically', () {
        const text = 'Hello 世界';
        final bytes = Uint8List.fromList(utf8.encode(text));
        final decoded = TextEncodingUtils.decodeWithDetection(bytes);
        expect(decoded, equals(text));
      });
    });

    group('Encoding Conversion', () {
      const testText = 'Hello World';

      test('converts from UTF-8 to UTF-16 LE', () {
        final bytes = TextEncodingUtils.convertEncoding(
          testText,
          from: TextEncoding.utf8,
          to: TextEncoding.utf16le,
        );

        // Should have BOM + text
        expect(bytes.sublist(0, 2), equals(TextEncodingUtils.utf16LeBom));
        expect(bytes.length, equals(2 + testText.length * 2));
      });

      test('converts from UTF-16 to UTF-8', () {
        final bytes = TextEncodingUtils.convertEncoding(
          testText,
          from: TextEncoding.utf16le,
          to: TextEncoding.utf8,
        );

        // Should have BOM + text
        expect(bytes.sublist(0, 3), equals(TextEncodingUtils.utf8Bom));
        expect(bytes.sublist(3), equals(utf8.encode(testText)));
      });

      test('converts without BOM when requested', () {
        final bytes = TextEncodingUtils.convertEncoding(
          testText,
          from: TextEncoding.utf8,
          to: TextEncoding.utf16le,
          includeBom: false,
        );

        expect(bytes.length, equals(testText.length * 2));
        expect(bytes[0], equals(0x48)); // 'H' low byte
        expect(bytes[1], equals(0x00)); // 'H' high byte
      });

      test('handles same encoding conversion', () {
        final bytes = TextEncodingUtils.convertEncoding(
          testText,
          from: TextEncoding.utf8,
          to: TextEncoding.utf8,
        );

        expect(bytes.sublist(0, 3), equals(TextEncodingUtils.utf8Bom));
        expect(bytes.sublist(3), equals(utf8.encode(testText)));
      });
    });

    group('Encoding Validation', () {
      test('validates UTF-8 can encode any text', () {
        const text = 'Hello 世界 🌍 ñáéíóú';
        expect(TextEncodingUtils.canEncode(text, TextEncoding.utf8), isTrue);
      });

      test('validates UTF-16 can encode any text', () {
        const text = 'Hello 世界 🌍 ñáéíóú';
        expect(TextEncodingUtils.canEncode(text, TextEncoding.utf16le), isTrue);
        expect(TextEncodingUtils.canEncode(text, TextEncoding.utf16be), isTrue);
      });

      test('validates ISO-8859-1 limitations', () {
        expect(TextEncodingUtils.canEncode('Hello World', TextEncoding.iso88591), isTrue);
        expect(TextEncodingUtils.canEncode('Café', TextEncoding.iso88591), isTrue);
        expect(TextEncodingUtils.canEncode('Hello 世界', TextEncoding.iso88591), isFalse);
      });

      test('validates ASCII limitations', () {
        expect(TextEncodingUtils.canEncode('Hello World', TextEncoding.ascii), isTrue);
        expect(TextEncodingUtils.canEncode('Café', TextEncoding.ascii), isFalse);
        expect(TextEncodingUtils.canEncode('Hello 世界', TextEncoding.ascii), isFalse);
      });
    });

    group('Encoded Length Calculation', () {
      test('calculates UTF-8 length', () {
        const text = 'Hello 世界';
        final actualBytes = utf8.encode(text);
        final calculatedLength = TextEncodingUtils.getEncodedLength(text, TextEncoding.utf8);
        expect(calculatedLength, equals(actualBytes.length));
      });

      test('calculates UTF-8 length with BOM', () {
        const text = 'Hello World';
        final calculatedLength = TextEncodingUtils.getEncodedLength(
          text,
          TextEncoding.utf8,
          includeBom: true,
        );
        expect(calculatedLength, equals(text.length + 3)); // +3 for UTF-8 BOM
      });

      test('calculates UTF-16 length', () {
        const text = 'Hello World';
        final calculatedLength = TextEncodingUtils.getEncodedLength(text, TextEncoding.utf16le);
        expect(calculatedLength, equals(text.length * 2));
      });

      test('calculates UTF-16 length with BOM', () {
        const text = 'Hello World';
        final calculatedLength = TextEncodingUtils.getEncodedLength(
          text,
          TextEncoding.utf16le,
          includeBom: true,
        );
        expect(calculatedLength, equals(text.length * 2 + 2)); // +2 for UTF-16 BOM
      });

      test('calculates ISO-8859-1 length', () {
        const text = 'Hello World';
        final calculatedLength = TextEncodingUtils.getEncodedLength(text, TextEncoding.iso88591);
        expect(calculatedLength, equals(text.length));
      });
    });

    group('Edge Cases', () {
      test('handles empty strings', () {
        final bytes = TextEncodingUtils.encodeText('', TextEncoding.utf8);
        expect(bytes, equals(TextEncodingUtils.utf8Bom));

        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf8);
        expect(decoded, equals(''));
      });

      test('handles single character', () {
        const text = 'A';
        final bytes = TextEncodingUtils.encodeText(text, TextEncoding.utf16le);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf16le);
        expect(decoded, equals(text));
      });

      test('handles null characters', () {
        const text = 'Hello\x00World';
        final bytes = TextEncodingUtils.encodeText(text, TextEncoding.utf8, includeBom: false);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf8, removeBom: false);
        expect(decoded, equals(text));
      });

      test('handles high Unicode characters', () {
        const text = '🌍🎵🚀'; // Emoji characters
        final bytes = TextEncodingUtils.encodeText(text, TextEncoding.utf8, includeBom: false);
        final decoded = TextEncodingUtils.decodeText(bytes, TextEncoding.utf8, removeBom: false);
        expect(decoded, equals(text));
      });
    });

    group('BOM Constants', () {
      test('has correct UTF-8 BOM', () {
        expect(TextEncodingUtils.utf8Bom, equals([0xEF, 0xBB, 0xBF]));
      });

      test('has correct UTF-16 BE BOM', () {
        expect(TextEncodingUtils.utf16BeBom, equals([0xFE, 0xFF]));
      });

      test('has correct UTF-16 LE BOM', () {
        expect(TextEncodingUtils.utf16LeBom, equals([0xFF, 0xFE]));
      });
    });
  });
}
