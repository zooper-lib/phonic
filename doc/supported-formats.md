# Supported Formats

This guide provides comprehensive information about the audio formats supported by Phonic and their capabilities.

## Format Overview

| Format     | Extensions     | Container  | Metadata System | Read | Write | Artwork |
| ---------- | -------------- | ---------- | --------------- | ---- | ----- | ------- |
| MP3        | `.mp3`         | ID3v1/v2.x | ID3 Tags        | ✅   | ✅    | ✅      |
| FLAC       | `.flac`        | FLAC       | Vorbis Comments | ✅   | ✅    | ✅      |
| OGG Vorbis | `.ogg`         | OGG        | Vorbis Comments | ✅   | ✅    | ✅      |
| Opus       | `.opus`        | OGG        | Vorbis Comments | ✅   | ✅    | ✅      |
| MP4/M4A    | `.mp4`, `.m4a` | MP4        | MP4 Atoms       | ✅   | ✅    | ✅      |

## MP3 Format

### Container Support

MP3 files can contain multiple metadata containers:

```dart
// MP3 files may have both ID3v1 and ID3v2 tags
final audioFile = await Phonic.fromFile('song.mp3');

// Check which containers are present
final allTags = audioFile.getAllTags();
final hasId3v1 = allTags.any((tag) => tag.provenance.containerKind == ContainerKind.id3v1);
final hasId3v2 = allTags.any((tag) => tag.provenance.containerKind == ContainerKind.id3v2);

print('Has ID3v1: $hasId3v1');
print('Has ID3v2: $hasId3v2');

// ID3v2 takes precedence over ID3v1
final title = audioFile.getTag(TagKey.title);
print('Title source: ${title?.provenance.containerKind}');
```

### ID3v1 Capabilities

ID3v1 has significant limitations:

```dart
// ID3v1 field limitations
const id3v1Limits = {
  'title': 30,      // characters
  'artist': 30,     // characters
  'album': 30,      // characters
  'comment': 30,    // characters (28 if track number present)
  'year': 4,        // characters (digits only)
  'genre': 1,       // byte (predefined genres only)
};

// Check if content fits in ID3v1
void checkId3v1Compatibility(PhonicAudioFile audioFile) {
  final title = audioFile.getTag(TagKey.title);
  if (title != null && title.value.length > 30) {
    print('Title too long for ID3v1: ${title.value.length} chars');
  }

  final genre = audioFile.getTag(TagKey.genre) as GenreTag?;
  if (genre != null && genre.value.length > 1) {
    print('Multiple genres not supported in ID3v1');
  }

  // Check for fields not supported in ID3v1
  final unsupported = [
    TagKey.bpm,
    TagKey.musicalKey,
    TagKey.rating,
    TagKey.lyrics,
    TagKey.artwork,
    TagKey.encoder,
    TagKey.isrc,
  ];

  for (final key in unsupported) {
    final tag = audioFile.getTag(key);
    if (tag != null) {
      print('${key.name} not supported in ID3v1 (will be omitted)');
    }
  }
}
```

### ID3v2 Versions

Different ID3v2 versions have varying capabilities:

```dart
// Check ID3v2 version capabilities
void analyzeId3v2Support(PhonicAudioFile audioFile) {
  final id3v2Tags = audioFile.getAllTags()
      .where((tag) => tag.provenance.containerKind == ContainerKind.id3v2);

  for (final tag in id3v2Tags) {
    final version = tag.provenance.containerVersion;
    print('${tag.key} from ID3v${version}');

    switch (version) {
      case '2.2':
        print('  - Legacy version, limited frame types');
        break;
      case '2.3':
        print('  - Most common version');
        print('  - Limited UTF-8 support');
        break;
      case '2.4':
        print('  - Latest version');
        print('  - Full UTF-8 support');
        print('  - Advanced features available');
        break;
    }
  }
}

// ID3v2 encoding support
final capability = id3v24Capability;
final titleSemantics = capability.semantics(TagKey.title);

print('UTF-8 support: ${titleSemantics.supportsEncoding(TextEncoding.utf8)}');
print('UTF-16 support: ${titleSemantics.supportsEncoding(TextEncoding.utf16)}');
```

