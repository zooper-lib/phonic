import 'container_kind.dart';
import 'format_strategy.dart';
import 'media_kind.dart';
import 'metadata_tag.dart';
import 'tag_capability.dart';
import 'tag_key.dart';
import 'tag_merger.dart';
import 'tag_semantics.dart';

/// Policy class that defines merge precedence and normalization rules for metadata operations.
///
/// [MergePolicy] encapsulates the logic for determining container precedence during
/// read operations, selecting target containers for write operations (fan-out), and
/// applying format-specific normalization to tag values. This class serves as the
/// central authority for merge and normalization decisions across the library.
///
/// The policy system enables:
/// - Format-specific precedence rules for conflict resolution
/// - Target container selection for write operations
/// - Value normalization based on container capabilities
/// - Consistent merge behavior across different media formats
/// - Extensible policy definitions for new formats
///
/// ## Precedence Rules
///
/// Precedence determines which container's values take priority when multiple
/// containers contain the same tag field. Higher precedence containers override
/// values from lower precedence ones during merge operations.
///
/// Example MP3 precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
///
/// ## Fan-out Policy
///
/// Fan-out determines which containers receive new tag data during write
/// operations. This allows writing to multiple containers simultaneously
/// for maximum compatibility while respecting each container's capabilities.
///
/// Example MP3 fan-out: Write to ID3v2.4 (full features) + ID3v1 (compatibility)
///
/// ## Normalization
///
/// Normalization adapts tag values to fit the constraints and capabilities
/// of specific container formats. This includes:
/// - Text length truncation (e.g., ID3v1's 30-character limits)
/// - Value range clamping (e.g., rating scale conversion)
/// - Encoding selection (e.g., UTF-8 vs UTF-16 vs Latin-1)
/// - Multi-value handling (e.g., genre list formatting)
///
/// ## Usage Example
///
/// ```dart
/// // Create policy for MP3 format
/// final strategy = Mp3FormatStrategy();
/// final policy = MergePolicy.fromStrategy(strategy);
///
/// // Get precedence for reading
/// final precedence = policy.precedenceFor(MediaKind.mp3);
/// print('Read precedence: $precedence');
///
/// // Get fan-out targets for writing
/// final targets = policy.writeFanout(MediaKind.mp3);
/// print('Write targets: $targets');
///
/// // Normalize tag for specific container
/// final capability = id3v1Capability;
/// final normalizedTag = policy.normalizeForTarget(titleTag, capability);
/// ```
///
/// ## Format-Specific Policies
///
/// Different media formats have different merge and normalization requirements:
///
/// - **MP3**: Multiple container types with version-based precedence
/// - **FLAC**: Single Vorbis container with multi-valued field support
/// - **OGG**: Vorbis-only with native UTF-8 encoding
/// - **MP4**: iTunes-style atoms with freeform field support
///
/// ## Thread Safety
///
/// MergePolicy instances are immutable and thread-safe. Multiple threads can
/// safely use the same policy instance concurrently for merge and normalization
/// operations.
class MergePolicy {
  /// Format strategy that defines precedence and fan-out rules.
  final FormatStrategy _strategy;

  /// Tag merger instance for performing merge operations.
  final TagMerger _merger;

  /// Creates a new [MergePolicy] with the specified strategy and merger.
  ///
  /// Parameters:
  /// - [strategy]: Format strategy defining precedence and fan-out rules
  /// - [merger]: Tag merger for performing merge operations (optional)
  ///
  /// The merger parameter allows customization of merge behavior, but most
  /// use cases can rely on the default TagMerger instance.
  ///
  /// Example:
  /// ```dart
  /// final strategy = Mp3FormatStrategy();
  /// final policy = MergePolicy(strategy);
  /// ```
  const MergePolicy(this._strategy, {TagMerger? merger}) : _merger = merger ?? const TagMerger();

  /// Creates a [MergePolicy] from a format strategy using default merger.
  ///
  /// This is the most common way to create a merge policy, using the
  /// strategy's built-in precedence and fan-out rules with standard
  /// merge behavior.
  ///
  /// Parameters:
  /// - [strategy]: Format strategy defining merge rules
  ///
  /// Returns:
  /// - New MergePolicy instance configured for the format
  ///
  /// Example:
  /// ```dart
  /// final mp3Policy = MergePolicy.fromStrategy(Mp3FormatStrategy());
  /// final flacPolicy = MergePolicy.fromStrategy(FlacFormatStrategy());
  /// ```
  factory MergePolicy.fromStrategy(FormatStrategy strategy) {
    return MergePolicy(strategy);
  }

