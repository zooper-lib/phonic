import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/media_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/vorbis/ogg_audio_file.dart';

void main() {
  group('OggAudioFile Integration', () {
    test('can be imported and instantiated from main library', () {
      // Create minimal OGG bytes
      final oggBytes = Uint8List.fromList([
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x1E, // Segment size
        // Vorbis identification packet
        0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // packet type + "vorbis"
        0x00, 0x00, 0x00, 0x00, 0x02, 0x44, 0xAC, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xB0, 0x01,
      ]);

      // Should be able to create OggAudioFile from main library export
      final oggFile = OggAudioFile.fromBytes(oggBytes);

      expect(oggFile, isNotNull);
      expect(oggFile.formatStrategy.mediaKind, equals(MediaKind.ogg));
    });

    test('integrates with format strategy system', () {
      final oggBytes = Uint8List.fromList([
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x1E, // Segment size
        // Vorbis identification packet
        0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // packet type + "vorbis"
        0x00, 0x00, 0x00, 0x00, 0x02, 0x44, 0xAC, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xB0, 0x01,
      ]);

      final oggFile = OggAudioFile.fromBytes(oggBytes);

      // Verify format strategy configuration
      final strategy = oggFile.formatStrategy;
      expect(strategy.mediaKind, equals(MediaKind.ogg));
      expect(strategy.precedence, hasLength(1));
      expect(strategy.precedence.first.$1, equals(ContainerKind.vorbis));
      expect(strategy.fanout, hasLength(1));
      expect(strategy.fanout.first.$1, equals(ContainerKind.vorbis));

      // Verify codec registry configuration
      final vorbisCodec = oggFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
      expect(vorbisCodec, isNotNull);

      final vorbisLocator = oggFile.codecRegistry.findLocator(ContainerKind.vorbis);
      expect(vorbisLocator, isNotNull);
    });

    test('supports basic tag operations', () {
      final oggBytes = Uint8List.fromList([
        0x4F, 0x67, 0x67, 0x53, // "OggS" signature
        0x00, 0x02, // Version and header type
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
        0x01, 0x00, 0x00, 0x00, // Serial number
        0x00, 0x00, 0x00, 0x00, // Page sequence number
        0x00, 0x00, 0x00, 0x00, // Checksum
        0x01, // Number of segments
        0x1E, // Segment size
        // Vorbis identification packet
        0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // packet type + "vorbis"
        0x00, 0x00, 0x00, 0x00, 0x02, 0x44, 0xAC, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xB0, 0x01,
      ]);

      final oggFile = OggAudioFile.fromBytes(oggBytes);

      // Should support setting and getting tags
      oggFile.setTag(const TitleTag('Test OGG Title'));
      oggFile.setTag(const ArtistTag('Test OGG Artist'));
      oggFile.setTag(GenreTag(const ['Electronic', 'Ambient']));

      expect(oggFile.isDirty, isTrue);

      final titleTag = oggFile.getTag(TagKey.title) as TitleTag?;
      final artistTag = oggFile.getTag(TagKey.artist) as ArtistTag?;
      final genreTags = oggFile.getTags(TagKey.genre);

      expect(titleTag?.value, equals('Test OGG Title'));
      expect(artistTag?.value, equals('Test OGG Artist'));
      expect(genreTags, hasLength(1));

      final genreTag = genreTags.first as GenreTag;
      expect(genreTag.value, equals(['Electronic', 'Ambient']));
    });
  });
}
