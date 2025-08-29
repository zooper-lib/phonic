import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('ArtworkData', () {
    test('creates instance with required parameters', () {
      final artwork = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        dataLoader: () async => Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(artwork.mimeType, equals('image/jpeg'));
      expect(artwork.type, equals(ArtworkType.frontCover));
      expect(artwork.description, isNull);
    });

    test('creates instance with optional description', () {
      final artwork = ArtworkData(
        mimeType: 'image/png',
        type: ArtworkType.backCover,
        description: 'Album back cover',
        dataLoader: () async => Uint8List.fromList([5, 6, 7, 8]),
      );

      expect(artwork.mimeType, equals('image/png'));
      expect(artwork.type, equals(ArtworkType.backCover));
      expect(artwork.description, equals('Album back cover'));
    });

    test('loads data lazily through data getter', () async {
      final testData = Uint8List.fromList([10, 20, 30, 40, 50]);
      final artwork = ArtworkData(
        mimeType: 'image/gif',
        type: ArtworkType.artist,
        dataLoader: () async => testData,
      );

      final loadedData = await artwork.data;
      expect(loadedData, equals(testData));
    });

    test('equality comparison excludes data loader', () {
      final loader1 = () async => Uint8List.fromList([1, 2, 3]);
      final loader2 = () async => Uint8List.fromList([4, 5, 6]);

      final artwork1 = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        description: 'Cover',
        dataLoader: loader1,
      );

      final artwork2 = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        description: 'Cover',
        dataLoader: loader2,
      );

      expect(artwork1, equals(artwork2));
      expect(artwork1.hashCode, equals(artwork2.hashCode));
    });

    test('equality comparison includes all metadata fields', () {
      final loader = () async => Uint8List.fromList([1, 2, 3]);

      final artwork1 = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        description: 'Cover 1',
        dataLoader: loader,
      );

      final artwork2 = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        description: 'Cover 2',
        dataLoader: loader,
      );

      final artwork3 = ArtworkData(
        mimeType: 'image/png',
        type: ArtworkType.frontCover,
        description: 'Cover 1',
        dataLoader: loader,
      );

      final artwork4 = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.backCover,
        description: 'Cover 1',
        dataLoader: loader,
      );

      expect(artwork1, isNot(equals(artwork2))); // Different description
      expect(artwork1, isNot(equals(artwork3))); // Different MIME type
      expect(artwork1, isNot(equals(artwork4))); // Different type
    });

    test('toString includes metadata but not loader', () {
      final artwork = ArtworkData(
        mimeType: 'image/webp',
        type: ArtworkType.illustration,
        description: 'Concept art',
        dataLoader: () async => Uint8List.fromList([]),
      );

      final str = artwork.toString();
      expect(str, contains('image/webp'));
      expect(str, contains('ArtworkType.illustration'));
      expect(str, contains('Concept art'));
      expect(str, isNot(contains('dataLoader')));
    });

    test('toString handles null description', () {
      final artwork = ArtworkData(
        mimeType: 'image/bmp',
        type: ArtworkType.media,
        dataLoader: () async => Uint8List.fromList([]),
      );

      final str = artwork.toString();
      expect(str, contains('image/bmp'));
      expect(str, contains('ArtworkType.media'));
      expect(str, contains('null'));
    });

    test('data loader can be called multiple times', () async {
      var callCount = 0;
      final artwork = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        dataLoader: () async {
          callCount++;
          return Uint8List.fromList([callCount]);
        },
      );

      final data1 = await artwork.data;
      final data2 = await artwork.data;

      expect(callCount, equals(2));
      expect(data1, equals(Uint8List.fromList([1])));
      expect(data2, equals(Uint8List.fromList([2])));
    });

    test('data loader exceptions are propagated', () async {
      final artwork = ArtworkData(
        mimeType: 'image/jpeg',
        type: ArtworkType.frontCover,
        dataLoader: () async => throw Exception('Loading failed'),
      );

      expect(
        () async => await artwork.data,
        throwsA(isA<Exception>()),
      );
    });
  });
}
