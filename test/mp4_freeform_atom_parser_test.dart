import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/src/utils/byte_reader.dart';
import '../lib/src/utils/mp4_atom_parser.dart';

void main() {
  group('Mp4AtomParser Freeform Atom Parsing', () {
    group('parseFreeformAtom', () {
      test('parses valid freeform atom with text data', () {
        // Create a freeform atom with mean, name, and data sub-atoms
        final freeformData = _buildFreeformAtom(
          domain: 'com.example.app',
          name: 'CUSTOM_FIELD',
          dataType: 0x00000001, // UTF-8 text
          data: Uint8List.fromList('Test Value'.codeUnits),
        );

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: freeformData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: freeformData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);

        expect(result, isNotNull);
        expect(result!.domain, equals('com.example.app'));
        expect(result.name, equals('CUSTOM_FIELD'));
        expect(result.fullIdentifier, equals('----:com.example.app:CUSTOM_FIELD'));
        expect(String.fromCharCodes(result.data), equals('Test Value'));
      });

      test('parses freeform atom with integer data', () {
        // Create integer data (big-endian 32-bit: 12345)
        final intData = Uint8List(4);
        final intView = ByteData.sublistView(intData);
        intView.setUint32(0, 12345, Endian.big);

        final freeformData = _buildFreeformAtom(
          domain: 'com.phonic.tags',
          name: 'RATING',
          dataType: 0x00000016, // Unsigned integer
          data: intData,
        );

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: freeformData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: freeformData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);

        expect(result, isNotNull);
        expect(result!.domain, equals('com.phonic.tags'));
        expect(result.name, equals('RATING'));
        expect(result.data.length, equals(4));

        // Verify integer value
        final reader = ByteReader(result.data);
        expect(reader.readUint32(), equals(12345));
      });

      test('parses freeform atom with binary data', () {
        final binaryData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0xFF]);

        final freeformData = _buildFreeformAtom(
          domain: 'com.test.binary',
          name: 'BINARY_FIELD',
          dataType: 0x00000000, // Binary data
          data: binaryData,
        );

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: freeformData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: freeformData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);

        expect(result, isNotNull);
        expect(result!.domain, equals('com.test.binary'));
        expect(result.name, equals('BINARY_FIELD'));
        expect(result.data, equals(binaryData));
      });

      test('returns null for non-freeform atom', () {
        final atom = Mp4Atom(
          header: const Mp4AtomHeader(
            size: 16,
            type: '©nam', // Standard atom, not freeform
            offset: 0,
          ),
          data: Uint8List(8),
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);
        expect(result, isNull);
      });

      test('returns null for malformed freeform atom', () {
        // Create atom with insufficient data
        final atom = Mp4Atom(
          header: const Mp4AtomHeader(
            size: 12,
            type: '----',
            offset: 0,
          ),
          data: Uint8List(4), // Too small to contain valid sub-atoms
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);
        expect(result, isNull);
      });

      test('returns null when missing required sub-atoms', () {
        // Create freeform atom with only mean sub-atom (missing name and data)
        final meanData = _buildMeanAtom('com.example.app');

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: meanData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: meanData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);
        expect(result, isNull);
      });

      test('handles empty domain and name strings', () {
        final freeformData = _buildFreeformAtom(
          domain: '',
          name: '',
          dataType: 0x00000001,
          data: Uint8List.fromList('value'.codeUnits),
        );

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: freeformData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: freeformData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);

        expect(result, isNotNull);
        expect(result!.domain, equals(''));
        expect(result.name, equals(''));
        expect(result.fullIdentifier, equals('----::'));
      });

      test('handles whitespace in domain and name', () {
        final freeformData = _buildFreeformAtom(
          domain: '  com.example.app  ',
          name: '  FIELD_NAME  ',
          dataType: 0x00000001,
          data: Uint8List.fromList('value'.codeUnits),
        );

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: freeformData.length + 8,
            type: '----',
            offset: 0,
          ),
          data: freeformData,
        );

        final result = Mp4AtomParser.parseFreeformAtom(atom);

        expect(result, isNotNull);
        expect(result!.domain, equals('com.example.app'));
        expect(result.name, equals('FIELD_NAME'));
      });
    });

    group('detectFreeformDataType', () {
      test('detects UTF-8 text type', () {
        // Build just the data portion (type/flags + locale + data)
        final dataContent = Uint8List(12); // 4 bytes type + 4 bytes locale + 4 bytes data
        final view = ByteData.sublistView(dataContent);
        view.setUint32(0, 0x00000001, Endian.big); // UTF-8 text type
        view.setUint32(4, 0, Endian.big); // locale
        dataContent.setRange(8, 12, 'text'.codeUnits);

        final type = Mp4AtomParser.detectFreeformDataType(dataContent);
        expect(type, equals(FreeformDataType.utf8Text));
      });

      test('detects signed integer type', () {
        final dataContent = Uint8List(12);
        final view = ByteData.sublistView(dataContent);
        view.setUint32(0, 0x00000015, Endian.big); // signed integer type
        view.setUint32(4, 0, Endian.big); // locale
        view.setUint32(8, 12345, Endian.big); // integer data

        final type = Mp4AtomParser.detectFreeformDataType(dataContent);
        expect(type, equals(FreeformDataType.signedInteger));
      });

      test('detects unsigned integer type', () {
        final dataContent = Uint8List(12);
        final view = ByteData.sublistView(dataContent);
        view.setUint32(0, 0x00000016, Endian.big); // unsigned integer type
        view.setUint32(4, 0, Endian.big); // locale
        view.setUint32(8, 12345, Endian.big); // integer data

        final type = Mp4AtomParser.detectFreeformDataType(dataContent);
        expect(type, equals(FreeformDataType.unsignedInteger));
      });

      test('detects binary type for unknown type values', () {
        final dataContent = Uint8List(11);
        final view = ByteData.sublistView(dataContent);
        view.setUint32(0, 0x12345678, Endian.big); // unknown type
        view.setUint32(4, 0, Endian.big); // locale
        dataContent.setRange(8, 11, [0x01, 0x02, 0x03]);

        final type = Mp4AtomParser.detectFreeformDataType(dataContent);
        expect(type, equals(FreeformDataType.binary));
      });

      test('returns binary for insufficient data', () {
        final type = Mp4AtomParser.detectFreeformDataType(Uint8List(2));
        expect(type, equals(FreeformDataType.binary));
      });
    });

    group('convertFreeformData', () {
      test('converts UTF-8 text data', () {
        final data = Uint8List.fromList('Hello World'.codeUnits);
        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.utf8Text);
        expect(result, equals('Hello World'));
      });

      test('trims whitespace from UTF-8 text', () {
        final data = Uint8List.fromList('  Hello World  '.codeUnits);
        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.utf8Text);
        expect(result, equals('Hello World'));
      });

      test('converts 32-bit signed integer', () {
        final data = Uint8List(4);
        final view = ByteData.sublistView(data);
        view.setInt32(0, -12345, Endian.big);

        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.signedInteger);
        expect(result, equals(-12345));
      });

      test('converts 16-bit signed integer', () {
        final data = Uint8List(2);
        final view = ByteData.sublistView(data);
        view.setInt16(0, -1234, Endian.big);

        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.signedInteger);
        expect(result, equals(-1234));
      });

      test('converts 8-bit signed integer', () {
        final data = Uint8List.fromList([200]); // > 127, should be negative
        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.signedInteger);
        expect(result, equals(-56)); // 200 - 256 = -56
      });

      test('converts 32-bit unsigned integer', () {
        final data = Uint8List(4);
        final view = ByteData.sublistView(data);
        view.setUint32(0, 4294967295, Endian.big); // Max uint32

        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.unsignedInteger);
        expect(result, equals(4294967295));
      });

      test('converts 16-bit unsigned integer', () {
        final data = Uint8List(2);
        final view = ByteData.sublistView(data);
        view.setUint16(0, 65535, Endian.big); // Max uint16

        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.unsignedInteger);
        expect(result, equals(65535));
      });

      test('converts 8-bit unsigned integer', () {
        final data = Uint8List.fromList([255]);
        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.unsignedInteger);
        expect(result, equals(255));
      });

      test('returns raw data for binary type', () {
        final data = Uint8List.fromList([0x01, 0x02, 0x03, 0xFF]);
        final result = Mp4AtomParser.convertFreeformData(data, FreeformDataType.binary);
        expect(result, equals(data));
      });

      test('returns default values for insufficient integer data', () {
        final emptyData = Uint8List(0);

        final signedResult = Mp4AtomParser.convertFreeformData(emptyData, FreeformDataType.signedInteger);
        expect(signedResult, equals(0));

        final unsignedResult = Mp4AtomParser.convertFreeformData(emptyData, FreeformDataType.unsignedInteger);
        expect(unsignedResult, equals(0));
      });

      test('handles conversion errors gracefully', () {
        // This should not throw, even with malformed data
        final result = Mp4AtomParser.convertFreeformData(Uint8List(0), FreeformDataType.utf8Text);
        expect(result, equals(''));
      });
    });

    group('FreeformAtomData', () {
      test('creates valid freeform atom data', () {
        final data = FreeformAtomData(
          domain: 'com.example.app',
          name: 'CUSTOM_FIELD',
          data: Uint8List.fromList('value'.codeUnits),
        );

        expect(data.domain, equals('com.example.app'));
        expect(data.name, equals('CUSTOM_FIELD'));
        expect(data.fullIdentifier, equals('----:com.example.app:CUSTOM_FIELD'));
        expect(String.fromCharCodes(data.data), equals('value'));
      });

      test('implements equality correctly', () {
        final data1 = FreeformAtomData(
          domain: 'com.example.app',
          name: 'FIELD',
          data: Uint8List.fromList([1, 2, 3]),
        );

        final data2 = FreeformAtomData(
          domain: 'com.example.app',
          name: 'FIELD',
          data: Uint8List.fromList([1, 2, 3]),
        );

        final data3 = FreeformAtomData(
          domain: 'com.example.app',
          name: 'DIFFERENT',
          data: Uint8List.fromList([1, 2, 3]),
        );

        expect(data1, equals(data2));
        expect(data1, isNot(equals(data3)));
        expect(data1.hashCode, equals(data2.hashCode));
      });

      test('toString provides useful information', () {
        final data = FreeformAtomData(
          domain: 'com.example.app',
          name: 'FIELD',
          data: Uint8List(10),
        );

        final str = data.toString();
        expect(str, contains('com.example.app'));
        expect(str, contains('FIELD'));
        expect(str, contains('10'));
      });
    });
  });
}

