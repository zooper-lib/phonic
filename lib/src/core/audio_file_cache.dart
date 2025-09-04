import 'dart:core';

import 'phonic_audio_file.dart';

/// A cache for PhonicAudioFile instances using weak references.
///
/// AudioFileCache provides memory-efficient caching of audio file instances
/// using weak references to prevent memory leaks. The cache automatically
/// evicts entries when the garbage collector reclaims the referenced objects,
/// and provides configurable size limits with LRU eviction.
///
/// The cache tracks performance metrics including hit/miss ratios to help
/// monitor cache effectiveness in applications processing large audio
/// collections.
///
/// ## Features
///
/// - **Weak References**: Uses WeakReference to allow garbage collection
/// - **Size Limits**: Configurable maximum cache size with LRU eviction
/// - **Performance Tracking**: Hit/miss statistics for monitoring
/// - **Thread Safety**: Not thread-safe, requires external synchronization
/// - **Memory Efficient**: Minimal overhead per cached entry
///
/// ## Usage Examples
///
/// ### Basic Caching
/// ```dart
/// final cache = AudioFileCache(maxCacheSize: 1000);
///
/// // Store audio file in cache
/// final audioFile = await Phonic.fromFile('song.mp3');
/// cache.put('song.mp3', audioFile);
///
/// // Retrieve from cache
/// final cached = cache.get('song.mp3');
/// if (cached != null) {
///   print('Cache hit: ${cached.getTag(TagKey.title)?.value}');
/// } else {
///   print('Cache miss - need to load file');
/// }
/// ```
///
/// ### Performance Monitoring
/// ```dart
/// final cache = AudioFileCache();
///
/// // Process many files...
/// for (final path in filePaths) {
///   var audioFile = cache.get(path);
///   if (audioFile == null) {
///     audioFile = await Phonic.fromFile(path);
///     cache.put(path, audioFile);
///   }
///   // Process audioFile...
/// }
///
/// // Check cache performance
/// print('Cache hit rate: ${cache.hitRate.toStringAsFixed(2)}%');
/// print('Total requests: ${cache.totalRequests}');
/// ```
///
/// ### Cache Management
/// ```dart
/// final cache = AudioFileCache(maxCacheSize: 500);
///
/// // Check cache status
/// print('Cache size: ${cache.size}/${cache.maxCacheSize}');
/// print('Hit rate: ${cache.hitRate}%');
///
/// // Clear cache when needed
/// cache.clear();
/// ```
///
/// ## Memory Management
///
/// The cache uses WeakReference to store audio file instances, which means:
/// - Cached objects can be garbage collected when no other references exist
/// - The cache doesn't prevent memory cleanup of unused audio files
/// - Cache size may be smaller than maxCacheSize due to garbage collection
/// - Regular cleanup removes dead weak references
///
/// ## Performance Considerations
///
/// - Cache lookups are O(1) average case
/// - LRU eviction is O(1) when cache is full
/// - Cleanup of dead references is O(n) but infrequent
/// - Memory overhead is minimal per cached entry
class AudioFileCache {
  final Map<String, _CacheEntry> _cache = {};
  final int _maxCacheSize;
  int _accessCounter = 0;
  int _hitCount = 0;
  int _missCount = 0;

  /// Creates a new AudioFileCache with the specified maximum size.
  ///
  /// Parameters:
  /// - [maxCacheSize]: Maximum number of entries to keep in cache (default: 1000)
  ///
  /// The cache will use LRU eviction when the maximum size is reached.
  /// Setting maxCacheSize to 0 disables size limits (not recommended).
  AudioFileCache({int maxCacheSize = 1000}) : _maxCacheSize = maxCacheSize;

  /// Gets the maximum cache size configured for this instance.
  int get maxCacheSize => _maxCacheSize;

  /// Gets the current number of entries in the cache.
  ///
  /// Note: This may be less than the number of put() calls due to
  /// garbage collection of weakly referenced objects.
  int get size {
    _cleanupDeadReferences();
    return _cache.length;
  }

  /// Gets the total number of cache requests (hits + misses).
  int get totalRequests => _hitCount + _missCount;

