import '../core/container_kind.dart';
import '../core/metadata_tag.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';
import '../core/tag_semantics.dart';
import 'capability_constraint_rule.dart';
import 'conversion_rule.dart';
import 'datetime_group_converter.dart';
import 'metadata_converter.dart';
import 'multi_value_delimiter_rule.dart';

/// Unified metadata converter that replaces SemanticTagConverter and GenericMetadataConverter.
///
/// This converter provides a dynamic, rule-based approach to metadata conversion
/// that eliminates the duplicate logic found in the previous converters. It uses
/// a pluggable rule system to handle different conversion scenarios.
class UnifiedMetadataConverter implements MetadataConverter {
  /// Map of format combinations to their capabilities.
  final Map<(ContainerKind, String), TagCapability> _capabilities = {};

  /// Registry of conversion rules.
  final List<ConversionRule> _conversionRules = [];

  /// Creates a new unified metadata converter.
  ///
  /// Initializes format capabilities and registers default conversion rules.
  UnifiedMetadataConverter() {
    _initializeCapabilities();
    _registerDefaultRules();
  }

  @override
  ConversionResult convertTags(
    List<MetadataTag> sourceTags,
    (ContainerKind, String) sourceFormat,
    (ContainerKind, String) targetFormat,
    ConversionOptions options,
  ) {
    final context = ConversionContext(
      sourceFormat: sourceFormat,
      targetFormat: targetFormat,
      mode: options.mode,
      sourceCapabilities: _getCapabilities(sourceFormat),
      targetCapabilities: _getCapabilities(targetFormat),
      options: options.preferences,
    );

    return _performConversion(sourceTags, context);
  }

  @override
  ConversionAnalysis analyzeConversion(
    List<MetadataTag> sourceTags,
    (ContainerKind, String) sourceFormat,
    (ContainerKind, String) targetFormat,
  ) {
    final losslessTags = <TagKey>[];
    final modifiedTags = <TagKey>[];
    final droppedTags = <TagKey>[];
    final limitations = <TagKey, String>{};

    // If same format, all tags will be preserved as-is
    if (sourceFormat == targetFormat) {
      losslessTags.addAll(sourceTags.map((tag) => tag.key));

      return ConversionAnalysis(
        losslessTags: losslessTags,
        modifiedTags: modifiedTags,
        droppedTags: droppedTags,
        viability: ConversionViability.perfect,
        limitations: limitations,
      );
    }

    try {
      final sourceCapability = _getCapabilities(sourceFormat);
      final targetCapability = _getCapabilities(targetFormat);

      for (final tag in sourceTags) {
        final tagKey = tag.key;
        final isTargetSupported = targetCapability.semanticsByKey.containsKey(tagKey);

        if (!isTargetSupported) {
          droppedTags.add(tagKey);
          limitations[tagKey] = 'Tag not supported by target format';
          continue;
        }

        // Check if any conversion rules would apply
        bool willBeConverted = false;
        for (final rule in _conversionRules) {
          if (rule.appliesTo(sourceFormat, targetFormat) && rule.handledTags().contains(tagKey)) {
            willBeConverted = true;
            break;
          }
        }

        if (willBeConverted) {
          modifiedTags.add(tagKey);
        } else {
          // Check for potential data loss due to format constraints
          final sourceSemantics = sourceCapability.semanticsByKey[tagKey];
          final targetSemantics = targetCapability.semanticsByKey[tagKey];

          if (sourceSemantics != null && targetSemantics != null) {
            final hasConstraintDifferences = _hasSemanticDifferences(sourceSemantics, targetSemantics);
            if (hasConstraintDifferences) {
              modifiedTags.add(tagKey);
            } else {
              losslessTags.add(tagKey);
            }
          } else {
            losslessTags.add(tagKey);
          }
        }
      }

      // Determine overall viability
      ConversionViability viability;
      if (droppedTags.isEmpty && modifiedTags.isEmpty) {
        viability = ConversionViability.perfect;
      } else if (droppedTags.isEmpty) {
        viability = ConversionViability.good;
      } else if (droppedTags.length < sourceTags.length) {
        viability = ConversionViability.limited;
      } else {
        viability = ConversionViability.poor;
      }

      return ConversionAnalysis(
        losslessTags: losslessTags,
        modifiedTags: modifiedTags,
        droppedTags: droppedTags,
        viability: viability,
        limitations: limitations,
      );
    } catch (e) {
      // If we can't get capabilities, assume all tags might be dropped
      droppedTags.addAll(sourceTags.map((tag) => tag.key));
      limitations[TagKey.title] = 'Unable to analyze conversion: ${e.toString()}';

      return ConversionAnalysis(
        losslessTags: losslessTags,
        modifiedTags: modifiedTags,
        droppedTags: droppedTags,
        viability: ConversionViability.poor,
        limitations: limitations,
      );
    }
  }

