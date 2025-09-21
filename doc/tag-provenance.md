# Tag Provenance

This guide explains how Phonic tracks the origin and reliability of metadata tags through its provenance system.

## Overview

Every tag in Phonic includes provenance information that tells you:

- **Source container** - Which format/container the tag came from
- **Container version** - Specific version of the container format
- **Confidence level** - How reliable the tag data is
- **Original encoding** - Text encoding used in the source

This information is crucial when dealing with files that contain multiple metadata containers or when assessing data quality.

## Accessing Provenance Information

All metadata tags include a `provenance` property:

```dart
final audioFile = await Phonic.openFile('song.mp3');
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;

if (titleTag != null) {
  final provenance = titleTag.provenance;

  print('Container: ${provenance.containerKind}');      // ContainerKind.id3v2
  print('Version: ${provenance.containerVersion}');     // "2.4"
  print('Confidence: ${provenance.confidence}');        // TagConfidence.certain
  print('Encoding: ${provenance.textEncoding}');        // TextEncoding.utf8
}
```

## Container Types

The `ContainerKind` enum identifies which metadata container the tag originated from:

```dart
enum ContainerKind {
  id3v1,      // ID3v1 tag (MP3)
  id3v2,      // ID3v2 tag (MP3)
  vorbis,     // Vorbis Comment (FLAC, OGG)
  mp4,        // MP4 atoms (M4A, MP4)
  opus,       // Opus tags
  apev2,      // APEv2 tags
}
```

### Usage Examples

```dart
switch (titleTag.provenance.containerKind) {
  case ContainerKind.id3v1:
    print('From ID3v1 tag (limited character set)');
    break;
  case ContainerKind.id3v2:
    print('From ID3v2.${titleTag.provenance.containerVersion} tag');
    break;
  case ContainerKind.vorbis:
    print('From Vorbis Comment (UTF-8 native)');
    break;
  case ContainerKind.mp4:
    print('From MP4 atom');
    break;
}
```

## Confidence Levels

The `TagConfidence` enum indicates how reliable the tag data is:

```dart
enum TagConfidence {
  certain,        // High confidence - native field mapping
  likely,         // Good confidence - standard mapping
  uncertain,      // Low confidence - converted or estimated
  speculative,    // Very low confidence - guessed or derived
}
```

### Confidence Meanings

| Level         | Description                    | Examples                      |
| ------------- | ------------------------------ | ----------------------------- |
| `certain`     | Direct, native field mapping   | ID3v2 TALB → album            |
| `likely`      | Standard but converted mapping | ID3v1 30-char title → title   |
| `uncertain`   | Format conversion applied      | Date extracted from year-only |
| `speculative` | Derived or guessed values      | Genre from filename analysis  |

### Using Confidence Information

```dart
final allTitles = audioFile.getAllTags(TagKey.title);

for (final tag in allTitles) {
  switch (tag.provenance.confidence) {
    case TagConfidence.certain:
      print('High quality: "${tag.value}"');
      break;
    case TagConfidence.likely:
      print('Good quality: "${tag.value}"');
      break;
    case TagConfidence.uncertain:
      print('Medium quality: "${tag.value}" (converted)');
      break;
    case TagConfidence.speculative:
      print('Low quality: "${tag.value}" (derived)');
      break;
  }
}
```

## Container Versions

Different metadata containers have version information:

| Container | Version Examples | Significance                     |
| --------- | ---------------- | -------------------------------- |
| ID3v2     | "2.3", "2.4"     | Different frame IDs and features |
| MP4       | "1.0", "2.0"     | Atom structure variations        |
| Vorbis    | "1.0"            | Comment format version           |
| APEv2     | "2.0"            | Tag structure version            |

### Version-Specific Handling

