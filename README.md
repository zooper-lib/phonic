# Phonic

A unified audio metadata tagging library for Dart that provides a format-agnostic interface for reading and writing audio metadata tags across different container formats. Work with MP3, FLAC, OGG, Opus, and MP4 files using a single, consistent API without needing to understand the complexities of ID3, Vorbis Comments, or MP4 atoms.

## ✨ Key Features

- **🎵 Format Agnostic** - Unified API across ID3v1, ID3v2.x, Vorbis Comments, MP4 atoms
- **🖼️ Smart Artwork** - Lazy loading and memory-optimized image handling
- **⚡ Performance** - Streaming operations for large collections
- **🔧 Type Safe** - Strong typing with Dart enums and sealed classes
- **🛡️ Robust** - Comprehensive error handling and validation
- **📊 Capability Aware** - Format-specific constraint handling

## 📦 Supported Formats

| Format     | Extension      | Container       | Read | Write | Artwork |
| ---------- | -------------- | --------------- | ---- | ----- | ------- |
| MP3        | `.mp3`         | ID3v1/v2.x      | ✅   | ✅    | ✅      |
| FLAC       | `.flac`        | Vorbis Comments | ✅   | ✅    | ✅      |
| OGG Vorbis | `.ogg`         | Vorbis Comments | ✅   | ✅    | ✅      |
| Opus       | `.opus`        | Vorbis Comments | ✅   | ✅    | ✅      |
| MP4/M4A    | `.mp4`, `.m4a` | MP4 Atoms       | ✅   | ✅    | ✅      |

## 🔧 Installation

Add phonic to your `pubspec.yaml`:

```yaml
dependencies:
  phonic: <latest>
```

## 📖 Quick Start

```dart
import 'package:phonic/phonic.dart';

// Load and read metadata
final audioFile = await Phonic.fromFile('song.mp3');
final title = audioFile.getTag(TagKey.title);
print('Title: ${title?.value}');

// Modify and save
audioFile.setTag(TitleTag('New Title'));
final updatedBytes = await audioFile.encode();
await File('updated_song.mp3').writeAsBytes(updatedBytes);

audioFile.dispose();
```

## 📚 Documentation

### Core Topics

- **[Getting Started](doc/getting-started.md)** - Installation, setup, and basic usage
- **[Tag Management](doc/tag-management.md)** - Working with metadata fields and tag operations
- **[Artwork Handling](doc/artwork-handling.md)** - Embedded images, optimization, and lazy loading
- **[Streaming Operations](doc/streaming-operations.md)** - Batch processing and memory efficiency
- **[Error Handling](doc/error-handling.md)** - Exception handling and validation patterns

### Advanced Topics

- **[Tag Provenance](doc/tag-provenance.md)** - Track metadata origin and reliability
- **[Tag Normalization](doc/tag-normalization.md)** - Data cleaning and standardization
- **[Automatic Tag Conversion](doc/automatic-tag-conversion.md)** - Cross-format conversion details
- **[Supported Formats](doc/supported-formats.md)** - Format capabilities and constraints
- **[Best Practices](doc/best-practices.md)** - Performance optimization and usage patterns

### Reference

- **[Tag Keys Reference](doc/tag-keys-reference.md)** - Complete metadata field reference
- **[Examples](doc/examples.md)** - Real-world use cases and integration patterns

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
