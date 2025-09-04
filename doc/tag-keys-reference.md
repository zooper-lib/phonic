# Tag Keys Reference

This comprehensive reference covers all metadata fields supported by Phonic, including their usage, format mappings, and constraints.

## Core Metadata Fields

### Text Fields

#### title

**Primary track title or name**

```dart
audioFile.setTag(TitleTag('Bohemian Rhapsody'));
final title = audioFile.getTag(TagKey.title) as TitleTag?;
```

| Format | Mapping     | Constraints        |
| ------ | ----------- | ------------------ |
| ID3v1  | Title field | 30 characters max  |
| ID3v2  | TIT2 frame  | No practical limit |
| Vorbis | TITLE field | No practical limit |
| MP4    | ©nam atom   | No practical limit |

#### artist

**Primary artist or performer**

```dart
audioFile.setTag(ArtistTag('Queen'));
final artist = audioFile.getTag(TagKey.artist) as ArtistTag?;
```

| Format | Mapping      | Constraints        |
| ------ | ------------ | ------------------ |
| ID3v1  | Artist field | 30 characters max  |
| ID3v2  | TPE1 frame   | No practical limit |
| Vorbis | ARTIST field | No practical limit |
| MP4    | ©ART atom    | No practical limit |

#### album

**Album or collection name**

```dart
audioFile.setTag(AlbumTag('A Night at the Opera'));
final album = audioFile.getTag(TagKey.album) as AlbumTag?;
```

| Format | Mapping     | Constraints        |
| ------ | ----------- | ------------------ |
| ID3v1  | Album field | 30 characters max  |
| ID3v2  | TALB frame  | No practical limit |
| Vorbis | ALBUM field | No practical limit |
| MP4    | ©alb atom   | No practical limit |

#### albumArtist

**Artist for the entire album (may differ from track artist)**

```dart
audioFile.setTag(AlbumArtistTag('Queen'));
final albumArtist = audioFile.getTag(TagKey.albumArtist) as AlbumArtistTag?;
```

| Format | Mapping           | Constraints        |
| ------ | ----------------- | ------------------ |
| ID3v1  | Not supported     | -                  |
| ID3v2  | TPE2 frame        | No practical limit |
| Vorbis | ALBUMARTIST field | No practical limit |
| MP4    | aART atom         | No practical limit |

#### comment

**Free-form comment or description**

```dart
audioFile.setTag(CommentTag('Recorded live at Wembley'));
final comment = audioFile.getTag(TagKey.comment) as CommentTag?;
```

| Format | Mapping       | Constraints                        |
| ------ | ------------- | ---------------------------------- |
| ID3v1  | Comment field | 30 chars (28 if track present)     |
| ID3v2  | COMM frame    | Language and description supported |
| Vorbis | COMMENT field | No practical limit                 |
| MP4    | ©cmt atom     | No practical limit                 |

#### composer

**Song composer or songwriter**

```dart
audioFile.setTag(ComposerTag('Freddie Mercury'));
final composer = audioFile.getTag(TagKey.composer) as ComposerTag?;
```

| Format | Mapping        | Constraints        |
| ------ | -------------- | ------------------ |
| ID3v1  | Not supported  | -                  |
| ID3v2  | TCOM frame     | No practical limit |
| Vorbis | COMPOSER field | No practical limit |
| MP4    | ©wrt atom      | No practical limit |

#### grouping

**Content grouping or collection**

```dart
audioFile.setTag(GroupingTag('Greatest Hits'));
final grouping = audioFile.getTag(TagKey.grouping) as GroupingTag?;
```

| Format | Mapping        | Constraints        |
| ------ | -------------- | ------------------ |
| ID3v1  | Not supported  | -                  |
| ID3v2  | TIT1 frame     | No practical limit |
| Vorbis | GROUPING field | No practical limit |
| MP4    | ©grp atom      | No practical limit |

#### encoder

**Software or hardware used to encode the audio**

```dart
audioFile.setTag(EncoderTag('LAME 3.100'));
final encoder = audioFile.getTag(TagKey.encoder) as EncoderTag?;
```

| Format | Mapping       | Constraints        |
| ------ | ------------- | ------------------ |
| ID3v1  | Not supported | -                  |
| ID3v2  | TSSE frame    | No practical limit |
| Vorbis | ENCODER field | No practical limit |
| MP4    | ©too atom     | No practical limit |

#### musicalKey

**Musical key or tonality**

```dart
audioFile.setTag(MusicalKeyTag('C major'));
final key = audioFile.getTag(TagKey.musicalKey) as MusicalKeyTag?;
```

| Format | Mapping         | Constraints        |
| ------ | --------------- | ------------------ |
| ID3v1  | Not supported   | -                  |
| ID3v2  | TKEY frame      | No practical limit |
| Vorbis | KEY field       | No practical limit |
| MP4    | Custom freeform | No practical limit |

