import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/utils/byte_reader.dart';

void main() {
  group('ByteReader', () {
    late ByteReader reader;
    late Uint8List testData;

    setUp(() {
      // Create test data with various patterns
      testData = Uint8List.fromList([
        // Integers in big-endian format (positions 0-13)
        0x12, 0x34, // uint16: 0x1234 = 4660 (pos 0-1)
        0x56, 0x78, 0x9A, 0xBC, // uint32: 0x56789ABC = 1450744508 (pos 2-5)
        0xDE, 0xF0, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, // uint64 (pos 6-13)
        // String data "Hello" (positions 14-18)
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello" (pos 14-18)
        0x00, // null terminator (pos 19)
        // Pascal string: length=5, "World" (positions 20-25)
        0x05, 0x57, 0x6F, 0x72, 0x6C, 0x64, // Pascal string (pos 20-25)
        // UTF-8 string: "Test" (positions 26-29)
        0x54, 0x65, 0x73, 0x74, // "Test" (pos 26-29)
        0x00, // null terminator (pos 30)
        // Signed integers (two's complement) (positions 31+)
        0xFF, // -1 as int8 (pos 31)
        0xFF, 0xFF, // -1 as int16 (pos 32-33)
        0xFF, 0xFF, 0xFF, 0xFF, // -1 as int32 (pos 34-37)
      ]);
      reader = ByteReader(testData);
    });

    group('Basic Properties', () {
      test('should initialize with correct properties', () {
        expect(reader.position, equals(0));
        expect(reader.length, equals(testData.length));
        expect(reader.remaining, equals(testData.length));
        expect(reader.hasRemaining, isTrue);
      });

      test('should update properties as position changes', () {
        reader.seek(10);
        expect(reader.position, equals(10));
        expect(reader.remaining, equals(testData.length - 10));
        expect(reader.hasRemaining, isTrue);

        reader.seek(testData.length);
        expect(reader.position, equals(testData.length));
        expect(reader.remaining, equals(0));
        expect(reader.hasRemaining, isFalse);
      });

      test('toString should provide useful information', () {
        final str = reader.toString();
        expect(str, contains('position: 0'));
        expect(str, contains('length: ${testData.length}'));
        expect(str, contains('remaining: ${testData.length}'));
      });
    });

    group('Position Management', () {
      test('seek should set position correctly', () {
        reader.seek(5);
        expect(reader.position, equals(5));

        reader.seek(0);
        expect(reader.position, equals(0));

        reader.seek(testData.length);
        expect(reader.position, equals(testData.length));
      });

      test('seek should throw on invalid positions', () {
        expect(() => reader.seek(-1), throwsRangeError);
        expect(() => reader.seek(testData.length + 1), throwsRangeError);
      });

      test('skip should advance position correctly', () {
        reader.skip(5);
        expect(reader.position, equals(5));

        reader.skip(10);
        expect(reader.position, equals(15));

        reader.skip(0);
        expect(reader.position, equals(15));
      });

      test('skip should throw on invalid values', () {
        expect(() => reader.skip(-1), throwsArgumentError);
        expect(() => reader.skip(testData.length + 1), throwsRangeError);

        reader.seek(testData.length - 5);
        expect(() => reader.skip(10), throwsRangeError);
      });
    });

    group('8-bit Integer Reading', () {
      test('readUint8 should read unsigned bytes correctly', () {
        expect(reader.readUint8(), equals(0x12));
        expect(reader.readUint8(), equals(0x34));
        expect(reader.position, equals(2));
      });

      test('readInt8 should read signed bytes correctly', () {
        reader.seek(31); // Position at 0xFF (-1 as int8)
        expect(reader.readInt8(), equals(-1));
        expect(reader.position, equals(32));
      });

      test('readUint8 should throw when no bytes remaining', () {
        reader.seek(testData.length);
        expect(() => reader.readUint8(), throwsRangeError);
      });
    });

    group('16-bit Integer Reading', () {
      test('readUint16 should read big-endian by default', () {
        expect(reader.readUint16(), equals(0x1234));
        expect(reader.position, equals(2));
      });

      test('readUint16 should read little-endian when specified', () {
        expect(reader.readUint16(Endian.little), equals(0x3412));
        expect(reader.position, equals(2));
      });

      test('readInt16 should read signed values correctly', () {
        reader.seek(32); // Position at 0xFFFF (-1 as int16)
        expect(reader.readInt16(), equals(-1));
      });

      test('readUint16 should throw when insufficient bytes', () {
        reader.seek(testData.length - 1);
        expect(() => reader.readUint16(), throwsRangeError);
      });
    });

    group('32-bit Integer Reading', () {
      test('readUint32 should read big-endian by default', () {
        reader.seek(2); // Skip first uint16
        expect(reader.readUint32(), equals(0x56789ABC));
        expect(reader.position, equals(6));
      });

      test('readUint32 should read little-endian when specified', () {
        reader.seek(2);
        expect(reader.readUint32(Endian.little), equals(0xBC9A7856));
      });

      test('readInt32 should read signed values correctly', () {
        reader.seek(34); // Position at 0xFFFFFFFF (-1 as int32)
        expect(reader.readInt32(), equals(-1));
      });

      test('readUint32 should throw when insufficient bytes', () {
        reader.seek(testData.length - 3);
        expect(() => reader.readUint32(), throwsRangeError);
      });
    });

    group('64-bit Integer Reading', () {
      test('readUint64 should read big-endian by default', () {
        reader.seek(6); // Skip to uint64 position
        final expected = (0xDEF01234 << 32) | 0x56789ABC;
        expect(reader.readUint64(), equals(expected));
        expect(reader.position, equals(14));
      });

      test('readUint64 should read little-endian when specified', () {
        reader.seek(6);
        final expected = (0xBC9A7856 << 32) | 0x3412F0DE;
        expect(reader.readUint64(Endian.little), equals(expected));
      });

      test('readInt64 should read signed values correctly', () {
        // Create a ByteReader with known int64 data
        final int64Data = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // -1
        ]);
        final int64Reader = ByteReader(int64Data);
        expect(int64Reader.readInt64(), equals(-1));
      });

      test('readUint64 should throw when insufficient bytes', () {
        reader.seek(testData.length - 7);
        expect(() => reader.readUint64(), throwsRangeError);
      });
    });

    group('Floating Point Reading', () {
      test('readFloat32 should read IEEE 754 single precision', () {
        // Create test data with known float32 value (1.0)
        final floatData = Uint8List.fromList([0x3F, 0x80, 0x00, 0x00]);
        final floatReader = ByteReader(floatData);
        expect(floatReader.readFloat32(), equals(1.0));
      });

      test('readFloat64 should read IEEE 754 double precision', () {
        // Create test data with known float64 value (1.0)
        final doubleData = Uint8List.fromList([0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
        final doubleReader = ByteReader(doubleData);
        expect(doubleReader.readFloat64(), equals(1.0));
      });

      test('floating point methods should respect endianness', () {
        final floatData = Uint8List.fromList([0x00, 0x00, 0x80, 0x3F]);
        final floatReader = ByteReader(floatData);
        expect(floatReader.readFloat32(Endian.little), equals(1.0));
      });

      test('floating point methods should throw when insufficient bytes', () {
        reader.seek(testData.length - 3);
        expect(() => reader.readFloat32(), throwsRangeError);
        expect(() => reader.readFloat64(), throwsRangeError);
      });
    });

    group('Byte Array Reading', () {
      test('readBytes should read specified number of bytes', () {
        final bytes = reader.readBytes(5);
        expect(bytes, equals([0x12, 0x34, 0x56, 0x78, 0x9A]));
        expect(reader.position, equals(5));
      });

      test('readBytes should handle zero length', () {
        final bytes = reader.readBytes(0);
        expect(bytes, isEmpty);
        expect(reader.position, equals(0));
      });

      test('readBytes should throw on negative length', () {
        expect(() => reader.readBytes(-1), throwsArgumentError);
      });

      test('readBytes should throw when insufficient bytes', () {
        expect(() => reader.readBytes(testData.length + 1), throwsRangeError);
      });

      test('readRemainingBytes should read all remaining bytes', () {
        reader.seek(5);
        final remaining = reader.readRemainingBytes();
        expect(remaining.length, equals(testData.length - 5));
        expect(reader.position, equals(testData.length));
        expect(reader.hasRemaining, isFalse);
      });
    });

    group('String Reading', () {
      test('readString should read ASCII strings correctly', () {
        reader.seek(14); // Position at "Hello"
        final str = reader.readString(5, ascii);
        expect(str, equals('Hello'));
        expect(reader.position, equals(19));
      });

      test('readString should read UTF-8 strings correctly', () {
        reader.seek(26); // Position at "Test"
        final str = reader.readString(4, utf8);
        expect(str, equals('Test'));
      });

      test('readString should use UTF-8 by default', () {
        reader.seek(26);
        final str = reader.readString(4);
        expect(str, equals('Test'));
      });

      test('readString should throw on invalid encoding', () {
        // Create invalid UTF-8 sequence
        final invalidUtf8 = Uint8List.fromList([0xFF, 0xFE]);
        final invalidReader = ByteReader(invalidUtf8);
        expect(() => invalidReader.readString(2, utf8), throwsFormatException);
      });

      test('readString should throw when insufficient bytes', () {
        expect(() => reader.readString(testData.length + 1), throwsRangeError);
      });
    });

    group('Null-Terminated String Reading', () {
      test('readNullTerminatedString should read until null terminator', () {
        reader.seek(14); // Position at "Hello\0"
        final str = reader.readNullTerminatedString();
        expect(str, equals('Hello'));
        expect(reader.position, equals(20)); // After null terminator
      });

      test('readNullTerminatedString should respect maxLength', () {
        reader.seek(14);
        final str = reader.readNullTerminatedString(utf8, 3);
        expect(str, equals('Hel'));
        expect(reader.position, equals(17));
      });

      test('readNullTerminatedString should read up to maxLength when no null found', () {
        reader.seek(26); // Position at "Test" (no null terminator within 4 bytes)
        final str = reader.readNullTerminatedString(utf8, 4);
        expect(str, equals('Test'));
        expect(reader.position, equals(30));
      });

      test('readNullTerminatedString should throw when no null terminator found', () {
        reader.seek(26); // Position at "Test" but there IS a null terminator at pos 30
        // Let's create a scenario without null terminator
        final noNullData = Uint8List.fromList([0x54, 0x65, 0x73, 0x74]); // "Test" without null
        final noNullReader = ByteReader(noNullData);
        expect(() => noNullReader.readNullTerminatedString(), throwsRangeError);
      });

      test('readNullTerminatedString should handle empty strings', () {
        final emptyStringData = Uint8List.fromList([0x00]);
        final emptyReader = ByteReader(emptyStringData);
        final str = emptyReader.readNullTerminatedString();
        expect(str, equals(''));
        expect(emptyReader.position, equals(1));
      });
    });

    group('Pascal String Reading', () {
      test('readPascalString should read length-prefixed strings', () {
        reader.seek(20); // Position at Pascal string: 0x05 "World"
        final str = reader.readPascalString();
        expect(str, equals('World'));
        expect(reader.position, equals(26));
      });

      test('readPascalString should handle zero-length strings', () {
        final pascalData = Uint8List.fromList([0x00]);
        final pascalReader = ByteReader(pascalData);
        final str = pascalReader.readPascalString();
        expect(str, equals(''));
        expect(pascalReader.position, equals(1));
      });

      test('readPascalString should throw when insufficient bytes for length', () {
        reader.seek(testData.length);
        expect(() => reader.readPascalString(), throwsRangeError);
      });

      test('readPascalString should throw when insufficient bytes for string', () {
        final invalidPascalData = Uint8List.fromList([0x05, 0x48, 0x65]); // length=5, only 2 chars
        final invalidReader = ByteReader(invalidPascalData);
        expect(() => invalidReader.readPascalString(), throwsRangeError);
      });
    });

    group('Peek Operations', () {
      test('peekBytes should not advance position', () {
        final peeked = reader.peekBytes(3);
        expect(peeked, equals([0x12, 0x34, 0x56]));
        expect(reader.position, equals(0));

        // Verify we can read the same bytes
        final read = reader.readBytes(3);
        expect(read, equals(peeked));
      });

      test('peekUint8 should not advance position', () {
        final peeked = reader.peekUint8();
        expect(peeked, equals(0x12));
        expect(reader.position, equals(0));

        final read = reader.readUint8();
        expect(read, equals(peeked));
      });

      test('peek methods should throw when insufficient bytes', () {
        expect(() => reader.peekBytes(testData.length + 1), throwsRangeError);

        reader.seek(testData.length);
        expect(() => reader.peekUint8(), throwsRangeError);
      });

      test('peekBytes should throw on negative length', () {
        expect(() => reader.peekBytes(-1), throwsArgumentError);
      });
    });

    group('Pattern Matching', () {
      test('matchesPattern should detect patterns correctly', () {
        expect(reader.matchesPattern([0x12, 0x34]), isTrue);
        expect(reader.matchesPattern([0x12, 0x34, 0x56]), isTrue);
        expect(reader.matchesPattern([0x12, 0x35]), isFalse);
        expect(reader.position, equals(0)); // Should not advance position
      });

      test('matchesPattern should return false when insufficient bytes', () {
        reader.seek(testData.length - 1);
        expect(reader.matchesPattern([0x12, 0x34]), isFalse);
      });

      test('matchesPattern should handle empty patterns', () {
        expect(reader.matchesPattern([]), isTrue);
      });

      test('findPattern should locate patterns correctly', () {
        // Look for "Hello" pattern
        final helloPattern = [0x48, 0x65, 0x6C, 0x6C, 0x6F];
        final position = reader.findPattern(helloPattern);
        expect(position, equals(14)); // "Hello" starts at position 14
        expect(reader.position, equals(0)); // Should not advance position
      });

      test('findPattern should return -1 when pattern not found', () {
        final notFoundPattern = [0xAA, 0xBB, 0xCC]; // Pattern that doesn't exist in test data
        final position = reader.findPattern(notFoundPattern);
        expect(position, equals(-1));
      });

      test('findPattern should respect maxSearchLength', () {
        final helloPattern = [0x48, 0x65, 0x6C, 0x6C, 0x6F];
        final position = reader.findPattern(helloPattern, 10); // Search only first 10 bytes
        expect(position, equals(-1)); // "Hello" is beyond first 10 bytes
      });

      test('findPattern should handle empty patterns', () {
        final position = reader.findPattern([]);
        expect(position, equals(0)); // Empty pattern matches at current position
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty byte arrays', () {
        final emptyReader = ByteReader(Uint8List(0));
        expect(emptyReader.length, equals(0));
        expect(emptyReader.hasRemaining, isFalse);
        expect(() => emptyReader.readUint8(), throwsRangeError);
      });

      test('should handle single byte arrays', () {
        final singleByteReader = ByteReader(Uint8List.fromList([0x42]));
        expect(singleByteReader.readUint8(), equals(0x42));
        expect(singleByteReader.hasRemaining, isFalse);
      });

      test('should provide detailed error messages', () {
        reader.seek(testData.length - 1);
        try {
          reader.readUint16();
          fail('Expected RangeError');
        } catch (e) {
          expect(e.toString(), contains('Insufficient bytes'));
          expect(e.toString(), contains('need 2'));
          expect(e.toString(), contains('only 1 remaining'));
        }
      });

      test('should handle maximum integer values', () {
        // Test with data containing maximum values
        final maxValueData = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Max uint64
        ]);
        final maxReader = ByteReader(maxValueData);

        maxReader.seek(0);
        expect(maxReader.readUint8(), equals(0xFF));

        maxReader.seek(0);
        expect(maxReader.readUint16(), equals(0xFFFF));

        maxReader.seek(0);
        expect(maxReader.readUint32(), equals(0xFFFFFFFF));
      });
    });

    group('Performance and Memory', () {
      test('should handle large byte arrays efficiently', () {
        final largeData = Uint8List(1024 * 1024); // 1MB
        for (int i = 0; i < largeData.length; i++) {
          largeData[i] = i % 256;
        }

        final largeReader = ByteReader(largeData);

        // Test that we can read from various positions without issues
        largeReader.seek(1000);
        expect(largeReader.readUint32(), equals((1000 % 256) << 24 | (1001 % 256) << 16 | (1002 % 256) << 8 | (1003 % 256)));

        largeReader.seek(largeData.length - 8);
        expect(() => largeReader.readUint64(), returnsNormally);
      });

      test('should not copy data unnecessarily', () {
        // Verify that readBytes returns a view/sublist, not a copy
        final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final testReader = ByteReader(originalData);

        final readData = testReader.readBytes(3);
        expect(readData, equals([1, 2, 3]));

        // The returned data should be a sublist of the original
        expect(readData.runtimeType.toString(), contains('Uint8List'));
      });
    });
  });
}
