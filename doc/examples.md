# Examples

This guide provides practical, real-world examples of using Phonic for common audio metadata tasks.

## Basic Operations

### Reading Metadata from a Single File

```dart
import 'package:phonic/phonic.dart';
import 'dart:io';

Future<void> readBasicMetadata() async {
  final audioFile = await Phonic.fromFile('song.mp3');

  try {
    // Read basic text metadata
    final title = audioFile.getTag(TagKey.title)?.value;
    final artist = audioFile.getTag(TagKey.artist)?.value;
    final album = audioFile.getTag(TagKey.album)?.value;

    print('Title: ${title ?? "Unknown"}');
    print('Artist: ${artist ?? "Unknown"}');
    print('Album: ${album ?? "Unknown"}');

    // Read numeric metadata
    final track = (audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value;
    final year = (audioFile.getTag(TagKey.year) as YearTag?)?.value;
    final rating = (audioFile.getTag(TagKey.rating) as RatingTag?)?.value;

    if (track != null) print('Track: $track');
    if (year != null) print('Year: $year');
    if (rating != null) print('Rating: $rating/100');

    // Read multi-valued fields
    final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
    if (genreTag != null && genreTag.value.isNotEmpty) {
      print('Genres: ${genreTag.value.join(', ')}');
    }

  } finally {
    audioFile.dispose();
  }
}
```

### Writing Metadata to a File

```dart
Future<void> writeBasicMetadata() async {
  final audioFile = await Phonic.fromFile('input.mp3');

  try {
    // Set basic metadata
    audioFile.setTag(TitleTag('My Favorite Song'));
    audioFile.setTag(ArtistTag('Great Artist'));
    audioFile.setTag(AlbumTag('Best Album Ever'));
    audioFile.setTag(YearTag(2024));
    audioFile.setTag(TrackNumberTag(1));

    // Set multiple genres
    audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));

    // Set rating (0-100)
    audioFile.setTag(RatingTag(85));

    // Save changes
    if (audioFile.isDirty) {
      final updatedBytes = await audioFile.encode();
      await File('output.mp3').writeAsBytes(updatedBytes);
      print('Metadata saved successfully');
    }

  } finally {
    audioFile.dispose();
  }
}
```

## Artwork Operations

### Extracting Artwork

```dart
Future<void> extractArtwork() async {
  final audioFile = await Phonic.fromFile('song_with_artwork.mp3');

  try {
    final artworkTags = audioFile.getTags(TagKey.artwork);

    if (artworkTags.isEmpty) {
      print('No artwork found');
      return;
    }

    print('Found ${artworkTags.length} artwork image(s)');

    for (int i = 0; i < artworkTags.length; i++) {
      final artworkTag = artworkTags[i] as ArtworkTag;
      final artwork = artworkTag.value;

      print('Artwork ${i + 1}:');
      print('  Type: ${artwork.type}');
      print('  MIME Type: ${artwork.mimeType}');
      print('  Description: ${artwork.description ?? "None"}');

      // Load and save the image data
      final imageData = await artwork.data;
      print('  Size: ${(imageData.length / 1024).toStringAsFixed(1)} KB');

      // Determine file extension from MIME type
      String extension;
      switch (artwork.mimeType.toLowerCase()) {
        case 'image/jpeg':
        case 'image/jpg':
          extension = 'jpg';
          break;
        case 'image/png':
          extension = 'png';
          break;
        case 'image/gif':
          extension = 'gif';
          break;
        default:
          extension = 'img';
      }

      final outputFile = File('artwork_${i + 1}.$extension');
      await outputFile.writeAsBytes(imageData);
      print('  Saved to: ${outputFile.path}');
    }

  } finally {
    audioFile.dispose();
  }
}
```

### Adding Artwork

```dart
Future<void> addArtwork() async {
  final audioFile = await Phonic.fromFile('song.mp3');

  try {
    // Check if artwork file exists
    final artworkFile = File('album_cover.jpg');
    if (!await artworkFile.exists()) {
      print('Artwork file not found');
      return;
    }

    // Create artwork data
    final artwork = ArtworkData(
      mimeType: MimeType.jpeg.standardName,
      type: ArtworkType.frontCover,
      description: 'Album front cover',
      dataLoader: () async => await artworkFile.readAsBytes(),
    );

    // Add artwork to file
    audioFile.setTag(ArtworkTag(artwork));

    // Save changes
    if (audioFile.isDirty) {
      final updatedBytes = await audioFile.encode();
      await File('song_with_artwork.mp3').writeAsBytes(updatedBytes);
      print('Artwork added successfully');
    }

  } finally {
    audioFile.dispose();
  }
}
```

