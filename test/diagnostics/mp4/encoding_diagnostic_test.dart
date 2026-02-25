// ignore_for_file: avoid_print

import 'dart:io';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Diagnostic tests to investigate MP4 encoding/decoding issues.
///
/// These tests help identify the exact point of failure in the MP4 workflow.
void main() {
  group('MP4 Diagnostic Tests', () {
    const mp4FixturePath = 'test/fixtures/mp4/23.mp4';

    test('Step 1: Can we load the MP4 file?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);
      expect(audioFile, isNotNull);
      print('✓ MP4 file loaded successfully');
      audioFile.dispose();
    });

    test('Step 2: Can we read existing metadata from MP4?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      print('Reading existing metadata...');
      print('  Title: ${audioFile.getTag(TagKey.title)?.value ?? "None"}');
      print('  Artist: ${audioFile.getTag(TagKey.artist)?.value ?? "None"}');
      print('  Album: ${audioFile.getTag(TagKey.album)?.value ?? "None"}');
      print('  Year: ${audioFile.getTag(TagKey.year)?.value ?? "None"}');

      audioFile.dispose();
    });

    test('Step 3: Can we modify metadata without encoding?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      audioFile.setTag(const TitleTag('Test Title'));
      audioFile.setTag(const ArtistTag('Test Artist'));

      expect(audioFile.isDirty, isTrue, reason: 'File should be marked as dirty');
      expect(audioFile.getTag(TagKey.title)?.value, equals('Test Title'));
      expect(audioFile.getTag(TagKey.artist)?.value, equals('Test Artist'));

      print('✓ Metadata modification works (in-memory)');
      audioFile.dispose();
    });

    test('Step 4: What happens when we encode MP4 (no validation)?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      audioFile.setTag(const TitleTag('Diagnostic Test'));
      audioFile.setTag(const ArtistTag('Diagnostic Artist'));

      print('Encoding MP4 without strict validation...');

      // Use basic validation (minimal checks)
      final encodingOptions = const EncodingOptions(
        strategy: EncodingStrategy.preserveExisting,
        validationLevel: ValidationLevel.basic,
      );

      final encodedBytes = await audioFile.encode(encodingOptions);

      print('✓ Encoding completed without errors');
      print('  Encoded size: ${encodedBytes.length} bytes');
      print('  Original file size: ${await File(mp4FixturePath).length()} bytes');

      // Write to temp file for manual inspection
      final tempFile = File('test/fixtures/mp4/23_diagnostic_output.mp4');
      await tempFile.writeAsBytes(encodedBytes);
      print('  Output written to: ${tempFile.path}');

      audioFile.dispose();
    });

    test('Step 5: Can we decode our own encoded MP4?', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      audioFile.setTag(const TitleTag('Decode Test'));
      audioFile.setTag(const ArtistTag('Decode Artist'));
      audioFile.setTag(const AlbumTag('Decode Album'));

      final encodedBytes = await audioFile.encode(
        const EncodingOptions(
          strategy: EncodingStrategy.preserveExisting,
          validationLevel: ValidationLevel.basic,
        ),
      );
      audioFile.dispose();

      print('Attempting to decode our encoded MP4...');

      try {
        final decodedFile = await Phonic.fromBytesAsync(encodedBytes);

        print('✓ Decoded successfully!');
        print('  Title: ${decodedFile.getTag(TagKey.title)?.value ?? "LOST"}');
        print('  Artist: ${decodedFile.getTag(TagKey.artist)?.value ?? "LOST"}');
        print('  Album: ${decodedFile.getTag(TagKey.album)?.value ?? "LOST"}');

        decodedFile.dispose();
      } catch (e) {
        print('✗ Decoding failed!');
        print('  Error: $e');
        fail('Cannot decode MP4 that we just encoded: $e');
      }
    });

    test('Step 6: Minimal MP4 encode test', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      // Set just ONE tag
      audioFile.setTag(const TitleTag('Single Tag Test'));

      final encodedBytes = await audioFile.encode(
        const EncodingOptions(
          strategy: EncodingStrategy.preserveExisting,
          validationLevel: ValidationLevel.basic,
        ),
      );
      audioFile.dispose();

      // Try to decode
      final decodedFile = await Phonic.fromBytesAsync(encodedBytes);
      final titleAfter = decodedFile.getTag(TagKey.title)?.value;

      print('Single tag test result:');
      print('  Expected: "Single Tag Test"');
      print('  Got: ${titleAfter ?? "NULL/LOST"}');

      if (titleAfter != 'Single Tag Test') {
        print('✗ Even a single tag is lost during round-trip!');
        print('  This confirms the MP4 encoding/decoding pipeline is broken');
      } else {
        print('✓ Single tag survived round-trip');
      }

      decodedFile.dispose();
    });

    test('Step 7: Check MP4 atom structure (if possible)', () async {
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);

      audioFile.setTag(const TitleTag('Structure Test'));

      final encodedBytes = await audioFile.encode(
        const EncodingOptions(
          strategy: EncodingStrategy.preserveExisting,
          validationLevel: ValidationLevel.basic,
        ),
      );

      print('Checking MP4 file structure...');
      print('  First 100 bytes (hex):');

      // Print first 100 bytes in hex to check MP4 structure
      final hexDump = encodedBytes.take(100).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      print('  $hexDump');

      // Check for MP4 signatures
      final hasIsom = String.fromCharCodes(encodedBytes.skip(4).take(4)) == 'ftyp';
      final hasM4a = encodedBytes.length > 20 && String.fromCharCodes(encodedBytes.skip(8).take(4)) == 'M4A ';

      print('  Has ftyp box: $hasIsom');
      print('  Has M4A signature: $hasM4a');

      audioFile.dispose();
    });

    test('Step 8: Compare original vs encoded file structure', () async {
      // Read original file
      final originalBytes = await File(mp4FixturePath).readAsBytes();

      // Encode with no changes
      final audioFile = await Phonic.fromFileAsync(mp4FixturePath);
      final encodedBytes = await audioFile.encode(
        const EncodingOptions(
          strategy: EncodingStrategy.preserveExisting,
          validationLevel: ValidationLevel.basic,
        ),
      );
      audioFile.dispose();

      print('File comparison:');
      print('  Original size: ${originalBytes.length} bytes');
      print('  Encoded size: ${encodedBytes.length} bytes');
      print('  Size difference: ${encodedBytes.length - originalBytes.length} bytes');

      // Check if files are identical
      final areIdentical =
          originalBytes.length == encodedBytes.length && List.generate(originalBytes.length, (i) => originalBytes[i] == encodedBytes[i]).every((e) => e);

      if (areIdentical) {
        print('  Files are byte-for-byte identical (unexpected for modified file)');
      } else {
        print('  Files differ (expected)');
      }

      // Find first difference
      for (int i = 0; i < originalBytes.length && i < encodedBytes.length; i++) {
        if (originalBytes[i] != encodedBytes[i]) {
          print('  First difference at byte $i:');
          print('    Original: 0x${originalBytes[i].toRadixString(16).padLeft(2, '0')}');
          print('    Encoded:  0x${encodedBytes[i].toRadixString(16).padLeft(2, '0')}');
          break;
        }
      }
    });
  });
}
