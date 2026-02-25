import 'package:phonic/src/exceptions/phonic_exception.dart';
import 'package:test/test.dart';

/// Concrete implementation of PhonicException for testing purposes.
class TestPhonicException extends PhonicException {
  const TestPhonicException(super.message, {super.context});
}

/// Another concrete implementation to test inheritance behavior.
class AnotherTestException extends PhonicException {
  const AnotherTestException(super.message, {super.context});
}

void main() {
  group('PhonicException', () {
    group('constructor', () {
      test('creates instance with message only', () {
        const exception = TestPhonicException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.context, isNull);
      });

      test('creates instance with message and context', () {
        const exception = TestPhonicException(
          'Test error message',
          context: 'file: test.mp3, offset: 1024',
        );

        expect(exception.message, equals('Test error message'));
        expect(exception.context, equals('file: test.mp3, offset: 1024'));
      });

      test('creates instance with empty message', () {
        const exception = TestPhonicException('');

        expect(exception.message, equals(''));
        expect(exception.context, isNull);
      });

      test('creates instance with empty context', () {
        const exception = TestPhonicException(
          'Test message',
          context: '',
        );

        expect(exception.message, equals('Test message'));
        expect(exception.context, equals(''));
      });

      test('handles special characters in message', () {
        const message = 'Error with special chars: àáâãäåæçèéêë 中文 🎵';
        const exception = TestPhonicException(message);

        expect(exception.message, equals(message));
      });

      test('handles special characters in context', () {
        const context = 'file: /path/with/üñíçødé/音楽.mp3';
        const exception = TestPhonicException(
          'Test message',
          context: context,
        );

        expect(exception.context, equals(context));
      });

      test('handles multiline message', () {
        const message = 'Line 1\nLine 2\nLine 3';
        const exception = TestPhonicException(message);

        expect(exception.message, equals(message));
      });

      test('handles multiline context', () {
        const context = 'Context line 1\nContext line 2\nContext line 3';
        const exception = TestPhonicException(
          'Test message',
          context: context,
        );

        expect(exception.context, equals(context));
      });
    });

    group('toString', () {
      test('returns formatted string without context', () {
        const exception = TestPhonicException('Failed to parse audio file');

        expect(
          exception.toString(),
          equals('PhonicException: Failed to parse audio file'),
        );
      });

      test('returns formatted string with context', () {
        const exception = TestPhonicException(
          'Failed to parse audio file',
          context: 'file: /path/to/audio.mp3, offset: 1024',
        );

        expect(
          exception.toString(),
          equals('PhonicException: Failed to parse audio file (Context: file: /path/to/audio.mp3, offset: 1024)'),
        );
      });

      test('handles empty message without context', () {
        const exception = TestPhonicException('');

        expect(
          exception.toString(),
          equals('PhonicException: '),
        );
      });

      test('handles empty message with context', () {
        const exception = TestPhonicException(
          '',
          context: 'some context',
        );

        expect(
          exception.toString(),
          equals('PhonicException:  (Context: some context)'),
        );
      });

      test('handles empty context', () {
        const exception = TestPhonicException(
          'Test message',
          context: '',
        );

        expect(
          exception.toString(),
          equals('PhonicException: Test message (Context: )'),
        );
      });

      test('handles special characters in output', () {
        const exception = TestPhonicException(
          'Error with üñíçødé characters',
          context: 'file: /path/音楽.mp3',
        );

        expect(
          exception.toString(),
          equals('PhonicException: Error with üñíçødé characters (Context: file: /path/音楽.mp3)'),
        );
      });

      test('handles multiline message and context', () {
        const exception = TestPhonicException(
          'Line 1\nLine 2',
          context: 'Context 1\nContext 2',
        );

        expect(
          exception.toString(),
          equals('PhonicException: Line 1\nLine 2 (Context: Context 1\nContext 2)'),
        );
      });

      test('different exception types show PhonicException in toString', () {
        const exception1 = TestPhonicException('Test message 1');
        const exception2 = AnotherTestException('Test message 2');

        // Both should show "PhonicException" in toString since it's the base class
        expect(exception1.toString(), startsWith('PhonicException:'));
        expect(exception2.toString(), startsWith('PhonicException:'));
      });
    });

    group('inheritance', () {
      test('implements Exception interface', () {
        const exception = TestPhonicException('Test message');

        expect(exception, isA<Exception>());
      });

      test('can be caught as Exception', () {
        Exception? caughtException;

        try {
          throw const TestPhonicException('Test error');
        } on Exception catch (e) {
          caughtException = e;
        }

        expect(caughtException, isNotNull);
        expect(caughtException, isA<TestPhonicException>());
        expect(caughtException, isA<PhonicException>());
      });

      test('can be caught as PhonicException', () {
        PhonicException? caughtException;

        try {
          throw const TestPhonicException('Test error');
        } on PhonicException catch (e) {
          caughtException = e;
        }

        expect(caughtException, isNotNull);
        expect(caughtException, isA<TestPhonicException>());
        expect(caughtException.message, equals('Test error'));
      });

      test('different concrete implementations are distinct types', () {
        const exception1 = TestPhonicException('Message 1');
        const exception2 = AnotherTestException('Message 2');

        expect(exception1.runtimeType, isNot(equals(exception2.runtimeType)));
        expect(exception1, isA<PhonicException>());
        expect(exception2, isA<PhonicException>());
      });

      test('subclass can add additional fields', () {
        // This test demonstrates that subclasses can extend functionality
        const exception = TestPhonicExceptionWithCode(
          'Test message',
          errorCode: 404,
        );

        expect(exception.message, equals('Test message'));
        expect(exception.errorCode, equals(404));
        expect(exception, isA<PhonicException>());
      });
    });

    group('immutability', () {
      test('message field is final', () {
        const exception = TestPhonicException('Test message');

        // This should compile without error, confirming field is final
        expect(exception.message, equals('Test message'));
      });

      test('context field is final', () {
        const exception = TestPhonicException(
          'Test message',
          context: 'Test context',
        );

        // This should compile without error, confirming field is final
        expect(exception.context, equals('Test context'));
      });

      test('const constructor creates compile-time constants', () {
        // This should compile as a const expression
        const exception = TestPhonicException(
          'Compile-time constant message',
          context: 'Compile-time constant context',
        );

        expect(exception.message, equals('Compile-time constant message'));
        expect(exception.context, equals('Compile-time constant context'));
      });
    });

    group('real-world usage scenarios', () {
      test('file parsing error with byte offset', () {
        const exception = TestPhonicException(
          'Invalid ID3v2 header detected',
          context: 'file: /music/song.mp3, offset: 0, expected: ID3, found: MP3',
        );

        expect(exception.message, equals('Invalid ID3v2 header detected'));
        expect(exception.context, contains('offset: 0'));
        expect(exception.context, contains('song.mp3'));
      });

      test('container format error', () {
        const exception = TestPhonicException(
          'Unsupported container format',
          context: 'file: audio.wav, detected format: WAV, supported: [MP3, FLAC, OGG, MP4]',
        );

        expect(exception.message, equals('Unsupported container format'));
        expect(exception.context, contains('WAV'));
      });

      test('tag validation error', () {
        const exception = TestPhonicException(
          'Tag validation failed for rating: value out of range',
          context: 'tag: RatingTag, value: 150, valid range: 0-100',
        );

        expect(exception.message, contains('Tag validation failed'));
        expect(exception.context, contains('value: 150'));
      });

      test('memory or I/O error', () {
        const exception = TestPhonicException(
          'Failed to load artwork data',
          context: 'file: album.mp3, artwork size: 5MB, available memory: 2MB',
        );

        expect(exception.message, equals('Failed to load artwork data'));
        expect(exception.context, contains('5MB'));
      });

      test('corruption detection', () {
        const exception = TestPhonicException(
          'Corrupted frame detected in ID3v2 tag',
          context: 'file: corrupted.mp3, frame: APIC, expected size: 1024, actual size: 512',
        );

        expect(exception.message, contains('Corrupted frame detected'));
        expect(exception.context, contains('APIC'));
      });
    });

    group('error handling patterns', () {
      test('can be used in try-catch blocks', () {
        String? errorMessage;
        String? errorContext;

        try {
          throw const TestPhonicException(
            'Test error',
            context: 'Test context',
          );
        } on PhonicException catch (e) {
          errorMessage = e.message;
          errorContext = e.context;
        }

        expect(errorMessage, equals('Test error'));
        expect(errorContext, equals('Test context'));
      });

      test('can be rethrown with additional context', () {
        PhonicException? finalException;

        try {
          try {
            throw const TestPhonicException('Original error');
          } on PhonicException catch (e) {
            // Rethrow with additional context
            throw TestPhonicException(
              e.message,
              context: 'Original context: ${e.context ?? "none"}, Additional: operation failed',
            );
          }
        } on PhonicException catch (e) {
          finalException = e;
        }

        expect(finalException, isNotNull);
        expect(finalException.message, equals('Original error'));
        expect(finalException.context, contains('Additional: operation failed'));
      });

      test('supports logging and debugging workflows', () {
        const exception = TestPhonicException(
          'Debug test error',
          context: 'debug info: step 1 completed, step 2 failed at validation',
        );

        // Simulate logging
        final logEntry = {
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'ERROR',
          'message': exception.message,
          'context': exception.context,
          'exception_type': exception.runtimeType.toString(),
        };

        expect(logEntry['message'], equals('Debug test error'));
        expect(logEntry['context'], contains('step 2 failed'));
        expect(logEntry['exception_type'], equals('TestPhonicException'));
      });
    });
  });
}

/// Extended test exception class to demonstrate inheritance capabilities.
class TestPhonicExceptionWithCode extends PhonicException {
  final int errorCode;

  const TestPhonicExceptionWithCode(
    super.message, {
    required this.errorCode,
    super.context,
  });
}
