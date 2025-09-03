// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('Validation Debug Tests', () {
    late List<String> testFiles;

    setUpAll(() async {
      // Get the first few fixture files for debugging
      final fixturesDir = Directory('test/fixtures/mp3');
      final files = fixturesDir.listSync().whereType<File>().where((file) => file.path.endsWith('.mp3')).map((file) => file.path).take(3).toList();

      testFiles = files;
      print('Debugging validation with files: ${files.map((f) => f.split('/').last).join(', ')}');
    });

    test('Debug validation failures', () async {
      for (final testFile in testFiles) {
        print('\n=== DEBUGGING ${testFile.split('/').last} ===');

        try {
          final audioFile = await Phonic.fromFile(testFile);

          // Show original metadata
          final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
          final artistTag = audioFile.getTag(TagKey.artist) as ArtistTag?;
          print('Original Title: ${titleTag?.value ?? "None"}');
          print('Original Artist: ${artistTag?.value ?? "None"}');

          // Modify metadata
          audioFile.setTag(const TitleTag('Test Title'));
          audioFile.setTag(const ArtistTag('Test Artist'));
          audioFile.setTag(YearTag(2024));

          print('Modified metadata, isDirty: ${audioFile.isDirty}');

          // Try to encode with basic validation
          try {
            final encodingOptions = const EncodingOptions(
              strategy: EncodingStrategy.preserveExisting,
              validationLevel: ValidationLevel.basic,
            );

            final encodedBytes = await audioFile.encode(encodingOptions);
            print('✓ Encoding successful! Size: ${encodedBytes.length} bytes');
          } catch (e) {
            print('✗ Encoding failed: $e');

            // If it's a validation exception, let's get more details
            if (e.toString().contains('Post-write validation failed')) {
              print('This is a post-write validation failure.');
              print('The issue is in our validation logic, not the original file.');

              // Try to get the raw encoded bytes without validation
              try {
                print('Attempting to bypass validation to see if encoding itself works...');

                // We need to access the internal encoding without validation
                // This will help us understand if the issue is encoding or validation
              } catch (e2) {
                print('Even basic encoding failed: $e2');
              }
            }
          }

          audioFile.dispose();
        } catch (e) {
          print('✗ Failed to load file: $e');
        }
      }
    });

    test('Try different validation levels', () async {
      final testFile = testFiles.first;
      print('\n=== TESTING VALIDATION LEVELS on ${testFile.split('/').last} ===');

      final audioFile = await Phonic.fromFile(testFile);
      audioFile.setTag(const TitleTag('Validation Test'));

      for (final level in ValidationLevel.values) {
        try {
          final options = EncodingOptions(
            strategy: EncodingStrategy.preserveExisting,
            validationLevel: level,
          );

          final encodedBytes = await audioFile.encode(options);
          print('✓ ${level.name} validation: SUCCESS (${encodedBytes.length} bytes)');
        } catch (e) {
          print('✗ ${level.name} validation: FAILED - $e');
        }
      }

      audioFile.dispose();
    });

    test('Compare encoding strategies', () async {
      final testFile = testFiles.first;
      print('\n=== TESTING ENCODING STRATEGIES on ${testFile.split('/').last} ===');

      for (final strategy in EncodingStrategy.values) {
        try {
          final audioFile = await Phonic.fromFile(testFile);
          audioFile.setTag(const TitleTag('Strategy Test'));

          final options = EncodingOptions(
            strategy: strategy,
            validationLevel: ValidationLevel.basic,
          );

          final encodedBytes = await audioFile.encode(options);
          print('✓ ${strategy.name} strategy: SUCCESS (${encodedBytes.length} bytes)');

          audioFile.dispose();
        } catch (e) {
          print('✗ ${strategy.name} strategy: FAILED - $e');
        }
      }
    });
  });
}
