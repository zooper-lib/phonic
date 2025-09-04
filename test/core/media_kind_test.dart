import 'package:phonic/src/core/media_kind.dart';
import 'package:test/test.dart';

void main() {
  group('MediaKind', () {
    test('should have all expected values', () {
      const expectedValues = [
        MediaKind.mp3,
        MediaKind.flac,
        MediaKind.ogg,
        MediaKind.opus,
        MediaKind.m4a,
        MediaKind.mp4,
      ];

      expect(MediaKind.values, equals(expectedValues));
    });

    test('should have correct enum names', () {
      expect(MediaKind.mp3.name, equals('mp3'));
      expect(MediaKind.flac.name, equals('flac'));
      expect(MediaKind.ogg.name, equals('ogg'));
      expect(MediaKind.opus.name, equals('opus'));
      expect(MediaKind.m4a.name, equals('m4a'));
      expect(MediaKind.mp4.name, equals('mp4'));
    });

    test('should be usable in switch statements', () {
      String getDescription(MediaKind kind) {
        switch (kind) {
          case MediaKind.mp3:
            return 'MPEG-1 Audio Layer III';
          case MediaKind.flac:
            return 'Free Lossless Audio Codec';
          case MediaKind.ogg:
            return 'OGG Vorbis';
          case MediaKind.opus:
            return 'Opus';
          case MediaKind.m4a:
            return 'MPEG-4 Audio';
          case MediaKind.mp4:
            return 'MPEG-4 Video';
        }
      }

      expect(getDescription(MediaKind.mp3), equals('MPEG-1 Audio Layer III'));
      expect(getDescription(MediaKind.flac), equals('Free Lossless Audio Codec'));
      expect(getDescription(MediaKind.ogg), equals('OGG Vorbis'));
      expect(getDescription(MediaKind.opus), equals('Opus'));
      expect(getDescription(MediaKind.m4a), equals('MPEG-4 Audio'));
      expect(getDescription(MediaKind.mp4), equals('MPEG-4 Video'));
    });

    test('should support equality comparison', () {
      expect(MediaKind.mp3, equals(MediaKind.mp3));
      expect(MediaKind.flac, equals(MediaKind.flac));
      expect(MediaKind.mp3, isNot(equals(MediaKind.flac)));
    });

    test('should support toString', () {
      expect(MediaKind.mp3.toString(), equals('MediaKind.mp3'));
      expect(MediaKind.flac.toString(), equals('MediaKind.flac'));
      expect(MediaKind.ogg.toString(), equals('MediaKind.ogg'));
      expect(MediaKind.opus.toString(), equals('MediaKind.opus'));
      expect(MediaKind.m4a.toString(), equals('MediaKind.m4a'));
      expect(MediaKind.mp4.toString(), equals('MediaKind.mp4'));
    });
  });
}
