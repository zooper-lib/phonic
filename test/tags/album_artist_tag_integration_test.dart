import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('AlbumArtistTag Integration', () {
    test('can be imported and used from main library', () {
      // Test that AlbumArtistTag is properly exported and accessible
      const tag = AlbumArtistTag('Various Artists');

      expect(tag.value, equals('Various Artists'));
      expect(tag.key, equals(TagKey.albumArtist));
      expect(tag.provenance, equals(const TagProvenance.none()));
    });

    test('works with all exported types', () {
      const provenance = TagProvenance(
        ContainerKind.id3v2,
        '2.4',
        TagConfidence.certain,
      );

      const tag = AlbumArtistTag('Test Album Artist', provenance: provenance);

      expect(tag.value, equals('Test Album Artist'));
      expect(tag.key, equals(TagKey.albumArtist));
      expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(tag.provenance.containerVersion, equals('2.4'));
      expect(tag.provenance.confidence, equals(TagConfidence.certain));
    });

    test('withProvenance works correctly', () {
      const originalTag = AlbumArtistTag('Original Artist');
      const newProvenance = TagProvenance(
        ContainerKind.vorbis,
        '',
        TagConfidence.inferred,
      );

      final updatedTag = originalTag.withProvenance(newProvenance);

      expect(updatedTag.value, equals('Original Artist'));
      expect(updatedTag.key, equals(TagKey.albumArtist));
      expect(updatedTag.provenance, equals(newProvenance));
      expect(updatedTag, isA<AlbumArtistTag>());
    });

    test('equality works correctly across different instances', () {
      const tag1 = AlbumArtistTag('Same Artist');
      const tag2 = AlbumArtistTag('Same Artist');
      const tag3 = AlbumArtistTag('Different Artist');

      expect(tag1, equals(tag2));
      expect(tag1, isNot(equals(tag3)));
      expect(tag1.hashCode, equals(tag2.hashCode));
    });

    test('can be used in collections', () {
      const tags = [
        AlbumArtistTag('Artist 1'),
        AlbumArtistTag('Artist 2'),
        AlbumArtistTag('Artist 3'),
      ];

      expect(tags.length, equals(3));
      expect(tags[0].value, equals('Artist 1'));
      expect(tags[1].value, equals('Artist 2'));
      expect(tags[2].value, equals('Artist 3'));

      // All should have the same key
      for (final tag in tags) {
        expect(tag.key, equals(TagKey.albumArtist));
      }
    });

    test('toString provides useful debugging information', () {
      const tag = AlbumArtistTag(
        'Debug Artist',
        provenance: TagProvenance(ContainerKind.mp4, '1.0', TagConfidence.derived),
      );

      final result = tag.toString();

      expect(result, contains('AlbumArtistTag'));
      expect(result, contains('Debug Artist'));
      expect(result, contains('mp4'));
      expect(result, contains('1.0'));
      expect(result, contains('derived'));
    });
  });
}
