import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/core/text_encoding.dart';
import 'package:phonic/src/utils/text_normalization.dart';
import 'package:test/test.dart';

void main() {
  group('TextNormalization', () {
    group('normalizeText', () {
      test('trims leading and trailing whitespace', () {
        expect(TextNormalization.normalizeText('  hello world  '), equals('hello world'));
        expect(TextNormalization.normalizeText('\t\nhello\t\n'), equals('hello'));
        expect(TextNormalization.normalizeText('   '), equals(''));
      });

      test('normalizes internal whitespace', () {
        expect(TextNormalization.normalizeText('hello    world'), equals('hello world'));
        expect(TextNormalization.normalizeText('a\t\tb\n\nc'), equals('a b c'));
        expect(TextNormalization.normalizeText('multiple   \t  spaces'), equals('multiple spaces'));
      });

      test('handles empty and null-like inputs', () {
        expect(TextNormalization.normalizeText(''), equals(''));
        expect(TextNormalization.normalizeText('   '), equals(''));
      });

      test('applies length constraint without word preservation', () {
        const longText = 'This is a very long text that exceeds the limit';
        final result = TextNormalization.normalizeText(longText, maxLength: 20);
        expect(result, equals('This is a very long '));
        expect(result.length, equals(20));
      });

      test('applies length constraint with word preservation', () {
        const longText = 'This is a very long text that exceeds the limit';
        final result = TextNormalization.normalizeText(
          longText,
          maxLength: 20,
          preserveWords: true,
        );
        expect(result, equals('This is a very long'));
        expect(result.length, lessThan(20));
      });

      test('preserves words only when reasonable', () {
        // When word boundary would remove too much text, use character boundary
        const text = 'Verylongwordthatcannotbebroken short';
        final result = TextNormalization.normalizeText(
          text,
          maxLength: 30,
          preserveWords: true,
        );
        expect(result, equals('Verylongwordthatcannotbebroken'));
        expect(result.length, equals(30));
      });

      test('handles text shorter than max length', () {
        const shortText = 'Short';
        final result = TextNormalization.normalizeText(shortText, maxLength: 20);
        expect(result, equals('Short'));
      });

      test('preserves Unicode characters', () {
        const unicodeText = 'Café with émojis 🎵';
        final result = TextNormalization.normalizeText(unicodeText);
        expect(result, equals('Café with émojis 🎵'));
      });
    });

    group('normalizeForConstraints', () {
      test('applies basic normalization without constraints', () {
        const semantics = TagSemantics();
        final result = TextNormalization.normalizeForConstraints(
          '  hello   world  ',
          semantics,
        );
        expect(result, equals('hello world'));
      });

      test('applies length constraint from semantics', () {
        const semantics = TagSemantics(maxTextLength: 10);
        final result = TextNormalization.normalizeForConstraints(
          'This is a very long text',
          semantics,
        );
        expect(result, equals('This is a '));
        expect(result.length, equals(10));
      });

      test('applies ASCII encoding constraint', () {
        const semantics = TagSemantics(allowedEncodings: {'ASCII'});
        final result = TextNormalization.normalizeForConstraints(
          'Café with émojis 🎵',
          semantics,
        );
        expect(result, equals('Caf? with ?mojis ?'));
      });

      test('applies ISO-8859-1 encoding constraint', () {
        const semantics = TagSemantics(allowedEncodings: {'ISO-8859-1'});
        final result = TextNormalization.normalizeForConstraints(
          'Café with émojis 🎵',
          semantics,
        );
        expect(result, equals('Café with émojis ?'));
      });

      test('applies both length and encoding constraints', () {
        const semantics = TagSemantics(
          maxTextLength: 15,
          allowedEncodings: {'ASCII'},
        );
        final result = TextNormalization.normalizeForConstraints(
          'Very long café text with special characters',
          semantics,
        );
        expect(result, equals('Very long caf? '));
        expect(result.length, equals(15));
      });

      test('handles UTF-8 encoding without changes', () {
        const semantics = TagSemantics(allowedEncodings: {'UTF-8'});
        final result = TextNormalization.normalizeForConstraints(
          'Café with émojis 🎵',
          semantics,
        );
        expect(result, equals('Café with émojis 🎵'));
      });

      test('handles multiple allowed encodings', () {
        const semantics = TagSemantics(allowedEncodings: {'UTF-8', 'ISO-8859-1'});
        final result = TextNormalization.normalizeForConstraints(
          'Café text',
          semantics,
        );
        // Should use ISO-8859-1 as it's more restrictive but still compatible
        expect(result, equals('Café text'));
      });
    });

    group('normalizeForEncoding', () {
      test('handles ASCII encoding', () {
        final result = TextNormalization.normalizeForEncoding(
          'Hello Café 🎵',
          TextEncoding.ascii,
        );
        expect(result, equals('Hello Caf? ?'));
      });

      test('handles ASCII encoding with custom replacement', () {
        final result = TextNormalization.normalizeForEncoding(
          'Hello Café 🎵',
          TextEncoding.ascii,
          replacementChar: '_',
        );
        expect(result, equals('Hello Caf_ _'));
      });

      test('handles ISO-8859-1 encoding', () {
        final result = TextNormalization.normalizeForEncoding(
          'Café naïve résumé 🎵',
          TextEncoding.iso88591,
        );
        expect(result, equals('Café naïve résumé ?'));
      });

      test('handles UTF-8 encoding without changes', () {
        const originalText = 'Café with émojis 🎵 and 中文';
        final result = TextNormalization.normalizeForEncoding(
          originalText,
          TextEncoding.utf8,
        );
        expect(result, equals(originalText));
      });

      test('handles UTF-16 encodings without changes', () {
        const originalText = 'Café with émojis 🎵 and 中文';

        expect(
          TextNormalization.normalizeForEncoding(originalText, TextEncoding.utf16),
          equals(originalText),
        );
        expect(
          TextNormalization.normalizeForEncoding(originalText, TextEncoding.utf16le),
          equals(originalText),
        );
        expect(
          TextNormalization.normalizeForEncoding(originalText, TextEncoding.utf16be),
          equals(originalText),
        );
      });

      test('preserves ASCII characters in all encodings', () {
        const asciiText = 'Hello World 123';

        expect(
          TextNormalization.normalizeForEncoding(asciiText, TextEncoding.ascii),
          equals(asciiText),
        );
        expect(
          TextNormalization.normalizeForEncoding(asciiText, TextEncoding.iso88591),
          equals(asciiText),
        );
        expect(
          TextNormalization.normalizeForEncoding(asciiText, TextEncoding.utf8),
          equals(asciiText),
        );
      });
    });

    group('normalizeVorbisKey', () {
      test('converts to uppercase', () {
        expect(TextNormalization.normalizeVorbisKey('artist'), equals('ARTIST'));
        expect(TextNormalization.normalizeVorbisKey('Title'), equals('TITLE'));
        expect(TextNormalization.normalizeVorbisKey('ALBUM'), equals('ALBUM'));
      });

      test('trims whitespace', () {
        expect(TextNormalization.normalizeVorbisKey('  artist  '), equals('ARTIST'));
        expect(TextNormalization.normalizeVorbisKey('\ttitle\n'), equals('TITLE'));
      });

      test('handles valid custom keys', () {
        expect(TextNormalization.normalizeVorbisKey('my_custom_field'), equals('MY_CUSTOM_FIELD'));
        expect(TextNormalization.normalizeVorbisKey('field123'), equals('FIELD123'));
        expect(TextNormalization.normalizeVorbisKey('A_B_C_123'), equals('A_B_C_123'));
      });

      test('throws on empty key', () {
        expect(
          () => TextNormalization.normalizeVorbisKey(''),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TextNormalization.normalizeVorbisKey('   '),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on invalid characters', () {
        expect(
          () => TextNormalization.normalizeVorbisKey('invalid-key'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TextNormalization.normalizeVorbisKey('invalid.key'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TextNormalization.normalizeVorbisKey('invalid key'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TextNormalization.normalizeVorbisKey('invalid@key'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('provides helpful error messages', () {
        try {
          TextNormalization.normalizeVorbisKey('invalid-key');
          fail('Should have thrown ArgumentError');
        } catch (e) {
          expect(e.toString(), contains('invalid-key'));
          expect(e.toString(), contains('letters, numbers, and underscores'));
        }
      });
    });

    group('getEncodedByteLength', () {
      test('calculates ASCII byte length', () {
        expect(
          TextNormalization.getEncodedByteLength('Hello', TextEncoding.ascii),
          equals(5),
        );
      });

      test('calculates UTF-8 byte length', () {
        expect(
          TextNormalization.getEncodedByteLength('Hello', TextEncoding.utf8),
          equals(5),
        );
        expect(
          TextNormalization.getEncodedByteLength('Café', TextEncoding.utf8),
          equals(5), // é is 2 bytes in UTF-8
        );
        expect(
          TextNormalization.getEncodedByteLength('🎵', TextEncoding.utf8),
          equals(4), // Emoji is 4 bytes in UTF-8
        );
      });

      test('calculates UTF-16 byte length', () {
        expect(
          TextNormalization.getEncodedByteLength('Hello', TextEncoding.utf16),
          equals(10), // 2 bytes per character
        );
        expect(
          TextNormalization.getEncodedByteLength('Café', TextEncoding.utf16),
          equals(8), // 4 characters × 2 bytes
        );
      });

      test('includes BOM when requested', () {
        expect(
          TextNormalization.getEncodedByteLength('Hello', TextEncoding.utf8, includeBom: true),
          equals(8), // 5 + 3 for UTF-8 BOM
        );
        expect(
          TextNormalization.getEncodedByteLength('Hello', TextEncoding.utf16, includeBom: true),
          equals(12), // 10 + 2 for UTF-16 BOM
        );
      });
    });

    group('truncateToByteLength', () {
      test('returns text as-is when it fits', () {
        final result = TextNormalization.truncateToByteLength(
          'Hello',
          10,
          TextEncoding.utf8,
        );
        expect(result, equals('Hello'));
      });

      test('truncates ASCII text to byte limit', () {
        final result = TextNormalization.truncateToByteLength(
          'Hello World',
          5,
          TextEncoding.ascii,
        );
        expect(result, equals('Hello'));
      });

      test('truncates UTF-8 text considering multi-byte characters', () {
        final result = TextNormalization.truncateToByteLength(
          'Café World',
          5,
          TextEncoding.utf8,
        );
        expect(result, equals('Café')); // 'Café' is exactly 5 bytes
      });

      test('handles emoji truncation in UTF-8', () {
        final result = TextNormalization.truncateToByteLength(
          'Hi 🎵 World',
          6,
          TextEncoding.utf8,
        );
        expect(result, equals('Hi ')); // Can't fit the 4-byte emoji
      });

      test('truncates UTF-16 text', () {
        final result = TextNormalization.truncateToByteLength(
          'Hello World',
          10,
          TextEncoding.utf16,
        );
        expect(result, equals('Hello')); // 5 characters × 2 bytes = 10 bytes
      });

      test('preserves words when requested and reasonable', () {
        final result = TextNormalization.truncateToByteLength(
          'Hello World Test',
          12,
          TextEncoding.ascii,
          preserveWords: true,
        );
        expect(result, equals('Hello World')); // Stops at word boundary
      });

      test('ignores word preservation when it would remove too much', () {
        final result = TextNormalization.truncateToByteLength(
          'Verylongword short',
          10,
          TextEncoding.ascii,
          preserveWords: true,
        );
        expect(result, equals('Verylongwo')); // Uses character boundary
      });

      test('handles empty input', () {
        expect(
          TextNormalization.truncateToByteLength('', 10, TextEncoding.utf8),
          equals(''),
        );
      });

      test('handles zero byte limit', () {
        expect(
          TextNormalization.truncateToByteLength('Hello', 0, TextEncoding.utf8),
          equals(''),
        );
      });

      test('handles negative byte limit', () {
        expect(
          TextNormalization.truncateToByteLength('Hello', -1, TextEncoding.utf8),
          equals(''),
        );
      });
    });

    group('edge cases and integration', () {
      test('handles complex Unicode normalization', () {
        const complexText = 'Naïve café résumé with 中文 and 🎵🎶';

        // Test different encoding constraints
        final asciiResult = TextNormalization.normalizeForEncoding(
          complexText,
          TextEncoding.ascii,
        );
        expect(asciiResult, equals('Na?ve caf? r?sum? with ?? and ??'));

        final latin1Result = TextNormalization.normalizeForEncoding(
          complexText,
          TextEncoding.iso88591,
        );
        expect(latin1Result, equals('Naïve café résumé with ?? and ??'));
      });

      test('combines normalization with constraints', () {
        const semantics = TagSemantics(
          maxTextLength: 20,
          allowedEncodings: {'ASCII'},
        );

        final result = TextNormalization.normalizeForConstraints(
          '  Very long café text with special characters  ',
          semantics,
          preserveWords: true,
        );

        expect(result, equals('Very long caf? text'));
        expect(result.length, lessThanOrEqualTo(20));
        // Should be ASCII-compatible
        expect(result.codeUnits.every((c) => c <= 127), isTrue);
      });

      test('handles byte-based truncation with encoding normalization', () {
        // Start with text that has multi-byte characters
        const originalText = 'Café with émojis 🎵';

        // First normalize for ASCII
        final asciiText = TextNormalization.normalizeForEncoding(
          originalText,
          TextEncoding.ascii,
        );

        // Then truncate to byte length
        final result = TextNormalization.truncateToByteLength(
          asciiText,
          15,
          TextEncoding.ascii,
        );

        expect(result, equals('Caf? with ?moji'));
        expect(result.length, equals(15));
      });
    });
  });
}
