import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('ArtworkType', () {
    test('should have all standard artwork types', () {
      // Verify all expected artwork types are present
      final expectedTypes = [
        ArtworkType.frontCover,
        ArtworkType.backCover,
        ArtworkType.leaflet,
        ArtworkType.media,
        ArtworkType.leadArtist,
        ArtworkType.artist,
        ArtworkType.conductor,
        ArtworkType.band,
        ArtworkType.composer,
        ArtworkType.lyricist,
        ArtworkType.recordingLocation,
        ArtworkType.duringRecording,
        ArtworkType.duringPerformance,
        ArtworkType.movieScreenCapture,
        ArtworkType.brightColoredFish,
        ArtworkType.illustration,
        ArtworkType.bandLogotype,
        ArtworkType.publisherLogotype,
      ];

      // Verify we have exactly the expected number of types
      expect(ArtworkType.values.length, equals(expectedTypes.length));

      // Verify each expected type exists
      for (final expectedType in expectedTypes) {
        expect(ArtworkType.values, contains(expectedType));
      }
    });

    test('should have correct enum names', () {
      expect(ArtworkType.frontCover.name, equals('frontCover'));
      expect(ArtworkType.backCover.name, equals('backCover'));
      expect(ArtworkType.leaflet.name, equals('leaflet'));
      expect(ArtworkType.media.name, equals('media'));
      expect(ArtworkType.leadArtist.name, equals('leadArtist'));
      expect(ArtworkType.artist.name, equals('artist'));
      expect(ArtworkType.conductor.name, equals('conductor'));
      expect(ArtworkType.band.name, equals('band'));
      expect(ArtworkType.composer.name, equals('composer'));
      expect(ArtworkType.lyricist.name, equals('lyricist'));
      expect(ArtworkType.recordingLocation.name, equals('recordingLocation'));
      expect(ArtworkType.duringRecording.name, equals('duringRecording'));
      expect(ArtworkType.duringPerformance.name, equals('duringPerformance'));
      expect(ArtworkType.movieScreenCapture.name, equals('movieScreenCapture'));
      expect(ArtworkType.brightColoredFish.name, equals('brightColoredFish'));
      expect(ArtworkType.illustration.name, equals('illustration'));
      expect(ArtworkType.bandLogotype.name, equals('bandLogotype'));
      expect(ArtworkType.publisherLogotype.name, equals('publisherLogotype'));
    });

    test('should support equality comparison', () {
      expect(ArtworkType.frontCover, equals(ArtworkType.frontCover));
      expect(ArtworkType.backCover, equals(ArtworkType.backCover));
      expect(ArtworkType.frontCover, isNot(equals(ArtworkType.backCover)));
    });

    test('should support switch statements', () {
      String getDescription(ArtworkType type) {
        switch (type) {
          case ArtworkType.frontCover:
            return 'Front cover image';
          case ArtworkType.backCover:
            return 'Back cover image';
          case ArtworkType.leaflet:
            return 'Leaflet or booklet pages';
          case ArtworkType.media:
            return 'Media image';
          case ArtworkType.leadArtist:
            return 'Lead artist portrait';
          case ArtworkType.artist:
            return 'Artist photograph';
          case ArtworkType.conductor:
            return 'Conductor portrait';
          case ArtworkType.band:
            return 'Band photograph';
          case ArtworkType.composer:
            return 'Composer portrait';
          case ArtworkType.lyricist:
            return 'Lyricist portrait';
          case ArtworkType.recordingLocation:
            return 'Recording location';
          case ArtworkType.duringRecording:
            return 'During recording';
          case ArtworkType.duringPerformance:
            return 'During performance';
          case ArtworkType.movieScreenCapture:
            return 'Movie screen capture';
          case ArtworkType.brightColoredFish:
            return 'Bright colored fish';
          case ArtworkType.illustration:
            return 'Illustration';
          case ArtworkType.bandLogotype:
            return 'Band logotype';
          case ArtworkType.publisherLogotype:
            return 'Publisher logotype';
        }
      }

      expect(getDescription(ArtworkType.frontCover), equals('Front cover image'));
      expect(getDescription(ArtworkType.backCover), equals('Back cover image'));
      expect(getDescription(ArtworkType.brightColoredFish), equals('Bright colored fish'));
    });

    test('should be usable in collections', () {
      final coverTypes = {ArtworkType.frontCover, ArtworkType.backCover};
      final artistTypes = {
        ArtworkType.leadArtist,
        ArtworkType.artist,
        ArtworkType.conductor,
        ArtworkType.band,
        ArtworkType.composer,
        ArtworkType.lyricist,
      };

      expect(coverTypes.contains(ArtworkType.frontCover), isTrue);
      expect(coverTypes.contains(ArtworkType.artist), isFalse);
      expect(artistTypes.contains(ArtworkType.artist), isTrue);
      expect(artistTypes.contains(ArtworkType.media), isFalse);
    });

    test('should maintain consistent ordering', () {
      final types = ArtworkType.values;

      // Verify the order matches the expected sequence
      expect(types[0], equals(ArtworkType.frontCover));
      expect(types[1], equals(ArtworkType.backCover));
      expect(types[2], equals(ArtworkType.leaflet));
      expect(types[3], equals(ArtworkType.media));
      expect(types.last, equals(ArtworkType.publisherLogotype));
    });

    test('should support toString representation', () {
      expect(ArtworkType.frontCover.toString(), equals('ArtworkType.frontCover'));
      expect(ArtworkType.brightColoredFish.toString(), equals('ArtworkType.brightColoredFish'));
    });
  });
}
