# Phonic

A unified, format-independent audio metadata library for Dart/Flutter applications. Phonic provides a clean, object-oriented API for reading and writing metadata across different audio formats without requiring users to understand format-specific implementation details.

## 🚀 Features

- **Unified API**: Single interface for all audio formats - no need to know about ID3, Vorbis Comments, or other format specifics
- **Automatic Format Detection**: Automatically detects and handles different audio formats
- **Type-Safe**: Full type safety with strong Dart typing
- **Format-Independent**: Add support for new formats without breaking existing code
- **Object-Oriented**: Clean, modern OOP design following Dart best practices
- **Extensible**: Easy to extend with custom metadata fields

## 📦 Currently Supported Formats

- **MP3 with ID3 tags** (ID3v1, ID3v2.2, ID3v2.3, ID3v2.4)
- More formats coming soon (FLAC, OGG, MP4, etc.)

## 🔧 Installation

Add phonic to your `pubspec.yaml`:

```yaml
dependencies:
  phonic: ^0.1.0
```

## 📖 Quick Start

### Basic Usage

```dart
import 'dart:typed_data';
import 'package:phonic/phonic.dart';

// Load and read metadata
Future<void> readMetadata() async {
  // Load audio file bytes (from file, network, etc.)
  Uint8List audioBytes = await loadAudioFile();

  // Create audio file - format detection is automatic
  PhonicAudioFile? audioFile = await AudioFileFactory.fromBytes(audioBytes);

  if (audioFile != null) {
    // Read metadata using unified interface
    print('Title: ${audioFile.title}');
    print('Artist: ${audioFile.artist}');
    print('Album: ${audioFile.album}');
    print('Genre: ${audioFile.genre}');

    // Access album artwork
    for (var art in audioFile.albumArt) {
      print('Artwork: ${art.type.name} (${art.data.length} bytes)');
    }
  }
}

// Modify and save metadata
Future<void> modifyMetadata() async {
  Uint8List audioBytes = await loadAudioFile();
  PhonicAudioFile? audioFile = await AudioFileFactory.fromBytes(audioBytes);

  if (audioFile != null) {
    // Modify metadata
    audioFile.title = 'New Title';
    audioFile.artist = 'New Artist';
    audioFile.year = '2025';

    // Add custom metadata
    audioFile.setCustomField('encoder', 'My App v1.0');

    // Save changes
    if (audioFile.isDirty) {
      List<int> modifiedBytes = audioFile.encode();
      await saveAudioFile(modifiedBytes);
      audioFile.markClean();
    }
  }
}
```

### Advanced Usage (Format-Specific Features)

For advanced users who need access to format-specific features:

```dart
import 'package:phonic/phonic.dart';

Future<void> advancedMp3Usage() async {
  PhonicAudioFile? audioFile = await AudioFileFactory.fromBytes(audioBytes);

  // Cast to specific implementation for advanced features
  if (audioFile is PhonicMp3AudioFile) {
    // Access MP3/ID3-specific functionality
    audioFile.deleteId3v1Tag();  // Remove ID3v1 tag

    // The unified interface still works
    audioFile.title = 'Title via unified API';
  }
}
```

## 🏗️ Architecture Overview

Phonic follows a layered architecture designed for extensibility and ease of use:

### Core Layer (Format-Independent)

- `PhonicAudioFile`: Abstract base class for all audio files
- `AudioMetadata`: Interface defining common metadata fields
- `AudioFileFactory`: Factory for creating appropriate audio file instances

### Implementation Layer (Format-Specific)

- `PhonicMp3AudioFile`: MP3/ID3 implementation
- Future: `PhonicFlacAudioFile`, `PhonicOggAudioFile`, etc.

### Legacy Layer

- Existing ID3 implementation (comprehensive ID3v1/v2 support)
- Will be extended for other formats

## 🎯 Design Principles

1. **Format Independence**: Users shouldn't need to know about specific metadata container formats
2. **Progressive Enhancement**: Basic unified API for common use cases, format-specific APIs for advanced features
3. **Type Safety**: Strong typing throughout the API
4. **Clean Code**: Following Dart/Flutter best practices and conventions
5. **Extensibility**: Easy to add new formats and features

## 🧪 Metadata Fields

### Common Fields (All Formats)

- `title`: Track title
- `artist`: Primary artist/performer
- `album`: Album name
- `year`: Release year
- `genre`: Music genre
- `comment`: Comments
- `trackNumber`: Track number
- `albumArt`: List of album artwork images

### Custom Fields

- `customFields`: Map for format-specific or custom metadata
- `setCustomField(key, value)`: Add custom metadata
- `getCustomField(key)`: Retrieve custom metadata

## 🔄 Migration from Direct ID3 Usage

If you're currently using the ID3 classes directly, migration is straightforward:

**Before:**

```dart
// Old way - format-specific
Id3v2Tag? tag = Id3v2Tag.decode(bytes, 0);
String? title = tag?.getTitleModel()?.value;
```

**After:**

```dart
// New way - unified
PhonicAudioFile? audioFile = await AudioFileFactory.fromBytes(bytes);
String? title = audioFile?.title;
```

## 🛠️ Development Status

**Current Status**: Foundation implemented with MP3/ID3 support

**Next Steps**:

1. Complete MP3 implementation (album art, track numbers, dates)
2. Add FLAC support
3. Add OGG Vorbis support
4. Add MP4/AAC support
5. File I/O utilities
6. Comprehensive testing suite

## 🤝 Contributing

We welcome contributions! Areas where help is needed:

- Additional format support (FLAC, OGG, MP4)
- Testing and bug fixes
- Documentation improvements
- Performance optimizations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Phonic** - _Because metadata should be simple, not format-dependent._
