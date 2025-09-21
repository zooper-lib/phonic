import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'base_conversion_rule.dart';
import 'conversion_loss_assessment.dart';
import 'conversion_rule_result.dart';
import 'data_preservation_level.dart';
import 'metadata_converter.dart';

/// Handles direct field mapping conversions between different container formats.
///
/// This rule implements the core cross-format field mappings that enable
/// conversion between ID3, Vorbis, MP4, and other container formats.
/// It maps semantic tag concepts to their format-specific representations.
///
/// Examples:
/// - ID3v2 TPE1 ↔ Vorbis ARTIST ↔ MP4 ©ART
/// - ID3v2 TIT2 ↔ Vorbis TITLE ↔ MP4 ©nam
/// - ID3v2 TALB ↔ Vorbis ALBUM ↔ MP4 ©alb
class CrossFormatMappingRule extends BaseConversionRule {
  /// Maps semantic tag keys to format-specific field identifiers.
  ///
  /// This mapping enables the conversion system to translate between
  /// different container formats' native field representations while
  /// preserving semantic meaning.
  static const Map<(ContainerKind, TagKey), String> _formatFieldMappings = {
    // ID3v2 frame mappings
    (ContainerKind.id3v2, TagKey.title): 'TIT2',
    (ContainerKind.id3v2, TagKey.artist): 'TPE1',
    (ContainerKind.id3v2, TagKey.album): 'TALB',
    (ContainerKind.id3v2, TagKey.albumArtist): 'TPE2',
    (ContainerKind.id3v2, TagKey.year): 'TYER', // v2.3 and earlier
    (ContainerKind.id3v2, TagKey.dateRecorded): 'TDRC', // v2.4
    (ContainerKind.id3v2, TagKey.genre): 'TCON',
    (ContainerKind.id3v2, TagKey.trackNumber): 'TRCK',
    (ContainerKind.id3v2, TagKey.discNumber): 'TPOS',
    (ContainerKind.id3v2, TagKey.comment): 'COMM',
    (ContainerKind.id3v2, TagKey.composer): 'TCOM',
    (ContainerKind.id3v2, TagKey.bpm): 'TBPM',
    (ContainerKind.id3v2, TagKey.rating): 'POPM',
    (ContainerKind.id3v2, TagKey.artwork): 'APIC',

    // Vorbis comment field mappings
    (ContainerKind.vorbis, TagKey.title): 'TITLE',
    (ContainerKind.vorbis, TagKey.artist): 'ARTIST',
    (ContainerKind.vorbis, TagKey.album): 'ALBUM',
    (ContainerKind.vorbis, TagKey.albumArtist): 'ALBUMARTIST',
    (ContainerKind.vorbis, TagKey.year): 'DATE',
    (ContainerKind.vorbis, TagKey.dateRecorded): 'DATE',
    (ContainerKind.vorbis, TagKey.genre): 'GENRE',
    (ContainerKind.vorbis, TagKey.trackNumber): 'TRACKNUMBER',
    (ContainerKind.vorbis, TagKey.discNumber): 'DISCNUMBER',
    (ContainerKind.vorbis, TagKey.comment): 'COMMENT',
    (ContainerKind.vorbis, TagKey.composer): 'COMPOSER',
    (ContainerKind.vorbis, TagKey.bpm): 'BPM',
    (ContainerKind.vorbis, TagKey.rating): 'RATING',

    // MP4 atom mappings
    (ContainerKind.mp4, TagKey.title): '©nam',
    (ContainerKind.mp4, TagKey.artist): '©ART',
    (ContainerKind.mp4, TagKey.album): '©alb',
    (ContainerKind.mp4, TagKey.albumArtist): 'aART',
    (ContainerKind.mp4, TagKey.year): '©day',
    (ContainerKind.mp4, TagKey.dateRecorded): '©day',
    (ContainerKind.mp4, TagKey.genre): '©gen',
    (ContainerKind.mp4, TagKey.trackNumber): 'trkn',
    (ContainerKind.mp4, TagKey.discNumber): 'disk',
    (ContainerKind.mp4, TagKey.comment): '©cmt',
    (ContainerKind.mp4, TagKey.composer): '©wrt',
    (ContainerKind.mp4, TagKey.bpm): 'tmpo',
    (ContainerKind.mp4, TagKey.rating): 'rtng',
    (ContainerKind.mp4, TagKey.artwork): 'covr',

    // ID3v1 field mappings (limited set)
    (ContainerKind.id3v1, TagKey.title): 'title',
    (ContainerKind.id3v1, TagKey.artist): 'artist',
    (ContainerKind.id3v1, TagKey.album): 'album',
    (ContainerKind.id3v1, TagKey.year): 'year',
    (ContainerKind.id3v1, TagKey.genre): 'genre',
    (ContainerKind.id3v1, TagKey.trackNumber): 'track',
    (ContainerKind.id3v1, TagKey.comment): 'comment',
  };

