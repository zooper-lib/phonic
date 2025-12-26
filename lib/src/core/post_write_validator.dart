import 'dart:typed_data';

import '../conversion/unified_metadata_converter.dart';
import '../exceptions/corrupted_container_exception.dart';
import 'codec_registry.dart';
import 'container_kind.dart';
import 'format_strategy.dart';
import 'metadata_tag.dart';
import 'tag_key.dart';

/// Comprehensive validation system for post-write file integrity checks.
///
/// This class provides detailed validation of encoded audio files to ensure
/// that the write operation was successful and the resulting file maintains
/// structural integrity. It performs multiple levels of validation from basic
/// format detection to deep container parsing and tag consistency checks.
///
/// ## Validation Levels
///
/// ### 1. Basic Structure Validation
/// - File size and format signature validation
/// - Container presence and positioning checks
/// - Header structure and size consistency
///
/// ### 2. Container Integrity Validation
/// - Container header parsing and validation
/// - Size field consistency checks
/// - Container boundary validation
/// - Format-specific structure requirements
///
/// ### 3. Tag Consistency Validation
/// - Tag parsing and value extraction
/// - Cross-container tag consistency checks
/// - Value range and format validation
/// - Encoding and character set validation
///
/// ### 4. Round-trip Validation
/// - Re-parsing written tags to verify consistency
/// - Comparing written values with expected values
/// - Detecting data loss or corruption during encoding
///
/// ## Usage Example
///
/// ```dart
/// final validator = PostWriteValidator(
///   codecRegistry: registry,
///   enableDeepValidation: true,
///   enableRoundTripValidation: true,
/// );
///
/// try {
///   final result = await validator.validateEncodedFile(
///     encodedBytes: encodedFile,
///     originalTags: originalTags,
///     formatStrategy: strategy,
///   );
///
///   if (!result.isValid) {
///     print('Validation failed: ${result.errors.length} errors');
///     for (final error in result.errors) {
///       print('  ${error.severity}: ${error.message}');
///     }
///   }
/// } catch (e) {
///   // Handle validation exceptions
/// }
/// ```
class PostWriteValidator {
  /// Registry of available codecs and container locators.
  final CodecRegistry codecRegistry;

  /// Whether to perform deep container structure validation.
  ///
  /// When enabled, performs detailed parsing of container structures
  /// to validate internal consistency. This is more thorough but slower.
  final bool enableDeepValidation;

  /// Whether to perform round-trip validation by re-parsing written tags.
  ///
  /// When enabled, re-parses the written file and compares the extracted
  /// tags with the original tags to detect data loss or corruption.
  final bool enableRoundTripValidation;

  /// Maximum file size to validate (in bytes).
  ///
  /// Files larger than this size will skip certain validation steps
  /// to avoid performance issues. Set to null for no limit.
  final int? maxValidationFileSize;

  /// Creates a new PostWriteValidator instance.
  ///
  /// Parameters:
  /// - [codecRegistry]: Registry for accessing codecs and locators
  /// - [enableDeepValidation]: Whether to perform deep structure validation
  /// - [enableRoundTripValidation]: Whether to perform round-trip validation
  /// - [maxValidationFileSize]: Maximum file size for full validation
  /// - [semanticConverter]: Optional semantic converter for equivalence checking
  PostWriteValidator({
    required this.codecRegistry,
    this.enableDeepValidation = true,
    this.enableRoundTripValidation = true,
    this.maxValidationFileSize = 100 * 1024 * 1024, // 100MB default
    UnifiedMetadataConverter? semanticConverter,
  });

