import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('GenreTag', () {
    group('constructor', () {
      test('creates instance with genre list and default provenance', () {
        final tag = GenreTag(const ['Rock', 'Alternative']);

        expect(tag.value, equals(['Rock', 'Alternative']));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with genre list and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = GenreTag(const ['Jazz', 'Blues'], provenance: provenance);

        expect(tag.value, equals(['Jazz', 'Blues']));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty genre list', () {
        final tag = GenreTag(const []);

        expect(tag.value, equals([]));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with single genre', () {
        final tag = GenreTag(const ['Electronic']);

        expect(tag.value, equals(['Electronic']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('creates instance with multiple genres', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie', 'Pop']);

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie', 'Pop']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('creates instance with unicode and special characters', () {
        final tag = GenreTag(const ['Música Popular', 'Électronique', '中文流行', '🎵 Electronic']);

        expect(tag.value, equals(['Música Popular', 'Électronique', '中文流行', '🎵 Electronic']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('key is always TagKey.genre', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['Jazz', 'Blues']);
        final tag3 = GenreTag(const []);

        expect(tag1.key, equals(TagKey.genre));
        expect(tag2.key, equals(TagKey.genre));
        expect(tag3.key, equals(TagKey.genre));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        final tag = GenreTag(
          const ['Rock', 'Alternative'],
          provenance: const TagProvenance.none(),
        );

        expect(tag.value, equals(['Rock', 'Alternative']));
        expect(tag.key, equals(TagKey.genre));
      });
    });

    group('single constructor', () {
      test('creates instance with single genre string', () {
        final tag = GenreTag.single('Jazz');

        expect(tag.value, equals(['Jazz']));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with single genre and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = GenreTag.single('Classical', provenance: provenance);

        expect(tag.value, equals(['Classical']));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance, equals(provenance));
      });

      test('handles empty string as single genre', () {
        final tag = GenreTag.single('');

        expect(tag.value, equals(['']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('handles unicode and special characters', () {
        final tag = GenreTag.single('Música Popular Brasileira');

        expect(tag.value, equals(['Música Popular Brasileira']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('handles very long genre name', () {
        final longGenre = 'A' * 1000;
        final tag = GenreTag.single(longGenre);

        expect(tag.value, equals([longGenre]));
        expect(tag.value.first.length, equals(1000));
      });
    });

    group('fromString constructor', () {
      group('automatic delimiter detection', () {
        test('detects semicolon delimiter', () {
          final tag = GenreTag.fromString('Rock;Alternative;Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('detects slash delimiter', () {
          final tag = GenreTag.fromString('Rock/Alternative/Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('detects pipe delimiter', () {
          final tag = GenreTag.fromString('Rock|Alternative|Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('detects comma delimiter', () {
          final tag = GenreTag.fromString('Rock,Alternative,Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('detects backslash delimiter', () {
          final tag = GenreTag.fromString('Rock\\Alternative\\Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('prioritizes null terminator over other delimiters', () {
          final tag = GenreTag.fromString('Rock${String.fromCharCode(0)}Alternative${String.fromCharCode(0)}Indie/Jazz;Blues');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie/Jazz;Blues']));
          expect(tag.key, equals(TagKey.genre));
        });

        test('uses most frequent delimiter when multiple present', () {
          final tag = GenreTag.fromString('Rock;Alternative;Indie/Pop');

          // Semicolon appears twice, slash appears once, so semicolon wins
          expect(tag.value, equals(['Rock', 'Alternative', 'Indie/Pop']));
        });

        test('defaults to slash when equal frequency', () {
          final tag = GenreTag.fromString('Rock;Alternative/Indie');

          // Both semicolon and slash appear once, defaults to slash
          expect(tag.value, equals(['Rock;Alternative', 'Indie']));
        });

        test('treats as single genre when no delimiters found', () {
          final tag = GenreTag.fromString('Electronic Music');

          expect(tag.value, equals(['Electronic Music']));
        });

        test('handles empty string', () {
          final tag = GenreTag.fromString('');

          expect(tag.value, equals([]));
        });

        test('handles whitespace-only string', () {
          final tag = GenreTag.fromString('   ');

          expect(tag.value, equals([]));
        });
      });

      group('whitespace handling', () {
        test('trims whitespace around genres', () {
          final tag = GenreTag.fromString(' Rock ; Alternative ; Indie ');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
        });

        test('handles mixed whitespace with commas', () {
          final tag = GenreTag.fromString('Rock, Alternative,  Indie,   Pop');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie', 'Pop']));
        });

        test('filters out empty values after splitting', () {
          final tag = GenreTag.fromString('Rock;;Alternative;;;Indie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
        });

        test('handles tabs and newlines', () {
          final tag = GenreTag.fromString('Rock\t;\tAlternative\n;\nIndie');

          expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
        });
      });

      test('creates with custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );
        final tag = GenreTag.fromString('Rock;Jazz', provenance: provenance);

        expect(tag.value, equals(['Rock', 'Jazz']));
        expect(tag.provenance, equals(provenance));
      });
    });

    group('fromId3v24String constructor', () {
      test('parses null-terminated string correctly', () {
        final tag = GenreTag.fromId3v24String('Rock${String.fromCharCode(0)}Alternative${String.fromCharCode(0)}Indie');

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('handles single genre without null terminator', () {
        final tag = GenreTag.fromId3v24String('Jazz');

        expect(tag.value, equals(['Jazz']));
      });

      test('handles empty string', () {
        final tag = GenreTag.fromId3v24String('');

        expect(tag.value, equals([]));
      });

      test('filters out empty values between null terminators', () {
        final tag = GenreTag.fromId3v24String(
          'Rock${String.fromCharCode(0)}${String.fromCharCode(0)}Alternative${String.fromCharCode(0)}${String.fromCharCode(0)}${String.fromCharCode(0)}Indie',
        );

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles trailing null terminator', () {
        final tag = GenreTag.fromId3v24String('Rock${String.fromCharCode(0)}Alternative${String.fromCharCode(0)}');

        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles leading null terminator', () {
        final tag = GenreTag.fromId3v24String('${String.fromCharCode(0)}Rock${String.fromCharCode(0)}Alternative');

        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('creates with custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = GenreTag.fromId3v24String('Rock${String.fromCharCode(0)}Jazz', provenance: provenance);

        expect(tag.value, equals(['Rock', 'Jazz']));
        expect(tag.provenance, equals(provenance));
      });
    });

    group('fromId3v23String constructor', () {
      test('parses slash-separated string correctly', () {
        final tag = GenreTag.fromId3v23String('Rock/Alternative/Indie');

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(tag.key, equals(TagKey.genre));
      });

      test('handles single genre without slash', () {
        final tag = GenreTag.fromId3v23String('Jazz');

        expect(tag.value, equals(['Jazz']));
      });

      test('handles empty string', () {
        final tag = GenreTag.fromId3v23String('');

        expect(tag.value, equals([]));
      });

      test('trims whitespace around genres', () {
        final tag = GenreTag.fromId3v23String(' Rock / Alternative / Indie ');

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('filters out empty values between slashes', () {
        final tag = GenreTag.fromId3v23String('Rock//Alternative///Indie');

        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles trailing slash', () {
        final tag = GenreTag.fromId3v23String('Rock/Alternative/');

        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles leading slash', () {
        final tag = GenreTag.fromId3v23String('/Rock/Alternative');

        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('creates with custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.3',
          TagConfidence.certain,
        );
        final tag = GenreTag.fromId3v23String('Rock/Jazz', provenance: provenance);

        expect(tag.value, equals(['Rock', 'Jazz']));
        expect(tag.provenance, equals(provenance));
      });
    });

    group('toEncodedString method', () {
      test('encodes with default semicolon delimiter', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        final result = tag.toEncodedString();

        expect(result, equals('Rock;Alternative;Indie'));
      });

      test('encodes with custom delimiter', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);

        expect(tag.toEncodedString('/'), equals('Rock/Alternative/Indie'));
        expect(tag.toEncodedString('|'), equals('Rock|Alternative|Indie'));
        expect(tag.toEncodedString(', '), equals('Rock, Alternative, Indie'));
        expect(tag.toEncodedString(' - '), equals('Rock - Alternative - Indie'));
      });

      test('handles single genre', () {
        final tag = GenreTag(const ['Jazz']);
        final result = tag.toEncodedString();

        expect(result, equals('Jazz'));
      });

      test('handles empty genre list', () {
        final tag = GenreTag(const []);
        final result = tag.toEncodedString();

        expect(result, equals(''));
      });

      test('handles unicode and special characters', () {
        final tag = GenreTag(const ['Música Popular', 'Électronique']);
        final result = tag.toEncodedString(';');

        expect(result, equals('Música Popular;Électronique'));
      });

      test('handles empty delimiter', () {
        final tag = GenreTag(const ['Rock', 'Alternative']);
        final result = tag.toEncodedString('');

        expect(result, equals('RockAlternative'));
      });
    });

    group('toId3v24String method', () {
      test('encodes with null terminators', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        final result = tag.toId3v24String();

        expect(result, equals('Rock${String.fromCharCode(0)}Alternative${String.fromCharCode(0)}Indie'));
      });

      test('handles single genre', () {
        final tag = GenreTag(const ['Jazz']);
        final result = tag.toId3v24String();

        expect(result, equals('Jazz'));
      });

      test('handles empty genre list', () {
        final tag = GenreTag(const []);
        final result = tag.toId3v24String();

        expect(result, equals(''));
      });

      test('handles unicode and special characters', () {
        final tag = GenreTag(const ['Música Popular', 'Électronique']);
        final result = tag.toId3v24String();

        expect(result, equals('Música Popular${String.fromCharCode(0)}Électronique'));
      });
    });

    group('toId3v23String method', () {
      test('encodes with slashes', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        final result = tag.toId3v23String();

        expect(result, equals('Rock/Alternative/Indie'));
      });

      test('handles single genre', () {
        final tag = GenreTag(const ['Jazz']);
        final result = tag.toId3v23String();

        expect(result, equals('Jazz'));
      });

      test('handles empty genre list', () {
        final tag = GenreTag(const []);
        final result = tag.toId3v23String();

        expect(result, equals(''));
      });

      test('handles unicode and special characters', () {
        final tag = GenreTag(const ['Música Popular', 'Électronique']);
        final result = tag.toId3v23String();

        expect(result, equals('Música Popular/Électronique'));
      });
    });

    group('withProvenance', () {
      test('returns new GenreTag instance with updated provenance', () {
        final originalTag = GenreTag(
          const ['Rock', 'Alternative'],
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(['Rock', 'Alternative']));
        expect(originalTag.key, equals(TagKey.genre));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(['Rock', 'Alternative']));
        expect(updatedTag.key, equals(TagKey.genre));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns GenreTag type specifically', () {
        final originalTag = GenreTag(const ['Jazz']);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<GenreTag>());
        expect(updatedTag.runtimeType, equals(GenreTag));
      });

      test('preserves genre list exactly', () {
        final originalTag = GenreTag(const ['Complex Genre: éñ中文🎵', 'Another Genre']);
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
        final originalTag = GenreTag(
          const ['Test Genre'],
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        final originalTag = GenreTag(const ['Test Genre']);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(['Test Genre']));
          expect(updatedTag.key, equals(TagKey.genre));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = GenreTag(const ['Test Genre']);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(['Test Genre']));
          expect(updatedTag.key, equals(TagKey.genre));
        }
      });
    });

    group('equality', () {
      test('equal instances with same genres, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = GenreTag(const ['Rock', 'Alternative'], provenance: provenance);
        final tag2 = GenreTag(const ['Rock', 'Alternative'], provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different genres', () {
        final tag1 = GenreTag(const ['Rock', 'Alternative']);
        final tag2 = GenreTag(const ['Jazz', 'Blues']);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different genre order', () {
        final tag1 = GenreTag(const ['Rock', 'Alternative']);
        final tag2 = GenreTag(const ['Alternative', 'Rock']);

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

        final tag1 = GenreTag(const ['Rock'], provenance: provenance1);
        final tag2 = GenreTag(const ['Rock'], provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = GenreTag(const ['Jazz']);
        final tag2 = GenreTag(const ['Jazz']);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty genre lists', () {
        final tag1 = GenreTag(const []);
        final tag2 = GenreTag(const []);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const ['rock']);
        final tag3 = GenreTag(const ['ROCK']);

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
        final tag = GenreTag(const ['Rock', 'Jazz'], provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(['Rock', 'Jazz']));
        expect(tag.props[1], equals(TagKey.genre));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = GenreTag(const ['Same Genre']);
        final tag2 = GenreTag(const ['Same Genre']);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and genres', () {
        final tag = GenreTag(const ['Rock', 'Alternative']);
        final result = tag.toString();

        expect(result, contains('GenreTag'));
        expect(result, contains('[Rock, Alternative]'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = GenreTag(const ['Jazz'], provenance: provenance);
        final result = tag.toString();

        expect(result, contains('GenreTag'));
        expect(result, contains('[Jazz]'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in genres', () {
        final tag = GenreTag(const ['Special: éñ中文🎵']);
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty genre list', () {
        final tag = GenreTag(const []);
        final result = tag.toString();

        expect(result, contains('GenreTag('));
        expect(result, contains('[]'));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = GenreTag(
          const ['Immutable Genre'],
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(['Immutable Genre']));
        expect(tag.key, equals(TagKey.genre));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = GenreTag(const ['Original Genre']);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(['Original Genre']));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(['Original Genre']));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });

      test('genre list is immutable', () {
        final genres = ['Rock', 'Alternative'];
        final tag = GenreTag(genres);

        // Modifying original list should not affect tag
        genres.add('Jazz');
        expect(tag.value, equals(['Rock', 'Alternative']));

        // Tag's value list should be unmodifiable
        expect(() => tag.value.add('Pop'), throwsUnsupportedError);
      });
    });

    group('type safety', () {
      test('value is always List<String> type', () {
        final tag1 = GenreTag(const ['Rock']);
        final tag2 = GenreTag(const []);
        final tag3 = GenreTag(const ['123', '456']);

        expect(tag1.value, isA<List<String>>());
        expect(tag2.value, isA<List<String>>());
        expect(tag3.value, isA<List<String>>());
        expect(tag3.value, equals(['123', '456'])); // Strings, not ints
      });

      test('withProvenance maintains GenreTag type', () {
        final originalTag = GenreTag(const ['Test']);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<GenreTag>());
        expect(newTag.value, isA<List<String>>());
        expect(newTag.runtimeType, equals(GenreTag));
      });
    });

    group('edge cases', () {
      test('handles very long genre names', () {
        final longGenre = 'A' * 10000;
        final tag = GenreTag([longGenre]);

        expect(tag.value, equals([longGenre]));
        expect(tag.value.first.length, equals(10000));
        expect(tag.key, equals(TagKey.genre));
      });

      test('handles unicode and emoji in genre names', () {
        final tag = GenreTag(const ['🎵 Electronic Music', 'Música Popular', '中文流行']);
        expect(tag.value, equals(['🎵 Electronic Music', 'Música Popular', '中文流行']));
      });

      test('handles whitespace-only genres', () {
        final tag1 = GenreTag(const [' ']);
        final tag2 = GenreTag(const ['   ']);
        final tag3 = GenreTag(const ['\t\n']);

        expect(tag1.value, equals([' ']));
        expect(tag2.value, equals(['   ']));
        expect(tag3.value, equals(['\t\n']));
      });

      test('handles genres with quotes and special formatting', () {
        final tag1 = GenreTag(const ['"Quoted Genre"']);
        final tag2 = GenreTag(const ["'Single Quoted'"]);
        final tag3 = GenreTag(const ['Genre with\nnewlines\tand\ttabs']);

        expect(tag1.value, equals(['"Quoted Genre"']));
        expect(tag2.value, equals(["'Single Quoted'"]));
        expect(tag3.value, equals(['Genre with\nnewlines\tand\ttabs']));
      });

      test('handles mixed delimiters in fromString', () {
        final tag = GenreTag.fromString('Rock;Alternative/Indie|Pop,Electronic\\Ambient');

        // All delimiters appear once, so it defaults to slash (/) which appears first in the priority list
        expect(tag.value, equals(['Rock;Alternative', 'Indie|Pop,Electronic\\Ambient']));
      });

      test('handles delimiter at start and end in fromString', () {
        final tag1 = GenreTag.fromString(';Rock;Alternative;');
        final tag2 = GenreTag.fromString('/Rock/Alternative/');

        expect(tag1.value, equals(['Rock', 'Alternative']));
        expect(tag2.value, equals(['Rock', 'Alternative']));
      });

      test('handles multiple consecutive delimiters', () {
        final tag1 = GenreTag.fromString('Rock;;;Alternative;;;Indie');
        final tag2 = GenreTag.fromString('Rock///Alternative///Indie');

        expect(tag1.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(tag2.value, equals(['Rock', 'Alternative', 'Indie']));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<List<String>> correctly', () {
        final tag = GenreTag(const ['Test Genre']);

        expect(tag, isA<GenreTag>());
        expect(tag.value, isA<List<String>>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = GenreTag(const ['Same Genre']);
        final tag2 = GenreTag(const ['Same Genre']);
        final tag3 = GenreTag(const ['Different Genre']);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = GenreTag(const ['Test Genre']);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'GenreTag\(.*\)'));
        expect(result, contains('[Test Genre]'));
        expect(result, contains('provenance:'));
      });
    });

    group('round-trip parsing and encoding', () {
      test('ID3v2.4 round-trip consistency', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie'];
        final tag = GenreTag(originalGenres);

        final encoded = tag.toId3v24String();
        final parsed = GenreTag.fromId3v24String(encoded);

        expect(parsed.value, equals(originalGenres));
      });

      test('ID3v2.3 round-trip consistency', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie'];
        final tag = GenreTag(originalGenres);

        final encoded = tag.toId3v23String();
        final parsed = GenreTag.fromId3v23String(encoded);

        expect(parsed.value, equals(originalGenres));
      });

      test('generic encoding round-trip consistency', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie'];
        final tag = GenreTag(originalGenres);

        final encoded = tag.toEncodedString(';');
        final parsed = GenreTag.fromString(encoded);

        expect(parsed.value, equals(originalGenres));
      });

      test('handles empty genre list in round-trip', () {
        final tag = GenreTag(const []);

        final id3v24Encoded = tag.toId3v24String();
        final id3v23Encoded = tag.toId3v23String();
        final genericEncoded = tag.toEncodedString();

        final id3v24Parsed = GenreTag.fromId3v24String(id3v24Encoded);
        final id3v23Parsed = GenreTag.fromId3v23String(id3v23Encoded);
        final genericParsed = GenreTag.fromString(genericEncoded);

        expect(id3v24Parsed.value, equals([]));
        expect(id3v23Parsed.value, equals([]));
        expect(genericParsed.value, equals([]));
      });

      test('handles single genre in round-trip', () {
        final originalGenres = ['Jazz'];
        final tag = GenreTag(originalGenres);

        final id3v24Encoded = tag.toId3v24String();
        final id3v23Encoded = tag.toId3v23String();

        final id3v24Parsed = GenreTag.fromId3v24String(id3v24Encoded);
        final id3v23Parsed = GenreTag.fromId3v23String(id3v23Encoded);

        expect(id3v24Parsed.value, equals(originalGenres));
        expect(id3v23Parsed.value, equals(originalGenres));
      });
    });
  });
}
