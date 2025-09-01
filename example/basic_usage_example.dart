// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:phonic/phonic.dart';

/// Basic usage examples demonstrating the core Phonic API functionality.
///
/// This example covers the most common use cases for reading and writing
/// audio metadata using the unified tagging API. It demonstrates:
/// - Loading audio files from different sources
/// - Reading various types of metadata tags
/// - Modifying and updating tag values
/// - Saving changes back to files
/// - Proper resource management
void main() async {
  print('Phonic Basic Usage Examples');
  print('===========================\n');

  // Example 1: Basic file loading and tag reading
  await basicTagReading();

  // Example 2: Modifying and saving tags
  await modifyingTags();

  // Example 3: Working with multi-valued tags
  await multiValuedTags();

  // Example 4: Artwork handling
  await artworkHandling();

  // Example 5: Batch processing
  await batchProcessing();
}

/// Demonstrates basic tag reading operations.
Future<void> basicTagReading() async {
  print('1. Basic Tag Reading');
  print('-------------------');

  try {
    // Load a real sample audio file
    final audioFile = await Phonic.fromFile('example/sample1.mp3');

    // Read basic text tags
    final titleTag = audioFile.getTag(TagKey.title);
    final artistTag = audioFile.getTag(TagKey.artist);
    final albumTag = audioFile.getTag(TagKey.album);

    print('Title: ${titleTag?.value ?? "Not found"}');
    print('Artist: ${artistTag?.value ?? "Not found"}');
    print('Album: ${albumTag?.value ?? "Not found"}');

    // Read numeric tags
    final trackTag = audioFile.getTag(TagKey.trackNumber);
    final yearTag = audioFile.getTag(TagKey.year);
    final ratingTag = audioFile.getTag(TagKey.rating);

    if (trackTag != null) {
      print('Track Number: ${(trackTag as TrackNumberTag).value}');
    }
    if (yearTag != null) {
      print('Year: ${(yearTag as YearTag).value}');
    }
    if (ratingTag != null) {
      print('Rating: ${(ratingTag as RatingTag).value}/100');
    }

    // Check provenance information
    if (titleTag != null) {
      final provenance = titleTag.provenance;
      print('Title source: ${provenance.containerKind} v${provenance.containerVersion}');
      print('Confidence: ${provenance.confidence}');
    }

    // Get all tags for comprehensive view
    final allTags = audioFile.getAllTags();
    print('Total tags found: ${allTags.length}');

    // Cleanup
    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in basic tag reading: $e\n');
  }
}

/// Demonstrates modifying and saving tags.
Future<void> modifyingTags() async {
  print('2. Modifying and Saving Tags');
  print('----------------------------');

  try {
    // Load a real sample audio file
    final audioFile = await Phonic.fromFile('example/sample1.mp3');

    print('Original tags:');
    final originalTitle = audioFile.getTag(TagKey.title);
    print('  Title: ${originalTitle?.value ?? "None"}');

    // Modify basic tags
    audioFile.setTag(const TitleTag('Updated Song Title'));
    audioFile.setTag(const ArtistTag('New Artist Name'));
    audioFile.setTag(const AlbumTag('New Album Title'));

    // Set numeric tags with validation
    audioFile.setTag(TrackNumberTag(5));
    audioFile.setTag(YearTag(2024));
    audioFile.setTag(RatingTag(85)); // 0-100 scale

    // Set additional metadata
    audioFile.setTag(const CommentTag('Updated with Phonic library'));
    audioFile.setTag(const ComposerTag('John Composer'));
    audioFile.setTag(BpmTag(120));

    print('Modified tags:');
    final newTitle = audioFile.getTag(TagKey.title);
    final newArtist = audioFile.getTag(TagKey.artist);
    final newRating = audioFile.getTag(TagKey.rating);
    print('  Title: ${newTitle?.value}');
    print('  Artist: ${newArtist?.value}');
    print('  Rating: ${(newRating as RatingTag?)?.value}/100');

    // Check if file has unsaved changes
    print('Has unsaved changes: ${audioFile.isDirty}');

    // Save changes to new file
    if (audioFile.isDirty) {
      try {
        final updatedBytes = await audioFile.encode();
        print('Encoded file size: ${updatedBytes.length} bytes');

        // In a real application, you would save to a file:
        // await File('updated_song.mp3').writeAsBytes(updatedBytes);

        // Mark as clean after saving
        audioFile.markClean();
        print('File marked as clean: ${!audioFile.isDirty}');
      } catch (e) {
        print('Encoding failed due to validation issues: ${e.toString().split('\n').first}');
        print('Note: Some files have metadata inconsistencies that prevent encoding');
        print('Reading and modifying tags still works correctly');
      }
    }

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in modifying tags: $e\n');
  }
}

