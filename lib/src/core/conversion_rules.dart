import 'container_kind.dart';
import 'metadata_tag.dart';
import 'tag_confidence.dart';
import 'tag_key.dart';
import 'tag_provenance.dart';

/// Rule-based engine for defining semantic tag conversions and conflict resolution.
///
/// This class provides a structured approach to defining conversion rules between
/// semantically equivalent tags across different ID3 versions and container formats.
/// It serves as the knowledge base for the SemanticTagConverter, encapsulating
/// the logic for when and how to convert between different tag representations.
///
/// ## Conversion Rule Types
///
/// ### 1. Direct Conversions
/// Simple one-to-one mappings between tag types:
/// - YearTag(2020) → DateRecordedTag("2020")
/// - DateRecordedTag("2020") → YearTag(2020)
///
/// ### 2. Frame Conflict Rules
/// Rules for resolving multiple tags mapping to the same frame:
/// - ID3v2.4 TDRC: YearTag + DateRecordedTag → DateRecordedTag (preserve precision)
///
/// ### 3. Precedence Rules
/// Define which tag type takes priority during conflicts:
/// - DateRecorded over Year (more precise)
/// - Higher confidence over lower confidence
/// - Newer container versions over older versions
///
/// ## Usage Examples
///
/// ### Check Conversion Capability
/// ```dart
/// final rules = ConversionRules();
///
/// final canConvert = rules.canConvert(TagKey.year, TagKey.dateRecorded);
/// // Result: true - year can be converted to dateRecorded
/// ```
///
/// ### Apply Conversion
/// ```dart
/// final yearTag = YearTag(2020);
/// final converted = rules.convert(yearTag, TagKey.dateRecorded);
/// // Result: DateRecordedTag("2020") with derived confidence
/// ```
///
/// ### Resolve Frame Conflicts
/// ```dart
/// final conflictingTags = [
///   YearTag(2020, provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
///   DateRecordedTag('2020-03-15', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
/// ];
///
/// final resolver = FrameConflictResolver();
/// final resolved = resolver.resolveConflict(conflictingTags);
/// // Result: DateRecordedTag('2020-03-15') - preserves more precise date
/// ```
class ConversionRules {
  /// Creates a new conversion rules engine instance.
  const ConversionRules();

  /// Checks if conversion is possible between two tag types.
  ///
  /// This method determines whether a semantic conversion exists between
  /// the source and target tag keys. It does not validate the actual
  /// tag value, only the possibility of conversion.
  ///
  /// @param from Source tag key
  /// @param to Target tag key
  /// @returns True if conversion is supported
  bool canConvert(TagKey from, TagKey to) {
    // Same tag type - no conversion needed
    if (from == to) return true;

    // Year ↔ DateRecorded conversions
    if (from == TagKey.year && to == TagKey.dateRecorded) return true;
    if (from == TagKey.dateRecorded && to == TagKey.year) return true;

    // Future: Add more conversion rules here
    // - GenreTag format conversions (null-terminated vs slash-separated)
    // - Rating scale conversions (0-100 vs 0-255)
    // - Text encoding conversions

    return false;
  }

  /// Converts a metadata tag to a different semantic representation.
  ///
  /// This method applies the appropriate conversion rule to transform a tag
  /// from one type to another while preserving semantic meaning. The conversion
  /// updates the tag's provenance to indicate it was derived through conversion.
  ///
  /// @param source The source tag to convert
  /// @param targetKey The desired target tag key
  /// @returns Converted tag, or null if conversion is not possible
  MetadataTag? convert(MetadataTag source, TagKey targetKey) {
    if (!canConvert(source.key, targetKey)) {
      return null;
    }

    // Same type - no conversion needed
    if (source.key == targetKey) {
      return source;
    }

    // Apply specific conversion rules
    switch ((source.key, targetKey)) {
      case (TagKey.year, TagKey.dateRecorded):
        return _convertYearToDateRecorded(source as YearTag);

      case (TagKey.dateRecorded, TagKey.year):
        return _convertDateRecordedToYear(source as DateRecordedTag);

      default:
        return null; // Unsupported conversion
    }
  }

  /// Gets the frame ID that a tag key maps to for a specific container version.
  ///
  /// This method provides the frame mapping logic that determines potential
  /// conflicts when multiple tag keys map to the same physical frame.
  ///
  /// @param tagKey The tag key to map
  /// @param containerKind The target container type
  /// @param containerVersion The target container version
  /// @returns Frame ID string, or null if not supported
  String? getFrameId(TagKey tagKey, ContainerKind containerKind, String containerVersion) {
    if (containerKind != ContainerKind.id3v2) {
      return null; // Only ID3v2 has frame conflicts currently
    }

    switch (containerVersion) {
      case '2.2':
        return _getId3v22FrameId(tagKey);
      case '2.3':
        return _getId3v23FrameId(tagKey);
      case '2.4':
        return _getId3v24FrameId(tagKey);
      default:
        return null;
    }
  }

