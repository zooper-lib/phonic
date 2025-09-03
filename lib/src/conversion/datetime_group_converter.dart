import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_key.dart';
import 'base_conversion_rule.dart';
import 'conversion_rule_result.dart';
import 'metadata_converter.dart';

/// Specialized converter for date/time related tag conflicts and format differences.
///
/// This converter handles all date/time tag conversions including:
/// - Year ↔ DateRecorded conflicts (ID3v2.3 TYER vs ID3v2.4 TDRC)
/// - Cross-format date representations (ID3 → Vorbis → MP4)
/// - Date format normalization and validation
///
/// Key conversions handled:
/// - ID3v2.3 TYER (year only) ↔ ID3v2.4 TDRC (full date/time)
/// - ID3 date frames → Vorbis DATE/YEAR comments
/// - MP4 date atoms (©day) format conversions
/// - Date validation and format normalization
///
/// This follows the clean architecture principle of one converter per logical
/// tag group, with single responsibility for date/time conversions.
class DateTimeGroupConverter extends BaseConversionRule {
  @override
  String get description => 'Date/time tag group conversions (Year ↔ DateRecorded, cross-format dates)';

  @override
  Set<TagKey> handledTags() => {
    TagKey.year,
    TagKey.dateRecorded,
  };

  @override
  bool appliesTo((ContainerKind, String) source, (ContainerKind, String) target) {
    // Only apply when there are potential date/time conflicts or format differences

    // ID3v2 version transitions (Year ↔ DateRecorded frame conflicts)
    if (source.$1 == ContainerKind.id3v2 && target.$1 == ContainerKind.id3v2) {
      // ID3v2.3 uses TYER, ID3v2.4 uses TDRC
      return (source.$2 == '2.3' && target.$2 == '2.4') || (source.$2 == '2.4' && target.$2 == '2.3');
    }

    // Cross-format conversions (different date representations)
    if (source.$1 != target.$1) {
      // Different container formats may have different date field semantics
      return _hasDateFormatDifferences(source.$1, target.$1);
    }

    return false;
  }

  @override
  ConversionRuleResult convert(List<MetadataTag> inputTags, ConversionContext context) {
    final convertedTags = <MetadataTag>[];
    final warnings = <ConversionWarning>[];
    final errors = <ConversionError>[];
    final actions = <TagKey, ConversionAction>{};

    // Group date-related tags for processing
    final dateTagsByKey = <TagKey, MetadataTag>{};
    for (final tag in inputTags) {
      if (handledTags().contains(tag.key)) {
        dateTagsByKey[tag.key] = tag;
      }
    }

    // Handle ID3v2 version transitions
    if (context.sourceFormat.$1 == ContainerKind.id3v2 && context.targetFormat.$1 == ContainerKind.id3v2) {
      final result = _handleID3VersionTransition(dateTagsByKey, context);
      convertedTags.addAll(result.convertedTags);
      warnings.addAll(result.warnings);
      errors.addAll(result.errors);
      actions.addAll(result.appliedActions);
    }
    // Handle cross-format conversions
    else if (context.sourceFormat.$1 != context.targetFormat.$1) {
      final result = _handleCrossFormatConversion(dateTagsByKey, context);
      convertedTags.addAll(result.convertedTags);
      warnings.addAll(result.warnings);
      errors.addAll(result.errors);
      actions.addAll(result.appliedActions);
    }

    return ConversionRuleResult(
      convertedTags: convertedTags,
      warnings: warnings,
      errors: errors,
      success: errors.isEmpty,
      appliedActions: actions,
    );
  }