/// Demonstrates working with multi-valued tags like genres.
Future<void> multiValuedTags() async {
  print('3. Multi-Valued Tags (Genres)');
  print('-----------------------------');

  try {
    final audioFile = await Phonic.fromFile('example/sample2.mp3');

    // Create multi-genre tags using different methods
    print('Creating genre tags:');

    // Method 1: Direct list creation
    final multiGenre = GenreTag(const ['Rock', 'Alternative', 'Indie']);
    audioFile.setTag(multiGenre);
    print('  Set multiple genres: ${multiGenre.value.join(', ')}');

    // Method 2: Single genre convenience constructor
    final singleGenre = GenreTag.single('Jazz');
    print('  Single genre example: ${singleGenre.value.join(', ')}');

    // Method 3: Parse from delimited string (automatic detection)
    final fromString = GenreTag.fromString('Electronic;Ambient;Downtempo');
    print('  Parsed from string: ${fromString.value.join(', ')}');

    // Method 4: Format-specific parsing
    final fromId3v24 = GenreTag.fromId3v24String('Rock\x00Alternative\x00Indie');
    final fromId3v23 = GenreTag.fromId3v23String('Rock/Alternative/Indie');
    print('  ID3v2.4 format: ${fromId3v24.value.join(', ')}');
    print('  ID3v2.3 format: ${fromId3v23.value.join(', ')}');

    // Get all genre tags (may include multiple from different containers)
    final genreTags = audioFile.getTags(TagKey.genre);
    print('Genre tags found: ${genreTags.length}');
    for (final tag in genreTags) {
      final genres = (tag as GenreTag).value;
      print('  From ${tag.provenance.containerKind}: ${genres.join(', ')}');
    }

    // Format-specific encoding for different containers
    final currentGenre = audioFile.getTag(TagKey.genre) as GenreTag?;
    if (currentGenre != null) {
      print('Format-specific encoding:');
      print('  ID3v2.4: "${currentGenre.toId3v24String()}"');
      print('  ID3v2.3: "${currentGenre.toId3v23String()}"');
      print('  MP4: "${currentGenre.toEncodedString(';')}"');
      print('  Display: "${currentGenre.toEncodedString(', ')}"');
    }

    // Remove specific genre value
    audioFile.removeTagValue(TagKey.genre, 'Alternative');
    final afterRemoval = audioFile.getTag(TagKey.genre) as GenreTag?;
    print('After removing "Alternative": ${afterRemoval?.value.join(', ') ?? "None"}');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in multi-valued tags: $e\n');
  }
}