### MP3 Best Practices

```dart
// Recommended MP3 metadata setup
Future<void> setupMp3Metadata(PhonicAudioFile audioFile) async {
  // Use ID3v2.4 for new files (best feature support)
  // ID3v1 for maximum compatibility

  // Set basic metadata
  audioFile.setTag(TitleTag('Song Title'));
  audioFile.setTag(ArtistTag('Artist Name'));
  audioFile.setTag(AlbumTag('Album Name'));

  // ID3v2 supports multiple genres
  audioFile.setTag(GenreTag(['Rock', 'Alternative']));

  // Advanced features only in ID3v2
  audioFile.setTag(BpmTag(120));
  audioFile.setTag(RatingTag(85));

  // Artwork support in ID3v2 only
  if (await File('cover.jpg').exists()) {
    final artwork = ArtworkData(
      mimeType: MimeType.jpeg.standardName,
      type: ArtworkType.frontCover,
      description: 'Album cover',
      dataLoader: () => File('cover.jpg').readAsBytes(),
    );
    audioFile.setTag(ArtworkTag(artwork));
  }
}
```

## FLAC Format

FLAC uses Vorbis Comments for metadata:

```dart
// FLAC-specific features
Future<void> handleFlacFile(PhonicAudioFile audioFile) async {
  // FLAC supports lossless compression
  print('Format: Lossless FLAC');

  // Vorbis Comments are UTF-8 by default
  final title = audioFile.getTag(TagKey.title);
  print('Title (UTF-8): ${title?.value}');

  // FLAC can embed large artwork efficiently
  final artworkTags = audioFile.getTags(TagKey.artwork);
  print('Embedded artwork: ${artworkTags.length} images');

  // FLAC supports custom fields easily
  final customTag = audioFile.getTag(TagKey.custom);
  if (customTag != null) {
    print('Custom metadata found');
  }
}

// FLAC Vorbis Comments capabilities
final vorbisCapability = vorbisCapability;
print('Multi-valued support: ${vorbisCapability.supportsMultipleValues(TagKey.genre)}');
print('Custom field support: ${vorbisCapability.supportsCustomFields}');
```

## OGG Vorbis and Opus

Both formats use Vorbis Comments in OGG containers:

```dart
// OGG format handling
Future<void> handleOggFile(PhonicAudioFile audioFile) async {
  final allTags = audioFile.getAllTags();
  final isVorbis = allTags.first.provenance.containerKind == ContainerKind.vorbis;

  if (isVorbis) {
    print('OGG Vorbis format detected');

    // Vorbis Comments are very flexible
    final genres = audioFile.getTags(TagKey.genre);
    print('Genres: ${genres.length} entries');

    // Multiple artwork support
    final artworkTags = audioFile.getTags(TagKey.artwork);
    for (int i = 0; i < artworkTags.length; i++) {
      final artwork = (artworkTags[i] as ArtworkTag).value;
      print('Artwork ${i + 1}: ${artwork.type} (${artwork.mimeType})');
    }

    // Check for Opus-specific features
    if (audioFile.toString().endsWith('.opus')) {
      print('Opus audio codec - optimized for speech and music');
    }
  }
}
```

## MP4/M4A Format

MP4 uses atom-based metadata:

