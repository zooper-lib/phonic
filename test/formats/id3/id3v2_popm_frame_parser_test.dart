import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v2_popm_frame_parser.dart';

void main() {
  group('Id3v2PopmFrameData', () {
    test('creates POPM frame data correctly', () {
      const popmData = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 200,
        counter: 42,
      );

      expect(popmData.email, equals('user@example.com'));
      expect(popmData.rating, equals(200));
      expect(popmData.counter, equals(42));
    });

    test('converts rating to unified scale correctly', () {
      // Test boundary values
      const noRating = Id3v2PopmFrameData(email: '', rating: 0);
      expect(noRating.unifiedRating, equals(0));

      const minRating = Id3v2PopmFrameData(email: '', rating: 1);
      expect(minRating.unifiedRating, equals(0));

      const midRating = Id3v2PopmFrameData(email: '', rating: 128);
      expect(midRating.unifiedRating, equals(50));

      const maxRating = Id3v2PopmFrameData(email: '', rating: 255);
      expect(maxRating.unifiedRating, equals(100));

      // Test common rating values
      const rating64 = Id3v2PopmFrameData(email: '', rating: 64);
      expect(rating64.unifiedRating, equals(25));

      const rating192 = Id3v2PopmFrameData(email: '', rating: 192);
      expect(rating192.unifiedRating, equals(75));
    });

    test('converts unified rating back to POPM scale correctly', () {
      // Test boundary values
      expect(Id3v2PopmFrameData.unifiedRatingToPopm(0), equals(0));
      expect(Id3v2PopmFrameData.unifiedRatingToPopm(100), equals(255));

      // Test common values (note: due to rounding, these may not be exact inverses)
      expect(Id3v2PopmFrameData.unifiedRatingToPopm(25), equals(65));
      expect(Id3v2PopmFrameData.unifiedRatingToPopm(50), equals(128));
      expect(Id3v2PopmFrameData.unifiedRatingToPopm(75), equals(192));
    });

    test('handles null counter correctly', () {
      const popmData = Id3v2PopmFrameData(
        email: 'test@test.com',
        rating: 100,
        counter: null,
      );

      expect(popmData.counter, isNull);
    });

    test('equality works correctly', () {
      const popm1 = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 200,
        counter: 42,
      );

      const popm2 = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 200,
        counter: 42,
      );

      const popm3 = Id3v2PopmFrameData(
        email: 'other@example.com',
        rating: 200,
        counter: 42,
      );

      expect(popm1, equals(popm2));
      expect(popm1, isNot(equals(popm3)));
      expect(popm1.hashCode, equals(popm2.hashCode));
    });

    test('toString includes all fields', () {
      const popmData = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 200,
        counter: 42,
      );

      final str = popmData.toString();
      expect(str, contains('user@example.com'));
      expect(str, contains('200'));
      expect(str, contains('42'));
    });
  });

  group('Id3v2PopmFrameParser.parse', () {
    test('parses complete POPM frame correctly', () {
      final frameData = Uint8List.fromList([
        // Email: "user@example.com"
        0x75, 0x73, 0x65, 0x72, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0xC8, // Rating: 200
        0x00, 0x00, 0x00, 0x2A, // Counter: 42
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals('user@example.com'));
      expect(popm.rating, equals(200));
      expect(popm.counter, equals(42));
      expect(popm.unifiedRating, equals(78)); // Converted to 0-100 scale
    });

    test('parses POPM frame without counter', () {
      final frameData = Uint8List.fromList([
        // Email: "test@test.com"
        0x74, 0x65, 0x73, 0x74, 0x40, 0x74, 0x65, 0x73, 0x74, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0x80, // Rating: 128
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals('test@test.com'));
      expect(popm.rating, equals(128));
      expect(popm.counter, isNull);
      expect(popm.unifiedRating, equals(50));
    });

    test('parses POPM frame with empty email', () {
      final frameData = Uint8List.fromList([
        0x00, // Empty email with null terminator
        0xFF, // Rating: 255 (max)
        0x00, 0x00, 0x03, 0xE8, // Counter: 1000
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals(''));
      expect(popm.rating, equals(255));
      expect(popm.counter, equals(1000));
      expect(popm.unifiedRating, equals(100));
    });

    test('parses POPM frame with zero rating', () {
      final frameData = Uint8List.fromList([
        // Email: "no-rating@example.com"
        0x6E, 0x6F, 0x2D, 0x72, 0x61, 0x74, 0x69, 0x6E, 0x67, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0x00, // Rating: 0 (no rating)
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals('no-rating@example.com'));
      expect(popm.rating, equals(0));
      expect(popm.counter, isNull);
      expect(popm.unifiedRating, equals(0));
    });

    test('handles different email formats', () {
      // Test with Windows Media Player format
      final wmpData = Uint8List.fromList([
        // Email: "Windows Media Player 9 Series"
        0x57,
        0x69,
        0x6E,
        0x64,
        0x6F,
        0x77,
        0x73,
        0x20,
        0x4D,
        0x65,
        0x64,
        0x69,
        0x61,
        0x20,
        0x50,
        0x6C,
        0x61,
        0x79,
        0x65,
        0x72,
        0x20,
        0x39,
        0x20,
        0x53,
        0x65,
        0x72,
        0x69,
        0x65,
        0x73,
        0x00, // Null terminator
        0x40, // Rating: 64
        0x00, 0x00, 0x00, 0x05, // Counter: 5
      ]);

      final popm = Id3v2PopmFrameParser.parse(wmpData);

      expect(popm.email, equals('Windows Media Player 9 Series'));
      expect(popm.rating, equals(64));
      expect(popm.counter, equals(5));
      expect(popm.unifiedRating, equals(25));
    });

    test('handles partial counter data gracefully', () {
      final frameData = Uint8List.fromList([
        0x74, 0x65, 0x73, 0x74, 0x00, // "test\0"
        0x80, // Rating: 128
        0x00, 0x00, // Only 2 bytes of counter (incomplete)
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals('test'));
      expect(popm.rating, equals(128));
      expect(popm.counter, isNull); // Incomplete counter should be ignored
    });

    test('throws on frame data too short', () {
      final shortData = Uint8List.fromList([0x00]); // Only 1 byte

      expect(
        () => Id3v2PopmFrameParser.parse(shortData),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing null terminator', () {
      final frameData = Uint8List.fromList([
        0x74, 0x65, 0x73, 0x74, // "test" without null terminator
        0x80, // Rating: 128
      ]);

      expect(
        () => Id3v2PopmFrameParser.parse(frameData),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('throws on missing rating byte', () {
      final frameData = Uint8List.fromList([
        0x74, 0x65, 0x73, 0x74, 0x00, // "test\0" but no rating byte
      ]);

      expect(
        () => Id3v2PopmFrameParser.parse(frameData),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('handles special characters in email', () {
      final frameData = Uint8List.fromList([
        // Email with special characters: "user+tag@sub.example.com"
        0x75, 0x73, 0x65, 0x72, 0x2B, 0x74, 0x61, 0x67, 0x40, 0x73, 0x75, 0x62, 0x2E, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0x96, // Rating: 150
        0x00, 0x00, 0x00, 0x64, // Counter: 100
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email, equals('user+tag@sub.example.com'));
      expect(popm.rating, equals(150));
      expect(popm.counter, equals(100));
      expect(popm.unifiedRating, equals(59));
    });

    test('handles maximum values correctly', () {
      final frameData = Uint8List.fromList([
        // Very long email (but still valid)
        ...List.generate(100, (i) => 0x61 + (i % 26)), // 100 'a'-'z' characters
        0x00, // Null terminator
        0xFF, // Rating: 255 (maximum)
        0xFF, 0xFF, 0xFF, 0xFF, // Counter: 4294967295 (maximum uint32)
      ]);

      final popm = Id3v2PopmFrameParser.parse(frameData);

      expect(popm.email.length, equals(100));
      expect(popm.rating, equals(255));
      expect(popm.counter, equals(4294967295));
      expect(popm.unifiedRating, equals(100));
    });
  });

  group('Id3v2PopmFrameParser.isValid', () {
    test('validates correct POPM data', () {
      const validData = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 128,
        counter: 42,
      );

      expect(Id3v2PopmFrameParser.isValid(validData), isTrue);
    });

    test('rejects invalid rating values', () {
      const invalidRating = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 256, // Out of range
      );

      expect(Id3v2PopmFrameParser.isValid(invalidRating), isFalse);
    });

    test('rejects email with null bytes', () {
      const invalidEmail = Id3v2PopmFrameData(
        email: 'user\x00@example.com', // Contains null byte
        rating: 128,
      );

      expect(Id3v2PopmFrameParser.isValid(invalidEmail), isFalse);
    });

    test('rejects negative counter', () {
      const invalidCounter = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 128,
        counter: -1, // Negative counter
      );

      expect(Id3v2PopmFrameParser.isValid(invalidCounter), isFalse);
    });
  });

  group('Id3v2PopmFrameParser.encode', () {
    test('encodes POPM frame data correctly', () {
      const popmData = Id3v2PopmFrameData(
        email: 'test@example.com',
        rating: 200,
        counter: 42,
      );

      final encoded = Id3v2PopmFrameParser.encode(popmData);
      final expected = Uint8List.fromList([
        // Email: "test@example.com"
        0x74, 0x65, 0x73, 0x74, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0xC8, // Rating: 200
        0x00, 0x00, 0x00, 0x2A, // Counter: 42
      ]);

      expect(encoded, equals(expected));
    });

    test('encodes POPM frame without counter', () {
      const popmData = Id3v2PopmFrameData(
        email: 'test@example.com',
        rating: 128,
      );

      final encoded = Id3v2PopmFrameParser.encode(popmData);
      final expected = Uint8List.fromList([
        // Email: "test@example.com"
        0x74, 0x65, 0x73, 0x74, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D,
        0x00, // Null terminator
        0x80, // Rating: 128
      ]);

      expect(encoded, equals(expected));
    });

    test('encodes empty email correctly', () {
      const popmData = Id3v2PopmFrameData(
        email: '',
        rating: 255,
        counter: 1000,
      );

      final encoded = Id3v2PopmFrameParser.encode(popmData);
      final expected = Uint8List.fromList([
        0x00, // Empty email with null terminator
        0xFF, // Rating: 255
        0x00, 0x00, 0x03, 0xE8, // Counter: 1000
      ]);

      expect(encoded, equals(expected));
    });

    test('throws on invalid POPM data', () {
      const invalidData = Id3v2PopmFrameData(
        email: 'user@example.com',
        rating: 256, // Invalid rating
      );

      expect(
        () => Id3v2PopmFrameParser.encode(invalidData),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trip encoding and parsing', () {
      const originalData = Id3v2PopmFrameData(
        email: 'roundtrip@test.com',
        rating: 150,
        counter: 999,
      );

      final encoded = Id3v2PopmFrameParser.encode(originalData);
      final parsed = Id3v2PopmFrameParser.parse(encoded);

      expect(parsed, equals(originalData));
    });
  });
}