/// Demonstrates artwork handling with lazy loading.
Future<void> artworkHandling() async {
  print('4. Artwork Handling');
  print('-------------------');

  try {
    final audioFile = await Phonic.fromFile('example/sample3.mp3');

    // Create artwork with lazy loading
    final artworkData = ArtworkData(
      mimeType: 'image/jpeg',
      type: ArtworkType.frontCover,
      description: 'Album front cover',
      dataLoader: () async {
        // Simulate loading image data
        print('    Loading artwork data...');
        await Future.delayed(const Duration(milliseconds: 100));
        return _createSampleImageData();
      },
    );

    // Set artwork tag
    final artworkTag = ArtworkTag(artworkData);
    audioFile.setTag(artworkTag);

    // Access artwork metadata without loading image data
    final retrievedArtwork = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
    if (retrievedArtwork != null) {
      print('Artwork metadata:');
      print('  MIME Type: ${retrievedArtwork.value.mimeType}');
      print('  Type: ${retrievedArtwork.value.type}');
      print('  Description: ${retrievedArtwork.value.description}');

      // Load the actual image data when needed
      print('Loading image data on demand...');
      final imageBytes = await retrievedArtwork.value.data;
      print('  Image size: ${imageBytes.length} bytes');
    }

    // Get all artwork tags (there might be multiple)
    final artworkTags = audioFile.getTags(TagKey.artwork);
    print('Total artwork images: ${artworkTags.length}');

    // Add additional artwork types
    final backCoverData = ArtworkData(
      mimeType: 'image/png',
      type: ArtworkType.backCover,
      description: 'Album back cover',
      dataLoader: () async => _createSampleImageData(),
    );
    audioFile.setTag(ArtworkTag(backCoverData));

    final artistPhotoData = ArtworkData(
      mimeType: 'image/jpeg',
      type: ArtworkType.artist,
      description: 'Artist photo',
      dataLoader: () async => _createSampleImageData(),
    );
    audioFile.setTag(ArtworkTag(artistPhotoData));

    // List all artwork after additions
    final allArtwork = audioFile.getTags(TagKey.artwork);
    print('After adding more artwork: ${allArtwork.length} images');
    for (final artwork in allArtwork) {
      final data = (artwork as ArtworkTag).value;
      print('  ${data.type}: ${data.mimeType} - ${data.description}');
    }

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in artwork handling: $e\n');
  }
}

/// Demonstrates batch processing of multiple files.
Future<void> batchProcessing() async {
  print('5. Batch Processing');
  print('------------------');

  // Use the actual sample files
  final filePaths = [
    'example/sample1.mp3',
    'example/sample2.mp3',
    'example/sample3.mp3',
  ];

  print('Processing ${filePaths.length} files...');

  var processedCount = 0;
  var errorCount = 0;

  for (final filePath in filePaths) {
    PhonicAudioFile? audioFile;
    try {
      // Load the file
      audioFile = await Phonic.fromFile(filePath);

      // Read existing metadata
      final title = audioFile.getTag(TagKey.title);
      final artist = audioFile.getTag(TagKey.artist);

      print('  Processing: ${filePath.split('/').last}');
      print('    Title: ${title?.value ?? "Unknown"}');
      print('    Artist: ${artist?.value ?? "Unknown"}');

      // Apply batch updates
      audioFile.setTag(const AlbumTag('Batch Processed Collection'));
      audioFile.setTag(YearTag(2024));
      audioFile.setTag(const CommentTag('Processed with Phonic'));

      // Save if changes were made
      if (audioFile.isDirty) {
        try {
          final updatedBytes = await audioFile.encode();
          print('    Successfully encoded: ${updatedBytes.length} bytes');

          // In a real application:
          // await File('processed_${filePath.split('/').last}').writeAsBytes(updatedBytes);

          audioFile.markClean();
          processedCount++;
        } catch (e) {
          print('    Encoding failed (validation issues in source file): ${e.toString().split('\n').first}');
          print('    Note: This is expected with some files that have metadata inconsistencies');
          // Still count as processed since we could read the tags
          processedCount++;
        }
      } else {
        processedCount++;
      }
    } catch (e) {
      print('    Error processing ${filePath.split('/').last}: $e');
      errorCount++;
    } finally {
      // Always dispose to free resources
      audioFile?.dispose();
    }
  }

  print('Batch processing complete:');
  print('  Processed: $processedCount files');
  print('  Errors: $errorCount files');
  print('');
}

/// Creates sample image data for artwork demonstrations.
Uint8List _createSampleImageData() {
  // Minimal JPEG header for demonstration
  final jpegHeader = [
    0xFF, 0xD8, // JPEG SOI
    0xFF, 0xE0, // APP0 marker
    0x00, 0x10, // Length
    0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, // Version
    0x01, // Units
    0x00, 0x48, 0x00, 0x48, // X/Y density
    0x00, 0x00, // Thumbnail size
  ];

  // Add some dummy image data
  final imageData = List.filled(1000, 0x80);

  // JPEG EOI
  final jpegEnd = [0xFF, 0xD9];

  return Uint8List.fromList([...jpegHeader, ...imageData, ...jpegEnd]);
}
