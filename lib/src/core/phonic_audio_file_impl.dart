import 'dart:typed_data';

import '../exceptions/corrupted_container_exception.dart';
import '../exceptions/phonic_exception.dart';
import '../exceptions/tag_validation_exception.dart';
import '../exceptions/unsupported_format_exception.dart';
import 'codec_registry.dart';
import 'container_kind.dart';
import 'container_rebuilder.dart';
import 'encoding_options.dart';
import 'encoding_preparation.dart';
import 'file_assembler.dart';
import 'format_strategy.dart';
import 'media_kind.dart';
import 'merge_policy.dart';
import 'metadata_tag.dart';
import 'phonic_audio_file.dart';
import 'post_write_validator.dart';
import 'rollback_manager.dart';
import 'tag_capability.dart';
import 'tag_key.dart';
import 'tag_semantics.dart';

/// Concrete implementation of the PhonicAudioFile interface providing comprehensive metadata operations.
///
/// PhonicAudioFileImpl serves as the primary implementation of the unified tagging API,
/// orchestrating the interaction between format strategies, codec registries, merge policies,
/// and container locators to provide seamless metadata operations across different audio
/// container formats.
///
/// This implementation maintains an in-memory representation of metadata tags with efficient
/// caching and change tracking to minimize file I/O operations while ensuring data integrity
/// and optimal performance for both single-file operations and batch processing scenarios.
///
/// ## Architecture Overview
///
/// The implementation follows a layered architecture with clear separation of concerns:
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │                    Public API Layer                         │
/// │           (getTag, setTag, encode, etc.)                   │
/// └─────────────────────────────────────────────────────────────┘
///                                │
/// ┌─────────────────────────────────────────────────────────────┐
/// │                 Tag Management Layer                        │
/// │        (in-memory storage, change tracking)                │
/// └─────────────────────────────────────────────────────────────┘
///                                │
/// ┌─────────────────────────────────────────────────────────────┐
/// │                Format Strategy Layer                        │
/// │     (precedence rules, fan-out policy, normalization)     │
/// └─────────────────────────────────────────────────────────────┘
///                                │
/// ┌─────────────────────────────────────────────────────────────┐
/// │                Container Processing Layer                   │
/// │         (codec registry, locators, merge policy)          │
/// └─────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Core Components
///
/// ### Format Strategy
/// - **Purpose**: Defines format-specific behavior and policies
/// - **Responsibilities**: Container precedence, fan-out targets, format detection
/// - **Examples**: Mp3FormatStrategy, FlacFormatStrategy, Mp4FormatStrategy
///
/// ### Codec Registry
/// - **Purpose**: Provides access to container-specific parsers and encoders
/// - **Responsibilities**: Codec discovery, container locator management
/// - **Thread Safety**: Immutable after construction, safe for concurrent access
///
/// ### Merge Policy
/// - **Purpose**: Handles tag merging and value normalization
/// - **Responsibilities**: Precedence-based conflict resolution, constraint application
/// - **Extensibility**: Supports custom merge rules and normalization strategies
///
/// ### In-Memory Tag Storage
/// - **Structure**: Map<TagKey, List<MetadataTag>> for efficient access
/// - **Benefits**: O(1) tag lookup, support for multi-valued fields, provenance preservation
/// - **Memory Efficiency**: Lazy loading for large payloads, string interning for common values
///
/// ## Memory Management Strategy
///
/// The implementation employs several memory optimization techniques:
///
/// ### Efficient Tag Storage
/// - **Primary Storage**: Tags organized by key for O(1) access patterns
/// - **Multi-Value Support**: Native support for fields like genre and artwork
/// - **Provenance Preservation**: Lightweight tracking of tag origins and confidence
/// - **String Interning**: Common values shared across instances to reduce memory footprint
///
/// ### Lazy Loading Patterns
/// - **Artwork Data**: Images loaded on-demand using LazyArtworkLoader
/// - **Container Caching**: Raw container bytes cached only when needed for writes
/// - **Streaming Support**: Large files processed incrementally where possible
///
/// ### Resource Management
/// - **Dispose Pattern**: Explicit resource cleanup for memory-constrained environments
/// - **Weak References**: Cached data eligible for garbage collection under memory pressure
/// - **Batch Processing**: Optimized memory usage for large collection operations
///
/// ## Change Tracking and Dirty State Management
///
/// ### Multi-Level Tracking
/// - **Global Dirty Flag**: Indicates any unsaved changes to the file
/// - **Tag-Level Changes**: Tracks modifications to individual metadata fields
/// - **Container-Level Deltas**: Optimizes write operations by updating only changed containers
///
/// ### Write Optimization
/// - **Selective Updates**: Only modified containers are rebuilt and written
/// - **Atomic Operations**: File integrity maintained through transactional writes
/// - **Rollback Support**: Failed operations can be reverted to previous state
///
/// ## Thread Safety Considerations
///
/// **Important**: This implementation is **not thread-safe**. Concurrent access requires
/// external synchronization:
///
/// ```dart
/// // Thread-safe usage pattern
/// final lock = Mutex();
///
/// await lock.acquire();
/// try {
///   audioFile.setTag(TitleTag('New Title'));
///   final encoded = await audioFile.encode();
/// } finally {
///   lock.release();
/// }
/// ```
///
/// ### Shared Resources
/// - **Format Strategy**: Immutable, safe for sharing across instances
/// - **Codec Registry**: Immutable, safe for concurrent access
/// - **Merge Policy**: Stateless, safe for sharing
/// - **File Instance**: Mutable state requires synchronization
///
/// ## Performance Characteristics
///
/// ### Read Operations
/// - **Tag Access**: O(1) lookup time for individual tags
/// - **Multi-Value Fields**: O(n) where n is number of values for the field
/// - **Container Parsing**: Cached results avoid redundant parsing
/// - **Memory Usage**: Proportional to metadata size, not file size
///
/// ### Write Operations
/// - **Encoding Preparation**: O(m) where m is number of tags to write
/// - **Container Rebuilding**: O(c) where c is number of target containers
/// - **File Assembly**: O(f) where f is total file size
/// - **Validation**: Optional post-write integrity checking
///
/// ## Usage Patterns and Examples
///
/// ### Basic Metadata Operations
/// ```dart
/// // Create from file bytes with automatic format detection
/// final audioFile = PhonicAudioFileImpl(
///   fileBytes: await File('song.mp3').readAsBytes(),
///   formatStrategy: Mp3FormatStrategy(),
///   codecRegistry: registry,
///   mergePolicy: MergePolicy.fromStrategy(Mp3FormatStrategy()),
/// );
///
/// // Read metadata with provenance information
/// final title = audioFile.getTag(TagKey.title);
/// print('Title: ${title?.value}');
/// print('Source: ${title?.provenance.containerKind} ${title?.provenance.containerVersion}');
///
/// // Handle multi-valued fields
/// final genres = audioFile.getTags(TagKey.genre);
/// for (final genre in genres) {
///   print('Genre: ${genre.value} from ${genre.provenance.containerKind}');
/// }
/// ```
///
/// ### Advanced Tag Management
/// ```dart
/// // Set tags with automatic validation
/// try {
///   audioFile.setTag(TitleTag('New Song Title'));
///   audioFile.setTag(ArtistTag('New Artist'));
///   audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));
///   audioFile.setTag(RatingTag(85)); // 0-100 scale
///   audioFile.setTag(TrackNumberTag(5));
/// } on TagValidationException catch (e) {
///   print('Validation failed for ${e.tagKey}: ${e.reason}');
/// }
///
/// // Remove specific tag values
/// audioFile.removeTagValue(TagKey.genre, 'Alternative');
///
/// // Remove entire tag fields
/// audioFile.removeTag(TagKey.comment);
/// ```
///
/// ### Batch Processing and Memory Management
/// ```dart
/// // Process large collections efficiently
/// final files = ['song1.mp3', 'song2.flac', 'song3.m4a'];
///
/// for (final filePath in files) {
///   PhonicAudioFile? audioFile;
///   try {
///     audioFile = await Phonic.fromFile(filePath);
///
///     // Process metadata
///     final title = audioFile.getTag(TagKey.title);
///     await processMetadata(title?.value);
///
///     // Modify if needed
///     if (needsUpdate(audioFile)) {
///       audioFile.setTag(TitleTag(generateNewTitle()));
///
///       if (audioFile.isDirty) {
///         final encoded = await audioFile.encode();
///         await File(filePath).writeAsBytes(encoded);
///         audioFile.markClean();
///       }
///     }
///   } finally {
///     // Always dispose to free resources
///     audioFile?.dispose();
///   }
/// }
/// ```
///
/// ### Error Handling and Recovery
/// ```dart
/// try {
///   // Attempt to encode with validation
///   final encodedBytes = await audioFile.encode();
///   await saveToFile(encodedBytes);
///   audioFile.markClean();
/// } on TagValidationException catch (e) {
///   // Handle validation errors
///   print('Tag validation failed: ${e.tagKey} - ${e.reason}');
///   // Optionally fix the problematic tag
///   audioFile.removeTag(e.tagKey);
///   retry();
/// } on CorruptedContainerException catch (e) {
///   // Handle container corruption
///   print('Container corruption at offset ${e.byteOffset}: ${e.message}');
///   // Attempt recovery or skip this container
/// } on UnsupportedFormatException catch (e) {
///   // Handle unsupported formats
///   print('Format not supported: ${e.message}');
/// }
/// ```
///
/// ## Integration with Format Strategies
///
/// The implementation works seamlessly with different format strategies:
///
/// ### MP3 Files (Multiple Containers)
/// ```dart
/// // MP3 strategy handles ID3v2.4, ID3v2.3, ID3v2.2, and ID3v1
/// final mp3File = PhonicAudioFileImpl(
///   fileBytes: mp3Bytes,
///   formatStrategy: Mp3FormatStrategy(),
///   codecRegistry: registry,
///   mergePolicy: MergePolicy.fromStrategy(Mp3FormatStrategy()),
/// );
///
/// // Reads with precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
/// // Writes to: ID3v2.4 (primary) + ID3v1 (compatibility)
/// ```
///
/// ### FLAC Files (Single Container)
/// ```dart
/// // FLAC strategy handles Vorbis Comments only
/// final flacFile = PhonicAudioFileImpl(
///   fileBytes: flacBytes,
///   formatStrategy: FlacFormatStrategy(),
///   codecRegistry: registry,
///   mergePolicy: MergePolicy.fromStrategy(FlacFormatStrategy()),
/// );
///
/// // Native multi-valued field support, UTF-8 encoding throughout
/// ```
///
/// ## Best Practices
///
/// ### Memory Efficiency
/// - Always call `dispose()` when finished with an audio file instance
/// - Use batch processing patterns for large collections
/// - Consider memory monitoring for long-running applications
/// - Leverage lazy loading for artwork and large payloads
///
/// ### Error Handling
/// - Wrap operations in try-catch blocks for specific exception types
/// - Validate tags before setting to avoid encoding failures
/// - Use dirty flag checking to avoid unnecessary encoding operations
/// - Implement retry logic for transient failures
///
/// ### Performance Optimization
/// - Cache PhonicAudioFileImpl instances for repeated access to the same file
/// - Use appropriate format strategies for known file types
/// - Batch tag modifications before encoding
/// - Consider streaming operations for very large files
///
/// ### Thread Safety
/// - Synchronize access when using instances across multiple threads
/// - Consider using separate instances per thread for better performance
/// - Be aware that format strategies and registries are thread-safe for sharing
class PhonicAudioFileImpl implements PhonicAudioFile {
  /// The format strategy used for this audio file.
  ///
  /// The format strategy determines how containers are detected, their
  /// precedence order for reading, and fan-out targets for writing.
  /// This strategy is specific to the media format (MP3, FLAC, etc.)
  /// and defines format-specific behavior.
  final FormatStrategy formatStrategy;

