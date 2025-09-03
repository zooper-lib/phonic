import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'base_conversion_rule.dart';
import 'conversion_rule_result.dart';
import 'metadata_converter.dart';

/// Rule that handles multi-value delimiter conversions between formats.
///
/// Different formats use different approaches for multi-value fields:
/// - ID3v2: Multiple frames with same name
/// - Vorbis: Delimited values in single field
/// - MP4: Format-dependent
class MultiValueDelimiterRule extends BaseConversionRule {
  @override
  bool appliesTo(
    (ContainerKind, String) source,
    (ContainerKind, String) target,
  ) {
    // Applies when source and target have different multi-value approaches
    return source.$1 != target.$1;
  }

  @override
  Set<TagKey> handledTags() {
    return {TagKey.artist, TagKey.genre}; // Common multi-value fields
  }

  @override
  String get description => 'Converts multi-value field delimiters';

  @override
  ConversionRuleResult convert(
    List<MetadataTag> inputTags,
    ConversionContext context,
  ) {
    // For now, just pass through unchanged
    // TODO: Implement actual multi-value delimiter conversion
    return ConversionRuleResult.success(inputTags, {});
  }
}
