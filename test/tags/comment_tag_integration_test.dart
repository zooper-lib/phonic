import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('CommentTag Integration', () {
    test('can be imported and used through main library export', () {
      // Test that CommentTag is accessible through the main library export
      const tag = CommentTag('Integration test comment');

      expect(tag.value, equals('Integration test comment'));
      expect(tag.key, equals(TagKey.comment));
      expect(tag.provenance, equals(const TagProvenance.none()));
    });

    test('can be used with all exported enums and classes', () {
      // Test integration with all related exported types
      const provenance = TagProvenance(
        ContainerKind.id3v2,
        '2.4',
        TagConfidence.certain,
      );

      const tag = CommentTag(
        'Test comment with full provenance',
        provenance: provenance,
      );

      expect(tag.key, equals(TagKey.comment));
      expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(tag.provenance.containerVersion, equals('2.4'));
      expect(tag.provenance.confidence, equals(TagConfidence.certain));
    });

    test('can be used in collections with other MetadataTag types', () {
      // Test that CommentTag works properly in collections with other tag types
      final tags = <MetadataTag>[
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
        const AlbumTag('Test Album'),
        const CommentTag('Test Comment'),
      ];

      expect(tags.length, equals(4));

      final commentTag = tags.whereType<CommentTag>().first;
      expect(commentTag.value, equals('Test Comment'));
      expect(commentTag.key, equals(TagKey.comment));
    });

    test('supports pattern matching with other tag types', () {
      // Test that CommentTag works in pattern matching scenarios
      const tag = CommentTag('Pattern matching test');

      final result = switch (tag) {
        CommentTag() => 'comment',
      };

      expect(result, equals('comment'));
    });

    test('maintains type safety in generic contexts', () {
      // Test that CommentTag maintains proper typing in generic contexts
      final MetadataTag<String> genericTag = const CommentTag('Generic test');

      expect(genericTag.value, isA<String>());
      expect(genericTag.key, equals(TagKey.comment));

      // Should be able to cast back to specific type
      final specificTag = genericTag as CommentTag;
      expect(specificTag.value, equals('Generic test'));
    });

    test('works with provenance updates in realistic scenarios', () {
      // Test realistic provenance update scenarios
      const originalTag = CommentTag('Original comment from ID3v1');

      // Simulate reading from ID3v1 first
      final id3v1Tag = originalTag.withProvenance(
        const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
      );

      // Then finding a better source in ID3v2
      final id3v2Tag = id3v1Tag.withProvenance(
        const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
      );

      expect(id3v1Tag.provenance.containerKind, equals(ContainerKind.id3v1));
      expect(id3v2Tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(id3v1Tag.value, equals(id3v2Tag.value)); // Same comment value
    });

    test('handles real-world comment scenarios', () {
      // Test with realistic comment content
      final realWorldComments = [
        'Recorded live at Madison Square Garden, December 15, 2023',
        'Bonus track from the deluxe edition - previously unreleased',
        'Featuring guest vocals by Sarah Johnson and backing by the London Symphony Orchestra',
        'Remastered from the original analog tapes by Bob Ludwig at Gateway Mastering',
        'Demo version recorded in the artist\'s home studio',
        '© 2023 Universal Music Group. All rights reserved.',
        'Part of the "Greatest Hits Collection" compilation series',
        'Radio edit - shortened from the original 7:32 album version',
      ];

      for (final comment in realWorldComments) {
        final tag = CommentTag(comment);
        expect(tag.value, equals(comment));
        expect(tag.key, equals(TagKey.comment));

        // Test that it can be updated with provenance
        final tagWithProvenance = tag.withProvenance(
          const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
        );
        expect(tagWithProvenance.value, equals(comment));
        expect(tagWithProvenance.provenance.containerKind, equals(ContainerKind.vorbis));
      }
    });
  });
}
