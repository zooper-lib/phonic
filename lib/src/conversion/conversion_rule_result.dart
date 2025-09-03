import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'metadata_converter.dart';

/// Result of applying a single conversion rule.
///
/// Encapsulates the outcome of a conversion rule's processing,
/// including any transformed tags, warnings, or errors.
class ConversionRuleResult {
  /// Tags that were successfully converted by this rule.
  final List<MetadataTag> convertedTags;

  /// Warnings about non-critical issues during conversion.
  final List<ConversionWarning> warnings;

  /// Errors that prevented some conversions.
  final List<ConversionError> errors;

  /// Map of conversion actions applied to each tag key.
  final Map<TagKey, ConversionAction> appliedActions;

  /// Whether this rule successfully processed its input.
  final bool success;

  const ConversionRuleResult({
    required this.convertedTags,
    this.warnings = const [],
    this.errors = const [],
    this.appliedActions = const {},
    required this.success,
  });

  /// Creates a successful conversion result.
  factory ConversionRuleResult.success(
    List<MetadataTag> tags,
    Map<TagKey, ConversionAction> actions,
  ) {
    return ConversionRuleResult(
      convertedTags: tags,
      appliedActions: actions,
      success: true,
    );
  }

  /// Creates a result indicating no changes were needed.
  factory ConversionRuleResult.noChange() {
    return const ConversionRuleResult(
      convertedTags: [],
      success: true,
    );
  }

  /// Creates a result indicating conversion failed.
  factory ConversionRuleResult.error(String errorMessage, {TagKey? tagKey, MetadataTag? originalTag}) {
    return ConversionRuleResult(
      convertedTags: [],
      errors: [
        ConversionError(
          tagKey: tagKey ?? TagKey.title, // Default, should be specified
          message: errorMessage,
          originalTag: originalTag,
        ),
      ],
      success: false,
    );
  }

  /// Creates a result with warnings but successful conversion.
  factory ConversionRuleResult.withWarnings(
    List<MetadataTag> tags,
    Map<TagKey, ConversionAction> actions,
    List<ConversionWarning> warnings,
  ) {
    return ConversionRuleResult(
      convertedTags: tags,
      appliedActions: actions,
      warnings: warnings,
      success: true,
    );
  }
}
