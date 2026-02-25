// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/phonic.dart';

/// Error handling and edge case examples for the Phonic library.
///
/// This example demonstrates how to handle various error conditions and
/// edge cases that can occur when working with audio metadata:
/// - Unsupported file formats
/// - Corrupted container data
/// - Tag validation errors
/// - File system errors
/// - Memory constraints
/// - Recovery strategies
void main() async {
  print('Phonic Error Handling Examples');
  print('==============================\n');

  // Example 1: Unsupported format handling
  await unsupportedFormatHandling();

  // Example 2: Corrupted container handling
  await corruptedContainerHandling();

  // Example 3: Tag validation errors
  await tagValidationErrors();

  // Example 4: File system error handling
  await fileSystemErrorHandling();

  // Example 5: Memory constraint handling
  await memoryConstraintHandling();

  // Example 6: Recovery strategies
  await recoveryStrategies();

  // Example 7: Edge cases and boundary conditions
  await edgeCasesAndBoundaryConditions();
}

/// Demonstrates handling of unsupported file formats.
Future<void> unsupportedFormatHandling() async {
  print('1. Unsupported Format Handling');
  print('------------------------------');

  // Test various unsupported formats
  final unsupportedFiles = [
    ('unknown.xyz', _createUnknownFormat()),
    ('text.txt', _createTextFile()),
    ('image.jpg', _createJpegFile()),
    ('empty.mp3', Uint8List(0)),
  ];

  for (final (filename, bytes) in unsupportedFiles) {
    try {
      print('Attempting to load: $filename');
      final audioFile = await Phonic.fromBytesAsync(bytes, filename);
      print('  ✓ Unexpectedly succeeded');
      audioFile.dispose();
    } on UnsupportedFormatException catch (e) {
      print('  ✗ UnsupportedFormatException: ${e.message}');
      if (e.context != null) {
        print('    Context: ${e.context}');
      }
    } on ArgumentError catch (e) {
      print('  ✗ ArgumentError: ${e.message}');
    } catch (e) {
      print('  ✗ Unexpected error: $e');
    }
  }

  // Demonstrate graceful fallback for batch processing
  print('\nBatch processing with error tolerance:');
  final mixedFiles = [
    ('valid.mp3', _createValidMp3()),
    ('invalid.xyz', _createUnknownFormat()),
    ('another_valid.mp3', _createValidMp3()),
  ];

  var successCount = 0;
  var errorCount = 0;

  for (final (filename, bytes) in mixedFiles) {
    try {
      final audioFile = await Phonic.fromBytesAsync(bytes, filename);
      final title = audioFile.getTag(TagKey.title);
      print('  ✓ $filename: ${title?.value ?? "No title"}');
      audioFile.dispose();
      successCount++;
    } on UnsupportedFormatException {
      print('  ✗ $filename: Unsupported format (skipped)');
      errorCount++;
    } catch (e) {
      print('  ✗ $filename: Error - $e');
      errorCount++;
    }
  }

  print('Batch result: $successCount successful, $errorCount errors');
  print('');
}

/// Demonstrates handling of corrupted container data.
Future<void> corruptedContainerHandling() async {
  print('2. Corrupted Container Handling');
  print('-------------------------------');

  final corruptedFiles = [
    ('truncated_header.mp3', _createTruncatedMp3()),
    ('invalid_id3.mp3', _createInvalidId3()),
    ('corrupted_flac.flac', _createCorruptedFlac()),
    ('malformed_mp4.m4a', _createMalformedMp4()),
  ];

  for (final (filename, bytes) in corruptedFiles) {
    try {
      print('Processing potentially corrupted file: $filename');
      final audioFile = await Phonic.fromBytesAsync(bytes, filename);

      // Try to read tags
      final allTags = audioFile.getAllTags();
      print('  ✓ Successfully read ${allTags.length} tags');

      // Try to modify and encode
      audioFile.setTag(const TitleTag('Test Title'));
      if (audioFile.isDirty) {
        final encoded = await audioFile.encode();
        print('  ✓ Successfully encoded ${encoded.length} bytes');
      }

      audioFile.dispose();
    } on CorruptedContainerException catch (e) {
      print('  ✗ CorruptedContainerException: ${e.message}');
      if (e.byteOffset != null) {
        print('    Error at byte offset: ${e.byteOffset}');
      }
      if (e.context != null) {
        print('    Context: ${e.context}');
      }
    } on UnsupportedFormatException catch (e) {
      print('  ✗ Format detection failed: ${e.message}');
    } catch (e) {
      print('  ✗ Unexpected error: $e');
    }
  }

  // Demonstrate partial recovery from corrupted containers
  print('\nPartial recovery example:');
  try {
    final partiallyCorrupted = _createPartiallyCorruptedMp3();
    final audioFile = await Phonic.fromBytesAsync(partiallyCorrupted, 'partial.mp3');

    // Some containers might be readable while others are corrupted
    final tags = audioFile.getAllTags();
    print('  Recovered ${tags.length} tags from non-corrupted containers');

    for (final tag in tags) {
      print('    ${tag.key}: ${tag.value} (from ${tag.provenance.containerKind})');
    }

    audioFile.dispose();
  } catch (e) {
    print('  Complete failure: $e');
  }

  print('');
}

