# Tag Normalization

This guide explains how Phonic normalizes metadata values to provide consistent, clean data regardless of the source format.

## Overview

Different audio formats handle metadata in various ways - some use specific encodings, others have format restrictions, and many contain inconsistent or malformed data. Phonic's normalization system automatically:

- **Standardizes text encoding** - Converts all text to Unicode
- **Cleans whitespace** - Removes excessive spacing and line breaks
- **Validates values** - Ensures data meets expected formats
- **Unifies representations** - Converts format-specific values to common forms
- **Handles multi-values** - Separates combined fields appropriately

## Text Normalization

### Unicode Conversion

All text fields are automatically converted to UTF-8, regardless of source encoding:

```dart
final audioFile = await Phonic.openFile('song.mp3');
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;

// Always returns Unicode string, even if source was Latin1 or UTF-16
print('Title: ${titleTag?.value}'); // Properly decoded Unicode
```

### Whitespace Cleaning

Phonic automatically cleans excessive whitespace:

```dart
// Source tag contained: "  Artist Name  \n\t  "
final artistTag = audioFile.getTag(TagKey.artist) as ArtistTag?;
print('Artist: "${artistTag?.value}"'); // "Artist Name" (cleaned)
```

**Normalization Rules:**

- Leading/trailing whitespace removed
- Multiple consecutive spaces reduced to single space
- Tab characters converted to spaces
- Line breaks normalized to single spaces
- Control characters removed

### Null Byte Handling

Some formats may contain null terminators that are cleaned:

```dart
// Source contained: "Title\0\0\0"
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
print('Title: "${titleTag?.value}"'); // "Title" (nulls removed)
```

## Numeric Normalization

### Value Validation

Numeric fields are validated and clamped to reasonable ranges:

```dart
// Even if source contained invalid value like -5 or 999999
final trackTag = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
print('Track: ${trackTag?.value}'); // Valid positive integer
```

### BPM Normalization

BPM values are validated for musical reasonableness:

```dart
final bpmTag = audioFile.getTag(TagKey.bpm) as BpmTag?;
// Source may have contained 0, negative, or impossibly high values
// Normalized to reasonable range (typically 60-300)
if (bpmTag != null) {
  print('BPM: ${bpmTag.value}'); // Valid tempo
}
```

### Year Normalization

Years are validated against reasonable bounds:

```dart
final yearTag = audioFile.getTag(TagKey.year) as YearTag?;
// Ensures year is between 1900 and current year + 1
if (yearTag != null) {
  print('Year: ${yearTag.value}'); // Realistic year value
}
```

### Rating Normalization

Ratings from different scales are normalized to 0-100:

```dart
final ratingTag = audioFile.getTag(TagKey.rating) as RatingTag?;
if (ratingTag != null) {
  // Always 0-100 scale regardless of source format:
  // - ID3v2 POPM (0-255) → normalized to 0-100
  // - Windows Media (1-5) → converted to 0-100
  // - iTunes (0-5) → converted to 0-100
  print('Rating: ${ratingTag.value}/100');
}
```

## Multi-Value Normalization

### Genre Separation

Genres from different formats are unified into consistent lists:

```dart
final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genreTag != null) {
  // Handles various source formats:
  // - ID3v2.3: "Rock/Alternative Rock" → ["Rock", "Alternative Rock"]
  // - ID3v2.4: "Rock\0Alternative Rock" → ["Rock", "Alternative Rock"]
  // - Vorbis: Multiple GENRE fields → ["Rock", "Alternative Rock"]
  // - MP4: "Rock; Alternative Rock" → ["Rock", "Alternative Rock"]

  print('Genres: ${genreTag.value.join(', ')}'); // Consistent list format
}
```

### Custom Separators

Multi-value fields handle various separator formats:

```dart
// Source formats handled automatically:
// - "Rock/Pop/Alternative" (ID3v2.3)
// - "Rock;Pop;Alternative" (MP4)
// - "Rock, Pop, Alternative" (custom)
// - Multiple fields (Vorbis)

final genres = genreTag?.value ?? [];
print('Found ${genres.length} genres: ${genres.join(' • ')}');
```

## Date Normalization

### Format Unification

Dates are parsed from various source formats into standard DateTime:

```dart
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
if (dateTag != null) {
  // Handles source formats:
  // - "2024" → DateTime(2024, 1, 1)
  // - "2024-06" → DateTime(2024, 6, 1)
  // - "2024-06-15" → DateTime(2024, 6, 15)
  // - "2024-06-15T14:30:00" → DateTime(2024, 6, 15, 14, 30)

  print('Recorded: ${dateTag.value.toIso8601String()}');
}
```

### Partial Date Handling

Incomplete dates are normalized with sensible defaults:

```dart
// Source: "2024-06" (year and month only)
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
if (dateTag != null) {
  final date = dateTag.value;
  print('Year: ${date.year}');    // 2024
  print('Month: ${date.month}');  // 6
  print('Day: ${date.day}');      // 1 (default)
}
```

## ISRC Normalization

International Standard Recording Codes are validated and formatted:

```dart
final isrcTag = audioFile.getTag(TagKey.isrc) as IsrcTag?;
if (isrcTag != null) {
  // Handles various input formats:
  // - "GBUM7-15-050-78" → "GBUM71505078"
  // - "GB-UM7-15-05078" → "GBUM71505078"
  // - "gbum71505078" → "GBUM71505078"

  print('ISRC: ${isrcTag.value}'); // Always standard format
}
```

## Format-Specific Normalization

### ID3v1 Limitations

Fields from ID3v1 are normalized considering format constraints:

```dart
final allTags = audioFile.getAllTags();
final id3v1Tags = allTags.where(
  (tag) => tag.provenance.containerKind == ContainerKind.id3v1
);

for (final tag in id3v1Tags) {
  // ID3v1 fields were limited to 30 characters and Latin1 encoding
  // Normalization ensures proper Unicode handling
  print('ID3v1 field: "${tag.value}" (normalized from Latin1)');
}
```

### ID3v2 Frame Handling

ID3v2 frames are normalized according to version:

```dart
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
if (dateTag?.provenance.containerKind == ContainerKind.id3v2) {
  switch (dateTag.provenance.containerVersion) {
    case "2.3":
      // ID3v2.3 used separate TYER/TDAT frames
      // Normalized into single DateTime
      print('Date reconstructed from ID3v2.3 frames');
      break;
    case "2.4":
      // ID3v2.4 uses TDRC unified timestamp
      print('Date from ID3v2.4 TDRC frame');
      break;
  }
}
```

### Vorbis Comment Normalization

Vorbis comments may contain duplicates or non-standard formatting:

```dart
// Vorbis files might have:
// GENRE=Rock
// GENRE=Alternative
// STYLE=Progressive
// All normalized into unified genre list

final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genreTag?.provenance.containerKind == ContainerKind.vorbis) {
  // Duplicates removed, related fields merged
  print('Normalized Vorbis genres: ${genreTag.value}');
}
```

### MP4 Atom Handling

MP4 atoms are normalized from various internal formats:

```dart
final trackTag = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
if (trackTag?.provenance.containerKind == ContainerKind.mp4) {
  // MP4 stores track as "track/total" in trkn atom
  // Normalized to just track number for TagKey.trackNumber
  print('Track: ${trackTag.value}'); // Just the track number
}
```

## Confidence and Normalization

Normalization operations affect confidence levels:

```dart
final tag = audioFile.getTag(TagKey.title) as TitleTag?;
if (tag != null) {
  switch (tag.provenance.confidence) {
    case TagConfidence.certain:
      print('No normalization needed');
      break;
    case TagConfidence.likely:
      print('Minor normalization applied (whitespace, encoding)');
      break;
    case TagConfidence.uncertain:
      print('Significant normalization (format conversion)');
      break;
    case TagConfidence.speculative:
      print('Heavy normalization (reconstructed from partial data)');
      break;
  }
}
```