  @override
  bool appliesTo((ContainerKind, String) source, (ContainerKind, String) target) {
    // This rule applies to any cross-format conversion
    return source.$1 != target.$1;
  }

  @override
  Set<TagKey> handledTags() {
    // Return all tag keys that have mappings in any format
    return _formatFieldMappings.keys.map((key) => key.$2).toSet();
  }

  @override
  String get description => 'Cross-format field mapping between container formats';

  @override
  ConversionRuleResult convert(
    List<MetadataTag> inputTags,
    ConversionContext context,
  ) {
    if (inputTags.isEmpty) {
      return ConversionRuleResult.noChange();
    }

    final convertedTags = <MetadataTag>[];
    final appliedActions = <TagKey, ConversionAction>{};
    final warnings = <ConversionWarning>[];
    final errors = <ConversionError>[];

    for (final tag in inputTags) {
      try {
        final convertedTag = _convertSingleTag(tag, context);

        if (convertedTag != null) {
          convertedTags.add(convertedTag);

          // Determine conversion action based on what happened
          if (_isDirectMapping(tag.key, context)) {
            appliedActions[tag.key] = ConversionAction.directMapping;
          } else if (_requiresDataTransformation(tag.key, context)) {
            appliedActions[tag.key] = ConversionAction.dataTypeChange;
          } else {
            appliedActions[tag.key] = ConversionAction.noChange;
          }
        } else {
          // Tag cannot be mapped to target format
          if (context.mode == ConversionMode.strict) {
            errors.add(
              ConversionError(
                tagKey: tag.key,
                message: 'Tag ${tag.key.name} not supported in target format ${context.targetFormat.$1.name}',
                originalTag: tag,
              ),
            );
          } else {
            // In permissive/conservative mode, drop unsupported tags with warning
            warnings.add(
              ConversionWarning(
                tagKey: tag.key,
                message: 'Tag ${tag.key.name} dropped - not supported in target format',
                action: ConversionAction.dropped,
              ),
            );
            appliedActions[tag.key] = ConversionAction.dropped;
          }
        }
      } catch (e) {
        errors.add(
          ConversionError(
            tagKey: tag.key,
            message: 'Failed to convert ${tag.key.name}: ${e.toString()}',
            originalTag: tag,
          ),
        );
      }
    }

    return ConversionRuleResult(
      convertedTags: convertedTags,
      warnings: warnings,
      errors: errors,
      appliedActions: appliedActions,
      success: errors.isEmpty,
    );
  }

  /// Converts a single tag to the target format.
  MetadataTag? _convertSingleTag(MetadataTag tag, ConversionContext context) {
    // Check if target format supports this tag key
    if (!context.targetCapabilities.supports(tag.key)) {
      return null; // Tag not supported in target format
    }

    // For now, return the tag as-is since the actual tag creation logic
    // would need to integrate with the existing MetadataTag hierarchy.
    // In a full implementation, this would create a new tag instance
    // with updated provenance reflecting the target format.
    return tag;
  }

