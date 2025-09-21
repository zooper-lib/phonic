import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/performance/memory/memory_efficient_tag_storage.dart';
import 'package:phonic/src/performance/memory/string_interning.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryEfficientTagStorage', () {
    late MemoryEfficientTagStorage storage;

    setUp(() {
      storage = MemoryEfficientTagStorage(useInterning: true);
    });

    tearDown(() {
      storage.clear();
    });

    group('Basic Operations', () {
      test('should store and retrieve single tag', () {
        final tag = const TitleTag('Test Title');
        storage.storeTags([tag]);

        final retrieved = storage.getTag(TagKey.title);
        expect(retrieved, isNotNull);
        expect(retrieved!.value, equals('Test Title'));
        expect(retrieved.key, equals(TagKey.title));
      });

      test('should store and retrieve multiple tags', () {
        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock', 'Alternative']),
        ];
        storage.storeTags(tags);

        expect(storage.getTag(TagKey.title)?.value, equals('Test Title'));
        expect(storage.getTag(TagKey.artist)?.value, equals('Test Artist'));
        expect(storage.getTag(TagKey.genre)?.value, equals(['Rock', 'Alternative']));
      });

      test('should handle empty tag list', () {
        storage.storeTags([]);
        expect(storage.isEmpty, isTrue);
        expect(storage.tagCount, equals(0));
        expect(storage.keyCount, equals(0));
      });

      test('should replace existing tags when storing new ones', () {
        storage.storeTags([const TitleTag('Original Title')]);
        expect(storage.getTag(TagKey.title)?.value, equals('Original Title'));

        storage.storeTags([const TitleTag('New Title')]);
        expect(storage.getTag(TagKey.title)?.value, equals('New Title'));
        expect(storage.tagCount, equals(1));
      });
    });

    group('Multi-valued Tags', () {
      test('should handle multiple tags with same key', () {
        final tags = [
          GenreTag(const ['Rock']),
          GenreTag(const ['Alternative']),
        ];

        // Add tags individually to test multi-value behavior
        storage.addTag(tags[0]);
        storage.addTag(tags[1]);

        final allGenres = storage.getTags(TagKey.genre);
        expect(allGenres.length, equals(2));
        expect(allGenres[0].value, equals(['Rock']));
        expect(allGenres[1].value, equals(['Alternative']));
      });

      test('should return empty list for non-existent key', () {
        final tags = storage.getTags(TagKey.title);
        expect(tags, isEmpty);
      });

      test('should return all tags across all keys', () {
        final tags = <MetadataTag>[
          const TitleTag('Title'),
          const ArtistTag('Artist'),
          GenreTag(const ['Rock']),
          GenreTag(const ['Alternative']),
        ];

        storage.storeTags([tags[0], tags[1]]);
        storage.addTag(tags[2]);
        storage.addTag(tags[3]);

        final allTags = storage.getAllTags();
        expect(allTags.length, equals(4)); // 2 from storeTags + 2 from addTag
      });
    });

    group('Tag Removal', () {
      test('should remove tag by key', () {
        storage.storeTags([const TitleTag('Test Title'), const ArtistTag('Test Artist')]);
        expect(storage.keyCount, equals(2));

        final removed = storage.removeTag(TagKey.title);
        expect(removed, isTrue);
        expect(storage.getTag(TagKey.title), isNull);
        expect(storage.getTag(TagKey.artist), isNotNull);
        expect(storage.keyCount, equals(1));
      });

      test('should return false when removing non-existent key', () {
        final removed = storage.removeTag(TagKey.title);
        expect(removed, isFalse);
      });
    });

    group('Memory Statistics', () {
      test('should track basic statistics', () {
        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock', 'Alternative']),
        ];
        storage.storeTags(tags);

        final stats = storage.memoryStatistics;
        expect(stats['keyCount'], equals(3));
        expect(stats['tagCount'], equals(3));
        expect(stats['estimatedMemoryUsage'], greaterThan(0));
        expect(stats['stringInterningEnabled'], isTrue);
      });

      test('should estimate memory usage', () {
        storage.storeTags([const TitleTag('Test Title')]);
        final usage1 = storage.estimatedMemoryUsage;

        storage.addTag(const ArtistTag('Test Artist'));
        final usage2 = storage.estimatedMemoryUsage;

        expect(usage2, greaterThan(usage1));
      });

      test('should track string interning effectiveness', () {
        // Create multiple tags with same string values to test interning
        final tags = [
          const TitleTag('Common Title'),
          const ArtistTag('Common Title'), // Same string as title
          const AlbumTag('Different Album'),
        ];
        storage.storeTags(tags);

        final stats = storage.memoryStatistics;
        expect(stats['totalStringValues'], greaterThan(0));
        // Note: Actual interning effectiveness depends on the interning heuristics
      });
    });

    group('String Interning Integration', () {
      test('should use custom string interning instance', () {
        final customInterning = StringInterning();
        final storageWithCustomInterning = MemoryEfficientTagStorage(
          useInterning: true,
          stringInterning: customInterning,
        );

        storageWithCustomInterning.storeTags([const TitleTag('Test Title')]);

        // The string should be interned in our custom instance
        expect(customInterning.isInterned('Test Title'), isTrue);

        storageWithCustomInterning.clear();
      });

      test('should work without string interning', () {
        final storageNoInterning = MemoryEfficientTagStorage(useInterning: false);

        storageNoInterning.storeTags([const TitleTag('Test Title')]);
        expect(storageNoInterning.getTag(TagKey.title)?.value, equals('Test Title'));

        final stats = storageNoInterning.memoryStatistics;
        expect(stats['stringInterningEnabled'], isFalse);

        storageNoInterning.clear();
      });
    });

    group('Performance Tests', () {
      test('should handle large number of tags efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Create a large number of tags
        final tags = <MetadataTag>[];
        for (int i = 0; i < 1000; i++) {
          tags.add(TitleTag('Title $i'));
          tags.add(ArtistTag('Artist $i'));
          tags.add(GenreTag(['Genre$i', 'SubGenre$i']));
        }

        storage.storeTags(tags);
        stopwatch.stop();

        expect(storage.tagCount, equals(3000));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast

        // Test retrieval performance
        stopwatch.reset();
        stopwatch.start();

        for (int i = 0; i < 100; i++) {
          storage.getTag(TagKey.title);
          storage.getTags(TagKey.genre);
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Retrieval should be very fast
      });

      test('should demonstrate memory efficiency with duplicate strings', () {
        // Create many tags with duplicate string values
        final tags = <MetadataTag>[];
        const commonGenres = ['Rock', 'Pop', 'Jazz', 'Classical'];

        for (int i = 0; i < 100; i++) {
          tags.add(GenreTag([commonGenres[i % commonGenres.length]]));
        }

        storage.storeTags(tags);

        final stats = storage.memoryStatistics;
        expect(stats['tagCount'], equals(100));

        // With interning, memory usage should be much less than without
        final estimatedUsage = stats['estimatedMemoryUsage'] as int;
        expect(estimatedUsage, lessThan(100 * 200)); // Much less than naive storage
      });
    });
  });

  group('TagStoragePool', () {
    late TagStoragePool pool;

    setUp(() {
      pool = TagStoragePool(useInterning: true);
    });

    tearDown(() {
      pool.clear();
    });

    test('should create new storage when pool is empty', () {
      final storage = pool.acquire();
      expect(storage, isNotNull);
      expect(storage.isEmpty, isTrue);

      final stats = pool.statistics;
      expect(stats['totalCreated'], equals(1));
      expect(stats['totalReused'], equals(0));
    });

    test('should reuse storage instances', () {
      final storage1 = pool.acquire();
      storage1.storeTags([const TitleTag('Test')]);

      pool.release(storage1);

      final storage2 = pool.acquire();
      expect(storage2.isEmpty, isTrue); // Should be cleared

      final stats = pool.statistics;
      expect(stats['totalCreated'], equals(1));
      expect(stats['totalReused'], equals(1));
    });

    test('should limit pool size to prevent unbounded growth', () {
      // Create and release many storage instances
      for (int i = 0; i < 150; i++) {
        final storage = pool.acquire();
        pool.release(storage);
      }

      final stats = pool.statistics;
      expect(stats['currentPoolSize'], lessThanOrEqualTo(100));
    });

    test('should calculate reuse ratio correctly', () {
      // Acquire and release multiple times
      for (int i = 0; i < 5; i++) {
        final storage = pool.acquire();
        pool.release(storage);
      }

      final stats = pool.statistics;
      final reuseRatio = stats['reuseRatio'] as double;
      expect(reuseRatio, greaterThan(0.0));
      expect(reuseRatio, lessThanOrEqualTo(1.0));
    });
  });

  group('Integration Tests', () {
    test('should work with real-world tag scenarios', () {
      final storage = MemoryEfficientTagStorage(useInterning: true);

      // Simulate processing multiple audio files with common metadata
      final commonArtists = ['The Beatles', 'Pink Floyd', 'Led Zeppelin'];
      final commonGenres = ['Rock', 'Progressive Rock', 'Classic Rock'];

      for (int fileIndex = 0; fileIndex < 50; fileIndex++) {
        final tags = <MetadataTag>[
          TitleTag('Song $fileIndex'),
          ArtistTag(commonArtists[fileIndex % commonArtists.length]),
          AlbumTag('Album ${fileIndex ~/ 10}'),
          GenreTag([commonGenres[fileIndex % commonGenres.length]]),
          TrackNumberTag(fileIndex % 12 + 1),
          YearTag(2000 + fileIndex % 24),
        ];

        // Simulate processing one file at a time
        storage.clear();
        storage.storeTags(tags);

        // Verify data integrity
        expect(storage.getTag(TagKey.title)?.value, equals('Song $fileIndex'));
        expect(storage.getTag(TagKey.artist)?.value, equals(commonArtists[fileIndex % commonArtists.length]));
        expect(storage.tagCount, equals(6));
      }

      storage.clear();
    });

    test('should maintain provenance information through optimization', () {
      final testStorage = MemoryEfficientTagStorage(useInterning: true);
      final provenance = const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain);

      final tag = TitleTag('Test Title', provenance: provenance);
      testStorage.storeTags([tag]);

      final retrieved = testStorage.getTag(TagKey.title);
      expect(retrieved?.provenance.containerKind, equals(ContainerKind.id3v2));
      expect(retrieved?.provenance.containerVersion, equals('2.4'));
      expect(retrieved?.provenance.confidence, equals(TagConfidence.certain));
    });
  });
}
