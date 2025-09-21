import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'base_conversion_rule.dart';
import 'conversion_rule_result.dart';
import 'metadata_converter.dart';

/// Rule that applies format capability constraints to tags.
///
/// This rule ensures that tag values comply with the limitations of the
/// target format, such as text length limits, encoding constraints, and
/// supported field types.
class CapabilityConstraintRule extends BaseConversionRule {
  @override
  bool appliesTo(
    (ContainerKind, String) source,
    (ContainerKind, String) target,
  ) {
    // Always applies - all formats have constraints
    return true;
  }

  @override
  Set<TagKey> handledTags() {
    return TagKey.values.toSet();
  }

  @override
  String get description => 'Applies format capability constraints';

  @override
  ConversionRuleResult convert(
    List<MetadataTag> inputTags,
    ConversionContext context,
  ) {
    final convertedTags = <MetadataTag>[];
    final actions = <TagKey, ConversionAction>{};
    final warnings = <ConversionWarning>[];

    for (final tag in inputTags) {
      if (!context.targetCapabilities.supports(tag.key)) {
        // Tag not supported in target format - drop it
        actions[tag.key] = ConversionAction.dropped;
        warnings.add(
          ConversionWarning(
            tagKey: tag.key,
            message: 'Tag ${tag.key} not supported in target format',
            action: ConversionAction.dropped,
          ),
        );
        continue;
      }

      final constrainedTag = _applyConstraints(tag, context);
      convertedTags.add(constrainedTag);

      // Generate warning if tag was modified
      if (constrainedTag != tag) {
        warnings.add(
          ConversionWarning(
            tagKey: tag.key,
            message: 'Tag value truncated or modified due to target format constraints',
            action: ConversionAction.truncation,
          ),
        );
      }

      actions[tag.key] = constrainedTag == tag ? ConversionAction.noChange : ConversionAction.truncation;
    }

    return ConversionRuleResult(
      convertedTags: convertedTags,
      warnings: warnings,
      errors: [],
      appliedActions: actions,
      success: true,
    );
  }

  /// Applies capability constraints to a tag.
  MetadataTag _applyConstraints(
    MetadataTag tag,
    ConversionContext context,
  ) {
    final targetSemantics = context.targetCapabilities.semantics(tag.key);

    // Apply text length constraints for string-based tags
    if (targetSemantics.maxTextLength != null && tag.value is String) {
      final originalText = tag.value as String;
      final maxLength = targetSemantics.maxTextLength!;

      if (originalText.length > maxLength) {
        // Truncate the text to fit the constraint
        final truncatedText = originalText.substring(0, maxLength);
        return _createConstrainedTag(tag, truncatedText);
      }
    }

    // Apply numeric value constraints
    if (tag.value is int) {
      final numValue = tag.value as int;
      final min = targetSemantics.minValue;
      final max = targetSemantics.maxValue;

      if (min != null && numValue < min) {
        return _createConstrainedTag(tag, min);
      }
      if (max != null && numValue > max) {
        return _createConstrainedTag(tag, max);
      }
    }

    return tag;
  }

  /// Creates a new tag with a constrained value.
  MetadataTag _createConstrainedTag(MetadataTag originalTag, dynamic newValue) {
    // Create a new tag of the same type with the constrained value
    switch (originalTag.key) {
      case TagKey.title:
        return TitleTag(newValue, provenance: originalTag.provenance);
      case TagKey.artist:
        return ArtistTag(newValue, provenance: originalTag.provenance);
      case TagKey.album:
        return AlbumTag(newValue, provenance: originalTag.provenance);
      case TagKey.albumArtist:
        return AlbumArtistTag(newValue, provenance: originalTag.provenance);
      case TagKey.comment:
        return CommentTag(newValue, provenance: originalTag.provenance);
      case TagKey.composer:
        return ComposerTag(newValue, provenance: originalTag.provenance);
      case TagKey.trackNumber:
        return TrackNumberTag(newValue, provenance: originalTag.provenance);
      case TagKey.discNumber:
        return DiscNumberTag(newValue, provenance: originalTag.provenance);
      case TagKey.year:
        return YearTag(newValue, provenance: originalTag.provenance);
      case TagKey.rating:
        return RatingTag(newValue, provenance: originalTag.provenance);
      default:
        // For unsupported tag types, return the original
        return originalTag;
    }
  }
}
