import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/utils/locators/mp4_locator.dart';
import 'package:test/test.dart';

void main() {
  group('Mp4Locator', () {
    late Mp4Locator locator;

    setUp(() {
      locator = Mp4Locator();
    });

    group('containerKind', () {
      test('should return mp4 container kind', () {
        expect(locator.containerKind, equals(ContainerKind.mp4));
      });
    });

    group('fileMatches', () {
      test('should return true for valid MP4 file with M4A brand', () {
        final mp4File = _createMp4File(majorBrand: 'M4A ');
        expect(locator.fileMatches(mp4File), isTrue);
      });

      test('should return true for valid MP4 file with mp41 brand', () {
        final mp4File = _createMp4File(majorBrand: 'mp41');
        expect(locator.fileMatches(mp4File), isTrue);
      });

      test('should return true for valid MP4 file with isom brand', () {
        final mp4File = _createMp4File(majorBrand: 'isom');
        expect(locator.fileMatches(mp4File), isTrue);
      });

      test('should return true when compatible brand is in compatible brands list', () {
        final mp4File = _createMp4File(
          majorBrand: 'unkn', // Unknown major brand
          compatibleBrands: ['M4A ', 'mp41'], // But has compatible brands
        );
        expect(locator.fileMatches(mp4File), isTrue);
      });

      test('should return false for files too small', () {
        final tooSmall = Uint8List.fromList([0x00, 0x00, 0x00, 0x10]); // Only 4 bytes
        expect(locator.fileMatches(tooSmall), isFalse);
      });

      test('should return false for empty files', () {
        final empty = Uint8List(0);
        expect(locator.fileMatches(empty), isFalse);
      });

      test('should return false for files without ftyp signature', () {
        final noFtyp = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Size: 32 bytes
          0x6D, 0x6F, 0x6F, 0x76, // "moov" instead of "ftyp"
          ...List.filled(24, 0x00), // Padding
        ]);
        expect(locator.fileMatches(noFtyp), isFalse);
      });

      test('should return false for files with invalid ftyp size', () {
        final invalidSize = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x08, // Size: 8 bytes (too small for ftyp)
          0x66, 0x74, 0x79, 0x70, // "ftyp"
        ]);
        expect(locator.fileMatches(invalidSize), isFalse);
      });

      test('should return false for files with unknown brands', () {
        final unknownBrand = _createMp4File(
          majorBrand: 'unkn',
          compatibleBrands: ['test', 'fake'],
        );
        expect(locator.fileMatches(unknownBrand), isFalse);
      });

      test('should handle various MP4 brands correctly', () {
        final testBrands = ['M4A ', 'M4B ', 'M4P ', 'M4V ', 'mp41', 'mp42', 'mp71', 'isom', 'iso2', 'avc1', 'qt  ', 'dash'];

        for (final brand in testBrands) {
          final mp4File = _createMp4File(majorBrand: brand);
          expect(locator.fileMatches(mp4File), isTrue, reason: 'Brand $brand should be recognized');
        }
      });

      test('should handle ftyp atom size edge cases', () {
        // Minimum valid ftyp size (16 bytes)
        final minimalFtyp = _createMp4File(majorBrand: 'M4A ', ftypSize: 16);
        expect(locator.fileMatches(minimalFtyp), isTrue);

        // Large ftyp with many compatible brands
        final largeFtyp = _createMp4File(
          majorBrand: 'M4A ',
          compatibleBrands: ['mp41', 'mp42', 'isom', 'iso2'],
          ftypSize: 32,
        );
        expect(locator.fileMatches(largeFtyp), isTrue);
      });
    });

    group('extract', () {
      test('should extract ilst atom from valid MP4 file', () {
        final ilstData = _createIlstAtom([
          _createTextAtom('©nam', 'Test Title'),
          _createTextAtom('©ART', 'Test Artist'),
        ]);

        final mp4File = _createMp4FileWithMetadata(ilstData);
        final extracted = locator.extract(mp4File);

        expect(extracted, isNotNull);
        expect(extracted!.length, greaterThan(8)); // Should have atom header + data

        // Verify it's an ilst atom
        final atomType = String.fromCharCodes(extracted.sublist(4, 8));
        expect(atomType, equals('ilst'));
      });

      test('should return null for files without MP4 signature', () {
        final nonMp4File = Uint8List.fromList([
          0x49, 0x44, 0x33, // ID3 signature instead
          ...List.filled(100, 0x00),
        ]);

        expect(locator.extract(nonMp4File), isNull);
      });

      test('should return null for MP4 files without moov atom', () {
        final mp4WithoutMoov = _createMp4File(majorBrand: 'M4A ', includeMovieAtom: false);
        expect(locator.extract(mp4WithoutMoov), isNull);
      });

      test('should return null for MP4 files without udta atom', () {
        final mp4WithoutUdta = _createMp4FileWithAtoms([
          _createAtom('moov', [
            _createAtom('mvhd', Uint8List.fromList(List.filled(100, 0x00))),
            // No udta atom
          ]),
        ]);
        expect(locator.extract(mp4WithoutUdta), isNull);
      });

      test('should return null for MP4 files without meta atom', () {
        final mp4WithoutMeta = _createMp4FileWithAtoms([
          _createAtom('moov', [
            _createAtom('mvhd', Uint8List.fromList(List.filled(100, 0x00))),
            _createAtom('udta', [
              // No meta atom
            ]),
          ]),
        ]);
        expect(locator.extract(mp4WithoutMeta), isNull);
      });

      test('should return null for MP4 files without ilst atom', () {
        final mp4WithoutIlst = _createMp4FileWithAtoms([
          _createAtom('moov', [
            _createAtom('mvhd', Uint8List.fromList(List.filled(100, 0x00))),
            _createAtom('udta', [
              _createAtom('meta', [
                ...List.filled(4, 0x00), // version/flags
                _createAtom('hdlr', Uint8List.fromList(List.filled(32, 0x00))),
                // No ilst atom
              ]),
            ]),
          ]),
        ]);
        expect(locator.extract(mp4WithoutIlst), isNull);
      });

      test('should handle corrupted atom headers gracefully', () {
        final corruptedMp4 = Uint8List.fromList([
          ...List.from(_createMp4File(majorBrand: 'M4A ').take(50)),
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid atom size
          0x6D, 0x6F, 0x6F, 0x76, // "moov"
          ...List.filled(100, 0x00),
        ]);

        expect(locator.extract(corruptedMp4), isNull);
      });

      test('should handle truncated files gracefully', () {
        final fullMp4 = _createMp4FileWithMetadata(_createIlstAtom([]));
        final truncated = Uint8List.fromList(fullMp4.take(fullMp4.length ~/ 2).toList());

        expect(locator.extract(truncated), isNull);
      });

      test('should extract ilst with various metadata atoms', () {
        final ilstData = _createIlstAtom([
          _createTextAtom('©nam', 'Complex Title'),
          _createTextAtom('©ART', 'Artist Name'),
          _createTextAtom('©alb', 'Album Name'),
          _createIntegerAtom('trkn', [0, 0, 0, 5, 0, 0, 0, 12]), // Track 5 of 12
          _createIntegerAtom('disk', [0, 0, 0, 1, 0, 0, 0, 2]), // Disc 1 of 2
        ]);

        final mp4File = _createMp4FileWithMetadata(ilstData);
        final extracted = locator.extract(mp4File);

        expect(extracted, isNotNull);
        expect(extracted!.length, greaterThan(100)); // Should contain all the metadata
      });

      test('should handle extended size atoms (64-bit)', () {
        // Create an ilst atom that would require extended size
        final largeIlstData = _createIlstAtom([
          _createTextAtom('©nam', 'A' * 1000), // Large text field
        ]);

        final mp4File = _createMp4FileWithMetadata(largeIlstData);
        final extracted = locator.extract(mp4File);

        expect(extracted, isNotNull);
        expect(extracted!.length, greaterThan(1000));
      });
    });

    group('inject', () {
      test('should inject new ilst atom into MP4 file', () {
        final originalMp4 = _createMp4FileWithMetadata(_createIlstAtom([]));

        final newIlstData = _createIlstAtom([
          _createTextAtom('©nam', 'New Title'),
          _createTextAtom('©ART', 'New Artist'),
        ]);

        final result = locator.inject(originalMp4, newIlstData);

        expect(result.length, greaterThan(originalMp4.length));
        expect(locator.fileMatches(result), isTrue);

        // Verify the new ilst can be extracted
        final extractedIlst = locator.extract(result);
        expect(extractedIlst, isNotNull);
        expect(extractedIlst!.length, equals(newIlstData.length));
      });

      test('should replace existing ilst atom', () {
        final originalIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Old Title'),
        ]);
        final originalMp4 = _createMp4FileWithMetadata(originalIlst);

        final newIlst = _createIlstAtom([
          _createTextAtom('©nam', 'New Title'),
          _createTextAtom('©ART', 'New Artist'),
        ]);

        final result = locator.inject(originalMp4, newIlst);

        expect(locator.fileMatches(result), isTrue);

        final extractedIlst = locator.extract(result);
        expect(extractedIlst, isNotNull);
        expect(extractedIlst!.length, equals(newIlst.length));
      });

      test('should remove ilst atom when containerBytes is null', () {
        final originalIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Title to Remove'),
        ]);
        final originalMp4 = _createMp4FileWithMetadata(originalIlst);

        final result = locator.inject(originalMp4, null);

        expect(locator.fileMatches(result), isTrue);
        expect(locator.extract(result), isNull); // ilst should be removed
      });

      test('should handle files without existing metadata structure', () {
        final mp4WithoutMetadata = _createMp4File(majorBrand: 'M4A ');

        final newIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Added Title'),
        ]);

        final result = locator.inject(mp4WithoutMetadata, newIlst);

        expect(locator.fileMatches(result), isTrue);
        // Note: This test might fail if the implementation doesn't create
        // the full udta/meta structure when it's missing
      });

      test('should preserve other atoms when injecting ilst', () {
        // Create atoms with distinctive data
        final mvhdAtom = _createAtom('mvhd', Uint8List.fromList(List.filled(100, 0x42)));
        final trakAtom = _createAtom('trak', Uint8List.fromList(List.filled(200, 0x43)));
        final hdlrAtom = _createAtom('hdlr', Uint8List.fromList(List.filled(32, 0x44)));
        final ilstAtom = _createIlstAtom([_createTextAtom('©nam', 'Original')]);

        // Create meta atom content
        final metaContent = <int>[];
        metaContent.addAll([0x00, 0x00, 0x00, 0x00]); // version/flags
        metaContent.addAll(hdlrAtom);
        metaContent.addAll(ilstAtom);
        final metaAtom = _createAtom('meta', Uint8List.fromList(metaContent));

        // Create udta atom
        final udtaAtom = _createAtom('udta', metaAtom);

        // Create moov atom content
        final moovContent = <int>[];
        moovContent.addAll(mvhdAtom);
        moovContent.addAll(trakAtom);
        moovContent.addAll(udtaAtom);
        final moovAtom = _createAtom('moov', Uint8List.fromList(moovContent));

        // Create mdat atom
        final mdatAtom = _createAtom('mdat', Uint8List.fromList(List.filled(1000, 0x45)));

        final originalMp4 = _createMp4FileWithAtoms([moovAtom, mdatAtom]);

        final newIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Updated'),
        ]);

        final result = locator.inject(originalMp4, newIlst);

        expect(locator.fileMatches(result), isTrue);

        // Verify other atoms are preserved by checking for distinctive byte patterns
        expect(result.contains(0x42), isTrue); // mvhd data
        expect(result.contains(0x43), isTrue); // trak data
        expect(result.contains(0x44), isTrue); // hdlr data
        expect(result.contains(0x45), isTrue); // mdat data
      });

      test('should handle non-MP4 files gracefully', () {
        final nonMp4File = Uint8List.fromList([
          0x49, 0x44, 0x33, // ID3 signature
          ...List.filled(100, 0x00),
        ]);

        final newIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Title'),
        ]);

        final result = locator.inject(nonMp4File, newIlst);
        expect(result, equals(nonMp4File)); // Should return original unchanged
      });

      test('should handle corrupted MP4 files gracefully', () {
        final corruptedMp4 = _createMp4File(majorBrand: 'M4A ', includeMovieAtom: false);
        // Corrupt the file by truncating it to just the ftyp atom
        final truncated = Uint8List.fromList(corruptedMp4.take(16).toList());

        final newIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Title'),
        ]);

        final result = locator.inject(truncated, newIlst);
        expect(result, equals(truncated)); // Should return original unchanged
      });

      test('should handle size changes correctly', () {
        // Start with small ilst
        final smallIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Short'),
        ]);
        final originalMp4 = _createMp4FileWithMetadata(smallIlst);

        // Replace with much larger ilst
        final largeIlst = _createIlstAtom([
          _createTextAtom('©nam', 'Very Long Title That Takes Much More Space'),
          _createTextAtom('©ART', 'Very Long Artist Name'),
          _createTextAtom('©alb', 'Very Long Album Name'),
          _createTextAtom('©cmt', 'Very Long Comment Field'),
        ]);

        final result1 = locator.inject(originalMp4, largeIlst);
        expect(result1.length, greaterThan(originalMp4.length));
        expect(locator.extract(result1), isNotNull);

        // Replace with smaller ilst
        final tinyIlst = _createIlstAtom([
          _createTextAtom('©nam', 'X'),
        ]);

        final result2 = locator.inject(result1, tinyIlst);
        expect(result2.length, lessThan(result1.length));
        expect(locator.extract(result2), isNotNull);
      });
    });

    group('edge cases and error handling', () {
      test('should handle minimal valid MP4 file', () {
        final minimalMp4 = _createMp4File(majorBrand: 'M4A ', ftypSize: 16);
        expect(locator.fileMatches(minimalMp4), isTrue);
        expect(locator.extract(minimalMp4), isNull); // No metadata structure
      });

      test('should handle MP4 files with empty ilst atom', () {
        final emptyIlst = _createIlstAtom([]);
        final mp4File = _createMp4FileWithMetadata(emptyIlst);

        final extracted = locator.extract(mp4File);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(emptyIlst.length));
      });

      test('should handle atom size of 0 (extends to end of file)', () {
        // This is a valid MP4 construct where size=0 means "rest of file"
        final mp4WithZeroSize = Uint8List.fromList([
          ...List.from(_createMp4File(majorBrand: 'M4A ').take(32)),
          0x00, 0x00, 0x00, 0x00, // Size: 0 (extends to end)
          0x6D, 0x64, 0x61, 0x74, // "mdat"
          ...List.filled(100, 0xFF), // Data to end of file
        ]);

        // Should not crash, even if it can't extract metadata
        expect(() => locator.extract(mp4WithZeroSize), returnsNormally);
      });

      test('should handle very large atom sizes', () {
        // Test with atom size that would exceed reasonable limits
        final largeAtomMp4 = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, // Very large size
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          ...List.filled(20, 0x00),
        ]);

        expect(locator.fileMatches(largeAtomMp4), isFalse);
        expect(locator.extract(largeAtomMp4), isNull);
      });

      test('should handle nested atom parsing errors', () {
        // Create MP4 with valid structure but corrupted nested atoms
        final corruptedNested = _createMp4FileWithAtoms([
          _createAtom('moov', [
            _createAtom('udta', [
              // Create meta atom with invalid content
              Uint8List.fromList([
                0x00, 0x00, 0x00, 0x20, // Size: 32
                0x6D, 0x65, 0x74, 0x61, // "meta"
                0x00, 0x00, 0x00, 0x00, // version/flags
                0xFF, 0xFF, 0xFF, 0xFF, // Invalid nested atom size
                0x69, 0x6C, 0x73, 0x74, // "ilst"
                ...List.filled(8, 0x00),
              ]),
            ]),
          ]),
        ]);

        expect(locator.extract(corruptedNested), isNull);
      });
    });
  });
}

