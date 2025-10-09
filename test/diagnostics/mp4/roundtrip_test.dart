// ignore_for_file: avoid_print

import 'dart:io';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Test round-trip encoding/decoding with the fixed decoder
void main() {
  group('MP4 Round-Trip Test', () {
    const mp4FixturePath = 'test/fixtures/mp4/23.mp4';
    const outputPath = 'test/fixtures/mp4/23_roundtrip.mp4';

    test('Read, modify, write, and read again', () async {
      // Step 1: Read original file
      print('=== MP4 Round-Trip Test ===\n');
      print('Step 1: Reading original file...');
      final audioFile = await Phonic.fromFile(mp4FixturePath);

      final originalTitle = audioFile.getTag(TagKey.title)?.value;
      final originalGenre = audioFile.getTags(TagKey.genre);

      print('  Original title: $originalTitle');
      print('  Original genre: ${originalGenre.isNotEmpty ? (originalGenre.first as GenreTag).value.join(", ") : "NONE"}');

      // Step 2: Modify a tag
      print('\nStep 2: Modifying title...');
      audioFile.setTag(TitleTag('Modified Title'));
      final modifiedTitle = audioFile.getTag(TagKey.title)?.value;
      print('  New title: $modifiedTitle');

      // Step 3: Write to new file
      print('\nStep 3: Writing to new file...');
      final outputBytes = await audioFile.encode();
      await File(outputPath).writeAsBytes(outputBytes);
      print('  Saved to: $outputPath');

      audioFile.dispose();

      // Step 4: Read the new file back
      print('\nStep 4: Reading modified file...');
      final audioFile2 = await Phonic.fromFile(outputPath);

      final roundTripTitle = audioFile2.getTag(TagKey.title)?.value;
      final roundTripGenre = audioFile2.getTags(TagKey.genre);

      print('  Round-trip title: $roundTripTitle');
      print('  Round-trip genre: ${roundTripGenre.isNotEmpty ? (roundTripGenre.first as GenreTag).value.join(", ") : "NONE"}');

      // Verify
      expect(roundTripTitle, equals('Modified Title'));
      expect(roundTripGenre.isNotEmpty, isTrue);
      expect((roundTripGenre.first as GenreTag).value.join(", "), equals("RNB, HIPHOP"));

      print('\n✓ Round-trip successful!');

      audioFile2.dispose();

      // Cleanup
      await File(outputPath).delete();
    });
  });
}
