/// Memory optimization utilities for efficient audio metadata processing.
///
/// This module provides advanced memory management tools designed to handle
/// large collections of audio files efficiently by:
/// - String interning to eliminate duplicate string storage
/// - Memory-efficient tag storage with compact data structures
/// - Tag storage pooling for batch processing scenarios
///
/// ## Core Components
///
/// ### String Interning
/// - [StringInterning] - Advanced string deduplication system
/// - [globalStringInterning] - Shared global instance
///
/// ### Memory-Efficient Storage
/// - [MemoryEfficientTagStorage] - Compact tag storage with optional interning
/// - [TagStoragePool] - Object pooling for batch processing
///
/// ## Usage Examples
///
/// ### String Interning for Large Collections
/// ```dart
/// final interning = StringInterning();
///
/// // Process many files with common metadata values
/// for (final audioFile in largeCollection) {
///   final artist = interning.intern(audioFile.artist);
///   final genre = interning.intern(audioFile.genre);
///   // Memory is automatically shared for identical strings
/// }
///
/// print('Memory saved: ${interning.estimatedMemorySaved} bytes');
/// interning.clear(); // Release memory after batch
/// ```
///
/// ### Memory-Efficient Tag Storage
/// ```dart
/// final storage = MemoryEfficientTagStorage(useInterning: true);
///
/// storage.storeTags([
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']),
/// ]);
///
/// print('Memory usage: ${storage.estimatedMemoryUsage} bytes');
/// ```
///
/// ### Storage Pooling for Batch Processing
/// ```dart
/// final pool = TagStoragePool(useInterning: true);
///
/// for (final audioFile in batchOfFiles) {
///   final storage = pool.acquire();
///   storage.storeTags(audioFile.getAllTags());
///
///   // Process the tags...
///
///   pool.release(storage); // Return to pool for reuse
/// }
///
/// print('Pool efficiency: ${pool.statistics['reuseRatio'] * 100}%');
/// ```
library phonic.performance.memory;

export 'memory_efficient_tag_storage.dart';
export 'string_interning.dart';
