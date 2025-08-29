import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/container_kind.dart';
import 'package:phonic/src/metadata_tag.dart';
import 'package:phonic/src/tag_confidence.dart';
import 'package:phonic/src/tag_key.dart';
import 'package:phonic/src/tag_provenance.dart';

void main() {
  group('MetadataTag', () {
    group('constructor', () {
      test('creates instance with all required parameters', () {
        const tag = TestStringTag(
          'Test Value',
          key: TagKey.title,
          provenance: TagProvenance(
            ContainerKind.id3v2,
            '2.4',
            TagConfidence.certain,
          ),
        );

        expect(tag.value, equals('Test Value'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with default provenance', () {
        const tag = TestStringTag('Test Value');

        expect(tag.value, equals('Test Value'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with different value types', () {
        const stringTag = TestStringTag('String Value');
        const intTag = TestIntTag(42);

        expect(stringTag.value, isA<String>());
        expect(stringTag.value, equals('String Value'));
        expect(intTag.value, isA<int>());
        expect(intTag.value, equals(42));
      });

      test('creates instance with all tag keys', () {
        for (final key in TagKey.values) {
          final tag = TestStringTag('Test', key: key);
          expect(tag.key, equals(key));
        }
      });

      test('creates instance with all container kinds in provenance', () {
        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final tag = TestStringTag('Test', provenance: provenance);
          expect(tag.provenance.containerKind, equals(kind));
        }
      });

      test('creates instance with all confidence levels in provenance', () {
        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final tag = TestStringTag('Test', provenance: provenance);
          expect(tag.provenance.confidence, equals(confidence));
        }
      });
    });

    group('withProvenance', () {
      test('returns new instance with updated provenance', () {
        const originalTag = TestStringTag(
          'Original Value',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Value'));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Value'));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns correct concrete type', () {
        const stringTag = TestStringTag('Test');
        const intTag = TestIntTag(42);

        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedStringTag = stringTag.withProvenance(newProvenance);
        final updatedIntTag = intTag.withProvenance(newProvenance);

        expect(updatedStringTag, isA<TestStringTag>());
        expect(updatedIntTag, isA<TestIntTag>());
        expect(updatedStringTag.value, isA<String>());
        expect(updatedIntTag.value, isA<int>());
      });

      test('preserves value and key exactly', () {
        const originalTag = TestStringTag(
          'Complex Value with Special Characters: éñ中文🎵',
          key: TagKey.comment,
        );

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

      test('works with none provenance', () {
        const originalTag = TestStringTag(
          'Test',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });
    });

    group('equality', () {
      test('equal instances with same value, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = TestStringTag(
          'Same Value',
          key: TagKey.artist,
          provenance: provenance,
        );
        const tag2 = TestStringTag(
          'Same Value',
          key: TagKey.artist,
          provenance: provenance,
        );

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different values', () {
        const tag1 = TestStringTag('Value 1');
        const tag2 = TestStringTag('Value 2');

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different keys', () {
        const tag1 = TestStringTag('Same Value', key: TagKey.title);
        const tag2 = TestStringTag('Same Value', key: TagKey.artist);

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

        const tag1 = TestStringTag('Same Value', provenance: provenance1);
        const tag2 = TestStringTag('Same Value', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal between different tag types with same value', () {
        const stringTag = TestStringTag('42');
        const intTag = TestIntTag(42);

        expect(stringTag, isNot(equals(intTag)));
      });

      test('equal with default provenance', () {
        const tag1 = TestStringTag('Test');
        const tag2 = TestStringTag('Test');

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
        const tag = TestStringTag(
          'Test Value',
          key: TagKey.album,
          provenance: provenance,
        );

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Value'));
        expect(tag.props[1], equals(TagKey.album));
        expect(tag.props[2], equals(provenance));
      });

      test('props support different value types', () {
        const stringTag = TestStringTag('String');
        const intTag = TestIntTag(123);

        expect(stringTag.props[0], isA<String>());
        expect(stringTag.props[0], equals('String'));
        expect(intTag.props[0], isA<int>());
        expect(intTag.props[0], equals(123));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and value', () {
        const tag = TestStringTag('Test Value');
        final result = tag.toString();

        expect(result, contains('TestStringTag'));
        expect(result, contains('Test Value'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = TestStringTag('Test', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('TestStringTag'));
        expect(result, contains('Test'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles different value types correctly', () {
        const stringTag = TestStringTag('String Value');
        const intTag = TestIntTag(42);

        final stringResult = stringTag.toString();
        final intResult = intTag.toString();

        expect(stringResult, contains('String Value'));
        expect(intResult, contains('42'));
        expect(stringResult, contains('TestStringTag'));
        expect(intResult, contains('TestIntTag'));
      });

      test('handles special characters in values', () {
        const tag = TestStringTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty and null-like values', () {
        const emptyTag = TestStringTag('');
        const zeroTag = TestIntTag(0);

        expect(emptyTag.toString(), contains('TestStringTag('));
        expect(zeroTag.toString(), contains('TestIntTag(0'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = TestStringTag(
          'Immutable Value',
          key: TagKey.title,
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Value'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('const constructor creates compile-time constants', () {
        // This should compile as a const expression
        const tag = TestStringTag(
          'Const Value',
          key: TagKey.artist,
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Value'));
        expect(tag.key, equals(TagKey.artist));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = TestStringTag('Original');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('generic type parameter enforces value type', () {
        const stringTag = TestStringTag('String');
        const intTag = TestIntTag(42);

        expect(stringTag.value, isA<String>());
        expect(intTag.value, isA<int>());
        expect(stringTag.value, isNot(isA<int>()));
        expect(intTag.value, isNot(isA<String>()));
      });

      test('withProvenance maintains concrete type', () {
        const originalStringTag = TestStringTag('Test');
        const originalIntTag = TestIntTag(123);
        const newProvenance = TagProvenance.none();

        final newStringTag = originalStringTag.withProvenance(newProvenance);
        final newIntTag = originalIntTag.withProvenance(newProvenance);

        expect(newStringTag, isA<TestStringTag>());
        expect(newIntTag, isA<TestIntTag>());
        expect(newStringTag.value, isA<String>());
        expect(newIntTag.value, isA<int>());
      });
    });

    group('edge cases', () {
      test('handles very long string values', () {
        final longValue = 'A' * 10000;
        final tag = TestStringTag(longValue);

        expect(tag.value, equals(longValue));
        expect(tag.value.length, equals(10000));
      });

      test('handles negative integer values', () {
        const tag = TestIntTag(-42);
        expect(tag.value, equals(-42));
      });

      test('handles zero and boundary values', () {
        const zeroTag = TestIntTag(0);
        const maxTag = TestIntTag(2147483647); // Max int32
        const minTag = TestIntTag(-2147483648); // Min int32

        expect(zeroTag.value, equals(0));
        expect(maxTag.value, equals(2147483647));
        expect(minTag.value, equals(-2147483648));
      });

      test('handles unicode and emoji in string values', () {
        const tag = TestStringTag('🎵 Music with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Music with émojis and ñ special chars 中文'));
      });

      test('handles empty string values', () {
        const tag = TestStringTag('');
        expect(tag.value, equals(''));
        expect(tag.value.isEmpty, isTrue);
      });
    });
  });
}