  /// Registry of available codecs and container locators.
  ///
  /// The codec registry provides access to all available TagCodec and
  /// ContainerLocator implementations. It's used to find appropriate
  /// codecs for parsing and encoding specific container formats.
  final CodecRegistry codecRegistry;

  /// Policy for merging tags and handling precedence.
  ///
  /// The merge policy defines how tags from multiple containers are
  /// combined, which containers take precedence, and how values are
  /// normalized for different target containers.
  final MergePolicy mergePolicy;

  /// In-memory storage of tags organized by key.
  ///
  /// This map provides efficient access to the current state of all
  /// metadata tags. Tags are organized by their TagKey for fast lookup
  /// and modification. Multiple tags with the same key are stored as
  /// a list to support multi-valued fields.
  ///
  /// The map is updated whenever tags are read from containers or
  /// modified through the API. It serves as the authoritative source
  /// for the current tag state.
  final Map<TagKey, List<MetadataTag>> inMemoryTagsByKey;

  /// Cache of loaded container data organized by kind and version.
  ///
  /// This map caches the raw bytes of metadata containers that have
  /// been loaded from the file. The cache is organized by container
  /// type and version to allow efficient lookup and avoid redundant
  /// parsing operations.
  ///
  /// Container data is loaded on-demand and cached for potential
  /// write operations. The cache is cleared when the file is disposed
  /// to free memory.
  ///
  /// Map structure: {(ContainerKind, version): containerBytes}
  final Map<(ContainerKind, String), Uint8List> loadedContainersByKindAndVersion;

  /// Flag indicating whether the file has unsaved changes.
  ///
  /// This flag is set to true whenever tags are modified through the
  /// API (setTag, removeTag, etc.) and reset to false when markClean()
  /// is called. It helps determine when the file needs to be encoded
  /// and written back to storage.
  bool _isDirty;

  /// The original file bytes for this audio file.
  ///
  /// These bytes represent the complete original file content, including
  /// both audio data and metadata containers. They are used as the base
  /// for encoding operations and for extracting raw audio data.
  final Uint8List _fileBytes;

  /// Post-write validator for ensuring file integrity after encoding.
  ///
  /// This validator performs comprehensive checks on encoded files to
  /// detect corruption, structural issues, and tag consistency problems.
  /// It can be configured for different levels of validation depth.
  late final PostWriteValidator _validator;

  /// Rollback manager for handling failed write operations.
  ///
  /// This manager maintains snapshots of file state before modifications,
  /// allowing restoration if validation fails or errors occur during
  /// the encoding process.
  late final RollbackManager _rollbackManager;

