import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/formats/id3/id3.dart';

void main() {
  group('Id3v1GenreTable Integration', () {
    test('can be imported from main library', () {
      // Test that Id3v1GenreTable is accessible through the main library export
      expect(Id3v1GenreTable.getGenreName(17), equals('Rock'));
      expect(Id3v1GenreTable.getGenreNumber('Blues'), equals(0));
      expect(Id3v1GenreTable.isValidGenreNumber(255), isTrue);
      expect(Id3v1GenreTable.getAllGenres().length, equals(256));
    });

    test('works with common genre lookups', () {
      // Test some common genre lookups that would be used in real applications
      final commonGenres = {
        'Blues': 0,
        'Rock': 17,
        'Pop': 13,
        'Jazz': 8,
        'Electronic': 52,
        'Hip-Hop': 7,
        'Classical': 32,
        'Country': 2,
        'R&B': 14,
        'Metal': 9,
      };

      for (final entry in commonGenres.entries) {
        final genreName = entry.key;
        final expectedNumber = entry.value;

        // Test name to number conversion
        final actualNumber = Id3v1GenreTable.getGenreNumber(genreName);
        expect(actualNumber, equals(expectedNumber), reason: 'Genre "$genreName" should map to $expectedNumber');

        // Test number to name conversion
        final actualName = Id3v1GenreTable.getGenreName(expectedNumber);
        expect(actualName, equals(genreName), reason: 'Genre number $expectedNumber should map to "$genreName"');
      }
    });

    test('handles case-insensitive lookups', () {
      // Test that case variations work correctly
      expect(Id3v1GenreTable.getGenreNumber('rock'), equals(17));
      expect(Id3v1GenreTable.getGenreNumber('ROCK'), equals(17));
      expect(Id3v1GenreTable.getGenreNumber('RoCk'), equals(17));

      expect(Id3v1GenreTable.isValidGenreName('blues'), isTrue);
      expect(Id3v1GenreTable.isValidGenreName('BLUES'), isTrue);
      expect(Id3v1GenreTable.isValidGenreName('BlUeS'), isTrue);
    });

    test('provides comprehensive genre search', () {
      // Test the search functionality
      final rockGenres = Id3v1GenreTable.findGenresContaining('rock');
      expect(rockGenres.isNotEmpty, isTrue);
      expect(rockGenres.containsKey(17), isTrue); // Rock
      expect(rockGenres.containsKey(1), isTrue); // Classic Rock

      final metalGenres = Id3v1GenreTable.findGenresContaining('metal');
      expect(metalGenres.isNotEmpty, isTrue);
      expect(metalGenres.containsKey(9), isTrue); // Metal
      expect(metalGenres.containsKey(22), isTrue); // Death Metal
      expect(metalGenres.containsKey(137), isTrue); // Heavy Metal
    });

    test('handles genre variations correctly', () {
      // Test common variations and abbreviations
      expect(Id3v1GenreTable.getGenreNumber('r&b'), equals(14));
      expect(Id3v1GenreTable.getGenreNumber('hip hop'), equals(7));
      expect(Id3v1GenreTable.getGenreNumber('alternative rock'), equals(20));
      expect(Id3v1GenreTable.getGenreNumber('rock and roll'), equals(78));
    });

    test('validates boundary conditions', () {
      // Test boundary values
      expect(Id3v1GenreTable.isValidGenreNumber(0), isTrue);
      expect(Id3v1GenreTable.isValidGenreNumber(255), isTrue);
      expect(Id3v1GenreTable.isValidGenreNumber(-1), isFalse);
      expect(Id3v1GenreTable.isValidGenreNumber(256), isFalse);

      expect(Id3v1GenreTable.getGenreName(0), equals('Blues'));
      expect(Id3v1GenreTable.getGenreName(255), equals('Unknown'));
      expect(Id3v1GenreTable.getGenreName(-1), isNull);
      expect(Id3v1GenreTable.getGenreName(256), isNull);
    });
  });
}