  /// Checks if there are semantic differences between source and target that might cause data loss.
  bool _hasSemanticDifferences(TagSemantics source, TagSemantics target) {
    // Check for text length constraints
    if (source.maxTextLength == null && target.maxTextLength != null) {
      return true; // Might truncate
    }
    if (source.maxTextLength != null && target.maxTextLength != null && source.maxTextLength! > target.maxTextLength!) {
      return true; // Will truncate
    }

    // Check for numeric range constraints
    if (source.minValue != null || source.maxValue != null || target.minValue != null || target.maxValue != null) {
      final sourceMin = source.minValue ?? double.negativeInfinity;
      final sourceMax = source.maxValue ?? double.infinity;
      final targetMin = target.minValue ?? double.negativeInfinity;
      final targetMax = target.maxValue ?? double.infinity;

      if (sourceMin < targetMin || sourceMax > targetMax) {
        return true; // Might clamp values
      }
    }

    // Check for multi-value support differences
    if (source.multiValued == true && target.multiValued != true) {
      return true; // Might lose additional values
    }

    // Check for encoding support differences
    if (source.allowedEncodings != null && target.allowedEncodings != null) {
      final sourceEncodings = source.allowedEncodings!;
      final targetEncodings = target.allowedEncodings!;

      // If source has encodings not supported by target
      if (!targetEncodings.containsAll(sourceEncodings)) {
        return true; // Might need encoding conversion
      }
    }

    return false; // No significant differences
  }

  /// Gets capabilities for a specific format version.
  TagCapability _getCapabilities((ContainerKind, String) format) {
    final capability = _capabilities[format];
    if (capability != null) {
      return capability;
    }

    // Special handling for ContainerKind.none - any version maps to the generic one
    if (format.$1 == ContainerKind.none) {
      final noneCapability = _capabilities[(ContainerKind.none, '')];
      if (noneCapability != null) {
        return noneCapability;
      }
    }

    throw UnsupportedError('No capabilities defined for format: $format');
  }

  /// Performs the actual conversion using registered rules.
  ConversionResult _performConversion(
    List<MetadataTag> sourceTags,
    ConversionContext context,
  ) {
    List<MetadataTag> processedTags = List.from(sourceTags);
    final warnings = <ConversionWarning>[];
    final errors = <ConversionError>[];
    final appliedConversions = <TagKey, ConversionAction>{};

    for (final rule in _conversionRules) {
      if (rule.appliesTo(context.sourceFormat, context.targetFormat)) {
        final relevantTags = processedTags.where((tag) => rule.handledTags().contains(tag.key)).toList();

        if (relevantTags.isNotEmpty) {
          final result = rule.convert(relevantTags, context);

          // Update processed tags with rule results
          final updatedTagMap = Map<TagKey, MetadataTag>.fromEntries(processedTags.map((tag) => MapEntry(tag.key, tag)));

          for (final tag in result.convertedTags) {
            updatedTagMap[tag.key] = tag;
            appliedConversions[tag.key] = ConversionAction.customLogic;
          }

          processedTags = updatedTagMap.values.toList();
          warnings.addAll(result.warnings);
          errors.addAll(result.errors);
        }
      }
    }

    final isLossless = warnings.isEmpty && errors.isEmpty;

    return ConversionResult(
      convertedTags: processedTags,
      warnings: warnings,
      errors: errors,
      isLossless: isLossless,
      summary: ConversionSummary(
        totalInputTags: sourceTags.length,
        convertedTags: processedTags.length,
        droppedTags: errors.length,
        modifiedTags: warnings.length,
      ),
      appliedConversions: appliedConversions,
    );
  }

