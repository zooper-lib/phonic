// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/phonic.dart';

/// Demonstrates using Phonic's isolate-based processing methods for
/// non-blocking metadata extraction.
///
/// This example shows:
/// - Basic isolate processing for single files
/// - Batch processing multiple files in parallel
/// - Performance comparison between standard and isolate methods
/// - Error handling in isolate-based processing
/// - Best practices for when to use isolate methods
void main() async {
  print('Phonic Isolate Processing Examples');
  print('==================================\n');

  // Example 1: Basic isolate processing
  await basicIsolateProcessing();

  // Example 2: Parallel batch processing
  await parallelBatchProcessing();

  // Example 3: Performance comparison
  await performanceComparison();

  // Example 4: Error handling
  await errorHandlingExample();

  // Example 5: Mixed processing strategy
  await mixedProcessingStrategy();
}

/// Demonstrates basic isolate processing for a single file.
Future<void> basicIsolateProcessing() async {
  print('1. Basic Isolate Processing');
  print('---------------------------');

  try {
    // Create a test file
    final testFile = await _createTestFile('isolate_test.mp3');

    // Process in isolate - UI remains responsive
    print('Processing file in background isolate...');
    final audioFile = await Phonic.fromFileInIsolateAsync(testFile.path);

    // Access tags normally - same API as standard method
    final title = audioFile.getTag(TagKey.title);
    final artist = audioFile.getTag(TagKey.artist);
    final album = audioFile.getTag(TagKey.album);

    print('Metadata extracted:');
    print('  Title: ${title?.value ?? "None"}');
    print('  Artist: ${artist?.value ?? "None"}');
    print('  Album: ${album?.value ?? "None"}');

    // Clean up
    audioFile.dispose();
    await testFile.delete();
    print('');
  } catch (e) {
    print('Error in basic isolate processing: $e\n');
  }
}

/// Demonstrates processing multiple files in parallel using isolates.
Future<void> parallelBatchProcessing() async {
  print('2. Parallel Batch Processing');
  print('----------------------------');

  try {
    // Create multiple test files
    final testFiles = await Future.wait([
      _createTestFile('batch_1.mp3'),
      _createTestFile('batch_2.mp3'),
      _createTestFile('batch_3.mp3'),
      _createTestFile('batch_4.mp3'),
      _createTestFile('batch_5.mp3'),
    ]);

    print('Processing ${testFiles.length} files in parallel...');
    final stopwatch = Stopwatch()..start();

    // Process all files in parallel using isolates
    // Each file processes in its own isolate simultaneously
    final futures = testFiles.map((file) {
      return Phonic.fromFileInIsolateAsync(file.path);
    });

    final audioFiles = await Future.wait(futures);
    stopwatch.stop();

    // Extract metadata from all files
    var successCount = 0;
    for (var i = 0; i < audioFiles.length; i++) {
      final title = audioFiles[i].getTag(TagKey.title);
      if (title != null) {
        successCount++;
        print('  File ${i + 1}: ${title.value}');
      }
      audioFiles[i].dispose();
    }

    print('\nProcessed $successCount files in ${stopwatch.elapsedMilliseconds}ms');
    print('Average: ${(stopwatch.elapsedMilliseconds / audioFiles.length).toStringAsFixed(1)}ms per file');

    // Clean up
    for (final file in testFiles) {
      await file.delete();
    }
    print('');
  } catch (e) {
    print('Error in parallel batch processing: $e\n');
  }
}

/// Compares performance between standard and isolate methods.
Future<void> performanceComparison() async {
  print('3. Performance Comparison');
  print('------------------------');

  try {
    final testFile = await _createLargeTestFile('performance_test.mp3');

    // Standard processing
    print('Standard processing...');
    var stopwatch = Stopwatch()..start();
    var audioFile = await Phonic.fromFileAsync(testFile.path);
    stopwatch.stop();
    final standardTime = stopwatch.elapsedMilliseconds;
    audioFile.dispose();

    // Isolate processing
    print('Isolate processing...');
    stopwatch = Stopwatch()..start();
    audioFile = await Phonic.fromFileInIsolateAsync(testFile.path);
    stopwatch.stop();
    final isolateTime = stopwatch.elapsedMilliseconds;
    audioFile.dispose();

    print('\nResults:');
    print('  Standard: ${standardTime}ms');
    print('  Isolate:  ${isolateTime}ms');
    print('  Difference: ${(isolateTime - standardTime).abs()}ms');

    if (isolateTime < standardTime) {
      final improvement = ((standardTime - isolateTime) / standardTime * 100).toStringAsFixed(1);
      print('  Isolate was $improvement% faster');
    } else {
      final overhead = ((isolateTime - standardTime) / standardTime * 100).toStringAsFixed(1);
      print('  Isolate had $overhead% overhead (expected for small files)');
    }

    await testFile.delete();
    print('');
  } catch (e) {
    print('Error in performance comparison: $e\n');
  }
}

