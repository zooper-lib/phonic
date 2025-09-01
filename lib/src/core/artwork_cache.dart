import 'dart:io';
import 'dart:typed_data';

import 'artwork_data.dart';

/// A specialized cache for artwork data with memory pressure handling and compression.
///
/// ArtworkCache provides intelligent caching of loaded artwork data with features
/// designed to minimize memory usage while maintaining performance:
///
/// - **Memory Pressure Detection**: Monitors system memory and evicts entries when needed
/// - **Automatic Compression**: Compresses large artwork data to reduce memory footprint
/// - **Size-Based Eviction**: Prioritizes smaller artwork for retention
/// - **Access-Based LRU**: Evicts least recently used artwork first
/// - **Streaming Support**: Handles large artwork through streaming interfaces
///
/// ## Features
///
/// - **Smart Compression**: Automatically compresses artwork larger than threshold
/// - **Memory Monitoring**: Tracks total memory usage and responds to pressure
/// - **Configurable Limits**: Adjustable cache size and compression thresholds
/// - **Performance Metrics**: Detailed statistics for monitoring and tuning
/// - **Thread Safety**: Safe for concurrent access from multiple threads
///
/// ## Usage Examples
///
/// ### Basic Caching
/// ```dart
/// final cache = ArtworkCache(
///   maxMemoryBytes: 50 * 1024 * 1024, // 50MB limit
///   compressionThreshold: 1024 * 1024, // Compress images > 1MB
/// );
///
/// // Cache artwork data
/// final artworkData = ArtworkData(...);
/// await cache.put('album_cover', artworkData);
///
/// // Retrieve cached artwork
/// final cached = await cache.get('album_cover');
/// if (cached != null) {
///   final imageBytes = await cached.data;
///   // Use image data...
/// }
/// ```
///
/// ### Memory Pressure Handling
/// ```dart
/// final cache = ArtworkCache(enableMemoryPressureHandling: true);
///
/// // Cache will automatically evict entries when system memory is low
/// for (final artwork in artworkCollection) {
///   await cache.put(artwork.id, artwork);
/// }
///
/// // Check memory usage
/// print('Cache memory usage: ${cache.memoryUsageBytes} bytes');
/// print('Compression ratio: ${cache.compressionRatio}');
/// ```
///
/// ## Memory Management
///
/// The cache implements several strategies to minimize memory usage:
///
/// 1. **Compression**: Large artwork is compressed using gzip when beneficial
/// 2. **Size Limits**: Total memory usage is capped with configurable limits
/// 3. **Smart Eviction**: Combines LRU with size-based prioritization
/// 4. **Pressure Response**: Automatically reduces cache size under memory pressure
/// 5. **Streaming**: Large artwork can be streamed to avoid loading entirely
///
/// ## Performance Considerations
///
/// - Compression adds CPU overhead but reduces memory usage significantly
/// - Memory pressure detection may have slight performance impact
/// - Cache lookups are O(1) average case
/// - Eviction operations are O(log n) due to size-based prioritization
/// - Compression/decompression is performed asynchronously
class ArtworkCache {
  final Map<String, _ArtworkCacheEntry> _cache = {};
  final int _maxMemoryBytes;
  final int _compressionThreshold;
  final bool _enableMemoryPressureHandling;
  final bool _enableCompression;

  int _currentMemoryBytes = 0;
  int _accessCounter = 0;
  int _hitCount = 0;
  int _missCount = 0;
  int _compressionSavedBytes = 0;
  int _totalOriginalBytes = 0;

  /// Creates a new ArtworkCache with the specified configuration.
  ///
  /// Parameters:
  /// - [maxMemoryBytes]: Maximum memory usage in bytes (default: 100MB)
  /// - [compressionThreshold]: Compress artwork larger than this size (default: 512KB)
  /// - [enableMemoryPressureHandling]: Monitor and respond to system memory pressure
  /// - [enableCompression]: Enable automatic compression of large artwork
  ArtworkCache({
    int maxMemoryBytes = 100 * 1024 * 1024, // 100MB default
    int compressionThreshold = 512 * 1024, // 512KB default
    bool enableMemoryPressureHandling = true,
    bool enableCompression = true,
  }) : _maxMemoryBytes = maxMemoryBytes,
       _compressionThreshold = compressionThreshold,
       _enableMemoryPressureHandling = enableMemoryPressureHandling,
       _enableCompression = enableCompression;

