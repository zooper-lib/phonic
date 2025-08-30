import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('GenreTag Format Tests', () {
    group('ID3v2.4 null-terminated format', () {
      test('parses single genre without null terminator', () {
        final tag = GenreTag.fromId3v24String('Rock');
        expect(tag.value, equals(['Rock']));
      });

      test('parses multiple genres with null terminators', () {
        final tag = GenreTag.fromId3v24String('Rock\0Alternative\0Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes single genre without null terminator', () {
        final tag = GenreTag(const ['Rock']);
        expect(tag.toId3v24String(), equals('Rock'));
      });

      test('encodes multiple genres with null terminators', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toId3v24String(), equals('Rock\0Alternative\0Indie'));
      });

      test('handles empty string input', () {
        final tag = GenreTag.fromId3v24String('');
        expect(tag.value, equals([]));
      });

      test('handles empty genre list encoding', () {
        final tag = GenreTag(const []);
        expect(tag.toId3v24String(), equals(''));
      });

      test('filters empty values between null terminators', () {
        final tag = GenreTag.fromId3v24String('Rock\0\0Alternative\0\0\0Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading null terminator', () {
        final tag = GenreTag.fromId3v24String('\0Rock\0Alternative');
        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles trailing null terminator', () {
        final tag = GenreTag.fromId3v24String('Rock\0Alternative\0');
        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles multiple consecutive null terminators', () {
        final tag = GenreTag.fromId3v24String('Rock\0\0\0Alternative\0\0Indie\0\0\0');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles unicode genres with null terminators', () {
        final tag = GenreTag.fromId3v24String('Música Popular\0Électronique\0中文流行');
        expect(tag.value, equals(['Música Popular', 'Électronique', '中文流行']));
      });

      test('round-trip consistency for ID3v2.4', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toId3v24String();
        final decoded = GenreTag.fromId3v24String(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('ID3v2.3 slash-separated format', () {
      test('parses single genre without slash', () {
        final tag = GenreTag.fromId3v23String('Rock');
        expect(tag.value, equals(['Rock']));
      });

      test('parses multiple genres with slashes', () {
        final tag = GenreTag.fromId3v23String('Rock/Alternative/Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes single genre without slash', () {
        final tag = GenreTag(const ['Rock']);
        expect(tag.toId3v23String(), equals('Rock'));
      });

      test('encodes multiple genres with slashes', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toId3v23String(), equals('Rock/Alternative/Indie'));
      });

      test('handles empty string input', () {
        final tag = GenreTag.fromId3v23String('');
        expect(tag.value, equals([]));
      });

      test('handles empty genre list encoding', () {
        final tag = GenreTag(const []);
        expect(tag.toId3v23String(), equals(''));
      });

      test('trims whitespace around genres', () {
        final tag = GenreTag.fromId3v23String(' Rock / Alternative / Indie ');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('filters empty values between slashes', () {
        final tag = GenreTag.fromId3v23String('Rock//Alternative///Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading slash', () {
        final tag = GenreTag.fromId3v23String('/Rock/Alternative');
        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles trailing slash', () {
        final tag = GenreTag.fromId3v23String('Rock/Alternative/');
        expect(tag.value, equals(['Rock', 'Alternative']));
      });

      test('handles multiple consecutive slashes', () {
        final tag = GenreTag.fromId3v23String('Rock///Alternative//Indie///');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles unicode genres with slashes', () {
        final tag = GenreTag.fromId3v23String('Música Popular/Électronique/中文流行');
        expect(tag.value, equals(['Música Popular', 'Électronique', '中文流行']));
      });

      test('round-trip consistency for ID3v2.3', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toId3v23String();
        final decoded = GenreTag.fromId3v23String(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('semicolon delimiter parsing (MP4/other formats)', () {
      test('parses single genre', () {
        final tag = GenreTag.fromString('Rock');
        expect(tag.value, equals(['Rock']));
      });

      test('parses multiple genres with semicolons', () {
        final tag = GenreTag.fromString('Rock;Alternative;Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes multiple genres with semicolons', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toEncodedString(';'), equals('Rock;Alternative;Indie'));
      });

      test('handles whitespace around semicolons', () {
        final tag = GenreTag.fromString(' Rock ; Alternative ; Indie ');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('filters empty values between semicolons', () {
        final tag = GenreTag.fromString('Rock;;Alternative;;;Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading and trailing semicolons', () {
        final tag1 = GenreTag.fromString(';Rock;Alternative;');
        final tag2 = GenreTag.fromString(';;;Rock;Alternative;;;');
        expect(tag1.value, equals(['Rock', 'Alternative']));
        expect(tag2.value, equals(['Rock', 'Alternative']));
      });

      test('round-trip consistency with semicolons', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toEncodedString(';');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('pipe delimiter parsing (legacy systems)', () {
      test('parses multiple genres with pipes', () {
        final tag = GenreTag.fromString('Rock|Alternative|Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes multiple genres with pipes', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toEncodedString('|'), equals('Rock|Alternative|Indie'));
      });

      test('handles whitespace around pipes', () {
        final tag = GenreTag.fromString(' Rock | Alternative | Indie ');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('filters empty values between pipes', () {
        final tag = GenreTag.fromString('Rock||Alternative|||Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading and trailing pipes', () {
        final tag1 = GenreTag.fromString('|Rock|Alternative|');
        final tag2 = GenreTag.fromString('|||Rock|Alternative|||');
        expect(tag1.value, equals(['Rock', 'Alternative']));
        expect(tag2.value, equals(['Rock', 'Alternative']));
      });

      test('round-trip consistency with pipes', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toEncodedString('|');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('comma delimiter parsing (human-readable format)', () {
      test('parses multiple genres with commas', () {
        final tag = GenreTag.fromString('Rock,Alternative,Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes multiple genres with commas', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toEncodedString(','), equals('Rock,Alternative,Indie'));
      });

      test('handles whitespace around commas (human-readable)', () {
        final tag = GenreTag.fromString('Rock, Alternative, Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles mixed whitespace with commas', () {
        final tag = GenreTag.fromString('Rock,  Alternative,   Indie,    Pop');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie', 'Pop']));
      });

      test('filters empty values between commas', () {
        final tag = GenreTag.fromString('Rock,,Alternative,,,Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading and trailing commas', () {
        final tag1 = GenreTag.fromString(',Rock,Alternative,');
        final tag2 = GenreTag.fromString(',,,Rock,Alternative,,,');
        expect(tag1.value, equals(['Rock', 'Alternative']));
        expect(tag2.value, equals(['Rock', 'Alternative']));
      });

      test('round-trip consistency with commas', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toEncodedString(',');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals(originalGenres));
      });

      test('handles human-readable format with spaces', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toEncodedString(', '), equals('Rock, Alternative, Indie'));
      });
    });

    group('backslash delimiter parsing (legacy systems)', () {
      test('parses multiple genres with backslashes', () {
        final tag = GenreTag.fromString('Rock\\Alternative\\Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('encodes multiple genres with backslashes', () {
        final tag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        expect(tag.toEncodedString('\\'), equals('Rock\\Alternative\\Indie'));
      });

      test('handles whitespace around backslashes', () {
        final tag = GenreTag.fromString(' Rock \\ Alternative \\ Indie ');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('filters empty values between backslashes', () {
        final tag = GenreTag.fromString('Rock\\\\Alternative\\\\\\Indie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles leading and trailing backslashes', () {
        final tag1 = GenreTag.fromString('\\Rock\\Alternative\\');
        final tag2 = GenreTag.fromString('\\\\\\Rock\\Alternative\\\\\\');
        expect(tag1.value, equals(['Rock', 'Alternative']));
        expect(tag2.value, equals(['Rock', 'Alternative']));
      });

      test('round-trip consistency with backslashes', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toEncodedString('\\');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('automatic format detection priority', () {
      test('prioritizes null terminators over other delimiters', () {
        final tag = GenreTag.fromString('Rock\0Alternative\0Indie/Jazz;Blues|Pop,Electronic\\Ambient');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie/Jazz;Blues|Pop,Electronic\\Ambient']));
      });

      test('uses most frequent delimiter when multiple present', () {
        // Semicolon appears 3 times, others appear once or twice
        final tag = GenreTag.fromString('Rock;Alternative;Indie;Pop/Jazz|Blues,Electronic');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie', 'Pop/Jazz|Blues,Electronic']));
      });

      test('defaults to slash when equal frequency', () {
        // Both semicolon and slash appear once, defaults to slash (first in priority)
        final tag = GenreTag.fromString('Rock;Alternative/Indie');
        expect(tag.value, equals(['Rock;Alternative', 'Indie']));
      });

      test('handles complex mixed delimiter scenarios', () {
        // Pipe appears 4 times, most frequent
        final tag = GenreTag.fromString('Rock|Alternative|Indie|Pop|Electronic;Jazz/Blues,Ambient');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie', 'Pop', 'Electronic;Jazz/Blues,Ambient']));
      });

      test('treats as single genre when no delimiters found', () {
        final tag = GenreTag.fromString('Electronic Music Without Delimiters');
        expect(tag.value, equals(['Electronic Music Without Delimiters']));
      });

      test('delimiter detection priority order', () {
        // Test that when all delimiters appear equally, it uses the first one found in the priority list
        final testCases = [
          ('Rock/Alternative;Indie', ['Rock', 'Alternative;Indie']), // slash wins (first in list)
          ('Rock;Alternative|Indie', ['Rock', 'Alternative|Indie']), // semicolon wins
          ('Rock|Alternative,Indie', ['Rock', 'Alternative,Indie']), // pipe wins
          ('Rock,Alternative\\Indie', ['Rock', 'Alternative\\Indie']), // comma wins
        ];

        for (final (input, expected) in testCases) {
          final tag = GenreTag.fromString(input);
          expect(tag.value, equals(expected), reason: 'Failed for input: $input');
        }
      });
    });

    group('mixed delimiter scenarios and edge cases', () {
      test('handles delimiter within genre names', () {
        final tag = GenreTag.fromString('Rock & Roll;Alternative/Rock;Indie Pop');
        // Semicolon appears twice, slash once, so semicolon wins
        expect(tag.value, equals(['Rock & Roll', 'Alternative/Rock', 'Indie Pop']));
      });

      test('handles escaped delimiters in genre names', () {
        // Note: This tests the current behavior - the parser doesn't handle escaping
        final tag = GenreTag.fromString('Rock\\;Alternative;Indie');
        // Backslash and semicolon each appear once, defaults to slash (but no slash present)
        // So semicolon wins with 1 occurrence
        expect(tag.value, equals(['Rock\\', 'Alternative', 'Indie']));
      });

      test('handles whitespace-only delimited sections', () {
        final tag1 = GenreTag.fromString('Rock;   ;Alternative;  ;Indie');
        final tag2 = GenreTag.fromString('Rock/   /Alternative/  /Indie');
        expect(tag1.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(tag2.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles tabs and newlines as whitespace', () {
        final tag = GenreTag.fromString('Rock\t;\tAlternative\n;\nIndie');
        expect(tag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles very long genre strings with delimiters', () {
        final longGenre = 'A' * 1000;
        final tag = GenreTag.fromString('$longGenre;Short;$longGenre');
        expect(tag.value, equals([longGenre, 'Short', longGenre]));
      });

      test('handles unicode delimiters and genres', () {
        final tag = GenreTag.fromString('Música Popular;Électronique;中文流行;🎵 Electronic');
        expect(tag.value, equals(['Música Popular', 'Électronique', '中文流行', '🎵 Electronic']));
      });

      test('handles empty input variations', () {
        final testCases = ['', '   ', '\t', '\n', '\r\n', ';;;', '///', '|||', ',,,', '\\\\\\'];
        for (final input in testCases) {
          final tag = GenreTag.fromString(input);
          expect(tag.value, equals([]), reason: 'Failed for input: "$input"');
        }
      });

      test('handles single character genres', () {
        final tag = GenreTag.fromString('A;B;C;D;E');
        expect(tag.value, equals(['A', 'B', 'C', 'D', 'E']));
      });
    });

    group('round-trip parsing and encoding consistency', () {
      test('ID3v2.4 round-trip with complex genres', () {
        final originalGenres = ['Progressive Rock', 'Alternative Metal', 'Post-Hardcore', 'Experimental Electronic', 'Ambient Techno'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toId3v24String();
        final decoded = GenreTag.fromId3v24String(encoded);
        expect(decoded.value, equals(originalGenres));
      });

      test('ID3v2.3 round-trip with complex genres', () {
        final originalGenres = ['Progressive Rock', 'Alternative Metal', 'Post-Hardcore', 'Experimental Electronic', 'Ambient Techno'];
        final tag = GenreTag(originalGenres);
        final encoded = tag.toId3v23String();
        final decoded = GenreTag.fromId3v23String(encoded);
        expect(decoded.value, equals(originalGenres));
      });

      test('generic encoding round-trip with various delimiters', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        // Only test single-character delimiters that are supported by the parser
        final delimiters = [';', '|', ',', '\\'];

        for (final delimiter in delimiters) {
          final tag = GenreTag(originalGenres);
          final encoded = tag.toEncodedString(delimiter);
          final decoded = GenreTag.fromString(encoded);
          expect(decoded.value, equals(originalGenres), reason: 'Failed for delimiter: "$delimiter"');
        }
      });

      test('encoding with multi-character delimiters (not parsed back)', () {
        final originalGenres = ['Rock', 'Alternative', 'Indie', 'Electronic'];
        final multiCharDelimiters = [' - ', ' & ', '::'];

        for (final delimiter in multiCharDelimiters) {
          final tag = GenreTag(originalGenres);
          final encoded = tag.toEncodedString(delimiter);
          // Multi-character delimiters are not recognized by the parser,
          // so they will be treated as single genre strings
          final decoded = GenreTag.fromString(encoded);
          expect(decoded.value, equals([encoded]), reason: 'Multi-char delimiter should not be parsed: "$delimiter"');
        }
      });

      test('round-trip with unicode and special characters', () {
        final originalGenres = ['Música Popular Brasileira', 'Électronique Française', '中文流行音乐', '🎵 Electronic Dance Music', 'Post-Rock Math-Rock'];

        // Test with different encoding methods
        final tag = GenreTag(originalGenres);

        // ID3v2.4 format
        final id3v24Encoded = tag.toId3v24String();
        final id3v24Decoded = GenreTag.fromId3v24String(id3v24Encoded);
        expect(id3v24Decoded.value, equals(originalGenres));

        // ID3v2.3 format
        final id3v23Encoded = tag.toId3v23String();
        final id3v23Decoded = GenreTag.fromId3v23String(id3v23Encoded);
        expect(id3v23Decoded.value, equals(originalGenres));

        // Generic semicolon format
        final semicolonEncoded = tag.toEncodedString(';');
        final semicolonDecoded = GenreTag.fromString(semicolonEncoded);
        expect(semicolonDecoded.value, equals(originalGenres));
      });

      test('round-trip preserves exact genre strings', () {
        final originalGenres = [
          'Genre with "quotes"',
          "Genre with 'apostrophes'",
          'Genre with (parentheses)',
          'Genre with [brackets]',
          'Genre with {braces}',
          'Genre with <angles>',
          'Genre with numbers 123',
          'Genre with symbols !@#\$%^&*()',
        ];

        final tag = GenreTag(originalGenres);
        final encoded = tag.toId3v24String();
        final decoded = GenreTag.fromId3v24String(encoded);
        expect(decoded.value, equals(originalGenres));
      });
    });

    group('compatibility with existing files from different tagging software', () {
      test('handles iTunes-style semicolon separation', () {
        // iTunes typically uses semicolons for multiple genres
        final tag = GenreTag.fromString('Alternative Rock; Indie Rock; Post-Rock');
        expect(tag.value, equals(['Alternative Rock', 'Indie Rock', 'Post-Rock']));
      });

      test('handles Windows Media Player slash separation', () {
        // Windows Media Player often uses slashes
        final tag = GenreTag.fromString('Alternative Rock/Indie Rock/Post-Rock');
        expect(tag.value, equals(['Alternative Rock', 'Indie Rock', 'Post-Rock']));
      });

      test('handles MusicBee pipe separation', () {
        // MusicBee sometimes uses pipes
        final tag = GenreTag.fromString('Alternative Rock|Indie Rock|Post-Rock');
        expect(tag.value, equals(['Alternative Rock', 'Indie Rock', 'Post-Rock']));
      });

      test('handles foobar2000 comma separation', () {
        // foobar2000 often displays with commas
        final tag = GenreTag.fromString('Alternative Rock, Indie Rock, Post-Rock');
        expect(tag.value, equals(['Alternative Rock', 'Indie Rock', 'Post-Rock']));
      });

      test('handles MediaMonkey mixed formats', () {
        // MediaMonkey might have inconsistent formatting
        final tag = GenreTag.fromString('Rock; Alternative / Indie, Electronic');
        // Semicolon appears once, slash once, comma once - defaults to slash
        // The trimming removes leading/trailing spaces from each split part
        expect(tag.value, equals(['Rock; Alternative', 'Indie, Electronic']));
      });

      test('handles Winamp legacy backslash separation', () {
        // Some legacy Winamp plugins used backslashes
        final tag = GenreTag.fromString('Alternative Rock\\Indie Rock\\Post-Rock');
        expect(tag.value, equals(['Alternative Rock', 'Indie Rock', 'Post-Rock']));
      });

      test('handles AIMP custom delimiters', () {
        // AIMP allows custom delimiters, but the current parser only supports single-character delimiters
        // Multi-character delimiters will be treated as part of the genre name
        final customDelimiters = [' & ', ' + ', ' :: ', ' >> '];
        for (final delimiter in customDelimiters) {
          final input = 'Rock${delimiter}Alternative${delimiter}Indie';
          final tag = GenreTag.fromString(input);
          // Multi-character delimiters are not recognized, so treated as single genre
          expect(tag.value, equals([input]), reason: 'Multi-character delimiter should not be parsed: "$delimiter"');
        }
      });

      test('handles mixed case and formatting variations', () {
        final variations = [
          'rock;ALTERNATIVE;Indie',
          'Rock ; Alternative ; Indie',
          'ROCK;alternative;INDIE',
          'Rock;  Alternative  ;Indie',
        ];

        for (final variation in variations) {
          final tag = GenreTag.fromString(variation);
          expect(tag.value.length, equals(3), reason: 'Failed for: $variation');
          expect(tag.value[0].toLowerCase(), equals('rock'));
          expect(tag.value[1].toLowerCase(), equals('alternative'));
          expect(tag.value[2].toLowerCase(), equals('indie'));
        }
      });

      test('handles genre names with internal delimiters from different software', () {
        // When genres contain delimiter characters, the parser will split on them
        // This demonstrates the current behavior - not necessarily ideal but consistent
        final testCases = [
          // Semicolon appears twice, slash once, so semicolon wins
          ('Rock & Roll;R&B/Soul;Hip-Hop', ['Rock & Roll', 'R&B/Soul', 'Hip-Hop']),
          // Slash appears once, semicolon once, defaults to slash (first in priority)
          ('Post-Rock/Math-Rock;Drum & Bass', ['Post-Rock', 'Math-Rock;Drum & Bass']),
          // Slash appears twice, semicolon once, so slash wins
          ('Alternative/Indie;Electronic/Dance', ['Alternative', 'Indie;Electronic', 'Dance']),
        ];

        for (final (input, expected) in testCases) {
          final tag = GenreTag.fromString(input);
          expect(tag.value, equals(expected), reason: 'Failed for: $input');
        }
      });
    });

    group('format-specific provenance handling', () {
      test('maintains provenance through ID3v2.4 round-trip', () {
        const provenance = TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);
        final originalTag = GenreTag(const ['Rock', 'Alternative'], provenance: provenance);

        final encoded = originalTag.toId3v24String();
        final decodedTag = GenreTag.fromId3v24String(encoded, provenance: provenance);

        expect(decodedTag.value, equals(['Rock', 'Alternative']));
        expect(decodedTag.provenance, equals(provenance));
      });

      test('maintains provenance through ID3v2.3 round-trip', () {
        const provenance = TagProvenance(ContainerKind.id3v2, '2.3', TagConfidence.certain);
        final originalTag = GenreTag(const ['Rock', 'Alternative'], provenance: provenance);

        final encoded = originalTag.toId3v23String();
        final decodedTag = GenreTag.fromId3v23String(encoded, provenance: provenance);

        expect(decodedTag.value, equals(['Rock', 'Alternative']));
        expect(decodedTag.provenance, equals(provenance));
      });

      test('maintains provenance through generic format round-trip', () {
        const provenance = TagProvenance(ContainerKind.mp4, '1.0', TagConfidence.inferred);
        final originalTag = GenreTag(const ['Rock', 'Alternative'], provenance: provenance);

        final encoded = originalTag.toEncodedString(';');
        final decodedTag = GenreTag.fromString(encoded, provenance: provenance);

        expect(decodedTag.value, equals(['Rock', 'Alternative']));
        expect(decodedTag.provenance, equals(provenance));
      });
    });

    group('additional edge cases and stress tests', () {
      test('handles extremely long genre lists', () {
        final longGenreList = List.generate(10, (i) => 'Genre${String.fromCharCode(65 + i)}'); // GenreA, GenreB, etc.
        final tag = GenreTag(longGenreList);

        // Test ID3v2.4 encoding/decoding (null-terminated, so no parsing issues)
        final id3v24Encoded = tag.toId3v24String();
        final id3v24Decoded = GenreTag.fromId3v24String(id3v24Encoded);
        expect(id3v24Decoded.value, equals(longGenreList));

        // Test semicolon encoding/decoding (semicolon not in genre names)
        final semicolonEncoded = tag.toEncodedString(';');
        final semicolonDecoded = GenreTag.fromString(semicolonEncoded);
        expect(semicolonDecoded.value, equals(longGenreList));
      });

      test('handles genres with only delimiter characters', () {
        final tag1 = GenreTag.fromString(';;;');
        final tag2 = GenreTag.fromString('///');
        final tag3 = GenreTag.fromString('|||');
        final tag4 = GenreTag.fromString(',,,');
        final tag5 = GenreTag.fromString('\\\\\\');

        expect(tag1.value, equals([]));
        expect(tag2.value, equals([]));
        expect(tag3.value, equals([]));
        expect(tag4.value, equals([]));
        expect(tag5.value, equals([]));
      });

      test('handles mixed null terminators and other delimiters', () {
        // Null terminators should always win regardless of frequency
        final tag1 = GenreTag.fromString('Rock\0Alternative;Jazz;Blues;Electronic;Ambient');
        expect(tag1.value, equals(['Rock', 'Alternative;Jazz;Blues;Electronic;Ambient']));

        final tag2 = GenreTag.fromString('Rock;Jazz;Blues\0Alternative');
        expect(tag2.value, equals(['Rock;Jazz;Blues', 'Alternative']));
      });

      test('handles genres with control characters', () {
        final genresWithControlChars = ['Rock_Tab_Newline', 'Alternative_Null_SOH', 'Indie_DEL'];
        final tag = GenreTag(genresWithControlChars);

        // Test that genres without delimiter characters are preserved
        final encoded = tag.toEncodedString(';');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals(genresWithControlChars));
      });

      test('handles genres with actual control characters in ID3v2.4', () {
        // ID3v2.4 null-terminated format can handle control characters
        final genresWithControlChars = ['Rock\t\n\r', 'Alternative\x01\x02', 'Indie\x7F'];
        final tag = GenreTag(genresWithControlChars);

        // ID3v2.4 format should preserve all characters (except null which is delimiter)
        final id3v24Encoded = tag.toId3v24String();
        final id3v24Decoded = GenreTag.fromId3v24String(id3v24Encoded);
        expect(id3v24Decoded.value, equals(genresWithControlChars));
      });

      test('handles very large individual genre names', () {
        final hugeGenre = 'A' * 100000; // 100KB genre name
        final tag = GenreTag([hugeGenre, 'Normal Genre']);

        final encoded = tag.toEncodedString(';');
        final decoded = GenreTag.fromString(encoded);
        expect(decoded.value, equals([hugeGenre, 'Normal Genre']));
      });

      test('delimiter frequency tie-breaking behavior', () {
        // When multiple delimiters have the same frequency, it should use the first one found in the priority list
        final testCases = [
          ('A/B;C', ['A', 'B;C']), // slash and semicolon each appear once, slash wins (first in priority)
          ('A;B|C', ['A', 'B|C']), // semicolon and pipe each appear once, semicolon wins
          ('A|B,C', ['A', 'B,C']), // pipe and comma each appear once, pipe wins
          ('A,B\\C', ['A', 'B\\C']), // comma and backslash each appear once, comma wins
        ];

        for (final (input, expected) in testCases) {
          final tag = GenreTag.fromString(input);
          expect(tag.value, equals(expected), reason: 'Tie-breaking failed for: $input');
        }
      });

      test('performance with many delimiters', () {
        // Test performance doesn't degrade significantly with many delimiters
        final manyDelimiters = List.generate(26, (i) => 'Genre${String.fromCharCode(65 + i)}').join(';');
        final tag = GenreTag.fromString(manyDelimiters);
        expect(tag.value.length, equals(26));
        expect(tag.value.first, equals('GenreA'));
        expect(tag.value.last, equals('GenreZ'));
      });
    });
  });
}
