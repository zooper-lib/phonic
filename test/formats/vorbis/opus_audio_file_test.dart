import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/vorbis/opus_audio_file.dart';
import 'package:test/test.dart';

void main() {
  group('OpusAudioFile', () {
    group('Constructor', () {
      test('creates instance with valid Opus bytes', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        expect(opusFile, isNotNull);
        expect(opusFile.isDirty, isFalse);
      });

      test('creates instance with isDirty flag', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes, isDirty: true);

        expect(opusFile.isDirty, isTrue);
      });

      test('creates instance with empty bytes', () {
        final emptyBytes = Uint8List(0);
        final opusFile = OpusAudioFile.fromBytes(emptyBytes);

        expect(opusFile, isNotNull);
        expect(opusFile.isDirty, isFalse);
      });
    });

    group('Codec Registry Configuration', () {
      test('includes Vorbis Comments codec', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Test that Vorbis Comments codec is available
        expect(opusFile.codecRegistry.findCodec(ContainerKind.vorbis, ''), isNotNull);
      });

      test('includes OGG Vorbis locator', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Test that OGG Vorbis locator is available
        expect(opusFile.codecRegistry.findLocator(ContainerKind.vorbis), isNotNull);
      });

      test('uses OpusFormatStrategy', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        expect(opusFile.formatStrategy.mediaKind.name, equals('opus'));
      });
    });

    group('Tag Operations', () {
      test('handles empty Opus files gracefully', () async {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Extract containers and decode tags (should not throw)
        await opusFile.extractContainersAndDecode();

        final allTags = opusFile.getAllTags();
        expect(allTags, isEmpty);
      });

      test('applies Vorbis-only precedence', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        final precedence = opusFile.formatStrategy.precedence;
        expect(precedence, hasLength(1));
        expect(precedence.first.$1, equals(ContainerKind.vorbis));
      });

      test('uses correct codec registry', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        final vorbisCodec = opusFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
        expect(vorbisCodec, isNotNull);
        expect(vorbisCodec!.containerKind, equals(ContainerKind.vorbis));

        final vorbisLocator = opusFile.codecRegistry.findLocator(ContainerKind.vorbis);
        expect(vorbisLocator, isNotNull);
        expect(vorbisLocator!.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('Tag Writing', () {
      test('sets tags and marks dirty', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set tags that should be written to Vorbis Comments
        opusFile.setTag(const TitleTag('New Title'));
        opusFile.setTag(const ArtistTag('New Artist'));

        expect(opusFile.isDirty, isTrue);
        expect(opusFile.getTag(TagKey.title)?.value, equals('New Title'));
        expect(opusFile.getTag(TagKey.artist)?.value, equals('New Artist'));
      });

      test('handles genre tags with multiple values', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set multi-genre tag (Vorbis Comments natively support multiple values)
        opusFile.setTag(GenreTag(const ['Electronic', 'Ambient', 'Experimental']));

        expect(opusFile.isDirty, isTrue);
        final genreTag = opusFile.getTag(TagKey.genre) as GenreTag?;
        expect(genreTag?.value, equals(['Electronic', 'Ambient', 'Experimental']));
      });

      test('removes tags correctly', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set some tags first
        opusFile.setTag(const TitleTag('Title to Remove'));
        opusFile.setTag(const ArtistTag('Artist to Keep'));
        opusFile.markClean();

        // Remove title tag
        opusFile.removeTag(TagKey.title);

        expect(opusFile.isDirty, isTrue);
        expect(opusFile.getTag(TagKey.title), isNull);
        expect(opusFile.getTag(TagKey.artist)?.value, equals('Artist to Keep'));
      });

      test('removes specific tag values', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set up multiple genre tags directly (simulating multiple GENRE fields in Vorbis Comments)
        final tag1 = GenreTag(const ['Electronic']);
        final tag2 = GenreTag(const ['Ambient']);
        final tag3 = GenreTag(const ['Experimental']);
        opusFile.inMemoryTagsByKey[TagKey.genre] = [tag1, tag2, tag3];
        opusFile.markClean();

        // Remove the tag with 'Ambient' value
        opusFile.removeTagValue(TagKey.genre, ['Ambient']);

        expect(opusFile.isDirty, isTrue);
        final genreTags = opusFile.getTags(TagKey.genre);
        expect(genreTags, hasLength(2));

        final genreValues = genreTags.map((tag) => (tag as GenreTag).value.first).toList();
        expect(genreValues, containsAll(['Electronic', 'Experimental']));
        expect(genreValues, isNot(contains('Ambient')));
      });

      test('disposes resources correctly', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Should not throw
        opusFile.dispose();
      });

      test('handles large Opus files', () {
        final largeBytes = Uint8List(1024 * 1024); // 1MB
        _writeOpusHeader(largeBytes, 0);

        final opusFile = OpusAudioFile.fromBytes(largeBytes);

        expect(opusFile, isNotNull);
      });
    });

    group('Error Handling', () {
      test('handles corrupted Opus files gracefully', () {
        final corruptedBytes = Uint8List.fromList([
          // Corrupted OGG header
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid data
        ]);

        final opusFile = OpusAudioFile.fromBytes(corruptedBytes);

        expect(opusFile, isNotNull);
      });

      test('handles empty files gracefully', () {
        final emptyBytes = Uint8List(0);
        final opusFile = OpusAudioFile.fromBytes(emptyBytes);

        expect(opusFile.getAllTags(), isEmpty);
      });

      test('handles audio-only Opus files', () {
        final audioOnlyBytes = Uint8List.fromList([
          // Minimal OGG header without OpusTags
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
          0x13, // Segment table
          // OpusHead packet (minimal)
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
          0x01, 0x02, 0x00, 0x00, 0x80, 0xBB, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);

        final opusFile = OpusAudioFile.fromBytes(audioOnlyBytes);

        expect(opusFile.getAllTags(), isEmpty);
      });
    });

    group('Format Strategy Integration', () {
      test('uses correct precedence order', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        final precedence = opusFile.formatStrategy.precedence;
        expect(precedence, hasLength(1));
        expect(precedence.first, equals((ContainerKind.vorbis, '')));
      });

      test('uses correct fanout targets', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        final fanout = opusFile.formatStrategy.fanout;
        expect(fanout, hasLength(1));
        expect(fanout.first, equals((ContainerKind.vorbis, '')));
      });

      test('detects Opus format correctly', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        expect(opusFile.formatStrategy.canHandle(opusBytes), isTrue);
      });

      test('uses UTF-8 encoding for all text fields', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set tags with Unicode characters
        opusFile.setTag(const TitleTag('Título con acentos'));
        opusFile.setTag(const ArtistTag('Артист на кириллице'));
        opusFile.setTag(const AlbumTag('アルバム名'));

        expect(opusFile.getTag(TagKey.title)?.value, equals('Título con acentos'));
        expect(opusFile.getTag(TagKey.artist)?.value, equals('Артист на кириллице'));
        expect(opusFile.getTag(TagKey.album)?.value, equals('アルバム名'));
      });

      test('supports native multi-value fields', () {
        final opusBytes = _createMinimalOpusWithVorbisComments();
        final opusFile = OpusAudioFile.fromBytes(opusBytes);

        // Set multiple genres (native Vorbis Comments support)
        opusFile.setTag(GenreTag(const ['Electronic', 'Ambient', 'Drone', 'Experimental']));

        final genreTag = opusFile.getTag(TagKey.genre) as GenreTag?;
        expect(genreTag?.value, hasLength(4));
        expect(genreTag?.value, contains('Electronic'));
        expect(genreTag?.value, contains('Ambient'));
        expect(genreTag?.value, contains('Drone'));
        expect(genreTag?.value, contains('Experimental'));
      });
    });
  });
}

