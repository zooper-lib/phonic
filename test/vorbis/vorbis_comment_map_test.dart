import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/tag_key.dart';
import 'package:phonic/src/vorbis/vorbis_comment_map.dart';

void main() {
  group('VorbisCommentMap', () {
    group('keys mappings', () {
      test('should contain all expected field mappings', () {
        final keys = VorbisCommentMap.keys;

        // Test core text fields
        expect(keys[TagKey.title], equals('TITLE'));
        expect(keys[TagKey.artist], equals('ARTIST'));
        expect(keys[TagKey.album], equals('ALBUM'));
        expect(keys[TagKey.albumArtist], equals('ALBUMARTIST'));
        expect(keys[TagKey.trackNumber], equals('TRACKNUMBER'));
        expect(keys[TagKey.discNumber], equals('DISCNUMBER'));
        expect(keys[TagKey.genre], equals('GENRE'));
        expect(keys[TagKey.comment], equals('COMMENT'));
        expect(keys[TagKey.grouping], equals('GROUPING'));
        expect(keys[TagKey.composer], equals('COMPOSER'));
        expect(keys[TagKey.encoder], equals('ENCODER'));
        expect(keys[TagKey.isrc], equals('ISRC'));
        expect(keys[TagKey.bpm], equals('BPM'));
        expect(keys[TagKey.musicalKey], equals('KEY'));
        expect(keys[TagKey.rating], equals('RATING'));
        expect(keys[TagKey.lyrics], equals('LYRICS'));

        // Test date field
        expect(keys[TagKey.dateRecorded], equals('DATE'));
      });

      test('should not contain artwork field (handled separately)', () {
        expect(VorbisCommentMap.keys.containsKey(TagKey.artwork), isFalse);
      });

      test('should not contain custom field (handled natively)', () {
        expect(VorbisCommentMap.keys.containsKey(TagKey.custom), isFalse);
      });

      test('should not contain year field (uses dateRecorded/DATE instead)', () {
        expect(VorbisCommentMap.keys.containsKey(TagKey.year), isFalse);
      });

      test('should have expected number of mappings', () {
        // Should support most fields except artwork, custom, and year
        expect(VorbisCommentMap.keys.length, equals(17));
      });

      test('all field names should be uppercase', () {
        for (final fieldName in VorbisCommentMap.keys.values) {
          expect(fieldName, equals(fieldName.toUpperCase()), reason: 'Field name "$fieldName" should be uppercase');
        }
      });

      test('all field names should be valid Vorbis comment format', () {
        for (final fieldName in VorbisCommentMap.keys.values) {
          // Vorbis comment field names should contain only uppercase letters, numbers, and underscores
          expect(
            fieldName,
            matches(RegExp(r'^[A-Z0-9_]+$')),
            reason: 'Field name "$fieldName" should only contain uppercase letters, numbers, and underscores',
          );

          // Should not start with underscore (reserved)
          expect(fieldName.startsWith('_'), isFalse, reason: 'Field name "$fieldName" should not start with underscore');
        }
      });
    });

    group('getSupportedTags', () {
      test('should return correct set of supported tags', () {
        final supportedTags = VorbisCommentMap.getSupportedTags();

        // Should contain all mapped tags
        expect(supportedTags.contains(TagKey.title), isTrue);
        expect(supportedTags.contains(TagKey.artist), isTrue);
        expect(supportedTags.contains(TagKey.album), isTrue);
        expect(supportedTags.contains(TagKey.albumArtist), isTrue);
        expect(supportedTags.contains(TagKey.trackNumber), isTrue);
        expect(supportedTags.contains(TagKey.discNumber), isTrue);
        expect(supportedTags.contains(TagKey.dateRecorded), isTrue);
        expect(supportedTags.contains(TagKey.genre), isTrue);
        expect(supportedTags.contains(TagKey.comment), isTrue);
        expect(supportedTags.contains(TagKey.bpm), isTrue);
        expect(supportedTags.contains(TagKey.musicalKey), isTrue);
        expect(supportedTags.contains(TagKey.rating), isTrue);
        expect(supportedTags.contains(TagKey.lyrics), isTrue);
        expect(supportedTags.contains(TagKey.grouping), isTrue);
        expect(supportedTags.contains(TagKey.composer), isTrue);
        expect(supportedTags.contains(TagKey.encoder), isTrue);
        expect(supportedTags.contains(TagKey.isrc), isTrue);

        // Should not contain unsupported tags
        expect(supportedTags.contains(TagKey.artwork), isFalse);
        expect(supportedTags.contains(TagKey.custom), isFalse);
        expect(supportedTags.contains(TagKey.year), isFalse);

        // Should have correct count
        expect(supportedTags.length, equals(17));
      });

      test('should return consistent set', () {
        final supportedTags1 = VorbisCommentMap.getSupportedTags();
        final supportedTags2 = VorbisCommentMap.getSupportedTags();
        expect(supportedTags1, equals(supportedTags2));
      });
    });

    group('getFieldName', () {
      test('should return correct field names for supported tags', () {
        expect(VorbisCommentMap.getFieldName(TagKey.title), equals('TITLE'));
        expect(VorbisCommentMap.getFieldName(TagKey.artist), equals('ARTIST'));
        expect(VorbisCommentMap.getFieldName(TagKey.album), equals('ALBUM'));
        expect(VorbisCommentMap.getFieldName(TagKey.albumArtist), equals('ALBUMARTIST'));
        expect(VorbisCommentMap.getFieldName(TagKey.trackNumber), equals('TRACKNUMBER'));
        expect(VorbisCommentMap.getFieldName(TagKey.discNumber), equals('DISCNUMBER'));
        expect(VorbisCommentMap.getFieldName(TagKey.dateRecorded), equals('DATE'));
        expect(VorbisCommentMap.getFieldName(TagKey.genre), equals('GENRE'));
        expect(VorbisCommentMap.getFieldName(TagKey.comment), equals('COMMENT'));
        expect(VorbisCommentMap.getFieldName(TagKey.bpm), equals('BPM'));
        expect(VorbisCommentMap.getFieldName(TagKey.musicalKey), equals('KEY'));
        expect(VorbisCommentMap.getFieldName(TagKey.rating), equals('RATING'));
        expect(VorbisCommentMap.getFieldName(TagKey.lyrics), equals('LYRICS'));
        expect(VorbisCommentMap.getFieldName(TagKey.grouping), equals('GROUPING'));
        expect(VorbisCommentMap.getFieldName(TagKey.composer), equals('COMPOSER'));
        expect(VorbisCommentMap.getFieldName(TagKey.encoder), equals('ENCODER'));
        expect(VorbisCommentMap.getFieldName(TagKey.isrc), equals('ISRC'));
      });

      test('should return null for unsupported tags', () {
        expect(VorbisCommentMap.getFieldName(TagKey.artwork), isNull);
        expect(VorbisCommentMap.getFieldName(TagKey.custom), isNull);
        expect(VorbisCommentMap.getFieldName(TagKey.year), isNull);
      });
    });

    group('getTagKey', () {
      test('should return correct tag keys for known field names', () {
        expect(VorbisCommentMap.getTagKey('TITLE'), equals(TagKey.title));
        expect(VorbisCommentMap.getTagKey('ARTIST'), equals(TagKey.artist));
        expect(VorbisCommentMap.getTagKey('ALBUM'), equals(TagKey.album));
        expect(VorbisCommentMap.getTagKey('ALBUMARTIST'), equals(TagKey.albumArtist));
        expect(VorbisCommentMap.getTagKey('TRACKNUMBER'), equals(TagKey.trackNumber));
        expect(VorbisCommentMap.getTagKey('DISCNUMBER'), equals(TagKey.discNumber));
        expect(VorbisCommentMap.getTagKey('DATE'), equals(TagKey.dateRecorded));
        expect(VorbisCommentMap.getTagKey('GENRE'), equals(TagKey.genre));
        expect(VorbisCommentMap.getTagKey('COMMENT'), equals(TagKey.comment));
        expect(VorbisCommentMap.getTagKey('BPM'), equals(TagKey.bpm));
        expect(VorbisCommentMap.getTagKey('KEY'), equals(TagKey.musicalKey));
        expect(VorbisCommentMap.getTagKey('RATING'), equals(TagKey.rating));
        expect(VorbisCommentMap.getTagKey('LYRICS'), equals(TagKey.lyrics));
        expect(VorbisCommentMap.getTagKey('GROUPING'), equals(TagKey.grouping));
        expect(VorbisCommentMap.getTagKey('COMPOSER'), equals(TagKey.composer));
        expect(VorbisCommentMap.getTagKey('ENCODER'), equals(TagKey.encoder));
        expect(VorbisCommentMap.getTagKey('ISRC'), equals(TagKey.isrc));
      });

      test('should handle case-insensitive matching', () {
        // Test lowercase
        expect(VorbisCommentMap.getTagKey('title'), equals(TagKey.title));
        expect(VorbisCommentMap.getTagKey('artist'), equals(TagKey.artist));
        expect(VorbisCommentMap.getTagKey('album'), equals(TagKey.album));
        expect(VorbisCommentMap.getTagKey('albumartist'), equals(TagKey.albumArtist));
        expect(VorbisCommentMap.getTagKey('tracknumber'), equals(TagKey.trackNumber));
        expect(VorbisCommentMap.getTagKey('date'), equals(TagKey.dateRecorded));

        // Test mixed case
        expect(VorbisCommentMap.getTagKey('Title'), equals(TagKey.title));
        expect(VorbisCommentMap.getTagKey('Artist'), equals(TagKey.artist));
        expect(VorbisCommentMap.getTagKey('AlbumArtist'), equals(TagKey.albumArtist));
        expect(VorbisCommentMap.getTagKey('TrackNumber'), equals(TagKey.trackNumber));
        expect(VorbisCommentMap.getTagKey('Date'), equals(TagKey.dateRecorded));

        // Test random case
        expect(VorbisCommentMap.getTagKey('tItLe'), equals(TagKey.title));
        expect(VorbisCommentMap.getTagKey('aRtIsT'), equals(TagKey.artist));
        expect(VorbisCommentMap.getTagKey('aLbUmArTiSt'), equals(TagKey.albumArtist));
      });

      test('should return null for unknown field names', () {
        expect(VorbisCommentMap.getTagKey('UNKNOWN'), isNull);
        expect(VorbisCommentMap.getTagKey('CUSTOM_FIELD'), isNull);
        expect(VorbisCommentMap.getTagKey(''), isNull);
        expect(VorbisCommentMap.getTagKey('ARTWORK'), isNull);
        expect(VorbisCommentMap.getTagKey('YEAR'), isNull);
        expect(VorbisCommentMap.getTagKey('INVALID'), isNull);
      });

      test('should handle edge cases', () {
        expect(VorbisCommentMap.getTagKey(''), isNull);
        expect(VorbisCommentMap.getTagKey(' '), isNull);
        expect(VorbisCommentMap.getTagKey('  TITLE  '), isNull); // No trimming
        expect(VorbisCommentMap.getTagKey('TITLE '), isNull); // No trimming
        expect(VorbisCommentMap.getTagKey(' TITLE'), isNull); // No trimming
      });
    });

    group('isStandardField', () {
      test('should return true for standard field names', () {
        expect(VorbisCommentMap.isStandardField('TITLE'), isTrue);
        expect(VorbisCommentMap.isStandardField('ARTIST'), isTrue);
        expect(VorbisCommentMap.isStandardField('ALBUM'), isTrue);
        expect(VorbisCommentMap.isStandardField('ALBUMARTIST'), isTrue);
        expect(VorbisCommentMap.isStandardField('TRACKNUMBER'), isTrue);
        expect(VorbisCommentMap.isStandardField('DISCNUMBER'), isTrue);
        expect(VorbisCommentMap.isStandardField('DATE'), isTrue);
        expect(VorbisCommentMap.isStandardField('GENRE'), isTrue);
        expect(VorbisCommentMap.isStandardField('COMMENT'), isTrue);
        expect(VorbisCommentMap.isStandardField('BPM'), isTrue);
        expect(VorbisCommentMap.isStandardField('KEY'), isTrue);
        expect(VorbisCommentMap.isStandardField('RATING'), isTrue);
        expect(VorbisCommentMap.isStandardField('LYRICS'), isTrue);
        expect(VorbisCommentMap.isStandardField('GROUPING'), isTrue);
        expect(VorbisCommentMap.isStandardField('COMPOSER'), isTrue);
        expect(VorbisCommentMap.isStandardField('ENCODER'), isTrue);
        expect(VorbisCommentMap.isStandardField('ISRC'), isTrue);
      });

      test('should handle case-insensitive matching for standard fields', () {
        expect(VorbisCommentMap.isStandardField('title'), isTrue);
        expect(VorbisCommentMap.isStandardField('Artist'), isTrue);
        expect(VorbisCommentMap.isStandardField('aLbUm'), isTrue);
        expect(VorbisCommentMap.isStandardField('ALBUMARTIST'), isTrue);
        expect(VorbisCommentMap.isStandardField('tracknumber'), isTrue);
        expect(VorbisCommentMap.isStandardField('Date'), isTrue);
      });

      test('should return false for non-standard field names', () {
        expect(VorbisCommentMap.isStandardField('CUSTOM_FIELD'), isFalse);
        expect(VorbisCommentMap.isStandardField('MY_FIELD'), isFalse);
        expect(VorbisCommentMap.isStandardField('UNKNOWN'), isFalse);
        expect(VorbisCommentMap.isStandardField('ARTWORK'), isFalse);
        expect(VorbisCommentMap.isStandardField('YEAR'), isFalse);
        expect(VorbisCommentMap.isStandardField(''), isFalse);
        expect(VorbisCommentMap.isStandardField('INVALID'), isFalse);
      });

      test('should handle edge cases', () {
        expect(VorbisCommentMap.isStandardField(''), isFalse);
        expect(VorbisCommentMap.isStandardField(' '), isFalse);
        expect(VorbisCommentMap.isStandardField('  TITLE  '), isFalse); // No trimming
        expect(VorbisCommentMap.isStandardField('TITLE '), isFalse); // No trimming
        expect(VorbisCommentMap.isStandardField(' TITLE'), isFalse); // No trimming
      });
    });

    group('mapping completeness', () {
      test('should have no duplicate field names', () {
        final fieldNames = VorbisCommentMap.keys.values.toList();
        final uniqueNames = fieldNames.toSet();
        expect(fieldNames.length, equals(uniqueNames.length), reason: 'Should have no duplicate field names');
      });

      test('should have bidirectional mapping consistency', () {
        // Every key should map to a field name and back
        for (final entry in VorbisCommentMap.keys.entries) {
          final tagKey = entry.key;
          final fieldName = entry.value;

          expect(VorbisCommentMap.getFieldName(tagKey), equals(fieldName), reason: 'getFieldName should return consistent result for $tagKey');
          expect(VorbisCommentMap.getTagKey(fieldName), equals(tagKey), reason: 'getTagKey should return consistent result for $fieldName');
        }
      });

      test('should follow Vorbis comment naming conventions', () {
        final expectedMappings = {
          TagKey.title: 'TITLE',
          TagKey.artist: 'ARTIST',
          TagKey.album: 'ALBUM',
          TagKey.albumArtist: 'ALBUMARTIST', // No separator
          TagKey.trackNumber: 'TRACKNUMBER', // No separator
          TagKey.discNumber: 'DISCNUMBER', // No separator
          TagKey.dateRecorded: 'DATE', // Standard Vorbis date field
          TagKey.genre: 'GENRE',
          TagKey.comment: 'COMMENT',
          TagKey.bpm: 'BPM',
          TagKey.musicalKey: 'KEY', // Short form
          TagKey.rating: 'RATING',
          TagKey.lyrics: 'LYRICS',
          TagKey.grouping: 'GROUPING',
          TagKey.composer: 'COMPOSER',
          TagKey.encoder: 'ENCODER',
          TagKey.isrc: 'ISRC',
        };

        for (final entry in expectedMappings.entries) {
          expect(VorbisCommentMap.keys[entry.key], equals(entry.value), reason: '${entry.key} should map to ${entry.value}');
        }
      });

      test('should exclude fields handled by special mechanisms', () {
        // Artwork is handled via METADATA_BLOCK_PICTURE (FLAC) or base64 encoding (OGG)
        expect(VorbisCommentMap.keys.containsKey(TagKey.artwork), isFalse, reason: 'Artwork should be handled separately from standard comments');

        // Custom fields are supported natively without special mapping
        expect(VorbisCommentMap.keys.containsKey(TagKey.custom), isFalse, reason: 'Custom fields should be handled natively without mapping');

        // Year is not used in Vorbis (uses DATE instead)
        expect(VorbisCommentMap.keys.containsKey(TagKey.year), isFalse, reason: 'Year should not be used (DATE field is preferred)');
      });

      test('should support all major metadata fields', () {
        // Core identification fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.title), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.artist), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.album), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.albumArtist), isTrue);

        // Track organization fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.trackNumber), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.discNumber), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.dateRecorded), isTrue);

        // Classification fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.genre), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.grouping), isTrue);

        // Content fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.comment), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.lyrics), isTrue);

        // Technical fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.bpm), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.musicalKey), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.rating), isTrue);
        expect(VorbisCommentMap.keys.containsKey(TagKey.encoder), isTrue);

        // Credits fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.composer), isTrue);

        // Identifier fields
        expect(VorbisCommentMap.keys.containsKey(TagKey.isrc), isTrue);
      });
    });

    group('Vorbis comment standards compliance', () {
      test('should use standard field names from Vorbis specification', () {
        // These are the standard field names defined in the Vorbis comment specification
        // and widely supported by FLAC, OGG Vorbis, and OGG Opus implementations
        final standardFields = {
          'TITLE': TagKey.title,
          'ARTIST': TagKey.artist,
          'ALBUM': TagKey.album,
          'ALBUMARTIST': TagKey.albumArtist,
          'TRACKNUMBER': TagKey.trackNumber,
          'DISCNUMBER': TagKey.discNumber,
          'DATE': TagKey.dateRecorded,
          'GENRE': TagKey.genre,
          'COMMENT': TagKey.comment,
          'COMPOSER': TagKey.composer,
          'ENCODER': TagKey.encoder,
        };

        for (final entry in standardFields.entries) {
          expect(VorbisCommentMap.keys[entry.value], equals(entry.key), reason: '${entry.value} should use standard field name ${entry.key}');
        }
      });

      test('should use commonly accepted field names for extended fields', () {
        // These fields are not in the core Vorbis spec but are widely supported
        final extendedFields = {
          'BPM': TagKey.bpm,
          'KEY': TagKey.musicalKey,
          'RATING': TagKey.rating,
          'LYRICS': TagKey.lyrics,
          'GROUPING': TagKey.grouping,
          'ISRC': TagKey.isrc,
        };

        for (final entry in extendedFields.entries) {
          expect(VorbisCommentMap.keys[entry.value], equals(entry.key), reason: '${entry.value} should use commonly accepted field name ${entry.key}');
        }
      });

      test('should prefer DATE over YEAR for temporal information', () {
        // Vorbis comments typically use DATE field for temporal information
        expect(VorbisCommentMap.keys[TagKey.dateRecorded], equals('DATE'));
        expect(VorbisCommentMap.keys.containsKey(TagKey.year), isFalse);
      });

      test('should use compound field names without separators', () {
        // Vorbis comment field names typically don't use separators for compound words
        expect(VorbisCommentMap.keys[TagKey.albumArtist], equals('ALBUMARTIST'));
        expect(VorbisCommentMap.keys[TagKey.trackNumber], equals('TRACKNUMBER'));
        expect(VorbisCommentMap.keys[TagKey.discNumber], equals('DISCNUMBER'));
      });
    });
  });
}