/// Demonstrates error handling with isolate processing.
Future<void> errorHandlingExample() async {
  print('4. Error Handling');
  print('----------------');

  // Test 1: Non-existent file
  try {
    print('Test 1: Processing non-existent file...');
    await Phonic.fromFileInIsolateAsync('/non/existent/file.mp3');
    print('  ERROR: Should have thrown exception!');
  } on FileSystemException catch (e) {
    print('  ✓ Caught FileSystemException: ${e.message}');
  }

  // Test 2: Unsupported format
  try {
    print('\nTest 2: Processing unsupported format...');
    final unsupportedBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
    await Phonic.fromBytesInIsolateAsync(unsupportedBytes, 'test.xyz');
    print('  ERROR: Should have thrown exception!');
  } on UnsupportedFormatException catch (e) {
    print('  ✓ Caught UnsupportedFormatException: ${e.message}');
  }

  // Test 3: Empty bytes
  try {
    print('\nTest 3: Processing empty bytes...');
    final emptyBytes = Uint8List(0);
    await Phonic.fromBytesInIsolateAsync(emptyBytes);
    print('  ERROR: Should have thrown exception!');
  } on ArgumentError catch (e) {
    print('  ✓ Caught ArgumentError: ${e.message}');
  }

  print('');
}

/// Demonstrates a mixed processing strategy based on file size.
Future<void> mixedProcessingStrategy() async {
  print('5. Mixed Processing Strategy');
  print('---------------------------');

  try {
    // Simulate processing a collection with different file sizes
    final files = [
      ('small_1.mp3', await _createTestFile('small_1.mp3')),
      ('small_2.mp3', await _createTestFile('small_2.mp3')),
      ('large_1.mp3', await _createLargeTestFile('large_1.mp3')),
      ('large_2.mp3', await _createLargeTestFile('large_2.mp3')),
    ];

    print('Processing files with optimal strategy...');

    for (final (name, file) in files) {
      final fileSize = await file.length();
      final sizeKB = fileSize / 1024;

      // Use isolate for large files (>100KB), standard for small files
      final useIsolate = sizeKB > 100;
      final method = useIsolate ? 'isolate' : 'standard';

      print('\n  $name (${sizeKB.toStringAsFixed(1)}KB) - using $method method');

      final stopwatch = Stopwatch()..start();
      final audioFile = useIsolate ? await Phonic.fromFileInIsolateAsync(file.path) : await Phonic.fromFileAsync(file.path);
      stopwatch.stop();

      final title = audioFile.getTag(TagKey.title);
      print('    Title: ${title?.value}');
      print('    Processing time: ${stopwatch.elapsedMilliseconds}ms');

      audioFile.dispose();
      await file.delete();
    }

    print('\nStrategy: Use isolates for files >100KB, standard method for smaller files');
    print('');
  } catch (e) {
    print('Error in mixed processing strategy: $e\n');
  }
}

// Helper functions

/// Creates a minimal test MP3 file with metadata.
Future<File> _createTestFile(String filename) async {
  final bytes = <int>[];

  // ID3v2.4 header
  bytes.addAll([
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x00, 0x50, // Size (synchsafe)
  ]);

  // TIT2 frame (Title)
  bytes.addAll([
    0x54, 0x49, 0x54, 0x32, // "TIT2"
    0x00, 0x00, 0x00, 0x0C, // Frame size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Test Title').codeUnits,
  ]);

  // TPE1 frame (Artist)
  bytes.addAll([
    0x54, 0x50, 0x45, 0x31, // "TPE1"
    0x00, 0x00, 0x00, 0x0D, // Frame size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Test Artist').codeUnits,
  ]);

  // TALB frame (Album)
  bytes.addAll([
    0x54, 0x41, 0x4C, 0x42, // "TALB"
    0x00, 0x00, 0x00, 0x0C, // Frame size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Test Album').codeUnits,
  ]);

  // Minimal MP3 frame
  bytes.addAll([0xFF, 0xFB, 0x90, 0x00]);
  bytes.addAll(List.filled(100, 0x00));

  final file = File(filename);
  await file.writeAsBytes(bytes);
  return file;
}

/// Creates a larger test file to demonstrate isolate benefits.
Future<File> _createLargeTestFile(String filename) async {
  final bytes = <int>[];

  // ID3v2.4 header
  bytes.addAll([
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x10, 0x00, // Size (synchsafe, larger)
  ]);

  // Add multiple frames to make it larger
  for (var i = 0; i < 10; i++) {
    bytes.addAll([
      0x54, 0x58, 0x58, 0x58, // "TXXX" (custom text frame)
      0x00, 0x00, 0x00, 0x20, // Frame size
      0x00, 0x00, // Flags
      0x03, // UTF-8 encoding
      ...('Custom frame $i').codeUnits,
      0x00,
      ...('Value $i').codeUnits,
    ]);
  }

  // Large padding to simulate bigger file
  bytes.addAll(List.filled(5000, 0x00));

  // Minimal MP3 frames
  for (var i = 0; i < 100; i++) {
    bytes.addAll([0xFF, 0xFB, 0x90, 0x00]);
    bytes.addAll(List.filled(96, 0x00));
  }

  final file = File(filename);
  await file.writeAsBytes(bytes);
  return file;
}
