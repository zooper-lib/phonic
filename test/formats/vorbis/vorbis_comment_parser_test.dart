import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';
import 'package:phonic/src/utils/utils.dart';

void main() {
  group('VorbisCommentParser', () {
    late VorbisCommentParser parser;

    setUp(() {
      parser = const VorbisCommentParser();
    });

    group('parseCommentString', () {
      test('parses valid comment string', () {
        final comment = parser.parseCommentString('TITLE=My Song');

        expect(comment, isNotNull);
        expect(comment!.key, equals('TITLE'));
        expect(comment.value, equals('My Song'));
        expect(comment.originalKey, equals('TITLE'));
      });

      test('normalizes key to uppercase', () {
        final comment = parser.parseCommentString('title=My Song');

        expect(comment, isNotNull);
        expect(comment!.key, equals('TITLE'));
        expect(comment.value, equals('My Song'));
        expect(comment.originalKey, equals('title'));
      });

      test('handles empty value', () {
        final comment = parser.parseCommentString('TITLE=');

        expect(comment, isNotNull);
        expect(comment!.key, equals('TITLE'));
        expect(comment.value, equals(''));
      });

      test('handles value with equals sign', () {
        final comment = parser.parseCommentString('COMMENT=This=is=a=test');

        expect(comment, isNotNull);
        expect(comment!.key, equals('COMMENT'));
        expect(comment.value, equals('This=is=a=test'));
      });

      test('handles UTF-8 characters in value', () {
        final comment = parser.parseCommentString('TITLE=Café Müller 世界');

        expect(comment, isNotNull);
        expect(comment!.key, equals('TITLE'));
        expect(comment.value, equals('Café Müller 世界'));
      });

      test('handles underscores in field name', () {
        final comment = parser.parseCommentString('CUSTOM_FIELD=value');

        expect(comment, isNotNull);
        expect(comment!.key, equals('CUSTOM_FIELD'));
        expect(comment.value, equals('value'));
      });

      test('rejects empty string', () {
        final comment = parser.parseCommentString('');
        expect(comment, isNull);
      });

      test('rejects string without equals sign', () {
        final comment = parser.parseCommentString('TITLE');
        expect(comment, isNull);
      });

      test('rejects string with empty key', () {
        final comment = parser.parseCommentString('=value');
        expect(comment, isNull);
      });

      test('rejects invalid field names', () {
        // Field name starting with number
        expect(parser.parseCommentString('1TITLE=value'), isNull);

        // Field name with special characters
        expect(parser.parseCommentString('TI-TLE=value'), isNull);
        expect(parser.parseCommentString('TI.TLE=value'), isNull);
        expect(parser.parseCommentString('TI TLE=value'), isNull);
      });

      test('accepts valid field names', () {
        // Letters only
        expect(parser.parseCommentString('TITLE=value'), isNotNull);

        // Letters and numbers
        expect(parser.parseCommentString('TRACK1=value'), isNotNull);

        // Letters, numbers, and underscores
        expect(parser.parseCommentString('CUSTOM_FIELD_1=value'), isNotNull);

        // Starting with underscore
        expect(parser.parseCommentString('_PRIVATE=value'), isNotNull);
      });

      test('can disable key normalization', () {
        final comment = parser.parseCommentString('Title=My Song', normalizeKey: false);

        expect(comment, isNotNull);
        expect(comment!.key, equals('Title'));
        expect(comment.originalKey, equals('Title'));
      });
    });

    group('parseComments', () {
      test('parses empty comment block', () {
        final emptyBytes = Uint8List(0);
        final comments = parser.parseComments(emptyBytes);

        expect(comments, isEmpty);
      });

      test('parses simple comment block', () {
        // Create a simple Vorbis comment block
        final commentBytes = _createVorbisCommentBlock([
          'TITLE=Test Song',
          'ARTIST=Test Artist',
          'ALBUM=Test Album',
        ]);

        final comments = parser.parseComments(commentBytes);

        expect(comments, hasLength(3));
        expect(comments[0].key, equals('TITLE'));
        expect(comments[0].value, equals('Test Song'));
        expect(comments[1].key, equals('ARTIST'));
        expect(comments[1].value, equals('Test Artist'));
        expect(comments[2].key, equals('ALBUM'));
        expect(comments[2].value, equals('Test Album'));
      });

      test('parses multi-valued fields', () {
        final commentBytes = _createVorbisCommentBlock([
          'GENRE=Rock',
          'GENRE=Alternative',
          'GENRE=Indie',
          'ARTIST=Primary Artist',
          'ARTIST=Featured Artist',
        ]);

        final comments = parser.parseComments(commentBytes);

        expect(comments, hasLength(5));

        final genres = comments.where((c) => c.key == 'GENRE').toList();
        expect(genres, hasLength(3));
        expect(genres[0].value, equals('Rock'));
        expect(genres[1].value, equals('Alternative'));
        expect(genres[2].value, equals('Indie'));

        final artists = comments.where((c) => c.key == 'ARTIST').toList();
        expect(artists, hasLength(2));
        expect(artists[0].value, equals('Primary Artist'));
        expect(artists[1].value, equals('Featured Artist'));
      });

      test('handles UTF-8 encoded values', () {
        final commentBytes = _createVorbisCommentBlock([
          'TITLE=Café Müller',
          'ARTIST=Björk',
          'ALBUM=世界音楽',
          'COMMENT=Тест комментарий',
        ]);

        final comments = parser.parseComments(commentBytes);

        expect(comments, hasLength(4));
        expect(comments[0].value, equals('Café Müller'));
        expect(comments[1].value, equals('Björk'));
        expect(comments[2].value, equals('世界音楽'));
        expect(comments[3].value, equals('Тест комментарий'));
      });

      test('handles case-insensitive field names', () {
        final commentBytes = _createVorbisCommentBlock([
          'title=Test Song',
          'ARTIST=Test Artist',
          'Album=Test Album',
        ]);

        final comments = parser.parseComments(commentBytes);

        expect(comments, hasLength(3));
        expect(comments[0].key, equals('TITLE'));
        expect(comments[0].originalKey, equals('title'));
        expect(comments[1].key, equals('ARTIST'));
        expect(comments[1].originalKey, equals('ARTIST'));
        expect(comments[2].key, equals('ALBUM'));
        expect(comments[2].originalKey, equals('Album'));
      });

      test('skips malformed comments', () {
        final commentBytes = _createVorbisCommentBlock([
          'TITLE=Valid Song',
          'INVALID_NO_EQUALS',
          '=EMPTY_KEY',
          'ARTIST=Valid Artist',
          '1INVALID=starts with number',
        ]);

        final comments = parser.parseComments(commentBytes);

        // Should only parse the valid comments
        expect(comments, hasLength(2));
        expect(comments[0].key, equals('TITLE'));
        expect(comments[0].value, equals('Valid Song'));
        expect(comments[1].key, equals('ARTIST'));
        expect(comments[1].value, equals('Valid Artist'));
      });

      test('handles empty comments', () {
        final commentBytes = _createVorbisCommentBlock([
          'TITLE=Test Song',
          '', // Empty comment
          'ARTIST=Test Artist',
        ]);

        final comments = parser.parseComments(commentBytes);

        // Should skip empty comment
        expect(comments, hasLength(2));
        expect(comments[0].key, equals('TITLE'));
        expect(comments[1].key, equals('ARTIST'));
      });

      test('handles truncated comment block gracefully', () {
        // Create a comment block but truncate it
        final fullBytes = _createVorbisCommentBlock(['TITLE=Test Song']);
        final truncatedBytes = fullBytes.sublist(0, fullBytes.length - 5);

        // Should not throw, just return what it can parse
        expect(() => parser.parseComments(truncatedBytes), returnsNormally);
      });

      test('throws FormatException for invalid vendor length', () {
        // Create invalid comment block with vendor length exceeding data
        final invalidBytes = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid vendor length (too large)
          0x00, 0x00, 0x00, 0x00, // User comment list length
        ]);

        expect(
          () => parser.parseComments(invalidBytes),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('getFieldValues', () {
      late List<VorbisComment> testComments;

      setUp(() {
        testComments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
          const VorbisComment(key: 'GENRE', value: 'Rock'),
          const VorbisComment(key: 'GENRE', value: 'Alternative'),
          const VorbisComment(key: 'GENRE', value: 'Indie'),
          const VorbisComment(key: 'ALBUM', value: 'Test Album'),
        ];
      });

      test('returns all values for multi-valued field', () {
        final genres = parser.getFieldValues(testComments, 'GENRE');

        expect(genres, hasLength(3));
        expect(genres, containsAll(['Rock', 'Alternative', 'Indie']));
      });

      test('returns single value for single-valued field', () {
        final titles = parser.getFieldValues(testComments, 'TITLE');

        expect(titles, hasLength(1));
        expect(titles.first, equals('Test Song'));
      });

      test('returns empty list for non-existent field', () {
        final missing = parser.getFieldValues(testComments, 'MISSING');

        expect(missing, isEmpty);
      });

      test('performs case-insensitive matching', () {
        final titles = parser.getFieldValues(testComments, 'title');

        expect(titles, hasLength(1));
        expect(titles.first, equals('Test Song'));
      });
    });

    group('groupCommentsByField', () {
      test('groups comments correctly', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'GENRE', value: 'Rock'),
          const VorbisComment(key: 'GENRE', value: 'Alternative'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
        ];

        final grouped = parser.groupCommentsByField(comments);

        expect(grouped, hasLength(3));
        expect(grouped['TITLE'], equals(['Test Song']));
        expect(grouped['GENRE'], equals(['Rock', 'Alternative']));
        expect(grouped['ARTIST'], equals(['Test Artist']));
      });

      test('handles empty comment list', () {
        final grouped = parser.groupCommentsByField([]);

        expect(grouped, isEmpty);
      });
    });

    group('filterStandardFields', () {
      test('filters to standard fields only', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
          const VorbisComment(key: 'CUSTOM_FIELD', value: 'Custom Value'),
          const VorbisComment(key: 'ANOTHER_CUSTOM', value: 'Another Value'),
          const VorbisComment(key: 'ALBUM', value: 'Test Album'),
        ];

        final standardComments = parser.filterStandardFields(comments);

        expect(standardComments, hasLength(3));
        expect(standardComments.map((c) => c.key), containsAll(['TITLE', 'ARTIST', 'ALBUM']));
      });
    });

    group('filterCustomFields', () {
      test('filters to custom fields only', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
          const VorbisComment(key: 'CUSTOM_FIELD', value: 'Custom Value'),
          const VorbisComment(key: 'ANOTHER_CUSTOM', value: 'Another Value'),
          const VorbisComment(key: 'ALBUM', value: 'Test Album'),
        ];

        final customComments = parser.filterCustomFields(comments);

        expect(customComments, hasLength(2));
        expect(customComments.map((c) => c.key), containsAll(['CUSTOM_FIELD', 'ANOTHER_CUSTOM']));
      });
    });

    group('getFirstFieldValue', () {
      test('returns first value for field', () {
        final comments = [
          const VorbisComment(key: 'GENRE', value: 'Rock'),
          const VorbisComment(key: 'GENRE', value: 'Alternative'),
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
        ];

        final firstGenre = parser.getFirstFieldValue(comments, 'GENRE');
        final title = parser.getFirstFieldValue(comments, 'TITLE');

        expect(firstGenre, equals('Rock'));
        expect(title, equals('Test Song'));
      });

      test('returns null for non-existent field', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
        ];

        final missing = parser.getFirstFieldValue(comments, 'MISSING');

        expect(missing, isNull);
      });

      test('performs case-insensitive matching', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
        ];

        final title = parser.getFirstFieldValue(comments, 'title');

        expect(title, equals('Test Song'));
      });
    });

    group('hasField', () {
      test('returns true for existing field', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
        ];

        expect(parser.hasField(comments, 'TITLE'), isTrue);
        expect(parser.hasField(comments, 'ARTIST'), isTrue);
      });

      test('returns false for non-existent field', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
        ];

        expect(parser.hasField(comments, 'MISSING'), isFalse);
      });

      test('performs case-insensitive matching', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
        ];

        expect(parser.hasField(comments, 'title'), isTrue);
        expect(parser.hasField(comments, 'Title'), isTrue);
      });
    });

    group('getCommentStats', () {
      test('calculates statistics correctly', () {
        final comments = [
          const VorbisComment(key: 'TITLE', value: 'Test Song'),
          const VorbisComment(key: 'ARTIST', value: 'Test Artist'),
          const VorbisComment(key: 'GENRE', value: 'Rock'),
          const VorbisComment(key: 'GENRE', value: 'Alternative'),
          const VorbisComment(key: 'CUSTOM_FIELD', value: 'Custom Value'),
        ];

        final stats = parser.getCommentStats(comments);

        expect(stats.totalComments, equals(5));
        expect(stats.uniqueFields, equals(4));
        expect(stats.standardFields, equals(4)); // TITLE, ARTIST, GENRE x2
        expect(stats.customFields, equals(1)); // CUSTOM_FIELD
        expect(stats.multiValuedFields, contains('GENRE'));
        expect(stats.fieldCounts['GENRE'], equals(2));
        expect(stats.fieldCounts['TITLE'], equals(1));
      });

      test('handles empty comment list', () {
        final stats = parser.getCommentStats([]);

        expect(stats.totalComments, equals(0));
        expect(stats.uniqueFields, equals(0));
        expect(stats.standardFields, equals(0));
        expect(stats.customFields, equals(0));
        expect(stats.multiValuedFields, isEmpty);
        expect(stats.fieldCounts, isEmpty);
      });
    });
  });

  group('VorbisComment', () {
    test('creates comment with all properties', () {
      const comment = VorbisComment(
        key: 'TITLE',
        value: 'Test Song',
        originalKey: 'title',
      );

      expect(comment.key, equals('TITLE'));
      expect(comment.value, equals('Test Song'));
      expect(comment.originalKey, equals('title'));
    });

    test('defaults originalKey to key when not provided', () {
      const comment = VorbisComment(
        key: 'TITLE',
        value: 'Test Song',
      );

      expect(comment.originalKey, equals('TITLE'));
    });

    test('returns correct tagKey for standard fields', () {
      const titleComment = VorbisComment(key: 'TITLE', value: 'Test');
      const artistComment = VorbisComment(key: 'ARTIST', value: 'Test');
      const customComment = VorbisComment(key: 'CUSTOM', value: 'Test');

      expect(titleComment.tagKey, equals(TagKey.title));
      expect(artistComment.tagKey, equals(TagKey.artist));
      expect(customComment.tagKey, isNull);
    });

    test('identifies standard vs custom fields correctly', () {
      const standardComment = VorbisComment(key: 'TITLE', value: 'Test');
      const customComment = VorbisComment(key: 'CUSTOM', value: 'Test');

      expect(standardComment.isStandardField, isTrue);
      expect(standardComment.isCustomField, isFalse);
      expect(customComment.isStandardField, isFalse);
      expect(customComment.isCustomField, isTrue);
    });

    test('toString returns key=value format', () {
      const comment = VorbisComment(key: 'TITLE', value: 'Test Song');

      expect(comment.toString(), equals('TITLE=Test Song'));
    });

    test('equality works correctly', () {
      const comment1 = VorbisComment(key: 'TITLE', value: 'Test', originalKey: 'title');
      const comment2 = VorbisComment(key: 'TITLE', value: 'Test', originalKey: 'title');
      const comment3 = VorbisComment(key: 'TITLE', value: 'Different', originalKey: 'title');

      expect(comment1, equals(comment2));
      expect(comment1, isNot(equals(comment3)));
    });

    test('hashCode works correctly', () {
      const comment1 = VorbisComment(key: 'TITLE', value: 'Test', originalKey: 'title');
      const comment2 = VorbisComment(key: 'TITLE', value: 'Test', originalKey: 'title');

      expect(comment1.hashCode, equals(comment2.hashCode));
    });
  });

  group('VorbisCommentStats', () {
    test('toString provides useful information', () {
      const stats = VorbisCommentStats(
        totalComments: 10,
        uniqueFields: 5,
        standardFields: 8,
        customFields: 2,
        multiValuedFields: ['GENRE', 'ARTIST'],
        fieldCounts: {'TITLE': 1, 'GENRE': 3},
      );

      final string = stats.toString();

      expect(string, contains('total: 10'));
      expect(string, contains('unique: 5'));
      expect(string, contains('standard: 8'));
      expect(string, contains('custom: 2'));
      expect(string, contains('multiValued: 2'));
    });
  });
}