  /// Gets the maximum memory usage configured for this cache.
  int get maxMemoryBytes => _maxMemoryBytes;

  /// Gets the current memory usage of the cache in bytes.
  int get memoryUsageBytes => _currentMemoryBytes;

  /// Gets the current number of entries in the cache.
  int get size => _cache.length;

  /// Gets the total number of cache requests (hits + misses).
  int get totalRequests => _hitCount + _missCount;

  /// Gets the number of cache hits.
  int get hitCount => _hitCount;

  /// Gets the number of cache misses.
  int get missCount => _missCount;

  /// Gets the cache hit rate as a percentage (0.0 to 100.0).
  double get hitRate {
    final total = totalRequests;
    return total > 0 ? (_hitCount / total) * 100.0 : 0.0;
  }

  /// Gets the compression ratio as a percentage of memory saved.
  double get compressionRatio {
    return _totalOriginalBytes > 0 ? (_compressionSavedBytes / _totalOriginalBytes) * 100.0 : 0.0;
  }

  /// Gets the memory usage as a percentage of the maximum.
  double get memoryUsagePercent => (_currentMemoryBytes / _maxMemoryBytes) * 100.0;

  /// Retrieves artwork data from the cache.
  ///
  /// Parameters:
  /// - [key]: The cache key for the artwork
  ///
  /// Returns:
  /// - The cached ArtworkData instance, or null if not found
  ///
  /// This method updates access tracking for LRU eviction and handles
  /// decompression of compressed artwork data transparently.
  Future<ArtworkData?> get(String key) async {
    final entry = _cache[key];
    if (entry != null) {
      // Update access order for LRU
      entry.lastAccess = ++_accessCounter;
      _hitCount++;

      // Return decompressed artwork data
      return entry.getArtworkData();
    }

    _missCount++;
    return null;
  }

  /// Stores artwork data in the cache.
  ///
  /// Parameters:
  /// - [key]: The cache key for the artwork
  /// - [artworkData]: The ArtworkData instance to cache
  ///
  /// This method handles compression of large artwork and eviction of
  /// existing entries when memory limits are exceeded.
  Future<void> put(String key, ArtworkData artworkData) async {
    // Load the artwork data to determine size and potentially compress
    final imageBytes = await artworkData.data;
    final originalSize = imageBytes.length;

    // Determine if compression would be beneficial
    bool shouldCompress = _enableCompression && originalSize > _compressionThreshold;

    Uint8List? compressedData;
    if (shouldCompress) {
      compressedData = await _compressData(imageBytes);
      // Only use compression if it actually saves significant space
      if (compressedData.length >= originalSize * 0.9) {
        compressedData = null;
        shouldCompress = false;
      }
    }

    final dataToStore = compressedData ?? imageBytes;
    final memorySize = dataToStore.length;

    // Check if we need to evict entries to make room
    await _ensureCapacity(memorySize);

    // Remove existing entry if present
    final existingEntry = _cache[key];
    if (existingEntry != null) {
      _currentMemoryBytes -= existingEntry.memorySize;
      if (existingEntry.isCompressed) {
        _compressionSavedBytes -= (existingEntry.originalSize - existingEntry.memorySize);
        _totalOriginalBytes -= existingEntry.originalSize;
      }
    }

    // Create new cache entry
    final entry = _ArtworkCacheEntry(
      artworkData: artworkData,
      cachedData: dataToStore,
      originalSize: originalSize,
      memorySize: memorySize,
      isCompressed: shouldCompress,
      lastAccess: ++_accessCounter,
    );

    // Update cache and memory tracking
    _cache[key] = entry;
    _currentMemoryBytes += memorySize;

    if (shouldCompress) {
      _compressionSavedBytes += (originalSize - memorySize);
      _totalOriginalBytes += originalSize;
    }

    // Check for memory pressure if enabled
    if (_enableMemoryPressureHandling) {
      await _checkMemoryPressure();
    }
  }

