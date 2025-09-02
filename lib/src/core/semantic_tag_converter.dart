import 'container_kind.dart';
import 'metadata_tag.dart';
import 'tag_confidence.dart';
import 'tag_key.dart';
import 'tag_provenance.dart';

/// Intelligent converter for semantically equivalent tags across ID3 versions.
///
/// This converter addresses frame mapping conflicts where multiple semantic tags
/// map to the same physical frame in certain ID3 versions. The most critical
/// conflict occurs in ID3v2.4 where both YearTag and DateRecordedTag map to
/// the TDRC frame, causing data loss during encoding and round-trip validation failures.
///
/// ## Core Problems Solved
///
/// 1. **Frame Mapping Conflicts**: Resolves conflicts when multiple tags target
///    the same frame (e.g., YearTag + DateRecordedTag → TDRC in ID3v2.4)
/// 2. **Semantic Equivalence**: Recognizes when different tag types represent
///    the same semantic information (e.g., YearTag(2020) ≡ DateRecordedTag("2020"))
/// 3. **Version Transitions**: Handles conversions between ID3 versions with
///    different frame structures
///
/// ## Conversion Rules
///
/// ### Year ↔ DateRecorded Conversion
/// - **YearTag → DateRecordedTag**: Convert year integer to ISO-8601 year string
/// - **DateRecordedTag → YearTag**: Extract year from ISO-8601 date string
/// - **Conflict Resolution**: When both exist, prioritize based on confidence/provenance
///
/// ## Usage Examples
///
/// ### Basic Conversion
/// ```dart
/// final converter = SemanticTagConverter();
///
/// // Convert for ID3v2.4 targeting (both tags map to TDRC)
/// final originalTags = [
///   YearTag(2020, provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain)),
///   DateRecordedTag('2020-03-15', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
/// ];
///
/// final targetContainers = [(ContainerKind.id3v2, '2.4')];
/// final converted = converter.convertForTargetVersion(originalTags, targetContainers);
///
/// // Result: Single DateRecordedTag('2020-03-15') - no conflict, no data loss
/// ```
///
/// ### Semantic Equivalence Detection
/// ```dart
/// final yearTag = YearTag(2020);
/// final dateTag = DateRecordedTag('2020');
///
/// final areEquivalent = converter.areTagsSemanticallyEquivalent(yearTag, dateTag);
/// // Result: true - both represent the same year
/// ```
///
/// ## Implementation Strategy
///
/// The converter uses a conservative approach:
/// 1. **Preserve Original Intent**: Only converts when necessary to avoid conflicts
/// 2. **Maintain Provenance**: Tracks conversion source and confidence levels
/// 3. **Priority-Based Resolution**: Uses provenance and confidence to resolve conflicts
/// 4. **Version Awareness**: Applies conversions only when targeting conflicting versions
class SemanticTagConverter {
  /// Creates a new semantic tag converter instance.
  const SemanticTagConverter();

  /// Converts tags for target containers, resolving frame mapping conflicts.
  ///
  /// This method analyzes the provided tags and target containers to identify
  /// potential frame mapping conflicts, then applies appropriate conversions
  /// to resolve them while preserving semantic information.
  ///
  /// ## Process
  /// 1. **Conflict Detection**: Identify tags that would map to the same frame
  /// 2. **Semantic Analysis**: Determine if conflicting tags are semantically equivalent
  /// 3. **Resolution Strategy**: Apply priority-based conflict resolution
  /// 4. **Conversion Application**: Convert tags as needed for target versions
  ///
  /// @param sourceTags Original tags from all containers
  /// @param targetContainers List of target container (kind, version) pairs
  /// @returns Converted tags with conflicts resolved
  List<MetadataTag> convertForTargetVersion(
    List<MetadataTag> sourceTags,
    List<(ContainerKind, String)> targetContainers,
  ) {
    if (sourceTags.isEmpty || targetContainers.isEmpty) {
      return sourceTags;
    }

    // Check if we need to handle Year/DateRecorded conflicts for ID3v2.4
    final needsConflictResolution = targetContainers.any((container) => container.$1 == ContainerKind.id3v2 && container.$2 == '2.4');

    if (needsConflictResolution) {
      // Apply frame conflict resolution for the entire tag set
      return _resolveFrameConflicts(sourceTags, targetContainers);
    }

    // No conflicts expected, return original tags
    return sourceTags;
  }