  /// Gets the number of cache hits.
  int get hitCount => _hitCount;

  /// Gets the number of cache misses.
  int get missCount => _missCount;

  /// Gets the cache hit rate as a percentage (0.0 to 100.0).
  ///
  /// Returns 0.0 if no requests have been made yet.
  double get hitRate {
    final total = totalRequests;
    return total > 0 ? (_hitCount / total) * 100.0 : 0.0;
  }

  /// Retrieves an audio file from the cache.
  ///
  /// Parameters:
  /// - [path]: The file path used as the cache key
  ///
  /// Returns:
  /// - The cached PhonicAudioFile instance, or null if not found or garbage collected
  ///
  /// This method updates the access order for LRU tracking and increments
  /// hit/miss counters for performance monitoring.
  PhonicAudioFile? get(String path) {
    final entry = _cache[path];
    if (entry != null) {
      final audioFile = entry.weakRef.target;
      if (audioFile != null) {
        // Update access order for LRU
        entry.lastAccess = ++_accessCounter;
        _hitCount++;
        return audioFile;
      } else {
        // Dead reference, remove it
        _cache.remove(path);
      }
    }

    _missCount++;
    return null;
  }

  /// Stores an audio file in the cache.
  ///
  /// Parameters:
  /// - [path]: The file path to use as the cache key
  /// - [audioFile]: The PhonicAudioFile instance to cache
  ///
  /// If the cache is at maximum capacity, the least recently used entry
  /// will be evicted to make room for the new entry.
  void put(String path, PhonicAudioFile audioFile) {
    // Clean up dead references before checking size
    _cleanupDeadReferences();

    // Evict LRU entry if at capacity
    if (_maxCacheSize > 0 && _cache.length >= _maxCacheSize) {
      _evictLeastRecentlyUsed();
    }

    // Store new entry
    _cache[path] = _CacheEntry(
      weakRef: WeakReference(audioFile),
      lastAccess: ++_accessCounter,
    );
  }

  /// Removes a specific entry from the cache.
  ///
  /// Parameters:
  /// - [path]: The file path of the entry to remove
  ///
  /// Returns:
  /// - true if an entry was removed, false if not found
  bool remove(String path) {
    return _cache.remove(path) != null;
  }

  /// Checks if the cache contains an entry for the specified path.
  ///
  /// Parameters:
  /// - [path]: The file path to check
  ///
  /// Returns:
  /// - true if the cache contains a live reference for the path
  ///
  /// Note: This method cleans up dead references, so it may return false
  /// even if put() was previously called with the same path.
  bool containsKey(String path) {
    final entry = _cache[path];
    if (entry != null) {
      if (entry.weakRef.target != null) {
        return true;
      } else {
        // Dead reference, remove it
        _cache.remove(path);
      }
    }
    return false;
  }

  /// Clears all entries from the cache.
  ///
  /// This resets the cache to an empty state and clears all performance
  /// statistics.
  void clear() {
    _cache.clear();
    _accessCounter = 0;
    _hitCount = 0;
    _missCount = 0;
  }

  /// Removes dead weak references from the cache.
  ///
  /// This method is called automatically during normal operations but
  /// can be called manually to force cleanup of garbage collected entries.
  void _cleanupDeadReferences() {
    final deadKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.weakRef.target == null) {
        deadKeys.add(entry.key);
      }
    }

    for (final key in deadKeys) {
      _cache.remove(key);
    }
  }

  /// Evicts the least recently used entry from the cache.
  ///
  /// This method is called automatically when the cache reaches maximum
  /// capacity. It finds and removes the entry with the oldest access time.
  void _evictLeastRecentlyUsed() {
    if (_cache.isEmpty) return;

    String? lruKey;
    int oldestAccess = _accessCounter + 1;

    for (final entry in _cache.entries) {
      if (entry.value.lastAccess < oldestAccess) {
        oldestAccess = entry.value.lastAccess;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
    }
  }
}

/// Internal cache entry containing weak reference and access tracking.
class _CacheEntry {
  final WeakReference<PhonicAudioFile> weakRef;
  int lastAccess;

  _CacheEntry({
    required this.weakRef,
    required this.lastAccess,
  });
}