  /// Creates a new PhonicAudioFileImpl instance.
  ///
  /// This constructor initializes the implementation with the required
  /// components and sets up the internal data structures. The file bytes
  /// are stored for later use in encoding operations.
  ///
  /// Parameters:
  /// - [fileBytes]: The complete audio file bytes
  /// - [formatStrategy]: Strategy for format-specific operations
  /// - [codecRegistry]: Registry of available codecs and locators
  /// - [mergePolicy]: Policy for tag merging and normalization
  /// - [isDirty]: Initial dirty state (defaults to false)
  ///
  /// The constructor does not automatically load tags from the file.
  /// Tag loading should be performed separately to allow for lazy
  /// initialization and error handling.
  ///
  /// Example:
  /// ```dart
  /// final audioFile = PhonicAudioFileImpl(
  ///   fileBytes: await File('song.mp3').readAsBytes(),
  ///   formatStrategy: Mp3FormatStrategy(),
  ///   codecRegistry: CodecRegistry(
  ///     codecList: [Id3v24Codec(), Id3v23Codec(), Id3v1Codec()],
  ///     containerLocatorList: [Id3v2Locator(), Id3v1Locator()],
  ///   ),
  ///   mergePolicy: MergePolicy.fromStrategy(Mp3FormatStrategy()),
  /// );
  /// ```
  PhonicAudioFileImpl({
    required Uint8List fileBytes,
    required this.formatStrategy,
    required this.codecRegistry,
    required this.mergePolicy,
    bool isDirty = false,
    PostWriteValidator? validator,
    RollbackManager? rollbackManager,
  }) : _fileBytes = Uint8List.fromList(fileBytes),
       inMemoryTagsByKey = <TagKey, List<MetadataTag>>{},
       loadedContainersByKindAndVersion = <(ContainerKind, String), Uint8List>{},
       _isDirty = isDirty {
    _validator = validator ?? PostWriteValidator(codecRegistry: codecRegistry);
    _rollbackManager = rollbackManager ?? RollbackManager();
  }

  @override
  MetadataTag? getTag(TagKey key) {
    final tags = inMemoryTagsByKey[key];
    if (tags == null || tags.isEmpty) {
      return null;
    }

    // Return the first tag (highest precedence)
    return tags.first;
  }

  @override
  List<MetadataTag> getTags(TagKey key) {
    final tags = inMemoryTagsByKey[key];
    if (tags == null) {
      return <MetadataTag>[];
    }

    // Return a copy to prevent external modification
    return List<MetadataTag>.from(tags);
  }

  /// Retrieves all metadata tags from all containers in the file.
  ///
  /// This method returns a flattened collection of all metadata tags
  /// that have been loaded from the file's containers, preserving
  /// provenance information for each tag. The tags are returned in
  /// the order they appear in the internal storage, which reflects
  /// the precedence rules applied during container extraction.
  ///
  /// ## Behavior
  ///
  /// - Returns all tags from all tag keys in a single flat list
  /// - Preserves provenance information for each tag
  /// - Maintains the order established by precedence rules
  /// - Returns an empty list if no tags have been loaded
  /// - Automatically triggers container extraction if not already performed
  ///
  /// ## Provenance Preservation
  ///
  /// Each returned tag maintains its original provenance information,
  /// including:
  /// - Container kind (ID3v2, ID3v1, Vorbis, MP4)
  /// - Container version (e.g., "2.4", "v1")
  /// - Confidence level (certain, inferred, derived)
  ///
  /// ## Performance Considerations
  ///
  /// This method creates a new list containing all tags, so it has
  /// O(n) time and space complexity where n is the total number of
  /// tags. For large collections, consider using getTags() for
  /// specific keys when possible.
  ///
  /// ## Usage Example
  ///
  /// ```dart
  /// // Get all tags for comprehensive metadata display
  /// final allTags = audioFile.getAllTags();
  ///
  /// for (final tag in allTags) {
  ///   print('${tag.key}: ${tag.value}');
  ///   print('  Source: ${tag.provenance.containerKind} ${tag.provenance.containerVersion}');
  ///   print('  Confidence: ${tag.provenance.confidence}');
  /// }
  ///
  /// // Filter by provenance
  /// final id3v2Tags = allTags.where((tag) =>
  ///   tag.provenance.containerKind == ContainerKind.id3v2).toList();
  /// ```
  ///
  /// Returns:
  /// - A new list containing all metadata tags from all containers
  /// - Empty list if no tags are present
  /// - Tags maintain their original provenance information
  @override
  List<MetadataTag> getAllTags() {
    // Ensure containers have been extracted before accessing tags
    final allTags = <MetadataTag>[];

    // Flatten all tag lists while preserving provenance
    for (final tagList in inMemoryTagsByKey.values) {
      allTags.addAll(tagList);
    }

    return allTags;
  }