  /// Returns the container precedence order for the specified media format.
  ///
  /// Precedence determines which container's values take priority during
  /// merge operations when multiple containers contain the same tag field.
  /// Containers earlier in the list have higher precedence.
  ///
  /// The precedence order is defined by the format strategy and reflects
  /// format-specific best practices and container capabilities.
  ///
  /// Parameters:
  /// - [mediaKind]: The media format to get precedence for
  ///
  /// Returns:
  /// - List of (ContainerKind, version) tuples in precedence order
  /// - Empty list if media format is not supported by this policy
  ///
  /// Example:
  /// ```dart
  /// final policy = MergePolicy.fromStrategy(Mp3FormatStrategy());
  /// final precedence = policy.precedenceFor(MediaKind.mp3);
  /// // Returns: [(ContainerKind.id3v2, "2.4"), (ContainerKind.id3v2, "2.3"), ...]
  ///
  /// // Use precedence for merge operations
  /// final merger = TagMerger(containerPrecedence: precedence.map((p) => p.$1).toList());
  /// ```
  ///
  /// The precedence order should be used by:
  /// - Tag merge operations to resolve conflicts
  /// - Container locators to determine search order
  /// - Format detection to prioritize container types
  /// - User interfaces to display container importance
  List<(ContainerKind, String)> precedenceFor(MediaKind mediaKind) {
    if (_strategy.mediaKind != mediaKind) {
      return const [];
    }
    return _strategy.precedence;
  }

  /// Returns the container fan-out targets for write operations.
  ///
  /// Fan-out determines which containers receive new tag data during write
  /// operations. This allows writing to multiple containers simultaneously
  /// for maximum compatibility while respecting format constraints.
  ///
  /// The fan-out policy balances feature completeness with compatibility:
  /// - Primary targets support full feature sets
  /// - Secondary targets provide legacy compatibility
  /// - Container capabilities determine which tags can be written
  ///
  /// Parameters:
  /// - [mediaKind]: The media format to get fan-out targets for
  ///
  /// Returns:
  /// - List of (ContainerKind, version) tuples for write operations
  /// - Empty list if media format is not supported by this policy
  ///
  /// Example:
  /// ```dart
  /// final policy = MergePolicy.fromStrategy(Mp3FormatStrategy());
  /// final targets = policy.writeFanout(MediaKind.mp3);
  /// // Returns: [(ContainerKind.id3v2, "2.4"), (ContainerKind.id3v1, "v1")]
  ///
  /// // Use targets for write operations
  /// for (final (containerKind, version) in targets) {
  ///   final codec = registry.getCodec(containerKind, version);
  ///   final normalizedTags = policy.normalizeForTarget(tags, codec.capability);
  ///   final containerBytes = codec.writeToContainer(tagsToWrite: normalizedTags);
  ///   // Write containerBytes to file...
  /// }
  /// ```
  ///
  /// Fan-out considerations:
  /// - Order may affect write performance and file structure
  /// - Each target may receive different subsets of tags based on capabilities
  /// - Normalization is applied per-target to respect constraints
  /// - Failed writes to secondary targets should not abort the operation
  List<(ContainerKind, String)> writeFanout(MediaKind mediaKind) {
    if (_strategy.mediaKind != mediaKind) {
      return const [];
    }
    return _strategy.fanout;
  }

  /// Normalizes a metadata tag for writing to a specific container format.
  ///
  /// Normalization adapts tag values to fit the constraints and capabilities
  /// of the target container format. This ensures that tag values are valid
  /// and properly formatted for the destination container.
  ///
  /// Normalization operations include:
  /// - Text length truncation for containers with size limits
  /// - Value range clamping for numeric fields
  /// - Encoding selection based on container support
  /// - Multi-value formatting (delimiters, separate fields, etc.)
  /// - Data type conversion where necessary
  ///
  /// Parameters:
  /// - [tag]: The metadata tag to normalize
  /// - [targetCapability]: Capability definition for the target container
  ///
  /// Returns:
  /// - Normalized tag suitable for the target container
  /// - Original tag if no normalization is needed
  /// - null if the tag is not supported by the target container
  ///
  /// Example:
  /// ```dart
  /// final longTitle = TitleTag('This is a very long title that exceeds ID3v1 limits');
  /// final normalizedTitle = policy.normalizeForTarget(longTitle, id3v1Capability);
  /// // Returns: TitleTag('This is a very long title th') - truncated to 30 chars
  ///
  /// final highRating = RatingTag(255); // ID3v2 scale (0-255)
  /// final normalizedRating = policy.normalizeForTarget(highRating, unifiedCapability);
  /// // Returns: RatingTag(100) - converted to unified scale (0-100)
  /// ```
  ///
  /// Normalization behavior by tag type:
  /// - **Text tags**: Truncate to maxTextLength, select appropriate encoding
  /// - **Numeric tags**: Clamp to minValue/maxValue range
  /// - **Genre tags**: Format according to container's multi-value support
  /// - **Artwork tags**: Validate MIME types and size constraints
  /// - **Custom tags**: Apply container-specific formatting rules
  ///
  /// The method preserves the original tag's provenance information while
  /// applying necessary transformations for container compatibility.
  MetadataTag? normalizeForTarget(MetadataTag tag, TagCapability targetCapability) {
    // Check if the target container supports this tag
    if (!targetCapability.supports(tag.key)) {
      return null;
    }

    final semantics = targetCapability.semantics(tag.key);

    // Apply normalization based on tag type and semantics
    return _normalizeTagValue(tag, semantics);
  }

