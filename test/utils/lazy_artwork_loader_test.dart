import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('LazyArtworkLoader', () {
    late Uint8List containerBytes;

    setUp(() {
      // Create test container bytes with known pattern
      // Simulates a container with header, metadata, and artwork data
      containerBytes = Uint8List.fromList([
        // Header bytes (0-9)
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
        // Metadata bytes (10-19)
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
        // Artwork data bytes (20-29)
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
        // Footer bytes (30-39)
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
      ]);
    });

    group('constructor', () {
      test('creates instance with valid parameters', () {
        final loader = LazyArtworkLoader(containerBytes, 20, 10);

        expect(loader.offset, equals(20));
        expect(loader.length, equals(10));
      });

      test('accepts zero offset', () {
        final loader = LazyArtworkLoader(containerBytes, 0, 10);

        expect(loader.offset, equals(0));
        expect(loader.length, equals(10));
      });

      test('accepts offset at container boundary', () {
        final loader = LazyArtworkLoader(containerBytes, 39, 1);

        expect(loader.offset, equals(39));
        expect(loader.length, equals(1));
      });

      test('accepts full container as artwork', () {
        final loader = LazyArtworkLoader(containerBytes, 0, containerBytes.length);

        expect(loader.offset, equals(0));
        expect(loader.length, equals(containerBytes.length));
      });

      test('throws ArgumentError for negative offset', () {
        expect(
          () => LazyArtworkLoader(containerBytes, -1, 10),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.message, 'message', contains('Offset must be non-negative'))
                .having((e) => e.invalidValue, 'invalidValue', equals(-1))
                .having((e) => e.name, 'name', equals('offset')),
          ),
        );
      });

      test('throws ArgumentError for zero length', () {
        expect(
          () => LazyArtworkLoader(containerBytes, 10, 0),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.message, 'message', contains('Length must be positive'))
                .having((e) => e.invalidValue, 'invalidValue', equals(0))
                .having((e) => e.name, 'name', equals('length')),
          ),
        );
      });

      test('throws ArgumentError for negative length', () {
        expect(
          () => LazyArtworkLoader(containerBytes, 10, -5),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.message, 'message', contains('Length must be positive'))
                .having((e) => e.invalidValue, 'invalidValue', equals(-5))
                .having((e) => e.name, 'name', equals('length')),
          ),
        );
      });

      test('throws RangeError when offset + length exceeds container size', () {
        expect(
          () => LazyArtworkLoader(containerBytes, 35, 10), // 35 + 10 = 45 > 40
          throwsA(
            isA<RangeError>()
                .having((e) => e.message, 'message', contains('Artwork data bounds exceed container size'))
                .having((e) => e.message, 'message', contains('offset: 35'))
                .having((e) => e.message, 'message', contains('length: 10'))
                .having((e) => e.message, 'message', contains('container: 40')),
          ),
        );
      });

      test('throws RangeError when offset equals container size', () {
        expect(
          () => LazyArtworkLoader(containerBytes, containerBytes.length, 1),
          throwsA(isA<RangeError>()),
        );
      });

      test('throws RangeError when offset exceeds container size', () {
        expect(
          () => LazyArtworkLoader(containerBytes, containerBytes.length + 1, 1),
          throwsA(isA<RangeError>()),
        );
      });
    });

    group('load method', () {
      test('extracts correct artwork data from middle of container', () async {
        final loader = LazyArtworkLoader(containerBytes, 20, 10);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(10));
        expect(
          artworkData,
          equals(Uint8List.fromList([0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29])),
        );
      });

      test('extracts artwork data from beginning of container', () async {
        final loader = LazyArtworkLoader(containerBytes, 0, 5);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(5));
        expect(
          artworkData,
          equals(Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04])),
        );
      });

      test('extracts artwork data from end of container', () async {
        final loader = LazyArtworkLoader(containerBytes, 35, 5);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(5));
        expect(
          artworkData,
          equals(Uint8List.fromList([0x35, 0x36, 0x37, 0x38, 0x39])),
        );
      });

      test('extracts single byte artwork', () async {
        final loader = LazyArtworkLoader(containerBytes, 25, 1);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(1));
        expect(artworkData, equals(Uint8List.fromList([0x25])));
      });

      test('extracts entire container as artwork', () async {
        final loader = LazyArtworkLoader(containerBytes, 0, containerBytes.length);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(containerBytes.length));
        expect(artworkData, equals(containerBytes));
      });

      test('returns independent copy of data', () async {
        final loader = LazyArtworkLoader(containerBytes, 20, 5);

        final artworkData1 = await loader.load();
        final artworkData2 = await loader.load();

        // Should be equal but not identical objects
        expect(artworkData1, equals(artworkData2));
        expect(identical(artworkData1, artworkData2), isFalse);

        // Modifying one should not affect the other
        artworkData1[0] = 0xFF;
        expect(artworkData1[0], equals(0xFF));
        expect(artworkData2[0], equals(0x20)); // Original value
      });

      test('multiple calls return consistent data', () async {
        final loader = LazyArtworkLoader(containerBytes, 15, 8);

        final artworkData1 = await loader.load();
        final artworkData2 = await loader.load();
        final artworkData3 = await loader.load();

        expect(artworkData1, equals(artworkData2));
        expect(artworkData2, equals(artworkData3));
        expect(
          artworkData1,
          equals(Uint8List.fromList([0x15, 0x16, 0x17, 0x18, 0x19, 0x20, 0x21, 0x22])),
        );
      });

      test('works with empty container bytes', () async {
        final emptyContainer = Uint8List(0);

        // Should not be able to create loader with empty container
        expect(
          () => LazyArtworkLoader(emptyContainer, 0, 1),
          throwsA(isA<RangeError>()),
        );
      });

      test('works with large container bytes', () async {
        // Create a large container (1MB)
        final largeContainer = Uint8List(1024 * 1024);
        for (int i = 0; i < largeContainer.length; i++) {
          largeContainer[i] = i % 256;
        }

        final loader = LazyArtworkLoader(largeContainer, 500000, 1000);
        final artworkData = await loader.load();

        expect(artworkData.length, equals(1000));
        expect(artworkData[0], equals(500000 % 256));
        expect(artworkData[999], equals((500000 + 999) % 256));
      });
    });

    group('getters', () {
      test('offset getter returns correct value', () {
        final loader = LazyArtworkLoader(containerBytes, 15, 10);
        expect(loader.offset, equals(15));
      });

      test('length getter returns correct value', () {
        final loader = LazyArtworkLoader(containerBytes, 15, 10);
        expect(loader.length, equals(10));
      });

      test('getters are read-only', () {
        final loader = LazyArtworkLoader(containerBytes, 15, 10);

        // These should be compile-time errors, but we can verify the getters exist
        expect(loader.offset, isA<int>());
        expect(loader.length, isA<int>());
      });
    });

    group('toString', () {
      test('includes offset, length, and container size', () {
        final loader = LazyArtworkLoader(containerBytes, 20, 10);

        final str = loader.toString();

        expect(str, contains('LazyArtworkLoader'));
        expect(str, contains('offset: 20'));
        expect(str, contains('length: 10'));
        expect(str, contains('containerSize: ${containerBytes.length}'));
      });

      test('handles zero offset', () {
        final loader = LazyArtworkLoader(containerBytes, 0, 5);

        final str = loader.toString();

        expect(str, contains('offset: 0'));
        expect(str, contains('length: 5'));
      });

      test('handles large values', () {
        final largeContainer = Uint8List(1000000);
        final loader = LazyArtworkLoader(largeContainer, 500000, 100000);

        final str = loader.toString();

        expect(str, contains('offset: 500000'));
        expect(str, contains('length: 100000'));
        expect(str, contains('containerSize: 1000000'));
      });
    });

    group('integration with ArtworkData', () {
      test('works as dataLoader for ArtworkData', () async {
        final loader = LazyArtworkLoader(containerBytes, 20, 10);
        final artworkData = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          description: 'Test artwork',
          dataLoader: () => loader.load(),
        );

        final imageData = await artworkData.data;

        expect(imageData.length, equals(10));
        expect(
          imageData,
          equals(Uint8List.fromList([0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29])),
        );
      });

      test('supports multiple ArtworkData instances with same loader', () async {
        final loader = LazyArtworkLoader(containerBytes, 25, 5);

        final artwork1 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () => loader.load(),
        );

        final artwork2 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () => loader.load(),
        );

        final data1 = await artwork1.data;
        final data2 = await artwork2.data;

        expect(data1, equals(data2));
        expect(
          data1,
          equals(Uint8List.fromList([0x25, 0x26, 0x27, 0x28, 0x29])),
        );
      });

      test('works with different loaders for different artwork', () async {
        final loader1 = LazyArtworkLoader(containerBytes, 10, 5);
        final loader2 = LazyArtworkLoader(containerBytes, 30, 5);

        final artwork1 = ArtworkData(
          mimeType: MimeType.jpeg.standardName,
          type: ArtworkType.frontCover,
          dataLoader: () => loader1.load(),
        );

        final artwork2 = ArtworkData(
          mimeType: MimeType.png.standardName,
          type: ArtworkType.backCover,
          dataLoader: () => loader2.load(),
        );

        final data1 = await artwork1.data;
        final data2 = await artwork2.data;

        expect(data1, isNot(equals(data2)));
        expect(
          data1,
          equals(Uint8List.fromList([0x10, 0x11, 0x12, 0x13, 0x14])),
        );
        expect(
          data2,
          equals(Uint8List.fromList([0x30, 0x31, 0x32, 0x33, 0x34])),
        );
      });
    });

    group('edge cases and error conditions', () {
      test('handles container bytes modification after construction', () async {
        final mutableContainer = Uint8List.fromList([1, 2, 3, 4, 5]);
        final loader = LazyArtworkLoader(mutableContainer, 1, 3);

        // Modify container after loader creation
        mutableContainer[2] = 99;

        final artworkData = await loader.load();

        // Should reflect the modified container
        expect(artworkData, equals(Uint8List.fromList([2, 99, 4])));
      });

      test('handles very small artwork data', () async {
        final smallContainer = Uint8List.fromList([42]);
        final loader = LazyArtworkLoader(smallContainer, 0, 1);

        final artworkData = await loader.load();

        expect(artworkData.length, equals(1));
        expect(artworkData[0], equals(42));
      });

      test('preserves original container bytes', () async {
        final originalContainer = Uint8List.fromList([1, 2, 3, 4, 5]);
        final containerCopy = Uint8List.fromList(originalContainer);
        final loader = LazyArtworkLoader(containerCopy, 1, 3);

        final artworkData = await loader.load();

        // Modify the loaded artwork data
        artworkData[0] = 99;

        // Original container should be unchanged
        expect(containerCopy, equals(originalContainer));
      });
    });
  });
}