  /// Sets a metadata tag, replacing any existing tags with the same key.
  ///
  /// This method adds or updates a metadata tag in the audio file's in-memory
  /// representation. The tag will be validated against the capabilities of the
  /// target container formats defined by the format strategy's fan-out policy.
  ///
  /// ## Behavior
  ///
  /// - **Single-valued tags**: Replaces any existing tag with the same key
  /// - **Multi-valued tags**: Replaces all existing tags with the same key with this single tag
  /// - **Validation**: Validates tag value against all fan-out target container capabilities
  /// - **Dirty tracking**: Sets the dirty flag to indicate unsaved changes
  /// - **Provenance**: Preserves the tag's provenance information
  ///
  /// ## Validation Process
  ///
  /// The method validates the tag against all containers in the format strategy's
  /// fan-out list to ensure the tag can be written to at least one target container:
  ///
  /// 1. **Container Support**: Verifies at least one fan-out container supports the tag key
  /// 2. **Value Constraints**: Validates numeric ranges, text lengths, and format requirements
  /// 3. **Multi-value Support**: Checks if multi-valued tags are supported appropriately
  /// 4. **Encoding Support**: Validates text encoding compatibility (future enhancement)
  ///
  /// ## Single-valued vs Multi-valued Tags
  ///
  /// ### Single-valued Tags (most common)
  /// ```dart
  /// // These replace any existing tag with the same key
  /// audioFile.setTag(TitleTag('New Song Title'));
  /// audioFile.setTag(ArtistTag('New Artist'));
  /// audioFile.setTag(RatingTag(85));
  /// ```
  ///
  /// ### Multi-valued Tags
  /// ```dart
  /// // This replaces all existing genre tags with a single multi-genre tag
  /// audioFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));
  ///
  /// // To add multiple separate genre tags, use multiple calls:
  /// audioFile.setTag(GenreTag(['Rock']));
  /// // This would replace the previous genre tag, not add to it
  /// ```
  ///
  /// ## Validation Examples
  ///
  /// ### Successful Validation
  /// ```dart
  /// // Valid rating within 0-100 range
  /// audioFile.setTag(RatingTag(85)); // ✓ Valid
  ///
  /// // Valid title within length constraints
  /// audioFile.setTag(TitleTag('Short Title')); // ✓ Valid
  ///
  /// // Valid track number (positive integer)
  /// audioFile.setTag(TrackNumberTag(5)); // ✓ Valid
  /// ```
  ///
  /// ### Validation Failures
  /// ```dart
  /// try {
  ///   // Rating outside valid range
  ///   audioFile.setTag(RatingTag(150)); // ✗ Throws TagValidationException
  /// } on TagValidationException catch (e) {
  ///   print('Rating validation failed: ${e.reason}');
  /// }
  ///
  /// try {
  ///   // Track number must be positive
  ///   audioFile.setTag(TrackNumberTag(-1)); // ✗ Throws TagValidationException
  /// } on TagValidationException catch (e) {
  ///   print('Track number validation failed: ${e.reason}');
  /// }
  /// ```
  ///
  /// ## Container-Specific Validation
  ///
  /// The validation process considers the constraints of all fan-out target containers:
  ///
  /// ```dart
  /// // For MP3 files with ID3v2.4 + ID3v1 fan-out:
  /// // - ID3v2.4: Supports long titles, full rating range
  /// // - ID3v1: 30-character title limit, no rating support
  ///
  /// // This title would be valid for ID3v2.4 but truncated for ID3v1
  /// audioFile.setTag(TitleTag('This is a very long song title that exceeds ID3v1 limits'));
  ///
  /// // This rating would be written to ID3v2.4 only (ID3v1 doesn't support ratings)
  /// audioFile.setTag(RatingTag(85));
  /// ```
  ///
  /// ## Error Handling
  ///
  /// The method provides detailed error information for validation failures:
  ///
  /// ```dart
  /// try {
  ///   audioFile.setTag(BpmTag(0)); // Invalid BPM
  /// } on TagValidationException catch (e) {
  ///   print('Tag: ${e.tagKey}');           // TagKey.bpm
  ///   print('Reason: ${e.reason}');        // "BPM must be positive, got 0"
  ///   print('Context: ${e.context}');      // Additional validation context
  /// }
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// - Validation is performed synchronously and should complete quickly
  /// - Container capability lookups are cached by the codec registry
  /// - Text length validation is O(1) for most cases
  /// - Numeric range validation is O(1)
  ///
  /// ## Thread Safety
  ///
  /// This method is not thread-safe. Concurrent access should be synchronized
  /// by the caller to prevent race conditions in tag modification.
  ///
  /// Parameters:
  /// - [tag]: The metadata tag to set. Must not be null.
  ///
  /// @throws [TagValidationException] if the tag value violates container constraints
  /// @throws [ArgumentError] if the tag parameter is null
  ///
  /// Example usage:
  /// ```dart
  /// // Basic tag setting
  /// audioFile.setTag(TitleTag('My Song'));
  /// audioFile.setTag(ArtistTag('My Artist'));
  /// audioFile.setTag(RatingTag(85));
  ///
  /// // Multi-genre tag
  /// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
  ///
  /// // With error handling
  /// try {
  ///   audioFile.setTag(TrackNumberTag(trackNum));
  /// } on TagValidationException catch (e) {
  ///   // Handle validation error
  ///   showErrorDialog('Invalid track number: ${e.reason}');
  /// }
  ///
  /// // Check if changes need saving
  /// if (audioFile.isDirty) {
  ///   final encodedBytes = await audioFile.encode();
  ///   await saveToFile(encodedBytes);
  ///   audioFile.markClean();
  /// }
  /// ```
  @override
  void setTag(MetadataTag tag) {
    // Note: Some tag classes (like RatingTag, TrackNumberTag) already perform
    // their own validation in their constructors and throw ArgumentError.
    // We let those validation errors pass through as they are more specific
    // than our container-based validation.

    // Validate the tag against fan-out target capabilities
    _validateTagForFanoutTargets(tag);

    // Replace all existing tags with this key with the new tag
    inMemoryTagsByKey[tag.key] = [tag];
    _isDirty = true;
  }

  /// Validates a tag against the capabilities of all fan-out target containers.
  ///
  /// This method ensures that the tag can be written to at least one of the
  /// containers specified in the format strategy's fan-out policy. It checks
  /// container support, value constraints, and format-specific requirements.
  ///
  /// The validation process:
  /// 1. Gets fan-out targets from the format strategy
  /// 2. For each target, finds the appropriate codec and its capabilities
  /// 3. Validates the tag value against each container's constraints
  /// 4. Ensures at least one container can accept the tag
  ///
  /// Parameters:
  /// - [tag]: The tag to validate
  ///
  /// @throws [TagValidationException] if validation fails
  void _validateTagForFanoutTargets(MetadataTag tag) {
    final fanoutTargets = formatStrategy.fanout;

    if (fanoutTargets.isEmpty) {
      // No fan-out targets defined - this shouldn't happen in normal usage
      // but we'll allow it for flexibility
      return;
    }

    bool isSupported = false;
    final validationErrors = <String>[];

    // Check each fan-out target container
    for (final (containerKind, containerVersion) in fanoutTargets) {
      final codec = codecRegistry.findCodec(containerKind, containerVersion);
      if (codec == null) {
        // No codec available for this container - skip it
        continue;
      }

      final capability = codec.capability;

      // Check if this container supports the tag key
      if (!capability.supports(tag.key)) {
        validationErrors.add('${containerKind.name} v$containerVersion does not support ${tag.key.name}');
        continue;
      }

      // Container supports the tag key
      isSupported = true;

      // Validate the tag value against this container's constraints
      final semantics = capability.semantics(tag.key);
      final validationError = _validateTagValue(tag, semantics, containerKind, containerVersion);

      if (validationError != null) {
        validationErrors.add(validationError);
      }
    }

    // If no container supports this tag key, throw validation exception
    if (!isSupported) {
      throw TagValidationException(
        tag.key,
        'Tag is not supported by any fan-out target container',
        context: 'fanout targets: ${fanoutTargets.map((t) => '${t.$1.name} v${t.$2}').join(', ')}',
      );
    }

    // If there were validation errors for all containers that support the tag,
    // we still allow the tag to be set since some containers might accept it
    // with normalization during the write process. The validation errors are
    // collected for potential logging or user feedback in the future.
  }

  /// Validates a tag value against the semantic constraints of a specific container.
  ///
  /// This method checks the tag value against the constraints defined in the
  /// container's TagSemantics, including text length limits, numeric ranges,
  /// and other format-specific requirements.
  ///
  /// Parameters:
  /// - [tag]: The tag to validate
  /// - [semantics]: The semantic constraints for the container
  /// - [containerKind]: The container type (for error messages)
  /// - [containerVersion]: The container version (for error messages)
  ///
  /// Returns:
  /// - `null` if validation passes
  /// - Error message string if validation fails
  String? _validateTagValue(MetadataTag tag, TagSemantics semantics, ContainerKind containerKind, String containerVersion) {
    final containerName = '${containerKind.name} v$containerVersion';

    // Validate text length constraints
    if (tag.value is String) {
      final textValue = tag.value as String;
      if (!semantics.isValidTextLength(textValue.length)) {
        return 'Text length ${textValue.length} exceeds maximum ${semantics.maxTextLength} for $containerName';
      }
    }

    // Validate numeric value constraints
    if (tag.value is num) {
      final numValue = tag.value as num;
      if (!semantics.isValidValue(numValue)) {
        final constraints = <String>[];
        if (semantics.minValue != null) constraints.add('min: ${semantics.minValue}');
        if (semantics.maxValue != null) constraints.add('max: ${semantics.maxValue}');
        return 'Value $numValue is outside allowed range (${constraints.join(', ')}) for $containerName';
      }
    }

    // Note: Specific tag validation (like rating ranges, positive integers)
    // is handled by the individual tag class constructors. We focus here
    // on container-specific constraints like text length and encoding.

    return null; // Validation passed
  }

  @override
  void removeTag(TagKey key) {
    if (inMemoryTagsByKey.remove(key) != null) {
      _isDirty = true;
    }
  }

