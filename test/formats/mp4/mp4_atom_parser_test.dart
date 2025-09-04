import 'dart:typed_data';

import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/utils/byte_reader.dart';
import 'package:phonic/src/utils/mp4_atom_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Mp4AtomHeader', () {
    group('parse', () {
      test('parses standard atom header correctly', () {
        // Create test data: size=32, type="ftyp"
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size: 32 bytes
          0x66, 0x74, 0x79, 0x70, // type: "ftyp"
          // Additional data to meet size requirement
          ...List.filled(24, 0x00),
        ]);

        final reader = ByteReader(bytes);
        final header = Mp4AtomHeader.parse(reader);

        expect(header.size, equals(32));
        expect(header.type, equals('ftyp'));
        expect(header.offset, equals(0));
        expect(header.isExtendedSize, isFalse);
        expect(header.headerSize, equals(8));
        expect(header.dataSize, equals(24));
        expect(header.dataOffset, equals(8));
        expect(header.nextAtomOffset, equals(32));
      });

      test('parses extended size atom header correctly', () {
        // Create test data: size=1 (extended), type="mdat", extended_size=1024
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x01, // size: 1 (indicates extended)
          0x6D, 0x64, 0x61, 0x74, // type: "mdat"
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, // extended_size: 1024
          // Additional data to meet size requirement
          ...List.filled(1024 - 16, 0x00),
        ]);

        final reader = ByteReader(bytes);
        final header = Mp4AtomHeader.parse(reader);

        expect(header.size, equals(1024));
        expect(header.type, equals('mdat'));
        expect(header.offset, equals(0));
        expect(header.isExtendedSize, isTrue);
        expect(header.headerSize, equals(16));
        expect(header.dataSize, equals(1024 - 16));
        expect(header.dataOffset, equals(16));
        expect(header.nextAtomOffset, equals(1024));
      });

      test('handles atom with minimum size', () {
        // Create test data: size=8 (header only), type="free"
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x08, // size: 8 bytes
          0x66, 0x72, 0x65, 0x65, // type: "free"
        ]);

        final reader = ByteReader(bytes);
        final header = Mp4AtomHeader.parse(reader);

        expect(header.size, equals(8));
        expect(header.type, equals('free'));
        expect(header.dataSize, equals(0));
      });

      test('handles atom with non-printable characters in type', () {
        // Create test data with non-printable characters
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // size: 16 bytes
          0x00, 0x01, 0x02, 0x03, // type: non-printable bytes
          ...List.filled(8, 0x00), // data
        ]);

        final reader = ByteReader(bytes);
        final header = Mp4AtomHeader.parse(reader);

        expect(header.size, equals(16));
        expect(header.type, equals('\x00\x01\x02\x03'));
      });

      test('throws CorruptedContainerException for insufficient bytes', () {
        final bytes = Uint8List.fromList([0x00, 0x00, 0x00]); // Only 3 bytes
        final reader = ByteReader(bytes);

        expect(
          () => Mp4AtomHeader.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Insufficient bytes for MP4 atom header'))),
        );
      });

      test('throws CorruptedContainerException for invalid standard size', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x07, // size: 7 bytes (invalid, minimum is 8)
          0x66, 0x72, 0x65, 0x65, // type: "free"
        ]);

        final reader = ByteReader(bytes);

        expect(
          () => Mp4AtomHeader.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Invalid MP4 atom size: 7'))),
        );
      });

      test('throws CorruptedContainerException for invalid extended size', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x01, // size: 1 (extended)
          0x6D, 0x64, 0x61, 0x74, // type: "mdat"
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0F, // extended_size: 15 (invalid, minimum is 16)
        ]);

        final reader = ByteReader(bytes);

        expect(
          () => Mp4AtomHeader.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Invalid extended MP4 atom size: 15'))),
        );
      });

      test('throws CorruptedContainerException for all-zero atom type', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x08, // size: 8 bytes
          0x00, 0x00, 0x00, 0x00, // type: all zeros (invalid)
        ]);

        final reader = ByteReader(bytes);

        expect(
          () => Mp4AtomHeader.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Invalid atom type: all zero bytes'))),
        );
      });

      test('throws CorruptedContainerException for insufficient extended size bytes', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x01, // size: 1 (extended)
          0x6D, 0x64, 0x61, 0x74, // type: "mdat"
          0x00, 0x00, 0x00, // Only 3 bytes of extended size
        ]);

        final reader = ByteReader(bytes);

        expect(
          () => Mp4AtomHeader.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Insufficient bytes for extended MP4 atom size'))),
        );
      });
    });

    group('equality and toString', () {
      test('equals works correctly', () {
        final header1 = const Mp4AtomHeader(size: 32, type: 'ftyp', offset: 0);
        final header2 = const Mp4AtomHeader(size: 32, type: 'ftyp', offset: 0);
        final header3 = const Mp4AtomHeader(size: 32, type: 'moov', offset: 0);

        expect(header1, equals(header2));
        expect(header1, isNot(equals(header3)));
      });

      test('toString provides useful information', () {
        final header = const Mp4AtomHeader(size: 32, type: 'ftyp', offset: 0);
        final str = header.toString();

        expect(str, contains('ftyp'));
        expect(str, contains('32'));
        expect(str, contains('0'));
        expect(str, contains('false'));
      });
    });
  });

  group('Mp4Atom', () {
    group('parse', () {
      test('parses atom with data correctly', () {
        final testData = List.generate(24, (i) => i); // Test data pattern
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size: 32 bytes
          0x66, 0x72, 0x65, 0x65, // type: "free"
          ...testData, // 24 bytes of data
        ]);

        final reader = ByteReader(bytes);
        final atom = Mp4Atom.parse(reader);

        expect(atom.header.size, equals(32));
        expect(atom.header.type, equals('free'));
        expect(atom.data.length, equals(24));
        expect(atom.data, equals(Uint8List.fromList(testData)));
      });

      test('parses atom with no data', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x08, // size: 8 bytes (header only)
          0x66, 0x72, 0x65, 0x65, // type: "free"
        ]);

        final reader = ByteReader(bytes);
        final atom = Mp4Atom.parse(reader);

        expect(atom.header.size, equals(8));
        expect(atom.header.type, equals('free'));
        expect(atom.data.length, equals(0));
      });

      test('throws CorruptedContainerException for insufficient data bytes', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size: 32 bytes
          0x66, 0x72, 0x65, 0x65, // type: "free"
          0x01, 0x02, 0x03, // Only 3 bytes of data (need 24)
        ]);

        final reader = ByteReader(bytes);

        expect(
          () => Mp4Atom.parse(reader),
          throwsA(isA<CorruptedContainerException>().having((e) => e.message, 'message', contains('Insufficient bytes for MP4 atom data'))),
        );
      });
    });

    group('container detection', () {
      test('identifies container atoms correctly', () {
        final containerTypes = ['moov', 'trak', 'mdia', 'minf', 'udta', 'meta', 'ilst'];

        for (final type in containerTypes) {
          final bytes = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x08, // size: 8 bytes
            ...type.codeUnits, // type
          ]);

          final reader = ByteReader(bytes);
          final atom = Mp4Atom.parse(reader);

          expect(atom.isContainer, isTrue, reason: '$type should be container');
          expect(atom.isLeaf, isFalse, reason: '$type should not be leaf');
        }
      });

      test('identifies leaf atoms correctly', () {
        final leafTypes = ['ftyp', 'mdat', 'free', '©nam', '©ART'];

        for (final type in leafTypes) {
          final typeBytes = type.length == 4 ? type.codeUnits : [0x00, 0x00, 0x00, 0x00];
          final bytes = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x08, // size: 8 bytes
            ...typeBytes, // type
          ]);

          final reader = ByteReader(bytes);
          final atom = Mp4Atom.parse(reader);

          expect(atom.isLeaf, isTrue, reason: '$type should be leaf');
          expect(atom.isContainer, isFalse, reason: '$type should not be container');
        }
      });
    });

    group('equality and toString', () {
      test('equals works correctly', () {
        final data1 = Uint8List.fromList([1, 2, 3, 4]);
        final data2 = Uint8List.fromList([1, 2, 3, 4]);
        final data3 = Uint8List.fromList([1, 2, 3, 5]);

        final header = const Mp4AtomHeader(size: 12, type: 'test', offset: 0);
        final atom1 = Mp4Atom(header: header, data: data1);
        final atom2 = Mp4Atom(header: header, data: data2);
        final atom3 = Mp4Atom(header: header, data: data3);

        expect(atom1, equals(atom2));
        expect(atom1, isNot(equals(atom3)));
      });

      test('toString provides useful information', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final header = const Mp4AtomHeader(size: 12, type: 'test', offset: 0);
        final atom = Mp4Atom(header: header, data: data);
        final str = atom.toString();

        expect(str, contains('test'));
        expect(str, contains('12'));
        expect(str, contains('4'));
      });
    });
  });

  group('Mp4AtomParser', () {
    group('parseAtoms', () {
      test('parses multiple atoms correctly', () {
        final bytes = Uint8List.fromList([
          // First atom: ftyp
          0x00, 0x00, 0x00, 0x10, // size: 16 bytes
          0x66, 0x74, 0x79, 0x70, // type: "ftyp"
          0x4D, 0x34, 0x41, 0x20, // data: "M4A "
          0x00, 0x00, 0x00, 0x00, // data: version
          // Second atom: free
          0x00, 0x00, 0x00, 0x08, // size: 8 bytes
          0x66, 0x72, 0x65, 0x65, // type: "free"
        ]);

        final atoms = Mp4AtomParser.parseAtoms(bytes);

        expect(atoms.length, equals(2));
        expect(atoms[0].header.type, equals('ftyp'));
        expect(atoms[0].header.size, equals(16));
        expect(atoms[0].data.length, equals(8));
        expect(atoms[1].header.type, equals('free'));
        expect(atoms[1].header.size, equals(8));
        expect(atoms[1].data.length, equals(0));
      });

      test('handles empty data', () {
        final bytes = Uint8List.fromList([]);
        final atoms = Mp4AtomParser.parseAtoms(bytes);
        expect(atoms, isEmpty);
      });

      test('throws CorruptedContainerException for malformed data', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size: 32 bytes
          0x66, 0x74, 0x79, 0x70, // type: "ftyp"
          0x01, 0x02, // Only 2 bytes of data (need 24)
        ]);

        expect(
          () => Mp4AtomParser.parseAtoms(bytes),
          throwsA(isA<CorruptedContainerException>()),
        );
      });
    });

    group('parseChildAtoms', () {
      test('parses child atoms from container data', () {
        final containerData = Uint8List.fromList([
          // Child atom 1
          0x00, 0x00, 0x00, 0x0C, // size: 12 bytes
          0x74, 0x65, 0x73, 0x74, // type: "test"
          0x01, 0x02, 0x03, 0x04, // data
          // Child atom 2
          0x00, 0x00, 0x00, 0x08, // size: 8 bytes
          0x66, 0x72, 0x65, 0x65, // type: "free"
        ]);

        final childAtoms = Mp4AtomParser.parseChildAtoms(containerData);

        expect(childAtoms.length, equals(2));
        expect(childAtoms[0].header.type, equals('test'));
        expect(childAtoms[1].header.type, equals('free'));
      });
    });

    group('findAtom', () {
      test('finds atom by type', () {
        final bytes = Uint8List.fromList([
          // ftyp atom
          0x00, 0x00, 0x00, 0x10,
          0x66, 0x74, 0x79, 0x70,
          ...List.filled(8, 0x00),
          // moov atom
          0x00, 0x00, 0x00, 0x0C,
          0x6D, 0x6F, 0x6F, 0x76,
          ...List.filled(4, 0x00),
        ]);

        final moovAtom = Mp4AtomParser.findAtom(bytes, 'moov');
        final ftypAtom = Mp4AtomParser.findAtom(bytes, 'ftyp');
        final missingAtom = Mp4AtomParser.findAtom(bytes, 'mdat');

        expect(moovAtom, isNotNull);
        expect(moovAtom!.header.type, equals('moov'));
        expect(ftypAtom, isNotNull);
        expect(ftypAtom!.header.type, equals('ftyp'));
        expect(missingAtom, isNull);
      });

      test('returns null for malformed data', () {
        final bytes = Uint8List.fromList([0x00, 0x00]); // Invalid data
        final atom = Mp4AtomParser.findAtom(bytes, 'ftyp');
        expect(atom, isNull);
      });
    });

    group('findAtoms', () {
      test('finds multiple atoms of same type', () {
        final bytes = Uint8List.fromList([
          // First trak atom
          0x00, 0x00, 0x00, 0x08,
          0x74, 0x72, 0x61, 0x6B, // "trak"
          // Second trak atom
          0x00, 0x00, 0x00, 0x08,
          0x74, 0x72, 0x61, 0x6B, // "trak"
          // Different atom
          0x00, 0x00, 0x00, 0x08,
          0x6D, 0x6F, 0x6F, 0x76, // "moov"
        ]);

        final trakAtoms = Mp4AtomParser.findAtoms(bytes, 'trak');
        final moovAtoms = Mp4AtomParser.findAtoms(bytes, 'moov');
        final missingAtoms = Mp4AtomParser.findAtoms(bytes, 'mdat');

        expect(trakAtoms.length, equals(2));
        expect(moovAtoms.length, equals(1));
        expect(missingAtoms, isEmpty);
      });
    });

    group('findAtomByPath', () {
      test('finds atom by hierarchical path', () {
        // Create nested structure: moov -> udta -> meta
        final metaData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        final udtaData = Uint8List.fromList([
          // meta atom inside udta
          0x00, 0x00, 0x00, 0x0C, // size: 12
          0x6D, 0x65, 0x74, 0x61, // type: "meta"
          ...metaData,
        ]);
        final moovData = Uint8List.fromList([
          // udta atom inside moov
          0x00, 0x00, 0x00, 0x14, // size: 20
          0x75, 0x64, 0x74, 0x61, // type: "udta"
          ...udtaData,
        ]);
        final fileData = Uint8List.fromList([
          // moov atom at top level
          0x00, 0x00, 0x00, 0x1C, // size: 28
          0x6D, 0x6F, 0x6F, 0x76, // type: "moov"
          ...moovData,
        ]);

        final metaAtom = Mp4AtomParser.findAtomByPath(fileData, ['moov', 'udta', 'meta']);
        expect(metaAtom, isNotNull);
        expect(metaAtom!.header.type, equals('meta'));
        expect(metaAtom.data, equals(metaData));

        final missingAtom = Mp4AtomParser.findAtomByPath(fileData, ['moov', 'udta', 'ilst']);
        expect(missingAtom, isNull);

        final emptyPath = Mp4AtomParser.findAtomByPath(fileData, []);
        expect(emptyPath, isNull);
      });
    });

    group('extractAtomData', () {
      test('extracts atom data by path', () {
        final testData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x0C, // size: 12
          0x74, 0x65, 0x73, 0x74, // type: "test"
          ...testData,
        ]);

        final data = Mp4AtomParser.extractAtomData(bytes, ['test']);
        expect(data, equals(testData));

        final missingData = Mp4AtomParser.extractAtomData(bytes, ['missing']);
        expect(missingData, isNull);
      });
    });

    group('getAtomHeaders', () {
      test('gets headers without parsing data', () {
        final bytes = Uint8List.fromList([
          // First atom
          0x00, 0x00, 0x00, 0x10,
          0x66, 0x74, 0x79, 0x70,
          ...List.filled(8, 0x00),
          // Second atom
          0x00, 0x00, 0x00, 0x0C,
          0x6D, 0x6F, 0x6F, 0x76,
          ...List.filled(4, 0x00),
        ]);

        final headers = Mp4AtomParser.getAtomHeaders(bytes);

        expect(headers.length, equals(2));
        expect(headers[0].type, equals('ftyp'));
        expect(headers[0].size, equals(16));
        expect(headers[1].type, equals('moov'));
        expect(headers[1].size, equals(12));
      });

      test('handles malformed data gracefully', () {
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10,
          0x66, 0x74, 0x79, 0x70,
          0x01, 0x02, // Incomplete data
        ]);

        final headers = Mp4AtomParser.getAtomHeaders(bytes);
        expect(headers.length, equals(1)); // Should parse first header only
        expect(headers[0].type, equals('ftyp'));
      });
    });

    group('isValidAtomData', () {
      test('validates correct atom data', () {
        final bytes = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x08,
          0x66,
          0x72,
          0x65,
          0x65,
        ]);

        expect(Mp4AtomParser.isValidAtomData(bytes), isTrue);
      });

      test('rejects invalid atom data', () {
        expect(Mp4AtomParser.isValidAtomData(Uint8List.fromList([])), isFalse);
        expect(Mp4AtomParser.isValidAtomData(Uint8List.fromList([0x00, 0x00])), isFalse);

        // Invalid size
        final invalidSize = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x07, // size: 7 (invalid)
          0x66, 0x72, 0x65, 0x65,
        ]);
        expect(Mp4AtomParser.isValidAtomData(invalidSize), isFalse);
      });
    });
  });
}