/// Helper function to create a Vorbis comment block for testing.
///
/// This creates a minimal valid Vorbis comment block with the given
/// comment strings. The format follows the Vorbis specification:
/// - vendor_length (4 bytes, little-endian)
/// - vendor_string (UTF-8)
/// - user_comment_list_length (4 bytes, little-endian)
/// - For each comment:
///   - comment_length (4 bytes, little-endian)
///   - comment_string (UTF-8)
Uint8List _createVorbisCommentBlock(List<String> comments) {
  final buffer = <int>[];

  // Vendor string (using empty vendor for simplicity)
  const vendorString = '';
  final vendorBytes = utf8.encode(vendorString);

  // Write vendor length (little-endian)
  buffer.addAll(_uint32ToLittleEndian(vendorBytes.length));

  // Write vendor string
  buffer.addAll(vendorBytes);

  // Write user comment list length (little-endian)
  buffer.addAll(_uint32ToLittleEndian(comments.length));

  // Write each comment
  for (final comment in comments) {
    final commentBytes = utf8.encode(comment);

    // Write comment length (little-endian)
    buffer.addAll(_uint32ToLittleEndian(commentBytes.length));

    // Write comment string
    buffer.addAll(commentBytes);
  }

  return Uint8List.fromList(buffer);
}

/// Converts a 32-bit unsigned integer to little-endian bytes.
List<int> _uint32ToLittleEndian(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}