/// Demonstrates tag validation error handling.
Future<void> tagValidationErrors() async {
  print('3. Tag Validation Errors');
  print('------------------------');

  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'test.mp3');

    // Test various validation scenarios
    final validationTests = [
      ('Invalid rating (too high)', () => audioFile.setTag(RatingTag(150))),
      ('Invalid rating (negative)', () => audioFile.setTag(RatingTag(-10))),
      ('Invalid track number (zero)', () => audioFile.setTag(TrackNumberTag(0))),
      ('Invalid track number (negative)', () => audioFile.setTag(TrackNumberTag(-5))),
      ('Invalid year (too old)', () => audioFile.setTag(YearTag(1800))),
      ('Invalid year (future)', () => audioFile.setTag(YearTag(3000))),
      ('Invalid BPM (too high)', () => audioFile.setTag(BpmTag(2000))),
      ('Invalid BPM (zero)', () => audioFile.setTag(BpmTag(0))),
    ];

    for (final (description, testFunction) in validationTests) {
      try {
        print('Testing: $description');
        testFunction();
        print('  ✓ Unexpectedly succeeded');
      } on TagValidationException catch (e) {
        print('  ✗ TagValidationException: ${e.reason}');
        print('    Tag: ${e.tagKey}');
      } on ArgumentError catch (e) {
        print('  ✗ ArgumentError: ${e.message}');
      } catch (e) {
        print('  ✗ Unexpected error: $e');
      }
    }

    // Demonstrate validation with correction
    print('\nValidation with automatic correction:');
    try {
      // Try invalid rating
      audioFile.setTag(RatingTag(150));
    } on TagValidationException catch (e) {
      print('Invalid rating detected: ${e.reason}');
      // Correct the value
      audioFile.setTag(RatingTag(100)); // Maximum valid rating
      print('Corrected to maximum valid rating: 100');
    }

    // Test container-specific constraints
    print('\nContainer-specific constraint handling:');
    final longTitle = 'This is an extremely long song title that exceeds the ID3v1 30-character limit and will be truncated';
    audioFile.setTag(TitleTag(longTitle));
    print('Set long title (${longTitle.length} chars): "$longTitle"');
    print('ID3v1 will automatically truncate to 30 characters during encoding');

    audioFile.dispose();
  } catch (e) {
    print('Error in validation tests: $e');
  }

  print('');
}

/// Demonstrates file system error handling.
Future<void> fileSystemErrorHandling() async {
  print('4. File System Error Handling');
  print('-----------------------------');

  // Simulate various file system scenarios
  final fileSystemTests = [
    ('Non-existent file', () => Phonic.fromFileAsync('/nonexistent/path/file.mp3')),
    ('Empty path', () => Phonic.fromFileAsync('')),
    ('Directory instead of file', () => Phonic.fromFileAsync('/')),
  ];

  for (final (description, testFunction) in fileSystemTests) {
    try {
      print('Testing: $description');
      final audioFile = await testFunction();
      print('  ✓ Unexpectedly succeeded');
      audioFile.dispose();
    } on FileSystemException catch (e) {
      print('  ✗ FileSystemException: ${e.message}');
      print('    Path: ${e.path}');
      print('    OS Error: ${e.osError}');
    } on ArgumentError catch (e) {
      print('  ✗ ArgumentError: ${e.message}');
    } on UnsupportedFormatException catch (e) {
      print('  ✗ UnsupportedFormatException: ${e.message}');
    } catch (e) {
      print('  ✗ Unexpected error: $e');
    }
  }

  // Demonstrate robust file loading with retries
  print('\nRobust file loading with error recovery:');
  final filePaths = [
    '/nonexistent/file1.mp3',
    '/nonexistent/file2.mp3',
    'valid_fallback.mp3', // This would be a valid file in real usage
  ];

  PhonicAudioFile? audioFile;
  for (final path in filePaths) {
    try {
      print('Attempting to load: $path');
      if (path == 'valid_fallback.mp3') {
        // Simulate successful fallback
        audioFile = await Phonic.fromBytesAsync(_createValidMp3(), path);
        print('  ✓ Successfully loaded fallback file');
        break;
      } else {
        audioFile = await Phonic.fromFileAsync(path);
        print('  ✓ Successfully loaded');
        break;
      }
    } catch (e) {
      print('  ✗ Failed: $e');
      continue;
    }
  }

  if (audioFile != null) {
    print('File loading succeeded with fallback strategy');
    audioFile.dispose();
  } else {
    print('All file loading attempts failed');
  }

  print('');
}

