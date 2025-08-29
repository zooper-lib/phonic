import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/text_encoding.dart';

void main() {
  group('TextEncoding', () {
    test('defines standard encoding constants with correct names', () {
      expect(TextEncoding.iso88591.standardName, equals('ISO-8859-1'));
      expect(TextEncoding.utf8.standardName, equals('UTF-8'));
      expect(TextEncoding.utf16.standardName, equals('UTF-16'));
      expect(TextEncoding.utf16be.standardName, equals('UTF-16BE'));
      expect(TextEncoding.utf16le.standardName, equals('UTF-16LE'));
      expect(TextEncoding.ascii.standardName, equals('ASCII'));
    });

    test('name getter returns standardName', () {
      for (final encoding in TextEncoding.values) {
        expect(encoding.name, equals(encoding.standardName));
      }
    });

    test('toString returns standardName', () {
      expect(TextEncoding.utf8.toString(), equals('UTF-8'));
      expect(TextEncoding.iso88591.toString(), equals('ISO-8859-1'));
      expect(TextEncoding.utf16.toString(), equals('UTF-16'));
    });

    test('allNames contains all encoding names', () {
      final expectedNames = {
        'ISO-8859-1',
        'UTF-8',
        'UTF-16',
        'UTF-16BE',
        'UTF-16LE',
        'ASCII',
      };

      expect(TextEncoding.allNames, equals(expectedNames));
      expect(TextEncoding.allNames.length, equals(TextEncoding.values.length));
    });

    test('fromName finds encoding by standard name', () {
      expect(TextEncoding.fromName('UTF-8'), equals(TextEncoding.utf8));
      expect(TextEncoding.fromName('ISO-8859-1'), equals(TextEncoding.iso88591));
      expect(TextEncoding.fromName('UTF-16'), equals(TextEncoding.utf16));
      expect(TextEncoding.fromName('UTF-16BE'), equals(TextEncoding.utf16be));
      expect(TextEncoding.fromName('UTF-16LE'), equals(TextEncoding.utf16le));
      expect(TextEncoding.fromName('ASCII'), equals(TextEncoding.ascii));
    });

    test('fromName returns null for unknown encoding', () {
      expect(TextEncoding.fromName('UNKNOWN'), isNull);
      expect(TextEncoding.fromName('utf-8'), isNull); // Case sensitive
      expect(TextEncoding.fromName('Utf-8'), isNull);
      expect(TextEncoding.fromName(''), isNull);
    });

    test('fromName is case sensitive', () {
      expect(TextEncoding.fromName('UTF-8'), isNotNull);
      expect(TextEncoding.fromName('utf-8'), isNull);
      expect(TextEncoding.fromName('Utf-8'), isNull);
      expect(TextEncoding.fromName('UTF8'), isNull);
    });

    group('isUnicode', () {
      test('returns true for Unicode encodings', () {
        expect(TextEncoding.utf8.isUnicode, isTrue);
        expect(TextEncoding.utf16.isUnicode, isTrue);
        expect(TextEncoding.utf16be.isUnicode, isTrue);
        expect(TextEncoding.utf16le.isUnicode, isTrue);
      });

      test('returns false for legacy encodings', () {
        expect(TextEncoding.iso88591.isUnicode, isFalse);
        expect(TextEncoding.ascii.isUnicode, isFalse);
      });
    });

    group('isVariableLength', () {
      test('returns true for variable-length encodings', () {
        expect(TextEncoding.utf8.isVariableLength, isTrue);
      });

      test('returns false for fixed-length encodings', () {
        expect(TextEncoding.utf16.isVariableLength, isFalse);
        expect(TextEncoding.utf16be.isVariableLength, isFalse);
        expect(TextEncoding.utf16le.isVariableLength, isFalse);
        expect(TextEncoding.iso88591.isVariableLength, isFalse);
        expect(TextEncoding.ascii.isVariableLength, isFalse);
      });
    });

    test('all values have unique standard names', () {
      final names = TextEncoding.values.map((e) => e.standardName).toSet();
      expect(names.length, equals(TextEncoding.values.length));
    });

    test('covers common encoding scenarios', () {
      // Verify we have the most commonly used encodings
      expect(TextEncoding.values, contains(TextEncoding.utf8)); // Modern Unicode
      expect(TextEncoding.values, contains(TextEncoding.utf16)); // Legacy Unicode
      expect(TextEncoding.values, contains(TextEncoding.iso88591)); // Legacy Latin
      expect(TextEncoding.values, contains(TextEncoding.ascii)); // Basic ASCII
    });
  });
}