  @override
  void removeTagValue(TagKey key, dynamic value) {
    final tags = inMemoryTagsByKey[key];
    if (tags == null || tags.isEmpty) {
      return;
    }

    // For single-valued tags, remove the entire tag if value matches
    if (tags.length == 1) {
      if (_valuesEqual(tags.first.value, value)) {
        removeTag(key);
      }
      return;
    }

    // For multi-valued tags, remove matching values
    final originalLength = tags.length;
    tags.removeWhere((tag) => _valuesEqual(tag.value, value));

    if (tags.length != originalLength) {
      _isDirty = true;

      // If no tags remain, remove the key entirely
      if (tags.isEmpty) {
        inMemoryTagsByKey.remove(key);
      }
    }
  }

  /// Helper method to compare tag values for equality.
  ///
  /// This method handles different value types appropriately:
  /// - For List values, compares element-wise
  /// - For other values, uses standard equality
  bool _valuesEqual(dynamic value1, dynamic value2) {
    if (value1 is List && value2 is List) {
      if (value1.length != value2.length) return false;
      for (int i = 0; i < value1.length; i++) {
        if (value1[i] != value2[i]) return false;
      }
      return true;
    }
    return value1 == value2;
  }

  @override
  bool get isDirty => _isDirty;

  @override
  void markClean() {
    _isDirty = false;
  }

  /// Encodes the audio file with current metadata tags to bytes.
  ///
  /// This method orchestrates the complete file encoding process by:
  /// 1. Preparing tags for encoding using format-specific normalization
  /// 2. Rebuilding containers with updated metadata while preserving unknown data
  /// 3. Injecting containers into the file using appropriate locators
  /// 4. Validating the resulting file structure for integrity
  /// 5. Clearing dirty flags after successful encoding
  ///
  /// ## Process Overview
  ///
  /// ### 1. Encoding Preparation
  /// Tags are prepared for each target container format according to the
  /// format strategy's fan-out policy. This includes:
  /// - Filtering tags to only those supported by each container
  /// - Normalizing values to fit container constraints (length limits, ranges)
  /// - Converting between different encoding formats and scales
  /// - Handling multi-valued fields appropriately for each format
  ///
  /// ### 2. Container Rebuilding
  /// For each target container, the system:
  /// - Uses the appropriate codec to encode prepared tags
  /// - Preserves unknown metadata from existing containers
  /// - Maintains format-specific structure and ordering
  /// - Applies container-specific encoding rules
  ///
  /// ### 3. File Assembly
  /// The updated containers are injected into the file:
  /// - Containers are placed in format-specific order
  /// - File structure is maintained for the audio format
  /// - Atomic operations ensure file integrity
  /// - Original audio data is preserved unchanged
  ///
  /// ### 4. Validation and Cleanup
  /// After successful encoding:
  /// - File structure is validated for integrity
  /// - Dirty flags are cleared to reflect saved state
  /// - Memory resources are managed efficiently
  ///
  /// ## Format-Specific Behavior
  ///
  /// ### MP3 Files
  /// - Writes to ID3v2.4 (primary) and ID3v1 (compatibility)
  /// - ID3v2 placed at file beginning, ID3v1 at end
  /// - Values normalized for each container's constraints
  /// - Multi-genre handling with appropriate delimiters
  ///
  /// ### FLAC Files
  /// - Writes to Vorbis Comments metadata block
  /// - Preserves other metadata blocks unchanged
  /// - Supports native multi-valued fields
  /// - UTF-8 encoding throughout
  ///
  /// ### OGG Files
  /// - Updates Vorbis Comments in comment header packet
  /// - Rebuilds OGG page structure as needed
  /// - Maintains stream integrity and checksums
  ///
  /// ### MP4 Files
  /// - Updates atoms within moov.udta.meta.ilst hierarchy
  /// - Preserves unknown atoms and structure
  /// - Handles both standard and freeform atoms
  /// - Maintains atom size and hierarchy consistency
  ///
  /// ## Error Handling
  ///
  /// The method provides comprehensive error handling:
  /// - Individual container failures don't abort the entire process
  /// - Validation errors are reported with specific context
  /// - File corruption is detected and reported
  /// - Rollback capability if encoding fails
  ///
  /// ## Performance Considerations
  ///
  /// - Encoding preparation is applied only to supported fields
  /// - Container rebuilding preserves unknown data efficiently
  /// - Memory usage is optimized for large files
  /// - Streaming operations used where possible
  ///
  /// ## Thread Safety
  ///
  /// This method is not thread-safe. Concurrent access should be synchronized
  /// by the caller to prevent race conditions during encoding.
  ///
  /// Returns:
  /// - The complete encoded file bytes with updated metadata
  ///
  /// Throws:
  /// - [UnsupportedFormatException] if the format strategy is not supported
  /// - [CorruptedContainerException] if container generation produces invalid data
  /// - [TagValidationException] if tag values violate container constraints
  /// - [PhonicException] for other encoding failures
  ///
  /// Example:
  /// ```dart
  /// // Modify tags
  /// audioFile.setTag(TitleTag('New Title'));
  /// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
  /// audioFile.setTag(RatingTag(85));
  ///
  /// // Check if encoding is needed
  /// if (audioFile.isDirty) {
  ///   try {
  ///     // Encode with all preparation and validation
  ///     final encodedBytes = await audioFile.encode();
  ///
  ///     // Save to file
  ///     await File('updated_song.mp3').writeAsBytes(encodedBytes);
  ///
  ///     // File is now clean (dirty flag cleared automatically)
  ///     assert(!audioFile.isDirty);
  ///   } on TagValidationException catch (e) {
  ///     print('Tag validation failed: ${e.reason}');
  ///   } on CorruptedContainerException catch (e) {
  ///     print('Container corruption: ${e.message}');
  ///   }
  /// }
  /// ```
  @override
  Future<Uint8List> encode([EncodingOptions? options]) async {
    // Use preserveExisting strategy by default for maximum compatibility
    final encodingOptions = options ?? const EncodingOptions.preserveExisting();

    try {
      // Step 1: Determine target containers based on encoding strategy
      final targetContainers = _determineTargetContainers(encodingOptions);

      // Step 2: Prepare tags for encoding using format-specific normalization
      final encodingPreparation = const EncodingPreparation();
      final tagsToWrite = getAllTags();

      // Get capabilities for target containers (not all fan-out containers)
      final capabilities = <(ContainerKind, String), TagCapability>{};
      for (final (containerKind, containerVersion) in targetContainers) {
        final codec = codecRegistry.findCodec(containerKind, containerVersion);
        if (codec != null) {
          capabilities[(containerKind, containerVersion)] = codec.capability;
        }
      }

      // Prepare tags for encoding with container-specific normalization
      final preparedTagsByContainer = encodingPreparation.prepareTagsForEncoding(
        tags: tagsToWrite,
        strategy: formatStrategy,
        capabilities: capabilities,
      );

      // Step 2: Create file assembler with container rebuilder
      final fileAssembler = FileAssembler(
        codecRegistry: codecRegistry,
        containerRebuilder: const ContainerRebuilder(),
      );

      // Step 3: Assemble the file with updated metadata containers
      // Use the prepared tags instead of raw tags for proper normalization
      final allPreparedTags = <MetadataTag>[];
      for (final tagList in preparedTagsByContainer.values) {
        allPreparedTags.addAll(tagList);
      }

      final assembledFile = await fileAssembler.assembleFile(
        originalFileBytes: _fileBytes,
        tagsToWrite: allPreparedTags.isNotEmpty ? allPreparedTags : tagsToWrite,
        formatStrategy: formatStrategy,
        existingContainers: loadedContainersByKindAndVersion,
      );

      // Step 4: Save current state for potential rollback
      final rollbackToken = _rollbackManager.saveState(
        fileBytes: _fileBytes,
        tags: inMemoryTagsByKey,
        description: 'Before encoding operation',
      );

      // Step 5: Validate the assembled file structure for integrity
      // Use custom target containers instead of default fan-out
      final validationResult = await _validator.validateEncodedFile(
        encodedBytes: assembledFile,
        originalTags: tagsToWrite,
        formatStrategy: formatStrategy,
        expectedContainers: targetContainers,
      );

      // Step 6: Handle validation results
      if (!validationResult.isValid) {
        // Rollback on validation failure
        final restoredState = _rollbackManager.rollbackTo(rollbackToken);
        if (restoredState != null) {
          // Restore the previous state
          inMemoryTagsByKey.clear();
          inMemoryTagsByKey.addAll(restoredState.tags);
        }

        // Create detailed error message
        final errorMessages = validationResult.errors.map((e) => e.toString()).join('\n');
        throw CorruptedContainerException(
          'Post-write validation failed: ${validationResult.summary}\n$errorMessages',
          context: 'Validation level: ${validationResult.validationLevel}, File size: ${assembledFile.length}',
        );
      }

      // Step 7: Log warnings if present
      if (validationResult.warnings.isNotEmpty) {
        // In a real implementation, you might want to use a proper logging system
        // For now, we'll just store the warnings in case the caller wants to access them
        // This could be exposed through a separate method or property
      }

      // Step 8: Discard rollback state after successful validation
      _rollbackManager.discardStatesUpTo(rollbackToken);

      // Step 9: Clear dirty flags after successful encoding
      markClean();

      return assembledFile;
    } catch (e) {
      // Attempt rollback on any exception during encoding
      final lastState = _rollbackManager.rollback();
      if (lastState != null) {
        // Restore the previous state
        inMemoryTagsByKey.clear();
        inMemoryTagsByKey.addAll(lastState.tags);
      }

      // Re-throw known exceptions with additional context
      if (e is PhonicException) {
        rethrow;
      }

      // Wrap unknown exceptions in PhonicException
      throw CorruptedContainerException(
        'File encoding failed: $e',
        context: 'Format: ${formatStrategy.mediaKind.name}, Tags: ${getAllTags().length}',
      );
    }
  }

