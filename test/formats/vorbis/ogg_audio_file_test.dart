import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/vorbis/ogg_audio_file.dart';
import 'package:test/test.dart';

void main() {
  group('OggAudioFile', () {
    group('Constructor', () {
      test('creates instance with valid OGG bytes', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        expect(oggFile, isNotNull);
        expect(oggFile.isDirty, isFalse);
      });

      test('creates instance with isDirty flag', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes, isDirty: true);

        expect(oggFile.isDirty, isTrue);
      });

      test('creates instance with empty bytes', () {
        final emptyBytes = Uint8List(0);
        final oggFile = OggAudioFile.fromBytes(emptyBytes);

        expect(oggFile, isNotNull);
        expect(oggFile.isDirty, isFalse);
      });
    });

    group('Codec Registry Configuration', () {
      test('includes Vorbis Comments codec', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Test that Vorbis Comments codec is available
        expect(oggFile.codecRegistry.findCodec(ContainerKind.vorbis, ''), isNotNull);
      });

      test('includes OGG Vorbis locator', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Test that OGG Vorbis locator is available
        expect(oggFile.codecRegistry.findLocator(ContainerKind.vorbis), isNotNull);
      });

      test('uses OggFormatStrategy', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        expect(oggFile.formatStrategy.mediaKind.name, equals('ogg'));
      });
    });

    group('Tag Operations', () {
      test('handles empty OGG files gracefully', () async {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Extract containers and decode tags (should not throw)
        await oggFile.extractContainersAndDecodeAsync();

        final allTags = oggFile.getAllTags();
        expect(allTags, isEmpty);
      });

      test('applies Vorbis-only precedence', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        final precedence = oggFile.formatStrategy.precedence;
        expect(precedence, hasLength(1));
        expect(precedence.first.$1, equals(ContainerKind.vorbis));
      });

      test('uses correct codec registry', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        final vorbisCodec = oggFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
        expect(vorbisCodec, isNotNull);
        expect(vorbisCodec!.containerKind, equals(ContainerKind.vorbis));

        final vorbisLocator = oggFile.codecRegistry.findLocator(ContainerKind.vorbis);
        expect(vorbisLocator, isNotNull);
        expect(vorbisLocator!.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('Tag Writing', () {
      test('sets tags and marks dirty', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set tags that should be written to Vorbis Comments
        oggFile.setTag(const TitleTag('New Title'));
        oggFile.setTag(const ArtistTag('New Artist'));

        expect(oggFile.isDirty, isTrue);

        // Verify tags are set in memory
        final titleTag = oggFile.getTag(TagKey.title) as TitleTag?;
        final artistTag = oggFile.getTag(TagKey.artist) as ArtistTag?;

        expect(titleTag?.value, equals('New Title'));
        expect(artistTag?.value, equals('New Artist'));
      });

      test('handles genre tags with multiple values', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set multi-genre tag (Vorbis Comments natively support multiple values)
        oggFile.setTag(GenreTag(const ['Rock', 'Alternative', 'Indie']));

        expect(oggFile.isDirty, isTrue);

        final genreTags = oggFile.getTags(TagKey.genre);
        expect(genreTags, hasLength(1));
        final genreTag = genreTags.first as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('removes tags correctly', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set some tags first
        oggFile.setTag(const TitleTag('Test Title'));
        oggFile.setTag(const ArtistTag('Test Artist'));

        // Verify tags exist
        expect(oggFile.getTag(TagKey.title), isNotNull);
        expect(oggFile.getTag(TagKey.artist), isNotNull);

        // Remove title tag
        oggFile.removeTag(TagKey.title);

        expect(oggFile.getTag(TagKey.title), isNull);
        expect(oggFile.getTag(TagKey.artist), isNotNull);
        expect(oggFile.isDirty, isTrue);
      });

      test('removes specific tag values', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set multi-genre tag
        oggFile.setTag(GenreTag(const ['Rock', 'Alternative', 'Indie']));

        // Remove the entire tag by matching the full list value
        oggFile.removeTagValue(TagKey.genre, ['Rock', 'Alternative', 'Indie']);

        final genreTags = oggFile.getTags(TagKey.genre);
        expect(genreTags, isEmpty);
      });
    });

    group('Memory Management', () {
      test('disposes resources correctly', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Should not throw
        oggFile.dispose();
      });

      test('handles large files efficiently', () {
        final largeBytes = Uint8List(1024 * 1024); // 1MB
        _writeOggHeader(largeBytes, 0);

        final oggFile = OggAudioFile.fromBytes(largeBytes);

        expect(oggFile, isNotNull);
        // Should not consume excessive memory during construction
      });
    });

    group('Error Handling', () {
      test('handles corrupted OGG files gracefully', () {
        final corruptedBytes = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
        ]);

        final oggFile = OggAudioFile.fromBytes(corruptedBytes);

        expect(oggFile, isNotNull);
        // Should handle gracefully during tag operations
      });

      test('handles empty files gracefully', () {
        final emptyBytes = Uint8List(0);
        final oggFile = OggAudioFile.fromBytes(emptyBytes);

        expect(oggFile.getAllTags(), isEmpty);
        expect(oggFile.isDirty, isFalse);
      });

      test('handles files without Vorbis Comments', () {
        final audioOnlyBytes = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Basic header
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x01, // One segment
          0x1E, // Segment size
          // Vorbis identification packet
          0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // packet type + "vorbis"
          // Minimal identification data
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);

        final oggFile = OggAudioFile.fromBytes(audioOnlyBytes);
        expect(oggFile.getAllTags(), isEmpty);
      });
    });

    group('OGG-Specific Behavior', () {
      test('uses correct precedence order', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        final precedence = oggFile.formatStrategy.precedence;
        expect(precedence, hasLength(1));
        expect(precedence.first.$1, equals(ContainerKind.vorbis));
        expect(precedence.first.$2, equals(''));
      });

      test('uses correct fanout targets', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        final fanout = oggFile.formatStrategy.fanout;
        expect(fanout, hasLength(1));
        expect(fanout.first.$1, equals(ContainerKind.vorbis));
        expect(fanout.first.$2, equals(''));
      });

      test('detects OGG format correctly', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        expect(oggFile.formatStrategy.canHandle(oggBytes), isTrue);
        expect(oggFile.formatStrategy.detectFormat(oggBytes), equals(MediaKind.ogg));
      });

      test('uses UTF-8 encoding for all text fields', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set tags with Unicode characters
        oggFile.setTag(const TitleTag('Test Title with émojis 🎵'));
        oggFile.setTag(const ArtistTag('Artíst Nâme with ñ'));

        expect(oggFile.isDirty, isTrue);

        final titleTag = oggFile.getTag(TagKey.title) as TitleTag?;
        final artistTag = oggFile.getTag(TagKey.artist) as ArtistTag?;

        expect(titleTag?.value, equals('Test Title with émojis 🎵'));
        expect(artistTag?.value, equals('Artíst Nâme with ñ'));
      });

      test('supports native multi-value fields', () {
        final oggBytes = _createMinimalOggWithVorbisComments();
        final oggFile = OggAudioFile.fromBytes(oggBytes);

        // Set multiple genres (native Vorbis Comments support)
        oggFile.setTag(GenreTag(const ['Electronic', 'Ambient', 'Experimental']));

        final genreTags = oggFile.getTags(TagKey.genre);
        expect(genreTags, hasLength(1));
        final genreTag = genreTags.first as GenreTag;
        expect(genreTag.value, hasLength(3));
        expect(genreTag.value, contains('Electronic'));
        expect(genreTag.value, contains('Ambient'));
        expect(genreTag.value, contains('Experimental'));
      });
    });
  });
}

