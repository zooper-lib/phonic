import 'package:phonic/src/formats/id3/id3v1_genre_table.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v1GenreTable', () {
    group('getGenreName', () {
      test('returns correct genre name for valid numbers', () {
        expect(Id3v1GenreTable.getGenreName(0), equals('Blues'));
        expect(Id3v1GenreTable.getGenreName(17), equals('Rock'));
        expect(Id3v1GenreTable.getGenreName(13), equals('Pop'));
        expect(Id3v1GenreTable.getGenreName(8), equals('Jazz'));
        expect(Id3v1GenreTable.getGenreName(255), equals('Unknown'));
      });

      test('returns null for invalid genre numbers', () {
        expect(Id3v1GenreTable.getGenreName(-1), isNull);
        expect(Id3v1GenreTable.getGenreName(256), isNull);
        expect(Id3v1GenreTable.getGenreName(999), isNull);
      });

      test('covers all original ID3v1 genres (0-79)', () {
        // Test a selection of original ID3v1 genres
        expect(Id3v1GenreTable.getGenreName(1), equals('Classic Rock'));
        expect(Id3v1GenreTable.getGenreName(2), equals('Country'));
        expect(Id3v1GenreTable.getGenreName(7), equals('Hip-Hop'));
        expect(Id3v1GenreTable.getGenreName(15), equals('Rap'));
        expect(Id3v1GenreTable.getGenreName(32), equals('Classical'));
        expect(Id3v1GenreTable.getGenreName(52), equals('Electronic'));
        expect(Id3v1GenreTable.getGenreName(79), equals('Hard Rock'));
      });

      test('covers Winamp extensions (80-125)', () {
        expect(Id3v1GenreTable.getGenreName(80), equals('Folk'));
        expect(Id3v1GenreTable.getGenreName(90), equals('Avantgarde'));
        expect(Id3v1GenreTable.getGenreName(100), equals('Humour'));
        expect(Id3v1GenreTable.getGenreName(125), equals('Dance Hall'));
      });

      test('covers additional extensions (126-255)', () {
        expect(Id3v1GenreTable.getGenreName(126), equals('Goa'));
        expect(Id3v1GenreTable.getGenreName(131), equals('Indie'));
        expect(Id3v1GenreTable.getGenreName(189), equals('Dubstep'));
        expect(Id3v1GenreTable.getGenreName(255), equals('Unknown'));
      });
    });

    group('getGenreNumber', () {
      test('returns correct number for valid genre names', () {
        expect(Id3v1GenreTable.getGenreNumber('Blues'), equals(0));
        expect(Id3v1GenreTable.getGenreNumber('Rock'), equals(17));
        expect(Id3v1GenreTable.getGenreNumber('Pop'), equals(13));
        expect(Id3v1GenreTable.getGenreNumber('Jazz'), equals(8));
        expect(Id3v1GenreTable.getGenreNumber('Unknown'), equals(255));
      });

      test('is case insensitive', () {
        expect(Id3v1GenreTable.getGenreNumber('rock'), equals(17));
        expect(Id3v1GenreTable.getGenreNumber('ROCK'), equals(17));
        expect(Id3v1GenreTable.getGenreNumber('RoCk'), equals(17));
        expect(Id3v1GenreTable.getGenreNumber('blues'), equals(0));
        expect(Id3v1GenreTable.getGenreNumber('BLUES'), equals(0));
      });

      test('handles genre name variations', () {
        // Test common abbreviations
        expect(Id3v1GenreTable.getGenreNumber('r&b'), equals(14));
        expect(Id3v1GenreTable.getGenreNumber('rnb'), equals(14));
        expect(Id3v1GenreTable.getGenreNumber('hiphop'), equals(7));
        expect(Id3v1GenreTable.getGenreNumber('hip hop'), equals(7));
        expect(Id3v1GenreTable.getGenreNumber('dnb'), equals(127));
        expect(Id3v1GenreTable.getGenreNumber('drum and bass'), equals(127));

        // Test alternative spellings
        expect(Id3v1GenreTable.getGenreNumber('psychedelic'), equals(67));
        expect(Id3v1GenreTable.getGenreNumber('alternative rock'), equals(20));
        expect(Id3v1GenreTable.getGenreNumber('alt rock'), equals(20));
        expect(Id3v1GenreTable.getGenreNumber('rock and roll'), equals(78));
        expect(Id3v1GenreTable.getGenreNumber('rock n roll'), equals(78));
      });

      test('returns null for non-existent genres', () {
        expect(Id3v1GenreTable.getGenreNumber('NonExistent'), isNull);
        expect(Id3v1GenreTable.getGenreNumber(''), isNull);
        expect(Id3v1GenreTable.getGenreNumber('FakeGenre'), isNull);
      });
    });

    group('isValidGenreNumber', () {
      test('returns true for valid genre numbers', () {
        expect(Id3v1GenreTable.isValidGenreNumber(0), isTrue);
        expect(Id3v1GenreTable.isValidGenreNumber(17), isTrue);
        expect(Id3v1GenreTable.isValidGenreNumber(127), isTrue);
        expect(Id3v1GenreTable.isValidGenreNumber(255), isTrue);
      });

      test('returns false for invalid genre numbers', () {
        expect(Id3v1GenreTable.isValidGenreNumber(-1), isFalse);
        expect(Id3v1GenreTable.isValidGenreNumber(256), isFalse);
        expect(Id3v1GenreTable.isValidGenreNumber(999), isFalse);
      });
    });

    group('isValidGenreName', () {
      test('returns true for valid genre names', () {
        expect(Id3v1GenreTable.isValidGenreName('Blues'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('Rock'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('Electronic'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('Unknown'), isTrue);
      });

      test('is case insensitive', () {
        expect(Id3v1GenreTable.isValidGenreName('rock'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('ROCK'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('RoCk'), isTrue);
      });

      test('handles genre name variations', () {
        expect(Id3v1GenreTable.isValidGenreName('r&b'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('hip hop'), isTrue);
        expect(Id3v1GenreTable.isValidGenreName('alternative rock'), isTrue);
      });

      test('returns false for invalid genre names', () {
        expect(Id3v1GenreTable.isValidGenreName('NonExistent'), isFalse);
        expect(Id3v1GenreTable.isValidGenreName(''), isFalse);
        expect(Id3v1GenreTable.isValidGenreName('FakeGenre'), isFalse);
      });
    });

    group('getAllGenres', () {
      test('returns complete genre table', () {
        final allGenres = Id3v1GenreTable.getAllGenres();

        expect(allGenres.length, equals(256));
        expect(allGenres[0], equals('Blues'));
        expect(allGenres[17], equals('Rock'));
        expect(allGenres[255], equals('Unknown'));
      });

      test('returns a copy of the table', () {
        final allGenres1 = Id3v1GenreTable.getAllGenres();
        final allGenres2 = Id3v1GenreTable.getAllGenres();

        // Should be equal but not identical
        expect(allGenres1, equals(allGenres2));
        expect(identical(allGenres1, allGenres2), isFalse);

        // Modifying one shouldn't affect the other
        allGenres1[999] = 'Test';
        expect(allGenres2.containsKey(999), isFalse);
      });
    });

    group('getAllGenreNames', () {
      test('returns all genre names in order', () {
        final genreNames = Id3v1GenreTable.getAllGenreNames();

        expect(genreNames.length, equals(256));
        expect(genreNames[0], equals('Blues'));
        expect(genreNames[17], equals('Rock'));
        expect(genreNames[255], equals('Unknown'));
      });
    });

    group('getAllGenreNumbers', () {
      test('returns all genre numbers sorted', () {
        final genreNumbers = Id3v1GenreTable.getAllGenreNumbers();

        expect(genreNumbers.length, equals(256));
        expect(genreNumbers.first, equals(0));
        expect(genreNumbers.last, equals(255));

        // Verify sorted order
        for (int i = 1; i < genreNumbers.length; i++) {
          expect(genreNumbers[i], greaterThan(genreNumbers[i - 1]));
        }
      });
    });

    group('findGenresContaining', () {
      test('finds genres containing substring (case insensitive)', () {
        final rockGenres = Id3v1GenreTable.findGenresContaining('rock');

        expect(rockGenres.isNotEmpty, isTrue);
        expect(rockGenres[1], equals('Classic Rock'));
        expect(rockGenres[17], equals('Rock'));
        expect(rockGenres[40], equals('AlternRock'));
        expect(rockGenres[56], equals('Southern Rock'));
        expect(rockGenres[78], equals('Rock & Roll'));
        expect(rockGenres[79], equals('Hard Rock'));
      });

      test('finds metal genres', () {
        final metalGenres = Id3v1GenreTable.findGenresContaining('metal');

        expect(metalGenres.isNotEmpty, isTrue);
        expect(metalGenres[9], equals('Metal'));
        expect(metalGenres[22], equals('Death Metal'));
        expect(metalGenres[137], equals('Heavy Metal'));
        expect(metalGenres[138], equals('Black Metal'));
        expect(metalGenres[144], equals('Thrash Metal'));
      });

      test('handles case insensitive search', () {
        final jazzUpper = Id3v1GenreTable.findGenresContaining('JAZZ');
        final jazzLower = Id3v1GenreTable.findGenresContaining('jazz');

        expect(jazzUpper, equals(jazzLower));
        expect(jazzUpper[8], equals('Jazz'));
        expect(jazzUpper[29], equals('Jazz+Funk'));
        expect(jazzUpper[74], equals('Acid Jazz'));
      });

      test('returns empty map for non-matching substring', () {
        final noMatches = Id3v1GenreTable.findGenresContaining('xyz123');
        expect(noMatches.isEmpty, isTrue);
      });

      test('handles empty search string', () {
        final allGenres = Id3v1GenreTable.findGenresContaining('');
        expect(allGenres.length, equals(256)); // All genres contain empty string
      });
    });

    group('round-trip conversion', () {
      test('genre name to number and back', () {
        final testGenres = ['Blues', 'Rock', 'Jazz', 'Electronic', 'Hip-Hop'];

        for (final genreName in testGenres) {
          final genreNumber = Id3v1GenreTable.getGenreNumber(genreName);
          expect(genreNumber, isNotNull);

          final roundTripName = Id3v1GenreTable.getGenreName(genreNumber!);
          expect(roundTripName, equals(genreName));
        }
      });

      test('genre number to name and back', () {
        final testNumbers = [0, 17, 8, 52, 7, 127, 189, 255];

        for (final genreNumber in testNumbers) {
          final genreName = Id3v1GenreTable.getGenreName(genreNumber);
          expect(genreName, isNotNull);

          final roundTripNumber = Id3v1GenreTable.getGenreNumber(genreName!);
          expect(roundTripNumber, equals(genreNumber));
        }
      });
    });

    group('edge cases', () {
      test('handles boundary values', () {
        // Test boundary values
        expect(Id3v1GenreTable.getGenreName(0), equals('Blues'));
        expect(Id3v1GenreTable.getGenreName(255), equals('Unknown'));
        expect(Id3v1GenreTable.isValidGenreNumber(0), isTrue);
        expect(Id3v1GenreTable.isValidGenreNumber(255), isTrue);
      });

      test('handles special characters in genre names', () {
        // Test genres with special characters
        expect(Id3v1GenreTable.getGenreNumber('R&B'), equals(14));
        expect(Id3v1GenreTable.getGenreNumber('Jazz+Funk'), equals(29));
        expect(Id3v1GenreTable.getGenreNumber('Pop/Funk'), equals(62));
        expect(Id3v1GenreTable.getGenreNumber('Rock & Roll'), equals(78));
      });

      test('handles hyphenated genre names', () {
        expect(Id3v1GenreTable.getGenreNumber('Hip-Hop'), equals(7));
        expect(Id3v1GenreTable.getGenreNumber('Trip-Hop'), equals(27));
        expect(Id3v1GenreTable.getGenreNumber('Euro-Techno'), equals(25));
        expect(Id3v1GenreTable.getGenreNumber('Euro-House'), equals(124));
      });

      test('handles whitespace in lookups', () {
        // The table should handle exact matches, variations are handled separately
        expect(Id3v1GenreTable.getGenreNumber('New Age'), equals(10));
        expect(Id3v1GenreTable.getGenreNumber('Death Metal'), equals(22));
        expect(Id3v1GenreTable.getGenreNumber('New Wave'), equals(66));
        expect(Id3v1GenreTable.getGenreNumber('Big Band'), equals(96));
      });
    });

    group('comprehensive coverage', () {
      test('all 256 genres are accessible', () {
        for (int i = 0; i <= 255; i++) {
          final genreName = Id3v1GenreTable.getGenreName(i);
          expect(genreName, isNotNull, reason: 'Genre $i should have a name');
          expect(genreName!.isNotEmpty, isTrue, reason: 'Genre $i name should not be empty');

          final roundTripNumber = Id3v1GenreTable.getGenreNumber(genreName);
          expect(roundTripNumber, equals(i), reason: 'Round trip failed for genre $i: $genreName');
        }
      });

      test('no duplicate genre names', () {
        final allGenres = Id3v1GenreTable.getAllGenres();
        final genreNames = allGenres.values.toList();
        final uniqueNames = genreNames.toSet();

        expect(uniqueNames.length, equals(genreNames.length), reason: 'All genre names should be unique');
      });

      test('no gaps in genre numbers', () {
        final allNumbers = Id3v1GenreTable.getAllGenreNumbers();

        expect(allNumbers.length, equals(256));
        expect(allNumbers.first, equals(0));
        expect(allNumbers.last, equals(255));

        // Check for consecutive numbers
        for (int i = 0; i <= 255; i++) {
          expect(allNumbers.contains(i), isTrue, reason: 'Genre number $i should exist');
        }
      });
    });

    group('performance', () {
      test('lookup operations are efficient', () {
        // Test that multiple lookups don't cause performance issues
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          Id3v1GenreTable.getGenreName(i % 256);
          Id3v1GenreTable.getGenreNumber('Rock');
          Id3v1GenreTable.isValidGenreNumber(i % 256);
          Id3v1GenreTable.isValidGenreName('Jazz');
        }

        stopwatch.stop();

        // Should complete quickly (less than 1 second for 4000 operations)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