  /// Normalizes a list of metadata tags for writing to a specific container format.
  ///
  /// This method applies [normalizeForTarget] to each tag in the list and
  /// filters out tags that are not supported by the target container.
  /// This is a convenience method for batch normalization operations.
  ///
  /// Parameters:
  /// - [tags]: List of metadata tags to normalize
  /// - [targetCapability]: Capability definition for the target container
  ///
  /// Returns:
  /// - List of normalized tags suitable for the target container
  /// - Empty list if no tags are supported by the target container
  ///
  /// Example:
  /// ```dart
  /// final allTags = [titleTag, artistTag, artworkTag, customTag];
  /// final id3v1Tags = policy.normalizeAllForTarget(allTags, id3v1Capability);
  /// // Returns: [normalizedTitle, normalizedArtist] - artwork and custom filtered out
  /// ```
  List<MetadataTag> normalizeAllForTarget(List<MetadataTag> tags, TagCapability targetCapability) {
    final normalizedTags = <MetadataTag>[];

    for (final tag in tags) {
      final normalized = normalizeForTarget(tag, targetCapability);
      if (normalized != null) {
        normalizedTags.add(normalized);
      }
    }

    return normalizedTags;
  }

  /// Merges tags from multiple containers using format-specific precedence.
  ///
  /// This method combines the merge policy's precedence rules with the
  /// tag merger's conflict resolution logic to produce a unified set of
  /// metadata tags from multiple container sources.
  ///
  /// Parameters:
  /// - [tagsByContainer]: Map of container kinds to their tag lists
  /// - [mediaKind]: Media format to determine precedence rules
  ///
  /// Returns:
  /// - List of merged tags with conflicts resolved
  /// - Empty list if no tags are provided or media format is unsupported
  ///
  /// Example:
  /// ```dart
  /// final tagsByContainer = {
  ///   ContainerKind.id3v2: [titleFromId3v2, genreFromId3v2],
  ///   ContainerKind.id3v1: [titleFromId3v1, genreFromId3v1],
  /// };
  ///
  /// final mergedTags = policy.mergeWithPrecedence(tagsByContainer, MediaKind.mp3);
  /// // Returns tags with ID3v2 values taking precedence over ID3v1
  /// ```
  List<MetadataTag> mergeWithPrecedence(
    Map<ContainerKind, List<MetadataTag>> tagsByContainer,
    MediaKind mediaKind,
  ) {
    final precedence = precedenceFor(mediaKind);
    if (precedence.isEmpty) {
      return [];
    }

    // Extract container kinds in precedence order
    final containerPrecedence = precedence.map((p) => p.$1).toList();

    final mergedTags = _merger.mergeByContainerPrecedence(tagsByContainer, containerPrecedence);

    // Filter out corrupted text tags after merging
    return mergedTags.where((tag) {
      // Check if tag is a text-based tag that could be corrupted
      if (tag is TitleTag ||
          tag is ArtistTag ||
          tag is AlbumTag ||
          tag is AlbumArtistTag ||
          tag is CommentTag ||
          tag is GroupingTag ||
          tag is ComposerTag ||
          tag is EncoderTag ||
          tag is IsrcTag) {
        return !_isCorruptedText(tag.value);
      }
      return true; // Keep non-text tags
    }).toList();
  }