## Batch Processing

### Processing Multiple Files

```dart
Future<void> processMusicLibrary() async {
  final directory = Directory('music_library');
  final audioFiles = <String>[];

  // Find all audio files
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) {
      final extension = path.extension(entity.path).toLowerCase();
      if (['.mp3', '.flac', '.ogg', '.m4a'].contains(extension)) {
        audioFiles.add(entity.path);
      }
    }
  }

  print('Found ${audioFiles.length} audio files');

  var processed = 0;
  var errors = 0;

  for (final filePath in audioFiles) {
    try {
      final audioFile = await Phonic.fromFile(filePath);

      try {
        // Process each file
        await processAudioFile(audioFile, filePath);
        processed++;

        if (processed % 100 == 0) {
          print('Processed $processed files...');
        }

      } finally {
        audioFile.dispose();
      }

    } catch (e) {
      print('Error processing $filePath: $e');
      errors++;
    }
  }

  print('Processing complete:');
  print('  Processed: $processed files');
  print('  Errors: $errors files');
}

Future<void> processAudioFile(PhonicAudioFile audioFile, String filePath) async {
  // Example: Fix missing titles using filename
  final title = audioFile.getTag(TagKey.title);
  if (title == null || title.value.trim().isEmpty) {
    final filename = path.basenameWithoutExtension(filePath);
    audioFile.setTag(TitleTag(filename));
    print('Fixed missing title: $filePath');
  }

  // Example: Normalize genre formatting
  final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
  if (genreTag != null) {
    final normalizedGenres = genreTag.value
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .map(_normalizeGenre)
        .toSet()
        .toList();

    if (!_listsEqual(normalizedGenres, genreTag.value)) {
      audioFile.setTag(GenreTag(normalizedGenres));
    }
  }

  // Save if modified
  if (audioFile.isDirty) {
    final updatedBytes = await audioFile.encode();
    await File(filePath).writeAsBytes(updatedBytes);
  }
}

String _normalizeGenre(String genre) {
  const genreMap = {
    'rock': 'Rock',
    'pop': 'Pop',
    'jazz': 'Jazz',
    'blues': 'Blues',
    'electronic': 'Electronic',
  };

  return genreMap[genre.toLowerCase()] ?? genre;
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

### Streaming Large Collections

```dart
Future<void> streamProcessLargeLibrary() async {
  // Find all audio files
  final allFiles = await findAudioFiles(Directory('large_music_library'));
  print('Found ${allFiles.length} audio files');

  final processor = StreamingAudioProcessor(
    config: StreamingConfig(
      batchSize: 50,
      maxConcurrency: 4,
      memoryLimitMB: 200,
      enableProgressReporting: true,
    ),
  );

  // Listen to progress
  processor.progressStream.listen((progress) {
    final percent = (progress.processedCount / progress.totalCount * 100).toStringAsFixed(1);
    print('Progress: $percent% (${progress.processedCount}/${progress.totalCount})');
    print('Current: ${path.basename(progress.currentFile)}');
    print('Rate: ${progress.filesPerSecond.toStringAsFixed(1)} files/sec');
  });

  final results = await processor.processFiles(
    filePaths: allFiles,
    processor: (audioFile, index, total) async {
      // Generate library report
      final metadata = extractMetadataInfo(audioFile);
      await appendToReport(metadata);

      return ProcessingResult.success();
    },
  );

  print('Streaming processing complete:');
  print('  Success: ${results.successCount}');
  print('  Failures: ${results.failureCount}');
  print('  Skipped: ${results.skippedCount}');
}

Map<String, String> extractMetadataInfo(PhonicAudioFile audioFile) {
  return {
    'title': audioFile.getTag(TagKey.title)?.value ?? '',
    'artist': audioFile.getTag(TagKey.artist)?.value ?? '',
    'album': audioFile.getTag(TagKey.album)?.value ?? '',
    'year': (audioFile.getTag(TagKey.year) as YearTag?)?.value?.toString() ?? '',
    'genre': (audioFile.getTag(TagKey.genre) as GenreTag?)?.value.join('; ') ?? '',
  };
}