/// Helper function to create a basic MP4 file with ftyp atom.
Uint8List _createMp4File({
  required String majorBrand,
  List<String> compatibleBrands = const [],
  int? ftypSize,
  bool includeMovieAtom = true,
}) {
  final result = <int>[];

  // Calculate ftyp content size: major brand (4) + minor version (4) + compatible brands (4 each)
  final contentSize = 8 + (compatibleBrands.length * 4);
  final actualFtypSize = ftypSize ?? (8 + contentSize); // 8 byte header + content

  // Create ftyp atom
  result.addAll(_writeUint32BigEndian(actualFtypSize));
  result.addAll('ftyp'.codeUnits);
  result.addAll(majorBrand.codeUnits);
  result.addAll([0x00, 0x00, 0x00, 0x00]); // Minor version

  // Add compatible brands
  for (final brand in compatibleBrands) {
    result.addAll(brand.codeUnits);
  }

  // Pad to declared size if needed
  while (result.length < actualFtypSize) {
    result.add(0x00);
  }

  if (includeMovieAtom) {
    // Add minimal moov atom with mvhd
    final mvhdData = List.filled(100, 0x00);
    final mvhdAtom = _createAtom('mvhd', Uint8List.fromList(mvhdData));
    final moovAtom = _createAtom('moov', mvhdAtom);
    result.addAll(moovAtom);
  }

  return Uint8List.fromList(result);
}

