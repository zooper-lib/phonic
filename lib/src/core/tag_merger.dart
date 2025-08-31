import 'container_kind.dart';
import 'metadata_tag.dart';
import 'tag_confidence.dart';
import 'tag_key.dart';
import 'tag_provenance.dart';

/// Utilities for merging metadata tags from multiple containers.
///
/// TagMerger provides sophisticated merging logic that handles precedence-based
/// conflict resolution for single-valued tags and union operations for multi-valued
/// tags. The merger preserves provenance information and applies container-specific
/// precedence rules to determine the most authoritative values.
///
/// The merging process considers:
/// - Container precedence (ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1 > Vorbis > MP4)
/// - Confidence levels (certain > inferred > derived)
/// - Multi-valued tag deduplication and union operations
/// - Provenance preservation for audit trails
///
/// Example usage:
/// ```dart
/// // Merge tags from multiple containers
/// final allTags = [
///   TitleTag('Song Title', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
///   TitleTag('Different Title', provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
///   GenreTag(['Rock', 'Alternative'], provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
///   GenreTag(['Alternative', 'Indie'], provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain)),
/// ];
///
/// final merger = TagMerger();
/// final mergedTags = merger.mergeTags(allTags);
///
/// // Result: TitleTag from ID3v2.4 (higher precedence) and GenreTag with ['Rock', 'Alternative', 'Indie']
/// ```
class TagMerger {
  /// Default container precedence order for merge operations.
  ///
  /// This precedence order reflects the general reliability and feature
  /// completeness of different container formats:
  /// - ID3v2.4: Most feature-complete, UTF-8 support, modern standard
  /// - ID3v2.3: Widely supported, good feature set, UTF-16 encoding
  /// - ID3v2.2: Older format, limited features but still common
  /// - Vorbis: Clean design, UTF-8 native, good for lossless formats
  /// - MP4: iTunes-style atoms, good for AAC/M4A files
  /// - ID3v1: Very limited, fixed-length fields, legacy compatibility
  /// - None: Lowest priority, used for synthetic or default values
  static const List<ContainerKind> defaultContainerPrecedence = [
    ContainerKind.id3v2,
    ContainerKind.vorbis,
    ContainerKind.mp4,
    ContainerKind.id3v1,
    ContainerKind.none,
  ];

  /// Version precedence within ID3v2 containers.
  ///
  /// When multiple ID3v2 versions are present, this order determines
  /// which version takes precedence. ID3v2.4 is preferred due to its
  /// UTF-8 support and extended feature set.
  static const Map<String, int> id3v2VersionPrecedence = {
    '2.4': 0,
    '2.3': 1,
    '2.2': 2,
  };

  /// Confidence level precedence for merge operations.
  ///
  /// When tags have the same container precedence, confidence levels
  /// are used as a tiebreaker. Certain values are preferred over
  /// inferred or derived values.
  static const List<TagConfidence> confidencePrecedence = [
    TagConfidence.certain,
    TagConfidence.inferred,
    TagConfidence.derived,
  ];

  /// Container precedence order used by this merger instance.
  final List<ContainerKind> containerPrecedence;

  /// Creates a new TagMerger with the specified container precedence.
  ///
  /// @param containerPrecedence The order of container precedence for merging.
  ///   Defaults to [defaultContainerPrecedence] if not specified.
  const TagMerger({
    this.containerPrecedence = defaultContainerPrecedence,
  });

  /// Merges a list of metadata tags, resolving conflicts based on precedence rules.
  ///
  /// This method groups tags by their key and applies appropriate merging logic:
  /// - Single-valued tags: Uses precedence-based conflict resolution
  /// - Multi-valued tags: Performs union operations with deduplication
  /// - GenreTag: Special handling for combining and deduplicating genre lists
  ///
  /// The merging process preserves provenance information and maintains
  /// the highest-precedence source for each tag value.
  ///
  /// @param tags The list of tags to merge from all containers
  /// @returns A list of merged tags with conflicts resolved
  ///
  /// Example:
  /// ```dart
  /// final tags = [
  ///   TitleTag('Title A', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
  ///   TitleTag('Title B', provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
  ///   GenreTag(['Rock'], provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
  ///   GenreTag(['Alternative'], provenance: TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain)),
  /// ];
  ///
  /// final merged = merger.mergeTags(tags);
  /// // Result: TitleTag('Title A') and GenreTag(['Rock', 'Alternative'])
  /// ```
  List<MetadataTag> mergeTags(List<MetadataTag> tags) {
    if (tags.isEmpty) return [];

    // Group tags by their key
    final tagsByKey = <TagKey, List<MetadataTag>>{};
    for (final tag in tags) {
      tagsByKey.putIfAbsent(tag.key, () => []).add(tag);
    }

    final mergedTags = <MetadataTag>[];

    // Merge each group of tags
    for (final entry in tagsByKey.entries) {
      final key = entry.key;
      final tagsForKey = entry.value;

      if (tagsForKey.length == 1) {
        // Single tag, no merging needed
        mergedTags.add(tagsForKey.first);
      } else {
        // Multiple tags for the same key, need to merge
        final merged = _mergeTagsForKey(key, tagsForKey);
        if (merged != null) {
          mergedTags.add(merged);
        }
      }
    }

    return mergedTags;
  }

