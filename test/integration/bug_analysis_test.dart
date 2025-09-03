// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

/// Bug Analysis and Fix Roadmap for Phonic Audio Processing
///
/// This test suite identifies specific bugs in the phonic library that prevent
/// the full load → modify → save workflow from working correctly.
///
/// IDENTIFIED BUGS:
/// 1. TAG_VALUE_INCONSISTENT: Tag values are inconsistent across containers (ID3v1 vs ID3v2)
/// 2. ROUND_TRIP_FAILED: ID3v2.3 vs ID3v2.4 version mismatch during round-trip validation
///
/// RECOMMENDED FIXES:
/// 1. Fix tag synchronization between ID3v1 and ID3v2 containers
/// 2. Fix ID3v2 version handling in round-trip validation
/// 3. Consider making validation levels more granular (some validations should be warnings, not errors)
void main() {
  group('Bug Analysis: Encoding Failures', () {
    late List<String> testFiles;

    setUpAll(() async {
      testFiles = await _getTestFiles();
      print('Analyzing ${testFiles.length} MP3 files for encoding bugs...');
    });

    test('BUG REPORT: Current encoding failures', () async {
      print('\n=== BUG ANALYSIS REPORT ===\n');

      final bugReport = <String, List<String>>{};
      int totalFiles = 0;
      int failedFiles = 0;

      // Use controlled set of test files instead of all fixtures
      final controlledTestFiles = testFiles.take(3).toList(); // Limit to 3 files for predictable testing

      for (final testFile in controlledTestFiles) {
        totalFiles++;
        PhonicAudioFile? audioFile;

        try {
          print('Testing file: ${testFile.split('/').last}');
          audioFile = await Phonic.fromFile(testFile);

          // First, let's see what's in this file
          final existingTags = audioFile.getAllTags();
          print('  Existing tags: ${existingTags.length}');
          for (final tag in existingTags.take(3)) {
            // Show first 3 tags
            print('    ${tag.key.name}: ${tag.value.toString().length > 30 ? '${tag.value.toString().substring(0, 30)}...' : tag.value}');
          }

          // Minimal modification to trigger encoding
          audioFile.setTag(const TitleTag('Bug Test'));

          // Try encoding with the most basic settings
          try {
            final encoded = await audioFile.encode(
              const EncodingOptions(
                strategy: EncodingStrategy.preserveExisting,
                validationLevel: ValidationLevel.basic,
              ),
            );
            print('  ✓ SUCCESS: File encoded (${encoded.length} bytes)');
          } catch (e) {
            failedFiles++;
            final fullError = e.toString();
            print('  ✗ FAILED: ${fullError.split('\n').first}');

            // Print more detailed error information for debugging
            if (fullError.contains('Post-write validation failed')) {
              final lines = fullError.split('\n');
              for (final line in lines.take(5)) {
                if (line.trim().isNotEmpty) {
                  print('    $line');
                }
              }
            }

            // Categorize the error
            if (fullError.contains('TAG_VALUE_CHANGED')) {
              bugReport.putIfAbsent('TAG_VALUE_CHANGED', () => []);
              bugReport['TAG_VALUE_CHANGED']!.add(testFile.split('/').last);
            }

            if (fullError.contains('TAG_LOST')) {
              bugReport.putIfAbsent('TAG_LOST', () => []);
              bugReport['TAG_LOST']!.add(testFile.split('/').last);
            }

            if (fullError.contains('ROUND_TRIP_FAILED')) {
              bugReport.putIfAbsent('ROUND_TRIP_FAILED', () => []);
              bugReport['ROUND_TRIP_FAILED']!.add(testFile.split('/').last);
            }

            if (fullError.contains('Validation failed')) {
              bugReport.putIfAbsent('VALIDATION_FAILED', () => []);
              bugReport['VALIDATION_FAILED']!.add(testFile.split('/').last);
            }
          }
        } finally {
          audioFile?.dispose();
        }
      }

      print('\n=== SUMMARY ===');
      print('Total files tested: $totalFiles');
      print('Files that failed: $failedFiles');
      print('Success rate: ${((totalFiles - failedFiles) / totalFiles * 100).toStringAsFixed(1)}%');

      print('\n=== BUG CATEGORIES ===');
      for (final category in bugReport.keys) {
        print('$category: ${bugReport[category]!.length} files affected');
        print('  Files: ${bugReport[category]!.join(', ')}');
      }

      print('\n=== RECOMMENDED FIXES ===');
      if (bugReport.containsKey('TAG_VALUE_INCONSISTENT')) {
        print('1. TAG_VALUE_INCONSISTENT Bug:');
        print('   - Issue: Tags are not synchronized between ID3v1 and ID3v2 containers');
        print('   - Fix: Implement proper tag synchronization logic');
        print('   - Location: Likely in tag merger or container rebuilder');
      }

      if (bugReport.containsKey('ROUND_TRIP_FAILED') || bugReport.containsKey('ID3_VERSION_MISMATCH')) {
        print('2. ID3 Version Mismatch Bug:');
        print('   - Issue: Round-trip validation expects ID3v2.3 but gets ID3v2.4');
        print('   - Fix: Either preserve original ID3 version or update validation expectations');
        print('   - Location: ID3v2 codec validation or version handling');
      }

      print('3. Validation Severity Bug:');
      print('   - Issue: Some validation failures should be warnings, not errors');
      print('   - Fix: Implement warning vs error classification in validation');
      print('   - Location: Validation system, ValidationLevel enum');

      print('\n=== INTEGRATION TEST EXPECTATION ===');
      print('Once these bugs are fixed, ALL integration tests should pass.');
      print('The encoding workflow is fundamental - it must work reliably.');

      // This test should fail until the bugs are fixed
      expect(
        failedFiles,
        equals(0),
        reason:
            '''
CRITICAL BUGS FOUND: $failedFiles out of $totalFiles files failed to encode.
This indicates fundamental issues in the audio processing pipeline.

See the detailed bug report above for specific issues to fix.
Integration tests will continue to fail until these core bugs are resolved.
''',
      );
    });

    test('DETAILED BUG: TAG_VALUE_INCONSISTENT analysis', () async {
      print('\n=== TAG_VALUE_INCONSISTENT DEEP DIVE ===\n');

      final testFile = testFiles.first;
      PhonicAudioFile? audioFile;

      try {
        audioFile = await Phonic.fromFile(testFile);

        print('Original tags:');
        final originalAlbum = audioFile.getTag(TagKey.album);
        print('  Album: ${originalAlbum?.value ?? "None"}');

        // Modify a tag that might cause ID3v1/ID3v2 sync issues
        audioFile.setTag(const AlbumTag('Test Album With Sync Issue'));

        print('\nAfter modification:');
        final newAlbum = audioFile.getTag(TagKey.album);
        print('  Album: ${newAlbum?.value ?? "None"}');

        // Try to encode and catch the specific error
        try {
          await audioFile.encode(
            const EncodingOptions(
              strategy: EncodingStrategy.preserveExisting,
              validationLevel: ValidationLevel.basic,
            ),
          );
          print('✓ No TAG_VALUE_INCONSISTENT error - this might be fixed!');
        } catch (e) {
          if (e.toString().contains('TAG_VALUE_INCONSISTENT')) {
            print('✗ TAG_VALUE_INCONSISTENT error confirmed:');
            print('  ${e.toString().split('\n').first}');

            print('\nThis error indicates:');
            print('  - The album tag was not properly synchronized between ID3v1 and ID3v2');
            print('  - ID3v1 has a 30-character limit that might cause truncation');
            print('  - The tag merger is not handling container differences correctly');

            fail('TAG_VALUE_INCONSISTENT bug needs to be fixed in tag synchronization logic');
          } else {
            print('Different error occurred: ${e.toString().split('\n').first}');
            fail('Unexpected error during TAG_VALUE_INCONSISTENT analysis');
          }
        }
      } finally {
        audioFile?.dispose();
      }
    });

    test('DETAILED BUG: ROUND_TRIP_FAILED analysis', () async {
      print('\n=== ROUND_TRIP_FAILED DEEP DIVE ===\n');

      final testFile = testFiles.first;
      PhonicAudioFile? audioFile;

      try {
        audioFile = await Phonic.fromFile(testFile);

        print('File: ${testFile.split('/').last}');

        // Make a minimal change
        audioFile.setTag(YearTag(2024));

        // Try encoding with different validation levels
        final validationLevels = [ValidationLevel.basic, ValidationLevel.standard, ValidationLevel.strict];
        var anyRoundTripFailures = false;

        for (final level in validationLevels) {
          try {
            await audioFile.encode(
              EncodingOptions(
                strategy: EncodingStrategy.preserveExisting,
                validationLevel: level,
              ),
            );
            print('✓ Success with ${level.name} validation');
          } catch (e) {
            if (e.toString().contains('ROUND_TRIP_FAILED')) {
              anyRoundTripFailures = true;
              print('✗ ROUND_TRIP_FAILED with ${level.name} validation:');
              print('  ${e.toString().split('\n').first}');

              if (e.toString().contains('ID3v2.3') && e.toString().contains('ID3v2.4')) {
                print('\nID3 Version Mismatch Details:');
                print('  - Original file likely has ID3v2.4 tags');
                print('  - Validation expects ID3v2.3');
                print('  - This suggests version preservation/conversion issues');
                print('  - Fix: Preserve original ID3 version or update validation logic');
              }
            } else {
              print('✗ Different error with ${level.name}: ${e.toString().split('\n').first}');
            }
          }
        }

        if (anyRoundTripFailures) {
          fail('ROUND_TRIP_FAILED bug needs to be fixed in ID3 version handling');
        } else {
          print('✅ ROUND_TRIP_FAILED bug has been resolved - all validation levels pass!');
        }
      } finally {
        audioFile?.dispose();
      }
    });
  });
}

/// Get test files for bug analysis
Future<List<String>> _getTestFiles() async {
  final fixtureFiles = <String>[];

  final mp3Dir = Directory('test/fixtures/mp3');
  if (await mp3Dir.exists()) {
    final mp3Files = await mp3Dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.mp3'))
        .map((entity) => entity.path.replaceAll(r'\', '/'))
        .toList();
    fixtureFiles.addAll(mp3Files);
  }

  fixtureFiles.sort();
  return fixtureFiles;
}