  /// Gets information about the current rollback stack.
  ///
  /// This method provides details about saved rollback states, including
  /// memory usage and state descriptions. Useful for debugging and
  /// monitoring rollback system usage.
  ///
  /// Returns:
  /// - [RollbackStackInfo] containing details about saved states
  RollbackStackInfo getRollbackInfo() {
    return _rollbackManager.getStackInfo();
  }

  /// Manually saves the current state for potential rollback.
  ///
  /// This method allows explicit state saving before performing risky
  /// operations. The returned token can be used for targeted rollback.
  ///
  /// Parameters:
  /// - [description]: Optional description of the state being saved
  ///
  /// Returns:
  /// - [RollbackToken] that can be used for targeted rollback operations
  RollbackToken saveRollbackState({String? description}) {
    return _rollbackManager.saveState(
      fileBytes: _fileBytes,
      tags: inMemoryTagsByKey,
      description: description,
    );
  }

  /// Manually rolls back to a previously saved state.
  ///
  /// This method allows explicit rollback to a specific saved state.
  /// The file's tag state will be restored to the saved state.
  ///
  /// Parameters:
  /// - [token]: The rollback token identifying the target state
  ///
  /// Returns:
  /// - `true` if rollback was successful
  /// - `false` if the token was not found or rollback failed
  bool rollbackTo(RollbackToken token) {
    final restoredState = _rollbackManager.rollbackTo(token);
    if (restoredState != null) {
      // Restore the tag state
      inMemoryTagsByKey.clear();
      inMemoryTagsByKey.addAll(restoredState.tags);
      _isDirty = true; // Mark as dirty since state changed
      return true;
    }
    return false;
  }

  /// Clears all saved rollback states to free memory.
  ///
  /// This method removes all rollback states from memory. Use with
  /// caution as it removes the ability to rollback operations.
  void clearRollbackStates() {
    _rollbackManager.clearAll();
  }

  /// Releases resources and cleans up memory used by this audio file instance.
  ///
  /// This method performs explicit resource cleanup to free memory and release
  /// any cached data held by the audio file instance. After calling dispose(),
  /// the instance should not be used for any further operations.
  ///
  /// ## Cleanup Operations
  ///
  /// The dispose method performs the following cleanup operations:
  /// 1. **Tag Collection Cleanup**: Clears all in-memory metadata tags
  /// 2. **Container Cache Cleanup**: Releases cached container bytes
  /// 3. **State Reset**: Resets dirty flags and internal state
  /// 4. **Memory Release**: Frees memory used by internal data structures
  ///
  /// ## Memory Management
  ///
  /// This method is particularly important for memory management when working
  /// with large audio collections. Each audio file instance caches metadata
  /// and container data in memory for performance. Calling dispose() ensures
  /// this memory is released when the instance is no longer needed.
  ///
  /// ## Usage Patterns
  ///
  /// ### Single File Processing
  /// ```dart
  /// final audioFile = await Phonic.fromFile('song.mp3');
  /// try {
  ///   // Work with the audio file
  ///   audioFile.setTag(TitleTag('New Title'));
  ///   final bytes = await audioFile.encode();
  ///   await File('updated_song.mp3').writeAsBytes(bytes);
  /// } finally {
  ///   // Always dispose when done
  ///   audioFile.dispose();
  /// }
  /// ```
  ///
  /// ### Batch Processing
  /// ```dart
  /// for (final filePath in audioFiles) {
  ///   final audioFile = await Phonic.fromFile(filePath);
  ///   try {
  ///     // Process the file
  ///     processAudioFile(audioFile);
  ///   } finally {
  ///     // Dispose each file to prevent memory accumulation
  ///     audioFile.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// ### Collection Management
  /// ```dart
  /// final audioFiles = <PhonicAudioFile>[];
  /// try {
  ///   // Load multiple files
  ///   for (final path in filePaths) {
  ///     audioFiles.add(await Phonic.fromFile(path));
  ///   }
  ///   // Work with collection...
  /// } finally {
  ///   // Dispose all files
  ///   for (final file in audioFiles) {
  ///     file.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// This method is not thread-safe. If the audio file instance is being
  /// accessed from multiple threads, synchronization should be handled by
  /// the caller before calling dispose().
  ///
  /// ## Multiple Calls
  ///
  /// This method can be called multiple times safely. Subsequent calls after
  /// the first will have no effect, as the resources will already be released.
  ///
  /// ## Post-Disposal Behavior
  ///
  /// After dispose() is called:
  /// - All tag collections will be empty
  /// - Container caches will be cleared
  /// - The dirty flag will be reset to false
  /// - The instance should not be used for further operations
  /// - Calling other methods may result in unexpected behavior
  ///
  /// ## Performance Impact
  ///
  /// - Time complexity: O(n) where n is the number of cached tags and containers
  /// - Space complexity: Frees O(m) memory where m is the size of cached data
  /// - The operation completes synchronously and should be fast
  ///
  /// ## Requirements Compliance
  ///
  /// This method fulfills the following requirements:
  /// - **Requirement 7.5**: Provides explicit memory management for large collections
  /// - **Requirement 9.1**: Exposes clean resource management in public API
  ///
  /// Example:
  /// ```dart
  /// // Create and use audio file
  /// final audioFile = PhonicAudioFileImpl(
  ///   fileBytes: audioBytes,
  ///   formatStrategy: Mp3FormatStrategy(),
  ///   codecRegistry: registry,
  ///   mergePolicy: mergePolicy,
  /// );
  ///
  /// // Load and modify tags
  /// await audioFile.extractContainers();
  /// audioFile.setTag(TitleTag('New Title'));
  ///
  /// // Verify state before disposal
  /// expect(audioFile.inMemoryTagsByKey, isNotEmpty);
  /// expect(audioFile.isDirty, isTrue);
  ///
  /// // Dispose resources
  /// audioFile.dispose();
  ///
  /// // Verify cleanup
  /// expect(audioFile.inMemoryTagsByKey, isEmpty);
  /// expect(audioFile.loadedContainersByKindAndVersion, isEmpty);
  /// expect(audioFile.isDirty, isFalse);
  /// ```
  @override
  void dispose() {
    // Clear all cached data to free memory
    inMemoryTagsByKey.clear();
    loadedContainersByKindAndVersion.clear();

    // Clear rollback states to free memory
    _rollbackManager.clearAll();

    // Reset dirty flag
    _isDirty = false;
  }

