# Getting Started

This guide will help you get up and running with Phonic, a unified audio metadata library for Dart.

## Installation

Add phonic to your `pubspec.yaml`:

```yaml
dependencies:
  phonic: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Basic Concepts

### Core Classes

- **`Phonic`** - Factory class for creating audio file instances
- **`PhonicAudioFile`** - Main interface for tag operations
- **`MetadataTag`** - Base class for all tag types (TitleTag, ArtistTag, etc.)
- **`TagKey`** - Enum defining all supported metadata fields

### Workflow

1. **Load** an audio file using `Phonic.fromFile()` or `Phonic.fromBytes()`
2. **Read** metadata using `getTag()` or `getTags()`
3. **Modify** metadata using `setTag()` or `removeTag()`
4. **Save** changes using `encode()` and write to file
5. **Cleanup** using `dispose()` to free resources

## Your First Program

Let's create a simple program that reads and displays metadata:

```dart
import 'dart:io';
import 'package:phonic/phonic.dart';

void main() async {
  // Load an audio file
  final audioFile = await Phonic.fromFile('song.mp3');

  // Read basic metadata
  final title = audioFile.getTag(TagKey.title);
  final artist = audioFile.getTag(TagKey.artist);
  final album = audioFile.getTag(TagKey.album);

  // Display the information
  print('Title: ${title?.value ?? "Unknown"}');
  print('Artist: ${artist?.value ?? "Unknown"}');
  print('Album: ${album?.value ?? "Unknown"}');

  // Always dispose when done
  audioFile.dispose();
}
```

## Loading Audio Files

### From File Path

```dart
// Load from file system
final audioFile = await Phonic.fromFile('/path/to/song.mp3');

// The library automatically detects the format
// Supports: MP3, FLAC, OGG, Opus, MP4/M4A
```

### From Byte Array

```dart
// Load from memory (useful for embedded data or network streams)
final bytes = await File('song.mp3').readAsBytes();
final audioFile = Phonic.fromBytes(bytes, 'song.mp3');

// Filename hint helps with format detection
```

### Error Handling

```dart
try {
  final audioFile = await Phonic.fromFile('song.mp3');
  // Use the audio file...
  audioFile.dispose();
} on UnsupportedFormatException catch (e) {
  print('Unsupported format: ${e.message}');
} on FileSystemException catch (e) {
  print('File error: ${e.message}');
}
```

## Reading Metadata

### Single Value Tags

Most metadata fields contain a single value:

```dart
// Basic text fields
final title = audioFile.getTag(TagKey.title) as TitleTag?;
final artist = audioFile.getTag(TagKey.artist) as ArtistTag?;
final album = audioFile.getTag(TagKey.album) as AlbumTag?;

print('Title: ${title?.value}');
print('Artist: ${artist?.value}');
print('Album: ${album?.value}');

// Numeric fields
final trackTag = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
final yearTag = audioFile.getTag(TagKey.year) as YearTag?;
final ratingTag = audioFile.getTag(TagKey.rating) as RatingTag?;

if (trackTag != null) {
  print('Track: ${trackTag.value}');
}
if (yearTag != null) {
  print('Year: ${yearTag.value}');
}
if (ratingTag != null) {
  print('Rating: ${ratingTag.value}/100');
}
```

### Multi-Value Tags

Some tags can contain multiple values:

```dart
// Genre can have multiple values
final genreTags = audioFile.getTags(TagKey.genre);
if (genreTags.isNotEmpty) {
  final genres = (genreTags.first as GenreTag).value;
  print('Genres: ${genres.join(', ')}');
}

// Or get the first genre tag directly
final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genreTag != null && genreTag.value.isNotEmpty) {
  print('Primary genre: ${genreTag.value.first}');
}
```

### Getting All Tags

```dart
// Get all metadata tags
final allTags = audioFile.getAllTags();

for (final tag in allTags) {
  print('${tag.key}: ${tag.value}');
}
```

## Writing Metadata

### Setting Basic Tags

```dart
// Set text fields
audioFile.setTag(TitleTag('New Song Title'));
audioFile.setTag(ArtistTag('New Artist'));
audioFile.setTag(AlbumTag('New Album'));

// Set numeric fields
audioFile.setTag(TrackNumberTag(5));
audioFile.setTag(YearTag(2024));
audioFile.setTag(RatingTag(85)); // 0-100 scale
```

### Setting Multi-Value Tags

```dart
// Set multiple genres
audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));

// Or set a single genre
audioFile.setTag(GenreTag.single('Jazz'));
```

### Removing Tags

```dart
// Remove all tags of a specific type
audioFile.removeTag(TagKey.comment);

