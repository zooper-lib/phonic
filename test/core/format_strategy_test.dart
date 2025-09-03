import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';
import 'package:phonic/src/core/format_strategy.dart';
import 'package:phonic/src/core/media_kind.dart';

/// Test implementation of FormatStrategy for testing purposes.
class TestFormatStrategy extends FormatStrategy {
  final MediaKind _mediaKind;
  final List<(ContainerKind, String)> _precedence;
  final List<(ContainerKind, String)> _fanout;
  final bool Function(Uint8List) _canHandleImpl;
  final MediaKind Function(Uint8List) _detectFormatImpl;

  TestFormatStrategy({
    required MediaKind mediaKind,
    required List<(ContainerKind, String)> precedence,
    required List<(ContainerKind, String)> fanout,
    required bool Function(Uint8List) canHandleImpl,
    required MediaKind Function(Uint8List) detectFormatImpl,
  }) : _mediaKind = mediaKind,
       _precedence = precedence,
       _fanout = fanout,
       _canHandleImpl = canHandleImpl,
       _detectFormatImpl = detectFormatImpl;

  @override
  MediaKind get mediaKind => _mediaKind;

  @override
  List<(ContainerKind, String)> get precedence => _precedence;

  @override
  List<(ContainerKind, String)> get fanout => _fanout;

  @override
  bool canHandle(Uint8List fileBytes) => _canHandleImpl(fileBytes);

  @override
  MediaKind detectFormat(Uint8List fileBytes) => _detectFormatImpl(fileBytes);
}

