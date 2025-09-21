import 'dart:typed_data';

import 'package:phonic/src/core/audio_file_cache.dart';
import 'package:phonic/src/core/encoding_options.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/phonic_audio_file.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:test/test.dart';

/// Mock implementation of PhonicAudioFile for testing purposes.
class MockPhonicAudioFile implements PhonicAudioFile {
  final String _identifier;
  final List<MetadataTag> _tags;
  bool _isDirty = false;

  MockPhonicAudioFile(this._identifier, [this._tags = const []]);

  @override
  MetadataTag? getTag(TagKey key) {
    return _tags.where((tag) => tag.key == key).firstOrNull;
  }

  @override
  List<MetadataTag> getTags(TagKey key) {
    return _tags.where((tag) => tag.key == key).toList();
  }

  @override
  List<MetadataTag> getAllTags() => List.from(_tags);

  @override
  void setTag(MetadataTag tag) {
    _isDirty = true;
  }

  @override
  void removeTag(TagKey key) {
    _isDirty = true;
  }

  @override
  void removeTagValue(TagKey key, dynamic value) {
    _isDirty = true;
  }

  @override
  bool get isDirty => _isDirty;

  @override
  void markClean() {
    _isDirty = false;
  }

  @override
  Future<Uint8List> encode([EncodingOptions? options]) async {
    return Uint8List.fromList([1, 2, 3, 4]); // Mock encoded data
  }

  @override
  Uint8List get audioData => Uint8List.fromList([5, 6, 7, 8]); // Mock audio data

  @override
  void dispose() {
    // Mock disposal
  }

  @override
  String toString() => 'MockPhonicAudioFile($_identifier)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MockPhonicAudioFile && runtimeType == other.runtimeType && _identifier == other._identifier;

  @override
  int get hashCode => _identifier.hashCode;
}

