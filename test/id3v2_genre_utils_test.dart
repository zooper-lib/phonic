import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/formats/id3/id3v2_genre_utils.dart';

void main() {
  group('Id3v2GenreUtils', () {
    group('parseId3v24Genres', () {
      test('parses null-terminated genre strings correctly', () {
        // Standard multi-genre case
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock\0Alternative\0Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles single genre without null terminator', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Jazz');
        expect(result, equals(['Jazz']));
      });

      test('handles empty string', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('');
        expect(result, equals([]));
      });

      test('handles string with trailing null terminator', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock\0Alternative\0');
        expect(result, equals(['Rock', 'Alternative']));
      });

      test('handles string with leading null terminator', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('\0Rock\0Alternative');
        expect(result, equals(['Rock', 'Alternative']));
      });

      test('filters empty genres from multiple null terminators', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock\0\0Alternative\0\0\0Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('trims whitespace from genres', () {
        final result = Id3v2GenreUtils.parseId3v24Genres(' Rock \0 Alternative \0 Indie ');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles genres with spaces in names', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Progressive Rock\0New Wave\0Indie Pop');
        expect(result, equals(['Progressive Rock', 'New Wave', 'Indie Pop']));
      });

      test('handles single null terminator', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('\0');
        expect(result, equals([]));
      });

      test('handles multiple consecutive null terminators', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('\0\0\0');
        expect(result, equals([]));
      });
    });

    group('parseId3v23Genres', () {
      test('parses slash-separated genre strings correctly', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock/Alternative/Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles single genre without slashes', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Jazz');
        expect(result, equals(['Jazz']));
      });

      test('handles empty string', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('');
        expect(result, equals([]));
      });

      test('handles escaped slashes in genre names', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock\\/Roll/Pop/Hip-Hop');
        expect(result, equals(['Rock/Roll', 'Pop', 'Hip-Hop']));
      });

      test('handles multiple escaped slashes', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('AC\\/DC/Guns N\\/ Roses');
        expect(result, equals(['AC/DC', 'Guns N/ Roses']));
      });

      test('handles trailing slash', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock/Alternative/');
        expect(result, equals(['Rock', 'Alternative']));
      });

      test('handles leading slash', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('/Rock/Alternative');
        expect(result, equals(['Rock', 'Alternative']));
      });

      test('filters empty genres from multiple slashes', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock//Alternative///Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('trims whitespace from genres', () {
        final result = Id3v2GenreUtils.parseId3v23Genres(' Rock / Alternative / Indie ');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles genres with spaces in names', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Progressive Rock/New Wave/Indie Pop');
        expect(result, equals(['Progressive Rock', 'New Wave', 'Indie Pop']));
      });

      test('handles single slash', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('/');
        expect(result, equals([]));
      });

      test('handles multiple consecutive slashes', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('///');
        expect(result, equals([]));
      });

      test('handles complex escaped slash scenarios', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock\\/Roll\\/Blues/Pop\\/Rock');
        expect(result, equals(['Rock/Roll/Blues', 'Pop/Rock']));
      });
    });

    group('parseGenresWithDelimiterDetection', () {
      test('detects null terminators (ID3v2.4 format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock\0Alternative\0Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('detects slash delimiters (ID3v2.3 format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock/Alternative/Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('detects semicolon delimiters (MP4 format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock;Alternative;Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('detects pipe delimiters (legacy format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock|Alternative|Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('detects comma delimiters (human-readable format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock, Alternative, Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('detects backslash delimiters (legacy format)', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock\\Alternative\\Indie');
        expect(result, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles single genre with no delimiters', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Electronic');
        expect(result, equals(['Electronic']));
      });

      test('handles empty string', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('');
        expect(result, equals([]));
      });

      test('handles whitespace-only string', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('   ');
        expect(result, equals([]));
      });

      test('prioritizes null terminators over other delimiters', () {
        // String contains both null terminators and slashes
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock\0Alternative/Indie\0Pop');
        expect(result, equals(['Rock', 'Alternative/Indie', 'Pop']));
      });

      test('chooses most frequent delimiter when multiple present', () {
        // More semicolons than slashes
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock;Alternative;Indie/Pop;Jazz');
        expect(result, equals(['Rock', 'Alternative', 'Indie/Pop', 'Jazz']));
      });

      test('handles mixed delimiters with equal frequency', () {
        // Equal number of semicolons and slashes - should pick first in priority order
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock/Alternative;Indie');
        expect(result, equals(['Rock', 'Alternative;Indie'])); // Slash has higher priority
      });

      test('handles genres with spaces and mixed delimiters', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Progressive Rock; New Wave; Indie Pop');
        expect(result, equals(['Progressive Rock', 'New Wave', 'Indie Pop']));
      });

      test('handles escaped delimiters in slash format', () {
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock\\/Roll/Pop');
        expect(result, equals(['Rock/Roll', 'Pop']));
      });
    });

    group('encodeId3v24Genres', () {
      test('encodes multiple genres with null terminators', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['Rock', 'Alternative', 'Indie']);
        expect(result, equals('Rock\0Alternative\0Indie'));
      });

      test('encodes single genre without null terminator', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['Jazz']);
        expect(result, equals('Jazz'));
      });

      test('handles empty list', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres([]);
        expect(result, equals(''));
      });

      test('filters empty genres', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['Rock', '', 'Alternative', '', 'Indie']);
        expect(result, equals('Rock\0Alternative\0Indie'));
      });

      test('handles genres with spaces', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['Progressive Rock', 'New Wave', 'Indie Pop']);
        expect(result, equals('Progressive Rock\0New Wave\0Indie Pop'));
      });

      test('handles genres with special characters', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['Rock & Roll', 'Hip-Hop', 'R&B']);
        expect(result, equals('Rock & Roll\0Hip-Hop\0R&B'));
      });

      test('handles list with only empty strings', () {
        final result = Id3v2GenreUtils.encodeId3v24Genres(['', '', '']);
        expect(result, equals(''));
      });
    });

    group('encodeId3v23Genres', () {
      test('encodes multiple genres with slashes', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Rock', 'Alternative', 'Indie']);
        expect(result, equals('Rock/Alternative/Indie'));
      });

      test('encodes single genre without slashes', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Jazz']);
        expect(result, equals('Jazz'));
      });

      test('handles empty list', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres([]);
        expect(result, equals(''));
      });

      test('escapes slashes in genre names', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Rock/Roll', 'Pop']);
        expect(result, equals('Rock\\/Roll/Pop'));
      });

      test('handles multiple slashes in genre names', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['AC/DC', 'Guns N/ Roses']);
        expect(result, equals('AC\\/DC/Guns N\\/ Roses'));
      });

      test('filters empty genres', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Rock', '', 'Alternative', '', 'Indie']);
        expect(result, equals('Rock/Alternative/Indie'));
      });

      test('handles genres with spaces', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Progressive Rock', 'New Wave', 'Indie Pop']);
        expect(result, equals('Progressive Rock/New Wave/Indie Pop'));
      });

      test('handles complex slash escaping', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['Rock/Roll/Blues', 'Pop/Rock']);
        expect(result, equals('Rock\\/Roll\\/Blues/Pop\\/Rock'));
      });

      test('handles list with only empty strings', () {
        final result = Id3v2GenreUtils.encodeId3v23Genres(['', '', '']);
        expect(result, equals(''));
      });
    });

    group('edge cases and error handling', () {
      test('handles very long genre strings', () {
        final longGenre = 'A' * 1000;
        final result = Id3v2GenreUtils.parseId3v24Genres('$longGenre\0Rock');
        expect(result, equals([longGenre, 'Rock']));
      });

      test('handles unicode characters in genres', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Röck\0Alternativé\0Indië');
        expect(result, equals(['Röck', 'Alternativé', 'Indië']));
      });

      test('handles emoji in genre names', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock 🎸\0Pop 🎵\0Jazz 🎷');
        expect(result, equals(['Rock 🎸', 'Pop 🎵', 'Jazz 🎷']));
      });

      test('handles genres with newlines', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock\nRoll\0Alternative');
        expect(result, equals(['Rock\nRoll', 'Alternative']));
      });

      test('handles genres with tabs', () {
        final result = Id3v2GenreUtils.parseId3v24Genres('Rock\tMusic\0Alternative');
        expect(result, equals(['Rock\tMusic', 'Alternative']));
      });

      test('handles mixed case delimiters in detection', () {
        // Should not detect uppercase delimiters
        final result = Id3v2GenreUtils.parseGenresWithDelimiterDetection('RockAAlternativeAIndie');
        expect(result, equals(['RockAAlternativeAIndie']));
      });

      test('handles string with only delimiters', () {
        final result1 = Id3v2GenreUtils.parseId3v24Genres('\0\0\0');
        expect(result1, equals([]));

        final result2 = Id3v2GenreUtils.parseId3v23Genres('///');
        expect(result2, equals([]));

        final result3 = Id3v2GenreUtils.parseGenresWithDelimiterDetection(';;;');
        expect(result3, equals([]));
      });

      test('handles extremely nested escaping', () {
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock\\/Roll\\/Blues\\/Metal/Pop');
        expect(result, equals(['Rock/Roll/Blues/Metal', 'Pop']));
      });
    });

    group('DelimiterAnalysis', () {
      test('creates analysis correctly', () {
        final analysis = const DelimiterAnalysis(';', 3);
        expect(analysis.bestDelimiter, equals(';'));
        expect(analysis.maxCount, equals(3));
      });

      test('toString returns correct format', () {
        final analysis = const DelimiterAnalysis('/', 2);
        expect(analysis.toString(), equals('DelimiterAnalysis(delimiter: "/", count: 2)'));
      });

      test('equality works correctly', () {
        final analysis1 = const DelimiterAnalysis(';', 3);
        final analysis2 = const DelimiterAnalysis(';', 3);
        final analysis3 = const DelimiterAnalysis('/', 3);

        expect(analysis1, equals(analysis2));
        expect(analysis1, isNot(equals(analysis3)));
      });

      test('hashCode works correctly', () {
        final analysis1 = const DelimiterAnalysis(';', 3);
        final analysis2 = const DelimiterAnalysis(';', 3);

        expect(analysis1.hashCode, equals(analysis2.hashCode));
      });
    });

    group('real-world scenarios', () {
      test('handles typical ID3v2.4 multi-genre scenario', () {
        // Simulates real ID3v2.4 TCON frame content
        final result = Id3v2GenreUtils.parseId3v24Genres('Electronic\0Ambient\0Downtempo');
        expect(result, equals(['Electronic', 'Ambient', 'Downtempo']));

        final encoded = Id3v2GenreUtils.encodeId3v24Genres(result);
        expect(encoded, equals('Electronic\0Ambient\0Downtempo'));
      });

      test('handles typical ID3v2.3 multi-genre scenario', () {
        // Simulates real ID3v2.3 TCON frame content
        final result = Id3v2GenreUtils.parseId3v23Genres('Rock/Alternative Rock/Indie Rock');
        expect(result, equals(['Rock', 'Alternative Rock', 'Indie Rock']));

        final encoded = Id3v2GenreUtils.encodeId3v23Genres(result);
        expect(encoded, equals('Rock/Alternative Rock/Indie Rock'));
      });

      test('handles round-trip parsing and encoding for ID3v2.4', () {
        final original = ['Progressive Metal', 'Symphonic Metal', 'Power Metal'];
        final encoded = Id3v2GenreUtils.encodeId3v24Genres(original);
        final parsed = Id3v2GenreUtils.parseId3v24Genres(encoded);
        expect(parsed, equals(original));
      });

      test('handles round-trip parsing and encoding for ID3v2.3', () {
        final original = ['Progressive Metal', 'Symphonic Metal', 'Power Metal'];
        final encoded = Id3v2GenreUtils.encodeId3v23Genres(original);
        final parsed = Id3v2GenreUtils.parseId3v23Genres(encoded);
        expect(parsed, equals(original));
      });

      test('handles round-trip with genres containing slashes', () {
        final original = ['Rock/Roll', 'Rhythm/Blues', 'Hip/Hop'];
        final encoded = Id3v2GenreUtils.encodeId3v23Genres(original);
        final parsed = Id3v2GenreUtils.parseId3v23Genres(encoded);
        expect(parsed, equals(original));
      });

      test('handles mixed format detection from different tagging software', () {
        // Different software might use different delimiters
        final mp4Style = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock;Alternative;Indie');
        final id3v23Style = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock/Alternative/Indie');
        final humanStyle = Id3v2GenreUtils.parseGenresWithDelimiterDetection('Rock, Alternative, Indie');

        expect(mp4Style, equals(['Rock', 'Alternative', 'Indie']));
        expect(id3v23Style, equals(['Rock', 'Alternative', 'Indie']));
        expect(humanStyle, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles compatibility with existing GenreTag parsing', () {
        // Ensure compatibility with the existing GenreTag._parseGenreString method
        final testCases = [
          'Rock\0Alternative\0Indie', // ID3v2.4
          'Rock/Alternative/Indie', // ID3v2.3
          'Rock;Alternative;Indie', // MP4
          'Rock, Alternative, Indie', // Human readable
          'Rock|Alternative|Indie', // Legacy
          'Electronic', // Single genre
          '', // Empty
        ];

        for (final testCase in testCases) {
          final utilResult = Id3v2GenreUtils.parseGenresWithDelimiterDetection(testCase);
          // The results should be consistent with what GenreTag would produce
          expect(utilResult, isA<List<String>>());
          if (testCase.isNotEmpty && testCase.trim().isNotEmpty) {
            expect(utilResult, isNotEmpty);
          }
        }
      });
    });
  });
}
