import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/tag_semantics.dart';
import 'package:phonic/src/text_encoding.dart';

void main() {
  group('TextEncoding', () {
    test('enum values have correct standard names', () {
      expect(TextEncoding.iso88591.standardName, equals('ISO-8859-1'));
      expect(TextEncoding.utf8.standardName, equals('UTF-8'));
      expect(TextEncoding.utf16.standardName, equals('UTF-16'));
      expect(TextEncoding.utf16be.standardName, equals('UTF-16BE'));
      expect(TextEncoding.utf16le.standardName, equals('UTF-16LE'));
      expect(TextEncoding.ascii.standardName, equals('ASCII'));
    });

    test('fromName returns correct enum values', () {
      expect(TextEncoding.fromName('UTF-8'), equals(TextEncoding.utf8));
      expect(TextEncoding.fromName('ISO-8859-1'), equals(TextEncoding.iso88591));
      expect(TextEncoding.fromName('UTF-16'), equals(TextEncoding.utf16));
      expect(TextEncoding.fromName('UTF-16BE'), equals(TextEncoding.utf16be));
      expect(TextEncoding.fromName('UTF-16LE'), equals(TextEncoding.utf16le));
      expect(TextEncoding.fromName('ASCII'), equals(TextEncoding.ascii));
    });

    test('fromName returns null for invalid names', () {
      expect(TextEncoding.fromName('utf-8'), isNull); // Case sensitive
      expect(TextEncoding.fromName('INVALID'), isNull);
      expect(TextEncoding.fromName(''), isNull);
    });

    test('isUnicode returns correct values', () {
      expect(TextEncoding.utf8.isUnicode, isTrue);
      expect(TextEncoding.utf16.isUnicode, isTrue);
      expect(TextEncoding.utf16be.isUnicode, isTrue);
      expect(TextEncoding.utf16le.isUnicode, isTrue);
      expect(TextEncoding.iso88591.isUnicode, isFalse);
      expect(TextEncoding.ascii.isUnicode, isFalse);
    });

    test('isVariableLength returns correct values', () {
      expect(TextEncoding.utf8.isVariableLength, isTrue);
      expect(TextEncoding.utf16.isVariableLength, isFalse);
      expect(TextEncoding.utf16be.isVariableLength, isFalse);
      expect(TextEncoding.utf16le.isVariableLength, isFalse);
      expect(TextEncoding.iso88591.isVariableLength, isFalse);
      expect(TextEncoding.ascii.isVariableLength, isFalse);
    });

    test('allNames returns all encoding names', () {
      final allNames = TextEncoding.allNames;
      expect(allNames, contains('UTF-8'));
      expect(allNames, contains('ISO-8859-1'));
      expect(allNames, contains('UTF-16'));
      expect(allNames, contains('UTF-16BE'));
      expect(allNames, contains('UTF-16LE'));
      expect(allNames, contains('ASCII'));
      expect(allNames.length, equals(6));
    });

    test('namesFor returns correct set of names', () {
      final encodings = {TextEncoding.utf8, TextEncoding.utf16};
      final names = TextEncoding.namesFor(encodings);
      expect(names, equals({'UTF-8', 'UTF-16'}));
    });

    test('toString returns standard name', () {
      expect(TextEncoding.utf8.toString(), equals('UTF-8'));
      expect(TextEncoding.iso88591.toString(), equals('ISO-8859-1'));
    });
  });

  group('TagSemantics with TextEncoding', () {
    test('supportsEncoding works with TextEncoding enum', () {
      final semantics = TagSemantics(
        allowedEncodings: {
          TextEncoding.utf8.standardName,
          TextEncoding.utf16.standardName,
        },
      );

      expect(semantics.supportsEncoding(TextEncoding.utf8), isTrue);
      expect(semantics.supportsEncoding(TextEncoding.utf16), isTrue);
      expect(semantics.supportsEncoding(TextEncoding.iso88591), isFalse);
    });

    test('supportsEncoding returns true when no encoding restrictions', () {
      const semantics = TagSemantics();

      expect(semantics.supportsEncoding(TextEncoding.utf8), isTrue);
      expect(semantics.supportsEncoding(TextEncoding.iso88591), isTrue);
    });

    test('isValidEncoding still works with string parameters', () {
      final semantics = TagSemantics(
        allowedEncodings: {TextEncoding.utf8.standardName},
      );

      expect(semantics.isValidEncoding(TextEncoding.utf8.standardName), isTrue);
      expect(semantics.isValidEncoding(TextEncoding.iso88591.standardName), isFalse);
    });
  });
}