  /// Identifies potential frame conflicts for target containers.
  ///
  /// This method analyzes a list of tag keys to identify cases where multiple
  /// tags would map to the same physical frame in the target containers,
  /// potentially causing data loss during encoding.
  ///
  /// @param tagKeys The tag keys to analyze
  /// @param targetContainers The target container specifications
  /// @returns Map of frame IDs to conflicting tag keys
  Map<String, List<TagKey>> identifyFrameConflicts(
    List<TagKey> tagKeys,
    List<(ContainerKind, String)> targetContainers,
  ) {
    final conflicts = <String, List<TagKey>>{};

    for (final (containerKind, containerVersion) in targetContainers) {
      final frameMap = <String, List<TagKey>>{};

      // Map each tag key to its frame ID
      for (final tagKey in tagKeys) {
        final frameId = getFrameId(tagKey, containerKind, containerVersion);
        if (frameId != null) {
          frameMap.putIfAbsent(frameId, () => []).add(tagKey);
        }
      }

      // Identify frames with multiple tag keys (conflicts)
      for (final entry in frameMap.entries) {
        if (entry.value.length > 1) {
          final frameId = '${containerKind.name}:$containerVersion:${entry.key}';
          conflicts[frameId] = entry.value;
        }
      }
    }

    return conflicts;
  }

  /// Converts YearTag to DateRecordedTag.
  DateRecordedTag _convertYearToDateRecorded(YearTag yearTag) {
    final yearString = yearTag.value.toString();

    // Mark as derived since this is a conversion
    final derivedProvenance = TagProvenance(
      yearTag.provenance.containerKind,
      yearTag.provenance.containerVersion,
      TagConfidence.derived,
    );

    return DateRecordedTag(yearString, provenance: derivedProvenance);
  }

  /// Converts DateRecordedTag to YearTag.
  YearTag? _convertDateRecordedToYear(DateRecordedTag dateTag) {
    // Extract year from ISO-8601 date string
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(dateTag.value);
    if (yearMatch == null) {
      return null; // Cannot extract year from date string
    }

    final year = int.tryParse(yearMatch.group(1)!);
    if (year == null || year < YearTag.minYear || year > YearTag.maxYear) {
      return null; // Invalid year range
    }

    // Mark as derived since this is a conversion
    final derivedProvenance = TagProvenance(
      dateTag.provenance.containerKind,
      dateTag.provenance.containerVersion,
      TagConfidence.derived,
    );

    return YearTag(year, provenance: derivedProvenance);
  }

  /// Gets ID3v2.2 frame ID for tag key.
  String? _getId3v22FrameId(TagKey tagKey) {
    switch (tagKey) {
      case TagKey.title:
        return 'TT2';
      case TagKey.artist:
        return 'TP1';
      case TagKey.album:
        return 'TAL';
      case TagKey.year:
        return 'TYE';
      case TagKey.genre:
        return 'TCO';
      case TagKey.comment:
        return 'COM';
      // dateRecorded not supported in ID3v2.2
      default:
        return null;
    }
  }

  /// Gets ID3v2.3 frame ID for tag key.
  String? _getId3v23FrameId(TagKey tagKey) {
    switch (tagKey) {
      case TagKey.title:
        return 'TIT2';
      case TagKey.artist:
        return 'TPE1';
      case TagKey.album:
        return 'TALB';
      case TagKey.year:
        return 'TYER';
      case TagKey.genre:
        return 'TCON';
      case TagKey.comment:
        return 'COMM';
      // dateRecorded maps to separate TYER/TDAT/TIME frames in ID3v2.3
      case TagKey.dateRecorded:
        return 'TYER'; // Primary frame for date
      default:
        return null;
    }
  }

  /// Gets ID3v2.4 frame ID for tag key.
  String? _getId3v24FrameId(TagKey tagKey) {
    switch (tagKey) {
      case TagKey.title:
        return 'TIT2';
      case TagKey.artist:
        return 'TPE1';
      case TagKey.album:
        return 'TALB';
      case TagKey.year:
        return 'TDRC'; // ← Conflict: Maps to TDRC
      case TagKey.dateRecorded:
        return 'TDRC'; // ← Conflict: Maps to TDRC
      case TagKey.genre:
        return 'TCON';
      case TagKey.comment:
        return 'COMM';
      default:
        return null;
    }
  }
}

/// Resolver for handling frame conflicts when multiple tags map to the same frame.
///
/// This class implements conflict resolution strategies when multiple semantic
/// tags would write to the same physical frame in a container format. It applies
/// precedence rules and semantic analysis to determine the best resolution approach.
class FrameConflictResolver {
  /// Creates a new frame conflict resolver instance.
  const FrameConflictResolver();

