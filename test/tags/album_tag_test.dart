import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('AlbumTag', () {
    group('constructor', () {
      test('creates instance with album value and default provenance', () {
        const tag = AlbumTag('Abbey Road');

        expect(tag.value, equals('Abbey Road'));
        expect(tag.key, equals(TagKey.album));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with album value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = AlbumTag('Abbey Road', provenance: provenance);

        expect(tag.value, equals('Abbey Road'));
        expect(tag.key, equals(TagKey.album));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty album', () {
        const tag = AlbumTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.album));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = AlbumTag('🎵 Album Name with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 Album Name with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.album));
      });

      test('creates instance with very long album name', () {
        final longAlbum = 'A' * 1000;
        final tag = AlbumTag(longAlbum);

        expect(tag.value, equals(longAlbum));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.album));
      });

      test('key is always TagKey.album', () {
        const tag1 = AlbumTag('Album 1');
        const tag2 = AlbumTag('Album 2');
        const tag3 = AlbumTag('');

        expect(tag1.key, equals(TagKey.album));
        expect(tag2.key, equals(TagKey.album));
        expect(tag3.key, equals(TagKey.album));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = AlbumTag(
          'Const Album',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Album'));
        expect(tag.key, equals(TagKey.album));
      });
    });

    group('withProvenance', () {
      test('returns new AlbumTag instance with updated provenance', () {
        const originalTag = AlbumTag(
          'Original Album',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Album'));
        expect(originalTag.key, equals(TagKey.album));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Album'));
        expect(updatedTag.key, equals(TagKey.album));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns AlbumTag type specifically', () {
        const originalTag = AlbumTag('Test Album');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<AlbumTag>());
        expect(updatedTag.runtimeType, equals(AlbumTag));
      });

      test('preserves album value exactly', () {
        const originalTag = AlbumTag('Complex Album: éñ中文🎵 with special chars');
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
        const originalTag = AlbumTag(
          'Test Album',
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
        const originalTag = AlbumTag('Test Album');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Album'));
          expect(updatedTag.key, equals(TagKey.album));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = AlbumTag('Test Album');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Album'));
          expect(updatedTag.key, equals(TagKey.album));
        }
      });
    });

    group('equality', () {
      test('equal instances with same album, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = AlbumTag('Same Album', provenance: provenance);
        const tag2 = AlbumTag('Same Album', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different albums', () {
        const tag1 = AlbumTag('Album 1');
        const tag2 = AlbumTag('Album 2');

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

        const tag1 = AlbumTag('Same Album', provenance: provenance1);
        const tag2 = AlbumTag('Same Album', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = AlbumTag('Test Album');
        const tag2 = AlbumTag('Test Album');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty albums', () {
        const tag1 = AlbumTag('');
        const tag2 = AlbumTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = AlbumTag('Album');
        const tag2 = AlbumTag('album');
        const tag3 = AlbumTag('ALBUM');

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
        const tag = AlbumTag('Test Album', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Album'));
        expect(tag.props[1], equals(TagKey.album));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = AlbumTag('Same Album');
        const tag2 = AlbumTag('Same Album');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and album', () {
        const tag = AlbumTag('My Favorite Album');
        final result = tag.toString();

        expect(result, contains('AlbumTag'));
        expect(result, contains('My Favorite Album'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = AlbumTag('Test Album', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('AlbumTag'));
        expect(result, contains('Test Album'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in album', () {
        const tag = AlbumTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty album', () {
        const tag = AlbumTag('');
        final result = tag.toString();

        expect(result, contains('AlbumTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = AlbumTag(
          'Immutable Album',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Album'));
        expect(tag.key, equals(TagKey.album));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = AlbumTag('Original Album');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Album'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Album'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = AlbumTag('String Album');
        const tag2 = AlbumTag('');
        const tag3 = AlbumTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains AlbumTag type', () {
        const originalTag = AlbumTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<AlbumTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(AlbumTag));
      });
    });

    group('edge cases', () {
      test('handles very long album values', () {
        final longAlbum = 'A' * 10000;
        final tag = AlbumTag(longAlbum);

        expect(tag.value, equals(longAlbum));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.album));
      });

      test('handles unicode and emoji in album values', () {
        const tag = AlbumTag('🎵 Album Name with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Album Name with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only albums', () {
        const tag1 = AlbumTag(' ');
        const tag2 = AlbumTag('   ');
        const tag3 = AlbumTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles albums with quotes and special formatting', () {
        const tag1 = AlbumTag('"Quoted Album"');
        const tag2 = AlbumTag("'Single Quoted'");
        const tag3 = AlbumTag('Album with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Album"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Album with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = AlbumTag('Test Album');

        expect(tag, isA<AlbumTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = AlbumTag('Same Album');
        const tag2 = AlbumTag('Same Album');
        const tag3 = AlbumTag('Different Album');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = AlbumTag('Test Album');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'AlbumTag\(.*\)'));
        expect(result, contains('Test Album'));
        expect(result, contains('provenance:'));
      });
    });
  });
}
