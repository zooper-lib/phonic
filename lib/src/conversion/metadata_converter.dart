import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';

/// Base interface for the Generic Audio Metadata Conversion System.
///
/// This interface provides a unified way to convert metadata tags between
/// different audio container formats while preserving semantic information
/// and handling format-specific constraints and capabilities.
///
/// The conversion system supports:
/// - Cross-format conversions (ID3 ↔ Vorbis ↔ MP4 ↔ APE)
/// - Version-specific conversions (ID3v2.3 ↔ ID3v2.4)
/// - Multi-value field handling across formats
/// - Graceful degradation for limited formats
/// - Capability-aware conversion with data loss detection
abstract interface class MetadataConverter {
  /// Converts tags from source format to target format.
  ///
  /// Performs intelligent conversion between container formats, handling:
  /// - Field name mapping (TPE1 → ARTIST → ©ART)
  /// - Multi-value conversions (multiple frames → single delimited field)
  /// - Data type conversions (string dates → structured dates)
  /// - Capability-based filtering and truncation
  ///
  /// @param sourceTags Tags to convert from source format
  /// @param sourceFormat Source container format and version
  /// @param targetFormat Target container format and version
  /// @param options Conversion behavior configuration
  /// @returns Conversion result with converted tags and metadata
  ConversionResult convertTags(
    List<MetadataTag> sourceTags,
    (ContainerKind, String) sourceFormat,
    (ContainerKind, String) targetFormat,
    ConversionOptions options,
  );

  /// Analyzes conversion feasibility without performing it.
  ///
  /// Examines the provided tags and target format to determine:
  /// - Which tags can be converted losslessly
  /// - Which tags would be modified (truncated, reformatted)
  /// - Which tags would be dropped due to format limitations
  /// - Overall conversion viability and data preservation level
  ///
  /// @param sourceTags Tags to analyze for conversion
  /// @param sourceFormat Source container format and version
  /// @param targetFormat Target container format and version
  /// @returns Analysis of conversion feasibility and expected changes
  ConversionAnalysis analyzeConversion(
    List<MetadataTag> sourceTags,
    (ContainerKind, String) sourceFormat,
    (ContainerKind, String) targetFormat,
  );
}

/// Configuration options for metadata conversion behavior.
///
/// Controls how the conversion system handles edge cases, data loss,
/// and format-specific constraints during cross-format conversion.
class ConversionOptions {
  /// How to handle conversion scenarios that would result in data loss.
  ///
  /// - [ConversionMode.permissive]: Allow data loss, choose best representation
  /// - [ConversionMode.strict]: Fail conversion if any data would be lost
  /// - [ConversionMode.conservative]: Warn about data loss but continue
  final ConversionMode mode;

  /// Whether to attempt conversion of custom/user-defined fields.
  ///
  /// When true, attempts to map custom fields between formats that support them.
  /// When false, custom fields are only preserved if both formats support them.
  final bool includeCustomFields;

  /// Maximum length for text fields in target format (overrides format defaults).
  ///
  /// When set, text fields longer than this limit will be truncated
  /// regardless of the target format's native limits.
  final int? maxTextLength;

  /// Additional format-specific conversion preferences.
  ///
  /// Allows fine-tuning of conversion behavior for specific formats:
  /// - 'preserveMultiValueOrder': Keep original order of multi-valued fields
  /// - 'dateFormatPreference': Preferred date format for target ('iso8601', 'year-only')
  /// - 'genreFormatPreference': Genre format preference ('text', 'numeric', 'both')
  final Map<String, dynamic> preferences;

  const ConversionOptions({
    this.mode = ConversionMode.permissive,
    this.includeCustomFields = true,
    this.maxTextLength,
    this.preferences = const {},
  });
}

/// Conversion behavior modes for handling data loss scenarios.
enum ConversionMode {
  /// Allow data loss and choose the best available representation.
  ///
  /// This mode prioritizes successful conversion over perfect data preservation.
  /// Fields that cannot be represented in the target format are dropped,
  /// text that exceeds length limits is truncated, and multi-valued fields
  /// may be combined or split as needed.
  permissive,

