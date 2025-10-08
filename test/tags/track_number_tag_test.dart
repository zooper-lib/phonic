import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('TrackNumberTag', () {
    group('constructor', () {
      test('creates instance with valid track number and default provenance', () {
        final tag = TrackNumberTag(3);

        expect(tag.value, equals(3));
        expect(tag.key, equals(TagKey.trackNumber));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid track number and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = TrackNumberTag(7, provenance: provenance);

        expect(tag.value, equals(7));
        expect(tag.key, equals(TagKey.trackNumber));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with track number 1', () {
        final tag = TrackNumberTag(1);

        expect(tag.value, equals(1));
        expect(tag.key, equals(TagKey.trackNumber));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with large track number', () {
        final tag = TrackNumberTag(999);

        expect(tag.value, equals(999));
        expect(tag.key, equals(TagKey.trackNumber));
      });

      test('creates instance with very large track number', () {
        final tag = TrackNumberTag(2147483647); // Max int32

        expect(tag.value, equals(2147483647));
        expect(tag.key, equals(TagKey.trackNumber));
      });

      test('key is always TagKey.trackNumber', () {
        final tag1 = TrackNumberTag(1);
        final tag2 = TrackNumberTag(5);
        final tag3 = TrackNumberTag(100);

        expect(tag1.key, equals(TagKey.trackNumber));
        expect(tag2.key, equals(TagKey.trackNumber));
        expect(tag3.key, equals(TagKey.trackNumber));
      });
    });

    group('validation', () {
      test('throws ArgumentError for track number 0', () {
        expect(
          () => TrackNumberTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative track numbers', () {
        expect(
          () => TrackNumberTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
            ),
          ),
        );

        expect(
          () => TrackNumberTag(-5),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
            ),
          ),
        );

        expect(
          () => TrackNumberTag(-999),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
            ),
          ),
        );
      });

      test('ArgumentError includes descriptive message', () {
        expect(
          () => TrackNumberTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
            ),
          ),
        );

        expect(
          () => TrackNumberTag(-10),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Track number must be greater than 0'),
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
          () => TrackNumberTag(0, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => TrackNumberTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        // Valid values should work fine with provenance
        final validTag = TrackNumberTag(5, provenance: provenance);
        expect(validTag.value, equals(5));
        expect(validTag.provenance, equals(provenance));
      });
    });

    group('withProvenance', () {
      test('returns new TrackNumberTag instance with updated provenance', () {
        final originalTag = TrackNumberTag(
          8,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(8));
        expect(originalTag.key, equals(TagKey.trackNumber));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(8));
        expect(updatedTag.key, equals(TagKey.trackNumber));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns TrackNumberTag type specifically', () {
        final originalTag = TrackNumberTag(12);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<TrackNumberTag>());
        expect(updatedTag.runtimeType, equals(TrackNumberTag));
      });

      test('preserves track number value exactly', () {
        final originalTag = TrackNumberTag(42);
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
        final originalTag = TrackNumberTag(
          15,
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
        final originalTag = TrackNumberTag(6);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(6));
          expect(updatedTag.key, equals(TagKey.trackNumber));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = TrackNumberTag(9);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(9));
          expect(updatedTag.key, equals(TagKey.trackNumber));
        }
      });
    });

    group('equality', () {
      test('equal instances with same track number, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = TrackNumberTag(5, provenance: provenance);
        final tag2 = TrackNumberTag(5, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different track numbers', () {
        final tag1 = TrackNumberTag(3);
        final tag2 = TrackNumberTag(7);

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

        final tag1 = TrackNumberTag(5, provenance: provenance1);
        final tag2 = TrackNumberTag(5, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = TrackNumberTag(10);
        final tag2 = TrackNumberTag(10);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with track number 1', () {
        final tag1 = TrackNumberTag(1);
        final tag2 = TrackNumberTag(1);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with large track numbers', () {
        final tag1 = TrackNumberTag(999);
        final tag2 = TrackNumberTag(999);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = TrackNumberTag(13, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(13));
        expect(tag.props[1], equals(TagKey.trackNumber));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = TrackNumberTag(7);
        final tag2 = TrackNumberTag(7);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and track number', () {
        final tag = TrackNumberTag(4);
        final result = tag.toString();

        expect(result, contains('TrackNumberTag'));
        expect(result, contains('4'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = TrackNumberTag(11, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('TrackNumberTag'));
        expect(result, contains('11'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles track number 1', () {
        final tag = TrackNumberTag(1);
        final result = tag.toString();

        expect(result, contains('1'));
      });

      test('handles large track numbers', () {
        final tag = TrackNumberTag(12345);
        final result = tag.toString();

        expect(result, contains('12345'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = TrackNumberTag(
          16,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(16));
        expect(tag.key, equals(TagKey.trackNumber));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = TrackNumberTag(20);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(20));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(20));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always int type', () {
        final tag1 = TrackNumberTag(1);
        final tag2 = TrackNumberTag(100);
        final tag3 = TrackNumberTag(999);

        expect(tag1.value, isA<int>());
        expect(tag2.value, isA<int>());
        expect(tag3.value, isA<int>());
      });

      test('withProvenance maintains TrackNumberTag type', () {
        final originalTag = TrackNumberTag(25);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<TrackNumberTag>());
        expect(newTag.value, isA<int>());
        expect(newTag.runtimeType, equals(TrackNumberTag));
      });
    });

    group('edge cases', () {
      test('handles maximum positive int values', () {
        const maxInt = 9223372036854775807; // Max int64
        final tag = TrackNumberTag(maxInt);

        expect(tag.value, equals(maxInt));
        expect(tag.key, equals(TagKey.trackNumber));
      });

      test('validation edge case: exactly 1', () {
        final tag = TrackNumberTag(1);
        expect(tag.value, equals(1));
      });

      test('validation edge case: just above 0', () {
        // Test that 1 is the minimum valid value
        final tag = TrackNumberTag(1);
        expect(tag.value, equals(1));

        // And that 0 is still invalid
        expect(() => TrackNumberTag(0), throwsA(isA<ArgumentError>()));
      });

      test('handles common track number ranges', () {
        // Test typical album track counts
        for (int i = 1; i <= 20; i++) {
          final tag = TrackNumberTag(i);
          expect(tag.value, equals(i));
          expect(tag.key, equals(TagKey.trackNumber));
        }
      });

      test('handles ID3v1 range (1-255)', () {
        // ID3v1 supports track numbers 1-255
        final tag1 = TrackNumberTag(1);
        final tag255 = TrackNumberTag(255);

        expect(tag1.value, equals(1));
        expect(tag255.value, equals(255));
      });

      test('handles values beyond ID3v1 range', () {
        // Modern formats can handle larger track numbers
        final tag256 = TrackNumberTag(256);
        final tag1000 = TrackNumberTag(1000);

        expect(tag256.value, equals(256));
        expect(tag1000.value, equals(1000));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<int> correctly', () {
        final tag = TrackNumberTag(8);

        expect(tag, isA<TrackNumberTag>());
        expect(tag.value, isA<int>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = TrackNumberTag(5);
        final tag2 = TrackNumberTag(5);
        final tag3 = TrackNumberTag(10);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = TrackNumberTag(7);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'TrackNumberTag\(.*\)'));
        expect(result, contains('7'));
        expect(result, contains('provenance:'));
      });
    });

    group('track number specific scenarios', () {
      test('handles single track releases', () {
        final singleTrack = TrackNumberTag(1);
        expect(singleTrack.value, equals(1));
      });

      test('handles EP track numbers (typically 3-8 tracks)', () {
        for (int i = 1; i <= 8; i++) {
          final tag = TrackNumberTag(i);
          expect(tag.value, equals(i));
        }
      });

      test('handles full album track numbers (typically 8-20 tracks)', () {
        for (int i = 1; i <= 20; i++) {
          final tag = TrackNumberTag(i);
          expect(tag.value, equals(i));
        }
      });

      test('handles compilation album track numbers (can be 50+ tracks)', () {
        final tag50 = TrackNumberTag(50);
        final tag100 = TrackNumberTag(100);

        expect(tag50.value, equals(50));
        expect(tag100.value, equals(100));
      });

      test('handles classical music track numbers (can be very high)', () {
        // Classical box sets can have hundreds of tracks
        final tag200 = TrackNumberTag(200);
        final tag500 = TrackNumberTag(500);

        expect(tag200.value, equals(200));
        expect(tag500.value, equals(500));
      });

      test('handles podcast episode numbers', () {
        // Podcasts can have very high episode numbers
        final tag1000 = TrackNumberTag(1000);
        final tag2500 = TrackNumberTag(2500);

        expect(tag1000.value, equals(1000));
        expect(tag2500.value, equals(2500));
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for zero', () {
        try {
          TrackNumberTag(0);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Track number must be greater than 0'));
        }
      });

      test('error message is descriptive for negative values', () {
        try {
          TrackNumberTag(-5);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Track number must be greater than 0'));
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
          () => TrackNumberTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