```dart
// MP4/M4A handling
Future<void> handleMp4File(PhonicAudioFile audioFile) async {
  // MP4 atoms are well-structured
  print('MP4/M4A format');

  // Check for iTunes-specific tags
  final albumArtist = audioFile.getTag(TagKey.albumArtist);
  if (albumArtist != null) {
    print('Album Artist: ${albumArtist.value}');
  }

  // MP4 supports high-quality artwork
  final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
  if (artworkTag != null) {
    final artwork = artworkTag.value;
    print('Artwork: ${artwork.mimeType}');

    // MP4 often contains high-resolution artwork
    final imageData = await artwork.data;
    print('Artwork size: ${(imageData.length / 1024).toStringAsFixed(1)} KB');
  }

  // Check MP4 capability
  final capability = mp4Capability;
  print('Supports custom atoms: ${capability.supportsCustomFields}');
}

// MP4 atom mapping
void showMp4Mapping() {
  const atomMapping = {
    TagKey.title: '©nam',
    TagKey.artist: '©ART',
    TagKey.album: '©alb',
    TagKey.albumArtist: 'aART',
    TagKey.genre: '©gen',
    TagKey.year: '©day',
    TagKey.trackNumber: 'trkn',
    TagKey.discNumber: 'disk',
    TagKey.artwork: 'covr',
  };

  print('MP4 Atom Mapping:');
  for (final entry in atomMapping.entries) {
    print('  ${entry.key.name} -> ${entry.value}');
  }
}
```

## Format Detection

Phonic automatically detects formats:

```dart
// Format detection process
Future<void> demonstrateFormatDetection() async {
  final testFiles = [
    'song.mp3',   // ID3 header or MP3 sync
    'track.flac', // FLAC signature
    'audio.ogg',  // OGG page header
    'music.m4a',  // MP4 ftyp box
  ];

  for (final filePath in testFiles) {
    try {
      final audioFile = await Phonic.fromFile(filePath);

      // Check detected format
      final tags = audioFile.getAllTags();
      if (tags.isNotEmpty) {
        final containerKind = tags.first.provenance.containerKind;
        final containerVersion = tags.first.provenance.containerVersion;

        print('$filePath: $containerKind v$containerVersion');
      }

      audioFile.dispose();

    } on UnsupportedFormatException catch (e) {
      print('$filePath: Unsupported - ${e.message}');
    }
  }
}

// Manual format checking
bool isFormatSupported(String filePath) {
  final extension = path.extension(filePath).toLowerCase();
  const supported = ['.mp3', '.flac', '.ogg', '.opus', '.m4a', '.mp4'];
  return supported.contains(extension);
}
```

## Cross-Format Compatibility

### Universal Tag Mapping

```dart
// Tags that work across all formats
void showUniversalTags() {
  const universalTags = {
    TagKey.title: 'Supported in all formats',
    TagKey.artist: 'Supported in all formats',
    TagKey.album: 'Supported in all formats',
    TagKey.genre: 'Supported (limitations in ID3v1)',
    TagKey.year: 'Supported in all formats',
    TagKey.trackNumber: 'Supported in all formats',
    TagKey.comment: 'Supported in all formats',
  };

  print('Universal Tag Support:');
  for (final entry in universalTags.entries) {
    print('  ${entry.key.name}: ${entry.value}');
  }
}

// Format-specific limitations
void showFormatLimitations() {
  const limitations = {
    'ID3v1': [
      '30 character limit on text fields',
      'Single genre only (predefined list)',
      'No artwork support',
      'No BPM, rating, or lyrics',
      '4-digit year only',
    ],
    'ID3v2.3': [
      'Limited UTF-8 support',
      'Genre uses slash separators',
    ],
    'ID3v2.4': [
      'Full feature support',
    ],
    'Vorbis Comments': [
      'Full feature support',
      'Case-sensitive field names',
    ],
    'MP4 Atoms': [
      'Full feature support',
      'Some non-standard fields use freeform atoms',
    ],
  };

  print('Format Limitations:');
  for (final format in limitations.entries) {
    print('${format.key}:');
    for (final limitation in format.value) {
      print('  - $limitation');
    }
    print('');
  }
}
```

### Cross-Format Best Practices

