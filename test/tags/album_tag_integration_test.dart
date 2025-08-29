import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('AlbumTag Integration', () {
    test('can be imported and used from main library', () {
      // Test that AlbumTag is available from the main library export
      const albumTag = AlbumTag('Test Album');

      expect(albumTag, isA<MetadataTag<String>>());
      expect(albumTag.value, equals('Test Album'));
      expect(albumTag.key, equals(TagKey.album));
    });

    test('works with TagKey.album enum value', () {
      const albumTag = AlbumTag('My Album');

      expect(albumTag.key, equals(TagKey.album));
      expect(TagKey.album.toString(), equals('TagKey.album'));
    });

    test('integrates with TagProvenance system', () {
      const provenance = TagProvenance(
        ContainerKind.id3v2,
        '2.4',
        TagConfidence.certain,
      );

      const albumTag = AlbumTag('Album with Provenance', provenance: provenance);

      expect(albumTag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(albumTag.provenance.containerVersion, equals('2.4'));
      expect(albumTag.provenance.confidence, equals(TagConfidence.certain));
    });

    test('can be used in collections with other tag types', () {
      const tags = <MetadataTag>[
        TitleTag('Song Title'),
        ArtistTag('Artist Name'),
        AlbumTag('Album Name'),
        AlbumArtistTag('Album Artist Name'),
      ];

      expect(tags.length, equals(4));
      expect(tags[0], isA<TitleTag>());
      expect(tags[1], isA<ArtistTag>());
      expect(tags[2], isA<AlbumTag>());
      expect(tags[3], isA<AlbumArtistTag>());

      // Verify each tag has the correct key
      expect(tags[0].key, equals(TagKey.title));
      expect(tags[1].key, equals(TagKey.artist));
      expect(tags[2].key, equals(TagKey.album));
      expect(tags[3].key, equals(TagKey.albumArtist));
    });

    test('supports pattern matching with different tag types', () {
      const tags = <MetadataTag>[
        TitleTag('Song Title'),
        ArtistTag('Artist Name'),
        AlbumTag('Album Name'),
        AlbumArtistTag('Album Artist Name'),
      ];

      final results = <String>[];
      for (final tag in tags) {
        final String result = switch (tag) {
          TitleTag() => 'title',
          ArtistTag() => 'artist',
          AlbumTag() => 'album',
          AlbumArtistTag() => 'albumArtist',
          _ => 'other',
        };
        results.add(result);
      }

      expect(results, equals(['title', 'artist', 'album', 'albumArtist']));
    });

    test('maintains type safety in generic contexts', () {
      final MetadataTag<String> stringTag = const AlbumTag('String Album');

      expect(stringTag.value, isA<String>());
      expect(stringTag.value, equals('String Album'));
      expect(stringTag.key, equals(TagKey.album));

      // Should be able to cast back to specific type
      final albumTag = stringTag as AlbumTag;
      expect(albumTag, isA<AlbumTag>());
    });
  });
}