```dart
final tags = audioFile.getAllTags(TagKey.dateRecorded);

for (final tag in tags) {
  if (tag.provenance.containerKind == ContainerKind.id3v2) {
    final version = tag.provenance.containerVersion;
    switch (version) {
      case "2.3":
        print('ID3v2.3 uses separate TYER/TDAT frames');
        break;
      case "2.4":
        print('ID3v2.4 uses unified TDRC frame');
        break;
    }
  }
}
```

## Text Encoding

The `TextEncoding` enum shows the original character encoding:

```dart
enum TextEncoding {
  latin1,     // ISO-8859-1 (ID3v1, ID3v2 default)
  utf8,       // UTF-8 (modern standard)
  utf16,      // UTF-16 with BOM (ID3v2)
  utf16be,    // UTF-16 Big Endian (ID3v2)
  ascii,      // ASCII (7-bit)
}
```

### Encoding Implications

```dart
final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;

if (titleTag != null) {
  switch (titleTag.provenance.textEncoding) {
    case TextEncoding.latin1:
      print('Limited character set - may have encoding issues');
      break;
    case TextEncoding.utf8:
      print('Full Unicode support');
      break;
    case TextEncoding.utf16:
      print('Unicode with byte order mark');
      break;
    case TextEncoding.ascii:
      print('Basic ASCII characters only');
      break;
  }
}
```

## Multiple Source Handling

When files contain multiple metadata containers, provenance helps you choose the best source:

### Finding All Sources

```dart
// Get all title tags from different containers
final allTitles = audioFile.getAllTags(TagKey.title);

print('Found ${allTitles.length} title sources:');
for (final tag in allTitles) {
  print('  "${tag.value}" from ${tag.provenance.containerKind}');
}
```

### Selecting Best Source

```dart
// Choose highest confidence tag
final bestTag = allTitles.reduce((a, b) =>
    a.provenance.confidence.index > b.provenance.confidence.index ? a : b);

print('Using: "${bestTag.value}" (confidence: ${bestTag.provenance.confidence})');
```

### Container Priority

```dart
// Define preferred container order
const containerPriority = [
  ContainerKind.id3v2,  // Prefer ID3v2 (most capable)
  ContainerKind.vorbis, // Then Vorbis (UTF-8 native)
  ContainerKind.mp4,    // Then MP4
  ContainerKind.id3v1,  // Last resort (limited)
];

TitleTag? selectBestTitle(List<TitleTag> tags) {
  for (final preferred in containerPriority) {
    final match = tags.firstWhere(
      (tag) => tag.provenance.containerKind == preferred,
      orElse: () => null,
    );
    if (match != null) return match;
  }
  return tags.firstOrNull;
}
```

## Format-Specific Considerations

### ID3v1 Limitations

```dart
final tag = audioFile.getTag(TagKey.comment) as CommentTag?;

if (tag?.provenance.containerKind == ContainerKind.id3v1) {
  // ID3v1 comments are limited and may be truncated
  print('ID3v1 comment (max 30 chars): "${tag.value}"');

  // Check if track number affected comment length
  final trackTag = audioFile.getTag(TagKey.trackNumber);
  if (trackTag != null && trackTag.provenance.containerKind == ContainerKind.id3v1) {
    print('Comment limited to 28 chars due to track number');
  }
}
```

### ID3v2 Version Differences

```dart
final dateTag = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;

if (dateTag?.provenance.containerKind == ContainerKind.id3v2) {
  switch (dateTag.provenance.containerVersion) {
    case "2.3":
      // ID3v2.3 uses separate year/date frames
      print('Date from ID3v2.3 (may be year-only)');
      if (dateTag.provenance.confidence == TagConfidence.uncertain) {
        print('Reconstructed from TYER/TDAT frames');
      }
      break;
    case "2.4":
      // ID3v2.4 uses unified timestamp
      print('Date from ID3v2.4 TDRC frame');
      break;
  }
}
```

### Vorbis Comments

