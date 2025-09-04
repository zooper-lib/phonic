import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/exceptions/phonic_exception.dart';
import 'package:phonic/src/exceptions/tag_validation_exception.dart';
import 'package:test/test.dart';

void main() {
  group('TagValidationException', () {
    group('constructor', () {
      test('creates exception with tagKey and reason only', () {
        final exception = TagValidationException(TagKey.title, 'Title exceeds maximum length');

        expect(exception.tagKey, equals(TagKey.title));
        expect(exception.reason, equals('Title exceeds maximum length'));
        expect(exception.message, equals('Tag validation failed for TagKey.title: Title exceeds maximum length'));
        expect(exception.context, isNull);
      });

      test('creates exception with tagKey, reason, and context', () {
        final exception = TagValidationException(
          TagKey.rating,
          'Rating value outside allowed range',
          context: 'value: 150, allowed: 0-100',
        );

        expect(exception.tagKey, equals(TagKey.rating));
        expect(exception.reason, equals('Rating value outside allowed range'));
        expect(exception.message, equals('Tag validation failed for TagKey.rating: Rating value outside allowed range'));
        expect(exception.context, equals('value: 150, allowed: 0-100'));
      });

      test('creates exception with empty reason', () {
        final exception = TagValidationException(TagKey.artist, '');

        expect(exception.tagKey, equals(TagKey.artist));
        expect(exception.reason, equals(''));
        expect(exception.message, equals('Tag validation failed for TagKey.artist: '));
        expect(exception.context, isNull);
      });

      test('creates exception with empty context', () {
        final exception = TagValidationException(
          TagKey.album,
          'Album validation failed',
          context: '',
        );

        expect(exception.tagKey, equals(TagKey.album));
        expect(exception.reason, equals('Album validation failed'));
        expect(exception.context, equals(''));
      });

      test('creates exception for all TagKey values', () {
        for (final tagKey in TagKey.values) {
          final exception = TagValidationException(tagKey, 'Test validation failure');

          expect(exception.tagKey, equals(tagKey));
          expect(exception.reason, equals('Test validation failure'));
          expect(exception.message, contains(tagKey.toString()));
        }
      });
    });

    group('inheritance', () {
      test('extends PhonicException', () {
        final exception = TagValidationException(TagKey.title, 'Test message');

        expect(exception, isA<PhonicException>());
        expect(exception, isA<Exception>());
      });

      test('implements Exception interface', () {
        final exception = TagValidationException(TagKey.title, 'Test message');

        expect(exception, isA<Exception>());
      });

      test('is a final class', () {
        final exception = TagValidationException(TagKey.title, 'Test message');

        expect(exception.runtimeType.toString(), equals('TagValidationException'));
      });

      test('inherits PhonicException properties', () {
        final exception = TagValidationException(
          TagKey.genre,
          'Genre validation failed',
          context: 'test context',
        );

        expect(exception.message, contains('Tag validation failed'));
        expect(exception.context, equals('test context'));
      });
    });

    group('toString', () {
      test('formats message without context', () {
        final exception = TagValidationException(TagKey.title, 'Title too long');

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.title: Title too long'),
        );
      });

      test('formats message with context', () {
        final exception = TagValidationException(
          TagKey.rating,
          'Rating out of range',
          context: 'value: 150, container: ID3v1',
        );

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.rating: Rating out of range (Context: value: 150, container: ID3v1)'),
        );
      });

      test('handles empty reason', () {
        final exception = TagValidationException(TagKey.bpm, '');

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.bpm: '),
        );
      });

      test('handles empty context', () {
        final exception = TagValidationException(
          TagKey.trackNumber,
          'Invalid track number',
          context: '',
        );

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.trackNumber: Invalid track number (Context: )'),
        );
      });

      test('handles special characters in reason', () {
        final exception = TagValidationException(
          TagKey.comment,
          'Comment contains invalid characters: "\\n\\t"',
        );

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.comment: Comment contains invalid characters: "\\n\\t"'),
        );
      });

      test('handles special characters in context', () {
        final exception = TagValidationException(
          TagKey.title,
          'Title validation failed',
          context: 'file: "my song.mp3", path: C:\\Music\\file.mp3',
        );

        expect(
          exception.toString(),
          equals(
            'TagValidationException: Tag validation failed for TagKey.title: Title validation failed (Context: file: "my song.mp3", path: C:\\Music\\file.mp3)',
          ),
        );
      });

      test('handles multiline reason and context', () {
        final exception = TagValidationException(
          TagKey.lyrics,
          'Line 1\nLine 2',
          context: 'Context 1\nContext 2',
        );

        expect(
          exception.toString(),
          equals('TagValidationException: Tag validation failed for TagKey.lyrics: Line 1\nLine 2 (Context: Context 1\nContext 2)'),
        );
      });
    });

    group('tagKey property', () {
      test('stores tagKey correctly for all enum values', () {
        for (final tagKey in TagKey.values) {
          final exception = TagValidationException(tagKey, 'Test reason');

          expect(exception.tagKey, equals(tagKey));
        }
      });

      test('tagKey is immutable', () {
        final exception = TagValidationException(TagKey.artist, 'Test reason');

        expect(exception.tagKey, equals(TagKey.artist));
        // The tagKey field is final, so attempting to modify would cause a compile error
      });
    });

    group('reason property', () {
      test('stores reason correctly', () {
        const testReason = 'This is a test validation failure reason';
        final exception = TagValidationException(TagKey.album, testReason);

        expect(exception.reason, equals(testReason));
      });

      test('stores empty reason correctly', () {
        final exception = TagValidationException(TagKey.genre, '');

        expect(exception.reason, equals(''));
      });

      test('stores multiline reason correctly', () {
        const multilineReason = 'Line 1\nLine 2\nLine 3';
        final exception = TagValidationException(TagKey.comment, multilineReason);

        expect(exception.reason, equals(multilineReason));
      });

      test('reason is immutable', () {
        final exception = TagValidationException(TagKey.title, 'Original reason');

        expect(exception.reason, equals('Original reason'));
        // The reason field is final, so attempting to modify would cause a compile error
      });
    });

    group('equality and immutability', () {
      test('instances with same values have same properties', () {
        final exception1 = TagValidationException(
          TagKey.rating,
          'Same reason',
          context: 'same context',
        );
        final exception2 = TagValidationException(
          TagKey.rating,
          'Same reason',
          context: 'same context',
        );

        expect(exception1.tagKey, equals(exception2.tagKey));
        expect(exception1.reason, equals(exception2.reason));
        expect(exception1.message, equals(exception2.message));
        expect(exception1.context, equals(exception2.context));
      });

      test('all properties are immutable', () {
        final exception = TagValidationException(
          TagKey.bpm,
          'Original reason',
          context: 'Original context',
        );

        expect(exception.tagKey, equals(TagKey.bpm));
        expect(exception.reason, equals('Original reason'));
        expect(exception.context, equals('Original context'));
        // All fields are final, so attempting to modify would cause compile errors
      });
    });

    group('validation scenarios', () {
      group('length constraints', () {
        test('handles ID3v1 title length violation', () {
          final exception = TagValidationException(
            TagKey.title,
            'Title length 45 exceeds ID3v1 limit of 30 characters',
            context: 'container: ID3v1, value: "This is a very long title that exceeds the limit"',
          );

          expect(exception.tagKey, equals(TagKey.title));
          expect(exception.reason, contains('45 exceeds'));
          expect(exception.context, contains('ID3v1'));
        });

        test('handles ID3v1 comment length with track number', () {
          final exception = TagValidationException(
            TagKey.comment,
            'Comment length 30 exceeds ID3v1 limit of 28 characters when track number is present',
            context: 'container: ID3v1, track: 5, comment: "This comment is too long for ID3v1"',
          );

          expect(exception.tagKey, equals(TagKey.comment));
          expect(exception.reason, contains('28 characters'));
          expect(exception.context, contains('track: 5'));
        });

        test('handles artist name length violation', () {
          final exception = TagValidationException(
            TagKey.artist,
            'Artist name length 50 exceeds container limit of 30 characters',
            context: 'container: ID3v1, value: "The Really Really Long Band Name That Exceeds Limits"',
          );

          expect(exception.tagKey, equals(TagKey.artist));
          expect(exception.reason, contains('50 exceeds'));
        });

        test('handles album name length violation', () {
          final exception = TagValidationException(
            TagKey.album,
            'Album name length 35 exceeds ID3v1 limit of 30 characters',
            context: 'container: ID3v1, value: "The Complete Works of Classical Music"',
          );

          expect(exception.tagKey, equals(TagKey.album));
          expect(exception.reason, contains('35 exceeds'));
        });
      });

      group('value range constraints', () {
        test('handles rating value too high', () {
          final exception = TagValidationException(
            TagKey.rating,
            'Rating value 150 is outside allowed range of 0-100',
            context: 'container: ID3v2.4, operation: setTag',
          );

          expect(exception.tagKey, equals(TagKey.rating));
          expect(exception.reason, contains('150 is outside'));
          expect(exception.reason, contains('0-100'));
        });

        test('handles rating value too low', () {
          final exception = TagValidationException(
            TagKey.rating,
            'Rating value -10 is outside allowed range of 0-100',
            context: 'container: Vorbis, operation: setTag',
          );

          expect(exception.tagKey, equals(TagKey.rating));
          expect(exception.reason, contains('-10 is outside'));
        });

        test('handles invalid track number', () {
          final exception = TagValidationException(
            TagKey.trackNumber,
            'Track number must be a positive integer, got 0',
            context: 'container: ID3v2.3, value: 0',
          );

          expect(exception.tagKey, equals(TagKey.trackNumber));
          expect(exception.reason, contains('positive integer'));
          expect(exception.reason, contains('got 0'));
        });

        test('handles negative track number', () {
          final exception = TagValidationException(
            TagKey.trackNumber,
            'Track number must be a positive integer, got -5',
            context: 'container: MP4, value: -5',
          );

          expect(exception.tagKey, equals(TagKey.trackNumber));
          expect(exception.reason, contains('got -5'));
        });

        test('handles invalid disc number', () {
          final exception = TagValidationException(
            TagKey.discNumber,
            'Disc number must be a positive integer, got 0',
            context: 'container: FLAC, value: 0',
          );

          expect(exception.tagKey, equals(TagKey.discNumber));
          expect(exception.reason, contains('Disc number'));
        });

        test('handles BPM out of range', () {
          final exception = TagValidationException(
            TagKey.bpm,
            'BPM value 0 must be positive',
            context: 'container: ID3v2.4, value: 0',
          );

          expect(exception.tagKey, equals(TagKey.bpm));
          expect(exception.reason, contains('must be positive'));
        });

        test('handles BPM too high', () {
          final exception = TagValidationException(
            TagKey.bpm,
            'BPM value 1500 exceeds reasonable maximum of 999',
            context: 'container: Vorbis, value: 1500',
          );

          expect(exception.tagKey, equals(TagKey.bpm));
          expect(exception.reason, contains('1500 exceeds'));
        });

        test('handles invalid year', () {
          final exception = TagValidationException(
            TagKey.year,
            'Year value 12345 is outside reasonable range of 1900-2100',
            context: 'container: ID3v1, value: 12345',
          );

          expect(exception.tagKey, equals(TagKey.year));
          expect(exception.reason, contains('12345 is outside'));
        });
      });

      group('format constraints', () {
        test('handles invalid date format', () {
          final exception = TagValidationException(
            TagKey.dateRecorded,
            'Date format "March 15, 2023" is not valid ISO-8601',
            context: 'container: ID3v2.4, expected: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS',
          );

          expect(exception.tagKey, equals(TagKey.dateRecorded));
          expect(exception.reason, contains('not valid ISO-8601'));
          expect(exception.context, contains('YYYY-MM-DD'));
        });

        test('handles invalid ISRC format', () {
          final exception = TagValidationException(
            TagKey.isrc,
            'ISRC format "INVALID-CODE" does not match pattern CC-XXX-YY-NNNNN',
            context: 'container: ID3v2.4, value: "INVALID-CODE"',
          );

          expect(exception.tagKey, equals(TagKey.isrc));
          expect(exception.reason, contains('does not match pattern'));
          expect(exception.reason, contains('CC-XXX-YY-NNNNN'));
        });

        test('handles empty required field', () {
          final exception = TagValidationException(
            TagKey.title,
            'Title cannot be empty',
            context: 'container: ID3v2.3, operation: setTag',
          );

          expect(exception.tagKey, equals(TagKey.title));
          expect(exception.reason, contains('cannot be empty'));
        });

        test('handles invalid encoding', () {
          final exception = TagValidationException(
            TagKey.comment,
            'Text contains invalid UTF-8 sequences',
            context: 'container: Vorbis, invalid bytes: [0xFF, 0xFE]',
          );

          expect(exception.tagKey, equals(TagKey.comment));
          expect(exception.reason, contains('invalid UTF-8'));
        });
      });

      group('container support constraints', () {
        test('handles unsupported field in ID3v1', () {
          final exception = TagValidationException(
            TagKey.bpm,
            'BPM field is not supported by ID3v1 container',
            context: 'container: ID3v1, supported fields: title, artist, album, year, comment, genre, track',
          );

          expect(exception.tagKey, equals(TagKey.bpm));
          expect(exception.reason, contains('not supported by ID3v1'));
        });

        test('handles artwork not supported in ID3v1', () {
          final exception = TagValidationException(
            TagKey.artwork,
            'Artwork field is not supported by ID3v1 container',
            context: 'container: ID3v1, operation: setTag',
          );

          expect(exception.tagKey, equals(TagKey.artwork));
          expect(exception.reason, contains('not supported by ID3v1'));
        });

        test('handles lyrics not supported in ID3v1', () {
          final exception = TagValidationException(
            TagKey.lyrics,
            'Lyrics field is not supported by ID3v1 container',
            context: 'container: ID3v1, operation: setTag',
          );

          expect(exception.tagKey, equals(TagKey.lyrics));
          expect(exception.reason, contains('not supported by ID3v1'));
        });

        test('handles multi-valued field in single-value container', () {
          final exception = TagValidationException(
            TagKey.genre,
            'Multiple genre values not supported by this container format',
            context: 'container: ID3v1, values: ["Rock", "Alternative", "Indie"]',
          );

          expect(exception.tagKey, equals(TagKey.genre));
          expect(exception.reason, contains('Multiple genre values'));
        });

        test('handles custom field not supported', () {
          final exception = TagValidationException(
            TagKey.custom,
            'Custom fields are not supported by ID3v1 container',
            context: 'container: ID3v1, field: "CUSTOM_FIELD"',
          );

          expect(exception.tagKey, equals(TagKey.custom));
          expect(exception.reason, contains('Custom fields'));
        });
      });
    });

    group('exception throwing and catching', () {
      test('can be thrown and caught as TagValidationException', () {
        expect(
          () => throw TagValidationException(TagKey.title, 'Test exception'),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('can be caught as PhonicException', () {
        expect(
          () => throw TagValidationException(TagKey.rating, 'Test exception'),
          throwsA(isA<PhonicException>()),
        );
      });

      test('can be caught as Exception', () {
        expect(
          () => throw TagValidationException(TagKey.album, 'Test exception'),
          throwsA(isA<Exception>()),
        );
      });

      test('preserves all properties when caught', () {
        const originalTagKey = TagKey.bpm;
        const originalReason = 'Original validation failure';
        const originalContext = 'Original context';

        try {
          throw TagValidationException(
            originalTagKey,
            originalReason,
            context: originalContext,
          );
        } on TagValidationException catch (e) {
          expect(e.tagKey, equals(originalTagKey));
          expect(e.reason, equals(originalReason));
          expect(e.context, equals(originalContext));
          expect(e.message, contains(originalReason));
        }
      });

      test('can be caught as base class and properties accessed', () {
        const originalTagKey = TagKey.trackNumber;
        const originalReason = 'Base class test';
        const originalContext = 'Base context';

        try {
          throw TagValidationException(
            originalTagKey,
            originalReason,
            context: originalContext,
          );
        } on PhonicException catch (e) {
          expect(e.message, contains(originalReason));
          expect(e.context, equals(originalContext));

          if (e is TagValidationException) {
            expect(e.tagKey, equals(originalTagKey));
            expect(e.reason, equals(originalReason));
          }
        }
      });
    });

    group('real-world validation scenarios', () {
      test('handles MP3 file with oversized title for ID3v1', () {
        final exception = TagValidationException(
          TagKey.title,
          'Title "The Complete Collection of Classical Music Masterpieces" exceeds ID3v1 limit of 30 characters',
          context: 'file: classical.mp3, container: ID3v1, length: 67, limit: 30',
        );

        expect(exception.tagKey, equals(TagKey.title));
        expect(exception.reason, contains('exceeds ID3v1 limit'));
        expect(exception.context, contains('classical.mp3'));
      });

      test('handles FLAC file with invalid rating', () {
        final exception = TagValidationException(
          TagKey.rating,
          'Rating value 255 from ID3v2 scale must be converted to 0-100 range',
          context: 'file: song.flac, source: ID3v2 POPM frame, raw value: 255',
        );

        expect(exception.tagKey, equals(TagKey.rating));
        expect(exception.reason, contains('converted to 0-100'));
        expect(exception.context, contains('POPM frame'));
      });

      test('handles M4A file with unsupported custom field', () {
        final exception = TagValidationException(
          TagKey.custom,
          'Custom field "MY_CUSTOM_TAG" cannot be mapped to MP4 atom format',
          context: 'file: track.m4a, container: MP4, field: "MY_CUSTOM_TAG"',
        );

        expect(exception.tagKey, equals(TagKey.custom));
        expect(exception.reason, contains('cannot be mapped'));
        expect(exception.context, contains('MP4'));
      });

      test('handles OGG file with invalid date', () {
        final exception = TagValidationException(
          TagKey.dateRecorded,
          'Date "2023/03/15" must be in ISO-8601 format for Vorbis comments',
          context: 'file: music.ogg, container: Vorbis, expected: "2023-03-15"',
        );

        expect(exception.tagKey, equals(TagKey.dateRecorded));
        expect(exception.reason, contains('ISO-8601 format'));
        expect(exception.context, contains('Vorbis'));
      });

      test('handles batch validation with multiple errors', () {
        final titleException = TagValidationException(
          TagKey.title,
          'Title too long for ID3v1',
          context: 'batch operation: file1.mp3',
        );
        final ratingException = TagValidationException(
          TagKey.rating,
          'Rating out of range',
          context: 'batch operation: file2.mp3',
        );

        expect(titleException.tagKey, equals(TagKey.title));
        expect(ratingException.tagKey, equals(TagKey.rating));
        expect(titleException.context, contains('batch operation'));
        expect(ratingException.context, contains('batch operation'));
      });

      test('handles genre validation with multiple values', () {
        final exception = TagValidationException(
          TagKey.genre,
          'ID3v1 container supports only single genre, got 3 values',
          context: 'file: multi-genre.mp3, values: ["Rock", "Alternative", "Indie"], container: ID3v1',
        );

        expect(exception.tagKey, equals(TagKey.genre));
        expect(exception.reason, contains('single genre'));
        expect(exception.reason, contains('3 values'));
      });

      test('handles track number validation edge cases', () {
        final exception = TagValidationException(
          TagKey.trackNumber,
          'Track number 256 exceeds ID3v1 maximum of 255',
          context: 'file: track256.mp3, container: ID3v1, value: 256',
        );

        expect(exception.tagKey, equals(TagKey.trackNumber));
        expect(exception.reason, contains('exceeds ID3v1 maximum'));
      });

      test('handles BPM validation for different containers', () {
        final exception = TagValidationException(
          TagKey.bpm,
          'BPM field not supported in ID3v1, will be omitted',
          context: 'file: dance.mp3, container: ID3v1, bpm: 128',
        );

        expect(exception.tagKey, equals(TagKey.bpm));
        expect(exception.reason, contains('not supported in ID3v1'));
      });

      test('handles artwork size validation', () {
        final exception = TagValidationException(
          TagKey.artwork,
          'Artwork size 10MB exceeds recommended maximum of 2MB',
          context: 'file: album.flac, container: FLAC, size: 10485760 bytes',
        );

        expect(exception.tagKey, equals(TagKey.artwork));
        expect(exception.reason, contains('exceeds recommended maximum'));
        expect(exception.context, contains('10485760 bytes'));
      });

      test('handles lyrics encoding validation', () {
        final exception = TagValidationException(
          TagKey.lyrics,
          'Lyrics contain non-UTF-8 characters incompatible with Vorbis comments',
          context: 'file: song.ogg, container: Vorbis, encoding issue at position: 245',
        );

        expect(exception.tagKey, equals(TagKey.lyrics));
        expect(exception.reason, contains('non-UTF-8 characters'));
        expect(exception.context, contains('position: 245'));
      });
    });

    group('validation error recovery scenarios', () {
      test('provides actionable error message for truncation', () {
        final exception = TagValidationException(
          TagKey.title,
          'Title will be truncated from 45 to 30 characters for ID3v1 compatibility',
          context: 'original: "The Complete Works of Bach", truncated: "The Complete Works of Bach"',
        );

        expect(exception.reason, contains('will be truncated'));
        expect(exception.context, contains('original:'));
        expect(exception.context, contains('truncated:'));
      });

      test('provides suggestion for rating conversion', () {
        final exception = TagValidationException(
          TagKey.rating,
          'Rating 255 will be converted to 100 for unified scale',
          context: 'source: ID3v2 POPM (0-255), target: unified (0-100)',
        );

        expect(exception.reason, contains('will be converted'));
        expect(exception.context, contains('source:'));
        expect(exception.context, contains('target:'));
      });

      test('provides field omission warning', () {
        final exception = TagValidationException(
          TagKey.bpm,
          'BPM field will be omitted for ID3v1 container (not supported)',
          context: 'value: 120, target containers: [ID3v2.4, ID3v1], omitted from: ID3v1',
        );

        expect(exception.reason, contains('will be omitted'));
        expect(exception.context, contains('target containers'));
      });
    });
  });
}