  /// Resolves conflicts when multiple tags map to the same frame.
  ///
  /// This method handles the specific case where YearTag and DateRecordedTag
  /// both map to the TDRC frame in ID3v2.4, causing encoding conflicts.
  ///
  /// @param tags List of tags that might cause conflicts
  /// @param targetContainers Target container specifications
  /// @returns List of tags with conflicts resolved
  List<MetadataTag> resolveFrameConflicts(
    List<MetadataTag> tags,
    List<(ContainerKind, String)> targetContainers,
  ) {
    return _resolveFrameConflicts(tags, targetContainers);
  }

  /// Checks if two tags are semantically equivalent.
  ///
  /// This method determines whether two different tag types represent the same
  /// semantic information, even if they have different types or values.
  ///
  /// ## Equivalence Rules
  /// - **YearTag(year) ≡ DateRecordedTag("year")**: Same year value
  /// - **YearTag(year) ≡ DateRecordedTag("year-mm-dd")**: Date contains the year
  ///
  /// @param tag1 First tag to compare
  /// @param tag2 Second tag to compare
  /// @returns True if tags represent semantically equivalent information
  bool areTagsSemanticallyEquivalent(MetadataTag tag1, MetadataTag tag2) {
    // Same tag type and value
    if (tag1.key == tag2.key && _deepEquals(tag1.value, tag2.value)) {
      return true;
    }

    // Year ↔ DateRecorded equivalence
    if (_isYearDateRecordedPair(tag1, tag2)) {
      return _areYearDateRecordedEquivalent(tag1, tag2);
    }

    return false;
  }

  /// Resolves frame conflicts for a group of tags.
  List<MetadataTag> _resolveFrameConflicts(
    List<MetadataTag> tags,
    List<(ContainerKind, String)> targetContainers,
  ) {
    // Check for Year/DateRecorded conflicts targeting ID3v2.4
    final hasId3v24Target = targetContainers.any((container) => container.$1 == ContainerKind.id3v2 && container.$2 == '2.4');

    if (!hasId3v24Target) {
      return tags; // No ID3v2.4 target, no TDRC conflicts
    }

    // Group by potential conflict type
    final yearTags = tags.whereType<YearTag>().toList();
    final dateRecordedTags = tags.whereType<DateRecordedTag>().toList();
    final otherTags = tags.where((tag) => tag.key != TagKey.year && tag.key != TagKey.dateRecorded).toList();

    final result = <MetadataTag>[];

    // Add non-conflicting tags
    result.addAll(otherTags);

    // Resolve Year/DateRecorded conflicts
    if (yearTags.isNotEmpty && dateRecordedTags.isNotEmpty) {
      // Both types present - resolve conflict
      final resolved = _resolveYearDateRecordedConflict(yearTags, dateRecordedTags);
      result.addAll(resolved);
    } else if (yearTags.isNotEmpty) {
      // Only year tags - convert to DateRecorded for ID3v2.4 compatibility
      final converted = _convertYearToDateRecorded(yearTags);
      result.addAll(converted);
    } else if (dateRecordedTags.isNotEmpty) {
      // Only date recorded tags - use as-is
      result.addAll(dateRecordedTags);
    }

    return result;
  }

  /// Resolves conflicts between YearTag and DateRecordedTag instances.
  List<MetadataTag> _resolveYearDateRecordedConflict(
    List<YearTag> yearTags,
    List<DateRecordedTag> dateRecordedTags,
  ) {
    final result = <MetadataTag>[];

    // Find the highest precedence DateRecordedTag
    final bestDateRecorded = _findHighestPrecedenceTag(dateRecordedTags);

    if (bestDateRecorded != null) {
      // Use the DateRecordedTag as it has more precision
      result.add(bestDateRecorded);

      // Check if any YearTags have different years that should be preserved
      final dateYear = _extractYearFromDateRecorded(bestDateRecorded.value);

      for (final yearTag in yearTags) {
        if (yearTag.value != dateYear) {
          // Different year - this represents conflicting information
          // For now, prioritize DateRecorded (could be configurable in the future)
          // TODO: Consider adding warning/logging for data conflicts
        }
      }
    } else {
      // No DateRecorded tag found (shouldn't happen), convert YearTags
      result.addAll(_convertYearToDateRecorded(yearTags));
    }

    return result;
  }

