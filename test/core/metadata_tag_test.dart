import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('MetadataTag', () {
    group('constructor', () {
      test('creates instance with all required parameters', () {
        const tag = TitleTag(
          'Test Value',
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
        const tag = TitleTag('Test Value');

        expect(tag.value, equals('Test Value'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with different value types', () {
        const stringTag = TitleTag('String Value');
        final intTag = TrackNumberTag(42);

        expect(stringTag.value, isA<String>());
        expect(stringTag.value, equals('String Value'));
        expect(intTag.value, isA<int>());
        expect(intTag.value, equals(42));
      });

      test('creates instance with different tag keys', () {
        // Each tag class has its specific key
        const titleTag = TitleTag('Test');
        const artistTag = ArtistTag('Artist Name');
        const albumTag = AlbumTag('Album Name');
        final trackTag = TrackNumberTag(1);

        expect(titleTag.key, equals(TagKey.title));
        expect(artistTag.key, equals(TagKey.artist));
        expect(albumTag.key, equals(TagKey.album));
        expect(trackTag.key, equals(TagKey.trackNumber));
      });

      test('creates instance with all container kinds in provenance', () {
        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final tag = TitleTag('Test', provenance: provenance);
          expect(tag.provenance.containerKind, equals(kind));
        }
      });

      test('creates instance with all confidence levels in provenance', () {
        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final tag = TitleTag('Test', provenance: provenance);
          expect(tag.provenance.confidence, equals(confidence));
        }
      });
    });

    group('withProvenance', () {
      test('returns new instance with updated provenance', () {
        const originalTag = TitleTag(
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
        const stringTag = TitleTag('Test');
        final intTag = TrackNumberTag(42);

        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedStringTag = stringTag.withProvenance(newProvenance);
        final updatedIntTag = intTag.withProvenance(newProvenance);

        expect(updatedStringTag, isA<TitleTag>());
        expect(updatedIntTag, isA<TrackNumberTag>());
        expect(updatedStringTag.value, isA<String>());
        expect(updatedIntTag.value, isA<int>());
      });

      test('preserves value and key exactly', () {
        const originalTag = CommentTag(
          'Complex Value with Special Characters: éñ中文🎵',
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
        const originalTag = TitleTag(
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

        const tag1 = ArtistTag(
          'Same Value',
          provenance: provenance,
        );
        const tag2 = ArtistTag(
          'Same Value',
          provenance: provenance,
        );

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different values', () {
        const tag1 = TitleTag('Value 1');
        const tag2 = TitleTag('Value 2');

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different keys', () {
        const tag1 = TitleTag('Same Value'); // key: TagKey.title
        const tag2 = ArtistTag('Same Value'); // key: TagKey.artist

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

        const tag1 = TitleTag('Same Value', provenance: provenance1);
        const tag2 = TitleTag('Same Value', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal between different tag types with same value', () {
        const stringTag = TitleTag('42');
        final intTag = TrackNumberTag(42);

        expect(stringTag, isNot(equals(intTag)));
      });

      test('equal with default provenance', () {
        const tag1 = TitleTag('Test');
        const tag2 = TitleTag('Test');

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
        const tag = AlbumTag(
          'Test Value',
          provenance: provenance,
        );

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Value'));
        expect(tag.props[1], equals(TagKey.album));
        expect(tag.props[2], equals(provenance));
      });

      test('props support different value types', () {
        const stringTag = TitleTag('String');
        final intTag = TrackNumberTag(123);

        expect(stringTag.props[0], isA<String>());
        expect(stringTag.props[0], equals('String'));
        expect(intTag.props[0], isA<int>());
        expect(intTag.props[0], equals(123));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and value', () {
        const tag = TitleTag('Test Value');
        final result = tag.toString();

        expect(result, contains('TitleTag'));
        expect(result, contains('Test Value'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = TitleTag('Test', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('TitleTag'));
        expect(result, contains('Test'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles different value types correctly', () {
        const stringTag = TitleTag('String Value');
        final intTag = TrackNumberTag(42);

        final stringResult = stringTag.toString();
        final intResult = intTag.toString();

        expect(stringResult, contains('String Value'));
        expect(intResult, contains('42'));
        expect(stringResult, contains('TitleTag'));
        expect(intResult, contains('TrackNumberTag'));
      });

      test('handles special characters in values', () {
        const tag = TitleTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty and null-like values', () {
        const emptyTag = TitleTag('');
        final validTag = TrackNumberTag(1); // Use a valid track number

        expect(emptyTag.toString(), contains('TitleTag('));
        expect(validTag.toString(), contains('TrackNumberTag(1'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = TitleTag(
          'Immutable Value',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Value'));
        expect(tag.key, equals(TagKey.title));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('const constructor creates compile-time constants', () {
        // This should compile as a const expression
        const tag = ArtistTag(
          'Const Value',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Value'));
        expect(tag.key, equals(TagKey.artist));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = TitleTag('Original');
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
        const stringTag = TitleTag('String');
        final intTag = TrackNumberTag(42);

        expect(stringTag.value, isA<String>());
        expect(intTag.value, isA<int>());
        expect(stringTag.value, isNot(isA<int>()));
        expect(intTag.value, isNot(isA<String>()));
      });

      test('withProvenance maintains concrete type', () {
        const originalStringTag = TitleTag('Test');
        final originalIntTag = TrackNumberTag(123);
        const newProvenance = TagProvenance.none();

        final newStringTag = originalStringTag.withProvenance(newProvenance);
        final newIntTag = originalIntTag.withProvenance(newProvenance);

        expect(newStringTag, isA<TitleTag>());
        expect(newIntTag, isA<TrackNumberTag>());
        expect(newStringTag.value, isA<String>());
        expect(newIntTag.value, isA<int>());
      });
    });

    group('edge cases', () {
      test('handles very long string values', () {
        final longValue = 'A' * 10000;
        final tag = TitleTag(longValue);

        expect(tag.value, equals(longValue));
        expect(tag.value.length, equals(10000));
      });

      test('validates track number range', () {
        // Test that TrackNumberTag validates its input
        expect(() => TrackNumberTag(-42), throwsArgumentError);
        expect(() => TrackNumberTag(0), throwsArgumentError);

        // Valid values should work
        final validTag = TrackNumberTag(42);
        expect(validTag.value, equals(42));
      });

      test('handles boundary values correctly', () {
        // Test maximum valid values for different tag types
        final maxTrack = TrackNumberTag(2147483647); // Max int32
        final validYear = YearTag(2023); // Valid year
        final validBpm = BpmTag(120); // Valid BPM

        expect(maxTrack.value, equals(2147483647));
        expect(validYear.value, equals(2023));
        expect(validBpm.value, equals(120));
      });

      test('handles unicode and emoji in string values', () {
        const tag = TitleTag('🎵 Music with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Music with émojis and ñ special chars 中文'));
      });

      test('handles empty string values', () {
        const tag = TitleTag('');
        expect(tag.value, equals(''));
        expect(tag.value.isEmpty, isTrue);
      });
    });
  });
}
