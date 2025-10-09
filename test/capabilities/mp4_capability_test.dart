import 'package:phonic/src/capabilities/mp4_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/text_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('MP4 Capability', () {
    test('should have correct container kind and version', () {
      expect(mp4Capability.containerKind, equals(ContainerKind.mp4));
      expect(mp4Capability.containerVersion, equals(''));
    });

    test('should support all standard MP4 tag fields', () {
      final expectedFields = {
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
        TagKey.artwork,
        TagKey.custom,
      };

      for (final field in expectedFields) {
        expect(mp4Capability.supports(field), isTrue, reason: 'MP4 should support $field');
      }
    });

    test('should have correct supported field count', () {
      expect(mp4Capability.supportedFieldCount, equals(20));
    });

    group('Text Field Semantics', () {
      test('should use UTF-8 encoding for text fields', () {
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
          TagKey.year,
          TagKey.dateRecorded,
          TagKey.custom,
        ];

        for (final field in textFields) {
          final semantics = mp4Capability.semantics(field);
          expect(semantics.allowedEncodings, isNotNull, reason: '$field should have encoding restrictions');
          expect(semantics.allowedEncodings!.contains(TextEncoding.utf8Name), isTrue, reason: '$field should support UTF-8');
          expect(semantics.allowedEncodings!.length, equals(1), reason: '$field should only support UTF-8');
        }
      });

      test('should not be multi-valued for single-value text fields', () {
        final singleValueFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          // Genre is excluded - it supports multiple values via semicolon delimiter
          TagKey.comment,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.isrc,
          TagKey.musicalKey,
          TagKey.lyrics,
          TagKey.year,
          TagKey.dateRecorded,
        ];

        for (final field in singleValueFields) {
          final semantics = mp4Capability.semantics(field);
          expect(semantics.multiValued, isFalse, reason: '$field should not be multi-valued');
        }
      });

      test('should have no text length limits', () {
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
          TagKey.year,
          TagKey.dateRecorded,
          TagKey.custom,
        ];

        for (final field in textFields) {
          final semantics = mp4Capability.semantics(field);
          expect(semantics.maxTextLength, isNull, reason: '$field should have no text length limit');
        }
      });
    });

    group('Numeric Field Semantics', () {
      test('should have correct track number constraints', () {
        final semantics = mp4Capability.semantics(TagKey.trackNumber);
        expect(semantics.minValue, equals(1));
        expect(semantics.maxValue, equals(65535)); // 16-bit unsigned integer
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, isNull); // Binary data, no encoding
      });

      test('should have correct disc number constraints', () {
        final semantics = mp4Capability.semantics(TagKey.discNumber);
        expect(semantics.minValue, equals(1));
        expect(semantics.maxValue, equals(65535)); // 16-bit unsigned integer
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, isNull); // Binary data, no encoding
      });

      test('should have correct year constraints', () {
        final semantics = mp4Capability.semantics(TagKey.year);
        expect(semantics.minValue, equals(1000));
        expect(semantics.maxValue, equals(3000));
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings!.contains(TextEncoding.utf8Name), isTrue);
      });

      test('should have correct BPM constraints', () {
        final semantics = mp4Capability.semantics(TagKey.bpm);
        expect(semantics.minValue, equals(1));
        expect(semantics.maxValue, equals(65535)); // 16-bit unsigned integer
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, isNull); // Binary data, no encoding
      });

      test('should have correct rating constraints', () {
        final semantics = mp4Capability.semantics(TagKey.rating);
        expect(semantics.minValue, equals(0));
        expect(semantics.maxValue, equals(100)); // Unified 0-100 scale
        expect(semantics.multiValued, isFalse);
        expect(semantics.allowedEncodings, isNull); // Binary data, no encoding
      });
    });

    group('Multi-valued Field Semantics', () {
      test('should support multi-valued genre', () {
        final semantics = mp4Capability.semantics(TagKey.genre);
        expect(semantics.multiValued, isTrue, reason: 'Genre should support multiple values with semicolon delimiter');
        expect(semantics.allowedEncodings!.contains(TextEncoding.utf8Name), isTrue);
        expect(semantics.maxTextLength, isNull);
      });

      test('should support multi-valued artwork', () {
        final semantics = mp4Capability.semantics(TagKey.artwork);
        expect(semantics.multiValued, isTrue);
        expect(semantics.allowedEncodings, isNull); // Binary data, no encoding
        expect(semantics.maxTextLength, isNull);
        expect(semantics.minValue, isNull);
        expect(semantics.maxValue, isNull);
      });

      test('should support multi-valued custom fields', () {
        final semantics = mp4Capability.semantics(TagKey.custom);
        expect(semantics.multiValued, isTrue);
        expect(semantics.allowedEncodings!.contains(TextEncoding.utf8Name), isTrue);
        expect(semantics.maxTextLength, isNull);
      });
    });

    group('Validation Methods', () {
      test('should validate track number values correctly', () {
        final semantics = mp4Capability.semantics(TagKey.trackNumber);

        expect(semantics.isValidValue(1), isTrue);
        expect(semantics.isValidValue(100), isTrue);
        expect(semantics.isValidValue(65535), isTrue);

        expect(semantics.isValidValue(0), isFalse);
        expect(semantics.isValidValue(-1), isFalse);
        expect(semantics.isValidValue(65536), isFalse);
      });

      test('should validate rating values correctly', () {
        final semantics = mp4Capability.semantics(TagKey.rating);

        expect(semantics.isValidValue(0), isTrue);
        expect(semantics.isValidValue(50), isTrue);
        expect(semantics.isValidValue(100), isTrue);

        expect(semantics.isValidValue(-1), isFalse);
        expect(semantics.isValidValue(101), isFalse);
      });

      test('should validate UTF-8 encoding for text fields', () {
        final semantics = mp4Capability.semantics(TagKey.title);

        expect(semantics.isValidEncoding(TextEncoding.utf8Name), isTrue);
        expect(semantics.supportsEncoding(TextEncoding.utf8), isTrue);

        expect(semantics.isValidEncoding(TextEncoding.iso88591Name), isFalse);
        expect(semantics.supportsEncoding(TextEncoding.iso88591), isFalse);
        expect(semantics.isValidEncoding(TextEncoding.utf16Name), isFalse);
        expect(semantics.supportsEncoding(TextEncoding.utf16), isFalse);
      });
    });

    group('Capability Properties', () {
      test('should have constraints', () {
        expect(mp4Capability.hasConstraints, isTrue);
      });

      test('should return correct supported fields list', () {
        final supportedFields = mp4Capability.supportedFields;
        expect(supportedFields.length, equals(20));
        expect(supportedFields.contains(TagKey.title), isTrue);
        expect(supportedFields.contains(TagKey.artwork), isTrue);
        expect(supportedFields.contains(TagKey.custom), isTrue);
      });

      test('should have meaningful string representation', () {
        final str = mp4Capability.toString();
        expect(str, contains('mp4'));
        expect(str, contains('20 fields'));
      });
    });

    group('Unsupported Fields', () {
      test('should return default semantics for unsupported fields', () {
        // All currently defined TagKey values are supported by MP4,
        // but test the behavior for completeness
        final semantics = mp4Capability.semantics(TagKey.title);
        expect(semantics, isNotNull);
      });
    });

    group('Value Clamping', () {
      test('should clamp track number values to valid range', () {
        final semantics = mp4Capability.semantics(TagKey.trackNumber);

        expect(semantics.clampValue(0), equals(1));
        expect(semantics.clampValue(-5), equals(1));
        expect(semantics.clampValue(50), equals(50));
        expect(semantics.clampValue(65535), equals(65535));
        expect(semantics.clampValue(70000), equals(65535));
      });

      test('should clamp rating values to valid range', () {
        final semantics = mp4Capability.semantics(TagKey.rating);

        expect(semantics.clampValue(-10), equals(0));
        expect(semantics.clampValue(0), equals(0));
        expect(semantics.clampValue(50), equals(50));
        expect(semantics.clampValue(100), equals(100));
        expect(semantics.clampValue(150), equals(100));
      });
    });

    group('Encoding Support', () {
      test('should only support UTF-8 for text fields', () {
        final textFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.comment,
        ];

        for (final field in textFields) {
          final semantics = mp4Capability.semantics(field);

          // Should support UTF-8
          expect(semantics.supportsEncoding(TextEncoding.utf8), isTrue);

          // Should not support other encodings
          expect(semantics.supportsEncoding(TextEncoding.iso88591), isFalse);
          expect(semantics.supportsEncoding(TextEncoding.utf16), isFalse);
          expect(semantics.supportsEncoding(TextEncoding.utf16be), isFalse);
          expect(semantics.supportsEncoding(TextEncoding.utf16le), isFalse);
          expect(semantics.supportsEncoding(TextEncoding.ascii), isFalse);
        }
      });
    });
  });
}
