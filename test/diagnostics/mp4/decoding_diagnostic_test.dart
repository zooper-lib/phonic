// ignore_for_file: avoid_print

import 'dart:io';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Diagnostic tests specifically for MP4 READING/DECODING issues.
///
/// The fixture file `test/fixtures/mp4/23.mp4` is known to contain:
/// - Genre: RNB/HIPHOP
/// - Title: Peaches & Cream (Intro) (Clean)
///
/// But our library is reading it as empty. This test investigates why.
void main() {
  group('MP4 Reading Diagnostic Tests', () {
    const mp4FixturePath = 'test/fixtures/mp4/23.mp4';

    test('What metadata does the library actually read?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      print('=== MP4 Metadata Reading Test ===');
      print('File: $mp4FixturePath');
      print('File size: ${await File(mp4FixturePath).length()} bytes');
      print('');

      print('Expected metadata (from external tool):');
      print('  Genre: RNB/HIPHOP');
      print('  Title: Peaches & Cream (Intro) (Clean)');
      print('');

      print('What our library reads:');

      // Try to read all common tags
      final title = audioFile.getTag(TagKey.title);
      final artist = audioFile.getTag(TagKey.artist);
      final album = audioFile.getTag(TagKey.album);
      final genre = audioFile.getTags(TagKey.genre);
      final year = audioFile.getTag(TagKey.year);
      final trackNumber = audioFile.getTag(TagKey.trackNumber);
      final comment = audioFile.getTag(TagKey.comment);
      final albumArtist = audioFile.getTag(TagKey.albumArtist);
      final composer = audioFile.getTag(TagKey.composer);
      final grouping = audioFile.getTag(TagKey.grouping);
      final bpm = audioFile.getTag(TagKey.bpm);
      final rating = audioFile.getTag(TagKey.rating);

      print('  Title: ${title?.value ?? "NOT FOUND"}');
      print('  Artist: ${artist?.value ?? "NOT FOUND"}');
      print('  Album: ${album?.value ?? "NOT FOUND"}');
      print('  Genre: ${genre.isNotEmpty ? (genre.first as GenreTag).value.join(", ") : "NOT FOUND"}');
      print('  Year: ${year?.value ?? "NOT FOUND"}');
      print('  Track: ${trackNumber?.value ?? "NOT FOUND"}');
      print('  Comment: ${comment?.value ?? "NOT FOUND"}');
      print('  Album Artist: ${albumArtist?.value ?? "NOT FOUND"}');
      print('  Composer: ${composer?.value ?? "NOT FOUND"}');
      print('  Grouping: ${grouping?.value ?? "NOT FOUND"}');
      print('  BPM: ${bpm?.value ?? "NOT FOUND"}');
      print('  Rating: ${rating?.value ?? "NOT FOUND"}');
      print('');

      // Check if we're reading ANYTHING
      final allTags = [title, artist, album, year, trackNumber, comment, albumArtist, composer, grouping, bpm, rating];
      final foundTags = allTags.where((tag) => tag != null).length;
      final foundGenres = genre.length;

      print('Summary:');
      print('  Total tags found: ${foundTags + foundGenres}');
      print('  Total tags expected: at least 2 (Title + Genre)');
      print('');

      if (foundTags + foundGenres == 0) {
        print('❌ CRITICAL: Library is reading ZERO metadata from MP4 file!');
        print('   This confirms MP4 DECODING is broken, not just encoding.');
      } else if (title?.value != 'Peaches & Cream (Intro) (Clean)') {
        print('⚠️  Library is reading SOME metadata but VALUES are wrong');
        print('   Expected title: "Peaches & Cream (Intro) (Clean)"');
        print('   Got title: "${title?.value ?? "NULL"}"');
      } else {
        print('✓ Library correctly reads MP4 metadata');
      }

      audioFile.dispose();

      // This test should fail to highlight the issue
      expect(title?.value, equals('Peaches & Cream (Intro) (Clean)'), reason: 'MP4 title should be read correctly');
      expect(genre.isNotEmpty, isTrue, reason: 'MP4 genre should be present');
    });

    test('Can we at least detect the MP4 container type?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      // Try to access any container information
      print('Container detection test:');

      // Check if any tags have provenance that indicates MP4
      final title = audioFile.getTag(TagKey.title);
      if (title != null) {
        print('  Title provenance: ${title.provenance}');
      } else {
        print('  No title found to check provenance');
      }

      audioFile.dispose();
    });

    test('Raw file inspection - MP4 atom structure', () async {
      final bytes = await File(mp4FixturePath).readAsBytes();

      print('=== Raw MP4 File Analysis ===');
      print('File size: ${bytes.length} bytes');
      print('');

      // Check for MP4 signatures
      print('MP4 Signatures:');
      if (bytes.length >= 12) {
        final ftypCheck = String.fromCharCodes(bytes.skip(4).take(4));
        print('  Byte 4-7 (ftyp check): "$ftypCheck"');

        if (ftypCheck == 'ftyp') {
          print('  ✓ Valid MP4 ftyp atom found');
          final brand = String.fromCharCodes(bytes.skip(8).take(4));
          print('  Brand: "$brand"');
        } else {
          print('  ✗ No ftyp atom at expected position');
        }
      }
      print('');

      // Search for metadata atoms
      print('Searching for metadata atoms:');
      final fileStr = String.fromCharCodes(bytes);

      final hasIlst = fileStr.contains('ilst');
      final hasMeta = fileStr.contains('meta');
      final hasUdta = fileStr.contains('udta');
      final hasMoov = fileStr.contains('moov');
      final hasNam = fileStr.contains('©nam'); // Title atom
      final hasGen = fileStr.contains('©gen'); // Genre atom

      print('  moov atom: ${hasMoov ? "FOUND" : "NOT FOUND"}');
      print('  udta atom: ${hasUdta ? "FOUND" : "NOT FOUND"}');
      print('  meta atom: ${hasMeta ? "FOUND" : "NOT FOUND"}');
      print('  ilst atom: ${hasIlst ? "FOUND" : "NOT FOUND"} (iTunes metadata container)');
      print('  ©nam atom: ${hasNam ? "FOUND" : "NOT FOUND"} (title)');
      print('  ©gen atom: ${hasGen ? "FOUND" : "NOT FOUND"} (genre)');
      print('');

      if (hasIlst && hasNam) {
        print('✓ File contains iTunes metadata atoms - metadata IS present in file');
        print('✗ But library is not reading it correctly!');
        print('  → MP4 DECODER has bugs in atom parsing');
      } else if (!hasIlst) {
        print('⚠️  No ilst atom found - metadata might be in different format');
      }

      // Try to find the actual metadata values
      print('');
      print('Searching for expected text values in file:');
      final hasTitle = fileStr.contains('Peaches & Cream');
      final hasGenreText = fileStr.contains('RNB/HIPHOP') || fileStr.contains('HIPHOP');

      print('  "Peaches & Cream": ${hasTitle ? "FOUND" : "NOT FOUND"}');
      print('  "RNB/HIPHOP" or "HIPHOP": ${hasGenreText ? "FOUND" : "NOT FOUND"}');

      if (hasTitle || hasGenreText) {
        print('');
        print('✓ Metadata text IS present in the file as raw bytes');
        print('✗ MP4 decoder is failing to extract it from atoms');
      }
    });

    test('Try to manually locate metadata atoms', () async {
      final bytes = await File(mp4FixturePath).readAsBytes();

      print('=== Manual Atom Location ===');

      // Search for ©nam atom (title)
      int? namPos;
      for (int i = 0; i < bytes.length - 4; i++) {
        if (bytes[i] == 0xA9 && // © character
            bytes[i + 1] == 0x6E && // n
            bytes[i + 2] == 0x61 && // a
            bytes[i + 3] == 0x6D) {
          // m
          namPos = i;
          print('Found ©nam atom at position: $i');

          // Try to extract the value
          // MP4 atom structure: [size:4][type:4][data...]
          if (i >= 8) {
            final atomSize = (bytes[i - 8] << 24) | (bytes[i - 7] << 16) | (bytes[i - 6] << 8) | bytes[i - 5];
            print('  Atom size: $atomSize bytes');

            // data atom is usually nested: [size:4]['data'][version:4][flags:4][value...]
            if (i + 20 < bytes.length) {
              final dataStart = i + 16; // Skip ©nam + data atom header
              final dataEnd = i + atomSize - 8;
              if (dataEnd <= bytes.length && dataEnd > dataStart) {
                try {
                  final value = String.fromCharCodes(bytes.skip(dataStart).take(dataEnd - dataStart));
                  print('  Extracted value: "$value"');
                } catch (e) {
                  print('  Error extracting value: $e');
                }
              }
            }
          }
          break;
        }
      }

      if (namPos == null) {
        print('Could not find ©nam atom in expected format');

        // Try alternative search
        print('');
        print('Alternative search for title text:');
        final titleBytes = 'Peaches & Cream'.codeUnits;
        for (int i = 0; i < bytes.length - titleBytes.length; i++) {
          bool match = true;
          for (int j = 0; j < titleBytes.length; j++) {
            if (bytes[i + j] != titleBytes[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            print('  Found title text at byte position: $i');
            print('  Context (20 bytes before):');
            final contextStart = i > 20 ? i - 20 : 0;
            final context = bytes.skip(contextStart).take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            print('    $context');
            break;
          }
        }
      }
    });
  });
}
