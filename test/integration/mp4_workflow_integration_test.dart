import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Integration tests for MP4/M4A audio file workflow.
///
/// Tests the complete load → modify → save workflow for MP4 container files.
/// MP4 files use iTunes-style metadata atoms and have different constraints
/// compared to ID3v2 tags.
void main() {
  group('MP4 Workflow Integration Tests', () {
    late List<String> mp4FixtureFiles;

    setUpAll(() async {
      mp4FixtureFiles = await _discoverMp4FixtureFiles();
    });

    group('Basic MP4 Operations', () {
      test('Load and modify MP4 metadata', () async {
        if (mp4FixtureFiles.isEmpty) return;

        final audioFile = await Phonic.fromFile(mp4FixtureFiles.first);

        try {
          audioFile.setTag(const TitleTag('MP4 Test Title'));
          audioFile.setTag(const ArtistTag('MP4 Test Artist'));
          audioFile.setTag(const AlbumTag('MP4 Test Album'));
          audioFile.setTag(YearTag(2024));
          audioFile.setTag(TrackNumberTag(1));

          expect(audioFile.isDirty, isTrue);
          expect(audioFile.getTag(TagKey.title)?.value, equals('MP4 Test Title'));
          expect(audioFile.getTag(TagKey.artist)?.value, equals('MP4 Test Artist'));

          final encodedBytes = await audioFile.encode(
            const EncodingOptions(
              strategy: EncodingStrategy.preserveExisting,
              validationLevel: ValidationLevel.basic,
            ),
          );

          expect(encodedBytes.isNotEmpty, isTrue);
        } finally {
          audioFile.dispose();
        }
      });

      test('MP4 multi-valued genre tags', () async {
        if (mp4FixtureFiles.isEmpty) return;

        final audioFile = await Phonic.fromFile(mp4FixtureFiles.first);

        try {
          audioFile.setTag(GenreTag(const ['Electronic', 'Ambient', 'Test']));

          final genres = audioFile.getTags(TagKey.genre);
          expect(genres.isNotEmpty, isTrue);

          final genreValues = (genres.first as GenreTag).value;
          expect(genreValues, containsAll(['Electronic', 'Ambient', 'Test']));
        } finally {
          audioFile.dispose();
        }
      });

      test('MP4 artwork handling', () async {
        if (mp4FixtureFiles.isEmpty) return;

        final audioFile = await Phonic.fromFile(mp4FixtureFiles.first);

        try {
          final testArtwork = ArtworkData(
            mimeType: 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Test artwork',
            dataLoader: () async => _createTestImageData(),
          );

          audioFile.setTag(ArtworkTag(testArtwork));

          final artwork = audioFile.getTags(TagKey.artwork);
          expect(artwork.isNotEmpty, isTrue);

          final imageData = await (artwork.last as ArtworkTag).value.data;
          expect(imageData.isNotEmpty, isTrue);
        } finally {
          audioFile.dispose();
        }
      });
    });

    group('MP4 Round-Trip Consistency', () {
      test('Metadata survives encode/decode cycle', () async {
        if (mp4FixtureFiles.isEmpty) return;

        final audioFile = await Phonic.fromFile(mp4FixtureFiles.first);

        try {
          final testData = {
            'title': 'Round Trip Test',
            'artist': 'Test Artist',
            'album': 'Test Album',
            'dateRecorded': '2024', // MP4 ©day atom stores dates, not just years
            'trackNumber': 5,
          };

          audioFile.setTag(TitleTag(testData['title'] as String));
          audioFile.setTag(ArtistTag(testData['artist'] as String));
          audioFile.setTag(AlbumTag(testData['album'] as String));
          audioFile.setTag(DateRecordedTag(testData['dateRecorded'] as String)); 
          audioFile.setTag(TrackNumberTag(testData['trackNumber'] as int));

          final encodedBytes = await audioFile.encode(
            const EncodingOptions(
              strategy: EncodingStrategy.preserveExisting,
              validationLevel: ValidationLevel.basic,
            ),
          );

          audioFile.dispose();

          final decodedFile = await Phonic.fromBytes(encodedBytes);

          expect(decodedFile.getTag(TagKey.title)?.value, equals(testData['title']));
          expect(decodedFile.getTag(TagKey.artist)?.value, equals(testData['artist']));
          expect(decodedFile.getTag(TagKey.album)?.value, equals(testData['album']));
          expect((decodedFile.getTag(TagKey.dateRecorded) as DateRecordedTag?)?.value, equals(testData['dateRecorded']));
          expect((decodedFile.getTag(TagKey.trackNumber) as TrackNumberTag?)?.value, equals(testData['trackNumber']));

          decodedFile.dispose();
        } catch (e) {
          audioFile.dispose();
          rethrow;
        }
      });
    });

    group('MP4 Encoding Strategies', () {
      for (final strategy in EncodingStrategy.values) {
        test('Encoding with ${strategy.name} strategy', () async {
          if (mp4FixtureFiles.isEmpty) return;

          final audioFile = await Phonic.fromFile(mp4FixtureFiles.first);

          try {
            audioFile.setTag(const TitleTag('Strategy Test'));
            audioFile.setTag(YearTag(2024));

            final encodedBytes = await audioFile.encode(
              EncodingOptions(
                strategy: strategy,
                validationLevel: ValidationLevel.basic,
              ),
            );

            expect(encodedBytes.isNotEmpty, isTrue);
          } finally {
            audioFile.dispose();
          }
        });
      }
    });

    group('MP4 Performance', () {
      test('Batch processing', () async {
        if (mp4FixtureFiles.isEmpty) return;

        final stopwatch = Stopwatch()..start();
        var processedCount = 0;

        for (final file in mp4FixtureFiles) {
          final audioFile = await Phonic.fromFile(file);

          try {
            audioFile.setTag(const AlbumTag('Batch Test'));
            audioFile.setTag(YearTag(2024));

            final encodedBytes = await audioFile.encode(
              const EncodingOptions(
                strategy: EncodingStrategy.preserveExisting,
                validationLevel: ValidationLevel.basic,
              ),
            );

            expect(encodedBytes.isNotEmpty, isTrue);
            processedCount++;
          } finally {
            audioFile.dispose();
          }
        }

        stopwatch.stop();

        expect(processedCount, equals(mp4FixtureFiles.length));
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });
    });
  });
}

Future<List<String>> _discoverMp4FixtureFiles() async {
  final files = <String>[];

  final mp4Dir = Directory('test/fixtures/mp4');
  if (await mp4Dir.exists()) {
    final mp4Files = await mp4Dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.mp4'))
        .map((entity) => entity.path.replaceAll(r'\', '/'))
        .toList();
    files.addAll(mp4Files);
  }

  final m4aDir = Directory('test/fixtures/m4a');
  if (await m4aDir.exists()) {
    final m4aFiles = await m4aDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.m4a'))
        .map((entity) => entity.path.replaceAll(r'\', '/'))
        .toList();
    files.addAll(m4aFiles);
  }

  files.sort();
  return files;
}

Uint8List _createTestImageData() {
  final jpegHeader = [
    0xFF, 0xD8, // JPEG SOI
    0xFF, 0xE0, // APP0 marker
    0x00, 0x10, // Length
    0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, // Version
    0x01, // Units
    0x00, 0x48, 0x00, 0x48, // X/Y density
    0x00, 0x00, // Thumbnail size
  ];

  final imageData = List.filled(100, 0x42);
  final jpegEnd = [0xFF, 0xD9];

  return Uint8List.fromList([...jpegHeader, ...imageData, ...jpegEnd]);
}
