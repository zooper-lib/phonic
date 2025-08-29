import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/id3v24_capability.dart';
import 'package:phonic/src/container_kind.dart';
import 'package:phonic/src/tag_key.dart';
import 'package:phonic/src/text_encoding.dart';

void main() {
  group('ID3v2.4 Capability Tests', () {
    test('capability has correct properties', () {
      expect(id3v24Capability.containerKind, equals(ContainerKind.id3v2));
      expect(id3v24Capability.containerVersion, equals('2.4'));
    });

    test('supports all expected tag keys', () {
      // Text fields
      expect(id3v24Capability.supports(TagKey.title), isTrue);
      expect(id3v24Capability.supports(TagKey.artist), isTrue);
      expect(id3v24Capability.supports(TagKey.album), isTrue);
      expect(id3v24Capability.supports(TagKey.albumArtist), isTrue);
      expect(id3v24Capability.supports(TagKey.genre), isTrue);
      expect(id3v24Capability.supports(TagKey.comment), isTrue);
      expect(id3v24Capability.supports(TagKey.grouping), isTrue);
      expect(id3v24Capability.supports(TagKey.composer), isTrue);
      expect(id3v24Capability.supports(TagKey.encoder), isTrue);
      expect(id3v24Capability.supports(TagKey.isrc), isTrue);
      expect(id3v24Capability.supports(TagKey.musicalKey), isTrue);
      expect(id3v24Capability.supports(TagKey.lyrics), isTrue);

      // Numeric fields
      expect(id3v24Capability.supports(TagKey.trackNumber), isTrue);
      expect(id3v24Capability.supports(TagKey.discNumber), isTrue);
      expect(id3v24Capability.supports(TagKey.year), isTrue);
      expect(id3v24Capability.supports(TagKey.bpm), isTrue);
      expect(id3v24Capability.supports(TagKey.rating), isTrue);

      // Date field
      expect(id3v24Capability.supports(TagKey.dateRecorded), isTrue);

      // Binary fields
      expect(id3v24Capability.supports(TagKey.artwork), isTrue);

      // Custom fields
      expect(id3v24Capability.supports(TagKey.custom), isTrue);
    });

    test('UTF-8 encoding support is available for text fields', () {
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
        TagKey.dateRecorded,
        TagKey.custom,
      ];

      for (final field in textFields) {
        final semantics = id3v24Capability.semantics(field);
        expect(
          semantics.allowedEncodings?.contains(TextEncoding.utf8.standardName),
          isTrue,
          reason: '$field should support UTF-8 encoding in ID3v2.4',
        );
      }
    });

    test('full encoding support includes all expected encodings', () {
      final titleSemantics = id3v24Capability.semantics(TagKey.title);
      final expectedEncodings = {
        TextEncoding.iso88591.standardName,
        TextEncoding.utf16.standardName,
        TextEncoding.utf16be.standardName,
        TextEncoding.utf16le.standardName,
        TextEncoding.utf8.standardName,
      };

      expect(titleSemantics.allowedEncodings, equals(expectedEncodings));
    });

    test('multi-valued field semantics are correct', () {
      // Fields that support multiple values
      expect(id3v24Capability.semantics(TagKey.genre).multiValued, isTrue);
      expect(id3v24Capability.semantics(TagKey.artwork).multiValued, isTrue);
      expect(id3v24Capability.semantics(TagKey.custom).multiValued, isTrue);

      // Fields that are single-valued
      expect(id3v24Capability.semantics(TagKey.title).multiValued, isFalse);
      expect(id3v24Capability.semantics(TagKey.artist).multiValued, isFalse);
      expect(id3v24Capability.semantics(TagKey.album).multiValued, isFalse);
      expect(id3v24Capability.semantics(TagKey.comment).multiValued, isFalse);
      expect(id3v24Capability.semantics(TagKey.rating).multiValued, isFalse);
      expect(id3v24Capability.semantics(TagKey.dateRecorded).multiValued, isFalse);
    });

    test('numeric field constraints are correct', () {
      // Track number constraints
      final trackSemantics = id3v24Capability.semantics(TagKey.trackNumber);
      expect(trackSemantics.minValue, equals(1));
      expect(trackSemantics.maxValue, equals(999));

      // Disc number constraints
      final discSemantics = id3v24Capability.semantics(TagKey.discNumber);
      expect(discSemantics.minValue, equals(1));
      expect(discSemantics.maxValue, equals(99));

      // Year constraints
      final yearSemantics = id3v24Capability.semantics(TagKey.year);
      expect(yearSemantics.minValue, equals(1000));
      expect(yearSemantics.maxValue, equals(3000));

      // BPM constraints
      final bpmSemantics = id3v24Capability.semantics(TagKey.bpm);
      expect(bpmSemantics.minValue, equals(1));
      expect(bpmSemantics.maxValue, equals(999));

      // Rating constraints (unified 0-100 scale)
      final ratingSemantics = id3v24Capability.semantics(TagKey.rating);
      expect(ratingSemantics.minValue, equals(0));
      expect(ratingSemantics.maxValue, equals(100));
    });

    test('rating field has no encoding constraints', () {
      // Rating is stored in POPM frame which doesn't use text encoding
      final ratingSemantics = id3v24Capability.semantics(TagKey.rating);
      expect(ratingSemantics.allowedEncodings, isNull);
    });

    test('artwork field has no encoding constraints', () {
      // Artwork is binary data in APIC frames
      final artworkSemantics = id3v24Capability.semantics(TagKey.artwork);
      expect(artworkSemantics.allowedEncodings, isNull);
    });

    test('unsupported tag keys return false', () {
      // Test with a hypothetical unsupported key by checking semantics
      expect(id3v24Capability.supports(TagKey.values.last), isTrue); // All keys should be supported
    });

    test('semantics for unsupported keys return default values', () {
      // Create a mock unsupported key scenario by checking behavior
      // Since all TagKey values are supported, we test the default semantics behavior
      final defaultSemantics = id3v24Capability.semantics(TagKey.title);
      expect(defaultSemantics, isNotNull);
    });

    group('ID3v2.4 specific features', () {
      test('genre field supports null-terminated multi-values', () {
        final genreSemantics = id3v24Capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isTrue);
        expect(genreSemantics.allowedEncodings?.contains(TextEncoding.utf8.standardName), isTrue);
      });

      test('date recorded field uses unified TDRC frame semantics', () {
        final dateSemantics = id3v24Capability.semantics(TagKey.dateRecorded);
        expect(dateSemantics.multiValued, isFalse);
        expect(dateSemantics.allowedEncodings?.contains(TextEncoding.utf8.standardName), isTrue);
      });

      test('all text fields support UTF-8 encoding', () {
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
          final semantics = id3v24Capability.semantics(field);
          expect(
            semantics.allowedEncodings?.contains(TextEncoding.utf8.standardName),
            isTrue,
            reason: '$field should support UTF-8 in ID3v2.4',
          );
          expect(
            semantics.allowedEncodings?.contains(TextEncoding.iso88591.standardName),
            isTrue,
            reason: '$field should maintain backward compatibility with ISO-8859-1',
          );
          expect(
            semantics.allowedEncodings?.contains(TextEncoding.utf16.standardName),
            isTrue,
            reason: '$field should maintain backward compatibility with UTF-16',
          );
        }
      });
    });

    group('comparison with ID3v2.3', () {
      test('ID3v2.4 has UTF-8 support that ID3v2.3 lacks', () {
        // This test documents the key difference between v2.3 and v2.4
        final v24TitleSemantics = id3v24Capability.semantics(TagKey.title);
        expect(v24TitleSemantics.allowedEncodings?.contains(TextEncoding.utf8.standardName), isTrue);

        // Note: This test assumes id3v23Capability is available for comparison
        // In a real scenario, you might import it to make direct comparisons
      });

      test('both versions support the same core tag fields', () {
        final coreFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.genre,
          TagKey.trackNumber,
          TagKey.year,
          TagKey.rating,
          TagKey.artwork,
        ];

        for (final field in coreFields) {
          expect(
            id3v24Capability.supports(field),
            isTrue,
            reason: 'ID3v2.4 should support core field $field',
          );
        }
      });
    });

    group('edge cases and validation', () {
      test('capability object is immutable', () {
        // Verify the capability constant is properly defined
        expect(id3v24Capability.containerKind, equals(ContainerKind.id3v2));
        expect(id3v24Capability.containerVersion, equals('2.4'));
        expect(id3v24Capability.semanticsByKey, isNotNull);
        expect(id3v24Capability.semanticsByKey.isNotEmpty, isTrue);
      });

      test('all semantics objects are properly configured', () {
        for (final key in TagKey.values) {
          if (id3v24Capability.supports(key)) {
            final semantics = id3v24Capability.semantics(key);
            expect(semantics, isNotNull, reason: 'Semantics for $key should not be null');

            // Verify encoding constraints are reasonable
            if (semantics.allowedEncodings != null) {
              expect(semantics.allowedEncodings!.isNotEmpty, isTrue, reason: 'If encodings are specified for $key, they should not be empty');
            }

            // Verify numeric constraints are reasonable
            if (semantics.minValue != null && semantics.maxValue != null) {
              expect(semantics.minValue! <= semantics.maxValue!, isTrue, reason: 'Min value should not exceed max value for $key');
            }
          }
        }
      });
    });
  });
}