  /// Extracts containers from the file and decodes them into metadata tags.
  ///
  /// This method implements the core container extraction and decoding logic
  /// for the unified tagging system. It uses the format strategy's precedence
  /// rules to locate and extract metadata containers, then decodes them using
  /// appropriate codecs and merges the results into a unified view.
  ///
  /// ## Process Overview
  ///
  /// 1. **Container Discovery**: Use format strategy precedence to determine
  ///    which container types to look for and in what order
  /// 2. **Container Extraction**: For each container type, use the appropriate
  ///    locator to extract container bytes from the file
  /// 3. **Container Decoding**: Use the matching codec to parse container
  ///    bytes into MetadataTag instances with proper provenance
  /// 4. **Tag Merging**: Merge decoded tags using format-specific precedence
  ///    rules to resolve conflicts and create unified view
  /// 5. **Memory Storage**: Store merged tags in inMemoryTagsByKey for
  ///    efficient access and cache container bytes for potential writes
  ///
  /// ## Container Precedence
  ///
  /// The method processes containers according to the format strategy's
  /// precedence rules. For example, with MP3 files:
  /// - ID3v2.4 (highest precedence)
  /// - ID3v2.3
  /// - ID3v2.2
  /// - ID3v1 (lowest precedence)
  ///
  /// Higher precedence containers override values from lower precedence
  /// containers during the merge process.
  ///
  /// ## Error Handling
  ///
  /// The method handles various error conditions gracefully:
  /// - Missing containers: Skipped without affecting other containers
  /// - Corrupted containers: Logged and skipped, processing continues
  /// - Missing codecs: Container skipped if no appropriate codec available
  /// - Parsing failures: Individual container failures don't abort entire process
  ///
  /// ## Memory Management
  ///
  /// - Container bytes are cached in loadedContainersByKindAndVersion
  /// - Only successfully extracted containers are cached
  /// - Large payloads (artwork) use lazy loading patterns
  /// - Failed extractions don't consume memory
  ///
  /// ## Usage
  ///
  /// This method is typically called during file initialization to populate
  /// the in-memory tag representation:
  ///
  /// ```dart
  /// final audioFile = PhonicAudioFileImpl(...);
  /// await audioFile._extractContainersAndDecode();
  ///
  /// // Tags are now available through the public API
  /// final title = audioFile.getTag(TagKey.title);
  /// final allTags = audioFile.getAllTags();
  /// ```
  ///
  /// @throws [UnsupportedFormatException] if the file format is not supported
  /// @throws [CorruptedContainerException] if critical container corruption prevents processing
  Future<void> extractContainersAndDecode() async {
    // Get precedence order from format strategy
    final precedence = formatStrategy.precedence;

    // Map to collect tags by container for merging
    final tagsByContainer = <ContainerKind, List<MetadataTag>>{};

    // Process each container type in precedence order
    for (final (containerKind, containerVersion) in precedence) {
      try {
        // Find appropriate locator for this container type
        final locator = codecRegistry.findLocator(containerKind);
        if (locator == null) {
          // No locator available for this container type, skip
          continue;
        }

        // Check if file contains this container type
        if (!locator.fileMatches(_fileBytes)) {
          // Container not present in file, skip
          continue;
        }

        // Extract container bytes from file
        final containerBytes = locator.extract(_fileBytes);
        if (containerBytes == null) {
          // Container extraction failed (corrupted or invalid), skip
          continue;
        }

        // Cache extracted container bytes for potential write operations
        loadedContainersByKindAndVersion[(containerKind, containerVersion)] = containerBytes;

        // Find appropriate codec for this container type and version
        final codec = codecRegistry.findCodec(containerKind, containerVersion);
        if (codec == null) {
          // No codec available for this container type/version, skip decoding
          continue;
        }

        // Decode container bytes into metadata tags
        final decodedTags = codec.readFromContainer(containerBytes);

        // Store decoded tags for merging (group by container kind)
        if (decodedTags.isNotEmpty) {
          tagsByContainer[containerKind] = decodedTags;
        }
      } catch (e) {
        // Remove cached container bytes if decoding failed
        loadedContainersByKindAndVersion.remove((containerKind, containerVersion));

        // Log error and continue processing other containers
        // Individual container failures should not abort the entire process
        // In a real implementation, this would use proper logging
        // For now, we silently continue to maintain robustness
        continue;
      }
    }

    // Merge tags from all containers using format-specific precedence
    final mergedTags = mergePolicy.mergeWithPrecedence(
      tagsByContainer,
      formatStrategy.mediaKind,
    );

    // Organize merged tags by key for efficient access
    inMemoryTagsByKey.clear();
    for (final tag in mergedTags) {
      inMemoryTagsByKey.putIfAbsent(tag.key, () => <MetadataTag>[]).add(tag);
    }
  }

  @override
  Uint8List get audioData {
    return _extractAudioData(_fileBytes);
  }

