import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('LyricsTag', () {
    group('constructor', () {
      test('creates instance with lyrics value and default provenance', () {
        const tag = LyricsTag('Verse 1:\nHello world\nThis is my song');

        expect(tag.value, equals('Verse 1:\nHello world\nThis is my song'));
        expect(tag.key, equals(TagKey.lyrics));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with lyrics value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = LyricsTag('Complete song lyrics here...', provenance: provenance);

        expect(tag.value, equals('Complete song lyrics here...'));
        expect(tag.key, equals(TagKey.lyrics));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty lyrics', () {
        const tag = LyricsTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.lyrics));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with simple lyrics', () {
        const simpleLyrics = LyricsTag('La la la, la la la');
        const singleWord = LyricsTag('Hello');
        const singleLine = LyricsTag('This is a single line of lyrics');

        expect(simpleLyrics.value, equals('La la la, la la la'));
        expect(singleWord.value, equals('Hello'));
        expect(singleLine.value, equals('This is a single line of lyrics'));

        // All should have the same key type
        expect(simpleLyrics.key, equals(TagKey.lyrics));
        expect(singleWord.key, equals(TagKey.lyrics));
        expect(singleLine.key, equals(TagKey.lyrics));
      });

      test('creates instance with multi-line lyrics', () {
        const multiLineLyrics = '''Verse 1:
Hello world
This is my song
I hope you like it

Chorus:
Sing along with me
La la la la la
Music sets us free

Verse 2:
Another verse here
With more lyrics to share
The melody flows''';

        const tag = LyricsTag(multiLineLyrics);

        expect(tag.value, equals(multiLineLyrics));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('creates instance with unicode and special characters', () {
        const tag = LyricsTag('Café ♪ ♫ ♪ música española ñ');

        expect(tag.value, equals('Café ♪ ♫ ♪ música española ñ'));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('creates instance with very long lyrics content', () {
        final longLyrics = 'This is a very long line of lyrics that goes on and on ' * 100;
        final tag = LyricsTag(longLyrics);

        expect(tag.value, equals(longLyrics));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('key is always TagKey.lyrics', () {
        const tag1 = LyricsTag('Some lyrics');
        const tag2 = LyricsTag('Different lyrics');
        const tag3 = LyricsTag('');

        expect(tag1.key, equals(TagKey.lyrics));
        expect(tag2.key, equals(TagKey.lyrics));
        expect(tag3.key, equals(TagKey.lyrics));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = LyricsTag(
          'Simple lyrics here',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Simple lyrics here'));
        expect(tag.key, equals(TagKey.lyrics));
      });
    });

    group('withProvenance', () {
      test('returns new LyricsTag instance with updated provenance', () {
        const originalTag = LyricsTag(
          'Original lyrics content',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original lyrics content'));
        expect(originalTag.key, equals(TagKey.lyrics));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original lyrics content'));
        expect(updatedTag.key, equals(TagKey.lyrics));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns LyricsTag type specifically', () {
        const originalTag = LyricsTag('Some lyrics');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<LyricsTag>());
        expect(updatedTag.runtimeType, equals(LyricsTag));
      });

      test('preserves lyrics value exactly', () {
        const originalTag = LyricsTag('Multi-line\nlyrics\nwith\nbreaks');
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
        const originalTag = LyricsTag(
          'Lyrics with provenance',
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
        const originalTag = LyricsTag('Test lyrics');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test lyrics'));
          expect(updatedTag.key, equals(TagKey.lyrics));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = LyricsTag('Test lyrics');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test lyrics'));
          expect(updatedTag.key, equals(TagKey.lyrics));
        }
      });
    });

    group('equality', () {
      test('equal instances with same lyrics, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = LyricsTag('Same lyrics content', provenance: provenance);
        const tag2 = LyricsTag('Same lyrics content', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different lyrics', () {
        const tag1 = LyricsTag('First lyrics');
        const tag2 = LyricsTag('Second lyrics');

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

        const tag1 = LyricsTag('Same lyrics', provenance: provenance1);
        const tag2 = LyricsTag('Same lyrics', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = LyricsTag('Identical lyrics');
        const tag2 = LyricsTag('Identical lyrics');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty lyrics', () {
        const tag1 = LyricsTag('');
        const tag2 = LyricsTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = LyricsTag('Hello World');
        const tag2 = LyricsTag('hello world');
        const tag3 = LyricsTag('HELLO WORLD');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag2, isNot(equals(tag3)));
      });

      test('handles whitespace differences', () {
        const tag1 = LyricsTag('Hello World');
        const tag2 = LyricsTag('Hello  World');
        const tag3 = LyricsTag('Hello\nWorld');
        const tag4 = LyricsTag('Hello\tWorld');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag1, isNot(equals(tag4)));
        expect(tag2, isNot(equals(tag3)));
      });

      test('handles multi-line lyrics equality', () {
        const lyrics1 = '''Verse 1:
Hello world
This is my song''';

        const lyrics2 = '''Verse 1:
Hello world
This is my song''';

        const lyrics3 = '''Verse 1:
Hello world
This is different''';

        const tag1 = LyricsTag(lyrics1);
        const tag2 = LyricsTag(lyrics2);
        const tag3 = LyricsTag(lyrics3);

        expect(tag1, equals(tag2));
        expect(tag1, isNot(equals(tag3)));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        const tag = LyricsTag('Test lyrics content', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test lyrics content'));
        expect(tag.props[1], equals(TagKey.lyrics));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = LyricsTag('Same lyrics');
        const tag2 = LyricsTag('Same lyrics');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and lyrics', () {
        const tag = LyricsTag('Simple lyrics');
        final result = tag.toString();

        expect(result, contains('LyricsTag'));
        expect(result, contains('Simple lyrics'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = LyricsTag('Lyrics with provenance', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('LyricsTag'));
        expect(result, contains('Lyrics with provenance'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in lyrics', () {
        const tag = LyricsTag('Café ♪ música');
        final result = tag.toString();

        expect(result, contains('Café ♪ música'));
      });

      test('handles empty lyrics', () {
        const tag = LyricsTag('');
        final result = tag.toString();

        expect(result, contains('LyricsTag('));
        expect(result, contains('TagProvenance.none()'));
      });

      test('handles multi-line lyrics in toString', () {
        const tag = LyricsTag('Line 1\nLine 2\nLine 3');
        final result = tag.toString();

        expect(result, contains('Line 1'));
        expect(result, contains('Line 2'));
        expect(result, contains('Line 3'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = LyricsTag(
          'Immutable lyrics',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable lyrics'));
        expect(tag.key, equals(TagKey.lyrics));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = LyricsTag('Original lyrics');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original lyrics'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original lyrics'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = LyricsTag('String lyrics');
        const tag2 = LyricsTag('');
        const tag3 = LyricsTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains LyricsTag type', () {
        const originalTag = LyricsTag('Test lyrics');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<LyricsTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(LyricsTag));
      });
    });

    group('edge cases', () {
      test('handles very long lyrics content', () {
        final longLyrics = 'This is a very long line of lyrics ' * 1000;
        final tag = LyricsTag(longLyrics);

        expect(tag.value, equals(longLyrics));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('handles unicode and special musical symbols', () {
        const tag = LyricsTag('♪ ♫ ♪ Café música española ñ ♪ ♫ ♪');
        expect(tag.value, equals('♪ ♫ ♪ Café música española ñ ♪ ♫ ♪'));
      });

      test('handles whitespace-only lyrics', () {
        const tag1 = LyricsTag(' ');
        const tag2 = LyricsTag('   ');
        const tag3 = LyricsTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles lyrics with quotes and special formatting', () {
        const tag1 = LyricsTag('"Hello world"');
        const tag2 = LyricsTag("'Single quotes'");
        const tag3 = LyricsTag('Lyrics with:\nTabs\t\tand\nNewlines');

        expect(tag1.value, equals('"Hello world"'));
        expect(tag2.value, equals("'Single quotes'"));
        expect(tag3.value, equals('Lyrics with:\nTabs\t\tand\nNewlines'));
      });

      test('handles various lyrics formats', () {
        const structuredLyrics = LyricsTag('[Verse 1]\nHello world\n\n[Chorus]\nSing along');
        const timedLyrics = LyricsTag('[00:15.50]Hello world\n[00:18.20]This is my song');
        const simpleLyrics = LyricsTag('Just simple lyrics without structure');
        const instrumentalTag = LyricsTag('[Instrumental]');

        expect(structuredLyrics.value, equals('[Verse 1]\nHello world\n\n[Chorus]\nSing along'));
        expect(timedLyrics.value, equals('[00:15.50]Hello world\n[00:18.20]This is my song'));
        expect(simpleLyrics.value, equals('Just simple lyrics without structure'));
        expect(instrumentalTag.value, equals('[Instrumental]'));
      });

      test('handles lyrics with HTML-like tags', () {
        const tag = LyricsTag('<verse>Hello world</verse>\n<chorus>Sing along</chorus>');
        expect(tag.value, equals('<verse>Hello world</verse>\n<chorus>Sing along</chorus>'));
      });

      test('handles lyrics with escape sequences', () {
        const tag = LyricsTag('Line 1\\nLine 2\\tTabbed\\r\\nWindows line ending');
        expect(tag.value, equals('Line 1\\nLine 2\\tTabbed\\r\\nWindows line ending'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = LyricsTag('Test lyrics');

        expect(tag, isA<LyricsTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = LyricsTag('Same lyrics');
        const tag2 = LyricsTag('Same lyrics');
        const tag3 = LyricsTag('Different lyrics');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = LyricsTag('Test lyrics');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'LyricsTag\(.*\)'));
        expect(result, contains('Test lyrics'));
        expect(result, contains('provenance:'));
      });
    });

    group('lyrics specific scenarios', () {
      test('handles common song structures', () {
        const verseChorus = '''[Verse 1]
This is the first verse
With some meaningful lyrics

[Chorus]
This is the catchy chorus
Everyone sings along

[Verse 2]
Second verse continues
The story of the song

[Chorus]
This is the catchy chorus
Everyone sings along

[Bridge]
A different section here
Changes the mood

[Chorus]
This is the catchy chorus
Everyone sings along''';

        final tag = const LyricsTag(verseChorus);
        expect(tag.value, equals(verseChorus));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('handles instrumental and non-vocal tracks', () {
        const instrumental = LyricsTag('[Instrumental]');
        const noLyrics = LyricsTag('');
        const vocalless = LyricsTag('[No lyrics]');

        expect(instrumental.value, equals('[Instrumental]'));
        expect(noLyrics.value, equals(''));
        expect(vocalless.value, equals('[No lyrics]'));
      });

      test('handles multi-language lyrics', () {
        const multiLang = '''English: Hello world
Spanish: Hola mundo
French: Bonjour le monde
German: Hallo Welt
Japanese: こんにちは世界''';

        final tag = const LyricsTag(multiLang);
        expect(tag.value, equals(multiLang));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('handles timed lyrics formats', () {
        const lrcFormat = '''[00:12.50]Line 1 of lyrics
[00:15.80]Line 2 of lyrics
[00:19.20]Line 3 of lyrics
[00:22.60]Line 4 of lyrics''';

        const srtFormat = '''1
00:00:12,500 --> 00:00:15,800
Line 1 of lyrics

2
00:00:15,800 --> 00:00:19,200
Line 2 of lyrics''';

        final lrcTag = const LyricsTag(lrcFormat);
        final srtTag = const LyricsTag(srtFormat);

        expect(lrcTag.value, equals(lrcFormat));
        expect(srtTag.value, equals(srtFormat));
      });

      test('handles lyrics with chord notations', () {
        const chordsAndLyrics = '''[C]Hello [G]world, this is [Am]my [F]song
[C]I hope you [G]like it, it won't take [Am]long [F]
[Dm]This is the [G]bridge section [C]here
[F]With different [G]chords to make it [C]clear''';

        final tag = const LyricsTag(chordsAndLyrics);
        expect(tag.value, equals(chordsAndLyrics));
        expect(tag.key, equals(TagKey.lyrics));
      });

      test('handles rap and spoken word lyrics', () {
        const rapLyrics = '''Yo, check it, this is how we do it
Fast-paced lyrics with a heavy beat
Every word counts, every line's complete
From the street to the stage, we can't be beat

[Spoken]
And now for something completely different...

Back to the rap, with a different flow
Switching up the rhythm, high and low
This is how the story continues to grow
Until the very end of the show''';

        final tag = const LyricsTag(rapLyrics);
        expect(tag.value, equals(rapLyrics));
        expect(tag.key, equals(TagKey.lyrics));
      });
    });
  });
}