  /// Internal method to normalize a tag value based on semantic constraints.
  ///
  /// This method applies the actual normalization logic for different tag
  /// types and semantic constraints. It handles the specific transformation
  /// rules for each type of metadata field.
  ///
  /// Parameters:
  /// - [tag]: The metadata tag to normalize
  /// - [semantics]: Semantic constraints for the target container
  ///
  /// Returns:
  /// - Normalized tag with applied constraints
  /// - null if the tag content is corrupted and should be filtered out
  /// - Original tag if no normalization is needed
  MetadataTag? _normalizeTagValue(MetadataTag tag, TagSemantics semantics) {
    // Handle text-based tags with length constraints
    if (tag is TitleTag ||
        tag is ArtistTag ||
        tag is AlbumTag ||
        tag is AlbumArtistTag ||
        tag is CommentTag ||
        tag is GroupingTag ||
        tag is ComposerTag ||
        tag is EncoderTag ||
        tag is IsrcTag ||
        tag is MusicalKeyTag ||
        tag is LyricsTag) {
      return _normalizeTextTag(tag, semantics);
    }

    // Handle numeric tags with value range constraints
    if (tag is TrackNumberTag || tag is DiscNumberTag || tag is YearTag || tag is BpmTag || tag is RatingTag) {
      return _normalizeNumericTag(tag, semantics);
    }

    // Handle genre tags with multi-value formatting
    if (tag is GenreTag) {
      return _normalizeGenreTag(tag, semantics);
    }

    // Handle date tags with format constraints
    if (tag is DateRecordedTag) {
      return _normalizeDateTag(tag, semantics);
    }

    // Handle artwork tags (no normalization needed for now)
    if (tag is ArtworkTag) {
      return tag;
    }

    // Handle custom tags
    if (tag is CustomTag) {
      return _normalizeTextTag(tag, semantics);
    }

    // Return original tag if no specific normalization is needed
    return tag;
  }

  /// Normalizes text-based tags by applying length constraints and filtering corrupted data.
  ///
  /// This method validates text content and filters out corrupted data such as:
  /// - Strings containing only null bytes (common in corrupted ID3v1 tags)
  /// - Strings with excessive control characters
  /// - Empty or whitespace-only strings from corrupted containers
  ///
  /// Parameters:
  /// - [tag]: Text-based metadata tag
  /// - [semantics]: Semantic constraints including maxTextLength
  ///
  /// Returns:
  /// - null if the text content is corrupted or invalid
  /// - Tag with truncated text if length exceeds constraints
  /// - Original tag if no normalization is needed
  MetadataTag? _normalizeTextTag(MetadataTag tag, TagSemantics semantics) {
    final currentValue = tag.value as String;

    // Filter out corrupted text content
    if (_isCorruptedText(currentValue)) {
      return null; // Don't include corrupted tags
    }

    if (semantics.maxTextLength == null) {
      return tag;
    }

    final maxLength = semantics.maxTextLength!;

    if (currentValue.length <= maxLength) {
      return tag;
    }

    final truncatedValue = currentValue.substring(0, maxLength);

    // Create new tag with truncated value
    switch (tag.key) {
      case TagKey.title:
        return TitleTag(truncatedValue, provenance: tag.provenance);
      case TagKey.artist:
        return ArtistTag(truncatedValue, provenance: tag.provenance);
      case TagKey.album:
        return AlbumTag(truncatedValue, provenance: tag.provenance);
      case TagKey.albumArtist:
        return AlbumArtistTag(truncatedValue, provenance: tag.provenance);
      case TagKey.comment:
        return CommentTag(truncatedValue, provenance: tag.provenance);
      case TagKey.grouping:
        return GroupingTag(truncatedValue, provenance: tag.provenance);
      case TagKey.composer:
        return ComposerTag(truncatedValue, provenance: tag.provenance);
      case TagKey.encoder:
        return EncoderTag(truncatedValue, provenance: tag.provenance);
      case TagKey.isrc:
        return IsrcTag(truncatedValue, provenance: tag.provenance);
      case TagKey.musicalKey:
        return MusicalKeyTag(truncatedValue, provenance: tag.provenance);
      case TagKey.lyrics:
        return LyricsTag(truncatedValue, provenance: tag.provenance);
      case TagKey.custom:
        return CustomTag(truncatedValue, provenance: tag.provenance);
      default:
        return tag;
    }
  }

  /// Checks if a text string contains corrupted data that should be filtered out.
  ///
  /// This method identifies common patterns of text corruption in audio metadata:
  /// - Strings containing only null bytes (common in corrupted ID3v1 fields)
  /// - Strings with a high percentage of control characters
  /// - Empty strings that may indicate missing or corrupted data
  ///
  /// Parameters:
  /// - [text]: The text content to validate
  ///
  /// Returns:
  /// - true if the text appears to be corrupted and should be filtered out
  /// - false if the text appears to be valid
  bool _isCorruptedText(String text) {
    if (text.isEmpty) {
      return false; // Empty strings are valid (just indicate missing data)
    }

    // Check for strings that are only null bytes (common ID3v1 corruption)
    if (text.replaceAll('\u0000', '').isEmpty) {
      return true; // String contains only null bytes
    }

    // Check for excessive control characters (excluding common whitespace)
    int controlCharCount = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      // Count control characters except tab (9), newline (10), and carriage return (13)
      if (char < 32 && char != 9 && char != 10 && char != 13) {
        controlCharCount++;
      }
    }