  /// Handles date/time conversions between ID3v2 versions.
  ///
  /// Key transitions:
  /// - ID3v2.3 → ID3v2.4: TYER → TDRC (year to full date)
  /// - ID3v2.4 → ID3v2.3: TDRC → TYER (full date to year only)
  ConversionRuleResult _handleID3VersionTransition(
    Map<TagKey, MetadataTag> dateTagsByKey,
    ConversionContext context,
  ) {
    final convertedTags = <MetadataTag>[];
    final warnings = <ConversionWarning>[];
    final actions = <TagKey, ConversionAction>{};
    final sourceVersion = context.sourceFormat.$2;
    final targetVersion = context.targetFormat.$2;

    // ID3v2.3 → ID3v2.4: Convert TYER to TDRC
    if (sourceVersion == '2.3' && targetVersion == '2.4') {
      final yearTag = dateTagsByKey[TagKey.year];
      if (yearTag != null) {
        final dateRecordedTag = _convertYearToDateRecorded(yearTag);
        if (dateRecordedTag != null) {
          convertedTags.add(dateRecordedTag);
          actions[TagKey.year] = ConversionAction.expansion;
          actions[TagKey.dateRecorded] = ConversionAction.expansion;
        } else {
          warnings.add(
            ConversionWarning(
              tagKey: TagKey.year,
              message: 'Could not convert year "${yearTag.value}" to date format',
              action: ConversionAction.noChange,
            ),
          );
        }
      }
    }
    // ID3v2.4 → ID3v2.3: Convert TDRC to TYER
    else if (sourceVersion == '2.4' && targetVersion == '2.3') {
      final dateRecordedTag = dateTagsByKey[TagKey.dateRecorded];
      if (dateRecordedTag != null) {
        final yearTag = _convertDateRecordedToYear(dateRecordedTag);
        if (yearTag != null) {
          convertedTags.add(yearTag);
          actions[TagKey.dateRecorded] = ConversionAction.consolidation;
          actions[TagKey.year] = ConversionAction.consolidation;
        } else {
          warnings.add(
            ConversionWarning(
              tagKey: TagKey.dateRecorded,
              message: 'Could not extract year from date "${dateRecordedTag.value}"',
              action: ConversionAction.noChange,
            ),
          );
        }
      }
    }

    return ConversionRuleResult(
      convertedTags: convertedTags,
      warnings: warnings,
      errors: [],
      success: true,
      appliedActions: actions,
    );
  }

  /// Handles date/time conversions between different container formats.
  ///
  /// Supports conversions between:
  /// - ID3 (TYER/TDRC frames) ↔ Vorbis (DATE/YEAR comments)
  /// - ID3/Vorbis ↔ MP4 (©day atom)
  /// - Format-specific date representations and constraints
  ConversionRuleResult _handleCrossFormatConversion(
    Map<TagKey, MetadataTag> dateTagsByKey,
    ConversionContext context,
  ) {
    final convertedTags = <MetadataTag>[];
    final warnings = <ConversionWarning>[];
    final actions = <TagKey, ConversionAction>{};

    for (final entry in dateTagsByKey.entries) {
      final tagKey = entry.key;
      final tag = entry.value;

      final convertedTag = _convertDateTagAcrossFormats(tag, context);
      if (convertedTag != null) {
        convertedTags.add(convertedTag);
        actions[tagKey] = _getConversionAction(context.sourceFormat.$1, context.targetFormat.$1);
      } else {
        warnings.add(
          ConversionWarning(
            tagKey: tagKey,
            message: 'Could not convert ${tagKey.name} from ${context.sourceFormat.$1.name} to ${context.targetFormat.$1.name}',
            action: ConversionAction.noChange,
          ),
        );
      }
    }

    return ConversionRuleResult(
      convertedTags: convertedTags,
      warnings: warnings,
      errors: [],
      success: true,
      appliedActions: actions,
    );
  }

  /// Converts a year tag to a date recorded tag (ID3v2.3 → ID3v2.4).
  MetadataTag? _convertYearToDateRecorded(MetadataTag yearTag) {
    final yearString = yearTag.value.toString().trim();

    // Validate year format
    final yearMatch = RegExp(r'^(\d{4})$').firstMatch(yearString);
    if (yearMatch == null) {
      return null;
    }

    // Create DateRecorded tag with the year (ID3v2.4 TDRC format)
    return DateRecordedTag(yearString);
  }

  /// Converts a date recorded tag to a year tag (ID3v2.4 → ID3v2.3).
  MetadataTag? _convertDateRecordedToYear(MetadataTag dateRecordedTag) {
    final dateString = dateRecordedTag.value.toString().trim();

    // Extract year from various date formats
    final year = _extractYearFromDate(dateString);
    if (year == null) {
      return null;
    }

    // Create Year tag (ID3v2.3 TYER format)
    return YearTag(year);
  }

  /// Converts date tags between different container formats.
  MetadataTag? _convertDateTagAcrossFormats(MetadataTag tag, ConversionContext context) {
    final sourceFormat = context.sourceFormat.$1;
    final targetFormat = context.targetFormat.$1;

    // Normalize the date value first
    final normalizedDate = _normalizeDateValue(tag.value.toString(), sourceFormat);
    if (normalizedDate == null) {
      return null;
    }

    // Convert to target format representation
    return _createDateTagForFormat(tag.key, normalizedDate, targetFormat);
  }

