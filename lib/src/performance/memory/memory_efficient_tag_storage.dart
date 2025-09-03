import 'dart:collection';

import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';

import 'string_interning.dart';

/// Memory-efficient storage system for metadata tags that minimizes overhead
/// per file while maintaining fast access patterns.
///
/// This storage system is designed to handle large collections of audio files
/// efficiently by:
/// - Using compact data structures to minimize memory overhead
/// - Interning common string values to eliminate duplicates
/// - Providing fast O(1) access to tags by key
/// - Supporting efficient iteration and bulk operations
/// - Tracking memory usage for monitoring and optimization
///
/// ## Design Principles
///
/// 1. **Minimize Per-File Overhead**: Each file's tag storage should use
///    minimal memory beyond the actual tag data
/// 2. **Share Common Data**: Identical tag values should share memory
/// 3. **Fast Access**: O(1) lookup by tag key for common operations
/// 4. **Memory Monitoring**: Provide visibility into memory usage patterns
/// 5. **Batch Efficiency**: Optimize for processing large collections
///
/// ## Usage Examples
///
/// ```dart
/// // Create storage with optional string interning
/// final storage = MemoryEfficientTagStorage(useInterning: true);
///
/// // Store tags for a file
/// final tags = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']),
/// ];
/// storage.storeTags(tags);
///
/// // Access tags efficiently
/// final title = storage.getTag(TagKey.title);
/// final genres = storage.getTags(TagKey.genre);
/// final allTags = storage.getAllTags();
///
/// // Monitor memory usage
/// print('Memory usage: ${storage.estimatedMemoryUsage} bytes');
/// print('Tag count: ${storage.tagCount}');
///
/// // Clear when done
/// storage.clear();
/// ```
///
/// ## Memory Optimization Strategies
///
/// 1. **Compact Storage**: Uses efficient data structures that minimize overhead
/// 2. **String Interning**: Eliminates duplicate string storage
/// 3. **Lazy Allocation**: Only allocates storage when tags are present
/// 4. **Efficient Collections**: Uses appropriate collection types for access patterns
/// 5. **Memory Pooling**: Reuses storage structures when possible
class MemoryEfficientTagStorage {
  /// Primary storage for tags organized by key for O(1) access.
  ///
  /// We use a compact map implementation that minimizes overhead for
  /// small collections (which is common for individual files).
  /// The map is lazily allocated to save memory for files with no tags.
  Map<TagKey, List<MetadataTag>>? _tagsByKey;

  /// String interning system for reducing duplicate string storage.
  final StringInterning? _stringInterning;

  /// Flag indicating whether string interning is enabled.
  final bool _useInterning;

  /// Statistics for memory usage monitoring.
  int _totalTagsStored = 0;
  int _totalStringValues = 0;
  int _internedStringValues = 0;

  /// Creates a new memory-efficient tag storage instance.
  ///
  /// @param useInterning Whether to enable string interning for tag values
  /// @param stringInterning Optional custom string interning instance
  MemoryEfficientTagStorage({
    bool useInterning = true,
    StringInterning? stringInterning,
  }) : _useInterning = useInterning,
       _stringInterning = useInterning ? (stringInterning ?? globalStringInterning) : null;

  /// Stores a collection of tags, replacing any existing tags.
  ///
  /// This method optimizes storage by:
  /// - Interning string values to reduce memory usage
  /// - Using compact data structures for small collections
  /// - Grouping tags by key for efficient access
  ///
  /// @param tags The tags to store
  void storeTags(List<MetadataTag> tags) {
    if (tags.isEmpty) {
      _tagsByKey?.clear();
      return;
    }

    // Lazy allocation of storage map
    _tagsByKey ??= <TagKey, List<MetadataTag>>{};
    _tagsByKey!.clear();

    // Group tags by key and apply memory optimizations
    for (final tag in tags) {
      final optimizedTag = _optimizeTag(tag);

      final tagList = _tagsByKey![tag.key] ??= <MetadataTag>[];
      tagList.add(optimizedTag);

      _totalTagsStored++;
    }

    // Compact storage for small collections
    _compactStorage();
  }