  /// Fail conversion if any data would be lost.
  ///
  /// This mode ensures perfect data preservation by failing the entire
  /// conversion if any tag cannot be represented exactly in the target format.
  /// Use when data integrity is more important than conversion success.
  strict,

  /// Warn about data loss but continue conversion.
  ///
  /// This mode attempts conversion while providing detailed warnings about
  /// any data modifications or losses. Allows monitoring of conversion
  /// quality while still achieving successful format conversion.
  conservative,
}

/// Result of a metadata conversion operation.
///
/// Contains the converted tags along with detailed information about
/// what conversions were applied and any issues encountered.
class ConversionResult {
  /// The successfully converted metadata tags.
  final List<MetadataTag> convertedTags;

  /// Non-critical warnings about conversion changes.
  ///
  /// Examples:
  /// - Text truncation due to length limits
  /// - Multi-value field consolidation
  /// - Custom field mapping approximations
  final List<ConversionWarning> warnings;

  /// Critical errors that prevented some conversions.
  ///
  /// Examples:
  /// - Unsupported field types in strict mode
  /// - Data validation failures
  /// - Format capability conflicts
  final List<ConversionError> errors;

  /// Whether the conversion preserved all data without modification.
  ///
  /// True if all tags were converted without any data loss, truncation,
  /// or semantic changes. False if any modifications were required.
  final bool isLossless;

  /// Summary of the conversion operation.
  final ConversionSummary summary;

  /// Map of what conversion action was applied to each tag key.
  ///
  /// Tracks the specific transformation applied to each semantic tag field
  /// to enable detailed analysis and debugging of conversion behavior.
  final Map<TagKey, ConversionAction> appliedConversions;

  const ConversionResult({
    required this.convertedTags,
    this.warnings = const [],
    this.errors = const [],
    required this.isLossless,
    required this.summary,
    this.appliedConversions = const {},
  });

  /// Creates a successful lossless conversion result.
  factory ConversionResult.success(
    List<MetadataTag> tags,
    Map<TagKey, ConversionAction> conversions,
  ) {
    return ConversionResult(
      convertedTags: tags,
      isLossless: conversions.values.every((action) => action == ConversionAction.directMapping || action == ConversionAction.noChange),
      summary: ConversionSummary(
        totalInputTags: tags.length,
        convertedTags: tags.length,
        droppedTags: 0,
        modifiedTags: conversions.values.where((action) => action != ConversionAction.directMapping && action != ConversionAction.noChange).length,
      ),
      appliedConversions: conversions,
    );
  }

  /// Creates a conversion result with errors.
  factory ConversionResult.withErrors(
    List<MetadataTag> tags,
    List<ConversionError> errors,
    Map<TagKey, ConversionAction> conversions,
  ) {
    return ConversionResult(
      convertedTags: tags,
      errors: errors,
      isLossless: false,
      summary: ConversionSummary(
        totalInputTags: tags.length + errors.length,
        convertedTags: tags.length,
        droppedTags: errors.length,
        modifiedTags: conversions.values.where((action) => action != ConversionAction.directMapping && action != ConversionAction.noChange).length,
      ),
      appliedConversions: conversions,
    );
  }
}

/// Types of conversion actions that can be applied to metadata tags.
enum ConversionAction {
  /// No conversion was needed - tag used as-is.
  noChange,

  /// Direct 1:1 field mapping between formats.
  ///
  /// Example: ID3v2 TPE1 → Vorbis ARTIST
  directMapping,

  /// Multiple source tags consolidated into single target tag.
  ///
  /// Example: ID3v2.3 TYER+TDAT+TIME → ID3v2.4 TDRC
  consolidation,

  /// Single source tag expanded into multiple target tags.
  ///
  /// Example: ID3v2.4 TDRC → ID3v2.3 TYER+TDAT+TIME
  expansion,

  /// Data type or format change applied.
  ///
  /// Example: String date → structured date object
  dataTypeChange,

  /// Data truncated due to target format limits.
  ///
  /// Example: Long text field cut to fit ID3v1 30-character limit
  truncation,

  /// Custom format-specific conversion logic applied.
  ///
  /// Example: Genre numeric ↔ text conversion, rating scale conversion
  customLogic,