Future<void> appendToReport(Map<String, String> metadata) async {
  final report = File('library_report.csv');
  final line = '${metadata['title']},${metadata['artist']},${metadata['album']},${metadata['year']},${metadata['genre']}\\n';
  await report.writeAsString(line, mode: FileMode.append);
}

Future<List<String>> findAudioFiles(Directory directory) async {
  final files = <String>[];
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) {
      final ext = path.extension(entity.path).toLowerCase();
      if (['.mp3', '.flac', '.ogg', '.opus', '.m4a'].contains(ext)) {
        files.add(entity.path);
      }
    }
  }
  return files;
}
```

## Album Organization

### Organizing Music by Album

```dart
Future<void> organizeByAlbum() async {
  final sourceDir = Directory('unsorted_music');
  final targetDir = Directory('organized_music');
  await targetDir.create(recursive: true);

  // Find all audio files
  final audioFiles = await findAudioFiles(sourceDir);
  print('Found ${audioFiles.length} files to organize');

  for (final filePath in audioFiles) {
    try {
      await organizeFile(filePath, targetDir.path);
    } catch (e) {
      print('Error organizing $filePath: $e');
    }
  }

  print('Organization complete');
}

Future<void> organizeFile(String sourceFile, String targetBasePath) async {
  final audioFile = await Phonic.fromFile(sourceFile);

  try {
    // Extract metadata for organization
    final artist = audioFile.getTag(TagKey.artist)?.value ?? 'Unknown Artist';
    final album = audioFile.getTag(TagKey.album)?.value ?? 'Unknown Album';
    final title = audioFile.getTag(TagKey.title)?.value ?? path.basenameWithoutExtension(sourceFile);
    final track = (audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value;

    // Create safe directory names
    final safeArtist = sanitizeFilename(artist);
    final safeAlbum = sanitizeFilename(album);
    final safeTitle = sanitizeFilename(title);

    // Build target path
    final albumDir = Directory(path.join(targetBasePath, safeArtist, safeAlbum));
    await albumDir.create(recursive: true);

    // Build filename with track number
    final trackPrefix = track != null ? '${track.toString().padLeft(2, '0')} - ' : '';
    final extension = path.extension(sourceFile);
    final targetFilename = '$trackPrefix$safeTitle$extension';
    final targetPath = path.join(albumDir.path, targetFilename);

    // Copy and encode file to target location
    final encodedData = await audioFile.encode();
    await File(targetPath).writeAsBytes(encodedData);

    print('Organized: $targetPath');

  } finally {
    audioFile.dispose();
  }
}

String sanitizeFilename(String filename) {
  return filename
      .replaceAll(RegExp(r'[<>:"/\\\\|?*]'), '_')  // Remove illegal chars
      .replaceAll(RegExp(r'\\s+'), ' ')            // Normalize whitespace
      .trim()
      .substring(0, math.min(filename.length, 100)); // Limit length
}
```

### Creating Album Collections

```dart
class AlbumInfo {
  final String artist;
  final String album;
  final int? year;
  final List<TrackInfo> tracks;

  AlbumInfo({
    required this.artist,
    required this.album,
    this.year,
    required this.tracks,
  });
}

class TrackInfo {
  final String filePath;
  final String title;
  final int trackNumber;
  final int? duration;

  TrackInfo({
    required this.filePath,
    required this.title,
    required this.trackNumber,
    this.duration,
  });
}

Future<void> createAlbumCollection() async {
  final albumTracks = [
    'track01.mp3',
    'track02.mp3',
    'track03.mp3',
    // ... more tracks
  ];

  final albumInfo = AlbumInfo(
    artist: 'The Great Band',
    album: 'Amazing Album',
    year: 2024,
    tracks: [],
  );

  // Process each track in the album
  for (int i = 0; i < albumTracks.length; i++) {
    final filePath = albumTracks[i];
    final audioFile = await Phonic.fromFile(filePath);

    try {
      // Set consistent album information
      audioFile.setTag(ArtistTag(albumInfo.artist));
      audioFile.setTag(AlbumTag(albumInfo.album));
      audioFile.setTag(AlbumArtistTag(albumInfo.artist));

      if (albumInfo.year != null) {
        audioFile.setTag(YearTag(albumInfo.year!));
      }

      // Set track number
      audioFile.setTag(TrackNumberTag(i + 1));

      // Ensure track has a title
      var title = audioFile.getTag(TagKey.title)?.value;
      if (title == null || title.trim().isEmpty) {
        title = 'Track ${i + 1}';
        audioFile.setTag(TitleTag(title));
      }

      // Add consistent genre
      audioFile.setTag(GenreTag(['Rock']));

      // Save changes
      if (audioFile.isDirty) {
        final updatedBytes = await audioFile.encode();
        await File(filePath).writeAsBytes(updatedBytes);
      }

      print('Updated track ${i + 1}: $title');

    } finally {
      audioFile.dispose();
    }
  }

  print('Album collection created successfully');
}
```

## Format Conversion

### Converting Metadata Between Formats

```dart
Future<void> convertMp3ToFlac() async {
  // This example shows metadata preservation during format conversion
  // Note: Audio conversion would require additional libraries

  final mp3File = await Phonic.fromFile('song.mp3');

  try {
    // Extract all metadata from MP3
    final metadata = extractAllMetadata(mp3File);

    print('Extracted metadata:');
    metadata.forEach((key, value) {
      print('  $key: $value');
    });

    // For actual audio conversion, you would use an audio processing library
    // Here we simulate the process of applying metadata to a new format

    print('\\nMetadata would be preserved in FLAC format with these considerations:');
    print('- ID3v2 tags would become Vorbis Comments');
    print('- Genre field supports multiple values natively in FLAC');
    print('- Artwork embedding is more efficient in FLAC');
    print('- Custom fields are easier to add in Vorbis Comments');

  } finally {
    mp3File.dispose();
  }
}

Map<String, dynamic> extractAllMetadata(PhonicAudioFile audioFile) {
  final metadata = <String, dynamic>{};

  // Basic text fields
  final textFields = [
    TagKey.title,
    TagKey.artist,
    TagKey.album,
    TagKey.albumArtist,
    TagKey.comment,
    TagKey.composer,
    TagKey.grouping,
  ];

  for (final field in textFields) {
    final tag = audioFile.getTag(field);
    if (tag != null) {
      metadata[field.name] = tag.value;
    }
  }

  // Numeric fields
  final year = (audioFile.getTag(TagKey.year) as YearTag?)?.value;
  if (year != null) metadata['year'] = year;

  final track = (audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value;
  if (track != null) metadata['trackNumber'] = track;

  final disc = (audioFile.getTag(TagKey.discNumber) as DiscNumberTag?)?.value;
  if (disc != null) metadata['discNumber'] = disc;

  final rating = (audioFile.getTag(TagKey.rating) as RatingTag?)?.value;
  if (rating != null) metadata['rating'] = rating;

  final bpm = (audioFile.getTag(TagKey.bpm) as BpmTag?)?.value;
  if (bpm != null) metadata['bpm'] = bpm;

  // Multi-value fields
  final genres = (audioFile.getTag(TagKey.genre) as GenreTag?)?.value;
  if (genres != null && genres.isNotEmpty) {
    metadata['genres'] = genres;
  }

  // Check for artwork
  final artworkTags = audioFile.getTags(TagKey.artwork);
  if (artworkTags.isNotEmpty) {
    metadata['artworkCount'] = artworkTags.length;
  }

  return metadata;
}
```

## Quality Assurance

### Validating Audio Library

```dart
class ValidationIssue {
  final String filePath;
  final String issue;
  final String severity; // 'warning', 'error'

  ValidationIssue(this.filePath, this.issue, this.severity);
}

Future<void> validateMusicLibrary() async {
  final directory = Directory('music_library');
  final audioFiles = await findAudioFiles(directory);
  final issues = <ValidationIssue>[];

  print('Validating ${audioFiles.length} audio files...');

  for (final filePath in audioFiles) {
    issues.addAll(await validateAudioFile(filePath));
  }

  // Report results
  final errors = issues.where((i) => i.severity == 'error').toList();
  final warnings = issues.where((i) => i.severity == 'warning').toList();

  print('\\nValidation Results:');
  print('==================');
  print('Files checked: ${audioFiles.length}');
  print('Errors: ${errors.length}');
  print('Warnings: ${warnings.length}');

  if (errors.isNotEmpty) {
    print('\\nErrors:');
    for (final error in errors.take(10)) {
      print('  ${path.basename(error.filePath)}: ${error.issue}');
    }
    if (errors.length > 10) {
      print('  ... and ${errors.length - 10} more errors');
    }
  }

  if (warnings.isNotEmpty) {
    print('\\nWarnings:');
    for (final warning in warnings.take(10)) {
      print('  ${path.basename(warning.filePath)}: ${warning.issue}');
    }
    if (warnings.length > 10) {
      print('  ... and ${warnings.length - 10} more warnings');
    }
  }

  // Export detailed report
  await exportValidationReport(issues, 'validation_report.txt');
}

Future<List<ValidationIssue>> validateAudioFile(String filePath) async {
  final issues = <ValidationIssue>[];

  try {
    final audioFile = await Phonic.fromFile(filePath);

    try {
      // Check required fields
      final title = audioFile.getTag(TagKey.title);
      if (title == null || title.value.trim().isEmpty) {
        issues.add(ValidationIssue(filePath, 'Missing title', 'error'));
      }

      final artist = audioFile.getTag(TagKey.artist);
      if (artist == null || artist.value.trim().isEmpty) {
        issues.add(ValidationIssue(filePath, 'Missing artist', 'error'));
      }

      final album = audioFile.getTag(TagKey.album);
      if (album == null || album.value.trim().isEmpty) {
        issues.add(ValidationIssue(filePath, 'Missing album', 'warning'));
      }

      // Check data quality
      if (title != null && title.value.length > 100) {
        issues.add(ValidationIssue(filePath, 'Title very long (${title.value.length} chars)', 'warning'));
      }

      final year = (audioFile.getTag(TagKey.year) as YearTag?)?.value;
      if (year != null && (year < 1900 || year > DateTime.now().year + 1)) {
        issues.add(ValidationIssue(filePath, 'Invalid year: $year', 'warning'));
      }

      final track = (audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value;
      if (track != null && track < 1) {
        issues.add(ValidationIssue(filePath, 'Invalid track number: $track', 'warning'));
      }

      final rating = (audioFile.getTag(TagKey.rating) as RatingTag?)?.value;
      if (rating != null && (rating < 0 || rating > 100)) {
        issues.add(ValidationIssue(filePath, 'Invalid rating: $rating', 'warning'));
      }

      // Check for inconsistencies
      final genres = (audioFile.getTag(TagKey.genre) as GenreTag?)?.value;
      if (genres != null) {
        for (final genre in genres) {
          if (genre.trim().isEmpty) {
            issues.add(ValidationIssue(filePath, 'Empty genre entry', 'warning'));
          }
          if (genre.length > 50) {
            issues.add(ValidationIssue(filePath, 'Genre name very long: "$genre"', 'warning'));
          }
        }
      }

    } finally {
      audioFile.dispose();
    }

  } catch (e) {
    issues.add(ValidationIssue(filePath, 'Cannot read file: $e', 'error'));
  }

  return issues;
}

Future<void> exportValidationReport(List<ValidationIssue> issues, String reportPath) async {
  final report = File(reportPath);
  final buffer = StringBuffer();

  buffer.writeln('Audio Library Validation Report');
  buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buffer.writeln('Total issues: ${issues.length}');
  buffer.writeln('');

  // Group by severity
  final errors = issues.where((i) => i.severity == 'error').toList();
  final warnings = issues.where((i) => i.severity == 'warning').toList();

  if (errors.isNotEmpty) {
    buffer.writeln('ERRORS (${errors.length}):');
    buffer.writeln('=' * 50);
    for (final error in errors) {
      buffer.writeln('${error.filePath}: ${error.issue}');
    }
    buffer.writeln('');
  }

  if (warnings.isNotEmpty) {
    buffer.writeln('WARNINGS (${warnings.length}):');
    buffer.writeln('=' * 50);
    for (final warning in warnings) {
      buffer.writeln('${warning.filePath}: ${warning.issue}');
    }
  }

  await report.writeAsString(buffer.toString());
  print('Validation report saved to: $reportPath');
}
```

## Integration Examples

### Music Player Integration

```dart
class MusicPlayerIntegration {
  final Map<String, Map<String, String>> _metadataCache = {};

  Future<Map<String, String>> getTrackInfo(String filePath) async {
    // Check cache first
    if (_metadataCache.containsKey(filePath)) {
      return _metadataCache[filePath]!;
    }

    try {
      final audioFile = await Phonic.fromFile(filePath);

      try {
        final metadata = {
          'title': audioFile.getTag(TagKey.title)?.value ?? path.basenameWithoutExtension(filePath),
          'artist': audioFile.getTag(TagKey.artist)?.value ?? 'Unknown Artist',
          'album': audioFile.getTag(TagKey.album)?.value ?? 'Unknown Album',
          'duration': '0:00', // Would come from audio analysis
          'year': (audioFile.getTag(TagKey.year) as YearTag?)?.value?.toString() ?? '',
          'genre': (audioFile.getTag(TagKey.genre) as GenreTag?)?.value.join(', ') ?? '',
        };

        // Cache for future use
        _metadataCache[filePath] = metadata;
        return metadata;

      } finally {
        audioFile.dispose();
      }

    } catch (e) {
      print('Error reading metadata for $filePath: $e');

      // Return fallback metadata
      return {
        'title': path.basenameWithoutExtension(filePath),
        'artist': 'Unknown Artist',
        'album': 'Unknown Album',
        'duration': '0:00',
        'year': '',
        'genre': '',
      };
    }
  }

  Future<Uint8List?> getAlbumArt(String filePath) async {
    try {
      final audioFile = await Phonic.fromFile(filePath);

      try {
        final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
        if (artworkTag != null) {
          return await artworkTag.value.data;
        }
        return null;

      } finally {
        audioFile.dispose();
      }

    } catch (e) {
      print('Error reading artwork for $filePath: $e');
      return null;
    }
  }

  void clearCache() {
    _metadataCache.clear();
  }
}

// Usage in a music player app
final playerIntegration = MusicPlayerIntegration();

Future<void> displayTrackInfo(String currentTrack) async {
  final trackInfo = await playerIntegration.getTrackInfo(currentTrack);
  final albumArt = await playerIntegration.getAlbumArt(currentTrack);

  print('Now Playing:');
  print('  Title: ${trackInfo['title']}');
  print('  Artist: ${trackInfo['artist']}');
  print('  Album: ${trackInfo['album']}');

  if (albumArt != null) {
    print('  Album art: ${albumArt.length} bytes');
    // Display artwork in UI
  }
}
```

### Podcast Processing

```dart
Future<void> processPodcastEpisodes() async {
  final podcastDir = Directory('podcasts');
  final episodes = await findAudioFiles(podcastDir);

  for (final episodePath in episodes) {
    await processPodcastEpisode(episodePath);
  }
}

Future<void> processPodcastEpisode(String filePath) async {
  final audioFile = await Phonic.fromFile(filePath);

  try {
    // Extract episode information from filename if metadata is missing
    final filename = path.basenameWithoutExtension(filePath);
    final episodeMatch = RegExp(r'Episode\\s+(\\d+)', caseSensitive: false).firstMatch(filename);

    if (episodeMatch != null) {
      final episodeNumber = int.parse(episodeMatch.group(1)!);

      // Set episode as track number
      audioFile.setTag(TrackNumberTag(episodeNumber));

      // Ensure title includes episode number if missing
      final title = audioFile.getTag(TagKey.title)?.value;
      if (title == null || !title.contains('Episode')) {
        final newTitle = 'Episode $episodeNumber${title != null ? ': $title' : ''}';
        audioFile.setTag(TitleTag(newTitle));
      }
    }

    // Set genre to Podcast
    audioFile.setTag(GenreTag(['Podcast']));

    // Podcasts often have longer descriptions in comments
    final comment = audioFile.getTag(TagKey.comment)?.value;
    if (comment != null && comment.length > 100) {
      print('Episode has detailed description: ${comment.substring(0, 100)}...');
    }

    // Check for episode artwork
    final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
    if (artworkTag != null) {
      print('Episode has custom artwork');
    }

    // Save if modified
    if (audioFile.isDirty) {
      final updatedBytes = await audioFile.encode();
      await File(filePath).writeAsBytes(updatedBytes);
    }

  } finally {
    audioFile.dispose();
  }
}
```

## Next Steps

These examples demonstrate practical applications of Phonic across different use cases. For more advanced usage:

- **[API Reference](api-reference.md)** - Complete API documentation
- **[Best Practices](best-practices.md)** - Optimization and best practices
- **[Error Handling](error-handling.md)** - Robust error handling strategies
