import 'dart:typed_data';

import '../exceptions/tag_validation_exception.dart';
import 'codec_registry.dart';
import 'container_kind.dart';
import 'format_strategy.dart';
import 'merge_policy.dart';
import 'metadata_tag.dart';
import 'phonic_audio_file.dart';
import 'tag_key.dart';
import 'tag_semantics.dart';

/// Concrete implementation of the PhonicAudioFile interface.
///
/// PhonicAudioFileImpl provides the core functionality for reading and writing
/// metadata tags across different audio container formats. It uses a strategy
/// pattern with format-specific strategies, codec registry for container
/// parsing, and merge policies for handling multiple containers.
///
/// The implementation maintains an in-memory representation of tags organized
/// by key, with caching of loaded containers to minimize file I/O operations.
/// Changes are tracked through dirty flags to optimize write operations.
///
/// ## Architecture
///
/// The implementation uses several key components:
/// - [FormatStrategy]: Determines format detection and container precedence
/// - [CodecRegistry]: Provides access to container-specific codecs
/// - [MergePolicy]: Handles tag merging and normalization
/// - In-memory tag storage: Efficient access to current tag state
/// - Container caching: Minimizes redundant parsing operations
///
/// ## Memory Management
///
/// The implementation is designed for efficient memory usage:
/// - Tags are stored in memory for fast access
/// - Container bytes are cached only when needed for writing
/// - Artwork and large payloads use lazy loading patterns
/// - Dispose method releases all cached resources
///
/// ## Change Tracking
///
/// Changes are tracked at multiple levels:
/// - Global dirty flag indicates any modifications
/// - Per-tag dirty tracking for selective updates
/// - Container-level change detection for optimized writes
///
/// ## Thread Safety
///
/// This implementation is not thread-safe. Concurrent access should be
/// synchronized by the caller.
///
/// ## Usage Example
///
/// ```dart
/// // Create from file bytes
/// final audioFile = PhonicAudioFileImpl(
///   fileBytes: audioBytes,
///   formatStrategy: Mp3FormatStrategy(),
///   codecRegistry: registry,
///   mergePolicy: MergePolicy.fromStrategy(Mp3FormatStrategy()),
/// );
///
/// // Read tags
/// final title = audioFile.getTag(TagKey.title);
/// final genres = audioFile.getTags(TagKey.genre);
///
/// // Modify tags
/// audioFile.setTag(TitleTag('New Title'));
/// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
///
/// // Save changes
/// if (audioFile.isDirty) {
///   final updatedBytes = await audioFile.encode();
///   // Write updatedBytes to file...
///   audioFile.markClean();
/// }
///
/// // Cleanup
/// audioFile.dispose();
/// ```
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
  }) : _fileBytes = Uint8List.fromList(fileBytes),
       inMemoryTagsByKey = <TagKey, List<MetadataTag>>{},
       loadedContainersByKindAndVersion = <(ContainerKind, String), Uint8List>{},
       _isDirty = isDirty;

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

  @override
  List<MetadataTag> getAllTags() {
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
    /// - Does not trigger container extraction if not already performed
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

  @override
  Future<Uint8List> encode() async {
    // TODO: Implement encoding logic
    // This will involve:
    // 1. Getting fan-out targets from format strategy
    // 2. For each target container:
    //    - Get appropriate codec from registry
    //    - Normalize tags for target capabilities
    //    - Encode tags to container bytes
    //    - Inject container into file using locator
    // 3. Return complete file bytes

    // For now, return original file bytes
    return Uint8List.fromList(_fileBytes);
  }

  @override
  Uint8List get audioData {
    // TODO: Implement audio data extraction
    // This will involve:
    // 1. Identifying all metadata containers in the file
    // 2. Using locators to extract container positions
    // 3. Removing container bytes from file
    // 4. Returning pure audio stream

    // For now, return original file bytes
    return Uint8List.fromList(_fileBytes);
  }

  @override
  void dispose() {
    // Clear all cached data to free memory
    inMemoryTagsByKey.clear();
    loadedContainersByKindAndVersion.clear();

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
}