  /// Tag dropped due to target format limitations.
  ///
  /// Example: Custom field dropped when converting to ID3v1
  dropped,
}

/// Summary statistics for a conversion operation.
class ConversionSummary {
  /// Total number of input tags processed.
  final int totalInputTags;

  /// Number of tags successfully converted.
  final int convertedTags;

  /// Number of tags dropped due to format limitations.
  final int droppedTags;

  /// Number of tags that were modified during conversion.
  final int modifiedTags;

  const ConversionSummary({
    required this.totalInputTags,
    required this.convertedTags,
    required this.droppedTags,
    required this.modifiedTags,
  });

  /// Percentage of tags that were successfully converted.
  double get conversionRate => totalInputTags > 0 ? convertedTags / totalInputTags : 1.0;

  /// Percentage of converted tags that were modified.
  double get modificationRate => convertedTags > 0 ? modifiedTags / convertedTags : 0.0;
}

/// Analysis of conversion feasibility without performing the conversion.
class ConversionAnalysis {
  /// Tags that can be converted without any data loss.
  final List<TagKey> losslessTags;

  /// Tags that would be modified during conversion.
  final List<TagKey> modifiedTags;

  /// Tags that would be dropped due to format limitations.
  final List<TagKey> droppedTags;

  /// Overall assessment of conversion viability.
  final ConversionViability viability;

  /// Detailed reasons for any conversion limitations.
  final Map<TagKey, String> limitations;

  const ConversionAnalysis({
    required this.losslessTags,
    required this.modifiedTags,
    required this.droppedTags,
    required this.viability,
    this.limitations = const {},
  });

  /// Checks if a specific tag would convert to the expected result.
  bool wouldConvertTo(MetadataTag expectedTag) {
    return losslessTags.contains(expectedTag.key) || modifiedTags.contains(expectedTag.key);
  }

  /// Checks if a specific tag would be dropped during conversion.
  bool wouldBeDropped(TagKey tagKey) {
    return droppedTags.contains(tagKey);
  }
}

/// Assessment of overall conversion viability.
enum ConversionViability {
  /// Conversion is fully supported with no data loss.
  perfect,

  /// Conversion is possible with minor modifications.
  good,

  /// Conversion is possible but with significant data loss.
  limited,

  /// Conversion is not recommended due to major limitations.
  poor,
}

/// Warning about a non-critical conversion issue.
class ConversionWarning {
  /// The tag key that was affected.
  final TagKey tagKey;

  /// Description of what was changed.
  final String message;

  /// The type of modification that was applied.
  final ConversionAction action;

  const ConversionWarning({
    required this.tagKey,
    required this.message,
    required this.action,
  });
}

/// Error that prevented a tag from being converted.
class ConversionError {
  /// The tag key that could not be converted.
  final TagKey tagKey;

  /// Description of why conversion failed.
  final String message;

  /// The original tag that failed conversion.
  final MetadataTag? originalTag;

  const ConversionError({
    required this.tagKey,
    required this.message,
    this.originalTag,
  });
}

/// Context information for conversion operations.
///
/// Provides all necessary information for conversion rules to make
/// informed decisions about how to transform tags between formats.
class ConversionContext {
  /// Source container format and version.
  final (ContainerKind, String) sourceFormat;

  /// Target container format and version.
  final (ContainerKind, String) targetFormat;

  /// Conversion behavior configuration.
  final ConversionMode mode;

  /// Capabilities of the source format.
  final TagCapability sourceCapabilities;

  /// Capabilities of the target format.
  final TagCapability targetCapabilities;

  /// Additional conversion options and preferences.
  final Map<String, dynamic> options;

  const ConversionContext({
    required this.sourceFormat,
    required this.targetFormat,
    required this.mode,
    required this.sourceCapabilities,
    required this.targetCapabilities,
    this.options = const {},
  });

  /// Whether the conversion is between different container types.
  bool get isCrossFormat => sourceFormat.$1 != targetFormat.$1;

  /// Whether the conversion is between different versions of the same format.
  bool get isVersionTransition => sourceFormat.$1 == targetFormat.$1 && sourceFormat.$2 != targetFormat.$2;
}
