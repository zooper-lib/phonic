import '../core/tag_key.dart';
import 'data_preservation_level.dart';

/// Assessment of potential data loss from a conversion rule.
///
/// Provides detailed information about what would happen if this rule
/// were applied to the input tags, without actually performing the conversion.
class ConversionLossAssessment {
  /// Tags that would be converted without any data loss.
  final List<TagKey> losslessTags;

  /// Tags that would be modified (but not lost) during conversion.
  final Map<TagKey, String> modifiedTags; // TagKey -> reason for modification

  /// Tags that would be dropped entirely during conversion.
  final Map<TagKey, String> droppedTags; // TagKey -> reason for dropping

  /// Overall data preservation level for this rule.
  final DataPreservationLevel preservationLevel;

  const ConversionLossAssessment({
    required this.losslessTags,
    required this.modifiedTags,
    required this.droppedTags,
    required this.preservationLevel,
  });

  /// Creates assessment for perfect data preservation.
  factory ConversionLossAssessment.lossless(List<TagKey> tags) {
    return ConversionLossAssessment(
      losslessTags: tags,
      modifiedTags: {},
      droppedTags: {},
      preservationLevel: DataPreservationLevel.perfect,
    );
  }

  /// Creates assessment indicating rule doesn't apply.
  factory ConversionLossAssessment.notApplicable() {
    return const ConversionLossAssessment(
      losslessTags: [],
      modifiedTags: {},
      droppedTags: {},
      preservationLevel: DataPreservationLevel.notApplicable,
    );
  }
}