/// Demonstrates memory constraint handling.
Future<void> memoryConstraintHandling() async {
  print('5. Memory Constraint Handling');
  print('-----------------------------');

  try {
    // Simulate large file processing
    print('Processing large file with memory constraints...');

    final largeFile = _createLargeAudioFile();
    final audioFile = await Phonic.fromBytesAsync(largeFile, 'large_file.mp3');

    print('Large file loaded: ${largeFile.length} bytes');

    // Demonstrate lazy artwork loading
    print('\nLazy artwork loading:');
    final largeArtwork = ArtworkData(
      mimeType: 'image/jpeg',
      type: ArtworkType.frontCover,
      description: 'High resolution album cover',
      dataLoader: () async {
        print('  Loading large artwork on demand...');
        // Simulate loading large image
        await Future.delayed(const Duration(milliseconds: 100));
        return _createLargeImageData();
      },
    );

    audioFile.setTag(ArtworkTag(largeArtwork));
    print('  Artwork tag set (image data not loaded yet)');

    // Access metadata without loading image
    final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
    if (artworkTag != null) {
      print('  Artwork metadata: ${artworkTag.value.mimeType}, ${artworkTag.value.type}');
      print('  Image data will be loaded only when accessed');

      // Load image data on demand
      final imageData = await artworkTag.value.data;
      print('  Image data loaded: ${imageData.length} bytes');
    }

    // Demonstrate memory-efficient batch processing
    print('\nMemory-efficient batch processing:');
    final batchFiles = List.generate(5, (i) => _createValidMp3());

    for (int i = 0; i < batchFiles.length; i++) {
      PhonicAudioFile? batchFile;
      try {
        batchFile = await Phonic.fromBytesAsync(batchFiles[i], 'batch_$i.mp3');

        // Process quickly and dispose
        final title = batchFile.getTag(TagKey.title);
        print('  Processed file $i: ${title?.value ?? "No title"}');
      } finally {
        // Always dispose to free memory
        batchFile?.dispose();
      }
    }

    audioFile.dispose();
    print('Memory-efficient processing completed');
  } catch (e) {
    print('Error in memory constraint handling: $e');
  }

  print('');
}

