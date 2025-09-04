# Automatic Tag Conversion

This guide explains how Phonic automatically converts metadata between different format specifications while preserving data integrity and tracking conversion operations.

## Overview

Different audio formats use different field names, data types, and structures for the same logical metadata. For example:

- **Year field**: ID3v2.3 uses `TYER` frame, ID3v2.4 uses `TDRC` frame, MP4 uses `©day` atom
- **Genre field**: ID3v1 uses numeric genre codes, ID3v2 uses text, Vorbis uses freeform text
- **Track numbers**: ID3v2 can store "5/12" format, MP4 stores track/total separately

Phonic's conversion system automatically handles these differences, presenting a unified API while tracking what conversions were applied.

## Automatic Frame/Field Mapping

### ID3v2 Version Conversion

Phonic automatically maps between ID3v2.3 and ID3v2.4 frame formats:

```dart
final audioFile = await Phonic.openFile('song.mp3');
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;

// Regardless of whether source file used:
// - ID3v2.3: TYER + TDAT + TIME frames
// - ID3v2.4: TDRC frame
// You get a unified DateTime value

print('Recorded: ${dateTag?.value}'); // DateTime object
print('Source: ${dateTag?.provenance.containerVersion}'); // "2.3" or "2.4"
```

**ID3v2 Frame Conversions:**

| TagKey         | ID3v2.3 Frame | ID3v2.4 Frame | Conversion                      |
| -------------- | ------------- | ------------- | ------------------------------- |
| `dateRecorded` | TYER + TDAT   | TDRC          | Date reconstruction/unification |
| `year`         | TYER          | TDRC          | Year extraction                 |
| `title`        | TIT2          | TIT2          | Direct (no change)              |
| `originalDate` | TORY          | TDOR          | Direct mapping                  |
| `releaseDate`  | -             | TDRL          | New in v2.4                     |

### Cross-Format Mapping

Phonic maps equivalent fields across different formats:

```dart
// These all map to TagKey.album regardless of source format:
// - ID3v1: Album field
// - ID3v2: TALB frame
// - Vorbis: ALBUM field
// - MP4: ©alb atom

final albumTag = audioFile.getTag(TagKey.album) as AlbumTag?;
print('Album: ${albumTag?.value}'); // Unified regardless of source
```

## Date/Time Conversion

### ID3v2.3 to Unified DateTime

ID3v2.3 uses separate frames for date components:

```dart
// Source file has ID3v2.3 with:
// TYER = "2024"
// TDAT = "0615"  (June 15th)
// TIME = "1430"  (14:30)

final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
if (dateTag?.provenance.containerVersion == "2.3") {
  // Automatically reconstructed into single DateTime
  print('Date: ${dateTag.value}'); // 2024-06-15T14:30:00

  // Confidence reflects reconstruction
  print('Confidence: ${dateTag.provenance.confidence}'); // likely or uncertain
}
```

### Partial Date Handling

When source provides incomplete date information:

```dart
// Source only has year: "2024"
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
if (dateTag != null) {
  final date = dateTag.value;
  // Automatically padded with defaults:
  print('${date.year}-${date.month}-${date.day}'); // "2024-1-1"

  // Confidence indicates partial data
  if (dateTag.provenance.confidence == TagConfidence.uncertain) {
    print('Date reconstructed from partial information');
  }
}
```

### Year Extraction

Year tags are automatically extracted from full dates:

```dart
// Source has full timestamp in ID3v2.4 TDRC: "2024-06-15T14:30:00"
final yearTag = audioFile.getTag(TagKey.year) as YearTag?;
print('Year: ${yearTag?.value}'); // 2024 (extracted automatically)
```

## Genre Conversion

### ID3v1 Numeric Genres

ID3v1 uses predefined numeric genre codes that are automatically converted:

```dart
// Source ID3v1 has genre byte = 17 (which represents "Rock")
final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genreTag?.provenance.containerKind == ContainerKind.id3v1) {
  print('Genre: ${genreTag.value}'); // ["Rock"] - converted from numeric
  print('Confidence: ${genreTag.provenance.confidence}'); // certain
}
```

**ID3v1 Genre Code Examples:**

```dart
// Common ID3v1 genre mappings (automatically applied):
final genreMap = {
  0: "Blues",
  1: "Classic Rock",
  2: "Country",
  3: "Dance",
  4: "Disco",
  17: "Rock",
  21: "Ska",
  255: "Unknown", // Special case
};
```

### Multi-Value Genre Conversion

Different formats handle multiple genres differently:

```dart
// Source formats and their automatic conversion:
// ID3v2.3: "Rock/Alternative Rock" → ["Rock", "Alternative Rock"]
// ID3v2.4: "Rock\0Alternative Rock" → ["Rock", "Alternative Rock"]
// Vorbis: Multiple GENRE fields → ["Rock", "Alternative Rock"]
// MP4: "Rock; Alternative Rock" → ["Rock", "Alternative Rock"]

final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
print('Genres: ${genreTag?.value}'); // Always List<String>
```

## Numeric Field Conversion

### Track/Disc Numbers

Track and disc numbers have different representations across formats:

```dart
// Source formats:
// ID3v2: "5/12" (track 5 of 12)
// MP4: track=5, total=12 (separate values)
// Vorbis: "5" (just track number)

final trackTag = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
print('Track: ${trackTag?.value}'); // 5 (normalized to just track number)

// Total track count available separately if present:
final totalTag = audioFile.getTag(TagKey.totalTracks) as TotalTracksTag?;
print('Total: ${totalTag?.value}'); // 12 (if available)
```

### Rating Scale Conversion

Ratings are normalized from format-specific scales:

```dart
// Source formats and automatic conversion to 0-100 scale:
// ID3v2 POPM: 0-255 → converted to 0-100
// Windows Media: 1-5 → converted to 20,40,60,80,100
// iTunes: 0-5 stars → converted to 0,20,40,60,80,100
// Custom: Any scale → normalized to 0-100

final ratingTag = audioFile.getTag(TagKey.rating) as RatingTag?;
print('Rating: ${ratingTag?.value}/100'); // Always 0-100 scale
```

## Text Encoding Conversion

### Character Set Handling

Text fields are automatically converted to Unicode:

```dart
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
if (titleTag != null) {
  // Regardless of source encoding:
  // - ID3v1: Latin1 → UTF-8
  // - ID3v2: Latin1/UTF-16/UTF-8 → UTF-8
  // - Vorbis: UTF-8 → UTF-8 (no conversion)
  // - MP4: UTF-8 → UTF-8 (no conversion)

  print('Title: ${titleTag.value}'); // Always proper Unicode string
  print('Original encoding: ${titleTag.provenance.textEncoding}');
}
```

### Encoding Confidence

Conversion quality affects confidence levels:

```dart
final tag = audioFile.getTag(TagKey.artist) as ArtistTag?;
if (tag != null) {
  switch (tag.provenance.textEncoding) {
    case TextEncoding.latin1:
      // May have had character loss if non-Latin characters present
      if (tag.provenance.confidence == TagConfidence.uncertain) {
        print('Possible encoding issues detected');
      }
      break;
    case TextEncoding.utf8:
    case TextEncoding.utf16:
      // High confidence - lossless conversion
      print('Clean Unicode conversion');
      break;
  }
}
```

## Custom Field Conversion

### Format-Specific Custom Fields

Custom fields are mapped when possible:

```dart
// Different formats use different custom field mechanisms:
// ID3v2: TXXX frames with descriptions
// Vorbis: Freeform field names
// MP4: ---- atoms (reverse DNS format)

final customTag = audioFile.getTag(TagKey.custom) as CustomTag?;
if (customTag != null) {
  switch (customTag.provenance.containerKind) {
    case ContainerKind.id3v2:
      print('ID3v2 TXXX: ${customTag.description} = ${customTag.value}');
      break;
    case ContainerKind.vorbis:
      print('Vorbis field: ${customTag.description} = ${customTag.value}');
      break;
    case ContainerKind.mp4:
      print('MP4 freeform: ${customTag.description} = ${customTag.value}');
      break;
  }
}
```

## Conversion Tracking

### Detecting Applied Conversions

You can detect when conversions were applied:

```dart
final allTags = audioFile.getAllTags();

for (final tag in allTags) {
  switch (tag.provenance.confidence) {
    case TagConfidence.certain:
      print('${tag.runtimeType}: No conversion needed');
      break;
    case TagConfidence.likely:
      print('${tag.runtimeType}: Minor conversion (encoding, normalization)');
      break;
    case TagConfidence.uncertain:
      print('${tag.runtimeType}: Significant conversion (format mapping)');
      break;
    case TagConfidence.speculative:
      print('${tag.runtimeType}: Heavy conversion (reconstruction, estimation)');
      break;
  }
}
```

### Conversion Details