  /// Converts YearTag instances to DateRecordedTag for ID3v2.4 compatibility.
  List<DateRecordedTag> _convertYearToDateRecorded(List<YearTag> yearTags) {
    if (yearTags.isEmpty) return [];

    // Find the highest precedence YearTag instead of converting all
    final highestPrecedenceYearTag = _findHighestPrecedenceTag(yearTags);

    if (highestPrecedenceYearTag == null) return [];

    // Convert only the highest precedence year to ISO-8601 year format
    final yearString = highestPrecedenceYearTag.value.toString();

    // Create new provenance indicating this was converted
    final convertedProvenance = TagProvenance(
      highestPrecedenceYearTag.provenance.containerKind,
      highestPrecedenceYearTag.provenance.containerVersion,
      TagConfidence.derived, // Mark as derived since it's a conversion
    );

    return [
      DateRecordedTag(
        yearString,
        provenance: convertedProvenance,
      ),
    ];
  }

  /// Finds the tag with highest precedence based on container and confidence.
  T? _findHighestPrecedenceTag<T extends MetadataTag>(List<T> tags) {
    if (tags.isEmpty) return null;
    if (tags.length == 1) return tags.first;

    // Sort by precedence (container precedence, then confidence)
    final sorted = tags.toList()
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

  /// Compares container kinds by precedence (lower value = higher precedence).
  int _compareContainerPrecedence(ContainerKind a, ContainerKind b) {
    const precedenceOrder = [
      ContainerKind.id3v2, // Highest precedence
      ContainerKind.id3v1,
      ContainerKind.vorbis,
      ContainerKind.mp4,
    ];

    final aIndex = precedenceOrder.indexOf(a);
    final bIndex = precedenceOrder.indexOf(b);

    // Handle unknown containers (assign lowest precedence)
    final aOrder = aIndex == -1 ? precedenceOrder.length : aIndex;
    final bOrder = bIndex == -1 ? precedenceOrder.length : bIndex;

    return aOrder.compareTo(bOrder);
  }

  /// Compares confidence levels by precedence (lower value = higher precedence).
  int _compareConfidencePrecedence(TagConfidence a, TagConfidence b) {
    const precedenceOrder = [
      TagConfidence.certain, // Highest precedence
      TagConfidence.inferred,
      TagConfidence.derived,
    ];

    return precedenceOrder.indexOf(a).compareTo(precedenceOrder.indexOf(b));
  }

  /// Checks if two tags form a Year/DateRecorded pair.
  bool _isYearDateRecordedPair(MetadataTag tag1, MetadataTag tag2) {
    return (tag1.key == TagKey.year && tag2.key == TagKey.dateRecorded) || (tag1.key == TagKey.dateRecorded && tag2.key == TagKey.year);
  }

  /// Checks if YearTag and DateRecordedTag are semantically equivalent.
  bool _areYearDateRecordedEquivalent(MetadataTag tag1, MetadataTag tag2) {
    int? year1, year2;

    // Extract years from both tags
    if (tag1.key == TagKey.year) {
      year1 = (tag1 as YearTag).value;
      year2 = _extractYearFromDateRecorded((tag2 as DateRecordedTag).value);
    } else {
      year1 = _extractYearFromDateRecorded((tag1 as DateRecordedTag).value);
      year2 = (tag2 as YearTag).value;
    }

    return year1 != null && year2 != null && year1 == year2;
  }

  /// Extracts year from ISO-8601 date string.
  int? _extractYearFromDateRecorded(String dateString) {
    // Handle various ISO-8601 formats: "2020", "2020-03", "2020-03-15", etc.
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(dateString);
    if (yearMatch != null) {
      return int.tryParse(yearMatch.group(1)!);
    }
    return null;
  }

  /// Deep equality comparison for tag values.
  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }

    return a == b;
  }
}