  /// Merges multiple tags for a specific key.
  ///
  /// This method applies key-specific merging logic:
  /// - GenreTag: Combines all genre lists and deduplicates
  /// - ArtworkTag: Collects all artwork with provenance (multi-valued)
  /// - Other tags: Uses precedence-based selection (single-valued)
  ///
  /// @param key The tag key being merged
  /// @param tags The list of tags with the same key
  /// @returns The merged tag, or null if no valid merge is possible
  MetadataTag? _mergeTagsForKey(TagKey key, List<MetadataTag> tags) {
    if (tags.isEmpty) return null;
    if (tags.length == 1) return tags.first;

    switch (key) {
      case TagKey.genre:
        return _mergeGenreTags(tags.cast<GenreTag>());
      case TagKey.artwork:
        return _mergeArtworkTags(tags.cast<ArtworkTag>());
      default:
        return _mergeSingleValuedTags(tags);
    }
  }

  /// Merges multiple GenreTag instances by combining their genre lists.
  ///
  /// This method performs a union operation on all genre lists, removing
  /// duplicates while preserving the order of first occurrence. The resulting
  /// tag uses the provenance from the highest-precedence source.
  ///
  /// @param genreTags The list of GenreTag instances to merge
  /// @returns A merged GenreTag with combined and deduplicated genres
  ///
  /// Example:
  /// ```dart
  /// final tag1 = GenreTag(['Rock', 'Alternative'], provenance: id3v24Provenance);
  /// final tag2 = GenreTag(['Alternative', 'Indie'], provenance: vorbisProvenance);
  /// final merged = merger._mergeGenreTags([tag1, tag2]);
  /// // Result: GenreTag(['Rock', 'Alternative', 'Indie'], provenance: id3v24Provenance)
  /// ```
  GenreTag _mergeGenreTags(List<GenreTag> genreTags) {
    if (genreTags.isEmpty) return GenreTag(const []);
    if (genreTags.length == 1) return genreTags.first;

    // Collect all genres while preserving order and removing duplicates
    final allGenres = <String>[];
    final seenGenres = <String>{};

    // Sort tags by precedence to ensure highest-precedence genres come first
    final sortedTags = List<GenreTag>.from(genreTags)..sort((a, b) => _compareTagPrecedence(a, b));

    for (final tag in sortedTags) {
      for (final genre in tag.value) {
        if (seenGenres.add(genre)) {
          allGenres.add(genre);
        }
      }
    }

    // Use provenance from the highest-precedence tag
    final highestPrecedenceTag = sortedTags.first;
    return GenreTag(allGenres, provenance: highestPrecedenceTag.provenance);
  }

  /// Merges multiple ArtworkTag instances by collecting all unique artwork.
  ///
  /// For artwork tags, we typically want to preserve all artwork from all
  /// sources rather than selecting just one. This method returns the artwork
  /// from the highest-precedence source, but in a real implementation, you
  /// might want to return a list of all artwork.
  ///
  /// Note: This is a simplified implementation. A full implementation might
  /// need to handle multiple artwork values differently, possibly returning
  /// a collection or using a different approach.
  ///
  /// @param artworkTags The list of ArtworkTag instances to merge
  /// @returns The artwork tag from the highest-precedence source
  ArtworkTag _mergeArtworkTags(List<ArtworkTag> artworkTags) {
    if (artworkTags.isEmpty) throw ArgumentError('Cannot merge empty artwork tags');
    if (artworkTags.length == 1) return artworkTags.first;

    // For now, return the highest-precedence artwork
    // In a full implementation, you might want to collect all artwork
    final sortedTags = List<ArtworkTag>.from(artworkTags)..sort((a, b) => _compareTagPrecedence(a, b));

    return sortedTags.first;
  }

  /// Merges single-valued tags using precedence-based conflict resolution.
  ///
  /// This method selects the tag with the highest precedence based on:
  /// 1. Container precedence (ID3v2.4 > ID3v2.3 > etc.)
  /// 2. Container version (within ID3v2: 2.4 > 2.3 > 2.2)
  /// 3. Confidence level (certain > inferred > derived)
  ///
  /// @param tags The list of tags with the same key to merge
  /// @returns The tag with the highest precedence
  MetadataTag _mergeSingleValuedTags(List<MetadataTag> tags) {
    if (tags.isEmpty) throw ArgumentError('Cannot merge empty tag list');
    if (tags.length == 1) return tags.first;

    // Sort by precedence and return the highest-precedence tag
    final sortedTags = List<MetadataTag>.from(tags)..sort((a, b) => _compareTagPrecedence(a, b));

    return sortedTags.first;
  }