  /// Resolves conflicts between multiple tags that map to the same frame.
  ///
  /// This method applies resolution strategies to determine which tag(s) should
  /// be preserved when multiple tags would write to the same physical frame.
  /// The resolution prioritizes data preservation and semantic accuracy.
  ///
  /// ## Resolution Strategies
  /// 1. **Semantic Equivalence**: If tags represent the same information, keep the most precise
  /// 2. **Data Conflict**: If tags have different values, apply precedence rules
  /// 3. **Precision Priority**: More specific data types take precedence over general ones
  ///
  /// @param conflictingTags List of tags that map to the same frame
  /// @returns Single tag representing the resolved conflict
  MetadataTag resolveConflict(List<MetadataTag> conflictingTags) {
    if (conflictingTags.isEmpty) {
      throw ArgumentError('Cannot resolve conflict with empty tag list');
    }

    if (conflictingTags.length == 1) {
      return conflictingTags.first;
    }

    // Special handling for Year/DateRecorded conflicts
    final yearTags = conflictingTags.whereType<YearTag>().toList();
    final dateRecordedTags = conflictingTags.whereType<DateRecordedTag>().toList();

    if (yearTags.isNotEmpty && dateRecordedTags.isNotEmpty) {
      return _resolveYearDateRecordedConflict(yearTags, dateRecordedTags);
    }

    // Generic conflict resolution based on precedence
    return _resolveByPrecedence(conflictingTags);
  }

  /// Resolves conflicts between YearTag and DateRecordedTag instances.
  MetadataTag _resolveYearDateRecordedConflict(
    List<YearTag> yearTags,
    List<DateRecordedTag> dateRecordedTags,
  ) {
    // Find the highest precedence DateRecordedTag
    final bestDateRecorded = _findHighestPrecedenceTag(dateRecordedTags);

    if (bestDateRecorded != null) {
      // Check if any year tags conflict with the date's year
      final dateYear = _extractYearFromDate(bestDateRecorded.value);

      for (final yearTag in yearTags) {
        if (dateYear != null && yearTag.value != dateYear) {
          // Data conflict - different years
          // Could log warning here in the future
        }
      }

      // Prioritize DateRecorded as it has more precision
      return bestDateRecorded;
    }

    // No DateRecorded tag, find best YearTag
    final bestYear = _findHighestPrecedenceTag(yearTags);
    return bestYear!;
  }

  /// Resolves conflicts using general precedence rules.
  MetadataTag _resolveByPrecedence(List<MetadataTag> conflictingTags) {
    final sorted = conflictingTags.toList()
      ..sort((a, b) {
        // Container precedence
        final containerComparison = _compareContainerPrecedence(
          a.provenance.containerKind,
          b.provenance.containerKind,
        );
        if (containerComparison != 0) return containerComparison;

        // Confidence level precedence
        return _compareConfidencePrecedence(
          a.provenance.confidence,
          b.provenance.confidence,
        );
      });

    return sorted.first;
  }

  /// Finds the tag with highest precedence from a list.
  T? _findHighestPrecedenceTag<T extends MetadataTag>(List<T> tags) {
    if (tags.isEmpty) return null;

    return tags.reduce((a, b) {
      final containerComparison = _compareContainerPrecedence(
        a.provenance.containerKind,
        b.provenance.containerKind,
      );

      if (containerComparison != 0) {
        return containerComparison < 0 ? a : b;
      }

      final confidenceComparison = _compareConfidencePrecedence(
        a.provenance.confidence,
        b.provenance.confidence,
      );

      return confidenceComparison <= 0 ? a : b;
    });
  }

  /// Compares container kinds by precedence.
  int _compareContainerPrecedence(ContainerKind a, ContainerKind b) {
    const precedenceOrder = [
      ContainerKind.id3v2, // Highest precedence
      ContainerKind.id3v1,
      ContainerKind.vorbis,
      ContainerKind.mp4,
    ];

    final aIndex = precedenceOrder.indexOf(a);
    final bIndex = precedenceOrder.indexOf(b);

    final aOrder = aIndex == -1 ? precedenceOrder.length : aIndex;
    final bOrder = bIndex == -1 ? precedenceOrder.length : bIndex;

    return aOrder.compareTo(bOrder);
  }

  /// Compares confidence levels by precedence.
  int _compareConfidencePrecedence(TagConfidence a, TagConfidence b) {
    const precedenceOrder = [
      TagConfidence.certain, // Highest precedence
      TagConfidence.inferred,
      TagConfidence.derived,
    ];

    return precedenceOrder.indexOf(a).compareTo(precedenceOrder.indexOf(b));
  }

  /// Extracts year from ISO-8601 date string.
  int? _extractYearFromDate(String dateString) {
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(dateString);
    return yearMatch != null ? int.tryParse(yearMatch.group(1)!) : null;
  }
}
