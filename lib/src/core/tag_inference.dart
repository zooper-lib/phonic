import 'container_kind.dart';
import 'metadata_tag.dart';
import 'tag_confidence.dart';
import 'tag_key.dart';
import 'tag_provenance.dart';

/// System for inferring missing metadata tags from available data.
///
/// TagInference provides intelligent logic for filling gaps in metadata
/// by deriving missing tags from available information. This helps create
/// more complete metadata sets while clearly marking inferred values
/// with appropriate confidence levels.
///
/// The inference system applies common-sense rules based on music industry
/// conventions and metadata relationships. All inferred tags are marked
/// with [TagConfidence.inferred] or [TagConfidence.derived] to distinguish
/// them from explicitly stored values.
///
/// Supported inference rules:
/// - AlbumArtist from Artist when AlbumArtist is missing
/// - Year from DateRecorded when Year is missing
/// - Additional rules can be added as needed
///
/// Example usage:
/// ```dart
/// final inference = TagInference();
///
/// // Original tags with missing albumArtist
/// final originalTags = [
///   ArtistTag('The Beatles'),
///   TitleTag('Hey Jude'),
///   DateRecordedTag('1968-08-26'),
/// ];
///
/// // Infer missing tags
/// final inferredTags = inference.inferMissingTags(originalTags);
///
/// // Result includes inferred AlbumArtistTag and YearTag
/// // AlbumArtistTag('The Beatles', confidence: inferred)
/// // YearTag(1968, confidence: derived)
/// ```
///
/// The inference system is conservative and only applies well-established
/// rules that are likely to be correct. Users can always override inferred
/// values with explicit data if needed.
class TagInference {
  /// Creates a new TagInference instance.
  const TagInference();

  /// Infers missing metadata tags from the provided tag list.
  ///
  /// This method analyzes the provided tags and applies inference rules
  /// to generate missing tags that can be reasonably derived from available
  /// data. The original tags are preserved unchanged, and new inferred tags
  /// are added to the result.
  ///
  /// Inference rules applied:
  /// 1. AlbumArtist from Artist (when AlbumArtist is missing)
  /// 2. Year from DateRecorded (when Year is missing)
  ///
  /// All inferred tags are marked with appropriate confidence levels:
  /// - [TagConfidence.inferred] for logical assumptions (albumArtist from artist)
  /// - [TagConfidence.derived] for calculated values (year from dateRecorded)
  ///
  /// @param originalTags The list of existing tags to analyze
  /// @returns A new list containing original tags plus any inferred tags
  ///
  /// Example:
  /// ```dart
  /// final tags = [
  ///   ArtistTag('Pink Floyd'),
  ///   DateRecordedTag('1973-03-01'),
  /// ];
  ///
  /// final withInferred = inference.inferMissingTags(tags);
  /// // Result includes:
  /// // - Original ArtistTag and DateRecordedTag
  /// // - Inferred AlbumArtistTag('Pink Floyd', confidence: inferred)
  /// // - Derived YearTag(1973, confidence: derived)
  /// ```
  List<MetadataTag> inferMissingTags(List<MetadataTag> originalTags) {
    if (originalTags.isEmpty) return [];

    final result = List<MetadataTag>.from(originalTags);
    final tagsByKey = _groupTagsByKey(originalTags);

    // Apply inference rules
    _inferAlbumArtistFromArtist(tagsByKey, result);
    _deriveYearFromDateRecorded(tagsByKey, result);

    return result;
  }

  /// Groups tags by their key for efficient lookup during inference.
  Map<TagKey, List<MetadataTag>> _groupTagsByKey(List<MetadataTag> tags) {
    final tagsByKey = <TagKey, List<MetadataTag>>{};
    for (final tag in tags) {
      tagsByKey.putIfAbsent(tag.key, () => []).add(tag);
    }
    return tagsByKey;
  }

  /// Infers AlbumArtist from Artist when AlbumArtist is missing.
  ///
  /// This rule applies the common convention that when no specific album
  /// artist is provided, the track artist is typically also the album artist.
  /// This is especially true for single-artist albums and most popular music.
  ///
  /// The inferred AlbumArtist tag is marked with [TagConfidence.inferred]
  /// and uses provenance derived from the source Artist tag to maintain
  /// traceability.
  ///
  /// @param tagsByKey Map of tags grouped by key for efficient lookup
  /// @param result The result list to add inferred tags to
  void _inferAlbumArtistFromArtist(
    Map<TagKey, List<MetadataTag>> tagsByKey,
    List<MetadataTag> result,
  ) {
    // Only infer if AlbumArtist is missing and Artist is present
    if (tagsByKey.containsKey(TagKey.albumArtist)) return;

    final artistTags = tagsByKey[TagKey.artist];
    if (artistTags == null || artistTags.isEmpty) return;

    // Use the first (highest precedence) artist tag
    final artistTag = artistTags.first as ArtistTag;

    // Create inferred AlbumArtist with appropriate provenance
    final inferredProvenance = TagProvenance(
      artistTag.provenance.containerKind,
      artistTag.provenance.containerVersion,
      TagConfidence.inferred,
    );

    final inferredAlbumArtist = AlbumArtistTag(
      artistTag.value,
      provenance: inferredProvenance,
    );

    result.add(inferredAlbumArtist);
  }

