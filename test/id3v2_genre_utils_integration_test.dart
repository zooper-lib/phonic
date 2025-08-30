import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('Id3v2GenreUtils Integration', () {
    test('utilities are properly exported from main library', () {
      // Test that the utilities are accessible through the main library export
      expect(Id3v2GenreUtils.parseId3v24Genres, isA<Function>());
      expect(Id3v2GenreUtils.parseId3v23Genres, isA<Function>());
      expect(Id3v2GenreUtils.parseGenresWithDelimiterDetection, isA<Function>());
      expect(Id3v2GenreUtils.encodeId3v24Genres, isA<Function>());
      expect(Id3v2GenreUtils.encodeId3v23Genres, isA<Function>());
    });

    test('utilities work with GenreTag for ID3v2.4 compatibility', () {
      // Test that the utilities produce results compatible with GenreTag
      final id3v24String = 'Rock\0Alternative\0Indie';

      // Parse using utility
      final utilResult = Id3v2GenreUtils.parseId3v24Genres(id3v24String);

      // Parse using GenreTag
      final genreTag = GenreTag.fromId3v24String(id3v24String);

      // Results should be identical
      expect(utilResult, equals(genreTag.value));
    });

    test('utilities work with GenreTag for ID3v2.3 compatibility', () {
      // Test that the utilities produce results compatible with GenreTag
      final id3v23String = 'Rock/Alternative/Indie';

      // Parse using utility
      final utilResult = Id3v2GenreUtils.parseId3v23Genres(id3v23String);

      // Parse using GenreTag
      final genreTag = GenreTag.fromId3v23String(id3v23String);

      // Results should be identical
      expect(utilResult, equals(genreTag.value));
    });

    test('utilities work with GenreTag for generic parsing compatibility', () {
      // Test that the utilities produce results compatible with GenreTag
      final genericString = 'Rock;Alternative;Indie';

      // Parse using utility
      final utilResult = Id3v2GenreUtils.parseGenresWithDelimiterDetection(genericString);

      // Parse using GenreTag
      final genreTag = GenreTag.fromString(genericString);

      // Results should be identical
      expect(utilResult, equals(genreTag.value));
    });

    test('round-trip encoding and parsing maintains data integrity', () {
      final originalGenres = ['Progressive Rock', 'Symphonic Metal', 'Power Metal'];

      // Test ID3v2.4 round-trip
      final encoded24 = Id3v2GenreUtils.encodeId3v24Genres(originalGenres);
      final parsed24 = Id3v2GenreUtils.parseId3v24Genres(encoded24);
      expect(parsed24, equals(originalGenres));

      // Test ID3v2.3 round-trip
      final encoded23 = Id3v2GenreUtils.encodeId3v23Genres(originalGenres);
      final parsed23 = Id3v2GenreUtils.parseId3v23Genres(encoded23);
      expect(parsed23, equals(originalGenres));
    });

    test('utilities handle complex real-world scenarios', () {
      // Test scenarios that might occur in real ID3v2 implementations

      // ID3v2.4 with trailing null terminator (common in some implementations)
      final id3v24WithTrailing = 'Electronic\0Ambient\0Downtempo\0';
      final result24 = Id3v2GenreUtils.parseId3v24Genres(id3v24WithTrailing);
      expect(result24, equals(['Electronic', 'Ambient', 'Downtempo']));

      // ID3v2.3 with genres containing slashes (needs escaping)
      final genresWithSlashes = ['Rock/Roll', 'Hip/Hop'];
      final encoded23 = Id3v2GenreUtils.encodeId3v23Genres(genresWithSlashes);
      final parsed23 = Id3v2GenreUtils.parseId3v23Genres(encoded23);
      expect(parsed23, equals(genresWithSlashes));

      // Mixed delimiter detection prioritizing null terminators
      final mixedDelimiters = 'Rock\0Alternative/Indie\0Pop';
      final resultMixed = Id3v2GenreUtils.parseGenresWithDelimiterDetection(mixedDelimiters);
      expect(resultMixed, equals(['Rock', 'Alternative/Indie', 'Pop']));
    });
  });
}
