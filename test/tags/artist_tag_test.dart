import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('ArtistTag', () {
    group('constructor', () {
      test('creates instance with artist value and default provenance', () {
        const tag = ArtistTag('The Beatles');

        expect(tag.value, equals('The Beatles'));
        expect(tag.key, equals(TagKey.artist));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with artist value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = ArtistTag('The Beatles', provenance: provenance);

        expect(tag.value, equals('The Beatles'));
        expect(tag.key, equals(TagKey.artist));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty artist', () {
        const tag = ArtistTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.artist));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = ArtistTag('🎤 Artist Name with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎤 Artist Name with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.artist));
      });

      test('creates instance with very long artist name', () {
        final longArtist = 'A' * 1000;
        final tag = ArtistTag(longArtist);

        expect(tag.value, equals(longArtist));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.artist));
      });

      test('key is always TagKey.artist', () {
        const tag1 = ArtistTag('Artist 1');
        const tag2 = ArtistTag('Artist 2');
        const tag3 = ArtistTag('');

        expect(tag1.key, equals(TagKey.artist));
        expect(tag2.key, equals(TagKey.artist));
        expect(tag3.key, equals(TagKey.artist));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = ArtistTag(
          'Const Artist',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Artist'));
        expect(tag.key, equals(TagKey.artist));
      });
    });

    group('withProvenance', () {
      test('returns new ArtistTag instance with updated provenance', () {
        const originalTag = ArtistTag(
          'Original Artist',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Artist'));
        expect(originalTag.key, equals(TagKey.artist));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Artist'));
        expect(updatedTag.key, equals(TagKey.artist));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns ArtistTag type specifically', () {
        const originalTag = ArtistTag('Test Artist');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<ArtistTag>());
        expect(updatedTag.runtimeType, equals(ArtistTag));
      });

      test('preserves artist value exactly', () {
        const originalTag = ArtistTag('Complex Artist: éñ中文🎤 with special chars');
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
        const originalTag = ArtistTag(
          'Test Artist',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        const originalTag = ArtistTag('Test Artist');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Artist'));
          expect(updatedTag.key, equals(TagKey.artist));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = ArtistTag('Test Artist');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Artist'));
          expect(updatedTag.key, equals(TagKey.artist));
        }
      });
    });

    group('equality', () {
      test('equal instances with same artist, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = ArtistTag('Same Artist', provenance: provenance);
        const tag2 = ArtistTag('Same Artist', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different artists', () {
        const tag1 = ArtistTag('Artist 1');
        const tag2 = ArtistTag('Artist 2');

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

        const tag1 = ArtistTag('Same Artist', provenance: provenance1);
        const tag2 = ArtistTag('Same Artist', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = ArtistTag('Test Artist');
        const tag2 = ArtistTag('Test Artist');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty artists', () {
        const tag1 = ArtistTag('');
        const tag2 = ArtistTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = ArtistTag('Artist');
        const tag2 = ArtistTag('artist');
        const tag3 = ArtistTag('ARTIST');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag2, isNot(equals(tag3)));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        const tag = ArtistTag('Test Artist', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Artist'));
        expect(tag.props[1], equals(TagKey.artist));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = ArtistTag('Same Artist');
        const tag2 = ArtistTag('Same Artist');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and artist', () {
        const tag = ArtistTag('My Favorite Artist');
        final result = tag.toString();

        expect(result, contains('ArtistTag'));
        expect(result, contains('My Favorite Artist'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = ArtistTag('Test Artist', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('ArtistTag'));
        expect(result, contains('Test Artist'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in artist', () {
        const tag = ArtistTag('Special: éñ中文🎤');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎤'));
      });

      test('handles empty artist', () {
        const tag = ArtistTag('');
        final result = tag.toString();

        expect(result, contains('ArtistTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = ArtistTag(
          'Immutable Artist',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Artist'));
        expect(tag.key, equals(TagKey.artist));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = ArtistTag('Original Artist');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Artist'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Artist'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = ArtistTag('String Artist');
        const tag2 = ArtistTag('');
        const tag3 = ArtistTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains ArtistTag type', () {
        const originalTag = ArtistTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<ArtistTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(ArtistTag));
      });
    });

    group('edge cases', () {
      test('handles very long artist values', () {
        final longArtist = 'A' * 10000;
        final tag = ArtistTag(longArtist);

        expect(tag.value, equals(longArtist));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.artist));
      });

      test('handles unicode and emoji in artist values', () {
        const tag = ArtistTag('🎤 Artist Name with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎤 Artist Name with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only artists', () {
        const tag1 = ArtistTag(' ');
        const tag2 = ArtistTag('   ');
        const tag3 = ArtistTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles artists with quotes and special formatting', () {
        const tag1 = ArtistTag('"Quoted Artist"');
        const tag2 = ArtistTag("'Single Quoted'");
        const tag3 = ArtistTag('Artist with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Artist"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Artist with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = ArtistTag('Test Artist');

        expect(tag, isA<ArtistTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = ArtistTag('Same Artist');
        const tag2 = ArtistTag('Same Artist');
        const tag3 = ArtistTag('Different Artist');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = ArtistTag('Test Artist');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'ArtistTag\(.*\)'));
        expect(result, contains('Test Artist'));
        expect(result, contains('provenance:'));
      });
    });
  });
}