  /// Registers default conversion rules.
  void _registerDefaultRules() {
    _conversionRules.addAll([
      DateTimeGroupConverter(),
      CapabilityConstraintRule(),
      MultiValueDelimiterRule(),
    ]);
  }

  /// Initializes format capabilities.
  void _initializeCapabilities() {
    // None/Generic capabilities (for unknown or mixed source formats)
    _capabilities[(ContainerKind.none, '')] = TagCapability(
      containerKind: ContainerKind.none,
      containerVersion: '',
      semanticsByKey: Map.fromEntries(
        TagKey.values.map(
          (key) => MapEntry(
            key,
            const TagSemantics(
              multiValued: true, // Most permissive to avoid data loss
              allowedEncodings: {'UTF-8'},
            ),
          ),
        ),
      ),
    );

    // ID3v1 capabilities
    _capabilities[(ContainerKind.id3v1, 'v1')] = const TagCapability(
      containerKind: ContainerKind.id3v1,
      containerVersion: 'v1',
      semanticsByKey: {
        TagKey.title: const TagSemantics(maxTextLength: 30),
        TagKey.artist: const TagSemantics(maxTextLength: 30),
        TagKey.album: const TagSemantics(maxTextLength: 30),
        TagKey.year: const TagSemantics(maxTextLength: 4),
        TagKey.comment: const TagSemantics(maxTextLength: 30),
        TagKey.trackNumber: const TagSemantics(minValue: 1, maxValue: 255),
        TagKey.genre: const TagSemantics(minValue: 0, maxValue: 255),
      },
    );

    // ID3v2.3 capabilities
    _capabilities[(ContainerKind.id3v2, '2.3')] = TagCapability(
      containerKind: ContainerKind.id3v2,
      containerVersion: '2.3',
      semanticsByKey: Map.fromEntries(
        TagKey.values.map(
          (key) => MapEntry(
            key,
            const TagSemantics(
              multiValued: false,
              allowedEncodings: {'ISO-8859-1', 'UTF-16'},
            ),
          ),
        ),
      ),
    );

    // ID3v2.4 capabilities
    _capabilities[(ContainerKind.id3v2, '2.4')] = TagCapability(
      containerKind: ContainerKind.id3v2,
      containerVersion: '2.4',
      semanticsByKey: Map.fromEntries(
        TagKey.values.map(
          (key) => MapEntry(
            key,
            const TagSemantics(
              multiValued: false,
              allowedEncodings: {'ISO-8859-1', 'UTF-16', 'UTF-8'},
            ),
          ),
        ),
      ),
    );

    // Vorbis capabilities
    _capabilities[(ContainerKind.vorbis, '')] = TagCapability(
      containerKind: ContainerKind.vorbis,
      containerVersion: '',
      semanticsByKey: Map.fromEntries(
        TagKey.values.map(
          (key) => MapEntry(
            key,
            const TagSemantics(
              multiValued: true,
              allowedEncodings: {'UTF-8'},
            ),
          ),
        ),
      ),
    );

    // MP4 capabilities
    _capabilities[(ContainerKind.mp4, '')] = TagCapability(
      containerKind: ContainerKind.mp4,
      containerVersion: '',
      semanticsByKey: Map.fromEntries(
        [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          TagKey.trackNumber,
          TagKey.discNumber,
          TagKey.year,
          TagKey.genre,
          TagKey.comment,
          TagKey.composer,
          TagKey.artwork,
        ].map(
          (key) => MapEntry(
            key,
            const TagSemantics(
              multiValued: false,
              allowedEncodings: {'UTF-8'},
            ),
          ),
        ),
      ),
    );
  }
}