#### lyrics

**Song lyrics or text content**

```dart
audioFile.setTag(LyricsTag('Is this the real life?\\nIs this just fantasy?...'));
final lyrics = audioFile.getTag(TagKey.lyrics) as LyricsTag?;
```

| Format | Mapping       | Constraints                        |
| ------ | ------------- | ---------------------------------- |
| ID3v1  | Not supported | -                                  |
| ID3v2  | USLT frame    | Language and description supported |
| Vorbis | LYRICS field  | No practical limit                 |
| MP4    | ©lyr atom     | No practical limit                 |

#### isrc

**International Standard Recording Code**

```dart
audioFile.setTag(IsrcTag('GBUM71505078'));
final isrc = audioFile.getTag(TagKey.isrc) as IsrcTag?;
```

| Format | Mapping         | Constraints                             |
| ------ | --------------- | --------------------------------------- |
| ID3v1  | Not supported   | -                                       |
| ID3v2  | TSRC frame      | 12 characters (format: CC-XXX-YY-NNNNN) |
| Vorbis | ISRC field      | 12 characters                           |
| MP4    | Custom freeform | 12 characters                           |

## Numeric Fields

#### trackNumber

**Track number within album or collection**

```dart
audioFile.setTag(TrackNumberTag(5));
final track = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
print('Track: ${track?.value}'); // Track: 5
```

| Format | Mapping           | Constraints                      |
| ------ | ----------------- | -------------------------------- |
| ID3v1  | Track byte        | 1-255                            |
| ID3v2  | TRCK frame        | Can include total (e.g., "5/12") |
| Vorbis | TRACKNUMBER field | Positive integer                 |
| MP4    | trkn atom         | 1-65535                          |

**Validation:**

- Must be positive integer (≥ 1)
- Typically 1-999 for practical purposes

#### discNumber

**Disc number in multi-disc sets**

```dart
audioFile.setTag(DiscNumberTag(2));
final disc = audioFile.getTag(TagKey.discNumber) as DiscNumberTag?;
```

| Format | Mapping          | Constraints                     |
| ------ | ---------------- | ------------------------------- |
| ID3v1  | Not supported    | -                               |
| ID3v2  | TPOS frame       | Can include total (e.g., "2/3") |
| Vorbis | DISCNUMBER field | Positive integer                |
| MP4    | disk atom        | 1-65535                         |

**Validation:**

- Must be positive integer (≥ 1)
- Typically 1-99 for practical purposes

#### year

**Release year**

```dart
audioFile.setTag(YearTag(1975));
final year = audioFile.getTag(TagKey.year) as YearTag?;
```

| Format  | Mapping    | Constraints           |
| ------- | ---------- | --------------------- |
| ID3v1   | Year field | 4 digits (1900-9999)  |
| ID3v2.3 | TYER frame | 4 digits              |
| ID3v2.4 | TDRL frame | ISO 8601 date format  |
| Vorbis  | DATE field | ISO 8601 or year only |
| MP4     | ©day atom  | Year or full date     |

**Validation:**

- Must be reasonable year (typically 1900-current year + 1)
- Some formats support full dates, but year extraction is standardized

#### bpm

**Beats per minute (tempo)**

```dart
audioFile.setTag(BpmTag(120));
final bpm = audioFile.getTag(TagKey.bpm) as BpmTag?;
```

| Format | Mapping       | Constraints      |
| ------ | ------------- | ---------------- |
| ID3v1  | Not supported | -                |
| ID3v2  | TBPM frame    | Positive integer |
| Vorbis | BPM field     | Positive integer |
| MP4    | tmpo atom     | 1-65535          |

**Validation:**

- Must be positive integer (≥ 1)
- Typical range: 60-200 BPM for most music
- Electronic music may go higher (up to 300+)

#### rating

**User rating or score (0-100 scale)**

```dart
audioFile.setTag(RatingTag(85));
final rating = audioFile.getTag(TagKey.rating) as RatingTag?;
print('Rating: ${rating?.value}/100'); // Rating: 85/100
```

| Format | Mapping         | Constraints    | Scale Conversion    |
| ------ | --------------- | -------------- | ------------------- |
| ID3v1  | Not supported   | -              | -                   |
| ID3v2  | POPM frame      | 0-255 internal | 0-255 → 0-100       |
| Vorbis | RATING field    | Various scales | Normalized to 0-100 |
| MP4    | Custom freeform | 0-100          | Direct mapping      |

**Validation:**

- Must be 0-100 inclusive
- 0 = No rating/unrated
- 100 = Maximum rating

## Date Fields

#### dateRecorded

**Recording date and time**