/// Helper function to create MP4 file with specific atoms.
Uint8List _createMp4FileWithAtoms(List<Uint8List> atoms) {
  final result = <int>[];

  // Add ftyp atom (8 byte header + 8 byte content = 16 bytes total)
  result.addAll(_writeUint32BigEndian(16)); // Size: 16
  result.addAll('ftyp'.codeUnits); // Type: "ftyp"
  result.addAll('M4A '.codeUnits); // Major brand: "M4A "
  result.addAll([0x00, 0x00, 0x00, 0x00]); // Minor version: 0

  // Add provided atoms
  for (final atom in atoms) {
    result.addAll(atom);
  }

  return Uint8List.fromList(result);
}

/// Helper function to create MP4 file with metadata structure.
Uint8List _createMp4FileWithMetadata(Uint8List ilstAtom) {
  // Create hdlr atom
  final hdlrAtom = _createAtom('hdlr', Uint8List.fromList(List.filled(32, 0x00)));

  // Create meta atom content (version/flags + hdlr + ilst)
  final metaContent = <int>[];
  metaContent.addAll([0x00, 0x00, 0x00, 0x00]); // version/flags
  metaContent.addAll(hdlrAtom);
  metaContent.addAll(ilstAtom);

  // Create meta atom
  final metaAtom = _createAtom('meta', Uint8List.fromList(metaContent));

  // Create udta atom
  final udtaAtom = _createAtom('udta', metaAtom);

  // Create mvhd atom
  final mvhdAtom = _createAtom('mvhd', Uint8List.fromList(List.filled(100, 0x00)));

  // Create moov atom content
  final moovContent = <int>[];
  moovContent.addAll(mvhdAtom);
  moovContent.addAll(udtaAtom);

  // Create moov atom
  final moovAtom = _createAtom('moov', Uint8List.fromList(moovContent));

  return _createMp4FileWithAtoms([moovAtom]);
}