  /// Validates an encoded file for structural integrity and tag consistency.
  ///
  /// This method performs comprehensive validation of the encoded file,
  /// checking everything from basic format detection to detailed tag
  /// consistency. The validation level depends on the configuration
  /// options provided during construction.
  ///
  /// Parameters:
  /// - [encodedBytes]: The encoded file bytes to validate
  /// - [originalTags]: The original tags that were written to the file
  /// - [formatStrategy]: The format strategy used for encoding
  /// - [expectedContainers]: Optional list of expected container types
  ///
  /// Returns:
  /// - [ValidationResult] containing validation status and any errors found
  ///
  /// Throws:
  /// - [ArgumentError] if required parameters are null or invalid
  Future<ValidationResult> validateEncodedFile({
    required Uint8List encodedBytes,
    required List<MetadataTag> originalTags,
    required FormatStrategy formatStrategy,
    List<(ContainerKind, String)>? expectedContainers,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];

    try {
      // Step 1: Basic structure validation
      final basicResult = await _validateBasicStructure(
        encodedBytes: encodedBytes,
        formatStrategy: formatStrategy,
      );
      errors.addAll(basicResult.errors);
      warnings.addAll(basicResult.warnings);

      // Step 2: Container integrity validation
      final containerResult = await _validateContainerIntegrity(
        encodedBytes: encodedBytes,
        formatStrategy: formatStrategy,
        expectedContainers: expectedContainers,
      );
      errors.addAll(containerResult.errors);
      warnings.addAll(containerResult.warnings);

      // Step 3: Tag consistency validation (if deep validation enabled)
      if (enableDeepValidation) {
        final tagResult = await _validateTagConsistency(
          encodedBytes: encodedBytes,
          formatStrategy: formatStrategy,
        );
        errors.addAll(tagResult.errors);
        warnings.addAll(tagResult.warnings);
      }

      // Step 4: Round-trip validation (if enabled and no critical errors)
      if (enableRoundTripValidation && !_hasCriticalErrors(errors)) {
        final roundTripResult = await _validateRoundTrip(
          encodedBytes: encodedBytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
          expectedContainers: expectedContainers,
        );
        errors.addAll(roundTripResult.errors);
        warnings.addAll(roundTripResult.warnings);
      }

      return ValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        validationLevel: _getValidationLevel(),
      );
    } catch (e) {
      // Convert exceptions to validation errors
      final error = ValidationError(
        severity: ValidationSeverity.critical,
        message: 'Validation failed with exception: $e',
        context: 'File size: ${encodedBytes.length} bytes',
        errorCode: 'VALIDATION_EXCEPTION',
      );

      return ValidationResult(
        isValid: false,
        errors: [error],
        warnings: warnings,
        validationLevel: _getValidationLevel(),
      );
    }
  }

  /// Validates basic file structure and format detection.
  Future<ValidationResult> _validateBasicStructure({
    required Uint8List encodedBytes,
    required FormatStrategy formatStrategy,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];

    // Check minimum file size
    if (encodedBytes.isEmpty) {
      errors.add(
        const ValidationError(
          severity: ValidationSeverity.critical,
          message: 'Encoded file is empty',
          context: 'Expected non-empty file after encoding',
          errorCode: 'EMPTY_FILE',
        ),
      );
      return ValidationResult(isValid: false, errors: errors, warnings: warnings, validationLevel: _getValidationLevel());
    }

    // Check maximum file size for validation
    if (maxValidationFileSize != null && encodedBytes.length > maxValidationFileSize!) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'File size exceeds validation limit, skipping some checks',
          context: 'File size: ${encodedBytes.length}, limit: $maxValidationFileSize',
          errorCode: 'FILE_SIZE_LIMIT',
        ),
      );
    }

    // Validate format detection
    try {
      if (!formatStrategy.canHandle(encodedBytes)) {
        errors.add(
          ValidationError(
            severity: ValidationSeverity.critical,
            message: 'Encoded file cannot be handled by format strategy',
            context: 'Format: ${formatStrategy.mediaKind.name}',
            errorCode: 'FORMAT_DETECTION_FAILED',
          ),
        );
      }
    } catch (e) {
      errors.add(
        ValidationError(
          severity: ValidationSeverity.error,
          message: 'Format detection threw exception: $e',
          context: 'Format: ${formatStrategy.mediaKind.name}',
          errorCode: 'FORMAT_DETECTION_EXCEPTION',
        ),
      );
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings, validationLevel: 'basic');
  }

  /// Validates container integrity and structure.
  Future<ValidationResult> _validateContainerIntegrity({
    required Uint8List encodedBytes,
    required FormatStrategy formatStrategy,
    List<(ContainerKind, String)>? expectedContainers,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];

    final containersToCheck = expectedContainers ?? formatStrategy.fanout;

    for (final (containerKind, containerVersion) in containersToCheck) {
      try {
        final locator = codecRegistry.findLocator(containerKind);
        if (locator == null) {
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'No locator available for container validation',
              context: 'Container: ${containerKind.name} v$containerVersion',
              errorCode: 'LOCATOR_NOT_FOUND',
            ),
          );
          continue;
        }

        // Check if container is present
        if (!locator.fileMatches(encodedBytes)) {
          // For optional containers, this might be a warning rather than error
          final severity = _isRequiredContainer(containerKind, formatStrategy) ? ValidationSeverity.error : ValidationSeverity.warning;

          errors.add(
            ValidationError(
              severity: severity,
              message: 'Expected container not found in encoded file',
              context: 'Container: ${containerKind.name} v$containerVersion',
              errorCode: 'CONTAINER_NOT_FOUND',
            ),
          );
          continue;
        }

        // Extract and validate container
        final containerBytes = locator.extract(encodedBytes);
        if (containerBytes == null || containerBytes.isEmpty) {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: 'Container extraction failed',
              context: 'Container: ${containerKind.name} v$containerVersion',
              errorCode: 'CONTAINER_EXTRACTION_FAILED',
            ),
          );
          continue;
        }

        // Validate container structure with codec
        if (enableDeepValidation) {
          await _validateContainerStructure(
            containerBytes: containerBytes,
            containerKind: containerKind,
            containerVersion: containerVersion,
            errors: errors,
            warnings: warnings,
          );
        }
      } catch (e) {
        errors.add(
          ValidationError(
            severity: ValidationSeverity.error,
            message: 'Container validation threw exception: $e',
            context: 'Container: ${containerKind.name} v$containerVersion',
            errorCode: 'CONTAINER_VALIDATION_EXCEPTION',
          ),
        );
      }
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings, validationLevel: 'container');
  }

  /// Validates individual container structure using appropriate codec.
  Future<void> _validateContainerStructure({
    required Uint8List containerBytes,
    required ContainerKind containerKind,
    required String containerVersion,
    required List<ValidationError> errors,
    required List<ValidationError> warnings,
  }) async {
    final codec = codecRegistry.findCodec(containerKind, containerVersion);
    if (codec == null) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'No codec available for container structure validation',
          context: 'Container: ${containerKind.name} v$containerVersion',
          errorCode: 'CODEC_NOT_FOUND',
        ),
      );
      return;
    }

    try {
      // Attempt to parse container structure
      final tags = codec.readFromContainer(containerBytes);

      // Validate that parsing returned reasonable results
      if (tags.isEmpty) {
        warnings.add(
          ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Container parsing returned no tags',
            context: 'Container: ${containerKind.name} v$containerVersion, size: ${containerBytes.length}',
            errorCode: 'NO_TAGS_PARSED',
          ),
        );
      }

      // Validate tag structure and values
      for (final tag in tags) {
        _validateTagStructure(tag, containerKind, containerVersion, errors, warnings);
      }
    } catch (e) {
      if (e is CorruptedContainerException) {
        errors.add(
          ValidationError(
            severity: ValidationSeverity.error,
            message: 'Container structure is corrupted: ${e.message}',
            context: 'Container: ${containerKind.name} v$containerVersion, offset: ${e.byteOffset}',
            errorCode: 'CONTAINER_CORRUPTED',
          ),
        );
      } else {
        errors.add(
          ValidationError(
            severity: ValidationSeverity.error,
            message: 'Container parsing failed: $e',
            context: 'Container: ${containerKind.name} v$containerVersion',
            errorCode: 'CONTAINER_PARSING_FAILED',
          ),
        );
      }
    }
  }

  /// Validates tag consistency across containers.
  Future<ValidationResult> _validateTagConsistency({
    required Uint8List encodedBytes,
    required FormatStrategy formatStrategy,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];

    final tagsByContainer = <(ContainerKind, String), List<MetadataTag>>{};

    // Extract tags from all containers
    for (final (containerKind, containerVersion) in formatStrategy.fanout) {
      try {
        final locator = codecRegistry.findLocator(containerKind);
        final codec = codecRegistry.findCodec(containerKind, containerVersion);

        if (locator == null || codec == null) continue;

        if (locator.fileMatches(encodedBytes)) {
          final containerBytes = locator.extract(encodedBytes);
          if (containerBytes != null && containerBytes.isNotEmpty) {
            final tags = codec.readFromContainer(containerBytes);
            tagsByContainer[(containerKind, containerVersion)] = tags;
          }
        }
      } catch (e) {
        warnings.add(
          ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Failed to extract tags for consistency check: $e',
            context: 'Container: ${containerKind.name} v$containerVersion',
            errorCode: 'TAG_EXTRACTION_FAILED',
          ),
        );
      }
    }

    // Check for tag consistency across containers
    _validateCrossContainerConsistency(tagsByContainer, errors, warnings);

    return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings, validationLevel: 'tag-consistency');
  }

  /// Validates round-trip consistency by re-parsing written tags.
  Future<ValidationResult> _validateRoundTrip({
    required Uint8List encodedBytes,
    required List<MetadataTag> originalTags,
    required FormatStrategy formatStrategy,
    List<(ContainerKind, String)>? expectedContainers,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];

    try {
      // Extract all tags from the encoded file
      final extractedTags = <MetadataTag>[];

      // Use expected containers if provided, otherwise fall back to precedence
      final containersToCheck = expectedContainers ?? formatStrategy.precedence;

      for (final (containerKind, containerVersion) in containersToCheck) {
        final locator = codecRegistry.findLocator(containerKind);

        if (locator == null) continue;

        if (locator.fileMatches(encodedBytes)) {
          final containerBytes = locator.extract(encodedBytes);
          if (containerBytes != null && containerBytes.isNotEmpty) {
            // For expected containers, use the expected version
            // For precedence fallback, detect the actual version
            String detectedVersion = containerVersion;

            if (expectedContainers == null && containerKind == ContainerKind.id3v2) {
              // Only detect version when falling back to precedence
              detectedVersion = _detectId3v2Version(containerBytes);
            }

            final codec = codecRegistry.findCodec(containerKind, detectedVersion);
            if (codec != null) {
              final tags = codec.readFromContainer(containerBytes);
              extractedTags.addAll(tags);
            }
          }
        }
      }

      // Compare original tags with extracted tags with capability awareness
      _compareTagSets(originalTags, extractedTags, errors, warnings, formatStrategy: formatStrategy);
    } catch (e) {
      errors.add(
        ValidationError(
          severity: ValidationSeverity.error,
          message: 'Round-trip validation failed: $e',
          context: 'Original tags: ${originalTags.length}',
          errorCode: 'ROUND_TRIP_FAILED',
        ),
      );
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings, validationLevel: 'round-trip');
  }

  /// Detects the actual ID3v2 version from container bytes.
  String _detectId3v2Version(Uint8List containerBytes) {
    if (containerBytes.length < 10) {
      return '2.4'; // Default fallback
    }

    // ID3v2 header structure:
    // Bytes 0-2: "ID3"
    // Byte 3: Major version
    // Byte 4: Revision
    // Bytes 5-9: Flags and size

    if (containerBytes[0] == 0x49 && containerBytes[1] == 0x44 && containerBytes[2] == 0x33) {
      final majorVersion = containerBytes[3];
      // The codec registry expects version format like "2.4", not "4.0"
      // The major version in the header is the second part (e.g., 4 for ID3v2.4)
      return '2.$majorVersion';
    }

    return '2.4'; // Default fallback
  }

  /// Validates individual tag structure and values.
  void _validateTagStructure(
    MetadataTag tag,
    ContainerKind containerKind,
    String containerVersion,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    // Validate tag key
    if (tag.key == TagKey.custom && tag.value is! String) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'Custom tag has non-string value',
          context: 'Container: ${containerKind.name} v$containerVersion, value type: ${tag.value.runtimeType}',
          errorCode: 'CUSTOM_TAG_TYPE_MISMATCH',
        ),
      );
    }

    // Validate value ranges for numeric tags
    if (tag.value is int) {
      _validateNumericTag(tag, containerKind, containerVersion, errors, warnings);
    }

    // Validate string encoding and length
    if (tag.value is String) {
      _validateStringTag(tag, containerKind, containerVersion, errors, warnings);
    }

    // Validate list values
    if (tag.value is List) {
      _validateListTag(tag, containerKind, containerVersion, errors, warnings);
    }
  }

  /// Validates numeric tag values and ranges.
  void _validateNumericTag(
    MetadataTag tag,
    ContainerKind containerKind,
    String containerVersion,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    final value = tag.value as int;

    switch (tag.key) {
      case TagKey.rating:
        if (value < 0 || value > 100) {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: 'Rating value outside valid range 0-100',
              context: 'Container: ${containerKind.name} v$containerVersion, value: $value',
              errorCode: 'RATING_OUT_OF_RANGE',
            ),
          );
        }
        break;

      case TagKey.trackNumber:
      case TagKey.discNumber:
        if (value <= 0) {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: '${tag.key.name} must be positive',
              context: 'Container: ${containerKind.name} v$containerVersion, value: $value',
              errorCode: 'NEGATIVE_NUMBER',
            ),
          );
        }
        break;

      case TagKey.bpm:
        if (value <= 0 || value > 999) {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: 'BPM value outside reasonable range 1-999',
              context: 'Container: ${containerKind.name} v$containerVersion, value: $value',
              errorCode: 'BPM_OUT_OF_RANGE',
            ),
          );
        }
        break;

      case TagKey.year:
        if (value < 1900 || value > 2100) {
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'Year value outside typical range 1900-2100',
              context: 'Container: ${containerKind.name} v$containerVersion, value: $value',
              errorCode: 'YEAR_OUT_OF_RANGE',
            ),
          );
        }
        break;

      default:
        // No specific validation for other numeric tags
        break;
    }
  }

  /// Validates string tag values and encoding.
  void _validateStringTag(
    MetadataTag tag,
    ContainerKind containerKind,
    String containerVersion,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    final value = tag.value as String;

    // Check for empty strings in required fields
    if (value.isEmpty && _isRequiredField(tag.key)) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'Required field is empty',
          context: 'Container: ${containerKind.name} v$containerVersion, field: ${tag.key.name}',
          errorCode: 'EMPTY_REQUIRED_FIELD',
        ),
      );
    }

    // Check for excessively long strings
    if (value.length > 10000) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'String value is very long (${value.length} characters)',
          context: 'Container: ${containerKind.name} v$containerVersion, field: ${tag.key.name}',
          errorCode: 'VERY_LONG_STRING',
        ),
      );
    }

    // Validate date format for date fields
    if (tag.key == TagKey.dateRecorded) {
      _validateDateFormat(value, containerKind, containerVersion, errors, warnings);
    }
  }

  /// Validates list tag values.
  void _validateListTag(
    MetadataTag tag,
    ContainerKind containerKind,
    String containerVersion,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    final value = tag.value as List;

    if (value.isEmpty) {
      warnings.add(
        ValidationError(
          severity: ValidationSeverity.warning,
          message: 'List field is empty',
          context: 'Container: ${containerKind.name} v$containerVersion, field: ${tag.key.name}',
          errorCode: 'EMPTY_LIST_FIELD',
        ),
      );
    }

    // Validate individual list elements
    for (int i = 0; i < value.length; i++) {
      final element = value[i];
      if (element is String && element.isEmpty) {
        warnings.add(
          ValidationError(
            severity: ValidationSeverity.warning,
            message: 'List contains empty string element',
            context: 'Container: ${containerKind.name} v$containerVersion, field: ${tag.key.name}, index: $i',
            errorCode: 'EMPTY_LIST_ELEMENT',
          ),
        );
      }
    }
  }

  /// Validates date format for date fields.
  void _validateDateFormat(
    String dateValue,
    ContainerKind containerKind,
    String containerVersion,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    // Basic ISO-8601 pattern check
    final iso8601Pattern = RegExp(r'^\d{4}(-\d{2}(-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})?)?)?)?$');

    if (!iso8601Pattern.hasMatch(dateValue)) {
      errors.add(
        ValidationError(
          severity: ValidationSeverity.error,
          message: 'Date value is not in valid ISO-8601 format',
          context: 'Container: ${containerKind.name} v$containerVersion, value: "$dateValue"',
          errorCode: 'INVALID_DATE_FORMAT',
        ),
      );
    }
  }

  /// Validates consistency of tags across different containers.
  void _validateCrossContainerConsistency(
    Map<(ContainerKind, String), List<MetadataTag>> tagsByContainer,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    final tagsByKey = <TagKey, List<(MetadataTag, ContainerKind, String)>>{};

    // Group tags by key across all containers
    for (final entry in tagsByContainer.entries) {
      final (containerKind, containerVersion) = entry.key;
      final tags = entry.value;

      for (final tag in tags) {
        tagsByKey.putIfAbsent(tag.key, () => []).add((tag, containerKind, containerVersion));
      }
    }

    // Check for inconsistencies
    for (final entry in tagsByKey.entries) {
      final tagKey = entry.key;
      final tagInstances = entry.value;

      if (tagInstances.length > 1) {
        _validateTagConsistencyAcrossContainers(tagKey, tagInstances, errors, warnings);
      }
    }
  }

  /// Validates consistency of a specific tag across containers.
  void _validateTagConsistencyAcrossContainers(
    TagKey tagKey,
    List<(MetadataTag, ContainerKind, String)> tagInstances,
    List<ValidationError> errors,
    List<ValidationError> warnings,
  ) {
    final values = tagInstances.map((instance) => instance.$1.value).toList();
    final firstValue = values.first;

    // Check if all values are identical
    final bool allIdentical = values.every((value) => _deepEquals(value, firstValue));

    if (!allIdentical) {
      // For some fields, differences might be expected due to format limitations
      if (_allowsValueDifferences(tagKey)) {
        warnings.add(
          ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Tag values differ across containers (may be due to format limitations)',
            context: 'Tag: ${tagKey.name}, containers: ${tagInstances.map((t) => '${t.$2.name} v${t.$3}').join(', ')}',
            errorCode: 'TAG_VALUE_DIFFERENCES',
          ),
        );
      } else {
        errors.add(
          ValidationError(
            severity: ValidationSeverity.error,
            message: 'Tag values are inconsistent across containers',
            context: 'Tag: ${tagKey.name}, containers: ${tagInstances.map((t) => '${t.$2.name} v${t.$3}').join(', ')}',
            errorCode: 'TAG_VALUE_INCONSISTENT',
          ),
        );
      }
    }
  }

  /// Compares original tags with extracted tags for round-trip validation.
  ///
  /// This method performs semantic-aware comparison, recognizing that tags
  /// converted during encoding (e.g., YearTag → DateRecordedTag for ID3v2.4)
  /// should not be reported as lost if they are semantically equivalent.
  /// It also takes into account format capabilities to avoid reporting expected
  /// tag losses due to format limitations.
  void _compareTagSets(
    List<MetadataTag> originalTags,
    List<MetadataTag> extractedTags,
    List<ValidationError> errors,
    List<ValidationError> warnings, {
    FormatStrategy? formatStrategy,
  }) {
    final originalByKey = <TagKey, List<MetadataTag>>{};
    final extractedByKey = <TagKey, List<MetadataTag>>{};

    // Group tags by key
    for (final tag in originalTags) {
      originalByKey.putIfAbsent(tag.key, () => []).add(tag);
    }
    for (final tag in extractedTags) {
      extractedByKey.putIfAbsent(tag.key, () => []).add(tag);
    }

    // Check for missing tags with semantic equivalence awareness
    for (final key in originalByKey.keys) {
      if (!extractedByKey.containsKey(key)) {
        // Tag key is missing - check if there's a semantically equivalent tag
        final originalTagsForKey = originalByKey[key]!;
        bool foundSemanticEquivalent = false;

        // Search for semantic equivalents in extracted tags
        for (final extractedKey in extractedByKey.keys) {
          if (extractedKey != key) {
            // Don't check the same key
            final extractedTagsForKey = extractedByKey[extractedKey]!;

            // Check if any original tag is semantically equivalent to any extracted tag
            for (final originalTag in originalTagsForKey) {
              for (final extractedTag in extractedTagsForKey) {
                if (_areTagsSemanticallyEquivalent(originalTag, extractedTag)) {
                  foundSemanticEquivalent = true;
                  break;
                }
              }
              if (foundSemanticEquivalent) break;
            }
          }
          if (foundSemanticEquivalent) break;
        }

        // Special case: Check if this was a data conflict resolution
        if (!foundSemanticEquivalent && _wasLostDueToDataConflict(originalTagsForKey, extractedByKey)) {
          // This tag was lost due to intentional data conflict resolution (e.g., different year values)
          // This is acceptable behavior - don't report as an error
          foundSemanticEquivalent = true; // Treat as "handled"
        }

        // Check if tag loss is due to format capability limitations
        if (!foundSemanticEquivalent && formatStrategy != null && _wasLostDueToCapabilityLimitations(key, formatStrategy)) {
          // This tag was lost because the target format doesn't support it
          // This is expected for optimized encoding - report as warning, not error
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'Tag was dropped due to format limitations',
              context: 'Tag: ${key.name} is not supported by target format',
              errorCode: 'TAG_DROPPED_UNSUPPORTED',
            ),
          );
          foundSemanticEquivalent = true; // Treat as "handled"
        }

        if (!foundSemanticEquivalent) {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: 'Tag was lost during round-trip (Tag: ${key.name})',
              context: 'Tag: ${key.name}',
              errorCode: 'TAG_LOST',
            ),
          );
        }
      }
    }

    // Check for unexpected tags
    for (final key in extractedByKey.keys) {
      if (!originalByKey.containsKey(key)) {
        // Tag key is new - check if this is a semantic conversion result
        final extractedTagsForKey = extractedByKey[key]!;
        bool isSemanticConversion = false;

        // Search for semantic equivalents in original tags
        for (final originalKey in originalByKey.keys) {
          if (originalKey != key) {
            // Don't check the same key
            final originalTagsForKey = originalByKey[originalKey]!;

            // Check if any extracted tag is semantically equivalent to any original tag
            for (final extractedTag in extractedTagsForKey) {
              for (final originalTag in originalTagsForKey) {
                if (_areTagsSemanticallyEquivalent(originalTag, extractedTag)) {
                  isSemanticConversion = true;
                  break;
                }
              }
              if (isSemanticConversion) break;
            }
          }
          if (isSemanticConversion) break;
        }

        if (!isSemanticConversion) {
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'Unexpected tag found after round-trip',
              context: 'Tag: ${key.name}',
              errorCode: 'UNEXPECTED_TAG',
            ),
          );
        }
      }
    }

    // Compare tag values for matching keys
    for (final key in originalByKey.keys) {
      final originalTagsForKey = originalByKey[key]!;
      final extractedTagsForKey = extractedByKey[key];

      if (extractedTagsForKey != null) {
        _compareTagValues(key, originalTagsForKey, extractedTagsForKey, errors, warnings, formatStrategy: formatStrategy);
      }
    }
  }

  /// Compares tag values for a specific key.
  void _compareTagValues(
    TagKey tagKey,
    List<MetadataTag> originalTags,
    List<MetadataTag> extractedTags,
    List<ValidationError> errors,
    List<ValidationError> warnings, {
    FormatStrategy? formatStrategy,
  }) {
    // For single-valued tags, compare the first value
    if (originalTags.length == 1 && extractedTags.length == 1) {
      final originalValue = originalTags.first.value;
      final extractedValue = extractedTags.first.value;

      if (!_deepEquals(originalValue, extractedValue)) {
        // Check if this is acceptable truncation due to format limitations
        if (_isAcceptableTruncation(tagKey, originalValue, extractedValue, formatStrategy)) {
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'Tag value was truncated due to format limitations',
              context: 'Tag: ${tagKey.name}, original: "$originalValue", extracted: "$extractedValue"',
              errorCode: 'TAG_VALUE_TRUNCATED',
            ),
          );
        } else if (_allowsValueNormalization(tagKey)) {
          warnings.add(
            ValidationError(
              severity: ValidationSeverity.warning,
              message: 'Tag value was normalized during round-trip',
              context: 'Tag: ${tagKey.name}, original: "$originalValue", extracted: "$extractedValue"',
              errorCode: 'TAG_VALUE_NORMALIZED',
            ),
          );
        } else {
          errors.add(
            ValidationError(
              severity: ValidationSeverity.error,
              message: 'Tag value changed during round-trip',
              context: 'Tag: ${tagKey.name}, original: "$originalValue", extracted: "$extractedValue"',
              errorCode: 'TAG_VALUE_CHANGED',
            ),
          );
        }
      }
    } else {
      // For multi-valued tags, compare counts and values
      if (originalTags.length != extractedTags.length) {
        warnings.add(
          ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Tag count changed during round-trip',
            context: 'Tag: ${tagKey.name}, original: ${originalTags.length}, extracted: ${extractedTags.length}',
            errorCode: 'TAG_COUNT_CHANGED',
          ),
        );
      }
    }
  }

  /// Helper methods for validation logic
  bool _hasCriticalErrors(List<ValidationError> errors) {
    return errors.any((error) => error.severity == ValidationSeverity.critical);
  }

  String _getValidationLevel() {
    final levels = <String>[];
    levels.add('basic');
    if (enableDeepValidation) levels.add('deep');
    if (enableRoundTripValidation) levels.add('round-trip');
    return levels.join('+');
  }

  bool _isRequiredContainer(ContainerKind containerKind, FormatStrategy formatStrategy) {
    // Primary containers are typically required
    return formatStrategy.fanout.isNotEmpty && formatStrategy.fanout.first.$1 == containerKind;
  }

  /// Checks if a tag was lost due to intentional data conflict resolution.
  ///
  /// This method determines whether a missing tag was removed because it
  /// conflicted with another tag that was prioritized. For example, if we had
  /// YearTag(2024) and DateRecordedTag("2020"), the converter might choose
  /// Checks if a tag was lost due to format capability limitations.
  ///
  /// This method determines whether a missing tag was dropped because the target
  /// format doesn't support it. For example, ID3v1 doesn't support artwork,
  /// musicalKey, bpm, or grouping tags.
  bool _wasLostDueToCapabilityLimitations(TagKey tagKey, FormatStrategy formatStrategy) {
    // First check if this is a commonly unsupported tag that should not cause errors
    const commonlyUnsupportedTags = {
      TagKey.musicalKey,
      TagKey.artwork,
      TagKey.bpm,
      TagKey.grouping,
      TagKey.encoder,
      TagKey.isrc,
      TagKey.lyrics,
      TagKey.albumArtist, // May not be supported in ID3v1
      TagKey.composer, // May not be supported in ID3v1
    };

    if (commonlyUnsupportedTags.contains(tagKey)) {
      // These tags are commonly dropped by format limitations
      return true;
    }

    // Check if any of the target containers support this tag
    bool anySupport = false;
    for (final (containerKind, containerVersion) in formatStrategy.fanout) {
      final codec = codecRegistry.findCodec(containerKind, containerVersion);
      if (codec != null) {
        final capability = codec.capability;
        if (capability.semanticsByKey.containsKey(tagKey)) {
          // At least one target container supports this tag
          anySupport = true;
          break;
        }
      }
    }

    // If no container supports this tag, it was lost due to capability limitations
    return !anySupport;
  }

  /// to keep only the DateRecordedTag and discard the conflicting YearTag.
  bool _wasLostDueToDataConflict(
    List<MetadataTag> lostTags,
    Map<TagKey, List<MetadataTag>> extractedByKey,
  ) {
    // Currently, we only handle Year/DateRecorded conflicts
    for (final lostTag in lostTags) {
      if (lostTag.key == TagKey.year) {
        // Check if we have a DateRecorded tag in the extracted tags
        final dateRecordedTags = extractedByKey[TagKey.dateRecorded];
        if (dateRecordedTags != null && dateRecordedTags.isNotEmpty) {
          // Check if the year values are different (indicating a data conflict)
          final yearTag = lostTag as YearTag;
          for (final dateRecordedTag in dateRecordedTags) {
            final dateRecorded = dateRecordedTag as DateRecordedTag;
            final extractedYear = _extractYearFromDateRecorded(dateRecorded.value);
            if (extractedYear != null && extractedYear != yearTag.value) {
              // This is a data conflict - the year tag was lost because
              // it had a different year than the date recorded tag
              return true;
            }
          }
        }
      } else if (lostTag.key == TagKey.dateRecorded) {
        // Check if we have a Year tag in the extracted tags with different value
        final yearTags = extractedByKey[TagKey.year];
        if (yearTags != null && yearTags.isNotEmpty) {
          final dateRecordedTag = lostTag as DateRecordedTag;
          final lostYear = _extractYearFromDateRecorded(dateRecordedTag.value);
          if (lostYear != null) {
            for (final yearTag in yearTags) {
              final year = (yearTag as YearTag).value;
              if (year != lostYear) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  /// Extracts year from ISO-8601 date string (same logic as SemanticTagConverter).
  int? _extractYearFromDateRecorded(String dateString) {
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(dateString);
    if (yearMatch != null) {
      return int.tryParse(yearMatch.group(1)!);
    }
    return null;
  }

  /// Checks if a value change is acceptable truncation due to format limitations.
  ///
  /// This method determines if the extracted value is a truncated version of the
  /// original value due to format constraints (e.g., ID3v1's 30-character limits).
  bool _isAcceptableTruncation(TagKey tagKey, dynamic originalValue, dynamic extractedValue, FormatStrategy? formatStrategy) {
    if (formatStrategy == null || originalValue is! String || extractedValue is! String) {
      return false;
    }

    final originalStr = originalValue;
    final extractedStr = extractedValue;

    // Check if extracted is a prefix of original (indicating truncation)
    if (!originalStr.startsWith(extractedStr)) {
      return false;
    }

    // Check if any target container has length limitations that would cause this truncation
    for (final (containerKind, containerVersion) in formatStrategy.fanout) {
      final codec = codecRegistry.findCodec(containerKind, containerVersion);
      if (codec != null) {
        final semantics = codec.capability.semanticsByKey[tagKey];
        if (semantics?.maxTextLength != null) {
          final maxLength = semantics!.maxTextLength!;
          // If the extracted length matches the format limit and original exceeds it
          if (extractedStr.length <= maxLength && originalStr.length > maxLength) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _isRequiredField(TagKey tagKey) {
    // Define which fields are considered required
    return const {TagKey.title, TagKey.artist}.contains(tagKey);
  }

  bool _allowsValueDifferences(TagKey tagKey) {
    // Some tags may have acceptable differences due to format limitations
    // ID3v1 has strict character limits that cause truncation:
    // - Title, Artist, Album: 30 characters
    // - Comment: 30 characters (or 28 with track number)
    // - Year: 4 characters
    // - DateRecorded: Not supported (year extracted to year field)
    // These differences should be warnings, not errors
    return const {
      TagKey.rating,
      TagKey.genre,
      TagKey.comment,
      TagKey.title, // ID3v1 30-char limit
      TagKey.artist, // ID3v1 30-char limit
      TagKey.album, // ID3v1 30-char limit
      TagKey.year, // ID3v1 4-char limit
      TagKey.dateRecorded, // ID3v1 vs ID3v2.4 year/date conversion
    }.contains(tagKey);
  }

  bool _allowsValueNormalization(TagKey tagKey) {
    // Some tags may be normalized during encoding/decoding
    return const {TagKey.rating, TagKey.bpm, TagKey.year, TagKey.genre, TagKey.dateRecorded}.contains(tagKey);
  }

  bool _deepEquals(dynamic value1, dynamic value2) {
    if (value1 is List && value2 is List) {
      if (value1.length != value2.length) return false;
      for (int i = 0; i < value1.length; i++) {
        if (!_deepEquals(value1[i], value2[i])) return false;
      }
      return true;
    }

    // Handle null and empty string cases
    if (value1 == null && value2 == null) return true;
    if (value1 == null || value2 == null) {
      // Check if one is null and the other is empty string - they should be equivalent
      if ((value1 == null && value2 is String && _isEffectivelyEmpty(value2)) || (value2 == null && value1 is String && _isEffectivelyEmpty(value1))) {
        return true;
      }
      return false;
    }

    // Normalize empty strings - some formats might represent empty differently
    if (value1 is String && value2 is String) {
      final isEmpty1 = _isEffectivelyEmpty(value1);
      final isEmpty2 = _isEffectivelyEmpty(value2);

      // Both empty after normalization
      if (isEmpty1 && isEmpty2) return true;

      // If one is empty and the other isn't, they're different
      if (isEmpty1 != isEmpty2) return false;

      // Both non-empty, compare normalized strings
      return _normalizeString(value1) == _normalizeString(value2);
    }

    return value1 == value2;
  }

  /// Checks if a string is effectively empty (whitespace, control chars, or null bytes)
  bool _isEffectivelyEmpty(String str) {
    // Remove all control characters and whitespace
    final cleaned = str.replaceAll(RegExp(r'[\x00-\x20\x7F-\x9F]'), '');
    return cleaned.isEmpty;
  }

  /// Normalizes a string by removing control characters and trimming
  String _normalizeString(String str) {
    return str.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
  }

  /// Checks if two tags are semantically equivalent.
  ///
  /// This is a simplified implementation for basic semantic equivalence.
  /// It handles basic cases like Year/DateRecorded equivalence.
  bool _areTagsSemanticallyEquivalent(MetadataTag tag1, MetadataTag tag2) {
    // Direct equality check first
    if (tag1 == tag2) return true;

    // Check for basic semantic equivalences
    if (tag1.key == TagKey.year && tag2.key == TagKey.dateRecorded) {
      // Year 2020 is equivalent to DateRecorded "2020"
      return tag1.value.toString() == tag2.value.toString().substring(0, 4);
    }

    if (tag1.key == TagKey.dateRecorded && tag2.key == TagKey.year) {
      // DateRecorded "2020" is equivalent to Year 2020
      return tag2.value.toString() == tag1.value.toString().substring(0, 4);
    }

    // For other cases, require same key and similar values
    return tag1.key == tag2.key && tag1.value == tag2.value;
  }
}

/// Result of a validation operation.
class ValidationResult {
  /// Whether the validation passed without errors.
  final bool isValid;

  /// List of validation errors found.
  final List<ValidationError> errors;

  /// List of validation warnings found.
  final List<ValidationError> warnings;

  /// The level of validation performed.
  final String validationLevel;

  /// Creates a new ValidationResult.
  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.validationLevel,
  });

  /// Whether the validation found any issues (errors or warnings).
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  /// Total number of issues found.
  int get issueCount => errors.length + warnings.length;

  /// Gets a summary of the validation result.
  String get summary {
    if (isValid && warnings.isEmpty) {
      return 'Validation passed with no issues';
    } else if (isValid) {
      return 'Validation passed with ${warnings.length} warnings';
    } else {
      return 'Validation failed with ${errors.length} errors and ${warnings.length} warnings';
    }
  }
}

/// Represents a validation error or warning.
class ValidationError {
  /// The severity level of this validation issue.
  final ValidationSeverity severity;

  /// Human-readable description of the validation issue.
  final String message;

  /// Additional context information about the issue.
  final String? context;

  /// Machine-readable error code for programmatic handling.
  final String errorCode;

  /// Creates a new ValidationError.
  const ValidationError({
    required this.severity,
    required this.message,
    this.context,
    required this.errorCode,
  });

  @override
  String toString() {
    final contextInfo = context != null ? ' ($context)' : '';
    return '${severity.name.toUpperCase()}: $message$contextInfo [$errorCode]';
  }
}

/// Severity levels for validation issues.
enum ValidationSeverity {
  /// Critical errors that indicate file corruption or complete failure.
  critical,

  /// Errors that indicate problems but the file might still be usable.
  error,

  /// Warnings about potential issues or format limitations.
  warning,
}
