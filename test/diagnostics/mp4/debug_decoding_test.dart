// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/src/formats/mp4/mp4_atoms_codec.dart';
import 'package:phonic/src/utils/locators/mp4_locator.dart';
import 'package:phonic/src/utils/mp4_atom_parser.dart';
import 'package:test/test.dart';

/// Debug test to trace the exact flow of MP4 decoding
void main() {
  group('MP4 Decoding Debug', () {
    const mp4FixturePath = 'test/fixtures/mp4/23.mp4';

    test('Step-by-step decoding trace', () async {
      print('=== MP4 Decoding Debug Trace ===\n');

      // Step 1: Load file
      final fileBytes = await File(mp4FixturePath).readAsBytes();
      print('Step 1: Loaded file');
      print('  File size: ${fileBytes.length} bytes\n');

      // Step 2: Use locator to extract ilst
      final locator = Mp4Locator();
      print('Step 2: Using Mp4Locator to extract ilst atom');
      final ilstBytes = locator.extract(fileBytes);

      if (ilstBytes == null) {
        print('  ❌ FAILED: Mp4Locator returned null!');
        print('  This means the locator could not find the ilst atom\n');
        fail('Mp4Locator failed to extract ilst atom');
      }

      print('  ✓ Successfully extracted ilst atom');
      print('  ilst size: ${ilstBytes.length} bytes');
      print('  ilst hex (first 32 bytes): ${_toHex(ilstBytes.take(32).toList())}\n');

      // Step 3: Parse atoms in ilst
      print('Step 3: Parsing atoms in ilst container');
      try {
        final atoms = Mp4AtomParser.parseAtoms(ilstBytes);
        print('  ✓ Successfully parsed ${atoms.length} atoms');

        for (final atom in atoms) {
          print('  - ${atom.header.type}: ${atom.header.size} bytes (data: ${atom.data.length} bytes)');
          if (atom.header.type == '©nam' || atom.header.type == '©gen') {
            print('    Data hex (first 32 bytes): ${_toHex(atom.data.take(32).toList())}');
          }
        }
        print('');
      } catch (e, stackTrace) {
        print('  ❌ FAILED to parse atoms: $e');
        print('  Stack trace: $stackTrace\n');
        rethrow;
      }

      // Step 4: Use codec to read tags
      print('Step 4: Using Mp4AtomsCodec to read tags');
      final codec = const Mp4AtomsCodec();

      try {
        final tags = codec.readFromContainer(ilstBytes);
        print('  ✓ Successfully read ${tags.length} tags');

        for (final tag in tags) {
          print('  - ${tag.key}: ${tag.value}');
        }
        print('');

        if (tags.isEmpty) {
          print('  ⚠️  WARNING: No tags were extracted!');
          print('  This means the codec could not parse any atoms into tags\n');
        }
      } catch (e, stackTrace) {
        print('  ❌ FAILED to read tags: $e');
        print('  Stack trace: $stackTrace\n');
        rethrow;
      }
    });

    test('Check if ilst bytes match expected structure', () async {
      final fileBytes = await File(mp4FixturePath).readAsBytes();
      final locator = Mp4Locator();
      final ilstBytes = locator.extract(fileBytes);

      expect(ilstBytes, isNotNull, reason: 'ilst atom should be found');

      print('\n=== ilst Atom Structure Check ===');
      print('ilst size field: ${_readUint32(ilstBytes!, 0)} bytes');
      print('ilst type field: ${String.fromCharCodes(ilstBytes.sublist(4, 8))}');
      print('\nFirst atom in ilst:');
      print('  Size: ${_readUint32(ilstBytes, 8)} bytes');
      print('  Type: ${String.fromCharCodes(ilstBytes.sublist(12, 16))}');

      // The ©nam type has character code 0xa9 for ©
      final firstAtomType = ilstBytes.sublist(12, 16);
      print('  Type bytes: ${_toHex(firstAtomType)}');

      if (firstAtomType[0] == 0xa9 && firstAtomType[1] == 0x6e && firstAtomType[2] == 0x61 && firstAtomType[3] == 0x6d) {
        print('  ✓ First atom is ©nam (title)');
      }
    });
  });
}

String _toHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}

int _readUint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
}