  /// Optimizes a tag for memory efficiency by interning string values.
  MetadataTag _optimizeTag(MetadataTag tag) {
    if (!_useInterning || _stringInterning == null) {
      return tag;
    }

    // Optimize string values through interning
    if (tag.value is String) {
      _totalStringValues++;
      final originalValue = tag.value as String;
      final internedValue = _stringInterning.internIfBeneficial(originalValue);

      if (identical(internedValue, originalValue)) {
        // String was not interned
        return tag;
      } else {
        // String was interned - create new tag with interned value
        _internedStringValues++;
        return _createTagWithInternedValue(tag, internedValue);
      }
    }

    // Optimize List<String> values (like genres)
    if (tag.value is List<String>) {
      _totalStringValues++;
      final originalList = tag.value as List<String>;
      final internedList = <String>[];
      bool anyInterned = false;

      for (final str in originalList) {
        final internedStr = _stringInterning.internIfBeneficial(str);
        internedList.add(internedStr);
        if (!identical(internedStr, str)) {
          anyInterned = true;
        }
      }

      if (anyInterned) {
        _internedStringValues++;
        return _createTagWithInternedValue(tag, internedList);
      }
    }

    return tag;
  }

  /// Creates a new tag instance with an interned value.
  ///
  /// This method handles the complexity of creating the correct tag type
  /// with the interned value while preserving other properties.
  MetadataTag _createTagWithInternedValue(MetadataTag originalTag, dynamic internedValue) {
    // Use the withProvenance method to create a new instance, then replace the value
    // This is a bit of a hack since we can't directly modify the value,
    // but it maintains type safety and immutability

    switch (originalTag.key) {
      case TagKey.title:
        return TitleTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.artist:
        return ArtistTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.album:
        return AlbumTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.albumArtist:
        return AlbumArtistTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.comment:
        return CommentTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.grouping:
        return GroupingTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.composer:
        return ComposerTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.encoder:
        return EncoderTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.isrc:
        return IsrcTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.lyrics:
        return LyricsTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.musicalKey:
        return MusicalKeyTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.dateRecorded:
        return DateRecordedTag(internedValue as String, provenance: originalTag.provenance);
      case TagKey.genre:
        return GenreTag(internedValue as List<String>, provenance: originalTag.provenance);
      case TagKey.custom:
        return CustomTag(internedValue as String, provenance: originalTag.provenance);
      default:
        // For non-string tags or unknown types, return original
        return originalTag;
    }
  }

  /// Compacts storage for small collections to minimize memory overhead.
  void _compactStorage() {
    if (_tagsByKey == null || _tagsByKey!.isEmpty) {
      return;
    }

    // For very small collections, consider using more compact representations
    if (_tagsByKey!.length <= 3) {
      // Convert to a more compact map implementation if beneficial
      // This is a placeholder for potential future optimizations
      // such as using specialized small-map implementations
    }

    // Compact individual tag lists
    for (final entry in _tagsByKey!.entries) {
      final tagList = entry.value;
      if (tagList.length == 1) {
        // For single-item lists, we could potentially use a more compact representation
        // This is a placeholder for future optimization
      }
    }
  }

  /// Retrieves the first tag with the specified key.
  ///
  /// @param key The tag key to look up
  /// @returns The first tag with the key, or null if not found
  MetadataTag? getTag(TagKey key) {
    final tags = _tagsByKey?[key];
    return tags?.isNotEmpty == true ? tags!.first : null;
  }

  /// Retrieves all tags with the specified key.
  ///
  /// @param key The tag key to look up
  /// @returns A list of all tags with the key (empty if none found)
  List<MetadataTag> getTags(TagKey key) {
    final tags = _tagsByKey?[key];
    return tags != null ? List<MetadataTag>.from(tags) : <MetadataTag>[];
  }

  /// Retrieves all tags stored in this instance.
  ///
  /// @returns A list of all stored tags
  List<MetadataTag> getAllTags() {
    if (_tagsByKey == null) {
      return <MetadataTag>[];
    }

    final allTags = <MetadataTag>[];
    for (final tagList in _tagsByKey!.values) {
      allTags.addAll(tagList);
    }
    return allTags;
  }

  /// Adds a single tag to the storage.
  ///
  /// @param tag The tag to add
  void addTag(MetadataTag tag) {
    _tagsByKey ??= <TagKey, List<MetadataTag>>{};

    final optimizedTag = _optimizeTag(tag);
    final tagList = _tagsByKey![tag.key] ??= <MetadataTag>[];
    tagList.add(optimizedTag);

    _totalTagsStored++;
  }

  /// Removes all tags with the specified key.
  ///
  /// @param key The tag key to remove
  /// @returns True if any tags were removed
  bool removeTag(TagKey key) {
    final removed = _tagsByKey?.remove(key);
    return removed != null && removed.isNotEmpty;
  }

  /// Returns the number of unique tag keys stored.
  int get keyCount => _tagsByKey?.length ?? 0;