```dart
// Write metadata compatible with all formats
Future<void> setUniversalMetadata(PhonicAudioFile audioFile) async {
  // Basic metadata that works everywhere
  audioFile.setTag(TitleTag('Song Title'));
  audioFile.setTag(ArtistTag('Artist Name'));
  audioFile.setTag(AlbumTag('Album Name'));
  audioFile.setTag(YearTag(2024));
  audioFile.setTag(TrackNumberTag(1));

  // Genre - use single genre for ID3v1 compatibility
  final genres = ['Rock', 'Alternative'];
  audioFile.setTag(GenreTag(genres));

  // Comment - keep under 30 chars for ID3v1
  final comment = 'Great song!';
  if (comment.length <= 30) {
    audioFile.setTag(CommentTag(comment));
  }

  // Advanced features - may not work in ID3v1
  audioFile.setTag(BpmTag(120));
  audioFile.setTag(RatingTag(85));

  // Artwork - not supported in ID3v1
  if (await File('cover.jpg').exists()) {
    final artwork = ArtworkData(
      mimeType: MimeType.jpeg.standardName,
      type: ArtworkType.frontCover,
      description: 'Cover',
      dataLoader: () => File('cover.jpg').readAsBytes(),
    );
    audioFile.setTag(ArtworkTag(artwork));
  }
}

// Check compatibility before writing
void validateCrossFormatCompatibility(PhonicAudioFile audioFile) {
  final issues = <String>[];

  // Check text field lengths for ID3v1
  final title = audioFile.getTag(TagKey.title);
  if (title != null && title.value.length > 30) {
    issues.add('Title too long for ID3v1: ${title.value.length} chars');
  }

  final artist = audioFile.getTag(TagKey.artist);
  if (artist != null && artist.value.length > 30) {
    issues.add('Artist too long for ID3v1: ${artist.value.length} chars');
  }

  // Check genre count
  final genres = audioFile.getTags(TagKey.genre);
  if (genres.length > 1) {
    issues.add('Multiple genres not supported in ID3v1');
  }

  // Check for unsupported fields in ID3v1
  final unsupportedInId3v1 = [
    TagKey.bpm,
    TagKey.rating,
    TagKey.lyrics,
    TagKey.artwork,
  ];

  for (final key in unsupportedInId3v1) {
    if (audioFile.getTag(key) != null) {
      issues.add('${key.name} not supported in ID3v1');
    }
  }

  if (issues.isNotEmpty) {
    print('Cross-format compatibility issues:');
    for (final issue in issues) {
      print('  - $issue');
    }
  } else {
    print('Metadata is compatible across all formats');
  }
}
```

## Format-Specific Optimizations

### MP3 Optimization

```dart
Future<void> optimizeMp3Tags(PhonicAudioFile audioFile) async {
  // Use ID3v2.4 for new files
  // Include ID3v1 for maximum compatibility

  // Optimize for file size
  audioFile.setTag(TitleTag('Title'));
  audioFile.removeTag(TagKey.comment); // Remove if empty

  // Compress artwork for MP3
  final artworkTag = audioFile.getTag(TagKey.artwork) as ArtworkTag?;
  if (artworkTag != null) {
    final artwork = artworkTag.value;
    final imageData = await artwork.data;

    if (imageData.length > 500 * 1024) { // > 500KB
      print('Large artwork detected, consider compressing');
    }
  }
}
```

### FLAC Optimization

```dart
Future<void> optimizeFlacTags(PhonicAudioFile audioFile) async {
  // FLAC handles large metadata efficiently
  // Use full quality artwork

  // FLAC supports extensive custom metadata
  audioFile.setTag(TitleTag('Full Song Title With Extended Information'));

  // Multiple genres work well in FLAC
  audioFile.setTag(GenreTag([
    'Progressive Rock',
    'Art Rock',
    'Symphonic Rock',
    'Concept Album',
  ]));

  // High-quality artwork is fine in FLAC
  if (await File('high_quality_cover.png').exists()) {
    final artwork = ArtworkData(
      mimeType: MimeType.png.standardName,
      type: ArtworkType.frontCover,
      description: 'High quality album artwork',
      dataLoader: () => File('high_quality_cover.png').readAsBytes(),
    );
    audioFile.setTag(ArtworkTag(artwork));
  }
}
```

## Next Steps

- **[Format-Specific Features](format-specific-features.md)** - Advanced format-specific capabilities
- **[Tag Management](tag-management.md)** - Working with metadata across formats
- **[Best Practices](best-practices.md)** - Recommendations for optimal format usage