/// Demonstrates recovery strategies for various error conditions.
Future<void> recoveryStrategies() async {
  print('6. Recovery Strategies');
  print('---------------------');

  // Strategy 1: Graceful degradation
  print('Strategy 1: Graceful degradation');
  try {
    final problematicFile = _createProblematicMp3();
    final audioFile = await Phonic.fromBytesAsync(problematicFile, 'problematic.mp3');

    // Try to read what we can
    final tags = audioFile.getAllTags();
    print('  Recovered ${tags.length} tags despite issues');

    // Continue with available data
    if (tags.isNotEmpty) {
      print('  Available metadata:');
      for (final tag in tags.take(3)) {
        print('    ${tag.key}: ${tag.value}');
      }
    }

    audioFile.dispose();
  } catch (e) {
    print('  Graceful degradation failed: $e');
  }

  // Strategy 2: Retry with different approaches
  print('\nStrategy 2: Retry with different approaches');
  final retryFile = _createAmbiguousFile();

  final strategies = [
    ('Direct format detection', () => Phonic.fromBytesAsync(retryFile, 'file.mp3')),
    ('Alternative extension', () => Phonic.fromBytesAsync(retryFile, 'file.flac')),
    ('No extension hint', () => Phonic.fromBytesAsync(retryFile)),
  ];

  PhonicAudioFile? successfulFile;
  for (final (strategyName, strategy) in strategies) {
    try {
      print('  Trying: $strategyName');
      successfulFile = await strategy();
      print('    ✓ Success');
      break;
    } catch (e) {
      print('    ✗ Failed: $e');
    }
  }

  if (successfulFile != null) {
    print('  Recovery successful with retry strategy');
    successfulFile.dispose();
  } else {
    print('  All retry strategies failed');
  }

  // Strategy 3: Partial data extraction
  print('\nStrategy 3: Partial data extraction');
  try {
    final partialFile = _createPartiallyValidFile();
    final audioFile = await Phonic.fromBytesAsync(partialFile, 'partial.mp3');

    // Extract what we can, ignore what we can't
    final extractedData = <String, dynamic>{};

    try {
      final title = audioFile.getTag(TagKey.title);
      if (title != null) extractedData['title'] = title.value;
    } catch (e) {
      print('  Could not extract title: $e');
    }

    try {
      final artist = audioFile.getTag(TagKey.artist);
      if (artist != null) extractedData['artist'] = artist.value;
    } catch (e) {
      print('  Could not extract artist: $e');
    }

    print('  Extracted data: $extractedData');
    audioFile.dispose();
  } catch (e) {
    print('  Partial extraction failed: $e');
  }

  print('');
}

/// Demonstrates edge cases and boundary conditions.
Future<void> edgeCasesAndBoundaryConditions() async {
  print('7. Edge Cases and Boundary Conditions');
  print('-------------------------------------');

  // Edge case 1: Empty tags
  print('Edge case 1: Empty and null values');
  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'test.mp3');

    // Test empty string handling
    audioFile.setTag(const TitleTag(''));
    audioFile.setTag(const ArtistTag('   ')); // Whitespace only

    // Test empty genre list
    audioFile.setTag(GenreTag(const []));

    print('  Empty values handled gracefully');
    audioFile.dispose();
  } catch (e) {
    print('  Error with empty values: $e');
  }

  // Edge case 2: Unicode and special characters
  print('\nEdge case 2: Unicode and special characters');
  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'unicode.mp3');

    // Test various Unicode characters
    audioFile.setTag(const TitleTag('🎵 Song with Emoji 🎶'));
    audioFile.setTag(const ArtistTag('Артист')); // Cyrillic
    audioFile.setTag(const AlbumTag('专辑')); // Chinese
    audioFile.setTag(const CommentTag('Café résumé naïve')); // Accented characters

    print('  Unicode characters handled correctly');
    audioFile.dispose();
  } catch (e) {
    print('  Error with Unicode: $e');
  }

  // Edge case 3: Boundary values
  print('\nEdge case 3: Boundary values');
  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'boundary.mp3');

    // Test boundary values for numeric fields
    audioFile.setTag(RatingTag(0)); // Minimum rating
    audioFile.setTag(RatingTag(100)); // Maximum rating
    audioFile.setTag(TrackNumberTag(1)); // Minimum track
    audioFile.setTag(TrackNumberTag(999)); // High track number
    audioFile.setTag(YearTag(1900)); // Early year
    audioFile.setTag(YearTag(2100)); // Future year

    print('  Boundary values accepted');
    audioFile.dispose();
  } catch (e) {
    print('  Error with boundary values: $e');
  }

  // Edge case 4: Very long strings
  print('\nEdge case 4: Very long strings');
  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'long.mp3');

    final veryLongTitle = 'A' * 1000; // 1000 character title
    final veryLongComment = 'B' * 5000; // 5000 character comment

    audioFile.setTag(TitleTag(veryLongTitle));
    audioFile.setTag(CommentTag(veryLongComment));

    print('  Very long strings handled (will be truncated per format constraints)');
    audioFile.dispose();
  } catch (e) {
    print('  Error with long strings: $e');
  }

  // Edge case 5: Rapid operations
  print('\nEdge case 5: Rapid operations');
  try {
    final audioFile = await Phonic.fromBytesAsync(_createValidMp3(), 'rapid.mp3');

    // Perform many rapid operations
    for (int i = 0; i < 100; i++) {
      audioFile.setTag(TitleTag('Title $i'));
      audioFile.setTag(TrackNumberTag(i + 1));
      final title = audioFile.getTag(TagKey.title);
      assert(title?.value == 'Title $i');
    }

    print('  Rapid operations completed successfully');
    audioFile.dispose();
  } catch (e) {
    print('  Error with rapid operations: $e');
  }

  print('');
}

