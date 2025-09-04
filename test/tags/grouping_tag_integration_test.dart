import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('GroupingTag Integration', () {
    test('can be imported and used through main library export', () {
      // Test that GroupingTag is accessible through the main library export
      const tag = GroupingTag('Integration test grouping');

      expect(tag.value, equals('Integration test grouping'));
      expect(tag.key, equals(TagKey.grouping));
      expect(tag.provenance, equals(const TagProvenance.none()));
    });

    test('can be used with all exported enums and classes', () {
      // Test integration with all related exported types
      const provenance = TagProvenance(
        ContainerKind.id3v2,
        '2.4',
        TagConfidence.certain,
      );

      const tag = GroupingTag(
        'Test grouping with full provenance',
        provenance: provenance,
      );

      expect(tag.key, equals(TagKey.grouping));
      expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(tag.provenance.containerVersion, equals('2.4'));
      expect(tag.provenance.confidence, equals(TagConfidence.certain));
    });

    test('can be used in collections with other MetadataTag types', () {
      // Test that GroupingTag works properly in collections with other tag types
      final tags = <MetadataTag>[
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
        const AlbumTag('Test Album'),
        const GroupingTag('Test Grouping'),
      ];

      expect(tags.length, equals(4));

      final groupingTag = tags.whereType<GroupingTag>().first;
      expect(groupingTag.value, equals('Test Grouping'));
      expect(groupingTag.key, equals(TagKey.grouping));
    });

    test('supports pattern matching with other tag types', () {
      // Test that GroupingTag works in pattern matching scenarios
      const tag = GroupingTag('Pattern matching test');

      final result = switch (tag) {
        GroupingTag() => 'grouping',
      };

      expect(result, equals('grouping'));
    });

    test('maintains type safety in generic contexts', () {
      // Test that GroupingTag maintains proper typing in generic contexts
      final MetadataTag<String> genericTag = const GroupingTag('Generic test');

      expect(genericTag.value, isA<String>());
      expect(genericTag.key, equals(TagKey.grouping));

      // Should be able to cast back to specific type
      final specificTag = genericTag as GroupingTag;
      expect(specificTag.value, equals('Generic test'));
    });

    test('works with provenance updates in realistic scenarios', () {
      // Test realistic provenance update scenarios
      const originalTag = GroupingTag('Original grouping from ID3v1');

      // Simulate reading from ID3v1 first (not supported, so would be none)
      final id3v1Tag = originalTag.withProvenance(
        const TagProvenance(ContainerKind.none, '', TagConfidence.derived),
      );

      // Then finding a better source in ID3v2
      final id3v2Tag = id3v1Tag.withProvenance(
        const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
      );

      expect(id3v1Tag.provenance.containerKind, equals(ContainerKind.none));
      expect(id3v2Tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(id3v1Tag.value, equals(id3v2Tag.value)); // Same grouping value
    });

    test('handles real-world grouping scenarios', () {
      // Test with realistic grouping content
      final realWorldGroupings = [
        'Symphony No. 9 in D minor, Op. 125 "Choral"',
        'The Beatles: Sgt. Pepper\'s Lonely Hearts Club Band',
        'Bach: The Well-Tempered Clavier, Book I',
        'Pink Floyd: The Wall',
        'Mozart: Piano Concerto No. 21 in C major, K. 467',
        'Beethoven: Piano Sonatas',
        'Vivaldi: The Four Seasons',
        'Led Zeppelin IV',
      ];

      for (final grouping in realWorldGroupings) {
        final tag = GroupingTag(grouping);
        expect(tag.value, equals(grouping));
        expect(tag.key, equals(TagKey.grouping));

        // Test that it can be updated with provenance
        final tagWithProvenance = tag.withProvenance(
          const TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
        );
        expect(tagWithProvenance.value, equals(grouping));
        expect(tagWithProvenance.provenance.containerKind, equals(ContainerKind.vorbis));
      }
    });

    test('handles classical music work and movement scenarios', () {
      // Test classical music specific grouping scenarios
      final classicalGroupings = [
        'Beethoven: Symphony No. 5 in C minor, Op. 67',
        'Mozart: Requiem in D minor, K. 626',
        'Bach: Brandenburg Concerto No. 3 in G major, BWV 1048',
        'Chopin: Piano Sonata No. 2 in B♭ minor, Op. 35 "Funeral March"',
        'Tchaikovsky: Swan Lake, Op. 20',
        'Debussy: Clair de Lune from Suite bergamasque',
        'Rachmaninoff: Piano Concerto No. 2 in C minor, Op. 18',
        'Stravinsky: The Rite of Spring',
      ];

      for (final grouping in classicalGroupings) {
        final tag = GroupingTag(grouping);
        expect(tag.value, equals(grouping));
        expect(tag.key, equals(TagKey.grouping));

        // Test with ID3v2 provenance (common for classical music metadata)
        final tagWithProvenance = tag.withProvenance(
          const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );
        expect(tagWithProvenance.value, equals(grouping));
        expect(tagWithProvenance.provenance.containerKind, equals(ContainerKind.id3v2));
      }
    });

    test('handles popular music album and concept groupings', () {
      // Test popular music grouping scenarios
      final popularGroupings = [
        'The Dark Side of the Moon',
        'Abbey Road',
        'Thriller',
        'Back in Black',
        'Rumours',
        'Hotel California',
        'The Joshua Tree',
        'Nevermind',
      ];

      for (final grouping in popularGroupings) {
        final tag = GroupingTag(grouping);
        expect(tag.value, equals(grouping));
        expect(tag.key, equals(TagKey.grouping));

        // Test with MP4 provenance (common for popular music)
        final tagWithProvenance = tag.withProvenance(
          const TagProvenance(ContainerKind.mp4, '1.0', TagConfidence.certain),
        );
        expect(tagWithProvenance.value, equals(grouping));
        expect(tagWithProvenance.provenance.containerKind, equals(ContainerKind.mp4));
      }
    });
  });
}
