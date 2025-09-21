import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'conversion_loss_assessment.dart';
import 'conversion_rule.dart';
import 'data_preservation_level.dart';
import 'metadata_converter.dart';

/// Base class for common conversion rule implementations.
///
/// Provides shared functionality and patterns used across many conversion rules,
/// reducing boilerplate code and ensuring consistent behavior.
abstract class BaseConversionRule implements ConversionRule {
  @override
  ConversionLossAssessment assessLoss(
    List<MetadataTag> inputTags,
    ConversionContext context,
  ) {
    // Default implementation: analyze without converting
    // Subclasses can override for more sophisticated analysis
    try {
      final result = convert(inputTags, context);
      if (!result.success) {
        return ConversionLossAssessment(
          losslessTags: [],
          modifiedTags: {},
          droppedTags: Map.fromEntries(result.errors.map((e) => MapEntry(e.tagKey, e.message))),
          preservationLevel: DataPreservationLevel.poor,
        );
      }

      // Categorize the conversion actions
      final lossless = <TagKey>[];
      final modified = <TagKey, String>{};
      final dropped = <TagKey, String>{};

      for (final entry in result.appliedActions.entries) {
        switch (entry.value) {
          case ConversionAction.noChange:
          case ConversionAction.directMapping:
            lossless.add(entry.key);
            break;
          case ConversionAction.truncation:
            modified[entry.key] = 'Data truncated to fit target format limits';
            break;
          case ConversionAction.dataTypeChange:
            modified[entry.key] = 'Data format changed for target compatibility';
            break;
          case ConversionAction.consolidation:
            modified[entry.key] = 'Multiple values consolidated into single field';
            break;
          case ConversionAction.expansion:
            modified[entry.key] = 'Single value expanded into multiple fields';
            break;
          case ConversionAction.customLogic:
            modified[entry.key] = 'Custom conversion logic applied';
            break;
          case ConversionAction.dropped:
            dropped[entry.key] = 'Tag not supported in target format';
            break;
        }
      }

      // Determine overall preservation level
      final preservation = _determinePreservationLevel(lossless, modified, dropped);

      return ConversionLossAssessment(
        losslessTags: lossless,
        modifiedTags: modified,
        droppedTags: dropped,
        preservationLevel: preservation,
      );
    } catch (e) {
      return const ConversionLossAssessment(
        losslessTags: [],
        modifiedTags: {},
        droppedTags: {},
        preservationLevel: DataPreservationLevel.poor,
      );
    }
  }

  /// Determines overall data preservation level based on conversion results.
  DataPreservationLevel _determinePreservationLevel(
    List<TagKey> lossless,
    Map<TagKey, String> modified,
    Map<TagKey, String> dropped,
  ) {
    final totalTags = lossless.length + modified.length + dropped.length;
    if (totalTags == 0) return DataPreservationLevel.notApplicable;

    final losslessRatio = lossless.length / totalTags;
    final droppedRatio = dropped.length / totalTags;

    if (droppedRatio == 0 && modified.isEmpty) return DataPreservationLevel.perfect;
    if (droppedRatio == 0 && losslessRatio >= 0.8) return DataPreservationLevel.excellent;
    if (droppedRatio <= 0.1 && losslessRatio >= 0.6) return DataPreservationLevel.good;
    if (droppedRatio <= 0.3) return DataPreservationLevel.limited;

    return DataPreservationLevel.poor;
  }

  /// Helper method to check if a tag key is supported by a format.
  bool isTagSupported(TagKey tagKey, ConversionContext context, {bool source = true}) {
    final capability = source ? context.sourceCapabilities : context.targetCapabilities;
    return capability.supports(tagKey);
  }

  /// Helper method to create a converted tag with proper provenance.
  MetadataTag createConvertedTag(
    MetadataTag originalTag,
    ConversionContext context, {
    dynamic newValue,
    TagKey? newKey,
  }) {
    // This would need to be implemented with proper tag creation logic
    // For now, return the original - subclasses should override as needed
    return originalTag;
  }
}