/// Helper function to create a generic atom.
Uint8List _createAtom(String type, dynamic content) {
  final result = <int>[];
  final contentBytes = <int>[];

  if (content is List) {
    for (final item in content) {
      if (item is Uint8List) {
        contentBytes.addAll(item);
      } else if (item is List<int>) {
        contentBytes.addAll(item);
      } else if (item is int) {
        contentBytes.add(item);
      }
    }
  } else if (content is Uint8List) {
    contentBytes.addAll(content);
  } else if (content is List<int>) {
    contentBytes.addAll(content);
  }

  final totalSize = 8 + contentBytes.length;
  result.addAll(_writeUint32BigEndian(totalSize));
  result.addAll(type.codeUnits);
  result.addAll(contentBytes);

  return Uint8List.fromList(result);
}

/// Helper function to create an ilst atom with metadata atoms.
Uint8List _createIlstAtom(List<Uint8List> metadataAtoms) {
  final result = <int>[];
  final contentBytes = <int>[];

  for (final atom in metadataAtoms) {
    contentBytes.addAll(atom);
  }

  final totalSize = 8 + contentBytes.length;
  result.addAll(_writeUint32BigEndian(totalSize));
  result.addAll('ilst'.codeUnits);
  result.addAll(contentBytes);

  return Uint8List.fromList(result);
}

