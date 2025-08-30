import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/utils/synchsafe_int.dart';

void main() {
  group('SynchsafeInt', () {
    group('encode', () {
      test('encodes zero correctly', () {
        final result = SynchsafeInt.encode(0);
        expect(result, equals([0x00, 0x00, 0x00, 0x00]));
      });

      test('encodes small values correctly', () {
        final result = SynchsafeInt.encode(127);
        expect(result, equals([0x00, 0x00, 0x00, 0x7F]));
      });

      test('encodes medium values correctly', () {
        final result = SynchsafeInt.encode(0x12345);
        expect(result, equals([0x00, 0x04, 0x46, 0x45]));
      });

      test('encodes maximum value correctly', () {
        final result = SynchsafeInt.encode(SynchsafeInt.maxValue);
        expect(result, equals([0x7F, 0x7F, 0x7F, 0x7F]));
      });

      test('encodes powers of 2 correctly', () {
        // Test various powers of 2 within the valid range
        expect(SynchsafeInt.encode(128), equals([0x00, 0x00, 0x01, 0x00]));
        expect(SynchsafeInt.encode(16384), equals([0x00, 0x01, 0x00, 0x00]));
        expect(SynchsafeInt.encode(2097152), equals([0x01, 0x00, 0x00, 0x00]));
      });

      test('throws ArgumentError for negative values', () {
        expect(() => SynchsafeInt.encode(-1), throwsArgumentError);
        expect(() => SynchsafeInt.encode(-100), throwsArgumentError);
      });

      test('throws ArgumentError for values exceeding maximum', () {
        expect(() => SynchsafeInt.encode(SynchsafeInt.maxValue + 1), throwsArgumentError);
        expect(() => SynchsafeInt.encode(0x10000000), throwsArgumentError);
      });

      test('ensures all encoded bytes have MSB = 0', () {
        // Test a range of values to ensure no encoded byte has MSB set
        for (int i = 0; i <= 1000; i += 100) {
          final encoded = SynchsafeInt.encode(i);
          for (int j = 0; j < 4; j++) {
            expect(encoded[j] & 0x80, equals(0), reason: 'Byte $j of encoded value $i has MSB set: 0x${encoded[j].toRadixString(16)}');
          }
        }
      });
    });

    group('encodeBytes', () {
      test('returns Uint8List with correct values', () {
        final result = SynchsafeInt.encodeBytes(0x12345);
        expect(result, isA<Uint8List>());
        expect(result.toList(), equals([0x00, 0x04, 0x46, 0x45]));
      });

      test('throws same errors as encode', () {
        expect(() => SynchsafeInt.encodeBytes(-1), throwsArgumentError);
        expect(() => SynchsafeInt.encodeBytes(SynchsafeInt.maxValue + 1), throwsArgumentError);
      });
    });

    group('decode', () {
      test('decodes zero correctly', () {
        final result = SynchsafeInt.decode([0x00, 0x00, 0x00, 0x00]);
        expect(result, equals(0));
      });

      test('decodes small values correctly', () {
        final result = SynchsafeInt.decode([0x00, 0x00, 0x00, 0x7F]);
        expect(result, equals(127));
      });

      test('decodes medium values correctly', () {
        final result = SynchsafeInt.decode([0x00, 0x04, 0x46, 0x45]);
        expect(result, equals(0x12345));
      });

      test('decodes maximum value correctly', () {
        final result = SynchsafeInt.decode([0x7F, 0x7F, 0x7F, 0x7F]);
        expect(result, equals(SynchsafeInt.maxValue));
      });

      test('decodes powers of 2 correctly', () {
        expect(SynchsafeInt.decode([0x00, 0x00, 0x01, 0x00]), equals(128));
        expect(SynchsafeInt.decode([0x00, 0x01, 0x00, 0x00]), equals(16384));
        expect(SynchsafeInt.decode([0x01, 0x00, 0x00, 0x00]), equals(2097152));
      });

      test('throws ArgumentError for wrong byte count', () {
        expect(() => SynchsafeInt.decode([]), throwsArgumentError);
        expect(() => SynchsafeInt.decode([0x00]), throwsArgumentError);
        expect(() => SynchsafeInt.decode([0x00, 0x00]), throwsArgumentError);
        expect(() => SynchsafeInt.decode([0x00, 0x00, 0x00]), throwsArgumentError);
        expect(() => SynchsafeInt.decode([0x00, 0x00, 0x00, 0x00, 0x00]), throwsArgumentError);
      });

      test('throws FormatException for bytes with MSB set', () {
        expect(() => SynchsafeInt.decode([0x80, 0x00, 0x00, 0x00]), throwsA(isA<FormatException>()));
        expect(() => SynchsafeInt.decode([0x00, 0x80, 0x00, 0x00]), throwsA(isA<FormatException>()));
        expect(() => SynchsafeInt.decode([0x00, 0x00, 0x80, 0x00]), throwsA(isA<FormatException>()));
        expect(() => SynchsafeInt.decode([0x00, 0x00, 0x00, 0x80]), throwsA(isA<FormatException>()));
        expect(() => SynchsafeInt.decode([0xFF, 0xFF, 0xFF, 0xFF]), throwsA(isA<FormatException>()));
      });

      test('throws ArgumentError for invalid byte values', () {
        expect(() => SynchsafeInt.decode([-1, 0x00, 0x00, 0x00]), throwsArgumentError);
        expect(() => SynchsafeInt.decode([256, 0x00, 0x00, 0x00]), throwsArgumentError);
      });

      test('provides detailed error messages', () {
        try {
          SynchsafeInt.decode([0x80, 0x00, 0x00, 0x00]);
          fail('Expected FormatException');
        } catch (e) {
          expect(e.toString(), contains('Invalid synchsafe format'));
          expect(e.toString(), contains('byte 0'));
          expect(e.toString(), contains('0x80'));
          expect(e.toString(), contains('MSB set'));
        }
      });
    });

    group('decodeBytes', () {
      test('decodes Uint8List correctly', () {
        final bytes = Uint8List.fromList([0x00, 0x04, 0x46, 0x45]);
        final result = SynchsafeInt.decodeBytes(bytes);
        expect(result, equals(0x12345));
      });

      test('throws same errors as decode', () {
        final invalidBytes = Uint8List.fromList([0x80, 0x00, 0x00, 0x00]);
        expect(() => SynchsafeInt.decodeBytes(invalidBytes), throwsA(isA<FormatException>()));
      });
    });

    group('decodeBytesAt', () {
      test('decodes from specified offset', () {
        final data = Uint8List.fromList([0xFF, 0x00, 0x04, 0x46, 0x45, 0xFF]);
        final result = SynchsafeInt.decodeBytesAt(data, 1);
        expect(result, equals(0x12345));
      });

      test('decodes from offset 0 by default', () {
        final data = Uint8List.fromList([0x00, 0x04, 0x46, 0x45]);
        final result = SynchsafeInt.decodeBytesAt(data);
        expect(result, equals(0x12345));
      });

      test('throws RangeError for negative offset', () {
        final data = Uint8List.fromList([0x00, 0x04, 0x68, 0x45]);
        expect(() => SynchsafeInt.decodeBytesAt(data, -1), throwsRangeError);
      });

      test('throws RangeError for insufficient bytes', () {
        final data = Uint8List.fromList([0x00, 0x04, 0x68]);
        expect(() => SynchsafeInt.decodeBytesAt(data, 0), throwsRangeError);
        expect(() => SynchsafeInt.decodeBytesAt(data, 1), throwsRangeError);
      });

      test('throws RangeError when offset + 4 exceeds array length', () {
        final data = Uint8List.fromList([0x00, 0x04, 0x68, 0x45]);
        expect(() => SynchsafeInt.decodeBytesAt(data, 1), throwsRangeError);
        expect(() => SynchsafeInt.decodeBytesAt(data, 4), throwsRangeError);
      });
    });

    group('isValid', () {
      test('returns true for valid synchsafe bytes', () {
        expect(SynchsafeInt.isValid([0x00, 0x00, 0x00, 0x00]), isTrue);
        expect(SynchsafeInt.isValid([0x00, 0x04, 0x46, 0x45]), isTrue);
        expect(SynchsafeInt.isValid([0x7F, 0x7F, 0x7F, 0x7F]), isTrue);
      });

      test('returns false for wrong byte count', () {
        expect(SynchsafeInt.isValid([]), isFalse);
        expect(SynchsafeInt.isValid([0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x00, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x00, 0x00, 0x00, 0x00]), isFalse);
      });

      test('returns false for bytes with MSB set', () {
        expect(SynchsafeInt.isValid([0x80, 0x00, 0x00, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x80, 0x00, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x00, 0x80, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([0x00, 0x00, 0x00, 0x80]), isFalse);
        expect(SynchsafeInt.isValid([0xFF, 0xFF, 0xFF, 0xFF]), isFalse);
      });

      test('returns false for invalid byte values', () {
        expect(SynchsafeInt.isValid([-1, 0x00, 0x00, 0x00]), isFalse);
        expect(SynchsafeInt.isValid([256, 0x00, 0x00, 0x00]), isFalse);
      });
    });

    group('isValidBytes', () {
      test('returns true for valid Uint8List', () {
        final bytes = Uint8List.fromList([0x00, 0x04, 0x46, 0x45]);
        expect(SynchsafeInt.isValidBytes(bytes), isTrue);
      });

      test('returns false for invalid Uint8List', () {
        final bytes = Uint8List.fromList([0x80, 0x00, 0x00, 0x00]);
        expect(SynchsafeInt.isValidBytes(bytes), isFalse);
      });
    });

    group('roundTrip', () {
      test('preserves values through encode/decode cycle', () {
        final testValues = [
          0,
          1,
          127,
          128,
          255,
          256,
          16383,
          16384,
          32767,
          32768,
          65535,
          65536,
          0x12345,
          0x100000,
          0x1000000,
          SynchsafeInt.maxValue,
        ];

        for (final value in testValues) {
          final result = SynchsafeInt.roundTrip(value);
          expect(result, equals(value), reason: 'Round trip failed for value $value');
        }
      });

      test('throws same errors as encode', () {
        expect(() => SynchsafeInt.roundTrip(-1), throwsArgumentError);
        expect(() => SynchsafeInt.roundTrip(SynchsafeInt.maxValue + 1), throwsArgumentError);
      });
    });

    group('edge cases and boundary conditions', () {
      test('handles boundary values correctly', () {
        // Test values around 7-bit boundaries
        final boundaryValues = [
          0x7F, // 7 bits
          0x80, // 8 bits
          0x3FFF, // 14 bits
          0x4000, // 15 bits
          0x1FFFFF, // 21 bits
          0x200000, // 22 bits
          0xFFFFFFF, // 28 bits (max value)
        ];

        for (final value in boundaryValues) {
          if (value <= SynchsafeInt.maxValue) {
            final encoded = SynchsafeInt.encode(value);
            final decoded = SynchsafeInt.decode(encoded);
            expect(decoded, equals(value), reason: 'Boundary test failed for value 0x${value.toRadixString(16)}');
          }
        }
      });

      test('handles all possible 7-bit values in each position', () {
        // Test that each byte position can handle all 7-bit values
        for (int i = 0; i < 128; i++) {
          // Test value in each byte position
          final values = [
            i, // Byte 3 only
            i << 7, // Byte 2 only
            i << 14, // Byte 1 only
            i << 21, // Byte 0 only
          ];

          for (final value in values) {
            if (value <= SynchsafeInt.maxValue) {
              final encoded = SynchsafeInt.encode(value);
              final decoded = SynchsafeInt.decode(encoded);
              expect(decoded, equals(value), reason: 'Failed for value $value (0x${value.toRadixString(16)})');
            }
          }
        }
      });

      test('correctly handles bit patterns that could cause issues', () {
        // Test patterns that might cause issues in MP3 parsing
        final problematicPatterns = [
          0x0FF0000, // Could resemble sync pattern if not encoded properly
          0x0FFE000, // Another potential sync pattern
          0x0FFFF00, // High bit density
          0x0555555, // Alternating bit pattern
          0x0AAAAAA, // Alternating bit pattern (inverted)
        ];

        for (final value in problematicPatterns) {
          if (value <= SynchsafeInt.maxValue) {
            final encoded = SynchsafeInt.encode(value);

            // Verify no byte has MSB set (which would create sync patterns)
            for (int i = 0; i < 4; i++) {
              expect(encoded[i] & 0x80, equals(0), reason: 'Encoded byte $i has MSB set for value 0x${value.toRadixString(16)}');
            }

            final decoded = SynchsafeInt.decode(encoded);
            expect(decoded, equals(value));
          }
        }
      });

      test('maintains consistency across different input types', () {
        final testValue = 0x12345;

        // Test that all encoding methods produce the same result
        final encodeResult = SynchsafeInt.encode(testValue);
        final encodeBytesResult = SynchsafeInt.encodeBytes(testValue);

        expect(encodeBytesResult.toList(), equals(encodeResult));

        // Test that all decoding methods produce the same result
        final decodeResult = SynchsafeInt.decode(encodeResult);
        final decodeBytesResult = SynchsafeInt.decodeBytes(encodeBytesResult);
        final decodeBytesAtResult = SynchsafeInt.decodeBytesAt(encodeBytesResult, 0);

        expect(decodeResult, equals(testValue));
        expect(decodeBytesResult, equals(testValue));
        expect(decodeBytesAtResult, equals(testValue));
      });
    });

    group('real-world ID3v2 scenarios', () {
      test('handles typical ID3v2 tag sizes', () {
        // Common ID3v2 tag sizes found in real files
        final typicalSizes = [
          128, // Small tag
          1024, // Medium tag
          4096, // Large tag
          32768, // Very large tag
          131072, // Huge tag with artwork
        ];

        for (final size in typicalSizes) {
          if (size <= SynchsafeInt.maxValue) {
            final encoded = SynchsafeInt.encode(size);
            final decoded = SynchsafeInt.decode(encoded);
            expect(decoded, equals(size), reason: 'Failed for typical size $size');
          }
        }
      });

      test('handles ID3v2 frame sizes', () {
        // Typical frame sizes
        final frameSizes = [
          4, // Tiny frame (like year)
          30, // Text frame (like title)
          100, // Longer text frame
          1000, // Very long text frame
          50000, // Large frame (like lyrics)
          1000000, // Huge frame (like high-res artwork)
        ];

        for (final size in frameSizes) {
          if (size <= SynchsafeInt.maxValue) {
            final encoded = SynchsafeInt.encode(size);
            final decoded = SynchsafeInt.decode(encoded);
            expect(decoded, equals(size), reason: 'Failed for frame size $size');
          }
        }
      });

      test('avoids MP3 sync patterns in encoded output', () {
        // Test a wide range of values to ensure none produce sync-like patterns
        for (int i = 0; i < 10000; i += 100) {
          if (i <= SynchsafeInt.maxValue) {
            final encoded = SynchsafeInt.encode(i);

            // Check that no two consecutive bytes form a sync pattern
            for (int j = 0; j < 3; j++) {
              final byte1 = encoded[j];
              final byte2 = encoded[j + 1];

              // MP3 sync pattern is 0xFF followed by 0xE0 or higher
              // Since our bytes never have MSB set, we can't create 0xFF
              // But let's verify this explicitly
              expect(byte1, lessThan(0x80), reason: 'Byte $j in encoded value $i is >= 0x80');
              expect(byte2, lessThan(0x80), reason: 'Byte ${j + 1} in encoded value $i is >= 0x80');
            }
          }
        }
      });
    });
  });
}