```dart
final recordingDate = DateTime(2024, 6, 15, 14, 30);
audioFile.setTag(DateRecordedTag(recordingDate));
final recorded = audioFile.getTag(TagKey.dateRecorded) as DateRecordedTag?;
```

| Format  | Mapping       | Constraints            |
| ------- | ------------- | ---------------------- |
| ID3v1   | Not supported | -                      |
| ID3v2.4 | TDRC frame    | ISO 8601 format        |
| ID3v2.3 | TYER + TDAT   | Year and date separate |
| Vorbis  | DATE field    | ISO 8601 format        |
| MP4     | ©day atom     | ISO 8601 format        |

**Validation:**

- Must be valid DateTime
- Typically not future dates
- Precision varies by format

## Multi-Value Fields

#### genre

**Musical genre or style (can contain multiple values)**

```dart
// Single genre
audioFile.setTag(GenreTag.single('Rock'));

// Multiple genres
audioFile.setTag(GenreTag(['Rock', 'Progressive Rock', 'Art Rock']));

final genres = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genres != null) {
  print('Genres: ${genres.value.join(', ')}');
}
```

| Format  | Mapping     | Multi-Value Support | Encoding                |
| ------- | ----------- | ------------------- | ----------------------- |
| ID3v1   | Genre byte  | No (single only)    | 255 predefined genres   |
| ID3v2.3 | TCON frame  | Yes                 | Slash-separated         |
| ID3v2.4 | TCON frame  | Yes                 | Null-terminated strings |
| Vorbis  | GENRE field | Yes                 | Multiple GENRE fields   |
| MP4     | ©gen atom   | Yes                 | Various separators      |

**Genre Handling:**

```dart
// Check format-specific genre encoding
final genreTag = audioFile.getTag(TagKey.genre) as GenreTag?;
if (genreTag != null) {
  // For ID3v2.3 compatibility
  final id3v23String = genreTag.toId3v23String(); // "Rock/Progressive Rock"

  // For MP4 compatibility
  final mp4String = genreTag.toEncodedString(';'); // "Rock;Progressive Rock"

  // Human-readable format
  final displayString = genreTag.toEncodedString(', '); // "Rock, Progressive Rock"
}
```

**Validation:**

- Genre names should be non-empty strings
- Avoid extremely long genre names (> 50 characters)
- Remove duplicates automatically

## Special Fields

#### artwork

**Embedded artwork/images**

```dart
// Add artwork
final artwork = ArtworkData(
  mimeType: MimeType.jpeg.standardName,
  type: ArtworkType.frontCover,
  description: 'Album cover',
  dataLoader: () => File('cover.jpg').readAsBytes(),
);
audioFile.setTag(ArtworkTag(artwork));

// Read artwork
final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
if (artworkTag != null) {
  final imageData = await artworkTag.value.data;
  print('Artwork size: ${imageData.length} bytes');
}
```

| Format | Mapping                | Multi-Image Support | Max Size               |
| ------ | ---------------------- | ------------------- | ---------------------- |
| ID3v1  | Not supported          | -                   | -                      |
| ID3v2  | APIC frame             | Yes                 | ~16MB practical        |
| Vorbis | METADATA_BLOCK_PICTURE | Yes                 | Large images supported |
| MP4    | covr atom              | Limited             | ~16MB practical        |

**Artwork Types:**

```dart
enum ArtworkType {
  frontCover,           // Most common - album front cover
  backCover,            // Album back cover
  leaflet,              // Booklet/leaflet page
  media,                // Media itself (CD, vinyl)
  leadArtist,           // Lead artist/performer
  artist,               // Artist/performer
  conductor,            // Conductor
  band,                 // Band/group
  composer,             // Composer
  lyricist,             // Lyricist/text writer
  recordingLocation,    // Recording location
  duringRecording,      // During recording
  duringPerformance,    // During performance
  movieScreenCapture,   // Video/movie screen capture
  brightColoredFish,    // A bright colored fish (ID3v2 humor)
  illustration,         // Illustration
  bandLogotype,         // Band/artist logotype
  publisherLogotype,    // Publisher/studio logotype
}
```

**MIME Types:**

```dart
// Supported image formats
const supportedMimeTypes = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/bmp',
  'image/webp',
  'image/tiff',
];

// Using MimeType enum for type safety
final artwork = ArtworkData(
  mimeType: MimeType.jpeg.standardName,  // "image/jpeg"
  type: ArtworkType.frontCover,
  description: 'Album cover',
  dataLoader: () => imageFile.readAsBytes(),
);
```

#### custom

**Custom or non-standard fields**

```dart
// Custom fields are format-dependent
audioFile.setTag(CustomTag('CUSTOM_FIELD', 'Custom Value'));
final custom = audioFile.getTag(TagKey.custom) as CustomTag?;
```

