import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/format_constraints.dart';
import 'package:phonic/src/text_encoding.dart';

void main() {
  group('ID3v1Constraints', () {
    test('defines correct text field lengths', () {
      expect(ID3v1Constraints.maxTextLength, equals(30));
      expect(ID3v1Constraints.yearLength, equals(4));
      expect(ID3v1Constraints.commentLengthWithTrack, equals(28));
      expect(ID3v1Constraints.commentLengthWithoutTrack, equals(30));
    });

    test('defines correct numeric ranges', () {
      expect(ID3v1Constraints.minTrackNumber, equals(1));
      expect(ID3v1Constraints.maxTrackNumber, equals(255));
      expect(ID3v1Constraints.minGenreCode, equals(0));
      expect(ID3v1Constraints.maxGenreCode, equals(255));
    });

    test('defines correct format structure constants', () {
      expect(ID3v1Constraints.tagSize, equals(128));
      expect(ID3v1Constraints.tagIdentifier, equals('TAG'));
    });

    test('defines correct encoding support', () {
      expect(ID3v1Constraints.supportedEncodings, equals({TextEncoding.iso88591}));
      expect(ID3v1Constraints.supportedEncodings.length, equals(1));
    });

    test('supportedEncodingNames returns string names', () {
      final expectedNames = {TextEncoding.iso88591.standardName};
      expect(ID3v1Constraints.supportedEncodingNames, equals(expectedNames));
      expect(ID3v1Constraints.supportedEncodingNames.length, equals(1));
    });

    test('comment length constraints are logical', () {
      // Comment with track should be less than without track
      expect(ID3v1Constraints.commentLengthWithTrack, lessThan(ID3v1Constraints.commentLengthWithoutTrack));

      // Both should be less than or equal to max text length
      expect(ID3v1Constraints.commentLengthWithTrack, lessThanOrEqualTo(ID3v1Constraints.maxTextLength));
      expect(ID3v1Constraints.commentLengthWithoutTrack, lessThanOrEqualTo(ID3v1Constraints.maxTextLength));
    });

    test('track number range is valid', () {
      // Min should be positive (track 0 is not valid)
      expect(ID3v1Constraints.minTrackNumber, greaterThan(0));

      // Max should fit in a single byte
      expect(ID3v1Constraints.maxTrackNumber, equals(255));
      expect(ID3v1Constraints.minTrackNumber, lessThanOrEqualTo(ID3v1Constraints.maxTrackNumber));
    });

    test('genre code range is valid', () {
      // Min should be 0 (first standard genre)
      expect(ID3v1Constraints.minGenreCode, equals(0));

      // Max should fit in a single byte
      expect(ID3v1Constraints.maxGenreCode, equals(255));
      expect(ID3v1Constraints.minGenreCode, lessThanOrEqualTo(ID3v1Constraints.maxGenreCode));
    });

    test('tag structure size is correct', () {
      // ID3v1 tag should be exactly 128 bytes
      expect(ID3v1Constraints.tagSize, equals(128));

      // Verify the structure adds up:
      // 3 (TAG) + 30 (title) + 30 (artist) + 30 (album) + 4 (year) + 30 (comment) + 1 (genre) = 128
      const expectedSize = 3 + 30 + 30 + 30 + 4 + 30 + 1;
      expect(ID3v1Constraints.tagSize, equals(expectedSize));
    });

    test('all constraints have non-negative values', () {
      expect(ID3v1Constraints.maxTextLength, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.yearLength, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.commentLengthWithTrack, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.commentLengthWithoutTrack, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.minTrackNumber, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.maxTrackNumber, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.minGenreCode, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.maxGenreCode, greaterThanOrEqualTo(0));
      expect(ID3v1Constraints.tagSize, greaterThanOrEqualTo(0));
    });

    test('constraint values are reasonable', () {
      // Text length constraints should be reasonable
      expect(ID3v1Constraints.maxTextLength, equals(30));
      expect(ID3v1Constraints.yearLength, equals(4));
      expect(ID3v1Constraints.commentLengthWithTrack, equals(28));
      expect(ID3v1Constraints.commentLengthWithoutTrack, equals(30));

      // Numeric ranges should be valid
      expect(ID3v1Constraints.minTrackNumber, equals(1));
      expect(ID3v1Constraints.maxTrackNumber, equals(255));
      expect(ID3v1Constraints.minGenreCode, equals(0));
      expect(ID3v1Constraints.maxGenreCode, equals(255));

      // Tag size should be exactly 128 bytes
      expect(ID3v1Constraints.tagSize, equals(128));
    });
  });

  group('FieldConstraints', () {
    test('defines correct rating scale', () {
      expect(FieldConstraints.ratingMin.value, equals(0));
      expect(FieldConstraints.ratingMax.value, equals(100));
      expect(FieldConstraints.ratingMin.value, lessThan(FieldConstraints.ratingMax.value));
    });

    test('defines reasonable BPM range', () {
      expect(FieldConstraints.bpmMin.value, equals(1));
      expect(FieldConstraints.bpmMax.value, equals(999));
      expect(FieldConstraints.bpmMin.value, lessThan(FieldConstraints.bpmMax.value));
      expect(FieldConstraints.bpmMin.value, greaterThan(0));
    });

    test('rating scale is 0-100', () {
      // Standard unified rating scale
      expect(FieldConstraints.ratingMax.value - FieldConstraints.ratingMin.value, equals(100));
    });

    test('BPM range is reasonable for music', () {
      // BPM should cover typical musical range
      expect(FieldConstraints.bpmMin.value, greaterThanOrEqualTo(1));
      expect(FieldConstraints.bpmMax.value, lessThanOrEqualTo(1000)); // Very fast but possible
    });

    test('static helper methods work correctly', () {
      expect(FieldConstraints.ratingRange, equals(100));
      expect(FieldConstraints.bpmRange, equals(998));
    });

    group('validation methods', () {
      test('isValidRating validates correctly', () {
        expect(FieldConstraints.isValidRating(0), isTrue);
        expect(FieldConstraints.isValidRating(50), isTrue);
        expect(FieldConstraints.isValidRating(100), isTrue);
        expect(FieldConstraints.isValidRating(-1), isFalse);
        expect(FieldConstraints.isValidRating(101), isFalse);
      });

      test('isValidBpm validates correctly', () {
        expect(FieldConstraints.isValidBpm(1), isTrue);
        expect(FieldConstraints.isValidBpm(120), isTrue);
        expect(FieldConstraints.isValidBpm(999), isTrue);
        expect(FieldConstraints.isValidBpm(0), isFalse);
        expect(FieldConstraints.isValidBpm(1000), isFalse);
      });

      test('clampRating clamps correctly', () {
        expect(FieldConstraints.clampRating(-10), equals(0));
        expect(FieldConstraints.clampRating(0), equals(0));
        expect(FieldConstraints.clampRating(50), equals(50));
        expect(FieldConstraints.clampRating(100), equals(100));
        expect(FieldConstraints.clampRating(150), equals(100));
      });

      test('clampBpm clamps correctly', () {
        expect(FieldConstraints.clampBpm(-10), equals(1));
        expect(FieldConstraints.clampBpm(0), equals(1));
        expect(FieldConstraints.clampBpm(1), equals(1));
        expect(FieldConstraints.clampBpm(120), equals(120));
        expect(FieldConstraints.clampBpm(999), equals(999));
        expect(FieldConstraints.clampBpm(1500), equals(999));
      });
    });

    test('all constraints have non-negative values', () {
      for (final constraint in FieldConstraints.values) {
        expect(constraint.value, greaterThanOrEqualTo(0), reason: '${constraint.name} should have non-negative value');
      }
    });

    test('enum values are unique', () {
      final values = FieldConstraints.values.map((e) => e.value).toSet();
      expect(values.length, equals(FieldConstraints.values.length));
    });
  });

  group('Constraints integration', () {
    test('ID3v1 uses correct text encoding', () {
      expect(ID3v1Constraints.supportedEncodings.first, equals(TextEncoding.iso88591));
    });

    test('constants are consistent across classes', () {
      // Verify that related constants make sense together
      expect(ID3v1Constraints.commentLengthWithoutTrack, equals(ID3v1Constraints.maxTextLength));
    });

    test('encoding names match TextEncoding values', () {
      for (final encoding in ID3v1Constraints.supportedEncodings) {
        expect(ID3v1Constraints.supportedEncodingNames, contains(encoding.standardName));
      }
    });

    test('all constraint classes provide meaningful values', () {
      // Verify that ID3v1 constraints have reasonable value ranges
      expect(ID3v1Constraints.maxTextLength, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.yearLength, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.commentLengthWithTrack, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.commentLengthWithoutTrack, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.minTrackNumber, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.maxTrackNumber, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.minGenreCode, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.maxGenreCode, inInclusiveRange(0, 1000));
      expect(ID3v1Constraints.tagSize, inInclusiveRange(0, 1000));

      // Verify that FieldConstraints enum values are reasonable
      for (final constraint in FieldConstraints.values) {
        expect(constraint.value, inInclusiveRange(0, 1000));
      }
    });
  });
}