  /// Checks if conversion involves direct field mapping.
  bool _isDirectMapping(TagKey tagKey, ConversionContext context) {
    final sourceMapping = _formatFieldMappings[(context.sourceFormat.$1, tagKey)];
    final targetMapping = _formatFieldMappings[(context.targetFormat.$1, tagKey)];

    return sourceMapping != null && targetMapping != null && sourceMapping != targetMapping;
  }

  /// Checks if conversion requires data transformation.
  bool _requiresDataTransformation(TagKey tagKey, ConversionContext context) {
    // Some conversions require data format changes:
    // - Date fields between formats with different date handling
    // - Genre between numeric and text representations
    // - Multi-value fields with different separator conventions

    switch (tagKey) {
      case TagKey.year:
      case TagKey.dateRecorded:
        // Date handling varies between formats and versions
        return _requiresDateTransformation(context);
      case TagKey.genre:
        // Genre handling varies between formats
        return _requiresGenreTransformation(context);
      case TagKey.trackNumber:
      case TagKey.discNumber:
        // Number formats may vary
        return _requiresNumberTransformation(context);
      default:
        return false;
    }
  }

  /// Checks if date transformation is needed.
  bool _requiresDateTransformation(ConversionContext context) {
    // Different formats handle dates differently:
    // - ID3v1: 4-digit year only
    // - ID3v2.3: Separate TYER, TDAT, TIME frames
    // - ID3v2.4: Consolidated TDRC frame with ISO-8601
    // - Vorbis: DATE field with flexible format
    // - MP4: ©day atom with various formats

    final source = context.sourceFormat;
    final target = context.targetFormat;

    // ID3v2.3 ↔ ID3v2.4 requires date frame transformation
    if (source.$1 == ContainerKind.id3v2 && target.$1 == ContainerKind.id3v2) {
      return source.$2 != target.$2; // Different ID3v2 versions
    }

    // Cross-format conversions generally need date transformation
    return context.isCrossFormat;
  }

  /// Checks if genre transformation is needed.
  bool _requiresGenreTransformation(ConversionContext context) {
    // ID3v1 uses numeric genre codes, others typically use text
    return context.sourceFormat.$1 == ContainerKind.id3v1 || context.targetFormat.$1 == ContainerKind.id3v1;
  }

  /// Checks if number format transformation is needed.
  bool _requiresNumberTransformation(ConversionContext context) {
    // Different formats handle track/disc numbers differently:
    // - ID3v1: Single byte (1-255)
    // - ID3v2: "track/total" format in text
    // - MP4: Binary packed format
    // - Vorbis: Text numbers

    return context.isCrossFormat;
  }

  @override
  ConversionLossAssessment assessLoss(
    List<MetadataTag> inputTags,
    ConversionContext context,
  ) {
    final lossless = <TagKey>[];
    final modified = <TagKey, String>{};
    final dropped = <TagKey, String>{};

    for (final tag in inputTags) {
      if (!context.targetCapabilities.supports(tag.key)) {
        dropped[tag.key] = 'Tag not supported in target format';
      } else if (_requiresDataTransformation(tag.key, context)) {
        modified[tag.key] = 'Data format transformation required';
      } else {
        lossless.add(tag.key);
      }
    }

    // Determine preservation level
    DataPreservationLevel level;
    if (dropped.isEmpty && modified.isEmpty) {
      level = DataPreservationLevel.perfect;
    } else if (dropped.isEmpty) {
      level = DataPreservationLevel.excellent; // Format changes but no data loss
    } else if (dropped.length / inputTags.length <= 0.2) {
      level = DataPreservationLevel.good;
    } else {
      level = DataPreservationLevel.limited;
    }

    return ConversionLossAssessment(
      losslessTags: lossless,
      modifiedTags: modified,
      droppedTags: dropped,
      preservationLevel: level,
    );
  }
}