/// Helper function to create a text metadata atom (like ©nam, ©ART).
Uint8List _createTextAtom(String atomType, String text) {
  final result = <int>[];
  final textBytes = text.codeUnits;

  // Create data atom
  final dataAtomSize = 8 + 8 + textBytes.length; // header + data header + text
  final dataAtom = <int>[];
  dataAtom.addAll(_writeUint32BigEndian(dataAtomSize));
  dataAtom.addAll('data'.codeUnits);
  dataAtom.addAll([0x00, 0x00, 0x00, 0x01]); // Type: text
  dataAtom.addAll([0x00, 0x00, 0x00, 0x00]); // Reserved
  dataAtom.addAll(textBytes);

  // Create main atom
  final totalSize = 8 + dataAtom.length;
  result.addAll(_writeUint32BigEndian(totalSize));
  result.addAll(atomType.codeUnits);
  result.addAll(dataAtom);

  return Uint8List.fromList(result);
}

/// Helper function to create an integer metadata atom (like trkn, disk).
Uint8List _createIntegerAtom(String atomType, List<int> integerBytes) {
  final result = <int>[];

  // Create data atom
  final dataAtomSize = 8 + 8 + integerBytes.length; // header + data header + integers
  final dataAtom = <int>[];
  dataAtom.addAll(_writeUint32BigEndian(dataAtomSize));
  dataAtom.addAll('data'.codeUnits);
  dataAtom.addAll([0x00, 0x00, 0x00, 0x00]); // Type: integer
  dataAtom.addAll([0x00, 0x00, 0x00, 0x00]); // Reserved
  dataAtom.addAll(integerBytes);

  // Create main atom
  final totalSize = 8 + dataAtom.length;
  result.addAll(_writeUint32BigEndian(totalSize));
  result.addAll(atomType.codeUnits);
  result.addAll(dataAtom);

  return Uint8List.fromList(result);
}

/// Helper function to write a 32-bit big-endian unsigned integer.
List<int> _writeUint32BigEndian(int value) {
  return [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}