/// Creates minimal Opus file bytes with OGG container and OpusHead/OpusTags structure.
///
/// This creates a basic Opus file structure that can be used for testing:
/// - OGG page header with "OggS" signature
/// - OpusHead identification packet
/// - OpusTags comment packet (empty)
/// - Minimal page structure for valid OGG parsing
Uint8List _createMinimalOpusWithVorbisComments() {
  final bytes = <int>[];

  // First OGG page with OpusHead
  bytes.addAll([
    // OGG page header
    0x4F, 0x67, 0x67, 0x53, // "OggS" capture pattern
    0x00, // stream_structure_version
    0x02, // header_type_flag (first page of logical bitstream)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // absolute_granule_position
    0x01, 0x00, 0x00, 0x00, // stream_serial_number
    0x00, 0x00, 0x00, 0x00, // page_sequence_no
    0x00, 0x00, 0x00, 0x00, // page_checksum (simplified for testing)
    0x01, // page_segments
    0x13, // segment_table[0] = 19 bytes for OpusHead
  ]);

  // OpusHead packet (19 bytes)
  bytes.addAll([
    0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
    0x01, // version
    0x02, // channel_count
    0x00, 0x00, // pre_skip (little-endian)
    0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz, little-endian)
    0x00, 0x00, // output_gain
    0x00, // channel_mapping_family
  ]);

  // Second OGG page with OpusTags (empty comment packet)
  bytes.addAll([
    // OGG page header
    0x4F, 0x67, 0x67, 0x53, // "OggS" capture pattern
    0x00, // stream_structure_version
    0x00, // header_type_flag (continuation page)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // absolute_granule_position
    0x01, 0x00, 0x00, 0x00, // stream_serial_number
    0x01, 0x00, 0x00, 0x00, // page_sequence_no
    0x00, 0x00, 0x00, 0x00, // page_checksum (simplified for testing)
    0x01, // page_segments
    0x0C, // segment_table[0] = 12 bytes for minimal OpusTags
  ]);

  // OpusTags packet (minimal empty comment)
  bytes.addAll([
    0x4F, 0x70, 0x75, 0x73, 0x54, 0x61, 0x67, 0x73, // "OpusTags"
    0x00, 0x00, 0x00, 0x00, // vendor_string_length = 0 (little-endian)
    0x00, 0x00, 0x00, 0x00, // user_comment_list_length = 0 (little-endian)
  ]);

  return Uint8List.fromList(bytes);
}

/// Writes a minimal Opus header to the given byte array at the specified offset.
///
/// This is used for creating test files with valid Opus signatures for
/// format detection and basic parsing tests.
void _writeOpusHeader(Uint8List bytes, int offset) {
  if (bytes.length < offset + 27) return;

  // Write OGG page header
  bytes[offset] = 0x4F; // 'O'
  bytes[offset + 1] = 0x67; // 'g'
  bytes[offset + 2] = 0x67; // 'g'
  bytes[offset + 3] = 0x53; // 'S'
  bytes[offset + 4] = 0x00; // version
  bytes[offset + 5] = 0x02; // header_type_flag
  // Skip granule position (8 bytes)
  bytes[offset + 14] = 0x01; // stream_serial_number (low byte)
  // Skip page sequence and checksum
  bytes[offset + 26] = 0x01; // page_segments

  // Write minimal OpusHead if there's space
  if (bytes.length >= offset + 35) {
    final opusHead = [0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64]; // "OpusHead"
    for (int i = 0; i < opusHead.length && offset + 27 + i < bytes.length; i++) {
      bytes[offset + 27 + i] = opusHead[i];
    }
  }
}