  /// Compares two tags to determine their precedence order.
  ///
  /// Returns a negative value if [a] has higher precedence than [b],
  /// zero if they have equal precedence, and a positive value if [b]
  /// has higher precedence than [a].
  ///
  /// Precedence is determined by:
  /// 1. Container kind precedence
  /// 2. Container version (for ID3v2)
  /// 3. Confidence level
  ///
  /// @param a The first tag to compare
  /// @param b The second tag to compare
  /// @returns Comparison result for sorting (negative = a wins, positive = b wins)
  int _compareTagPrecedence(MetadataTag a, MetadataTag b) {
    // Compare container precedence
    final aContainerIndex = containerPrecedence.indexOf(a.provenance.containerKind);
    final bContainerIndex = containerPrecedence.indexOf(b.provenance.containerKind);

    // Handle unknown containers (not in precedence list)
    final aIndex = aContainerIndex == -1 ? containerPrecedence.length : aContainerIndex;
    final bIndex = bContainerIndex == -1 ? containerPrecedence.length : bContainerIndex;

    if (aIndex != bIndex) {
      return aIndex.compareTo(bIndex);
    }

    // If same container kind, compare versions (for ID3v2)
    if (a.provenance.containerKind == ContainerKind.id3v2 && b.provenance.containerKind == ContainerKind.id3v2) {
      final aVersionIndex = id3v2VersionPrecedence[a.provenance.containerVersion] ?? 999;
      final bVersionIndex = id3v2VersionPrecedence[b.provenance.containerVersion] ?? 999;

      if (aVersionIndex != bVersionIndex) {
        return aVersionIndex.compareTo(bVersionIndex);
      }
    }

    // If same container and version, compare confidence levels
    final aConfidenceIndex = confidencePrecedence.indexOf(a.provenance.confidence);
    final bConfidenceIndex = confidencePrecedence.indexOf(b.provenance.confidence);

    final aConfIndex = aConfidenceIndex == -1 ? confidencePrecedence.length : aConfidenceIndex;
    final bConfIndex = bConfidenceIndex == -1 ? confidencePrecedence.length : bConfidenceIndex;

    return aConfIndex.compareTo(bConfIndex);
  }

  /// Merges tags from multiple containers with format-specific precedence.
  ///
  /// This method provides a higher-level interface for merging tags that
  /// automatically applies format-specific precedence rules. It's designed
  /// to be used by format strategies that know their preferred precedence order.
  ///
  /// @param tagsByContainer A map of container kinds to their tags
  /// @param precedenceOrder The precedence order for this specific format
  /// @returns A list of merged tags with conflicts resolved
  ///
  /// Example:
  /// ```dart
  /// final tagsByContainer = {
  ///   ContainerKind.id3v2: [TitleTag('ID3v2 Title'), GenreTag(['Rock'])],
  ///   ContainerKind.id3v1: [TitleTag('ID3v1 Title'), GenreTag.single('Pop')],
  /// };
  ///
  /// final precedence = [ContainerKind.id3v2, ContainerKind.id3v1];
  /// final merged = merger.mergeByContainerPrecedence(tagsByContainer, precedence);
  /// ```
  List<MetadataTag> mergeByContainerPrecedence(
    Map<ContainerKind, List<MetadataTag>> tagsByContainer,
    List<ContainerKind> precedenceOrder,
  ) {
    // Create a temporary merger with the specified precedence
    final customMerger = TagMerger(containerPrecedence: precedenceOrder);

    // Flatten all tags into a single list
    final allTags = <MetadataTag>[];
    for (final tags in tagsByContainer.values) {
      allTags.addAll(tags);
    }

    return customMerger.mergeTags(allTags);
  }

  /// Creates a merged tag with combined provenance information.
  ///
  /// This utility method creates provenance that indicates the tag value
  /// was derived from multiple sources. This is useful for tags that are
  /// the result of merging operations.
  ///
  /// @param sourceTags The original tags that were merged
  /// @param resultTag The resulting merged tag
  /// @returns A new tag with merged provenance information
  ///
  /// Example:
  /// ```dart
  /// final sources = [tag1, tag2, tag3];
  /// final result = GenreTag(['Rock', 'Alternative', 'Indie']);
  /// final withProvenance = merger.withMergedProvenance(sources, result);
  /// ```
  MetadataTag withMergedProvenance(List<MetadataTag> sourceTags, MetadataTag resultTag) {
    if (sourceTags.isEmpty) return resultTag;
    if (sourceTags.length == 1) return resultTag.withProvenance(sourceTags.first.provenance);

    // Find the highest-precedence source
    final sortedSources = List<MetadataTag>.from(sourceTags)..sort((a, b) => _compareTagPrecedence(a, b));

    final highestPrecedenceSource = sortedSources.first;

    // Create provenance indicating this was derived from the highest-precedence source
    final mergedProvenance = TagProvenance(
      highestPrecedenceSource.provenance.containerKind,
      highestPrecedenceSource.provenance.containerVersion,
      TagConfidence.derived, // Mark as derived since it's a merge result
    );

    return resultTag.withProvenance(mergedProvenance);
  }
}
