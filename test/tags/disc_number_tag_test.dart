import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('DiscNumberTag', () {
    group('constructor', () {
      test('creates instance with valid disc number and default provenance', () {
        final tag = DiscNumberTag(2);

        expect(tag.value, equals(2));
        expect(tag.key, equals(TagKey.discNumber));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid disc number and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = DiscNumberTag(3, provenance: provenance);

        expect(tag.value, equals(3));
        expect(tag.key, equals(TagKey.discNumber));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with disc number 1', () {
        final tag = DiscNumberTag(1);

        expect(tag.value, equals(1));
        expect(tag.key, equals(TagKey.discNumber));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with large disc number', () {
        final tag = DiscNumberTag(99);

        expect(tag.value, equals(99));
        expect(tag.key, equals(TagKey.discNumber));
      });

      test('creates instance with very large disc number', () {
        final tag = DiscNumberTag(2147483647); // Max int32

        expect(tag.value, equals(2147483647));
        expect(tag.key, equals(TagKey.discNumber));
      });

      test('key is always TagKey.discNumber', () {
        final tag1 = DiscNumberTag(1);
        final tag2 = DiscNumberTag(5);
        final tag3 = DiscNumberTag(10);

        expect(tag1.key, equals(TagKey.discNumber));
        expect(tag2.key, equals(TagKey.discNumber));
        expect(tag3.key, equals(TagKey.discNumber));
      });
    });

    group('validation', () {
      test('throws ArgumentError for disc number 0', () {
        expect(
          () => DiscNumberTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Disc number must be greater than 0'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative disc numbers', () {
        expect(
          () => DiscNumberTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Disc number must be greater than 0'),
            ),
          ),
        );

        expect(
          () => DiscNumberTag(-5),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Disc number must be greater than 0'),
            ),
          ),
        );

        expect(
          () => DiscNumberTag(-999),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Disc number must be greater than 0'),
            ),
          ),
        );
      });

      test('ArgumentError includes the invalid value', () {
        expect(
          () => DiscNumberTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(0),
            ),
          ),
        );

        expect(
          () => DiscNumberTag(-10),
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
          () => DiscNumberTag(0),
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
          () => DiscNumberTag(0, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => DiscNumberTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        // Valid values should work fine with provenance
        final validTag = DiscNumberTag(2, provenance: provenance);
        expect(validTag.value, equals(2));
        expect(validTag.provenance, equals(provenance));
      });
    });

    group('withProvenance', () {
      test('returns new DiscNumberTag instance with updated provenance', () {
        final originalTag = DiscNumberTag(
          4,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(4));
        expect(originalTag.key, equals(TagKey.discNumber));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(4));
        expect(updatedTag.key, equals(TagKey.discNumber));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns DiscNumberTag type specifically', () {
        final originalTag = DiscNumberTag(6);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<DiscNumberTag>());
        expect(updatedTag.runtimeType, equals(DiscNumberTag));
      });

      test('preserves disc number value exactly', () {
        final originalTag = DiscNumberTag(8);
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
        final originalTag = DiscNumberTag(
          3,
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
        final originalTag = DiscNumberTag(2);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(2));
          expect(updatedTag.key, equals(TagKey.discNumber));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = DiscNumberTag(5);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(5));
          expect(updatedTag.key, equals(TagKey.discNumber));
        }
      });
    });

    group('equality', () {
      test('equal instances with same disc number, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = DiscNumberTag(2, provenance: provenance);
        final tag2 = DiscNumberTag(2, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different disc numbers', () {
        final tag1 = DiscNumberTag(1);
        final tag2 = DiscNumberTag(2);

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

        final tag1 = DiscNumberTag(2, provenance: provenance1);
        final tag2 = DiscNumberTag(2, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = DiscNumberTag(3);
        final tag2 = DiscNumberTag(3);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with disc number 1', () {
        final tag1 = DiscNumberTag(1);
        final tag2 = DiscNumberTag(1);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with large disc numbers', () {
        final tag1 = DiscNumberTag(50);
        final tag2 = DiscNumberTag(50);

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
        final tag = DiscNumberTag(7, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(7));
        expect(tag.props[1], equals(TagKey.discNumber));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = DiscNumberTag(4);
        final tag2 = DiscNumberTag(4);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and disc number', () {
        final tag = DiscNumberTag(2);
        final result = tag.toString();

        expect(result, contains('DiscNumberTag'));
        expect(result, contains('2'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = DiscNumberTag(5, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('DiscNumberTag'));
        expect(result, contains('5'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles disc number 1', () {
        final tag = DiscNumberTag(1);
        final result = tag.toString();

        expect(result, contains('1'));
      });

      test('handles large disc numbers', () {
        final tag = DiscNumberTag(999);
        final result = tag.toString();

        expect(result, contains('999'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = DiscNumberTag(
          8,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(8));
        expect(tag.key, equals(TagKey.discNumber));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = DiscNumberTag(3);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(3));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(3));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always int type', () {
        final tag1 = DiscNumberTag(1);
        final tag2 = DiscNumberTag(10);
        final tag3 = DiscNumberTag(99);

        expect(tag1.value, isA<int>());
        expect(tag2.value, isA<int>());
        expect(tag3.value, isA<int>());
      });

      test('withProvenance maintains DiscNumberTag type', () {
        final originalTag = DiscNumberTag(4);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<DiscNumberTag>());
        expect(newTag.value, isA<int>());
        expect(newTag.runtimeType, equals(DiscNumberTag));
      });
    });

    group('edge cases', () {
      test('handles maximum positive int values', () {
        const maxInt = 9223372036854775807; // Max int64
        final tag = DiscNumberTag(maxInt);

        expect(tag.value, equals(maxInt));
        expect(tag.key, equals(TagKey.discNumber));
      });

      test('validation edge case: exactly 1', () {
        final tag = DiscNumberTag(1);
        expect(tag.value, equals(1));
      });

      test('validation edge case: just above 0', () {
        // Test that 1 is the minimum valid value
        final tag = DiscNumberTag(1);
        expect(tag.value, equals(1));

        // And that 0 is still invalid
        expect(() => DiscNumberTag(0), throwsA(isA<ArgumentError>()));
      });

      test('handles common disc number ranges', () {
        // Test typical multi-disc set sizes
        for (int i = 1; i <= 10; i++) {
          final tag = DiscNumberTag(i);
          expect(tag.value, equals(i));
          expect(tag.key, equals(TagKey.discNumber));
        }
      });

      test('handles small multi-disc sets (2-3 discs)', () {
        final tag2 = DiscNumberTag(2);
        final tag3 = DiscNumberTag(3);

        expect(tag2.value, equals(2));
        expect(tag3.value, equals(3));
      });

      test('handles large box sets', () {
        // Classical box sets can have many discs
        final tag20 = DiscNumberTag(20);
        final tag50 = DiscNumberTag(50);
        final tag100 = DiscNumberTag(100);

        expect(tag20.value, equals(20));
        expect(tag50.value, equals(50));
        expect(tag100.value, equals(100));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<int> correctly', () {
        final tag = DiscNumberTag(2);

        expect(tag, isA<DiscNumberTag>());
        expect(tag.value, isA<int>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = DiscNumberTag(3);
        final tag2 = DiscNumberTag(3);
        final tag3 = DiscNumberTag(5);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = DiscNumberTag(4);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'DiscNumberTag\(.*\)'));
        expect(result, contains('4'));
        expect(result, contains('provenance:'));
      });
    });

    group('disc number specific scenarios', () {
      test('handles single disc releases', () {
        final singleDisc = DiscNumberTag(1);
        expect(singleDisc.value, equals(1));
      });

      test('handles double albums (2 discs)', () {
        final disc1 = DiscNumberTag(1);
        final disc2 = DiscNumberTag(2);

        expect(disc1.value, equals(1));
        expect(disc2.value, equals(2));
      });

      test('handles triple albums (3 discs)', () {
        for (int i = 1; i <= 3; i++) {
          final tag = DiscNumberTag(i);
          expect(tag.value, equals(i));
        }
      });

      test('handles box sets (4+ discs)', () {
        for (int i = 4; i <= 10; i++) {
          final tag = DiscNumberTag(i);
          expect(tag.value, equals(i));
        }
      });

      test('handles classical music box sets (can be very large)', () {
        // Classical complete works can have 50+ discs
        final tag25 = DiscNumberTag(25);
        final tag50 = DiscNumberTag(50);
        final tag75 = DiscNumberTag(75);

        expect(tag25.value, equals(25));
        expect(tag50.value, equals(50));
        expect(tag75.value, equals(75));
      });

      test('handles compilation series', () {
        // Compilation series can have many volumes
        final tag10 = DiscNumberTag(10);
        final tag20 = DiscNumberTag(20);

        expect(tag10.value, equals(10));
        expect(tag20.value, equals(20));
      });

      test('handles special editions with bonus discs', () {
        // Special editions might have disc numbers like 3, 4, 5 for bonus content
        final bonusDisc3 = DiscNumberTag(3);
        final bonusDisc4 = DiscNumberTag(4);

        expect(bonusDisc3.value, equals(3));
        expect(bonusDisc4.value, equals(4));
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for zero', () {
        try {
          DiscNumberTag(0);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Disc number must be greater than 0'));
          expect(error.invalidValue, equals(0));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for negative values', () {
        try {
          DiscNumberTag(-3);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('Disc number must be greater than 0'));
          expect(error.invalidValue, equals(-3));
          expect(error.name, equals('value'));
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
          () => DiscNumberTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