// Helper methods to create various test files and scenarios

Uint8List _createUnknownFormat() {
  return Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
}

Uint8List _createTextFile() {
  return Uint8List.fromList('This is a text file, not audio'.codeUnits);
}

Uint8List _createJpegFile() {
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, // JPEG header
    ...List.filled(100, 0x00),
    0xFF, 0xD9, // JPEG end
  ]);
}

Uint8List _createValidMp3() {
  final id3Header = [
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x00, 0x17, // Size
  ];

  final titleFrame = [
    0x54, 0x49, 0x54, 0x32, // "TIT2"
    0x00, 0x00, 0x00, 0x0D, // Size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Valid Song'.codeUnits),
  ];

  final audioData = [
    0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
    ...List.filled(100, 0x00),
  ];

  return Uint8List.fromList([...id3Header, ...titleFrame, ...audioData]);
}

Uint8List _createTruncatedMp3() {
  // ID3 header claiming more data than available
  return Uint8List.fromList([
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x01, 0x00, // Size (claims 256 bytes but file is shorter)
    0x54, 0x49, 0x54, 0x32, // "TIT2" frame start
    // File truncated here
  ]);
}

Uint8List _createInvalidId3() {
  return Uint8List.fromList([
    0x49, 0x44, 0x33, // "ID3"
    0xFF, 0xFF, // Invalid version
    0x00, // Flags
    0x00, 0x00, 0x00, 0x10, // Size
    ...List.filled(16, 0xFF), // Invalid frame data
  ]);
}

Uint8List _createCorruptedFlac() {
  return Uint8List.fromList([
    0x66, 0x4C, 0x61, 0x43, // "fLaC"
    0xFF, // Invalid metadata block header
    0xFF, 0xFF, 0xFF, // Invalid block length
    ...List.filled(10, 0xFF), // Corrupted data
  ]);
}

Uint8List _createMalformedMp4() {
  return Uint8List.fromList([
    0xFF, 0xFF, 0xFF, 0xFF, // Invalid box size
    0x66, 0x74, 0x79, 0x70, // "ftyp"
    ...List.filled(10, 0x00),
  ]);
}

Uint8List _createPartiallyCorruptedMp3() {
  // Valid ID3v2.4 tag followed by corrupted ID3v1
  final validId3v2 = [
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x00, 0x17, // Size
    0x54, 0x49, 0x54, 0x32, // "TIT2"
    0x00, 0x00, 0x00, 0x0D, // Size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Partial Song'.codeUnits),
  ];

  final audioData = List.filled(1000, 0x00);

  final corruptedId3v1 = [
    ...('TAG'.codeUnits), // Valid signature
    ...List.filled(125, 0xFF), // Corrupted data
  ];

  return Uint8List.fromList([...validId3v2, ...audioData, ...corruptedId3v1]);
}

Uint8List _createLargeAudioFile() {
  final header = _createValidMp3();
  final largeAudioData = List.filled(10 * 1024 * 1024, 0x00); // 10MB
  return Uint8List.fromList([...header, ...largeAudioData]);
}

Uint8List _createLargeImageData() {
  final jpegHeader = [0xFF, 0xD8, 0xFF, 0xE0];
  final largeImageData = List.filled(5 * 1024 * 1024, 0x80); // 5MB
  final jpegEnd = [0xFF, 0xD9];
  return Uint8List.fromList([...jpegHeader, ...largeImageData, ...jpegEnd]);
}

Uint8List _createProblematicMp3() {
  // File with some valid data and some issues
  return _createPartiallyCorruptedMp3();
}

Uint8List _createAmbiguousFile() {
  // File that could be interpreted as multiple formats
  return Uint8List.fromList([
    0x49, 0x44, 0x33, // Could be ID3
    0x66, 0x4C, 0x61, 0x43, // Could be FLAC
    ...List.filled(100, 0x00),
  ]);
}

Uint8List _createPartiallyValidFile() {
  // File with some readable containers and some unreadable ones
  return _createPartiallyCorruptedMp3();
}
