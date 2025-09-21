import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/exceptions/phonic_exception.dart';
import 'package:test/test.dart';

void main() {
  group('CorruptedContainerException', () {
    group('constructor', () {
      test('creates exception with message only', () {
        const exception = CorruptedContainerException('Invalid frame header detected');

        expect(exception.message, equals('Invalid frame header detected'));
        expect(exception.context, isNull);
        expect(exception.byteOffset, isNull);
      });

      test('creates exception with message and byteOffset', () {
        const exception = CorruptedContainerException('Invalid frame header detected', byteOffset: 1024);

        expect(exception.message, equals('Invalid frame header detected'));
        expect(exception.context, isNull);
        expect(exception.byteOffset, equals(1024));
      });

      test('creates exception with message and context', () {
        const exception = CorruptedContainerException(
          'Invalid frame header detected',
          context: 'file: corrupted.mp3, frame: TIT2',
        );

        expect(exception.message, equals('Invalid frame header detected'));
        expect(exception.context, equals('file: corrupted.mp3, frame: TIT2'));
        expect(exception.byteOffset, isNull);
      });

      test('creates exception with all parameters', () {
        const exception = CorruptedContainerException(
          'Invalid frame header detected',
          byteOffset: 2048,
          context: 'file: corrupted.mp3, container: ID3v2.4, frame: APIC',
        );

        expect(exception.message, equals('Invalid frame header detected'));
        expect(exception.context, equals('file: corrupted.mp3, container: ID3v2.4, frame: APIC'));
        expect(exception.byteOffset, equals(2048));
      });

      test('creates exception with zero byteOffset', () {
        const exception = CorruptedContainerException('Header corruption at file start', byteOffset: 0);

        expect(exception.message, equals('Header corruption at file start'));
        expect(exception.byteOffset, equals(0));
      });

      test('creates exception with large byteOffset', () {
        const exception = CorruptedContainerException('Corruption near end of file', byteOffset: 999999999);

        expect(exception.message, equals('Corruption near end of file'));
        expect(exception.byteOffset, equals(999999999));
      });

      test('creates exception with empty message', () {
        const exception = CorruptedContainerException('');

        expect(exception.message, equals(''));
        expect(exception.context, isNull);
        expect(exception.byteOffset, isNull);
      });

      test('creates exception with empty context', () {
        const exception = CorruptedContainerException(
          'Container corruption detected',
          context: '',
        );

        expect(exception.message, equals('Container corruption detected'));
        expect(exception.context, equals(''));
        expect(exception.byteOffset, isNull);
      });
    });

    group('inheritance', () {
      test('extends PhonicException', () {
        const exception = CorruptedContainerException('Test message');

        expect(exception, isA<PhonicException>());
        expect(exception, isA<Exception>());
      });

      test('implements Exception interface', () {
        const exception = CorruptedContainerException('Test message');

        expect(exception, isA<Exception>());
      });

      test('is a final class', () {
        // This test ensures the class is marked as final
        // The compiler will enforce this, but we test the type hierarchy
        const exception = CorruptedContainerException('Test message');

        expect(exception.runtimeType.toString(), equals('CorruptedContainerException'));
      });

      test('inherits PhonicException properties', () {
        const exception = CorruptedContainerException(
          'Inherited test',
          context: 'test context',
        );

        // Should have access to base class properties
        expect(exception.message, equals('Inherited test'));
        expect(exception.context, equals('test context'));
      });
    });

    group('toString', () {
      test('formats message without byteOffset or context', () {
        const exception = CorruptedContainerException('Container corruption detected');

        expect(exception.toString(), equals('CorruptedContainerException: Container corruption detected'));
      });

      test('formats message with byteOffset but no context', () {
        const exception = CorruptedContainerException('Container corruption detected', byteOffset: 1024);

        expect(exception.toString(), equals('CorruptedContainerException: Container corruption detected at byte 1024'));
      });

      test('formats message with context but no byteOffset', () {
        const exception = CorruptedContainerException(
          'Container corruption detected',
          context: 'file: test.mp3',
        );

        expect(exception.toString(), equals('CorruptedContainerException: Container corruption detected (Context: file: test.mp3)'));
      });

      test('formats message with both byteOffset and context', () {
        const exception = CorruptedContainerException(
          'Container corruption detected',
          byteOffset: 2048,
          context: 'file: test.mp3, frame: APIC',
        );

        expect(
          exception.toString(),
          equals('CorruptedContainerException: Container corruption detected at byte 2048 (Context: file: test.mp3, frame: APIC)'),
        );
      });

      test('handles zero byteOffset', () {
        const exception = CorruptedContainerException('Header corruption', byteOffset: 0);

        expect(exception.toString(), equals('CorruptedContainerException: Header corruption at byte 0'));
      });

      test('handles large byteOffset', () {
        const exception = CorruptedContainerException('Late corruption', byteOffset: 999999999);

        expect(exception.toString(), equals('CorruptedContainerException: Late corruption at byte 999999999'));
      });

      test('handles empty message with byteOffset', () {
        const exception = CorruptedContainerException('', byteOffset: 512);

        expect(exception.toString(), equals('CorruptedContainerException:  at byte 512'));
      });

      test('handles empty message with context', () {
        const exception = CorruptedContainerException('', context: 'some context');

        expect(exception.toString(), equals('CorruptedContainerException:  (Context: some context)'));
      });

      test('handles empty context with byteOffset', () {
        const exception = CorruptedContainerException(
          'Corruption detected',
          byteOffset: 256,
          context: '',
        );

        expect(exception.toString(), equals('CorruptedContainerException: Corruption detected at byte 256 (Context: )'));
      });

      test('handles special characters in message', () {
        const exception = CorruptedContainerException('Frame "TIT2" corrupted: 100% invalid');

        expect(exception.toString(), equals('CorruptedContainerException: Frame "TIT2" corrupted: 100% invalid'));
      });

      test('handles special characters in context', () {
        const exception = CorruptedContainerException(
          'Corruption detected',
          context: 'file: "my song.mp3", path: C:\\Music\\file.mp3',
        );

        expect(
          exception.toString(),
          equals('CorruptedContainerException: Corruption detected (Context: file: "my song.mp3", path: C:\\Music\\file.mp3)'),
        );
      });

      test('handles multiline message and context', () {
        const exception = CorruptedContainerException(
          'Line 1\nLine 2',
          byteOffset: 1024,
          context: 'Context 1\nContext 2',
        );

        expect(
          exception.toString(),
          equals('CorruptedContainerException: Line 1\nLine 2 at byte 1024 (Context: Context 1\nContext 2)'),
        );
      });
    });

    group('byteOffset property', () {
      test('stores null byteOffset correctly', () {
        const exception = CorruptedContainerException('Test message');

        expect(exception.byteOffset, isNull);
      });

      test('stores zero byteOffset correctly', () {
        const exception = CorruptedContainerException('Test message', byteOffset: 0);

        expect(exception.byteOffset, equals(0));
      });

      test('stores positive byteOffset correctly', () {
        const exception = CorruptedContainerException('Test message', byteOffset: 12345);

        expect(exception.byteOffset, equals(12345));
      });

      test('stores large byteOffset correctly', () {
        const exception = CorruptedContainerException('Test message', byteOffset: 0x7FFFFFFFFFFFFFFF);

        expect(exception.byteOffset, equals(0x7FFFFFFFFFFFFFFF));
      });

      test('byteOffset is immutable', () {
        const exception = CorruptedContainerException('Test message', byteOffset: 1024);

        // The byteOffset field is final, so this test just verifies access
        expect(exception.byteOffset, equals(1024));

        // Attempting to modify would cause a compile error:
        // exception.byteOffset = 2048; // This would not compile
      });
    });

    group('equality and immutability', () {
      test('instances with same values have same properties', () {
        const exception1 = CorruptedContainerException(
          'Same message',
          byteOffset: 1024,
          context: 'same context',
        );
        const exception2 = CorruptedContainerException(
          'Same message',
          byteOffset: 1024,
          context: 'same context',
        );

        // Note: Exception classes don't typically implement equality,
        // but we test that the properties are accessible and immutable
        expect(exception1.message, equals(exception2.message));
        expect(exception1.context, equals(exception2.context));
        expect(exception1.byteOffset, equals(exception2.byteOffset));
      });

      test('all properties are immutable', () {
        const exception = CorruptedContainerException(
          'Original message',
          byteOffset: 2048,
          context: 'Original context',
        );

        // All fields are final, so this test just verifies access
        expect(exception.message, equals('Original message'));
        expect(exception.context, equals('Original context'));
        expect(exception.byteOffset, equals(2048));

        // Attempting to modify would cause compile errors:
        // exception.message = 'New message'; // This would not compile
        // exception.context = 'New context'; // This would not compile
        // exception.byteOffset = 4096; // This would not compile
      });
    });

    group('real-world scenarios', () {
      test('handles ID3v2 header corruption', () {
        const exception = CorruptedContainerException(
          'Invalid ID3v2 header: expected "ID3", found "MP3"',
          byteOffset: 0,
          context: 'file: corrupted.mp3, container: ID3v2',
        );

        expect(exception.message, contains('ID3v2 header'));
        expect(exception.byteOffset, equals(0));
        expect(exception.context, contains('corrupted.mp3'));
        expect(exception.toString(), contains('at byte 0'));
      });

      test('handles frame size mismatch', () {
        const exception = CorruptedContainerException(
          'Frame size exceeds remaining container data',
          byteOffset: 2048,
          context: 'file: song.mp3, frame: APIC, declared size: 1024, remaining: 512',
        );

        expect(exception.message, contains('Frame size exceeds'));
        expect(exception.byteOffset, equals(2048));
        expect(exception.context, contains('APIC'));
      });

      test('handles MP4 atom corruption', () {
        const exception = CorruptedContainerException(
          'Invalid MP4 atom header: size field corrupted',
          byteOffset: 4096,
          context: 'file: track.m4a, atom: moov, expected size: > 8, found: 0',
        );

        expect(exception.message, contains('MP4 atom'));
        expect(exception.byteOffset, equals(4096));
        expect(exception.context, contains('moov'));
      });

      test('handles Vorbis comment corruption', () {
        const exception = CorruptedContainerException(
          'Vorbis comment block truncated',
          byteOffset: 1536,
          context: 'file: music.flac, block type: VORBIS_COMMENT, expected length: 256, found: 128',
        );

        expect(exception.message, contains('Vorbis comment'));
        expect(exception.byteOffset, equals(1536));
        expect(exception.context, contains('VORBIS_COMMENT'));
      });

      test('handles text encoding corruption', () {
        const exception = CorruptedContainerException(
          'Invalid UTF-8 sequence in text frame',
          byteOffset: 512,
          context: 'file: tagged.mp3, frame: TIT2, encoding: UTF-8, invalid bytes: [0xFF, 0xFE]',
        );

        expect(exception.message, contains('UTF-8 sequence'));
        expect(exception.byteOffset, equals(512));
        expect(exception.context, contains('TIT2'));
      });

      test('handles file truncation', () {
        const exception = CorruptedContainerException(
          'Unexpected end of file during frame parsing',
          byteOffset: 8192,
          context: 'file: incomplete.mp3, expected: 1024 more bytes, file size: 8192',
        );

        expect(exception.message, contains('end of file'));
        expect(exception.byteOffset, equals(8192));
        expect(exception.context, contains('incomplete.mp3'));
      });

      test('handles synchronization loss', () {
        const exception = CorruptedContainerException(
          'Lost frame synchronization: unable to find next frame boundary',
          byteOffset: 3072,
          context: 'file: damaged.mp3, last valid frame: TPE1, searched: 512 bytes',
        );

        expect(exception.message, contains('synchronization'));
        expect(exception.byteOffset, equals(3072));
        expect(exception.context, contains('TPE1'));
      });

      test('handles unknown corruption without offset', () {
        const exception = CorruptedContainerException(
          'General container corruption detected',
          context: 'file: mystery.mp3, multiple validation failures',
        );

        expect(exception.message, contains('General container'));
        expect(exception.byteOffset, isNull);
        expect(exception.context, contains('mystery.mp3'));
        expect(exception.toString(), isNot(contains('at byte')));
      });
    });

    group('exception throwing and catching', () {
      test('can be thrown and caught as CorruptedContainerException', () {
        expect(
          () => throw const CorruptedContainerException('Test exception'),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('can be caught as PhonicException', () {
        expect(
          () => throw const CorruptedContainerException('Test exception'),
          throwsA(isA<PhonicException>()),
        );
      });

      test('can be caught as Exception', () {
        expect(
          () => throw const CorruptedContainerException('Test exception'),
          throwsA(isA<Exception>()),
        );
      });

      test('preserves all properties when caught', () {
        const originalMessage = 'Original error message';
        const originalOffset = 1024;
        const originalContext = 'Original context';

        try {
          throw const CorruptedContainerException(
            originalMessage,
            byteOffset: originalOffset,
            context: originalContext,
          );
        } on CorruptedContainerException catch (e) {
          expect(e.message, equals(originalMessage));
          expect(e.byteOffset, equals(originalOffset));
          expect(e.context, equals(originalContext));
        }
      });

      test('can be caught as base class and properties accessed', () {
        const originalMessage = 'Base class test';
        const originalOffset = 2048;
        const originalContext = 'Base context';

        try {
          throw const CorruptedContainerException(
            originalMessage,
            byteOffset: originalOffset,
            context: originalContext,
          );
        } on PhonicException catch (e) {
          expect(e.message, equals(originalMessage));
          expect(e.context, equals(originalContext));

          // Cast to access specific properties
          if (e is CorruptedContainerException) {
            expect(e.byteOffset, equals(originalOffset));
          }
        }
      });
    });

    group('offset tracking scenarios', () {
      test('tracks corruption at file beginning', () {
        const exception = CorruptedContainerException(
          'File signature corruption',
          byteOffset: 0,
        );

        expect(exception.byteOffset, equals(0));
        expect(exception.toString(), contains('at byte 0'));
      });

      test('tracks corruption in middle of file', () {
        const exception = CorruptedContainerException(
          'Frame boundary corruption',
          byteOffset: 16384,
        );

        expect(exception.byteOffset, equals(16384));
        expect(exception.toString(), contains('at byte 16384'));
      });

      test('tracks corruption near end of file', () {
        const exception = CorruptedContainerException(
          'Tail corruption detected',
          byteOffset: 999999,
        );

        expect(exception.byteOffset, equals(999999));
        expect(exception.toString(), contains('at byte 999999'));
      });

      test('handles unknown corruption location', () {
        const exception = CorruptedContainerException(
          'Corruption detected but location unknown',
        );

        expect(exception.byteOffset, isNull);
        expect(exception.toString(), isNot(contains('at byte')));
      });

      test('supports recovery strategy based on offset', () {
        const earlyCorruption = CorruptedContainerException(
          'Early corruption',
          byteOffset: 100,
        );
        const lateCorruption = CorruptedContainerException(
          'Late corruption',
          byteOffset: 50000,
        );

        // Simulate recovery logic
        final bool canRecoverFromEarly = earlyCorruption.byteOffset != null && earlyCorruption.byteOffset! < 1000;
        final bool canRecoverFromLate = lateCorruption.byteOffset != null && lateCorruption.byteOffset! > 10000;

        expect(canRecoverFromEarly, isTrue);
        expect(canRecoverFromLate, isTrue);
      });
    });
  });
}
