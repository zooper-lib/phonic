// ignore_for_file: avoid_print

import 'dart:io';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/mp4/mp4_atoms_codec.dart';
import 'package:phonic/src/utils/locators/mp4_locator.dart';
import 'package:phonic/src/utils/mp4_atom_parser.dart';
import 'package:test/test.dart';

void main() {
  test('Debug genre atom writing', () async {
    print('=== Genre Atom Writing Debug ===\n');

    // Read original
    final fileBytes = await File('test/fixtures/mp4/23.mp4').readAsBytes();
    final locator = Mp4Locator();
    final codec = const Mp4AtomsCodec();

    final ilstData = locator.extract(fileBytes)!;
    final tags = codec.readFromContainer(ilstData);

    print('Original tags read: ${tags.length}');
    final genreTag = tags.where((t) => t.key == 'genre').firstOrNull;
    if (genreTag != null) {
      print('Genre tag found: ${genreTag.value}');
    }

    // Write tags
    print('\nWriting tags...');
    final newIlstData = codec.writeToContainer(tagsToWrite: tags);
    print('New ilst data size: ${newIlstData.length} bytes');

    // Parse what was written
    print('\nParsing written atoms...');
    final writtenAtoms = Mp4AtomParser.parseAtoms(newIlstData);
    for (final atom in writtenAtoms) {
      if (atom.header.type == '©gen') {
        print('  Found ©gen atom:');
        print('    Total size: ${atom.header.size} bytes');
        print('    Data size: ${atom.data.length} bytes');
        print('    Data hex: ${_toHex(atom.data.take(50).toList())}');

        // Try to extract the text
        if (atom.data.length >= 16) {
          final textStart = 24; // After nested data atom header + flags
          final textBytes = atom.data.sublist(textStart - 8); // Adjust for atom.data starting point
          print('    Text bytes: ${_toHex(textBytes.take(20).toList())}');
          final text = String.fromCharCodes(textBytes.takeWhile((b) => b != 0).toList());
          print('    Extracted text: "$text"');
        }
      }
    }

    // Now read it back
    print('\nReading back via codec...');
    try {
      final readBackTags = codec.readFromContainer(newIlstData);
      print('Successfully read ${readBackTags.length} tags');
      for (final tag in readBackTags) {
        print('  - ${tag.key}: ${tag.value}');
      }
      final readBackGenre = readBackTags.where((t) => t.key == TagKey.genre).firstOrNull;
      if (readBackGenre != null) {
        print('Read back genre: ${readBackGenre.value}');
      } else {
        print('WARNING: Genre tag not found in read-back tags!');
      }
    } catch (e, stackTrace) {
      print('ERROR reading back: $e');
      print('Stack trace: $stackTrace');
    }
  });
}

String _toHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