/// Helper function to build a complete freeform atom data structure.
Uint8List _buildFreeformAtom({
  required String domain,
  required String name,
  required int dataType,
  required Uint8List data,
}) {
  final meanAtom = _buildMeanAtom(domain);
  final nameAtom = _buildNameAtom(name);
  final dataAtom = _buildDataAtom(dataType, data);

  final totalSize = meanAtom.length + nameAtom.length + dataAtom.length;
  final result = Uint8List(totalSize);

  int offset = 0;
  result.setRange(offset, offset + meanAtom.length, meanAtom);
  offset += meanAtom.length;

  result.setRange(offset, offset + nameAtom.length, nameAtom);
  offset += nameAtom.length;

  result.setRange(offset, offset + dataAtom.length, dataAtom);

  return result;
}

/// Helper function to build a 'mean' sub-atom.
Uint8List _buildMeanAtom(String domain) {
  final domainBytes = Uint8List.fromList(domain.codeUnits);
  final atomSize = 8 + 4 + domainBytes.length; // header + version/flags + domain

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'mean'.codeUnits); // type

  // Version/flags (4 bytes of zeros)
  view.setUint32(8, 0, Endian.big);

  // Domain string
  result.setRange(12, 12 + domainBytes.length, domainBytes);

  return result;
}

/// Helper function to build a 'name' sub-atom.
Uint8List _buildNameAtom(String name) {
  final nameBytes = Uint8List.fromList(name.codeUnits);
  final atomSize = 8 + 4 + nameBytes.length; // header + version/flags + name

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'name'.codeUnits); // type

  // Version/flags (4 bytes of zeros)
  view.setUint32(8, 0, Endian.big);

  // Name string
  result.setRange(12, 12 + nameBytes.length, nameBytes);

  return result;
}

/// Helper function to build a 'data' sub-atom.
Uint8List _buildDataAtom(int dataType, Uint8List data) {
  final atomSize = 8 + 8 + data.length; // header + type/flags + locale + data

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'data'.codeUnits); // type

  // Type/flags
  view.setUint32(8, dataType, Endian.big);

  // Locale (4 bytes of zeros)
  view.setUint32(12, 0, Endian.big);

  // Data payload
  result.setRange(16, 16 + data.length, data);

  return result;
}