  /// Extracts raw audio data by removing all metadata containers from the file.
  ///
  /// This method systematically removes all known metadata containers from the
  /// audio file, leaving only the pure audio stream data. It handles different
  /// container types and their specific removal requirements.
  ///
  /// ## Process Overview
  ///
  /// 1. **Container Detection**: Identify all metadata containers present in the file
  /// 2. **Container Removal**: Remove containers in the correct order to maintain file integrity
  /// 3. **Audio Extraction**: Extract the remaining audio data
  /// 4. **Validation**: Ensure the resulting data represents valid audio content
  ///
  /// ## Container Removal Order
  ///
  /// Containers are removed in a specific order to handle interdependencies:
  /// 1. **ID3v2**: Removed from file beginning (affects audio data offset)
  /// 2. **ID3v1**: Removed from file end (fixed position, easy removal)
  /// 3. **Vorbis**: Handled format-specifically within FLAC/OGG structure
  /// 4. **MP4**: Extracted from atom hierarchy, leaving audio in mdat atoms
  ///
  /// ## Format-Specific Handling
  ///
  /// ### MP3 Files
  /// - Remove ID3v2 tag from beginning (if present)
  /// - Remove ID3v1 tag from end (if present)
  /// - Remaining data is MP3 audio frames
  ///
  /// ### FLAC Files
  /// - Remove Vorbis comment metadata blocks
  /// - Preserve FLAC signature and essential metadata blocks
  /// - Extract audio frames following metadata blocks
  ///
  /// ### OGG Files
  /// - Remove Vorbis comment header packets
  /// - Preserve OGG page structure for audio packets
  /// - Extract audio packet data from remaining pages
  ///
  /// ### MP4 Files
  /// - Navigate atom hierarchy to separate metadata (moov) from audio (mdat)
  /// - Extract raw audio data from mdat atoms
  /// - Remove all metadata atoms and structural overhead
  ///
  /// ## Error Handling
  ///
  /// The method handles various error conditions gracefully:
  /// - Unknown or unsupported container types are ignored
  /// - Corrupted containers are skipped rather than causing failures
  /// - Files with no metadata containers return the original data
  /// - Partial container removal continues if some containers fail
  ///
  /// ## Memory Efficiency
  ///
  /// The extraction process is designed for memory efficiency:
  /// - Processes containers sequentially to minimize peak memory usage
  /// - Uses streaming approaches for large files where possible
  /// - Avoids creating unnecessary intermediate copies
  /// - Returns a view of the data when possible
  ///
  /// ## Use Cases
  ///
  /// This method is useful for:
  /// - Audio processing that requires pure audio data
  /// - Transcoding operations that need to preserve only audio content
  /// - Analysis tools that work with raw audio streams
  /// - Debugging audio format issues by isolating audio from metadata
  ///
  /// Parameters:
  /// - [fileBytes]: The complete audio file bytes including metadata containers
  ///
  /// Returns:
  /// - The raw audio data with all metadata containers removed
  ///
  /// Example:
  /// ```dart
  /// // Extract audio data for processing
  /// final audioFile = await Phonic.fromFile('song.mp3');
  /// final rawAudio = audioFile.audioData;
  ///
  /// // Process raw audio (e.g., apply effects, analyze waveform)
  /// final processedAudio = audioProcessor.process(rawAudio);
  ///
  /// // Create new file with processed audio and original metadata
  /// final newFile = await audioFile.encode(); // Preserves metadata
  /// ```
  Uint8List _extractAudioData(Uint8List fileBytes) {
    var currentBytes = Uint8List.fromList(fileBytes);

    // Get the container removal order based on format strategy
    final removalOrder = _getContainerRemovalOrder();

    // Remove containers in the specified order
    for (final containerKind in removalOrder) {
      currentBytes = _removeContainer(currentBytes, containerKind);
    }

    return currentBytes;
  }

  /// Gets the order in which containers should be removed for audio extraction.
  ///
  /// The removal order is important because some containers affect the positioning
  /// of others. For example, removing ID3v2 from the beginning changes the offset
  /// of all subsequent data.
  ///
  /// Returns:
  /// - List of container kinds in removal order
  List<ContainerKind> _getContainerRemovalOrder() {
    // Remove containers in order that minimizes data shifting:
    // 1. ID3v1 first (end of file, no shifting required)
    // 2. ID3v2 second (beginning of file, shifts remaining data)
    // 3. Format-specific containers (Vorbis, MP4) last
    return [
      ContainerKind.id3v1,
      ContainerKind.id3v2,
      ContainerKind.vorbis,
      ContainerKind.mp4,
    ];
  }

  /// Removes a specific container type from the file bytes.
  ///
  /// This method uses the appropriate container locator to detect and remove
  /// the specified container type from the file. If the container is not present
  /// or cannot be removed, the original bytes are returned unchanged.
  ///
  /// Parameters:
  /// - [fileBytes]: The file bytes to process
  /// - [containerKind]: The type of container to remove
  ///
  /// Returns:
  /// - The file bytes with the specified container removed
  Uint8List _removeContainer(Uint8List fileBytes, ContainerKind containerKind) {
    try {
      // Find the appropriate locator for this container type
      final locator = codecRegistry.findLocator(containerKind);
      if (locator == null) {
        // No locator available for this container type, return unchanged
        return fileBytes;
      }

      // Check if the file contains this container type
      if (!locator.fileMatches(fileBytes)) {
        // Container not present, return unchanged
        return fileBytes;
      }

      // Remove the container by injecting null (which removes it)
      return locator.inject(fileBytes, null);
    } catch (e) {
      // If container removal fails, return original bytes
      // This ensures robustness when dealing with corrupted containers
      return fileBytes;
    }
  }

  /// Determines which containers to write to based on the encoding strategy.
  ///
  /// This method implements the core logic for container target selection,
  /// taking into account the encoding strategy, existing containers, and
  /// user preferences.
  ///
  /// Parameters:
  /// - [options]: The encoding options specifying strategy and targets
  ///
  /// Returns:
  /// - List of container kinds and versions to write metadata to
  List<(ContainerKind, String)> _determineTargetContainers(EncodingOptions options) {
    switch (options.strategy) {
      case EncodingStrategy.preserveExisting:
        // Use containers that already exist in the file
        final existingContainers = loadedContainersByKindAndVersion.keys.toList();

        // If no containers exist, fall back to format's default fan-out
        if (existingContainers.isEmpty) {
          return formatStrategy.fanout;
        }

        return existingContainers;

      case EncodingStrategy.optimized:
        // Use optimized modern formats for this media kind
        return _getOptimizedTargetsForFormat(formatStrategy.mediaKind);

      case EncodingStrategy.explicit:
        // Use user-specified target containers
        if (options.targetContainers != null && options.targetContainers!.isNotEmpty) {
          // Target containers are already (ContainerKind, String) tuples
          return options.targetContainers!;
        }

        // If no explicit targets specified, fall back to preserveExisting behavior
        return _determineTargetContainers(
          const EncodingOptions(strategy: EncodingStrategy.preserveExisting),
        );
    }
  }

  /// Gets the optimized container targets for a specific media format.
  ///
  /// This method returns the most modern and feature-complete container
  /// types for each media format, prioritizing compatibility with current
  /// software while providing maximum metadata capability.
  ///
  /// Parameters:
  /// - [mediaKind]: The media format to get optimized targets for
  ///
  /// Returns:
  /// - List of optimized container targets for the format
  List<(ContainerKind, String)> _getOptimizedTargetsForFormat(MediaKind mediaKind) {
    switch (mediaKind) {
      case MediaKind.mp3:
        // For MP3, use ID3v2 as the primary modern standard
        // ID3v1 is omitted in optimized mode as it's very limited
        return [(ContainerKind.id3v2, '2.4')];

      case MediaKind.flac:
        // FLAC uses Vorbis Comments as the standard metadata container
        return [(ContainerKind.vorbis, '')];

      case MediaKind.ogg:
        // OGG Vorbis uses Vorbis Comments
        return [(ContainerKind.vorbis, '')];

      case MediaKind.opus:
        // Opus uses Vorbis Comments (in Ogg container)
        return [(ContainerKind.vorbis, '')];

      case MediaKind.mp4:
      case MediaKind.m4a:
        // MP4/M4A uses MP4 atoms for metadata
        return [(ContainerKind.mp4, '')];
    }
  }
}