| Format | Support        | Implementation           |
| ------ | -------------- | ------------------------ |
| ID3v1  | Not supported  | -                        |
| ID3v2  | TXXX frames    | User-defined text frames |
| Vorbis | Native         | Any field name allowed   |
| MP4    | Freeform atoms | ----:domain:name format  |

## Field Constraints Summary

### Length Constraints

| Field   | ID3v1  | ID3v2    | Vorbis   | MP4      | Recommendation  |
| ------- | ------ | -------- | -------- | -------- | --------------- |
| title   | 30     | No limit | No limit | No limit | < 200 chars     |
| artist  | 30     | No limit | No limit | No limit | < 200 chars     |
| album   | 30     | No limit | No limit | No limit | < 200 chars     |
| comment | 30\*   | No limit | No limit | No limit | < 500 chars     |
| genre   | 1 byte | No limit | No limit | No limit | < 50 chars each |

\*28 characters if track number present in ID3v1

### Value Constraints

| Field       | Type | Range     | Notes                |
| ----------- | ---- | --------- | -------------------- |
| trackNumber | int  | 1+        | Typically 1-999      |
| discNumber  | int  | 1+        | Typically 1-99       |
| year        | int  | 1900-2099 | Current year + 1 max |
| bpm         | int  | 1-300+    | Typical: 60-200      |
| rating      | int  | 0-100     | 0 = unrated          |

## Format Compatibility Matrix

| TagKey       | ID3v1  | ID3v2.3 | ID3v2.4 | Vorbis | MP4      |
| ------------ | ------ | ------- | ------- | ------ | -------- |
| title        | ✅     | ✅      | ✅      | ✅     | ✅       |
| artist       | ✅     | ✅      | ✅      | ✅     | ✅       |
| album        | ✅     | ✅      | ✅      | ✅     | ✅       |
| albumArtist  | ❌     | ✅      | ✅      | ✅     | ✅       |
| trackNumber  | ✅     | ✅      | ✅      | ✅     | ✅       |
| discNumber   | ❌     | ✅      | ✅      | ✅     | ✅       |
| year         | ✅     | ✅      | ⚠️\*    | ✅     | ✅       |
| dateRecorded | ❌     | ⚠️\*    | ✅      | ✅     | ✅       |
| genre        | ✅\*\* | ✅      | ✅      | ✅     | ✅       |
| comment      | ✅     | ✅      | ✅      | ✅     | ✅       |
| bpm          | ❌     | ✅      | ✅      | ✅     | ✅       |
| musicalKey   | ❌     | ✅      | ✅      | ✅     | ⚠️\*\*\* |
| rating       | ❌     | ✅      | ✅      | ✅     | ⚠️\*\*\* |
| lyrics       | ❌     | ✅      | ✅      | ✅     | ✅       |
| artwork      | ❌     | ✅      | ✅      | ✅     | ✅       |
| grouping     | ❌     | ✅      | ✅      | ✅     | ✅       |
| composer     | ❌     | ✅      | ✅      | ✅     | ✅       |
| encoder      | ❌     | ✅      | ✅      | ✅     | ✅       |
| isrc         | ❌     | ✅      | ✅      | ✅     | ⚠️\*\*\* |
| custom       | ❌     | ✅      | ✅      | ✅     | ✅       |

**Legend:**

- ✅ Full support
- ⚠️ Limited support or different implementation
- ❌ Not supported

**Notes:**

- `*` ID3v2.4 uses different date frames than ID3v2.3
- `**` ID3v1 uses predefined genre list only
- `***` MP4 uses custom freeform atoms for some fields

## Usage Examples by Field Type

### Text Field Pattern

```dart
// Reading
final tag = audioFile.getTag(TagKey.title) as TitleTag?;
final value = tag?.value;

// Writing
audioFile.setTag(TitleTag('New Title'));

// Validation
if (value != null && value.trim().isNotEmpty && value.length <= 200) {
  // Valid title
}
```

### Numeric Field Pattern

```dart
// Reading
final tag = audioFile.getTag(TagKey.trackNumber) as TrackNumberTag?;
final value = tag?.value;

// Writing
audioFile.setTag(TrackNumberTag(5));

// Validation
if (value != null && value >= 1 && value <= 999) {
  // Valid track number
}
```

### Multi-Value Field Pattern

```dart
// Reading
final tag = audioFile.getTag(TagKey.genre) as GenreTag?;
final values = tag?.value ?? <String>[];

// Writing
audioFile.setTag(GenreTag(['Rock', 'Alternative']));

// Single value convenience
audioFile.setTag(GenreTag.single('Jazz'));
```

This reference provides the complete specification for all metadata fields supported by Phonic, including format-specific constraints and best practices for cross-format compatibility.
