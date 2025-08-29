import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('UnsupportedFormatException', () {
    group('constructor', () {
      test('creates exception with message only', () {
        const exception = UnsupportedFormatException('Unsupported format: WMA');

        expect(exception.message, equals('Unsupported format: WMA'));
        expect(exception.context, isNull);
      });

      test('creates exception with message and context', () {
        const exception = UnsupportedFormatException('Unsupported format: WMA', context: 'file: audio.wma, size: 1024 bytes');

        expect(exception.message, equals('Unsupported format: WMA'));
        expect(exception.context, equals('file: audio.wma, size: 1024 bytes'));
      });

      test('creates exception with empty message', () {
        const exception = UnsupportedFormatException('');

        expect(exception.message, equals(''));
        expect(exception.context, isNull);
      });

      test('creates exception with empty context', () {
        const exception = UnsupportedFormatException('Format not recognized', context: '');

        expect(exception.message, equals('Format not recognized'));
        expect(exception.context, equals(''));
      });
    });

    group('inheritance', () {
      test('extends PhonicException', () {
        const exception = UnsupportedFormatException('Test message');

        expect(exception, isA<PhonicException>());
        expect(exception, isA<Exception>());
      });

      test('implements Exception interface', () {
        const exception = UnsupportedFormatException('Test message');

        expect(exception, isA<Exception>());
      });

      test('is a final class', () {
        // This test ensures the class is marked as final
        // The compiler will enforce this, but we test the type hierarchy
        const exception = UnsupportedFormatException('Test message');

        expect(exception.runtimeType.toString(), equals('UnsupportedFormatException'));
      });
    });

    group('toString', () {
      test('formats message without context', () {
        const exception = UnsupportedFormatException('Format not supported');

        expect(exception.toString(), equals('UnsupportedFormatException: Format not supported'));
      });

      test('formats message with context', () {
        const exception = UnsupportedFormatException('Format not supported', context: 'file: test.wma');

        expect(exception.toString(), equals('UnsupportedFormatException: Format not supported (Context: file: test.wma)'));
      });

      test('handles empty message', () {
        const exception = UnsupportedFormatException('');

        expect(exception.toString(), equals('UnsupportedFormatException: '));
      });

      test('handles empty context', () {
        const exception = UnsupportedFormatException('Format error', context: '');

        expect(exception.toString(), equals('UnsupportedFormatException: Format error (Context: )'));
      });

      test('handles special characters in message', () {
        const exception = UnsupportedFormatException('Format "WMA" not supported: 100% incompatible');

        expect(exception.toString(), equals('UnsupportedFormatException: Format "WMA" not supported: 100% incompatible'));
      });

      test('handles special characters in context', () {
        const exception = UnsupportedFormatException('Format error', context: 'file: "my song.wma", path: C:\\Music\\file.wma');

        expect(exception.toString(), equals('UnsupportedFormatException: Format error (Context: file: "my song.wma", path: C:\\Music\\file.wma)'));
      });
    });

    group('equality and immutability', () {
      test('instances with same values are equal', () {
        const exception1 = UnsupportedFormatException('Same message', context: 'same context');
        const exception2 = UnsupportedFormatException('Same message', context: 'same context');

        // Note: Exception classes don't typically implement equality,
        // but we test that the properties are accessible and immutable
        expect(exception1.message, equals(exception2.message));
        expect(exception1.context, equals(exception2.context));
      });

      test('message property is immutable', () {
        const exception = UnsupportedFormatException('Original message');

        // The message field is final, so this test just verifies access
        expect(exception.message, equals('Original message'));

        // Attempting to modify would cause a compile error:
        // exception.message = 'New message'; // This would not compile
      });

      test('context property is immutable', () {
        const exception = UnsupportedFormatException('Message', context: 'Original context');

        // The context field is final, so this test just verifies access
        expect(exception.context, equals('Original context'));

        // Attempting to modify would cause a compile error:
        // exception.context = 'New context'; // This would not compile
      });
    });

    group('real-world scenarios', () {
      test('handles typical format detection failure', () {
        const exception = UnsupportedFormatException('No format strategy available for detected format', context: 'file: unknown.xyz, signature: 0x4D546864');

        expect(exception.message, contains('format strategy'));
        expect(exception.context, contains('unknown.xyz'));
        expect(exception.toString(), contains('UnsupportedFormatException'));
      });

      test('handles codec unavailability', () {
        const exception = UnsupportedFormatException('Required codec not available: AAC', context: 'container: MP4, codec: AAC-LC');

        expect(exception.message, contains('codec not available'));
        expect(exception.context, contains('AAC-LC'));
      });

      test('handles corrupted format detection', () {
        const exception = UnsupportedFormatException('File format corrupted beyond recognition', context: 'file: corrupted.mp3, attempted: ID3v2, MP3, ID3v1');

        expect(exception.message, contains('corrupted'));
        expect(exception.context, contains('attempted'));
      });

      test('handles missing format headers', () {
        const exception = UnsupportedFormatException(
          'No recognizable format headers found',
          context: 'file: headerless.bin, size: 2048 bytes, scanned: 512 bytes',
        );

        expect(exception.message, contains('headers'));
        expect(exception.context, contains('scanned'));
      });
    });

    group('exception throwing and catching', () {
      test('can be thrown and caught as UnsupportedFormatException', () {
        expect(() => throw const UnsupportedFormatException('Test exception'), throwsA(isA<UnsupportedFormatException>()));
      });

      test('can be caught as PhonicException', () {
        expect(() => throw const UnsupportedFormatException('Test exception'), throwsA(isA<PhonicException>()));
      });

      test('can be caught as Exception', () {
        expect(() => throw const UnsupportedFormatException('Test exception'), throwsA(isA<Exception>()));
      });

      test('preserves message and context when caught', () {
        const originalMessage = 'Original error message';
        const originalContext = 'Original context';

        try {
          throw const UnsupportedFormatException(originalMessage, context: originalContext);
        } on UnsupportedFormatException catch (e) {
          expect(e.message, equals(originalMessage));
          expect(e.context, equals(originalContext));
        }
      });
    });
  });
}
