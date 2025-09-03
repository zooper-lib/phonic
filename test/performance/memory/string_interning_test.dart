import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/performance/memory/string_interning.dart';

void main() {
  group('StringInterning', () {
    late StringInterning interning;

    setUp(() {
      interning = StringInterning();
    });

    tearDown(() {
      interning.clear();
    });

    group('Basic Interning', () {
      test('should return same instance for identical strings', () {
        final str1 = interning.intern('test');
        final str2 = interning.intern('test');

        expect(identical(str1, str2), isTrue);
        expect(str1, equals(str2));
      });

      test('should return different instances for different strings', () {
        final str1 = interning.intern('test1');
        final str2 = interning.intern('test2');

        expect(identical(str1, str2), isFalse);
        expect(str1, isNot(equals(str2)));
      });

      test('should track statistics correctly', () {
        interning.intern('test');
        interning.intern('test'); // Cache hit
        interning.intern('different');

        expect(interning.size, equals(2));
        expect(interning.hitRatio, closeTo(0.33, 0.1)); // 1 hit out of 3 total requests

        final stats = interning.statistics;
        expect(stats['totalRequests'], equals(3));
        expect(stats['cacheHits'], equals(1));
        expect(stats['uniqueStrings'], equals(2));
      });
    });

    group('Beneficial Interning Heuristics', () {
      test('should not intern very short strings', () {
        final original = 'ab';
        final result = interning.internIfBeneficial(original);

        expect(identical(original, result), isTrue);
        expect(interning.isInterned(original), isFalse);
      });

      test('should not intern very long strings', () {
        final longString = 'a' * 150;
        final result = interning.internIfBeneficial(longString);

        expect(identical(longString, result), isTrue);
        expect(interning.isInterned(longString), isFalse);
      });

      test('should intern common genre names', () {
        const commonGenres = ['Rock', 'Pop', 'Jazz', 'Classical'];

        for (final genre in commonGenres) {
          interning.internIfBeneficial(genre);
          expect(interning.isInterned(genre), isTrue);
        }
      });

      test('should intern common artist patterns', () {
        const artistPatterns = ['The Beatles', 'Pink Floyd Band', 'London Symphony Orchestra', 'Miles Davis Quartet'];

        for (final artist in artistPatterns) {
          interning.internIfBeneficial(artist);
          expect(interning.isInterned(artist), isTrue);
        }
      });

      test('should intern common encoder names', () {
        const encoders = ['LAME', 'iTunes', 'foobar2000', 'Winamp'];

        for (final encoder in encoders) {
          interning.internIfBeneficial(encoder);
          expect(interning.isInterned(encoder), isTrue);
        }
      });

      test('should intern strings with similar patterns', () {
        // First, intern a string to establish a pattern
        interning.internIfBeneficial('The Beatles');

        // Now try a string with similar prefix
        interning.internIfBeneficial('The Rolling Stones');
        expect(interning.isInterned('The Rolling Stones'), isTrue);
      });
    });

    group('Memory Estimation', () {
      test('should estimate memory savings', () {
        // Create multiple references to the same strings
        for (int i = 0; i < 10; i++) {
          interning.intern('Rock');
          interning.intern('Pop');
        }

        final savings = interning.estimatedMemorySaved;
        expect(savings, greaterThan(0));
      });

      test('should provide comprehensive statistics', () {
        interning.intern('test1');
        interning.intern('test1'); // Hit
        interning.intern('test2');
        interning.intern('test2'); // Hit

        final stats = interning.statistics;
        expect(stats['totalRequests'], equals(4));
        expect(stats['cacheHits'], equals(2));
        expect(stats['uniqueStrings'], equals(2));
        expect(stats['hitRatio'], equals(0.5));
        expect(stats['estimatedMemorySaved'], greaterThan(0));
      });
    });

    group('Performance Tests', () {
      test('should handle large number of strings efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Intern many strings with some duplicates
        for (int i = 0; i < 10000; i++) {
          interning.intern('string_${i % 100}'); // 100 unique strings, repeated
        }

        stopwatch.stop();

        expect(interning.size, equals(100));
        expect(interning.hitRatio, greaterThan(0.9)); // High hit ratio
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast
      });

      test('should demonstrate memory efficiency with real-world data', () {
        // Simulate real-world metadata with common values
        const commonValues = ['Rock', 'Pop', 'Jazz', 'Classical', 'Electronic', 'The Beatles', 'Pink Floyd', 'Led Zeppelin', 'LAME', 'iTunes', 'foobar2000'];

        final stopwatch = Stopwatch()..start();

        // Simulate processing 1000 files with common metadata
        for (int file = 0; file < 1000; file++) {
          for (final value in commonValues) {
            interning.intern(value);
          }
        }

        stopwatch.stop();

        expect(interning.size, equals(commonValues.length));
        expect(interning.hitRatio, greaterThan(0.99)); // Very high hit ratio
        expect(stopwatch.elapsedMilliseconds, lessThan(500));

        final savings = interning.estimatedMemorySaved;
        expect(savings, greaterThan(10000)); // Significant memory savings
      });

      test('should maintain performance with mixed string lengths', () {
        final strings = <String>[];

        // Create strings of various lengths
        for (int i = 1; i <= 100; i++) {
          strings.add('a' * i); // Strings from 1 to 100 characters
        }

        final stopwatch = Stopwatch()..start();

        // Intern each string multiple times
        for (int round = 0; round < 10; round++) {
          for (final str in strings) {
            interning.intern(str);
          }
        }

        stopwatch.stop();

        expect(interning.size, equals(100));
        expect(interning.hitRatio, greaterThanOrEqualTo(0.9));
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
    });

    group('Edge Cases', () {
      test('should handle empty strings', () {
        final empty1 = interning.intern('');
        final empty2 = interning.intern('');

        expect(identical(empty1, empty2), isTrue);
        expect(interning.size, equals(1));
      });

      test('should handle strings with special characters', () {
        const specialStrings = ['Café del Mar', 'Björk', 'Sigur Rós', '東京事変', '🎵 Music 🎵'];

        for (final str in specialStrings) {
          final interned1 = interning.intern(str);
          final interned2 = interning.intern(str);
          expect(identical(interned1, interned2), isTrue);
        }

        expect(interning.size, equals(specialStrings.length));
      });

      test('should handle very long strings gracefully', () {
        final longString = 'a' * 10000;

        final result1 = interning.intern(longString);
        final result2 = interning.intern(longString);

        expect(identical(result1, result2), isTrue);
        expect(interning.size, equals(1));
      });

      test('should clear statistics when cleared', () {
        interning.intern('test1');
        interning.intern('test2');
        interning.intern('test1'); // Hit

        expect(interning.size, equals(2));
        expect(interning.hitRatio, greaterThan(0));

        interning.clear();

        expect(interning.size, equals(0));
        expect(interning.hitRatio, equals(0));

        final stats = interning.statistics;
        expect(stats['totalRequests'], equals(0));
        expect(stats['cacheHits'], equals(0));
      });
    });
  });

  group('Global String Interning', () {
    test('should provide global instance', () {
      expect(globalStringInterning, isNotNull);
      expect(globalStringInterning, isA<StringInterning>());
    });

    test('should maintain state across calls', () {
      globalStringInterning.clear(); // Start clean

      final str1 = globalStringInterning.intern('global_test');
      final str2 = globalStringInterning.intern('global_test');

      expect(identical(str1, str2), isTrue);
      expect(globalStringInterning.size, equals(1));

      globalStringInterning.clear(); // Clean up
    });
  });

  group('Real-world Scenarios', () {
    test('should efficiently handle music metadata patterns', () {
      final testInterning = StringInterning();

      // Simulate processing a music collection with common patterns
      final albums = ['Abbey Road', 'The Dark Side of the Moon', 'Led Zeppelin IV', 'Thriller', 'Back in Black', 'The Wall'];

      final artists = ['The Beatles', 'Pink Floyd', 'Led Zeppelin', 'Michael Jackson', 'AC/DC'];

      final genres = ['Rock', 'Pop', 'Progressive Rock', 'Hard Rock'];

      // Process 100 songs with overlapping metadata
      for (int song = 0; song < 100; song++) {
        testInterning.intern(albums[song % albums.length]);
        testInterning.intern(artists[song % artists.length]);
        testInterning.intern(genres[song % genres.length]);
      }

      final totalUniqueValues = albums.length + artists.length + genres.length;
      expect(testInterning.size, equals(totalUniqueValues));
      expect(testInterning.hitRatio, greaterThan(0.8)); // High reuse

      final stats = testInterning.statistics;
      expect(stats['estimatedMemorySaved'], greaterThan(1000));
    });

    test('should handle batch processing efficiently', () {
      final testInterning = StringInterning();
      const batchSize = 1000;
      const uniqueValuesPerBatch = 50;

      final stopwatch = Stopwatch()..start();

      for (int batch = 0; batch < 10; batch++) {
        // Each batch has some unique values and some repeated from previous batches
        for (int item = 0; item < batchSize; item++) {
          final value = 'batch_${batch}_item_${item % uniqueValuesPerBatch}';
          testInterning.intern(value);
        }
      }

      stopwatch.stop();

      // Should have reasonable performance even with large datasets
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(testInterning.hitRatio, greaterThan(0.5));

      // Memory usage should be much less than naive storage
      final estimatedSavings = testInterning.estimatedMemorySaved;
      expect(estimatedSavings, greaterThan(50000));
    });
  });
}