void main() {
  group('FormatStrategy', () {
    group('abstract interface', () {
      test('should define required properties and methods', () {
        // Create a test implementation
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v1, 'v1'),
          ],
          fanout: [
            (ContainerKind.id3v2, '2.4'),
          ],
          canHandleImpl: (bytes) => bytes.isNotEmpty,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        // Verify properties are accessible
        expect(strategy.mediaKind, equals(MediaKind.mp3));
        expect(strategy.precedence, hasLength(2));
        expect(strategy.fanout, hasLength(1));

        // Verify methods are callable
        final testBytes = Uint8List.fromList([1, 2, 3, 4]);
        expect(strategy.canHandle(testBytes), isTrue);
        expect(strategy.detectFormat(testBytes), equals(MediaKind.mp3));
      });
    });

    group('precedence property', () {
      test('should return container precedence order', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v2, '2.3'),
            (ContainerKind.id3v2, '2.2'),
            (ContainerKind.id3v1, 'v1'),
          ],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final precedence = strategy.precedence;
        expect(precedence, hasLength(4));
        expect(precedence[0], equals((ContainerKind.id3v2, '2.4')));
        expect(precedence[1], equals((ContainerKind.id3v2, '2.3')));
        expect(precedence[2], equals((ContainerKind.id3v2, '2.2')));
        expect(precedence[3], equals((ContainerKind.id3v1, 'v1')));
      });

      test('should handle single container format', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.flac,
          precedence: [
            (ContainerKind.vorbis, ''),
          ],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.flac,
        );

        final precedence = strategy.precedence;
        expect(precedence, hasLength(1));
        expect(precedence[0], equals((ContainerKind.vorbis, '')));
      });

      test('should handle empty precedence list', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        expect(strategy.precedence, isEmpty);
      });
    });

    group('fanout property', () {
      test('should return container fanout targets', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v1, 'v1'),
          ],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final fanout = strategy.fanout;
        expect(fanout, hasLength(2));
        expect(fanout[0], equals((ContainerKind.id3v2, '2.4')));
        expect(fanout[1], equals((ContainerKind.id3v1, 'v1')));
      });

      test('should handle single fanout target', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.flac,
          precedence: [],
          fanout: [
            (ContainerKind.vorbis, ''),
          ],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.flac,
        );

        final fanout = strategy.fanout;
        expect(fanout, hasLength(1));
        expect(fanout[0], equals((ContainerKind.vorbis, '')));
      });

      test('should handle empty fanout list', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        expect(strategy.fanout, isEmpty);
      });
    });

    group('canHandle method', () {
      test('should return true for supported formats', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => bytes.length >= 4 && bytes[0] == 0xFF,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final supportedBytes = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        expect(strategy.canHandle(supportedBytes), isTrue);
      });

      test('should return false for unsupported formats', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => bytes.length >= 4 && bytes[0] == 0xFF,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final unsupportedBytes = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]);
        expect(strategy.canHandle(unsupportedBytes), isFalse);
      });

      test('should handle empty byte arrays gracefully', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => bytes.length >= 4,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final emptyBytes = Uint8List(0);
        expect(strategy.canHandle(emptyBytes), isFalse);
      });

      test('should handle short byte arrays gracefully', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => bytes.length >= 4,
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        final shortBytes = Uint8List.fromList([0xFF, 0xFB]);
        expect(strategy.canHandle(shortBytes), isFalse);
      });
    });

    group('detectFormat method', () {
      test('should return correct MediaKind for detected format', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.flac,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) {
            if (bytes.length >= 4) {
              final signature = String.fromCharCodes(bytes.take(4));
              if (signature == 'fLaC') return MediaKind.flac;
            }
            throw const UnsupportedFormatException('Unknown format');
          },
        );

        final flacBytes = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]); // "fLaC"
        expect(strategy.detectFormat(flacBytes), equals(MediaKind.flac));
      });

      test('should throw UnsupportedFormatException for unknown formats', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) => throw const UnsupportedFormatException('Unknown format'),
        );

        final unknownBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        expect(
          () => strategy.detectFormat(unknownBytes),
          throwsA(isA<UnsupportedFormatException>()),
        );
      });

      test('should handle different format variations', () {
        final strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp4,
          precedence: [],
          fanout: [],
          canHandleImpl: (bytes) => true,
          detectFormatImpl: (bytes) {
            // Simplified MP4/M4A detection
            if (bytes.length >= 8) {
              final ftyp = String.fromCharCodes(bytes.skip(4).take(4));
              if (ftyp == 'ftyp') {
                final brand = String.fromCharCodes(bytes.skip(8).take(4));
                if (brand == 'M4A ') return MediaKind.m4a;
                if (brand == 'mp41') return MediaKind.mp4;
              }
            }
            throw const UnsupportedFormatException('Not MP4 format');
          },
        );

        final m4aBytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x4D, 0x34, 0x41, 0x20, // "M4A "
        ]);
        expect(strategy.detectFormat(m4aBytes), equals(MediaKind.m4a));

        final mp4Bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x6D, 0x70, 0x34, 0x31, // "mp41"
        ]);
        expect(strategy.detectFormat(mp4Bytes), equals(MediaKind.mp4));
      });
    });

    group('mediaKind property', () {
      test('should return the correct MediaKind for each format', () {
        for (final kind in MediaKind.values) {
          final strategy = TestFormatStrategy(
            mediaKind: kind,
            precedence: [],
            fanout: [],
            canHandleImpl: (bytes) => true,
            detectFormatImpl: (bytes) => kind,
          );

          expect(strategy.mediaKind, equals(kind));
        }
      });
    });

    group('integration scenarios', () {
      test('should support typical MP3 strategy configuration', () {
        final mp3Strategy = TestFormatStrategy(
          mediaKind: MediaKind.mp3,
          precedence: [
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v2, '2.3'),
            (ContainerKind.id3v2, '2.2'),
            (ContainerKind.id3v1, 'v1'),
          ],
          fanout: [
            (ContainerKind.id3v2, '2.4'),
            (ContainerKind.id3v1, 'v1'),
          ],
          canHandleImpl: (bytes) {
            // Check for ID3v2 header or MP3 frame sync
            if (bytes.length >= 3) {
              final id3Header = String.fromCharCodes(bytes.take(3));
              if (id3Header == 'ID3') return true;
            }
            if (bytes.length >= 2) {
              final frameSync = (bytes[0] << 8) | bytes[1];
              if ((frameSync & 0xFFE0) == 0xFFE0) return true;
            }
            return false;
          },
          detectFormatImpl: (bytes) => MediaKind.mp3,
        );

        expect(mp3Strategy.mediaKind, equals(MediaKind.mp3));
        expect(mp3Strategy.precedence, hasLength(4));
        expect(mp3Strategy.fanout, hasLength(2));

        // Test ID3v2 detection
        final id3Bytes = Uint8List.fromList([0x49, 0x44, 0x33]); // "ID3"
        expect(mp3Strategy.canHandle(id3Bytes), isTrue);

        // Test MP3 frame sync detection
        final mp3Bytes = Uint8List.fromList([0xFF, 0xFB]);
        expect(mp3Strategy.canHandle(mp3Bytes), isTrue);
      });

      test('should support typical FLAC strategy configuration', () {
        final flacStrategy = TestFormatStrategy(
          mediaKind: MediaKind.flac,
          precedence: [
            (ContainerKind.vorbis, ''),
          ],
          fanout: [
            (ContainerKind.vorbis, ''),
          ],
          canHandleImpl: (bytes) {
            if (bytes.length >= 4) {
              final signature = String.fromCharCodes(bytes.take(4));
              return signature == 'fLaC';
            }
            return false;
          },
          detectFormatImpl: (bytes) => MediaKind.flac,
        );

        expect(flacStrategy.mediaKind, equals(MediaKind.flac));
        expect(flacStrategy.precedence, hasLength(1));
        expect(flacStrategy.fanout, hasLength(1));

        final flacBytes = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]); // "fLaC"
        expect(flacStrategy.canHandle(flacBytes), isTrue);
        expect(flacStrategy.detectFormat(flacBytes), equals(MediaKind.flac));
      });

      test('should support typical OGG strategy configuration', () {
        final oggStrategy = TestFormatStrategy(
          mediaKind: MediaKind.ogg,
          precedence: [
            (ContainerKind.vorbis, ''),
          ],
          fanout: [
            (ContainerKind.vorbis, ''),
          ],
          canHandleImpl: (bytes) {
            if (bytes.length >= 4) {
              final signature = String.fromCharCodes(bytes.take(4));
              return signature == 'OggS';
            }
            return false;
          },
          detectFormatImpl: (bytes) => MediaKind.ogg,
        );

        expect(oggStrategy.mediaKind, equals(MediaKind.ogg));
        expect(oggStrategy.precedence, hasLength(1));
        expect(oggStrategy.fanout, hasLength(1));

        final oggBytes = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53]); // "OggS"
        expect(oggStrategy.canHandle(oggBytes), isTrue);
        expect(oggStrategy.detectFormat(oggBytes), equals(MediaKind.ogg));
      });
    });
  });
}
