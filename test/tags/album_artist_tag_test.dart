import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('AlbumArtistTag', () {
    group('constructor', () {
      test('creates instance with album artist value and default provenance', () {
        const tag = AlbumArtistTag('Various Artists');

        expect(tag.value, equals('Various Artists'));
        expect(tag.key, equals(TagKey.albumArtist));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with album artist value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = AlbumArtistTag('Various Artists', provenance: provenance);

        expect(tag.value, equals('Various Artists'));
        expect(tag.key, equals(TagKey.albumArtist));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty album artist', () {
        const tag = AlbumArtistTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.albumArtist));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = AlbumArtistTag('🎵 Artist Name with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 Artist Name with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.albumArtist));
      });

      test('creates instance with very long album artist name', () {
        final longArtist = 'A' * 1000;
        final tag = AlbumArtistTag(longArtist);

        expect(tag.value, equals(longArtist));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.albumArtist));
      });

      test('key is always TagKey.albumArtist', () {
        const tag1 = AlbumArtistTag('Artist 1');
        const tag2 = AlbumArtistTag('Artist 2');
        const tag3 = AlbumArtistTag('');

        expect(tag1.key, equals(TagKey.albumArtist));
        expect(tag2.key, equals(TagKey.albumArtist));
        expect(tag3.key, equals(TagKey.albumArtist));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = AlbumArtistTag(
          'Const Album Artist',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Album Artist'));
        expect(tag.key, equals(TagKey.albumArtist));
      });
    });

    group('withProvenance', () {
      test('returns new AlbumArtistTag instance with updated provenance', () {
        const originalTag = AlbumArtistTag(
          'Original Album Artist',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Album Artist'));
        expect(originalTag.key, equals(TagKey.albumArtist));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Album Artist'));
        expect(updatedTag.key, equals(TagKey.albumArtist));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns AlbumArtistTag type specifically', () {
        const originalTag = AlbumArtistTag('Test Album Artist');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<AlbumArtistTag>());
        expect(updatedTag.runtimeType, equals(AlbumArtistTag));
      });

      test('preserves album artist value exactly', () {
        const originalTag = AlbumArtistTag('Complex Album Artist: éñ中文🎵 with special chars');
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
        const originalTag = AlbumArtistTag(
          'Test Album Artist',
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
        const originalTag = AlbumArtistTag('Test Album Artist');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Album Artist'));
          expect(updatedTag.key, equals(TagKey.albumArtist));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = AlbumArtistTag('Test Album Artist');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Album Artist'));
          expect(updatedTag.key, equals(TagKey.albumArtist));
        }
      });
    });

    group('equality', () {
      test('equal instances with same album artist, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = AlbumArtistTag('Same Album Artist', provenance: provenance);
        const tag2 = AlbumArtistTag('Same Album Artist', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different album artists', () {
        const tag1 = AlbumArtistTag('Album Artist 1');
        const tag2 = AlbumArtistTag('Album Artist 2');

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

        const tag1 = AlbumArtistTag('Same Album Artist', provenance: provenance1);
        const tag2 = AlbumArtistTag('Same Album Artist', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = AlbumArtistTag('Test Album Artist');
        const tag2 = AlbumArtistTag('Test Album Artist');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty album artists', () {
        const tag1 = AlbumArtistTag('');
        const tag2 = AlbumArtistTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = AlbumArtistTag('Album Artist');
        const tag2 = AlbumArtistTag('album artist');
        const tag3 = AlbumArtistTag('ALBUM ARTIST');

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
        const tag = AlbumArtistTag('Test Album Artist', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Album Artist'));
        expect(tag.props[1], equals(TagKey.albumArtist));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = AlbumArtistTag('Same Album Artist');
        const tag2 = AlbumArtistTag('Same Album Artist');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and album artist', () {
        const tag = AlbumArtistTag('My Favorite Album Artist');
        final result = tag.toString();

        expect(result, contains('AlbumArtistTag'));
        expect(result, contains('My Favorite Album Artist'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = AlbumArtistTag('Test Album Artist', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('AlbumArtistTag'));
        expect(result, contains('Test Album Artist'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in album artist', () {
        const tag = AlbumArtistTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty album artist', () {
        const tag = AlbumArtistTag('');
        final result = tag.toString();

        expect(result, contains('AlbumArtistTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = AlbumArtistTag(
          'Immutable Album Artist',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Album Artist'));
        expect(tag.key, equals(TagKey.albumArtist));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = AlbumArtistTag('Original Album Artist');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Album Artist'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Album Artist'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = AlbumArtistTag('String Album Artist');
        const tag2 = AlbumArtistTag('');
        const tag3 = AlbumArtistTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains AlbumArtistTag type', () {
        const originalTag = AlbumArtistTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<AlbumArtistTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(AlbumArtistTag));
      });
    });

    group('edge cases', () {
      test('handles very long album artist values', () {
        final longArtist = 'A' * 10000;
        final tag = AlbumArtistTag(longArtist);

        expect(tag.value, equals(longArtist));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.albumArtist));
      });

      test('handles unicode and emoji in album artist values', () {
        const tag = AlbumArtistTag('🎵 Album Artist Name with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Album Artist Name with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only album artists', () {
        const tag1 = AlbumArtistTag(' ');
        const tag2 = AlbumArtistTag('   ');
        const tag3 = AlbumArtistTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles album artists with quotes and special formatting', () {
        const tag1 = AlbumArtistTag('"Quoted Album Artist"');
        const tag2 = AlbumArtistTag("'Single Quoted'");
        const tag3 = AlbumArtistTag('Album Artist with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Album Artist"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Album Artist with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = AlbumArtistTag('Test Album Artist');

        expect(tag, isA<AlbumArtistTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = AlbumArtistTag('Same Album Artist');
        const tag2 = AlbumArtistTag('Same Album Artist');
        const tag3 = AlbumArtistTag('Different Album Artist');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = AlbumArtistTag('Test Album Artist');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'AlbumArtistTag\(.*\)'));
        expect(result, contains('Test Album Artist'));
        expect(result, contains('provenance:'));
      });
    });
  });
}