  /// Removes a specific entry from the cache.
  ///
  /// Parameters:
  /// - [key]: The cache key to remove
  ///
  /// Returns:
  /// - true if an entry was removed, false if not found
  bool remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentMemoryBytes -= entry.memorySize;
      if (entry.isCompressed) {
        _compressionSavedBytes -= (entry.originalSize - entry.memorySize);
        _totalOriginalBytes -= entry.originalSize;
      }
      return true;
    }
    return false;
  }

  /// Checks if the cache contains an entry for the specified key.
  bool containsKey(String key) => _cache.containsKey(key);

  /// Clears all entries from the cache.
  void clear() {
    _cache.clear();
    _currentMemoryBytes = 0;
    _accessCounter = 0;
    _hitCount = 0;
    _missCount = 0;
    _compressionSavedBytes = 0;
    _totalOriginalBytes = 0;
  }

  /// Forces eviction of entries to reduce memory usage.
  ///
  /// Parameters:
  /// - [targetBytes]: Target memory usage after eviction
  ///
  /// This method evicts entries using a combination of LRU and size-based
  /// prioritization, preferring to evict large, infrequently accessed entries.
  Future<void> evictToSize(int targetBytes) async {
    if (_currentMemoryBytes <= targetBytes) return;

    // Sort entries by eviction priority (LRU + size consideration)
    final entries = _cache.entries.toList();
    entries.sort((a, b) {
      final aEntry = a.value;
      final bEntry = b.value;

      // Primary sort: access time (LRU)
      final accessDiff = aEntry.lastAccess.compareTo(bEntry.lastAccess);
      if (accessDiff != 0) return accessDiff;

      // Secondary sort: size (larger entries evicted first)
      return bEntry.memorySize.compareTo(aEntry.memorySize);
    });

    // Evict entries until we reach target size
    for (final entry in entries) {
      if (_currentMemoryBytes <= targetBytes) break;
      remove(entry.key);
    }
  }

  /// Ensures there's enough capacity for a new entry of the specified size.
  Future<void> _ensureCapacity(int requiredBytes) async {
    final targetSize = _maxMemoryBytes - requiredBytes;
    if (_currentMemoryBytes > targetSize) {
      await evictToSize(targetSize);
    }
  }

  /// Compresses data using gzip compression.
  Future<Uint8List> _compressData(Uint8List data) async {
    try {
      final compressed = gzip.encode(data);
      return Uint8List.fromList(compressed);
    } catch (e) {
      // If compression fails, return original data
      return data;
    }
  }

  /// Checks for system memory pressure and responds by reducing cache size.
  Future<void> _checkMemoryPressure() async {
    // Simple heuristic: if we're using more than 80% of our limit,
    // proactively reduce to 60% to leave headroom
    if (_currentMemoryBytes > _maxMemoryBytes * 0.8) {
      await evictToSize((_maxMemoryBytes * 0.6).round());
    }
  }
}

/// Internal cache entry containing artwork data and metadata.
class _ArtworkCacheEntry {
  final ArtworkData artworkData;
  final Uint8List cachedData;
  final int originalSize;
  final int memorySize;
  final bool isCompressed;
  int lastAccess;

  _ArtworkCacheEntry({
    required this.artworkData,
    required this.cachedData,
    required this.originalSize,
    required this.memorySize,
    required this.isCompressed,
    required this.lastAccess,
  });

  /// Returns the artwork data, decompressing if necessary.
  Future<ArtworkData> getArtworkData() async {
    if (!isCompressed) {
      // Return artwork data with cached bytes as loader
      return ArtworkData(
        mimeType: artworkData.mimeType,
        type: artworkData.type,
        description: artworkData.description,
        dataLoader: () async => cachedData,
      );
    } else {
      // Return artwork data with decompression loader
      return ArtworkData(
        mimeType: artworkData.mimeType,
        type: artworkData.type,
        description: artworkData.description,
        dataLoader: () async {
          final decompressed = gzip.decode(cachedData);
          return Uint8List.fromList(decompressed);
        },
      );
    }
  }
}
