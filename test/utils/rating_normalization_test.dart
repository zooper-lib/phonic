/// Unit tests for rating normalization utilities.
///
/// This test suite verifies the correct conversion of rating values between
/// different container-specific scales and the unified 0-100 scale used by
/// the Phonic API.

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/id3v23_capability.dart';
import 'package:phonic/src/capabilities/id3v24_capability.dart';
import 'package:phonic/src/capabilities/vorbis_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/utils/rating_normalization.dart';

void main() {
  group('RatingNormalization', () {
    group('fromId3v2Scale', () {
      test('converts minimum ID3v2 rating (0) to unified scale (0)', () {
        expect(RatingNormalization.fromId3v2Scale(0), equals(0));
      });

      test('converts maximum ID3v2 rating (255) to unified scale (100)', () {
        expect(RatingNormalization.fromId3v2Scale(255), equals(100));
      });

      test('converts common ID3v2 ratings to expected unified values', () {
        // Test common 5-star rating equivalents
        expect(RatingNormalization.fromId3v2Scale(51), equals(20)); // 1 star
        expect(RatingNormalization.fromId3v2Scale(102), equals(40)); // 2 stars
        expect(RatingNormalization.fromId3v2Scale(153), equals(60)); // 3 stars
        expect(RatingNormalization.fromId3v2Scale(204), equals(80)); // 4 stars
        expect(RatingNormalization.fromId3v2Scale(255), equals(100)); // 5 stars
      });

      test('converts mid-range ID3v2 ratings correctly', () {
        expect(RatingNormalization.fromId3v2Scale(128), equals(50)); // Midpoint
        expect(RatingNormalization.fromId3v2Scale(64), equals(25)); // Quarter
        expect(RatingNormalization.fromId3v2Scale(191), equals(75)); // Three quarters
      });

      test('handles edge cases near boundaries', () {
        expect(RatingNormalization.fromId3v2Scale(1), equals(0)); // Very low
        expect(RatingNormalization.fromId3v2Scale(254), equals(100)); // Very high
        expect(RatingNormalization.fromId3v2Scale(127), equals(50)); // Just below midpoint
        expect(RatingNormalization.fromId3v2Scale(129), equals(51)); // Just above midpoint
      });

      test('throws ArgumentError for values below minimum', () {
        expect(
          () => RatingNormalization.fromId3v2Scale(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('ID3v2 rating must be between 0 and 255'),
            ),
          ),
        );
      });

      test('throws ArgumentError for values above maximum', () {
        expect(
          () => RatingNormalization.fromId3v2Scale(256),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('ID3v2 rating must be between 0 and 255'),
            ),
          ),
        );
      });
    });

    group('toId3v2Scale', () {
      test('converts minimum unified rating (0) to ID3v2 scale (0)', () {
        expect(RatingNormalization.toId3v2Scale(0), equals(0));
      });

      test('converts maximum unified rating (100) to ID3v2 scale (255)', () {
        expect(RatingNormalization.toId3v2Scale(100), equals(255));
      });

      test('converts common unified ratings to expected ID3v2 values', () {
        // Test common 5-star rating equivalents
        expect(RatingNormalization.toId3v2Scale(20), equals(51)); // 1 star
        expect(RatingNormalization.toId3v2Scale(40), equals(102)); // 2 stars
        expect(RatingNormalization.toId3v2Scale(60), equals(153)); // 3 stars
        expect(RatingNormalization.toId3v2Scale(80), equals(204)); // 4 stars
        expect(RatingNormalization.toId3v2Scale(100), equals(255)); // 5 stars
      });

      test('converts mid-range unified ratings correctly', () {
        expect(RatingNormalization.toId3v2Scale(50), equals(128)); // Midpoint
        expect(RatingNormalization.toId3v2Scale(25), equals(64)); // Quarter
        expect(RatingNormalization.toId3v2Scale(75), equals(191)); // Three quarters
      });

      test('handles edge cases near boundaries', () {
        expect(RatingNormalization.toId3v2Scale(1), equals(3)); // Very low
        expect(RatingNormalization.toId3v2Scale(99), equals(252)); // Very high
        expect(RatingNormalization.toId3v2Scale(49), equals(125)); // Just below midpoint
        expect(RatingNormalization.toId3v2Scale(51), equals(130)); // Just above midpoint
      });

      test('throws ArgumentError for values below minimum', () {
        expect(
          () => RatingNormalization.toId3v2Scale(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unified rating must be between 0 and 100'),
            ),
          ),
        );
      });

      test('throws ArgumentError for values above maximum', () {
        expect(
          () => RatingNormalization.toId3v2Scale(101),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unified rating must be between 0 and 100'),
            ),
          ),
        );
      });
    });

    group('round-trip conversion', () {
      test('ID3v2 to unified and back preserves common values', () {
        final testValues = [0, 51, 102, 153, 204, 255];
        for (final id3v2Value in testValues) {
          final unified = RatingNormalization.fromId3v2Scale(id3v2Value);
          final backToId3v2 = RatingNormalization.toId3v2Scale(unified);
          expect(backToId3v2, equals(id3v2Value), reason: 'Round-trip failed for ID3v2 value $id3v2Value');
        }
      });

      test('unified to ID3v2 and back preserves common values', () {
        final testValues = [0, 20, 40, 50, 60, 80, 100];
        for (final unifiedValue in testValues) {
          final id3v2 = RatingNormalization.toId3v2Scale(unifiedValue);
          final backToUnified = RatingNormalization.fromId3v2Scale(id3v2);
          expect(backToUnified, equals(unifiedValue), reason: 'Round-trip failed for unified value $unifiedValue');
        }
      });

      test('round-trip conversion has minimal precision loss', () {
        // Test that round-trip conversion doesn't lose more than 1 point
        for (int i = 0; i <= 100; i += 5) {
          final id3v2 = RatingNormalization.toId3v2Scale(i);
          final backToUnified = RatingNormalization.fromId3v2Scale(id3v2);
          final difference = (backToUnified - i).abs();
          expect(difference, lessThanOrEqualTo(1), reason: 'Precision loss too high for unified value $i: got $backToUnified');
        }
      });
    });

    group('normalizeFromContainer', () {
      test('converts ID3v2.4 ratings using ID3v2 scale', () {
        expect(RatingNormalization.normalizeFromContainer(204, id3v24Capability), equals(80));
        expect(RatingNormalization.normalizeFromContainer(255, id3v24Capability), equals(100));
        expect(RatingNormalization.normalizeFromContainer(0, id3v24Capability), equals(0));
      });

      test('converts ID3v2.3 ratings using ID3v2 scale', () {
        expect(RatingNormalization.normalizeFromContainer(153, id3v23Capability), equals(60));
        expect(RatingNormalization.normalizeFromContainer(128, id3v23Capability), equals(50));
        expect(RatingNormalization.normalizeFromContainer(51, id3v23Capability), equals(20));
      });

      test('passes through Vorbis ratings unchanged', () {
        expect(RatingNormalization.normalizeFromContainer(85, vorbisCapability), equals(85));
        expect(RatingNormalization.normalizeFromContainer(0, vorbisCapability), equals(0));
        expect(RatingNormalization.normalizeFromContainer(100, vorbisCapability), equals(100));
      });

      test('handles MP4 ratings as unified scale', () {
        const mp4Capability = TagCapability(
          containerKind: ContainerKind.mp4,
          containerVersion: '',
          semanticsByKey: {TagKey.rating: TagSemantics()},
        );

        expect(RatingNormalization.normalizeFromContainer(75, mp4Capability), equals(75));
        expect(RatingNormalization.normalizeFromContainer(0, mp4Capability), equals(0));
        expect(RatingNormalization.normalizeFromContainer(100, mp4Capability), equals(100));
      });

      test('handles ID3v1 ratings as pass-through', () {
        const id3v1Capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {},
        );

        expect(RatingNormalization.normalizeFromContainer(42, id3v1Capability), equals(42));
      });

      test('handles no container as pass-through', () {
        const noCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(RatingNormalization.normalizeFromContainer(67, noCapability), equals(67));
      });

      test('throws ArgumentError for invalid Vorbis ratings', () {
        expect(
          () => RatingNormalization.normalizeFromContainer(-1, vorbisCapability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Vorbis rating must be between 0 and 100'),
            ),
          ),
        );

        expect(
          () => RatingNormalization.normalizeFromContainer(101, vorbisCapability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Vorbis rating must be between 0 and 100'),
            ),
          ),
        );
      });

      test('throws ArgumentError for invalid MP4 ratings', () {
        const mp4Capability = TagCapability(
          containerKind: ContainerKind.mp4,
          containerVersion: '',
          semanticsByKey: {TagKey.rating: TagSemantics()},
        );

        expect(
          () => RatingNormalization.normalizeFromContainer(-1, mp4Capability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('MP4 rating must be between 0 and 100'),
            ),
          ),
        );

        expect(
          () => RatingNormalization.normalizeFromContainer(101, mp4Capability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('MP4 rating must be between 0 and 100'),
            ),
          ),
        );
      });
    });

    group('normalizeToContainer', () {
      test('converts to ID3v2.4 ratings using ID3v2 scale', () {
        expect(RatingNormalization.normalizeToContainer(80, id3v24Capability), equals(204));
        expect(RatingNormalization.normalizeToContainer(100, id3v24Capability), equals(255));
        expect(RatingNormalization.normalizeToContainer(0, id3v24Capability), equals(0));
      });

      test('converts to ID3v2.3 ratings using ID3v2 scale', () {
        expect(RatingNormalization.normalizeToContainer(60, id3v23Capability), equals(153));
        expect(RatingNormalization.normalizeToContainer(50, id3v23Capability), equals(128));
        expect(RatingNormalization.normalizeToContainer(20, id3v23Capability), equals(51));
      });

      test('passes through Vorbis ratings unchanged', () {
        expect(RatingNormalization.normalizeToContainer(85, vorbisCapability), equals(85));
        expect(RatingNormalization.normalizeToContainer(0, vorbisCapability), equals(0));
        expect(RatingNormalization.normalizeToContainer(100, vorbisCapability), equals(100));
      });

      test('handles MP4 ratings as unified scale', () {
        const mp4Capability = TagCapability(
          containerKind: ContainerKind.mp4,
          containerVersion: '',
          semanticsByKey: {TagKey.rating: TagSemantics()},
        );

        expect(RatingNormalization.normalizeToContainer(75, mp4Capability), equals(75));
        expect(RatingNormalization.normalizeToContainer(0, mp4Capability), equals(0));
        expect(RatingNormalization.normalizeToContainer(100, mp4Capability), equals(100));
      });

      test('handles ID3v1 ratings as pass-through', () {
        const id3v1Capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {},
        );

        expect(RatingNormalization.normalizeToContainer(42, id3v1Capability), equals(42));
      });

      test('handles no container as pass-through', () {
        const noCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(RatingNormalization.normalizeToContainer(67, noCapability), equals(67));
      });

      test('throws ArgumentError for invalid unified ratings', () {
        expect(
          () => RatingNormalization.normalizeToContainer(-1, id3v24Capability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unified rating must be between 0 and 100'),
            ),
          ),
        );

        expect(
          () => RatingNormalization.normalizeToContainer(101, vorbisCapability),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unified rating must be between 0 and 100'),
            ),
          ),
        );
      });
    });

    group('supportsRating', () {
      test('returns true for containers that support ratings', () {
        expect(RatingNormalization.supportsRating(id3v24Capability), isTrue);
        expect(RatingNormalization.supportsRating(id3v23Capability), isTrue);
        expect(RatingNormalization.supportsRating(vorbisCapability), isTrue);
      });

      test('returns false for containers that do not support ratings', () {
        const id3v1Capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            // ID3v1 doesn't support ratings
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
          },
        );

        expect(RatingNormalization.supportsRating(id3v1Capability), isFalse);
      });

      test('returns false for empty capabilities', () {
        const emptyCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(RatingNormalization.supportsRating(emptyCapability), isFalse);
      });
    });

    group('getContainerRatingRange', () {
      test('returns ID3v2 range for ID3v2 containers', () {
        final (min, max) = RatingNormalization.getContainerRatingRange(id3v24Capability);
        expect(min, equals(0));
        expect(max, equals(255));

        final (min23, max23) = RatingNormalization.getContainerRatingRange(id3v23Capability);
        expect(min23, equals(0));
        expect(max23, equals(255));
      });

      test('returns unified range for Vorbis containers', () {
        final (min, max) = RatingNormalization.getContainerRatingRange(vorbisCapability);
        expect(min, equals(0));
        expect(max, equals(100));
      });

      test('returns unified range for MP4 containers', () {
        const mp4Capability = TagCapability(
          containerKind: ContainerKind.mp4,
          containerVersion: '',
          semanticsByKey: {TagKey.rating: TagSemantics()},
        );

        final (min, max) = RatingNormalization.getContainerRatingRange(mp4Capability);
        expect(min, equals(0));
        expect(max, equals(100));
      });

      test('returns zero range for unsupported containers', () {
        const id3v1Capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {},
        );

        final (min, max) = RatingNormalization.getContainerRatingRange(id3v1Capability);
        expect(min, equals(0));
        expect(max, equals(0));

        const noCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        final (minNone, maxNone) = RatingNormalization.getContainerRatingRange(noCapability);
        expect(minNone, equals(0));
        expect(maxNone, equals(0));
      });
    });

    group('precision and accuracy', () {
      test('maintains precision for common rating values', () {
        // Test that common percentage values convert accurately
        final commonValues = [0, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100];

        for (final value in commonValues) {
          final id3v2 = RatingNormalization.toId3v2Scale(value);
          final backToUnified = RatingNormalization.fromId3v2Scale(id3v2);

          // Allow for minimal rounding error (±1)
          expect((backToUnified - value).abs(), lessThanOrEqualTo(1), reason: 'Precision loss for value $value: got $backToUnified');
        }
      });

      test('handles boundary conditions correctly', () {
        // Test exact boundary values
        expect(RatingNormalization.fromId3v2Scale(0), equals(0));
        expect(RatingNormalization.fromId3v2Scale(255), equals(100));
        expect(RatingNormalization.toId3v2Scale(0), equals(0));
        expect(RatingNormalization.toId3v2Scale(100), equals(255));
      });

      test('conversion is monotonic', () {
        // Verify that higher input values always produce higher output values
        for (int i = 0; i < 255; i++) {
          final current = RatingNormalization.fromId3v2Scale(i);
          final next = RatingNormalization.fromId3v2Scale(i + 1);
          expect(next, greaterThanOrEqualTo(current), reason: 'Non-monotonic conversion at ID3v2 value $i');
        }

        for (int i = 0; i < 100; i++) {
          final current = RatingNormalization.toId3v2Scale(i);
          final next = RatingNormalization.toId3v2Scale(i + 1);
          expect(next, greaterThanOrEqualTo(current), reason: 'Non-monotonic conversion at unified value $i');
        }
      });
    });
  });
}