## Custom Normalization Control

While normalization is automatic, you can access pre-normalization data if needed:

```dart
// Get raw tag data before normalization (advanced usage)
final allTags = audioFile.getAllTags(TagKey.title);

for (final tag in allTags) {
  print('Normalized: "${tag.value}"');

  // Check if significant normalization occurred
  if (tag.provenance.confidence == TagConfidence.uncertain) {
    print('  (Original may have differed significantly)');
  }
}
```

## Normalization Examples

### Text Field Example

```dart
// Various source encodings and formats:
final sources = [
  'ID3v1: "  Artist Name  " (Latin1, 30 chars)',
  'ID3v2: "Artist Name\0\0" (UTF-16 with nulls)',
  'Vorbis: "Artist Name\t\n" (UTF-8 with whitespace)',
  'MP4: "Artist Name   " (UTF-8 with trailing spaces)',
];

// All normalized to:
final artistTag = audioFile.getTag(TagKey.artist) as ArtistTag?;
print('Result: "${artistTag?.value}"'); // "Artist Name"
```

### Multi-Value Example

```dart
// Different source separators:
final sources = [
  'ID3v2.3: "Rock/Alternative Rock/Progressive"',
  'ID3v2.4: "Rock\0Alternative Rock\0Progressive"',
  'MP4: "Rock; Alternative Rock; Progressive"',
  'Vorbis: Three separate GENRE fields',
];

// All normalized to:
final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
print('Genres: ${genreTag?.value}'); // ["Rock", "Alternative Rock", "Progressive"]
```

### Numeric Example

```dart
// Different source scales and formats:
final sources = [
  'ID3v2: "120.5" (string with decimal)',
  'Vorbis: "120" (string integer)',
  'MP4: 120 (binary integer)',
  'Custom: "120 BPM" (with units)',
];

// All normalized to:
final bpmTag = audioFile.getTag(TagKey.bpm) as BpmTag?;
print('BPM: ${bpmTag?.value}'); // 120 (integer)
```

## Performance Considerations

Normalization is performed efficiently:

- **Lazy evaluation** - Only normalizes when tag values are accessed
- **Caching** - Normalized values are cached to avoid re-processing
- **Minimal allocation** - Reuses string instances when no changes needed
- **Format awareness** - Skips unnecessary normalization for clean sources

```dart
// First access performs normalization and caches result
final title1 = audioFile.getTag(TagKey.title)?.value;

// Subsequent accesses use cached normalized value
final title2 = audioFile.getTag(TagKey.title)?.value;
// title1 and title2 are identical without re-normalization
```

## Best Practices

### 1. Trust Normalized Values

```dart
// ✅ Use normalized values directly
final trackNumber = audioFile.getTag(TagKey.trackNumber)?.value;
if (trackNumber != null && trackNumber > 0) {
  // Value is guaranteed to be valid positive integer
}
```

### 2. Check Confidence for Quality Assessment

```dart
final tag = audioFile.getTag(TagKey.title);
if (tag?.provenance.confidence == TagConfidence.uncertain) {
  print('Title underwent significant normalization - may differ from original');
}
```

### 3. Handle Multi-Values Appropriately

```dart
final genres = audioFile.getTag(TagKey.genre)?.value ?? [];
// Always a proper List<String>, never null or malformed
print('${genres.length} genres found');
```

### 4. Use Normalization for Validation

```dart
// Normalization ensures consistent format for comparisons
final year = audioFile.getTag(TagKey.year)?.value;
if (year != null && year >= 2020) {
  print('Recent release');
}
```

Phonic's normalization system ensures you receive clean, consistent metadata regardless of the source format's quirks or limitations, while preserving information about the transformation process through the provenance system.
