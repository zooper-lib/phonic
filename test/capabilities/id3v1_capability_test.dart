import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/id3v1_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/format_constraints.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/text_encoding.dart';

void main() {
  group('ID3v1 Capability', () {
    group('basic properties', () {
      test('has correct container kind and version', () {
        expect(id3v1Capability.containerKind, equals(ContainerKind.id3v1));
        expect(id3v1Capability.containerVersion, equals('v1'));
      });

      test('supports exactly 7 fields', () {
        expect(id3v1Capability.supportedFieldCount, equals(7));
      });

      test('has constraints defined', () {
        expect(id3v1Capability.hasConstraints, isTrue);
      });

      test('toString provides meaningful description', () {
        final description = id3v1Capability.toString();
        expect(description, contains('id3v1'));
        expect(description, contains('v1'));
        expect(description, contains('7 fields'));
      });
    });

    group('supported fields', () {
      test('supports basic text fields with 30-character limits', () {
        final supportedTextFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
        ];

        for (final field in supportedTextFields) {
          expect(id3v1Capability.supports(field), isTrue, reason: '$field should be supported');

          final semantics = id3v1Capability.semantics(field);
          expect(semantics.maxTextLength, equals(30), reason: '$field should have 30-character limit');
          expect(semantics.multiValued, isFalse, reason: '$field should not support multiple values');
          expect(
            semantics.allowedEncodings,
            equals({TextEncoding.iso88591.standardName}),
            reason: '$field should only support ISO-8859-1 encoding',
          );
        }
      });

      test('supports year field with 4-character limit', () {
        expect(id3v1Capability.supports(TagKey.year), isTrue);

        final semantics = id3v1Capability.semantics(TagKey.year);
        expect(semantics.maxTextLength, equals(4));
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, equals({TextEncoding.iso88591.standardName}));
      });

      test('supports comment field with 28-character limit', () {
        expect(id3v1Capability.supports(TagKey.comment), isTrue);

        final semantics = id3v1Capability.semantics(TagKey.comment);
        expect(
          semantics.maxTextLength,
          equals(28),
          reason: 'Comment should be limited to 28 chars when track is present',
        );
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, equals({TextEncoding.iso88591.standardName}));
      });

      test('supports track number with 1-255 range', () {
        expect(id3v1Capability.supports(TagKey.trackNumber), isTrue);

        final semantics = id3v1Capability.semantics(TagKey.trackNumber);
        expect(semantics.minValue, equals(1));
        expect(semantics.maxValue, equals(255));
        expect(semantics.multiValued, isFalse);
        expect(semantics.hasTextLengthLimit, isFalse);
      });

      test('supports genre with 0-255 range', () {
        expect(id3v1Capability.supports(TagKey.genre), isTrue);

        final semantics = id3v1Capability.semantics(TagKey.genre);
        expect(semantics.minValue, equals(ID3v1Constraints.minGenreCode));
        expect(semantics.maxValue, equals(ID3v1Constraints.maxGenreCode));
        expect(semantics.multiValued, isFalse);
        expect(semantics.hasTextLengthLimit, isFalse);
      });

      test('returns complete list of supported fields', () {
        final supportedFields = id3v1Capability.supportedFields;
        final expectedFields = {
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.year,
          TagKey.comment,
          TagKey.trackNumber,
          TagKey.genre,
        };

        expect(supportedFields.toSet(), equals(expectedFields));
      });
    });

    group('unsupported fields', () {
      test('does not support extended metadata fields', () {
        final unsupportedFields = [
          TagKey.albumArtist,
          TagKey.discNumber,
          TagKey.dateRecorded,
          TagKey.bpm,
          TagKey.musicalKey,
          TagKey.rating,
          TagKey.lyrics,
          TagKey.artwork,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.custom,
        ];

        for (final field in unsupportedFields) {
          expect(id3v1Capability.supports(field), isFalse, reason: '$field should not be supported by ID3v1');

          final semantics = id3v1Capability.semantics(field);
          expect(semantics.hasConstraints, isFalse, reason: 'Unsupported $field should have no constraints');
        }
      });

      test('returns default semantics for unsupported fields', () {
        final semantics = id3v1Capability.semantics(TagKey.artwork);
        expect(semantics.maxTextLength, isNull);
        expect(semantics.minValue, isNull);
        expect(semantics.maxValue, isNull);
        expect(semantics.allowedEncodings, isNull);
        expect(semantics.multiValued, isFalse);
      });
    });

    group('field validation', () {
      test('validates text field lengths correctly', () {
        final titleSemantics = id3v1Capability.semantics(TagKey.title);

        // Valid lengths
        expect(titleSemantics.isValidTextLength(0), isTrue);
        expect(titleSemantics.isValidTextLength(15), isTrue);
        expect(titleSemantics.isValidTextLength(30), isTrue);

        // Invalid lengths
        expect(titleSemantics.isValidTextLength(31), isFalse);
        expect(titleSemantics.isValidTextLength(100), isFalse);
      });

      test('validates year field length correctly', () {
        final yearSemantics = id3v1Capability.semantics(TagKey.year);

        // Valid lengths
        expect(yearSemantics.isValidTextLength(4), isTrue);

        // Invalid lengths
        expect(yearSemantics.isValidTextLength(3), isTrue); // Will be padded
        expect(yearSemantics.isValidTextLength(5), isFalse); // Will be truncated
      });

      test('validates comment field length correctly', () {
        final commentSemantics = id3v1Capability.semantics(TagKey.comment);

        // Valid lengths (conservative 28-char limit)
        expect(commentSemantics.isValidTextLength(0), isTrue);
        expect(commentSemantics.isValidTextLength(28), isTrue);

        // Invalid lengths
        expect(commentSemantics.isValidTextLength(29), isFalse);
        expect(commentSemantics.isValidTextLength(30), isFalse);
      });

      test('validates track number range correctly', () {
        final trackSemantics = id3v1Capability.semantics(TagKey.trackNumber);

        // Valid values
        expect(trackSemantics.isValidValue(ID3v1Constraints.minTrackNumber), isTrue);
        expect(trackSemantics.isValidValue(128), isTrue);
        expect(trackSemantics.isValidValue(ID3v1Constraints.maxTrackNumber), isTrue);

        // Invalid values
        expect(trackSemantics.isValidValue(0), isFalse);
        expect(trackSemantics.isValidValue(-1), isFalse);
        expect(trackSemantics.isValidValue(ID3v1Constraints.maxTrackNumber + 1), isFalse);
        expect(trackSemantics.isValidValue(1000), isFalse);
      });

      test('validates genre range correctly', () {
        final genreSemantics = id3v1Capability.semantics(TagKey.genre);

        // Valid values
        expect(genreSemantics.isValidValue(ID3v1Constraints.minGenreCode), isTrue);
        expect(genreSemantics.isValidValue(128), isTrue);
        expect(genreSemantics.isValidValue(ID3v1Constraints.maxGenreCode), isTrue);

        // Invalid values
        expect(genreSemantics.isValidValue(-1), isFalse);
        expect(genreSemantics.isValidValue(ID3v1Constraints.maxGenreCode + 1), isFalse);
        expect(genreSemantics.isValidValue(1000), isFalse);
      });

      test('validates encoding restrictions correctly', () {
        final titleSemantics = id3v1Capability.semantics(TagKey.title);

        // Valid encoding
        expect(titleSemantics.isValidEncoding(TextEncoding.iso88591.standardName), isTrue);

        // Invalid encodings
        expect(titleSemantics.isValidEncoding(TextEncoding.utf8.standardName), isFalse);
        expect(titleSemantics.isValidEncoding(TextEncoding.utf16.standardName), isFalse);
        expect(titleSemantics.isValidEncoding(TextEncoding.ascii.standardName), isFalse);
      });
    });

    group('value normalization', () {
      test('truncates text fields to maximum length', () {
        final titleSemantics = id3v1Capability.semantics(TagKey.title);

        expect(titleSemantics.truncateText('Short title'), equals('Short title'));
        expect(titleSemantics.truncateText('This is exactly thirty chars!!'), equals('This is exactly thirty chars!!'));
        expect(titleSemantics.truncateText('This title is way too long for ID3v1 format'), equals('This title is way too long for'));
      });

      test('truncates year field to 4 characters', () {
        final yearSemantics = id3v1Capability.semantics(TagKey.year);

        expect(yearSemantics.truncateText('2023'), equals('2023'));
        expect(yearSemantics.truncateText('23'), equals('23')); // Will need padding elsewhere
        expect(yearSemantics.truncateText('20231'), equals('2023'));
      });

      test('truncates comment field to 28 characters', () {
        final commentSemantics = id3v1Capability.semantics(TagKey.comment);

        expect(commentSemantics.truncateText('Short comment'), equals('Short comment'));
        expect(commentSemantics.truncateText('This is exactly 28 chars!!'), equals('This is exactly 28 chars!!'));
        expect(commentSemantics.truncateText('This comment is too long for ID3v1 when track is present'), equals('This comment is too long for'));
      });

      test('clamps track number to valid range', () {
        final trackSemantics = id3v1Capability.semantics(TagKey.trackNumber);

        expect(trackSemantics.clampValue(0), equals(ID3v1Constraints.minTrackNumber));
        expect(trackSemantics.clampValue(-5), equals(ID3v1Constraints.minTrackNumber));
        expect(trackSemantics.clampValue(128), equals(128));
        expect(trackSemantics.clampValue(ID3v1Constraints.maxTrackNumber), equals(ID3v1Constraints.maxTrackNumber));
        expect(trackSemantics.clampValue(ID3v1Constraints.maxTrackNumber + 1), equals(ID3v1Constraints.maxTrackNumber));
        expect(trackSemantics.clampValue(1000), equals(ID3v1Constraints.maxTrackNumber));
      });

      test('clamps genre to valid range', () {
        final genreSemantics = id3v1Capability.semantics(TagKey.genre);

        expect(genreSemantics.clampValue(-1), equals(ID3v1Constraints.minGenreCode));
        expect(genreSemantics.clampValue(ID3v1Constraints.minGenreCode), equals(ID3v1Constraints.minGenreCode));
        expect(genreSemantics.clampValue(128), equals(128));
        expect(genreSemantics.clampValue(ID3v1Constraints.maxGenreCode), equals(ID3v1Constraints.maxGenreCode));
        expect(genreSemantics.clampValue(ID3v1Constraints.maxGenreCode + 1), equals(ID3v1Constraints.maxGenreCode));
        expect(genreSemantics.clampValue(1000), equals(ID3v1Constraints.maxGenreCode));
      });
    });

    group('constraint analysis', () {
      test('identifies fields with text length constraints', () {
        final textFields = [TagKey.title, TagKey.artist, TagKey.album, TagKey.year, TagKey.comment];

        for (final field in textFields) {
          final semantics = id3v1Capability.semantics(field);
          expect(semantics.hasTextLengthLimit, isTrue, reason: '$field should have text length limit');
          expect(semantics.hasConstraints, isTrue, reason: '$field should have constraints');
        }
      });

      test('identifies fields with value range constraints', () {
        final numericFields = [TagKey.trackNumber, TagKey.genre];

        for (final field in numericFields) {
          final semantics = id3v1Capability.semantics(field);
          expect(semantics.hasValueRange, isTrue, reason: '$field should have value range constraints');
          expect(semantics.hasConstraints, isTrue, reason: '$field should have constraints');
        }
      });

      test('identifies fields with encoding constraints', () {
        final textFields = [TagKey.title, TagKey.artist, TagKey.album, TagKey.year, TagKey.comment];

        for (final field in textFields) {
          final semantics = id3v1Capability.semantics(field);
          expect(semantics.hasEncodingRestrictions, isTrue, reason: '$field should have encoding restrictions');
          expect(semantics.allowedEncodings, isNotNull, reason: '$field should specify allowed encodings');
        }
      });

      test('all supported fields are single-valued', () {
        for (final field in id3v1Capability.supportedFields) {
          final semantics = id3v1Capability.semantics(field);
          expect(semantics.multiValued, isFalse, reason: 'ID3v1 $field should not support multiple values');
        }
      });
    });

    group('format limitations documentation', () {
      test('documents key ID3v1 limitations in capability', () {
        // This test ensures the capability correctly represents ID3v1 limitations

        // Text field limitations
        expect(id3v1Capability.semantics(TagKey.title).maxTextLength, equals(30));
        expect(id3v1Capability.semantics(TagKey.artist).maxTextLength, equals(30));
        expect(id3v1Capability.semantics(TagKey.album).maxTextLength, equals(30));
        expect(id3v1Capability.semantics(TagKey.year).maxTextLength, equals(4));
        expect(id3v1Capability.semantics(TagKey.comment).maxTextLength, equals(28));

        // Numeric field limitations
        expect(id3v1Capability.semantics(TagKey.trackNumber).minValue, equals(1));
        expect(id3v1Capability.semantics(TagKey.trackNumber).maxValue, equals(255));
        expect(id3v1Capability.semantics(TagKey.genre).minValue, equals(0));
        expect(id3v1Capability.semantics(TagKey.genre).maxValue, equals(255));

        // Encoding limitations
        for (final field in [TagKey.title, TagKey.artist, TagKey.album, TagKey.year, TagKey.comment]) {
          expect(id3v1Capability.semantics(field).allowedEncodings, equals({TextEncoding.iso88591.standardName}));
        }

        // Unsupported fields
        final modernFields = [
          TagKey.albumArtist,
          TagKey.discNumber,
          TagKey.dateRecorded,
          TagKey.bpm,
          TagKey.musicalKey,
          TagKey.rating,
          TagKey.lyrics,
          TagKey.artwork,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.custom,
        ];

        for (final field in modernFields) {
          expect(id3v1Capability.supports(field), isFalse, reason: 'ID3v1 should not support modern field $field');
        }
      });
    });
  });
}