// For multi-value tags, remove specific values
audioFile.removeTagValue(TagKey.genre, 'Pop');
```

## Saving Changes

### Check if Changes Were Made

```dart
if (audioFile.isDirty) {
  print('File has unsaved changes');
} else {
  print('No changes to save');
}
```

### Encode and Save

```dart
// Get the updated file bytes
final updatedBytes = await audioFile.encode();

// Write to new file
await File('updated_song.mp3').writeAsBytes(updatedBytes);

// Mark as clean (no unsaved changes)
audioFile.markClean();
```

### Complete Example

```dart
import 'dart:io';
import 'package:phonic/phonic.dart';

Future<void> updateMetadata(String filePath) async {
  // Load the file
  final audioFile = await Phonic.fromFile(filePath);

  try {
    // Read current metadata
    final title = audioFile.getTag(TagKey.title);
    print('Current title: ${title?.value ?? "None"}');

    // Update metadata
    audioFile.setTag(TitleTag('Updated Title'));
    audioFile.setTag(ArtistTag('Updated Artist'));
    audioFile.setTag(GenreTag(['Electronic', 'Ambient']));

    // Save if there are changes
    if (audioFile.isDirty) {
      final updatedBytes = await audioFile.encode();
      await File('updated_$filePath').writeAsBytes(updatedBytes);
      audioFile.markClean();
      print('Metadata updated successfully');
    }
  } finally {
    // Always clean up
    audioFile.dispose();
  }
}
```

## Memory Management

### Resource Cleanup

Always call `dispose()` when you're done with an audio file:

```dart
// Manual cleanup
final audioFile = await Phonic.fromFile('song.mp3');
try {
  // Use the audio file...
} finally {
  audioFile.dispose();
}

// Or use a helper function
Future<T> withAudioFile<T>(
  String path,
  Future<T> Function(PhonicAudioFile) action,
) async {
  final audioFile = await Phonic.fromFile(path);
  try {
    return await action(audioFile);
  } finally {
    audioFile.dispose();
  }
}

// Usage
await withAudioFile('song.mp3', (audioFile) async {
  final title = audioFile.getTag(TagKey.title);
  print('Title: ${title?.value}');
});
```

## Format Detection

Phonic automatically detects audio formats based on:

1. **File content** (magic bytes, headers)
2. **File extension** (fallback)
3. **Filename hints** (for byte arrays)

```dart
// Format is detected automatically
final mp3File = await Phonic.fromFile('song.mp3');     // ID3v1/v2
final flacFile = await Phonic.fromFile('song.flac');   // Vorbis Comments
final m4aFile = await Phonic.fromFile('song.m4a');     // MP4 atoms

// For bytes, provide filename hint
final audioFile = Phonic.fromBytes(bytes, 'song.ogg'); // Helps detection
```

## Error Handling Best Practices

```dart
Future<void> safeReadMetadata(String filePath) async {
  try {
    final audioFile = await Phonic.fromFile(filePath);

    try {
      // Read metadata safely
      final title = audioFile.getTag(TagKey.title);
      if (title != null) {
        print('Title: ${title.value}');
      } else {
        print('No title found');
      }
    } finally {
      audioFile.dispose();
    }

  } on UnsupportedFormatException catch (e) {
    print('Format not supported: ${e.message}');
  } on FileSystemException catch (e) {
    print('File system error: ${e.message}');
  } on PhonicException catch (e) {
    print('Phonic error: ${e.message}');
  } catch (e) {
    print('Unexpected error: $e');
  }
}
```

## Next Steps

Now that you understand the basics:

1. **[Tag Management](tag-management.md)** - Learn about all supported metadata fields
2. **[Artwork Handling](artwork-handling.md)** - Work with embedded album art
3. **[Streaming Operations](streaming-operations.md)** - Process large audio collections efficiently
4. **[Error Handling](error-handling.md)** - Handle edge cases and errors gracefully

## Common Patterns

### Quick Metadata Reader

```dart
Map<String, String> getBasicMetadata(String filePath) async {
  final audioFile = await Phonic.fromFile(filePath);

  try {
    return {
      'title': audioFile.getTag(TagKey.title)?.value ?? '',
      'artist': audioFile.getTag(TagKey.artist)?.value ?? '',
      'album': audioFile.getTag(TagKey.album)?.value ?? '',
      'year': audioFile.getTag(TagKey.year)?.value?.toString() ?? '',
    };
  } finally {
    audioFile.dispose();
  }
}
```

### Batch Metadata Update

```dart
Future<void> updateAlbumInfo(List<String> tracks, String album, String artist) async {
  for (final track in tracks) {
    final audioFile = await Phonic.fromFile(track);

    try {
      audioFile.setTag(AlbumTag(album));
      audioFile.setTag(AlbumArtistTag(artist));

      if (audioFile.isDirty) {
        final bytes = await audioFile.encode();
        await File(track).writeAsBytes(bytes);
        audioFile.markClean();
      }
    } finally {
      audioFile.dispose();
    }
  }
}
```