```dart
void analyzeConversions(PhonicAudioFile audioFile) {
  final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;

  if (dateTag != null) {
    final p = dateTag.provenance;

    if (p.containerKind == ContainerKind.id3v2) {
      switch (p.containerVersion) {
        case "2.3":
          if (p.confidence == TagConfidence.uncertain) {
            print('Date reconstructed from ID3v2.3 TYER/TDAT/TIME frames');
          }
          break;
        case "2.4":
          if (p.confidence == TagConfidence.certain) {
            print('Date directly from ID3v2.4 TDRC frame');
          }
          break;
      }
    }
  }
}
```

## Format-Specific Conversion Examples

### MP3 File with ID3v2.3

```dart
// Original file structure:
// ID3v2.3 header
// TYER: "2024"
// TDAT: "0615"
// TIME: "1430"
// TALB: "Album Name"
// TCON: "17"  (Rock genre code)

final audioFile = await Phonic.openFile('song.mp3');

// Automatic conversions applied:
final date = audioFile.getTag(TagKey.dateRecorded)?.value;
print('Date: ${date?.toIso8601String()}'); // "2024-06-15T14:30:00"

final year = audioFile.getTag(TagKey.year)?.value;
print('Year: $year'); // 2024

final album = audioFile.getTag(TagKey.album)?.value;
print('Album: $album'); // "Album Name"

final genre = audioFile.getTag(TagKey.genre)?.value;
print('Genre: $genre'); // ["Rock"] - converted from code 17
```

### FLAC File with Vorbis Comments

```dart
// Original Vorbis comments:
// TITLE=Song Name
// ARTIST=Artist Name
// DATE=2024-06-15
// GENRE=Rock
// GENRE=Alternative Rock  (multiple fields)

final audioFile = await Phonic.openFile('song.flac');

// Automatic conversions:
final title = audioFile.getTag(TagKey.title)?.value;
print('Title: $title'); // "Song Name" - direct mapping

final date = audioFile.getTag(TagKey.dateRecorded)?.value;
print('Date: ${date?.toIso8601String()}'); // "2024-06-15T00:00:00"

final genres = audioFile.getTag(TagKey.genre)?.value;
print('Genres: $genres'); // ["Rock", "Alternative Rock"] - merged fields
```

### MP4 File

```dart
// Original MP4 atoms:
// ©nam: "Song Name"
// ©day: "2024"
// trkn: [5, 12]  (track 5 of 12)
// gnre: [17]     (Rock genre code)

final audioFile = await Phonic.openFile('song.m4a');

// Automatic conversions:
final title = audioFile.getTag(TagKey.title)?.value;
print('Title: $title'); // "Song Name"

final year = audioFile.getTag(TagKey.year)?.value;
print('Year: $year'); // 2024

final track = audioFile.getTag(TagKey.trackNumber)?.value;
print('Track: $track'); // 5

final total = audioFile.getTag(TagKey.totalTracks)?.value;
print('Total: $total'); // 12

final genre = audioFile.getTag(TagKey.genre)?.value;
print('Genre: $genre'); // ["Rock"] - converted from code
```

## Best Practices

### 1. Trust Automatic Conversion

```dart
// ✅ Let Phonic handle conversions automatically
final yearTag = audioFile.getTag(TagKey.year);
// Works regardless of source format (ID3v2.3 TYER, ID3v2.4 TDRC, MP4 ©day, etc.)
```

### 2. Check Confidence for Conversion Quality

```dart
final dateTag = audioFile.getTag(TagKey.dateRecorded);
if (dateTag?.provenance.confidence == TagConfidence.uncertain) {
  print('Date was reconstructed - may not be fully accurate');
}
```

### 3. Use Provenance for Format-Aware Logic

```dart
final genreTag = audioFile.getTag(TagKey.genre);
if (genreTag?.provenance.containerKind == ContainerKind.id3v1) {
  print('Genre came from ID3v1 - limited to predefined list');
}
```

### 4. Handle Multi-Value Fields Consistently

```dart
// Always expect List<String> for genres, regardless of source format
final genres = audioFile.getTag(TagKey.genre)?.value ?? <String>[];
print('Found ${genres.length} genres');
```

### 5. Validate Converted Numeric Values

```dart
final rating = audioFile.getTag(TagKey.rating)?.value;
if (rating != null) {
  // Always 0-100 scale after conversion
  assert(rating >= 0 && rating <= 100);
  print('${(rating / 20).round()} stars'); // Convert to 5-star scale
}
```

Phonic's automatic conversion system ensures you work with consistent, normalized metadata regardless of the underlying format differences, while preserving information about what conversions were applied through the provenance system.