/// Creates a minimal OGG Vorbis file with basic structure.
Uint8List _createMinimalOggWithVorbisComments() {
  final bytes = <int>[];

  // OGG page header
  bytes.addAll([0x4F, 0x67, 0x67, 0x53]); // "OggS" signature
  bytes.add(0x00); // Version
  bytes.add(0x02); // Header type (first page of logical bitstream)
  bytes.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // Granule position
  bytes.addAll([0x01, 0x00, 0x00, 0x00]); // Serial number
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Page sequence number
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Checksum (placeholder)
  bytes.add(0x01); // Number of segments
  bytes.add(0x1E); // Segment size

  // Vorbis identification packet
  bytes.add(0x01); // Packet type
  bytes.addAll([0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]); // "vorbis"
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Version
  bytes.add(0x02); // Channels
  bytes.addAll([0x44, 0xAC, 0x00, 0x00]); // Sample rate (44100)
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Bitrate maximum
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Bitrate nominal
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // Bitrate minimum
  bytes.add(0xB0); // Blocksize
  bytes.add(0x01); // Framing flag

  return Uint8List.fromList(bytes);
}

/// Writes an OGG header at the specified offset.
void _writeOggHeader(Uint8List bytes, int offset) {
  if (offset + 4 <= bytes.length) {
    bytes[offset] = 0x4F; // 'O'
    bytes[offset + 1] = 0x67; // 'g'
    bytes[offset + 2] = 0x67; // 'g'
    bytes[offset + 3] = 0x53; // 'S'
  }
}
