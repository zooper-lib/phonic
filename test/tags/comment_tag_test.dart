import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('CommentTag', () {
    group('constructor', () {
      test('creates instance with comment value and default provenance', () {
        const tag = CommentTag('Recorded live at Madison Square Garden');

        expect(tag.value, equals('Recorded live at Madison Square Garden'));
        expect(tag.key, equals(TagKey.comment));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with comment value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = CommentTag('Live recording from 2023 tour', provenance: provenance);

        expect(tag.value, equals('Live recording from 2023 tour'));
        expect(tag.key, equals(TagKey.comment));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty comment', () {
        const tag = CommentTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.comment));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = CommentTag('🎵 Comment with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 Comment with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.comment));
      });

      test('creates instance with very long comment', () {
        final longComment = 'A' * 1000;
        final tag = CommentTag(longComment);

        expect(tag.value, equals(longComment));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.comment));
      });

      test('creates instance with multi-line comment', () {
        const multiLineComment = '''This is a multi-line comment
that spans several lines
and includes various information
about the track.''';
        const tag = CommentTag(multiLineComment);

        expect(tag.value, equals(multiLineComment));
        expect(tag.key, equals(TagKey.comment));
      });

      test('key is always TagKey.comment', () {
        const tag1 = CommentTag('Comment 1');
        const tag2 = CommentTag('Comment 2');
        const tag3 = CommentTag('');

        expect(tag1.key, equals(TagKey.comment));
        expect(tag2.key, equals(TagKey.comment));
        expect(tag3.key, equals(TagKey.comment));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = CommentTag(
          'Const Comment',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Comment'));
        expect(tag.key, equals(TagKey.comment));
      });
    });

    group('withProvenance', () {
      test('returns new CommentTag instance with updated provenance', () {
        const originalTag = CommentTag(
          'Original Comment',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Comment'));
        expect(originalTag.key, equals(TagKey.comment));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Comment'));
        expect(updatedTag.key, equals(TagKey.comment));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns CommentTag type specifically', () {
        const originalTag = CommentTag('Test Comment');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<CommentTag>());
        expect(updatedTag.runtimeType, equals(CommentTag));
      });

      test('preserves comment value exactly', () {
        const originalTag = CommentTag('Complex Comment: éñ中文🎵 with special chars');
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
        const originalTag = CommentTag(
          'Test Comment',
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
        const originalTag = CommentTag('Test Comment');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Comment'));
          expect(updatedTag.key, equals(TagKey.comment));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = CommentTag('Test Comment');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Comment'));
          expect(updatedTag.key, equals(TagKey.comment));
        }
      });
    });

    group('equality', () {
      test('equal instances with same comment, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = CommentTag('Same Comment', provenance: provenance);
        const tag2 = CommentTag('Same Comment', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different comments', () {
        const tag1 = CommentTag('Comment 1');
        const tag2 = CommentTag('Comment 2');

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

        const tag1 = CommentTag('Same Comment', provenance: provenance1);
        const tag2 = CommentTag('Same Comment', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = CommentTag('Test Comment');
        const tag2 = CommentTag('Test Comment');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty comments', () {
        const tag1 = CommentTag('');
        const tag2 = CommentTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = CommentTag('Comment');
        const tag2 = CommentTag('comment');
        const tag3 = CommentTag('COMMENT');

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
        const tag = CommentTag('Test Comment', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Comment'));
        expect(tag.props[1], equals(TagKey.comment));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = CommentTag('Same Comment');
        const tag2 = CommentTag('Same Comment');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and comment', () {
        const tag = CommentTag('My Comment');
        final result = tag.toString();

        expect(result, contains('CommentTag'));
        expect(result, contains('My Comment'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = CommentTag('Test Comment', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('CommentTag'));
        expect(result, contains('Test Comment'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in comment', () {
        const tag = CommentTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty comment', () {
        const tag = CommentTag('');
        final result = tag.toString();

        expect(result, contains('CommentTag('));
        expect(result, contains('TagProvenance.none()'));
      });

      test('handles multi-line comments', () {
        const tag = CommentTag('Line 1\nLine 2\nLine 3');
        final result = tag.toString();

        expect(result, contains('Line 1\nLine 2\nLine 3'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = CommentTag(
          'Immutable Comment',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Comment'));
        expect(tag.key, equals(TagKey.comment));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = CommentTag('Original Comment');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Comment'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Comment'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = CommentTag('String Comment');
        const tag2 = CommentTag('');
        const tag3 = CommentTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains CommentTag type', () {
        const originalTag = CommentTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<CommentTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(CommentTag));
      });
    });

    group('edge cases', () {
      test('handles very long comment values', () {
        final longComment = 'A' * 10000;
        final tag = CommentTag(longComment);

        expect(tag.value, equals(longComment));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.comment));
      });

      test('handles unicode and emoji in comment values', () {
        const tag = CommentTag('🎵 Music Comment with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Music Comment with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only comments', () {
        const tag1 = CommentTag(' ');
        const tag2 = CommentTag('   ');
        const tag3 = CommentTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles comments with quotes and special formatting', () {
        const tag1 = CommentTag('"Quoted Comment"');
        const tag2 = CommentTag("'Single Quoted'");
        const tag3 = CommentTag('Comment with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Comment"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Comment with\nnewlines\tand\ttabs'));
      });

      test('handles typical comment scenarios', () {
        const scenarios = [
          'Recorded live at Madison Square Garden on December 15, 2023',
          'Bonus track from the deluxe edition',
          'Featuring guest vocals by John Doe',
          'Remastered version of the original 1975 recording',
          'Demo version - not final mix',
          'Track 5 from the concept album "Journey Through Time"',
          'Acoustic version recorded in studio B',
          'Contains explicit lyrics',
        ];

        for (final scenario in scenarios) {
          final tag = CommentTag(scenario);
          expect(tag.value, equals(scenario));
          expect(tag.key, equals(TagKey.comment));
        }
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = CommentTag('Test Comment');

        expect(tag, isA<CommentTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = CommentTag('Same Comment');
        const tag2 = CommentTag('Same Comment');
        const tag3 = CommentTag('Different Comment');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = CommentTag('Test Comment');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'CommentTag\(.*\)'));
        expect(result, contains('Test Comment'));
        expect(result, contains('provenance:'));
      });
    });

    group('comment-specific scenarios', () {
      test('handles typical music comment use cases', () {
        const liveRecording = CommentTag('Recorded live at Wembley Stadium, July 13, 1985');
        const bonusTrack = CommentTag('Bonus track from the 20th anniversary edition');
        const featuring = CommentTag('Featuring guest vocals by Sarah Johnson');
        const remaster = CommentTag('2023 remaster of the original 1973 recording');

        expect(liveRecording.key, equals(TagKey.comment));
        expect(bonusTrack.key, equals(TagKey.comment));
        expect(featuring.key, equals(TagKey.comment));
        expect(remaster.key, equals(TagKey.comment));

        expect(liveRecording.value, contains('Wembley Stadium'));
        expect(bonusTrack.value, contains('anniversary'));
        expect(featuring.value, contains('guest vocals'));
        expect(remaster.value, contains('remaster'));
      });

      test('handles technical and production comments', () {
        const technical = CommentTag('Recorded at 96kHz/24-bit, mixed in Pro Tools');
        const production = CommentTag('Produced by John Smith, engineered by Jane Doe');
        const version = CommentTag('Radio edit - 3:45 version');

        expect(technical.value, contains('96kHz'));
        expect(production.value, contains('Produced by'));
        expect(version.value, contains('Radio edit'));
      });

      test('handles metadata and cataloging comments', () {
        const catalog = CommentTag('Catalog #: ABC-12345, ISRC: USRC17607839');
        const rights = CommentTag('© 2023 Record Label Inc. All rights reserved.');
        const notes = CommentTag('Part of the "Greatest Hits" compilation series');

        expect(catalog.value, contains('Catalog'));
        expect(rights.value, contains('©'));
        expect(notes.value, contains('compilation'));
      });
    });
  });
}
