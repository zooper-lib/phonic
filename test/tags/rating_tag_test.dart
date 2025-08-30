import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('RatingTag', () {
    group('constructor', () {
      test('creates instance with valid rating and default provenance', () {
        final tag = RatingTag(75);

        expect(tag.value, equals(75));
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid rating and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = RatingTag(85, provenance: provenance);

        expect(tag.value, equals(85));
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with minimum valid rating', () {
        final tag = RatingTag(0);

        expect(tag.value, equals(0));
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with maximum valid rating', () {
        final tag = RatingTag(100);

        expect(tag.value, equals(100));
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with common rating values', () {
        final tag0 = RatingTag(0); // Unrated/poor
        final tag25 = RatingTag(25); // Poor
        final tag50 = RatingTag(50); // Average
        final tag75 = RatingTag(75); // Good
        final tag100 = RatingTag(100); // Excellent

        expect(tag0.value, equals(0));
        expect(tag25.value, equals(25));
        expect(tag50.value, equals(50));
        expect(tag75.value, equals(75));
        expect(tag100.value, equals(100));
      });

      test('creates instance with star-based rating equivalents', () {
        final onestar = RatingTag(20); // 1 star (20%)
        final twostar = RatingTag(40); // 2 stars (40%)
        final threestar = RatingTag(60); // 3 stars (60%)
        final fourstar = RatingTag(80); // 4 stars (80%)
        final fivestar = RatingTag(100); // 5 stars (100%)

        expect(onestar.value, equals(20));
        expect(twostar.value, equals(40));
        expect(threestar.value, equals(60));
        expect(fourstar.value, equals(80));
        expect(fivestar.value, equals(100));
      });

      test('key is always TagKey.rating', () {
        final tag1 = RatingTag(0);
        final tag2 = RatingTag(50);
        final tag3 = RatingTag(100);

        expect(tag1.key, equals(TagKey.rating));
        expect(tag2.key, equals(TagKey.rating));
        expect(tag3.key, equals(TagKey.rating));
      });
    });

    group('validation', () {
      test('throws ArgumentError for rating -1', () {
        expect(
          () => RatingTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for rating 101', () {
        expect(
          () => RatingTag(101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative rating values', () {
        expect(
          () => RatingTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => RatingTag(-50),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => RatingTag(-999),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for rating values above maximum', () {
        expect(
          () => RatingTag(101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => RatingTag(150),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );

        expect(
          () => RatingTag(255),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Rating must be between 0 and 100 (inclusive)'),
            ),
          ),
        );
      });

      test('ArgumentError includes the invalid value', () {
        expect(
          () => RatingTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(-1),
            ),
          ),
        );

        expect(
          () => RatingTag(101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(101),
            ),
          ),
        );

        expect(
          () => RatingTag(-10),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(-10),
            ),
          ),
        );
      });

      test('ArgumentError includes parameter name', () {
        expect(
          () => RatingTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              equals('value'),
            ),
          ),
        );
      });

      test('validation works with provenance parameter', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );

        expect(
          () => RatingTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => RatingTag(101, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        // Valid values should work fine with provenance
        final validTag = RatingTag(75, provenance: provenance);
        expect(validTag.value, equals(75));
        expect(validTag.provenance, equals(provenance));
      });

      test('accepts boundary values', () {
        // Test that boundary values are valid
        final minTag = RatingTag(0);
        final maxTag = RatingTag(100);

        expect(minTag.value, equals(0));
        expect(maxTag.value, equals(100));
      });

      test('rejects values just outside boundaries', () {
        expect(() => RatingTag(-1), throwsA(isA<ArgumentError>()));
        expect(() => RatingTag(101), throwsA(isA<ArgumentError>()));
      });
    });

    group('withProvenance', () {
      test('returns new RatingTag instance with updated provenance', () {
        final originalTag = RatingTag(
          88,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(88));
        expect(originalTag.key, equals(TagKey.rating));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(88));
        expect(updatedTag.key, equals(TagKey.rating));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns RatingTag type specifically', () {
        final originalTag = RatingTag(92);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<RatingTag>());
        expect(updatedTag.runtimeType, equals(RatingTag));
      });

      test('preserves rating value exactly', () {
        final originalTag = RatingTag(67);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag.value, equals(originalTag.value));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance, equals(newProvenance));
      });

      test('works with TagProvenance.none()', () {
        final originalTag = RatingTag(
          45,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        final originalTag = RatingTag(55);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(55));
          expect(updatedTag.key, equals(TagKey.rating));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = RatingTag(78);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(78));
          expect(updatedTag.key, equals(TagKey.rating));
        }
      });
    });

    group('equality', () {
      test('equal instances with same rating, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = RatingTag(85, provenance: provenance);
        final tag2 = RatingTag(85, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different rating values', () {
        final tag1 = RatingTag(75);
        final tag2 = RatingTag(85);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different provenance', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v1,
          'v1',
          TagConfidence.certain,
        );

        final tag1 = RatingTag(90, provenance: provenance1);
        final tag2 = RatingTag(90, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = RatingTag(65);
        final tag2 = RatingTag(65);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with boundary rating values', () {
        final tag1Min = RatingTag(0);
        final tag2Min = RatingTag(0);
        final tag1Max = RatingTag(100);
        final tag2Max = RatingTag(100);

        expect(tag1Min, equals(tag2Min));
        expect(tag1Min.hashCode, equals(tag2Min.hashCode));
        expect(tag1Max, equals(tag2Max));
        expect(tag1Max.hashCode, equals(tag2Max.hashCode));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = RatingTag(95, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(95));
        expect(tag.props[1], equals(TagKey.rating));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = RatingTag(50);
        final tag2 = RatingTag(50);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and rating', () {
        final tag = RatingTag(80);
        final result = tag.toString();

        expect(result, contains('RatingTag'));
        expect(result, contains('80'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = RatingTag(95, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('RatingTag'));
        expect(result, contains('95'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles boundary rating values', () {
        final tagMin = RatingTag(0);
        final tagMax = RatingTag(100);

        final resultMin = tagMin.toString();
        final resultMax = tagMax.toString();

        expect(resultMin, contains('0'));
        expect(resultMax, contains('100'));
      });

      test('handles common rating values', () {
        final tag25 = RatingTag(25);
        final tag50 = RatingTag(50);
        final tag75 = RatingTag(75);

        expect(tag25.toString(), contains('25'));
        expect(tag50.toString(), contains('50'));
        expect(tag75.toString(), contains('75'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = RatingTag(
          88,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(88));
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = RatingTag(60);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(60));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(60));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always int type', () {
        final tag1 = RatingTag(0);
        final tag2 = RatingTag(50);
        final tag3 = RatingTag(100);

        expect(tag1.value, isA<int>());
        expect(tag2.value, isA<int>());
        expect(tag3.value, isA<int>());
      });

      test('withProvenance maintains RatingTag type', () {
        final originalTag = RatingTag(72);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<RatingTag>());
        expect(newTag.value, isA<int>());
        expect(newTag.runtimeType, equals(RatingTag));
      });
    });

    group('edge cases', () {
      test('handles exact boundary values', () {
        final minTag = RatingTag(0);
        final maxTag = RatingTag(100);

        expect(minTag.value, equals(0));
        expect(maxTag.value, equals(100));
        expect(minTag.key, equals(TagKey.rating));
        expect(maxTag.key, equals(TagKey.rating));
      });

      test('validation edge case: exactly at boundaries', () {
        // Test that boundary values are valid
        final tag0 = RatingTag(0);
        final tag100 = RatingTag(100);

        expect(tag0.value, equals(0));
        expect(tag100.value, equals(100));

        // And that values just outside boundaries are invalid
        expect(() => RatingTag(-1), throwsA(isA<ArgumentError>()));
        expect(() => RatingTag(101), throwsA(isA<ArgumentError>()));
      });

      test('handles percentage-based rating ranges', () {
        // Test various percentage ranges
        final unrated = RatingTag(0); // 0%
        final poor = RatingTag(20); // 20%
        final fair = RatingTag(40); // 40%
        final good = RatingTag(60); // 60%
        final verygood = RatingTag(80); // 80%
        final excellent = RatingTag(100); // 100%

        expect(unrated.value, equals(0));
        expect(poor.value, equals(20));
        expect(fair.value, equals(40));
        expect(good.value, equals(60));
        expect(verygood.value, equals(80));
        expect(excellent.value, equals(100));
      });

      test('handles star rating equivalents', () {
        // Test 5-star rating system equivalents (20% per star)
        final nostar = RatingTag(0); // 0 stars
        final onestar = RatingTag(20); // 1 star
        final twostar = RatingTag(40); // 2 stars
        final threestar = RatingTag(60); // 3 stars
        final fourstar = RatingTag(80); // 4 stars
        final fivestar = RatingTag(100); // 5 stars

        expect(nostar.value, equals(0));
        expect(onestar.value, equals(20));
        expect(twostar.value, equals(40));
        expect(threestar.value, equals(60));
        expect(fourstar.value, equals(80));
        expect(fivestar.value, equals(100));
      });

      test('handles 10-point rating scale equivalents', () {
        // Test 10-point rating system equivalents (10% per point)
        for (int i = 0; i <= 10; i++) {
          final rating = i * 10;
          final tag = RatingTag(rating);
          expect(tag.value, equals(rating));
        }
      });

      test('handles common music rating scenarios', () {
        // Test ratings commonly used in music applications
        final skip = RatingTag(0); // Skip/don't play
        final dislike = RatingTag(25); // Dislike
        final neutral = RatingTag(50); // Neutral/OK
        final like = RatingTag(75); // Like
        final love = RatingTag(100); // Love/favorite

        expect(skip.value, equals(0));
        expect(dislike.value, equals(25));
        expect(neutral.value, equals(50));
        expect(like.value, equals(75));
        expect(love.value, equals(100));
      });

      test('handles ID3v2 POPM scale conversion scenarios', () {
        // Test values that would be common when converting from ID3v2 POMP (0-255)
        final pomp0 = RatingTag(0); // POPM 0 -> 0%
        final pomp64 = RatingTag(25); // POPM 64 -> 25%
        final pomp128 = RatingTag(50); // POPM 128 -> 50%
        final pomp192 = RatingTag(75); // POPM 192 -> 75%
        final pomp255 = RatingTag(100); // POPM 255 -> 100%

        expect(pomp0.value, equals(0));
        expect(pomp64.value, equals(25));
        expect(pomp128.value, equals(50));
        expect(pomp192.value, equals(75));
        expect(pomp255.value, equals(100));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<int> correctly', () {
        final tag = RatingTag(85);

        expect(tag, isA<RatingTag>());
        expect(tag.value, isA<int>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = RatingTag(75);
        final tag2 = RatingTag(75);
        final tag3 = RatingTag(85);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = RatingTag(90);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'RatingTag\(.*\)'));
        expect(result, contains('90'));
        expect(result, contains('provenance:'));
      });
    });

    group('rating specific scenarios', () {
      test('handles thumbs up/down rating (binary)', () {
        final thumbsDown = RatingTag(0); // Thumbs down
        final thumbsUp = RatingTag(100); // Thumbs up

        expect(thumbsDown.value, equals(0));
        expect(thumbsUp.value, equals(100));
      });

      test('handles like/dislike rating (binary)', () {
        final dislike = RatingTag(0); // Dislike
        final like = RatingTag(100); // Like

        expect(dislike.value, equals(0));
        expect(like.value, equals(100));
      });

      test('handles 3-point rating scale', () {
        final bad = RatingTag(0); // Bad
        final ok = RatingTag(50); // OK
        final good = RatingTag(100); // Good

        expect(bad.value, equals(0));
        expect(ok.value, equals(50));
        expect(good.value, equals(100));
      });

      test('handles 4-point rating scale', () {
        final poor = RatingTag(0); // Poor
        final fair = RatingTag(33); // Fair
        final good = RatingTag(67); // Good
        final excellent = RatingTag(100); // Excellent

        expect(poor.value, equals(0));
        expect(fair.value, equals(33));
        expect(good.value, equals(67));
        expect(excellent.value, equals(100));
      });

      test('handles granular percentage ratings', () {
        // Test that any value in the 0-100 range works
        for (int rating = 0; rating <= 100; rating += 5) {
          final tag = RatingTag(rating);
          expect(tag.value, equals(rating));
        }
      });

      test('handles music streaming service rating equivalents', () {
        // Common rating systems from streaming services
        final spotify_dislike = RatingTag(0); // Spotify dislike
        final spotify_like = RatingTag(100); // Spotify like
        final apple_1star = RatingTag(20); // Apple Music 1 star
        final apple_5star = RatingTag(100); // Apple Music 5 stars
        final lastfm_love = RatingTag(100); // Last.fm love

        expect(spotify_dislike.value, equals(0));
        expect(spotify_like.value, equals(100));
        expect(apple_1star.value, equals(20));
        expect(apple_5star.value, equals(100));
        expect(lastfm_love.value, equals(100));
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for rating -1', () {
        try {
          RatingTag(-1);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Rating must be between 0 and 100 (inclusive)'));
          expect(error.invalidValue, equals(-1));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for rating 101', () {
        try {
          RatingTag(101);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Rating must be between 0 and 100 (inclusive)'));
          expect(error.invalidValue, equals(101));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for negative values', () {
        try {
          RatingTag(-50);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Rating must be between 0 and 100 (inclusive)'));
          expect(error.invalidValue, equals(-50));
          expect(error.name, equals('value'));
        }
      });

      test('error message includes range information', () {
        try {
          RatingTag(200);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('0'));
          expect(error.message, contains('100'));
          expect(error.message, contains('inclusive'));
        }
      });

      test('error occurs before provenance is processed', () {
        // Ensure validation happens early in constructor
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        expect(
          () => RatingTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('constants', () {
      test('minRating constant is correct', () {
        expect(RatingTag.minRating, equals(0));
      });

      test('maxRating constant is correct', () {
        expect(RatingTag.maxRating, equals(100));
      });

      test('constants are used in validation', () {
        // Test that the constants are actually used
        expect(() => RatingTag(RatingTag.minRating - 1), throwsA(isA<ArgumentError>()));
        expect(() => RatingTag(RatingTag.maxRating + 1), throwsA(isA<ArgumentError>()));

        // And that boundary values work
        final minTag = RatingTag(RatingTag.minRating);
        final maxTag = RatingTag(RatingTag.maxRating);

        expect(minTag.value, equals(RatingTag.minRating));
        expect(maxTag.value, equals(RatingTag.maxRating));
      });
    });
  });
}