  /// Returns the total number of tag instances stored.
  int get tagCount {
    if (_tagsByKey == null) return 0;

    int count = 0;
    for (final tagList in _tagsByKey!.values) {
      count += tagList.length;
    }
    return count;
  }

  /// Estimates the memory usage of this storage instance in bytes.
  ///
  /// This provides a rough estimate based on:
  /// - Map overhead for key storage
  /// - List overhead for tag collections
  /// - Tag object overhead
  /// - String storage (accounting for interning)
  int get estimatedMemoryUsage {
    if (_tagsByKey == null) {
      return 32; // Base object overhead
    }

    int usage = 64; // Base map overhead

    for (final entry in _tagsByKey!.entries) {
      usage += 16; // Map entry overhead
      usage += 32; // List overhead

      for (final tag in entry.value) {
        usage += 48; // Tag object overhead

        // Estimate value storage
        if (tag.value is String) {
          final str = tag.value as String;
          usage += str.length * 2; // Approximate UTF-16 storage
        } else if (tag.value is List<String>) {
          final list = tag.value as List<String>;
          usage += 32; // List overhead
          for (final str in list) {
            usage += str.length * 2 + 16; // String + list entry overhead
          }
        } else if (tag.value is int) {
          usage += 8; // Integer storage
        } else {
          usage += 32; // Generic object overhead
        }
      }
    }

    return usage;
  }

  /// Returns statistics about memory usage and optimization effectiveness.
  Map<String, dynamic> get memoryStatistics => {
    'keyCount': keyCount,
    'tagCount': tagCount,
    'estimatedMemoryUsage': estimatedMemoryUsage,
    'totalTagsStored': _totalTagsStored,
    'totalStringValues': _totalStringValues,
    'internedStringValues': _internedStringValues,
    'interningEffectiveness': _totalStringValues > 0 ? _internedStringValues / _totalStringValues : 0.0,
    'stringInterningEnabled': _useInterning,
    'stringInterningStats': _stringInterning?.statistics,
  };

  /// Clears all stored tags and resets statistics.
  void clear() {
    _tagsByKey?.clear();
    _totalTagsStored = 0;
    _totalStringValues = 0;
    _internedStringValues = 0;
  }

  /// Returns whether the storage is empty.
  bool get isEmpty => _tagsByKey == null || _tagsByKey!.isEmpty;

  /// Returns whether the storage has any tags.
  bool get isNotEmpty => !isEmpty;
}

/// A specialized storage pool for managing multiple tag storage instances
/// efficiently, useful for batch processing of many files.
///
/// This pool helps reduce memory allocation overhead when processing
/// large collections of files by reusing storage instances.
class TagStoragePool {
  final Queue<MemoryEfficientTagStorage> _availableStorage = Queue<MemoryEfficientTagStorage>();
  final bool _useInterning;
  final StringInterning? _sharedInterning;

  int _totalCreated = 0;
  int _totalReused = 0;

  /// Creates a new tag storage pool.
  ///
  /// @param useInterning Whether storage instances should use string interning
  /// @param sharedInterning Optional shared string interning instance
  TagStoragePool({
    bool useInterning = true,
    StringInterning? sharedInterning,
  }) : _useInterning = useInterning,
       _sharedInterning = sharedInterning;

  /// Acquires a tag storage instance from the pool.
  ///
  /// Returns a clean, ready-to-use storage instance. If no instances
  /// are available in the pool, creates a new one.
  MemoryEfficientTagStorage acquire() {
    if (_availableStorage.isNotEmpty) {
      _totalReused++;
      final storage = _availableStorage.removeFirst();
      storage.clear(); // Ensure it's clean
      return storage;
    }

    _totalCreated++;
    return MemoryEfficientTagStorage(
      useInterning: _useInterning,
      stringInterning: _sharedInterning,
    );
  }

  /// Returns a tag storage instance to the pool for reuse.
  ///
  /// The storage will be cleared and made available for future use.
  /// This helps reduce allocation overhead in batch processing scenarios.
  void release(MemoryEfficientTagStorage storage) {
    storage.clear();
    _availableStorage.add(storage);

    // Prevent unbounded growth of the pool
    if (_availableStorage.length > 100) {
      _availableStorage.removeFirst();
    }
  }

  /// Returns statistics about pool usage efficiency.
  Map<String, dynamic> get statistics => {
    'totalCreated': _totalCreated,
    'totalReused': _totalReused,
    'currentPoolSize': _availableStorage.length,
    'reuseRatio': _totalCreated > 0 ? _totalReused / (_totalCreated + _totalReused) : 0.0,
  };

  /// Clears the pool and releases all storage instances.
  void clear() {
    _availableStorage.clear();
  }
}
