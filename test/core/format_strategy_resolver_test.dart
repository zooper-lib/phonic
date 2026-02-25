import 'dart:typed_data';

import 'package:phonic/src/core/format_strategy_resolver.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/formats/flac/flac_format_strategy.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';
import 'package:phonic/src/formats/mp4/mp4_format_strategy.dart';
import 'package:phonic/src/formats/vorbis/ogg_format_strategy.dart';
import 'package:phonic/src/formats/vorbis/opus_format_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('FormatStrategyResolver', () {
    group('resolve', () {
      test('resolves MP3 when bytes contain ID3 header', () {
        // Arrange: an ID3v2 header is a strong MP3 indicator.
        final Uint8List mp3Bytes = Uint8List.fromList(<int>[
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // version 2.4
          0x00, // flags
          0x00, 0x00, 0x00, 0x00, // synchsafe size (0)
        ]);

        // Act.
        final strategy = FormatStrategyResolver.resolve(mp3Bytes);

        // Assert: we should pick the MP3 strategy based on canHandle().
        expect(strategy, isA<Mp3FormatStrategy>());
      });

      test('resolves FLAC when bytes start with fLaC signature', () {
        // Arrange: FLAC signature is unambiguous.
        final Uint8List flacBytes = Uint8List.fromList(<int>[
          0x66, 0x4C, 0x61, 0x43, // "fLaC"
          0x00, 0x00, 0x00, 0x00, // padding
        ]);

        // Act.
        final strategy = FormatStrategyResolver.resolve(flacBytes);

        // Assert: we should pick the FLAC strategy based on canHandle().
        expect(strategy, isA<FlacFormatStrategy>());
      });

      test('resolves MP4 when bytes contain a valid ftyp box', () {
        // Arrange: minimal MP4 ftyp box where major brand is known.
        // The first box size must be >= 16 and <= bytes.length.
        final Uint8List mp4Bytes = Uint8List.fromList(<int>[
          0x00, 0x00, 0x00, 0x10, // size: 16
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // major brand: "isom"
          0x00, 0x00, 0x00, 0x00, // minor version
        ]);

        // Act.
        final strategy = FormatStrategyResolver.resolve(mp4Bytes);

        // Assert: we should pick the MP4 strategy based on canHandle().
        expect(strategy, isA<Mp4FormatStrategy>());
      });

      test('resolves OGG Vorbis when bytes contain OggS and vorbis header', () {
        // Arrange: minimal OGG page with 1 segment and vorbis identification.
        final Uint8List oggVorbisBytes = Uint8List.fromList(<int>[
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          // bytes 4..25: not used by detection, keep as zeros
          ...List<int>.filled(22, 0x00),
          0x01, // byte 26: page_segments = 1
          0x1E, // byte 27: segment_table[0]
          0x01, // packet type: identification
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
        ]);

        // Act.
        final strategy = FormatStrategyResolver.resolve(oggVorbisBytes);

        // Assert: we must select OGG Vorbis, not Opus, because codec ID differs.
        expect(strategy, isA<OggFormatStrategy>());
      });

      test('resolves Opus when bytes contain OggS and OpusHead header', () {
        // Arrange: minimal OGG page with 1 segment and OpusHead identification.
        final Uint8List opusBytes = Uint8List.fromList(<int>[
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          // bytes 4..25: not used by detection, keep as zeros
          ...List<int>.filled(22, 0x00),
          0x01, // byte 26: page_segments = 1
          0x13, // byte 27: segment_table[0]
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
        ]);

        // Act.
        final strategy = FormatStrategyResolver.resolve(opusBytes);

        // Assert: we must select Opus, not OGG Vorbis, because codec ID differs.
        expect(strategy, isA<OpusFormatStrategy>());
      });

      test('uses filename extension as a hint but still prefers real bytes', () {
        // Arrange: MP3 bytes, but a misleading filename extension.
        final Uint8List mp3Bytes = Uint8List.fromList(<int>[
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00,
          0x00,
          0x00, 0x00, 0x00, 0x00,
        ]);

        // Act: even if extension suggests FLAC, the bytes should win.
        final strategy = FormatStrategyResolver.resolve(
          mp3Bytes,
          filename: 'misleading.flac',
        );

        // Assert: correct detection should not be overridden by the extension.
        expect(strategy, isA<Mp3FormatStrategy>());
      });

      test('throws UnsupportedFormatException when no strategy can handle bytes', () {
        // Arrange: random bytes that should not match any supported signature.
        final Uint8List unknownBytes = Uint8List.fromList(<int>[
          0x00,
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
        ]);

        // Act + Assert: failing early prevents silent mis-detections.
        expect(
          () => FormatStrategyResolver.resolve(unknownBytes, filename: 'file.xyz'),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });
    });
  });
}
