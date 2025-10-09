// ignore_for_file: avoid_print

import 'dart:io';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Debug genre round-trip specifically
void main() {
  group('Genre Round-Trip Debug', () {
    const mp4FixturePath = 'test/fixtures/mp4/23.mp4';

    test('Trace genre through round-trip', () async {
      print('=== Genre Round-Trip Debug ===\n');

      // Step 1: Read original
      print('Step 1: Reading original file...');
      final audioFile = await Phonic.fromFile(mp4FixturePath);

      final originalGenreTags = audioFile.getTags(TagKey.genre);
      print('  Original genre tags count: ${originalGenreTags.length}');
      for (final tag in originalGenreTags) {
        final genreTag = tag as GenreTag;
        print('    Genre values: ${genreTag.value}');
        print('    As encoded string (semicolon): ${genreTag.toEncodedString(";")}');
        print('    As encoded string (comma): ${genreTag.toEncodedString(",")}');
      }

      // Step 2: DON'T modify, just write
      print('\nStep 2: Writing without modification...');
      final outputBytes = await audioFile.encode();
      await File('test/fixtures/mp4/genre_test.mp4').writeAsBytes(outputBytes);

      audioFile.dispose();

      // Step 3: Read back
      print('\nStep 3: Reading back...');
      final audioFile2 = await Phonic.fromFile('test/fixtures/mp4/genre_test.mp4');

      final roundTripGenreTags = audioFile2.getTags(TagKey.genre);
      print('  Round-trip genre tags count: ${roundTripGenreTags.length}');
      for (final tag in roundTripGenreTags) {
        final genreTag = tag as GenreTag;
        print('    Genre values: ${genreTag.value}');
        print('    As encoded string (semicolon): ${genreTag.toEncodedString(";")}');
      }

      audioFile2.dispose();

      // Cleanup
      await File('test/fixtures/mp4/genre_test.mp4').delete();
    });
  });
}
