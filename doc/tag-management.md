# Tag Management

This guide covers everything you need to know about working with metadata tags in Phonic.

## Overview

Phonic provides a unified API for working with metadata across different audio formats. Each metadata field is represented by a `TagKey` enum value and a corresponding tag class.

## Tag Types and Classes

### Text Tags

Most metadata consists of text information:

| TagKey        | Tag Class        | Description       | Example                |
| ------------- | ---------------- | ----------------- | ---------------------- |
| `title`       | `TitleTag`       | Track title       | "Bohemian Rhapsody"    |
| `artist`      | `ArtistTag`      | Primary artist    | "Queen"                |
| `album`       | `AlbumTag`       | Album name        | "A Night at the Opera" |
| `albumArtist` | `AlbumArtistTag` | Album artist      | "Queen"                |
| `comment`     | `CommentTag`     | Free-form comment | "Recorded at...",      |
| `grouping`    | `GroupingTag`    | Content grouping  | "Greatest Hits"        |
| `composer`    | `ComposerTag`    | Song composer     | "Freddie Mercury"      |
| `encoder`     | `EncoderTag`     | Encoding software | "LAME 3.100"           |
| `musicalKey`  | `MusicalKeyTag`  | Musical key       | "C major", "Am"        |
| `lyrics`      | `LyricsTag`      | Song lyrics       | Full lyrics text       |
| `isrc`        | `IsrcTag`        | ISRC code         | "GBUM71505078"         |

### Numeric Tags

Some tags contain numeric values:

| TagKey        | Tag Class        | Type  | Range  | Description      |
| ------------- | ---------------- | ----- | ------ | ---------------- |
| `trackNumber` | `TrackNumberTag` | `int` | 1+     | Track number     |
| `discNumber`  | `DiscNumberTag`  | `int` | 1+     | Disc number      |
| `year`        | `YearTag`        | `int` | 1000+  | Release year     |
| `bpm`         | `BpmTag`         | `int` | 1-300+ | Beats per minute |
| `rating`      | `RatingTag`      | `int` | 0-100  | User rating      |

### Date Tags

| TagKey         | Tag Class         | Type       | Description         |
| -------------- | ----------------- | ---------- | ------------------- |
| `dateRecorded` | `DateRecordedTag` | `DateTime` | Recording date/time |

### Multi-Value Tags

Some tags can contain multiple values:

| TagKey  | Tag Class  | Type           | Description    |
| ------- | ---------- | -------------- | -------------- |
| `genre` | `GenreTag` | `List<String>` | Musical genres |

### Special Tags

| TagKey    | Tag Class    | Type          | Description      |
| --------- | ------------ | ------------- | ---------------- |
| `artwork` | `ArtworkTag` | `ArtworkData` | Embedded artwork |

## Reading Tags

### Single Value Access

```dart
// Get the first/primary tag value
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
if (titleTag != null) {
  print('Title: ${titleTag.value}');

  // Access metadata about the tag
  print('Source: ${titleTag.provenance.containerKind}');
  print('Confidence: ${titleTag.provenance.confidence}');
}
```

### Multiple Value Access

```dart
// Get all values for a tag key
final genreTags = audioFile.getTags(TagKey.genre);
for (final tag in genreTags) {
  final genreTag = tag as GenreTag;
  print('Genres from ${tag.provenance.containerKind}: ${genreTag.value.join(', ')}');
}

// Or get the consolidated primary tag
final primaryGenre = audioFile.getTag(TagKey.genre) as GenreTag?;
if (primaryGenre != null) {
  print('All genres: ${primaryGenre.value.join(', ')}');
}
```

### Safe Access Patterns

```dart
// Null-safe access with fallback
String getTitle(PhonicAudioFile audioFile) {
  final tag = audioFile.getTag(TagKey.title) as TitleTag?;
  return tag?.value ?? 'Unknown Title';
}

// Type-safe access helper
T? getTagValue<T extends MetadataTag>(PhonicAudioFile audioFile, TagKey key) {
  return audioFile.getTag(key) as T?;
}

// Usage
final titleTag = getTagValue<TitleTag>(audioFile, TagKey.title);
final ratingTag = getTagValue<RatingTag>(audioFile, TagKey.rating);
```

### Reading All Tags

```dart
// Get comprehensive metadata view
final allTags = audioFile.getAllTags();

// Group by tag type
final tagsByKey = <TagKey, List<MetadataTag>>{};
for (final tag in allTags) {
  tagsByKey.putIfAbsent(tag.key, () => []).add(tag);
}

// Display organized view
for (final entry in tagsByKey.entries) {
  print('${entry.key}:');
  for (final tag in entry.value) {
    print('  ${tag.value} (from ${tag.provenance.containerKind})');
  }
}
```

## Writing Tags

### Setting Text Tags

```dart
// Basic text tags
audioFile.setTag(TitleTag('New Song Title'));
audioFile.setTag(ArtistTag('New Artist Name'));
audioFile.setTag(AlbumTag('New Album Name'));
audioFile.setTag(CommentTag('Recorded in 2024'));

// Longer text content
audioFile.setTag(LyricsTag('''
Verse 1:
First line of lyrics
Second line of lyrics

Chorus:
Chorus lyrics here
...
'''));
```

