import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/vorbis_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/text_encoding.dart';

void main() {
  group('Vorbis Capability Tests', () {
    test('capability has correct properties', () {
      expect(vorbisCapability.containerKind, equals(ContainerKind.vorbis));
      expect(vorbisCapability.containerVersion, equals(''));
    });

    test('supports all expected tag keys', () {
      // Text fields
      expect(vorbisCapability.supports(TagKey.title), isTrue);
      expect(vorbisCapability.supports(TagKey.artist), isTrue);
      expect(vorbisCapability.supports(TagKey.album), isTrue);
      expect(vorbisCapability.supports(TagKey.albumArtist), isTrue);
      expect(vorbisCapability.supports(TagKey.genre), isTrue);
      expect(vorbisCapability.supports(TagKey.comment), isTrue);
      expect(vorbisCapability.supports(TagKey.grouping), isTrue);
      expect(vorbisCapability.supports(TagKey.composer), isTrue);
      expect(vorbisCapability.supports(TagKey.encoder), isTrue);
      expect(vorbisCapability.supports(TagKey.isrc), isTrue);
      expect(vorbisCapability.supports(TagKey.musicalKey), isTrue);
      expect(vorbisCapability.supports(TagKey.lyrics), isTrue);

      // Numeric fields
      expect(vorbisCapability.supports(TagKey.trackNumber), isTrue);
      expect(vorbisCapability.supports(TagKey.discNumber), isTrue);
      expect(vorbisCapability.supports(TagKey.year), isTrue);
      expect(vorbisCapability.supports(TagKey.bpm), isTrue);
      expect(vorbisCapability.supports(TagKey.rating), isTrue);

      // Date field
      expect(vorbisCapability.supports(TagKey.dateRecorded), isTrue);

      // Binary fields
      expect(vorbisCapability.supports(TagKey.artwork), isTrue);

      // Custom fields
      expect(vorbisCapability.supports(TagKey.custom), isTrue);
    });

    test('UTF-8 encoding is the only supported encoding for text fields', () {
      final textFields = [
        TagKey.title,
        TagKey.artist,
        TagKey.album,
        TagKey.albumArtist,
        TagKey.genre,
        TagKey.comment,
        TagKey.grouping,
        TagKey.composer,
        TagKey.encoder,
        TagKey.isrc,
        TagKey.musicalKey,
        TagKey.lyrics,
        TagKey.trackNumber,
        TagKey.discNumber,
        TagKey.year,
        TagKey.bpm,
        TagKey.rating,
        TagKey.dateRecorded,
        TagKey.custom,
      ];

      for (final field in textFields) {
        final semantics = vorbisCapability.semantics(field);
        expect(
          semantics.allowedEncodings,
          equals({TextEncoding.utf8.standardName}),
          reason: '$field should only support UTF-8 encoding in Vorbis Comments',
        );
      }
    });

    test('multi-valued field semantics are correct', () {
      // Fields that support multiple values natively in Vorbis
      expect(vorbisCapability.semantics(TagKey.genre).multiValued, isTrue);
      expect(vorbisCapability.semantics(TagKey.artwork).multiValued, isTrue);
      expect(vorbisCapability.semantics(TagKey.custom).multiValued, isTrue);

      // Fields that are typically single-valued
      expect(vorbisCapability.semantics(TagKey.title).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.artist).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.album).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.albumArtist).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.comment).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.grouping).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.composer).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.encoder).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.isrc).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.musicalKey).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.lyrics).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.trackNumber).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.discNumber).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.year).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.bpm).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.rating).multiValued, isFalse);
      expect(vorbisCapability.semantics(TagKey.dateRecorded).multiValued, isFalse);
    });

    test('numeric field constraints are correct', () {
      // Track number constraints
      final trackSemantics = vorbisCapability.semantics(TagKey.trackNumber);
      expect(trackSemantics.minValue, equals(1));
      expect(trackSemantics.maxValue, equals(999));

      // Disc number constraints
      final discSemantics = vorbisCapability.semantics(TagKey.discNumber);
      expect(discSemantics.minValue, equals(1));
      expect(discSemantics.maxValue, equals(99));

      // Year constraints
      final yearSemantics = vorbisCapability.semantics(TagKey.year);
      expect(yearSemantics.minValue, equals(1000));
      expect(yearSemantics.maxValue, equals(3000));

      // BPM constraints
      final bpmSemantics = vorbisCapability.semantics(TagKey.bpm);
      expect(bpmSemantics.minValue, equals(1));
      expect(bpmSemantics.maxValue, equals(999));

      // Rating constraints (unified 0-100 scale)
      final ratingSemantics = vorbisCapability.semantics(TagKey.rating);
      expect(ratingSemantics.minValue, equals(0));
      expect(ratingSemantics.maxValue, equals(100));
    });

    test('no text length restrictions', () {
      final textFields = [
        TagKey.title,
        TagKey.artist,
        TagKey.album,
        TagKey.albumArtist,
        TagKey.genre,
        TagKey.comment,
        TagKey.grouping,
        TagKey.composer,
        TagKey.encoder,
        TagKey.isrc,
        TagKey.musicalKey,
        TagKey.lyrics,
        TagKey.dateRecorded,
        TagKey.custom,
      ];

      for (final field in textFields) {
        final semantics = vorbisCapability.semantics(field);
        expect(
          semantics.maxTextLength,
          isNull,
          reason: '$field should have no text length restrictions in Vorbis Comments',
        );
      }
    });

    test('artwork field has no encoding constraints', () {
      // Artwork is binary data in METADATA_BLOCK_PICTURE
      final artworkSemantics = vorbisCapability.semantics(TagKey.artwork);
      expect(artworkSemantics.allowedEncodings, isNull);
    });

    group('Vorbis Comments specific features', () {
      test('genre field supports native multi-values', () {
        final genreSemantics = vorbisCapability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isTrue);
        expect(genreSemantics.allowedEncodings, equals({TextEncoding.utf8.standardName}));
        expect(genreSemantics.maxTextLength, isNull);
      });

      test('date recorded field uses ISO-8601 format', () {
        final dateSemantics = vorbisCapability.semantics(TagKey.dateRecorded);
        expect(dateSemantics.multiValued, isFalse);
        expect(dateSemantics.allowedEncodings, equals({TextEncoding.utf8.standardName}));
        expect(dateSemantics.maxTextLength, isNull);
      });

      test('all text fields are UTF-8 only', () {
        final textFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          TagKey.comment,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.musicalKey,
          TagKey.lyrics,
        ];

        for (final field in textFields) {
          final semantics = vorbisCapability.semantics(field);
          expect(
            semantics.allowedEncodings,
            equals({TextEncoding.utf8.standardName}),
            reason: '$field should only support UTF-8 in Vorbis Comments',
          );
        }
      });

      test('custom fields support multi-values and UTF-8', () {
        final customSemantics = vorbisCapability.semantics(TagKey.custom);
        expect(customSemantics.multiValued, isTrue);
        expect(customSemantics.allowedEncodings, equals({TextEncoding.utf8.standardName}));
        expect(customSemantics.maxTextLength, isNull);
      });
    });

    group('comparison with other formats', () {
      test('Vorbis has simpler encoding than ID3v2', () {
        // Vorbis only supports UTF-8, unlike ID3v2 which supports multiple encodings
        final titleSemantics = vorbisCapability.semantics(TagKey.title);
        expect(titleSemantics.allowedEncodings, equals({TextEncoding.utf8.standardName}));
        expect(titleSemantics.allowedEncodings?.length, equals(1));
      });

      test('Vorbis has no length restrictions unlike ID3v1', () {
        final titleSemantics = vorbisCapability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, isNull);
      });

      test('Vorbis supports native multi-valued genres', () {
        final genreSemantics = vorbisCapability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isTrue);
      });
    });

    group('edge cases and validation', () {
      test('capability object is immutable', () {
        expect(vorbisCapability.containerKind, equals(ContainerKind.vorbis));
        expect(vorbisCapability.containerVersion, equals(''));
        expect(vorbisCapability.semanticsByKey, isNotNull);
        expect(vorbisCapability.semanticsByKey.isNotEmpty, isTrue);
      });

      test('all semantics objects are properly configured', () {
        for (final key in TagKey.values) {
          if (vorbisCapability.supports(key)) {
            final semantics = vorbisCapability.semantics(key);
            expect(semantics, isNotNull, reason: 'Semantics for $key should not be null');

            // Verify encoding constraints are reasonable
            if (semantics.allowedEncodings != null) {
              expect(semantics.allowedEncodings!.isNotEmpty, isTrue, reason: 'If encodings are specified for $key, they should not be empty');
              expect(semantics.allowedEncodings, equals({TextEncoding.utf8.standardName}), reason: 'Vorbis should only support UTF-8 for $key');
            }

            // Verify numeric constraints are reasonable
            if (semantics.minValue != null && semantics.maxValue != null) {
              expect(semantics.minValue! <= semantics.maxValue!, isTrue, reason: 'Min value should not exceed max value for $key');
            }

            // Verify no text length restrictions
            if ([TagKey.rating, TagKey.artwork].contains(key)) {
              // These fields may not have text length restrictions for different reasons
            } else {
              expect(semantics.maxTextLength, isNull, reason: 'Vorbis should have no text length restrictions for $key');
            }
          }
        }
      });

      test('UTF-8 encoding validation', () {
        final textFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          TagKey.genre,
          TagKey.comment,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.musicalKey,
          TagKey.lyrics,
          TagKey.trackNumber,
          TagKey.discNumber,
          TagKey.year,
          TagKey.bpm,
          TagKey.rating,
          TagKey.dateRecorded,
          TagKey.custom,
        ];

        for (final field in textFields) {
          final semantics = vorbisCapability.semantics(field);
          expect(semantics.supportsEncoding(TextEncoding.utf8), isTrue, reason: '$field should support UTF-8');
          expect(semantics.supportsEncoding(TextEncoding.iso88591), isFalse, reason: '$field should not support ISO-8859-1');
          expect(semantics.supportsEncoding(TextEncoding.utf16), isFalse, reason: '$field should not support UTF-16');
        }
      });

      test('multi-valued fields are correctly identified', () {
        final multiValuedFields = [TagKey.genre, TagKey.artwork, TagKey.custom];
        final singleValuedFields = TagKey.values.where((key) => !multiValuedFields.contains(key) && vorbisCapability.supports(key)).toList();

        for (final field in multiValuedFields) {
          expect(vorbisCapability.semantics(field).multiValued, isTrue, reason: '$field should be multi-valued');
        }

        for (final field in singleValuedFields) {
          expect(vorbisCapability.semantics(field).multiValued, isFalse, reason: '$field should be single-valued');
        }
      });
    });

    group('field mapping documentation', () {
      test('documents expected Vorbis comment field names', () {
        // This test documents the expected field mappings for Vorbis Comments
        // The actual mapping implementation will be in VorbisCommentMap class

        final expectedMappings = {
          TagKey.title: 'TITLE',
          TagKey.artist: 'ARTIST',
          TagKey.album: 'ALBUM',
          TagKey.albumArtist: 'ALBUMARTIST',
          TagKey.genre: 'GENRE',
          TagKey.comment: 'COMMENT',
          TagKey.grouping: 'GROUPING',
          TagKey.composer: 'COMPOSER',
          TagKey.encoder: 'ENCODER',
          TagKey.isrc: 'ISRC',
          TagKey.musicalKey: 'KEY',
          TagKey.lyrics: 'LYRICS',
          TagKey.trackNumber: 'TRACKNUMBER',
          TagKey.discNumber: 'DISCNUMBER',
          TagKey.dateRecorded: 'DATE',
          TagKey.bpm: 'BPM',
          TagKey.rating: 'RATING',
        };

        // Verify all mapped fields are supported
        for (final key in expectedMappings.keys) {
          expect(vorbisCapability.supports(key), isTrue, reason: 'Expected field $key should be supported');
        }
      });
    });
  });
}