  /// Derives Year from DateRecorded when Year is missing.
  ///
  /// This rule extracts the year component from a full date recorded field
  /// when a separate year field is not present. This is a mechanical
  /// transformation that preserves the temporal information in a more
  /// accessible format.
  ///
  /// The derived Year tag is marked with [TagConfidence.derived] and uses
  /// provenance from the source DateRecorded tag to maintain traceability.
  ///
  /// @param tagsByKey Map of tags grouped by key for efficient lookup
  /// @param result The result list to add derived tags to
  void _deriveYearFromDateRecorded(
    Map<TagKey, List<MetadataTag>> tagsByKey,
    List<MetadataTag> result,
  ) {
    // Only derive if Year is missing and DateRecorded is present
    if (tagsByKey.containsKey(TagKey.year)) return;

    final dateRecordedTags = tagsByKey[TagKey.dateRecorded];
    if (dateRecordedTags == null || dateRecordedTags.isEmpty) return;

    // Use the first (highest precedence) date recorded tag
    final dateRecordedTag = dateRecordedTags.first as DateRecordedTag;

    // Extract year from ISO-8601 date string
    final year = _extractYearFromIso8601(dateRecordedTag.value);
    if (year == null) return;

    // Create derived Year with appropriate provenance
    final derivedProvenance = TagProvenance(
      dateRecordedTag.provenance.containerKind,
      dateRecordedTag.provenance.containerVersion,
      TagConfidence.derived,
    );

    final derivedYear = YearTag(
      year,
      provenance: derivedProvenance,
    );

    result.add(derivedYear);
  }

  /// Extracts the year component from an ISO-8601 date string.
  ///
  /// This method parses various ISO-8601 formats to extract just the year
  /// component. It handles formats from simple year-only strings to full
  /// timestamps with timezone information.
  ///
  /// Supported formats:
  /// - "2023" → 2023
  /// - "2023-03" → 2023
  /// - "2023-03-15" → 2023
  /// - "2023-03-15T14:30:00Z" → 2023
  ///
  /// @param iso8601Date The ISO-8601 formatted date string
  /// @returns The extracted year, or null if parsing fails
  int? _extractYearFromIso8601(String iso8601Date) {
    if (iso8601Date.trim().isEmpty) return null;

    // Simple regex to extract year from start of ISO-8601 string
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(iso8601Date.trim());
    if (yearMatch == null) return null;

    final yearStr = yearMatch.group(1)!;
    final year = int.tryParse(yearStr);

    // Validate year range (same as YearTag validation)
    if (year == null || year < YearTag.minYear || year > YearTag.maxYear) {
      return null;
    }

    return year;
  }

  /// Infers missing tags for a specific container context.
  ///
  /// This method provides container-aware inference that can apply different
  /// rules based on the target container's capabilities and conventions.
  /// This is useful when preparing tags for writing to specific formats
  /// that may have different expectations or limitations.
  ///
  /// @param originalTags The list of existing tags to analyze
  /// @param containerKind The target container kind for context
  /// @param containerVersion The target container version for context
  /// @returns A new list containing original tags plus any inferred tags
  ///
  /// Example:
  /// ```dart
  /// // Infer tags specifically for ID3v2.4 context
  /// final id3Tags = inference.inferMissingTagsForContainer(
  ///   originalTags,
  ///   ContainerKind.id3v2,
  ///   '2.4',
  /// );
  /// ```
  List<MetadataTag> inferMissingTagsForContainer(
    List<MetadataTag> originalTags,
    ContainerKind containerKind,
    String containerVersion,
  ) {
    // For now, use the same inference rules regardless of container
    // Future enhancements could apply container-specific logic
    return inferMissingTags(originalTags);
  }

  /// Checks if a specific tag key can be inferred from available tags.
  ///
  /// This method allows callers to check whether a specific missing tag
  /// could be inferred without actually performing the inference. This
  /// is useful for UI applications that want to show users what tags
  /// could be automatically filled.
  ///
  /// @param targetKey The tag key to check for inference possibility
  /// @param availableTags The list of available tags to analyze
  /// @returns True if the target key can be inferred from available tags
  ///
  /// Example:
  /// ```dart
  /// final canInferAlbumArtist = inference.canInferTag(
  ///   TagKey.albumArtist,
  ///   [ArtistTag('The Beatles')],
  /// ); // Returns true
  ///
  /// final canInferYear = inference.canInferTag(
  ///   TagKey.year,
  ///   [DateRecordedTag('1969-09-26')],
  /// ); // Returns true
  /// ```
  bool canInferTag(TagKey targetKey, List<MetadataTag> availableTags) {
    final tagsByKey = _groupTagsByKey(availableTags);

    // Don't infer if target already exists
    if (tagsByKey.containsKey(targetKey)) return false;

    switch (targetKey) {
      case TagKey.albumArtist:
        return tagsByKey.containsKey(TagKey.artist);
      case TagKey.year:
        return tagsByKey.containsKey(TagKey.dateRecorded);
      default:
        return false;
    }
  }

  /// Returns a list of all tag keys that can be inferred from available tags.
  ///
  /// This method provides a comprehensive view of what inference opportunities
  /// exist for a given set of tags. It's useful for applications that want
  /// to show users all possible automatic enhancements to their metadata.
  ///
  /// @param availableTags The list of available tags to analyze
  /// @returns A list of tag keys that could be inferred
  ///
  /// Example:
  /// ```dart
  /// final tags = [
  ///   ArtistTag('Queen'),
  ///   DateRecordedTag('1975-10-31'),
  /// ];
  ///
  /// final inferrable = inference.getInferrableKeys(tags);
  /// // Returns [TagKey.albumArtist, TagKey.year]
  /// ```
  List<TagKey> getInferrableKeys(List<MetadataTag> availableTags) {
    final inferrable = <TagKey>[];

    // Check each supported inference rule
    const supportedInferences = [TagKey.albumArtist, TagKey.year];

    for (final key in supportedInferences) {
      if (canInferTag(key, availableTags)) {
        inferrable.add(key);
      }
    }

    return inferrable;
  }
}
