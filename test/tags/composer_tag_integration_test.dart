import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('ComposerTag Integration', () {
    test('can be imported and used from main library', () {
      // Test that ComposerTag is properly exported and accessible
      const tag = ComposerTag('Ludwig van Beethoven');

      expect(tag.value, equals('Ludwig van Beethoven'));
      expect(tag.key, equals(TagKey.composer));
      expect(tag.provenance, equals(const TagProvenance.none()));
    });

    test('works with all exported types', () {
      const provenance = TagProvenance(
        ContainerKind.id3v2,
        '2.4',
        TagConfidence.certain,
      );

      const tag = ComposerTag(
        'Johann Sebastian Bach',
        provenance: provenance,
      );

      expect(tag.value, equals('Johann Sebastian Bach'));
      expect(tag.key, equals(TagKey.composer));
      expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(tag.provenance.containerVersion, equals('2.4'));
      expect(tag.provenance.confidence, equals(TagConfidence.certain));
    });

    test('withProvenance works with exported types', () {
      const originalTag = ComposerTag('Wolfgang Amadeus Mozart');

      const newProvenance = TagProvenance(
        ContainerKind.vorbis,
        '',
        TagConfidence.inferred,
      );

      final updatedTag = originalTag.withProvenance(newProvenance);

      expect(updatedTag.value, equals('Wolfgang Amadeus Mozart'));
      expect(updatedTag.key, equals(TagKey.composer));
      expect(updatedTag.provenance, equals(newProvenance));
      expect(updatedTag, isA<ComposerTag>());
    });

    test('can be used in collections with other MetadataTag types', () {
      const tags = <MetadataTag>[
        TitleTag('Symphony No. 9'),
        ArtistTag('Vienna Philharmonic'),
        ComposerTag('Ludwig van Beethoven'),
        AlbumTag('Beethoven: Complete Symphonies'),
      ];

      expect(tags.length, equals(4));

      final composerTag = tags.whereType<ComposerTag>().first;
      expect(composerTag.value, equals('Ludwig van Beethoven'));
      expect(composerTag.key, equals(TagKey.composer));
    });

    test('equality works across different instances', () {
      const tag1 = ComposerTag('Franz Schubert');
      const tag2 = ComposerTag('Franz Schubert');
      const tag3 = ComposerTag('Frédéric Chopin');

      expect(tag1, equals(tag2));
      expect(tag1, isNot(equals(tag3)));
      expect(tag1.hashCode, equals(tag2.hashCode));
    });

    test('toString provides useful debugging information', () {
      const tag = ComposerTag(
        'Pyotr Ilyich Tchaikovsky',
        provenance: TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        ),
      );

      final result = tag.toString();

      expect(result, contains('ComposerTag'));
      expect(result, contains('Pyotr Ilyich Tchaikovsky'));
      expect(result, contains('mp4'));
      expect(result, contains('derived'));
    });

    test('can be pattern matched as MetadataTag', () {
      const MetadataTag tag = ComposerTag('Antonio Vivaldi');

      switch (tag) {
        case TitleTag():
          fail('Should not match TitleTag');
        case ArtistTag():
          fail('Should not match ArtistTag');
        case ComposerTag():
          expect(tag.value, equals('Antonio Vivaldi'));
          expect(tag.key, equals(TagKey.composer));
        default:
          fail('Should match ComposerTag');
      }
    });

    test('maintains type safety in generic contexts', () {
      MetadataTag<String> createComposerTag(String composer) {
        return ComposerTag(composer);
      }

      final tag = createComposerTag('George Frideric Handel');

      expect(tag, isA<ComposerTag>());
      expect(tag.value, equals('George Frideric Handel'));
      expect(tag.key, equals(TagKey.composer));
    });
  });
}