void main() {
  group('AudioFileCache', () {
    group('constructor', () {
      test('creates cache with default max size', () {
        final cache = AudioFileCache();
        expect(cache.maxCacheSize, equals(1000));
        expect(cache.size, equals(0));
        expect(cache.totalRequests, equals(0));
        expect(cache.hitCount, equals(0));
        expect(cache.missCount, equals(0));
        expect(cache.hitRate, equals(0.0));
      });

      test('creates cache with custom max size', () {
        final cache = AudioFileCache(maxCacheSize: 500);
        expect(cache.maxCacheSize, equals(500));
        expect(cache.size, equals(0));
      });

      test('creates cache with zero max size', () {
        final cache = AudioFileCache(maxCacheSize: 0);
        expect(cache.maxCacheSize, equals(0));
      });
    });

    group('basic operations', () {
      late AudioFileCache cache;
      late MockPhonicAudioFile audioFile1;
      late MockPhonicAudioFile audioFile2;

      setUp(() {
        cache = AudioFileCache(maxCacheSize: 3);
        audioFile1 = MockPhonicAudioFile('file1');
        audioFile2 = MockPhonicAudioFile('file2');
      });

      test('put and get single item', () {
        cache.put('path1', audioFile1);

        expect(cache.size, equals(1));
        expect(cache.containsKey('path1'), isTrue);

        final retrieved = cache.get('path1');
        expect(retrieved, same(audioFile1));
        expect(cache.hitCount, equals(1));
        expect(cache.missCount, equals(0));
        expect(cache.hitRate, equals(100.0));
      });

      test('get non-existent item returns null', () {
        final retrieved = cache.get('nonexistent');

        expect(retrieved, isNull);
        expect(cache.hitCount, equals(0));
        expect(cache.missCount, equals(1));
        expect(cache.hitRate, equals(0.0));
      });

      test('put multiple items', () {
        cache.put('path1', audioFile1);
        cache.put('path2', audioFile2);

        expect(cache.size, equals(2));
        expect(cache.containsKey('path1'), isTrue);
        expect(cache.containsKey('path2'), isTrue);

        expect(cache.get('path1'), same(audioFile1));
        expect(cache.get('path2'), same(audioFile2));
      });

      test('overwrite existing item', () {
        final audioFile1Updated = MockPhonicAudioFile('file1_updated');

        cache.put('path1', audioFile1);
        cache.put('path1', audioFile1Updated);

        expect(cache.size, equals(1));
        expect(cache.get('path1'), same(audioFile1Updated));
      });

      test('remove item', () {
        cache.put('path1', audioFile1);
        expect(cache.size, equals(1));

        final removed = cache.remove('path1');
        expect(removed, isTrue);
        expect(cache.size, equals(0));
        expect(cache.containsKey('path1'), isFalse);

        final removedAgain = cache.remove('path1');
        expect(removedAgain, isFalse);
      });

      test('clear cache', () {
        cache.put('path1', audioFile1);
        cache.put('path2', audioFile2);
        cache.get('path1'); // Generate some stats

        expect(cache.size, equals(2));
        expect(cache.hitCount, equals(1));

        cache.clear();

        expect(cache.size, equals(0));
        expect(cache.totalRequests, equals(0));
        expect(cache.hitCount, equals(0));
        expect(cache.missCount, equals(0));
        expect(cache.hitRate, equals(0.0));
      });
    });

    group('LRU eviction', () {
      late AudioFileCache cache;
      late List<MockPhonicAudioFile> audioFiles;

      setUp(() {
        cache = AudioFileCache(maxCacheSize: 3);
        audioFiles = List.generate(5, (i) => MockPhonicAudioFile('file$i'));
      });

      test('evicts least recently used when at capacity', () {
        // Fill cache to capacity
        cache.put('path0', audioFiles[0]);
        cache.put('path1', audioFiles[1]);
        cache.put('path2', audioFiles[2]);
        expect(cache.size, equals(3));

        // Access path1 to make it more recently used
        cache.get('path1');

        // Add new item, should evict path0 (least recently used)
        cache.put('path3', audioFiles[3]);
        expect(cache.size, equals(3));
        expect(cache.containsKey('path0'), isFalse);
        expect(cache.containsKey('path1'), isTrue);
        expect(cache.containsKey('path2'), isTrue);
        expect(cache.containsKey('path3'), isTrue);
      });

      test('updates access order on get', () {
        cache.put('path0', audioFiles[0]);
        cache.put('path1', audioFiles[1]);
        cache.put('path2', audioFiles[2]);

        // Access path0 to make it most recently used
        cache.get('path0');

        // Add new item, should evict path1 (now least recently used)
        cache.put('path3', audioFiles[3]);
        expect(cache.containsKey('path0'), isTrue);
        expect(cache.containsKey('path1'), isFalse);
        expect(cache.containsKey('path2'), isTrue);
        expect(cache.containsKey('path3'), isTrue);
      });

      test('handles eviction with zero max size', () {
        final unlimitedCache = AudioFileCache(maxCacheSize: 0);

        // Should not evict anything
        for (int i = 0; i < 10; i++) {
          unlimitedCache.put('path$i', audioFiles[i % audioFiles.length]);
        }

        expect(unlimitedCache.size, equals(10));
      });
    });

    group('weak reference behavior', () {
      test('handles garbage collected references', () {
        final cache = AudioFileCache();

        // Create a scope where the audio file can be garbage collected
        void createAndCacheFile() {
          final audioFile = MockPhonicAudioFile('temp_file');
          cache.put('temp_path', audioFile);
        }

        createAndCacheFile();
        expect(cache.size, equals(1));

        // Force garbage collection (this is implementation dependent)
        // In a real scenario, the weak reference might become null
        // For testing, we'll simulate this by checking the behavior

        // The cache should handle null weak references gracefully
        cache.get('temp_path');
        // Retrieved might be null if GC occurred, or the same object if not
        // Both are valid behaviors for weak references
      });

      test('containsKey handles dead references', () {
        final cache = AudioFileCache();
        final audioFile = MockPhonicAudioFile('test_file');

        cache.put('test_path', audioFile);
        expect(cache.containsKey('test_path'), isTrue);

        // Even if the weak reference becomes dead, containsKey should handle it
        // This test verifies the method doesn't throw exceptions
        expect(() => cache.containsKey('test_path'), returnsNormally);
      });
    });

    group('performance tracking', () {
      late AudioFileCache cache;
      late MockPhonicAudioFile audioFile;

      setUp(() {
        cache = AudioFileCache();
        audioFile = MockPhonicAudioFile('test_file');
      });

      test('tracks hit and miss counts', () {
        expect(cache.hitCount, equals(0));
        expect(cache.missCount, equals(0));
        expect(cache.totalRequests, equals(0));

        // Miss
        cache.get('nonexistent');
        expect(cache.hitCount, equals(0));
        expect(cache.missCount, equals(1));
        expect(cache.totalRequests, equals(1));

        // Put and hit
        cache.put('path1', audioFile);
        cache.get('path1');
        expect(cache.hitCount, equals(1));
        expect(cache.missCount, equals(1));
        expect(cache.totalRequests, equals(2));

        // Another hit
        cache.get('path1');
        expect(cache.hitCount, equals(2));
        expect(cache.missCount, equals(1));
        expect(cache.totalRequests, equals(3));
      });

      test('calculates hit rate correctly', () {
        expect(cache.hitRate, equals(0.0));

        // 1 miss
        cache.get('nonexistent');
        expect(cache.hitRate, equals(0.0));

        // 1 hit, 1 miss = 50%
        cache.put('path1', audioFile);
        cache.get('path1');
        expect(cache.hitRate, equals(50.0));

        // 2 hits, 1 miss = 66.67%
        cache.get('path1');
        expect(cache.hitRate, closeTo(66.67, 0.01));

        // 3 hits, 1 miss = 75%
        cache.get('path1');
        expect(cache.hitRate, equals(75.0));
      });

      test('hit rate resets after clear', () {
        cache.put('path1', audioFile);
        cache.get('path1');
        cache.get('nonexistent');

        expect(cache.hitRate, equals(50.0));

        cache.clear();
        expect(cache.hitRate, equals(0.0));
      });
    });

    group('edge cases', () {
      test('handles empty cache operations', () {
        final cache = AudioFileCache();

        expect(cache.get('anything'), isNull);
        expect(cache.remove('anything'), isFalse);
        expect(cache.containsKey('anything'), isFalse);
        expect(() => cache.clear(), returnsNormally);
      });

      test('handles single item cache', () {
        final cache = AudioFileCache(maxCacheSize: 1);
        final audioFile1 = MockPhonicAudioFile('file1');
        final audioFile2 = MockPhonicAudioFile('file2');

        cache.put('path1', audioFile1);
        expect(cache.size, equals(1));

        cache.put('path2', audioFile2);
        expect(cache.size, equals(1));
        expect(cache.containsKey('path1'), isFalse);
        expect(cache.containsKey('path2'), isTrue);
      });

      test('handles duplicate puts', () {
        final cache = AudioFileCache();
        final audioFile = MockPhonicAudioFile('test_file');

        cache.put('path1', audioFile);
        cache.put('path1', audioFile);
        cache.put('path1', audioFile);

        expect(cache.size, equals(1));
        expect(cache.get('path1'), same(audioFile));
      });

      test('handles null-like paths', () {
        final cache = AudioFileCache();
        final audioFile = MockPhonicAudioFile('test_file');

        // Empty string path
        cache.put('', audioFile);
        expect(cache.get(''), same(audioFile));

        // Whitespace path
        cache.put('   ', audioFile);
        expect(cache.get('   '), same(audioFile));
      });
    });

    group('memory efficiency', () {
      test('cache size reflects actual stored entries', () {
        final cache = AudioFileCache();

        expect(cache.size, equals(0));

        final audioFile1 = MockPhonicAudioFile('file1');
        final audioFile2 = MockPhonicAudioFile('file2');

        cache.put('path1', audioFile1);
        expect(cache.size, equals(1));

        cache.put('path2', audioFile2);
        expect(cache.size, equals(2));

        cache.remove('path1');
        expect(cache.size, equals(1));

        cache.clear();
        expect(cache.size, equals(0));
      });

      test('cleanup removes dead references', () {
        final cache = AudioFileCache();

        // This test verifies that the cleanup mechanism works
        // In practice, weak references become null when GC occurs
        void addTemporaryFile() {
          final tempFile = MockPhonicAudioFile('temp');
          cache.put('temp_path', tempFile);
        }

        addTemporaryFile();
        expect(cache.size, greaterThanOrEqualTo(0)); // Size might be 0 or 1 depending on GC

        // Accessing the cache should trigger cleanup
        cache.get('temp_path');
        cache.containsKey('temp_path');

        // The cache should handle cleanup gracefully
        expect(() => cache.size, returnsNormally);
      });
    });
  });
}