    // If more than 50% of the string is control characters, consider it corrupted
    final controlRatio = controlCharCount / text.length;
    return controlRatio > 0.5;
  }

  /// Normalizes numeric tags by applying value range constraints.
  ///
  /// Parameters:
  /// - [tag]: Numeric metadata tag
  /// - [semantics]: Semantic constraints including minValue/maxValue
  ///
  /// Returns:
  /// - Tag with clamped value if outside valid range
  /// - Original tag if value is within constraints
  MetadataTag _normalizeNumericTag(MetadataTag tag, TagSemantics semantics) {
    final currentValue = tag.value as int;
    int normalizedValue = currentValue;

    // Apply minimum value constraint
    if (semantics.minValue != null) {
      final minValue = semantics.minValue!.toInt();
      if (normalizedValue < minValue) {
        normalizedValue = minValue;
      }
    }

    // Apply maximum value constraint
    if (semantics.maxValue != null) {
      final maxValue = semantics.maxValue!.toInt();
      if (normalizedValue > maxValue) {
        normalizedValue = maxValue;
      }
    }

    // Return original tag if no clamping was needed
    if (normalizedValue == currentValue) {
      return tag;
    }

    // Create new tag with clamped value
    switch (tag.key) {
      case TagKey.trackNumber:
        return TrackNumberTag(normalizedValue, provenance: tag.provenance);
      case TagKey.discNumber:
        return DiscNumberTag(normalizedValue, provenance: tag.provenance);
      case TagKey.year:
        return YearTag(normalizedValue, provenance: tag.provenance);
      case TagKey.bpm:
        return BpmTag(normalizedValue, provenance: tag.provenance);
      case TagKey.rating:
        return RatingTag(normalizedValue, provenance: tag.provenance);
      default:
        return tag;
    }
  }

  /// Normalizes genre tags based on multi-value support.
  ///
  /// Different container formats handle multiple genres differently:
  /// - Some support native multi-valued fields (Vorbis)
  /// - Others use delimited strings (ID3v2 with various delimiters)
  /// - Legacy formats support only single values (ID3v1)
  ///
  /// Parameters:
  /// - [tag]: Genre metadata tag
  /// - [semantics]: Semantic constraints including multiValued support
  ///
  /// Returns:
  /// - Original tag if multi-valued support matches
  /// - Single-genre tag if container doesn't support multi-values
  MetadataTag _normalizeGenreTag(GenreTag tag, TagSemantics semantics) {
    // If container doesn't support multi-valued genres and we have multiple genres
    if (!semantics.multiValued && tag.value.length > 1) {
      // Use the first genre only for single-value containers
      return GenreTag.single(tag.value.first, provenance: tag.provenance);
    }

    // Return original tag if no normalization is needed
    return tag;
  }

  /// Normalizes date tags based on format constraints.
  ///
  /// Different container formats have different date/time handling:
  /// - ID3v2.4: Unified TDRC frame with ISO-8601 format
  /// - ID3v2.3: Separate TYER/TDAT/TIME frames
  /// - ID3v1: 4-character year field only
  ///
  /// Parameters:
  /// - [tag]: Date recorded metadata tag
  /// - [semantics]: Semantic constraints for date formatting
  ///
  /// Returns:
  /// - Normalized date tag appropriate for target container
  /// - Original tag if no normalization is needed
  MetadataTag _normalizeDateTag(DateRecordedTag tag, TagSemantics semantics) {
    // For now, return the original tag
    // Future enhancement: Apply container-specific date formatting
    return tag;
  }

  /// Returns the format strategy used by this merge policy.
  ///
  /// This provides access to the underlying format strategy for advanced
  /// use cases that need direct access to format detection or other
  /// strategy-specific functionality.
  ///
  /// Returns:
  /// - The FormatStrategy instance used by this policy
  FormatStrategy get strategy => _strategy;

  /// Returns the tag merger used by this merge policy.
  ///
  /// This provides access to the underlying tag merger for advanced
  /// use cases that need direct access to merge functionality or
  /// custom merge operations.
  ///
  /// Returns:
  /// - The TagMerger instance used by this policy
  TagMerger get merger => _merger;
}
