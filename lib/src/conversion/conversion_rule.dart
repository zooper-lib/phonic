import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'conversion_loss_assessment.dart';
import 'conversion_rule_result.dart';
import 'metadata_converter.dart';

/// Base interface for individual metadata conversion rules.
///
/// Conversion rules encapsulate the logic for transforming specific types
/// of metadata tags between container formats. Each rule is responsible
/// for a particular conversion scenario and can be combined with other
/// rules to handle complex cross-format conversions.
///
/// Rules are designed to be:
/// - **Composable**: Multiple rules can be chained together
/// - **Testable**: Each rule can be tested in isolation
/// - **Extensible**: New rules can be added without modifying existing ones
/// - **Format-aware**: Rules understand source and target format capabilities
abstract interface class ConversionRule {
  /// Checks if this rule applies to the given format combination.
  ///
  /// Rules can be format-specific (e.g., only ID3v2.3 → ID3v2.4) or
  /// more general (e.g., any format with multi-value support).
  ///
  /// @param source Source container format and version
  /// @param target Target container format and version
  /// @returns True if this rule can handle the conversion
  bool appliesTo(
    (ContainerKind, String) source,
    (ContainerKind, String) target,
  );

  /// Returns the set of tag keys this rule can process.
  ///
  /// Used by the conversion system to determine which rules are relevant
  /// for a given set of input tags, enabling efficient rule selection
  /// and avoiding unnecessary processing.
  ///
  /// @returns Set of tag keys this rule handles
  Set<TagKey> handledTags();

  /// Performs the conversion of input tags.
  ///
  /// Applies this rule's conversion logic to the provided tags within
  /// the given conversion context. The rule should only process tags
  /// that it claims to handle via [handledTags()].
  ///
  /// @param inputTags Tags to be converted
  /// @param context Complete conversion context including formats and capabilities
  /// @returns Result of the conversion operation
  ConversionRuleResult convert(
    List<MetadataTag> inputTags,
    ConversionContext context,
  );

  /// Analyzes potential data loss without performing conversion.
  ///
  /// Evaluates what changes would be required to convert the input tags
  /// without actually performing the conversion. Used for prevalidation
  /// and user feedback about conversion quality.
  ///
  /// @param inputTags Tags to analyze for conversion
  /// @param context Complete conversion context
  /// @returns Assessment of potential data loss and modifications
  ConversionLossAssessment assessLoss(
    List<MetadataTag> inputTags,
    ConversionContext context,
  );

  /// Human-readable description of what this rule does.
  ///
  /// Used for debugging, logging, and user-facing conversion explanations.
  /// Should clearly describe the transformation this rule performs.
  String get description;
}