```dart
final tags = audioFile.getAllTags();
final vorbisTag = tags.firstWhere(
  (tag) => tag.provenance.containerKind == ContainerKind.vorbis,
  orElse: () => null,
);

if (vorbisTag != null) {
  // Vorbis comments are always UTF-8
  assert(vorbisTag.provenance.textEncoding == TextEncoding.utf8);
  print('UTF-8 native: ${vorbisTag.value}');
}
```

## Provenance in Validation

Use provenance information for validation and quality assessment:

```dart
class TagValidator {
  static bool isHighQuality(MetadataTag tag) {
    final provenance = tag.provenance;

    // Check confidence level
    if (provenance.confidence.index < TagConfidence.likely.index) {
      return false;
    }

    // Prefer UTF-8 encoding
    if (provenance.textEncoding != TextEncoding.utf8 &&
        provenance.textEncoding != TextEncoding.utf16) {
      return false;
    }

    // Avoid ID3v1 for complex data
    if (provenance.containerKind == ContainerKind.id3v1 &&
        tag.value.toString().length > 25) {
      return false;
    }

    return true;
  }

  static String getQualityReport(MetadataTag tag) {
    final p = tag.provenance;
    final quality = <String>[];

    quality.add('Source: ${p.containerKind.name}');
    if (p.containerVersion != null) {
      quality.add('Version: ${p.containerVersion}');
    }
    quality.add('Confidence: ${p.confidence.name}');
    quality.add('Encoding: ${p.textEncoding.name}');

    return quality.join(', ');
  }
}
```

## Debugging with Provenance

Provenance information is invaluable for debugging metadata issues:

```dart
void debugMetadata(PhonicAudioFile audioFile) {
  final allTags = audioFile.getAllTags();

  // Group by container type
  final byContainer = <ContainerKind, List<MetadataTag>>{};
  for (final tag in allTags) {
    byContainer
        .putIfAbsent(tag.provenance.containerKind, () => [])
        .add(tag);
  }

  // Report by container
  for (final entry in byContainer.entries) {
    print('\n=== ${entry.key.name.toUpperCase()} ===');
    for (final tag in entry.value) {
      final p = tag.provenance;
      print('${tag.runtimeType}: "${tag.value}"');
      print('  Confidence: ${p.confidence.name}');
      print('  Encoding: ${p.textEncoding.name}');
      if (p.containerVersion != null) {
        print('  Version: ${p.containerVersion}');
      }
    }
  }
}
```

## Best Practices

### 1. Always Check Confidence

```dart
final tag = audioFile.getTag(TagKey.title);
if (tag != null && tag.provenance.confidence.index >= TagConfidence.likely.index) {
  // Use the tag - confidence is acceptable
  processTag(tag);
}
```

### 2. Handle Multiple Sources Gracefully

```dart
final allArtists = audioFile.getAllTags(TagKey.artist);
if (allArtists.length > 1) {
  // Multiple artist tags found - use provenance to decide
  final bestArtist = selectBestByProvenance(allArtists);
  print('Chose: ${bestArtist.value}');
}
```

### 3. Consider Encoding Limitations

```dart
final tag = audioFile.getTag(TagKey.title);
if (tag?.provenance.textEncoding == TextEncoding.latin1) {
  // May have character encoding issues with non-Latin text
  if (containsNonLatinCharacters(tag.value)) {
    print('Warning: Non-Latin characters in Latin1 field');
  }
}
```

### 4. Document Provenance Decisions

```dart
class MetadataChoice {
  final MetadataTag chosen;
  final List<MetadataTag> alternatives;
  final String reason;

  MetadataChoice(this.chosen, this.alternatives, this.reason);

  @override
  String toString() {
    final alt = alternatives.map((t) => t.provenance.containerKind.name);
    return 'Chose ${chosen.provenance.containerKind.name} over [${alt.join(', ')}]: $reason';
  }
}
```

The provenance system in Phonic ensures you always know where your metadata came from and how reliable it is, enabling informed decisions about data quality and source selection.