### Setting Numeric Tags

```dart
// Track and disc numbers
audioFile.setTag(TrackNumberTag(5));
audioFile.setTag(DiscNumberTag(1));

// Year and BPM
audioFile.setTag(YearTag(2024));
audioFile.setTag(BpmTag(120));

// Rating (0-100 scale)
audioFile.setTag(RatingTag(85));
```

### Setting Date Tags

```dart
// Recording date with full datetime
final recordingDate = DateTime(2024, 3, 15, 14, 30);
audioFile.setTag(DateRecordedTag(recordingDate));

// Just year/month (day defaults to 1)
final releaseDate = DateTime(2024, 6);
audioFile.setTag(DateRecordedTag(releaseDate));
```

### Setting Multi-Value Tags

```dart
// Multiple genres
audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie Rock']));

// Single genre (convenience constructor)
audioFile.setTag(GenreTag.single('Jazz'));

// Building genre list dynamically
final genres = <String>[];
genres.add('Electronic');
if (isTechno) genres.add('Techno');
if (isAmbient) genres.add('Ambient');
audioFile.setTag(GenreTag(genres));
```

### Tag Validation

Tags are automatically validated during creation:

```dart
try {
  // This will throw TagValidationException
  audioFile.setTag(RatingTag(-1)); // Rating must be 0-100
} on TagValidationException catch (e) {
  print('Validation error: ${e.message}');
  print('Field: ${e.fieldName}');
  print('Value: ${e.invalidValue}');
}

// Valid ranges
audioFile.setTag(RatingTag(0));   // Minimum rating
audioFile.setTag(RatingTag(100)); // Maximum rating
audioFile.setTag(TrackNumberTag(1)); // Minimum track
```

## Removing Tags

### Remove All Values

```dart
// Remove all instances of a tag
audioFile.removeTag(TagKey.comment);
audioFile.removeTag(TagKey.genre);

// Check if removal was successful
final commentTag = audioFile.getTag(TagKey.comment);
assert(commentTag == null, 'Comment should be removed');
```

### Remove Specific Values (Multi-Value Tags)

```dart
// Remove specific genre while keeping others
audioFile.removeTagValue(TagKey.genre, 'Pop');

// Check remaining genres
final remainingGenres = audioFile.getTag(TagKey.genre) as GenreTag?;
if (remainingGenres != null) {
  print('Remaining genres: ${remainingGenres.value.join(', ')}');
}
```

### Conditional Removal

```dart
// Remove empty or default values
void cleanupEmptyTags(PhonicAudioFile audioFile) {
  // Remove empty text fields
  final title = audioFile.getTag(TagKey.title) as TitleTag?;
  if (title?.value.trim().isEmpty == true) {
    audioFile.removeTag(TagKey.title);
  }

  // Remove zero ratings
  final rating = audioFile.getTag(TagKey.rating) as RatingTag?;
  if (rating?.value == 0) {
    audioFile.removeTag(TagKey.rating);
  }

  // Remove empty genre lists
  final genres = audioFile.getTag(TagKey.genre) as GenreTag?;
  if (genres?.value.isEmpty == true) {
    audioFile.removeTag(TagKey.genre);
  }
}
```

## Format Constraints

Different formats have different capabilities and constraints:

### ID3v1 Limitations

```dart
// ID3v1 has strict length limits
final id3v1Capability = id3v1Capability;

// Check field constraints
if (title.length > 30) {
  print('Title will be truncated in ID3v1');
}

// Limited genre support (predefined list only)
final supportedGenres = id3v1Capability.supportedGenres;
if (!supportedGenres.contains('Synthwave')) {
  print('Custom genre not supported in ID3v1');
}
```

### Encoding Support

```dart
// Check text encoding support
final capability = id3v24Capability;
final titleSemantics = capability.semantics(TagKey.title);

if (titleSemantics.supportsEncoding(TextEncoding.utf8)) {
  print('UTF-8 supported for titles');
}

// Some formats have encoding limitations
final id3v23Semantics = id3v23Capability.semantics(TagKey.title);
if (!id3v23Semantics.supportsEncoding(TextEncoding.utf8)) {
  print('UTF-8 not fully supported in ID3v2.3');
}
```

## Multiple Source Tags

When files contain multiple metadata containers (e.g., both ID3v1 and ID3v2), you can access all sources:

```dart
// Get all title tags from different sources
final allTitles = audioFile.getAllTags(TagKey.title);

print('Found ${allTitles.length} title sources:');
for (final tag in allTitles) {
  print('  "${tag.value}" from ${tag.provenance.containerKind}');
}

// Get the primary (best) title - Phonic automatically selects the best source
final primaryTitle = audioFile.getTag(TagKey.title);
print('Primary title: "${primaryTitle?.value}"');
```

## Next Steps

- **[Tag Provenance](tag-provenance.md)** - Learn about tag origin tracking
- **[Tag Normalization](tag-normalization.md)** - Understand data cleaning and normalization
- **[Automatic Tag Conversion](automatic-tag-conversion.md)** - Format conversion details
- **[Artwork Handling](artwork-handling.md)** - Learn about working with embedded images
- **[Error Handling](error-handling.md)** - Handle validation and format errors
