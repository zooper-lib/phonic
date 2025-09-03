import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/vorbis/ogg_format_strategy.dart';
import 'package:phonic/src/formats/vorbis/opus_audio_file.dart';

void main() {
  group('OpusAudioFile Integration', () {
    test('can be imported and instantiated from main library', () {
      // Create minimal Opus bytes
      final opusBytes = Uint8List.fromList([
        // First OGG page with OpusHead
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type (first page)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x13, // Segment size (19 bytes for OpusHead)
        // OpusHead packet
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        0x01, // version
        0x02, // channel_count
        0x00, 0x00, // pre_skip
        0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz)
        0x00, 0x00, // output_gain
        0x00, // channel_mapping_family
      ]);

      // Should be able to create OpusAudioFile from main library export
      final opusFile = OpusAudioFile.fromBytes(opusBytes);

      expect(opusFile, isNotNull);
      expect(opusFile.formatStrategy.mediaKind, equals(MediaKind.opus));
    });

    test('integrates with format strategy system', () {
      final opusBytes = Uint8List.fromList([
        // First OGG page with OpusHead
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type (first page)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x13, // Segment size (19 bytes for OpusHead)
        // OpusHead packet
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        0x01, // version
        0x02, // channel_count
        0x00, 0x00, // pre_skip
        0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz)
        0x00, 0x00, // output_gain
        0x00, // channel_mapping_family
      ]);

      final opusFile = OpusAudioFile.fromBytes(opusBytes);

      // Verify format strategy configuration
      final strategy = opusFile.formatStrategy;
      expect(strategy.mediaKind, equals(MediaKind.opus));
      expect(strategy.precedence, hasLength(1));
      expect(strategy.precedence.first.$1, equals(ContainerKind.vorbis));
      expect(strategy.fanout, hasLength(1));
      expect(strategy.fanout.first.$1, equals(ContainerKind.vorbis));

      // Verify codec registry configuration
      final vorbisCodec = opusFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
      expect(vorbisCodec, isNotNull);

      final vorbisLocator = opusFile.codecRegistry.findLocator(ContainerKind.vorbis);
      expect(vorbisLocator, isNotNull);
    });

    test('supports basic tag operations', () {
      final opusBytes = Uint8List.fromList([
        // First OGG page with OpusHead
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type (first page)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x13, // Segment size (19 bytes for OpusHead)
        // OpusHead packet
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        0x01, // version
        0x02, // channel_count
        0x00, 0x00, // pre_skip
        0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz)
        0x00, 0x00, // output_gain
        0x00, // channel_mapping_family
      ]);

      final opusFile = OpusAudioFile.fromBytes(opusBytes);

      // Should support setting and getting tags
      opusFile.setTag(const TitleTag('Test Opus Title'));
      opusFile.setTag(const ArtistTag('Test Opus Artist'));
      opusFile.setTag(GenreTag(const ['Electronic', 'Ambient']));

      expect(opusFile.isDirty, isTrue);

      final titleTag = opusFile.getTag(TagKey.title) as TitleTag?;
      final artistTag = opusFile.getTag(TagKey.artist) as ArtistTag?;
      final genreTags = opusFile.getTags(TagKey.genre);

      expect(titleTag?.value, equals('Test Opus Title'));
      expect(artistTag?.value, equals('Test Opus Artist'));
      expect(genreTags, hasLength(1));

      final genreTag = genreTags.first as GenreTag;
      expect(genreTag.value, equals(['Electronic', 'Ambient']));
    });

    test('uses Opus-specific format detection', () {
      final opusBytes = Uint8List.fromList([
        // First OGG page with OpusHead
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type (first page)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x13, // Segment size (19 bytes for OpusHead)
        // OpusHead packet
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        0x01, // version
        0x02, // channel_count
        0x00, 0x00, // pre_skip
        0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz)
        0x00, 0x00, // output_gain
        0x00, // channel_mapping_family
      ]);

      final opusFile = OpusAudioFile.fromBytes(opusBytes);

      // Verify Opus-specific format detection
      expect(opusFile.formatStrategy.canHandle(opusBytes), isTrue);
      expect(opusFile.formatStrategy.detectFormat(opusBytes), equals(MediaKind.opus));

      // Verify it's different from OGG Vorbis detection
      final oggStrategy = const OggFormatStrategy();
      expect(oggStrategy.canHandle(opusBytes), isFalse); // Should not handle Opus files
    });

    test('supports Vorbis Comments metadata like OGG Vorbis', () {
      final opusBytes = Uint8List.fromList([
        // First OGG page with OpusHead
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type (first page)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x13, // Segment size (19 bytes for OpusHead)
        // OpusHead packet
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        0x01, // version
        0x02, // channel_count
        0x00, 0x00, // pre_skip
        0x80, 0xBB, 0x00, 0x00, // input_sample_rate (48000 Hz)
        0x00, 0x00, // output_gain
        0x00, // channel_mapping_family
      ]);

      final opusFile = OpusAudioFile.fromBytes(opusBytes);

      // Should use the same Vorbis Comments codec as OGG Vorbis
      final vorbisCodec = opusFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
      expect(vorbisCodec, isNotNull);
      expect(vorbisCodec!.containerKind, equals(ContainerKind.vorbis));

      // Should use the same OGG locator for comment packet extraction
      final vorbisLocator = opusFile.codecRegistry.findLocator(ContainerKind.vorbis);
      expect(vorbisLocator, isNotNull);
      expect(vorbisLocator!.containerKind, equals(ContainerKind.vorbis));

      // Should support UTF-8 encoding like Vorbis Comments
      opusFile.setTag(const TitleTag('Título con acentos'));
      opusFile.setTag(const ArtistTag('Артист на кириллице'));

      expect(opusFile.getTag(TagKey.title)?.value, equals('Título con acentos'));
      expect(opusFile.getTag(TagKey.artist)?.value, equals('Артист на кириллице'));
    });
  });
}