  /// Extracts a year from various date string formats.
  int? _extractYearFromDate(String dateString) {
    // Try various date formats
    final patterns = [
      RegExp(r'^(\d{4})$'), // YYYY
      RegExp(r'^(\d{4})-\d{2}-\d{2}'), // YYYY-MM-DD (ISO 8601)
      RegExp(r'^(\d{4})-\d{2}'), // YYYY-MM
      RegExp(r'^(\d{4})/\d{2}/\d{2}'), // YYYY/MM/DD
      RegExp(r'^(\d{4})\.\d{2}\.\d{2}'), // YYYY.MM.DD
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateString);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }

    return null;
  }

  /// Normalizes date values from source format to internal representation.
  String? _normalizeDateValue(String dateValue, ContainerKind sourceFormat) {
    final trimmedValue = dateValue.trim();
    if (trimmedValue.isEmpty) return null;

    switch (sourceFormat) {
      case ContainerKind.id3v2:
        // ID3v2 can have YYYY or full ISO 8601 dates
        return _normalizeID3Date(trimmedValue);

      case ContainerKind.vorbis:
        // Vorbis comments typically use DATE field with various formats
        return _normalizeVorbisDate(trimmedValue);

      case ContainerKind.mp4:
        // MP4 uses ©day atom with various formats
        return _normalizeMP4Date(trimmedValue);

      default:
        return trimmedValue;
    }
  }

  /// Creates a date tag appropriate for the target format.
  MetadataTag? _createDateTagForFormat(TagKey tagKey, String normalizedDate, ContainerKind targetFormat) {
    switch (targetFormat) {
      case ContainerKind.id3v2:
        // ID3v2.4 prefers full dates, ID3v2.3 prefers year only
        if (tagKey == TagKey.year) {
          final year = _extractYearFromDate(normalizedDate);
          return year != null ? YearTag(year) : null;
        } else if (tagKey == TagKey.dateRecorded) {
          return DateRecordedTag(normalizedDate);
        }
        break;

      case ContainerKind.vorbis:
        // Vorbis uses text-based date fields
        if (tagKey == TagKey.year) {
          final year = _extractYearFromDate(normalizedDate);
          return year != null ? YearTag(year) : null;
        } else if (tagKey == TagKey.dateRecorded) {
          return DateRecordedTag(normalizedDate);
        }
        break;

      case ContainerKind.mp4:
        // MP4 uses specific atom formats
        if (tagKey == TagKey.year) {
          final year = _extractYearFromDate(normalizedDate);
          return year != null ? YearTag(year) : null;
        } else if (tagKey == TagKey.dateRecorded) {
          return DateRecordedTag(normalizedDate);
        }
        break;

      default:
        if (tagKey == TagKey.year) {
          final year = _extractYearFromDate(normalizedDate);
          return year != null ? YearTag(year) : null;
        } else if (tagKey == TagKey.dateRecorded) {
          return DateRecordedTag(normalizedDate);
        }
        break;
    }

    return null;
  }

  /// Normalizes ID3v2 date values.
  String? _normalizeID3Date(String value) {
    // Handle YYYY format
    if (RegExp(r'^\d{4}$').hasMatch(value)) {
      return value; // Already normalized year
    }

    // Handle ISO 8601 formats
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return value; // Valid ISO 8601 date
    }

    return null;
  }

  /// Normalizes Vorbis comment date values.
  String? _normalizeVorbisDate(String value) {
    // Vorbis is flexible with date formats
    return value.isNotEmpty ? value : null;
  }

  /// Normalizes MP4 date atom values.
  String? _normalizeMP4Date(String value) {
    // MP4 typically uses ISO 8601 or year-only formats
    return value.isNotEmpty ? value : null;
  }

  /// Checks if two container formats have different date representation requirements.
  bool _hasDateFormatDifferences(ContainerKind source, ContainerKind target) {
    // Different container formats have different date field semantics
    final formatPairs = {
      (ContainerKind.id3v2, ContainerKind.vorbis),
      (ContainerKind.id3v2, ContainerKind.mp4),
      (ContainerKind.vorbis, ContainerKind.mp4),
      (ContainerKind.vorbis, ContainerKind.id3v2),
      (ContainerKind.mp4, ContainerKind.id3v2),
      (ContainerKind.mp4, ContainerKind.vorbis),
    };

    return formatPairs.contains((source, target));
  }

  /// Determines the appropriate conversion action for cross-format date conversion.
  ConversionAction _getConversionAction(ContainerKind source, ContainerKind target) {
    // Cross-format conversions typically involve data type or representation changes
    return ConversionAction.dataTypeChange;
  }
}
