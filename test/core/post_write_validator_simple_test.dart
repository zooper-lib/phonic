import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/post_write_validator.dart';
import 'package:phonic/src/formats/formats.dart';
import 'package:phonic/src/utils/utils.dart';

void main() {
  group('PostWriteValidator', () {
    late CodecRegistry codecRegistry;
    late PostWriteValidator validator;
    late Mp3FormatStrategy formatStrategy;

    setUp(() {
      codecRegistry = CodecRegistry(
        codecList: [
          const Id3v24Codec(),
          const Id3v1Codec(),
        ],
        containerLocatorList: [
          Id3v2Locator(),
          Id3v1Locator(),
        ],
      );

      validator = PostWriteValidator(
        codecRegistry: codecRegistry,
        enableDeepValidation: true,
        enableRoundTripValidation: true,
      );

      formatStrategy = const Mp3FormatStrategy();
    });

    group('Basic Structure Validation', () {
      test('should fail validation for empty file', () async {
        final emptyBytes = Uint8List(0);
        final originalTags = [const TitleTag('Test Title')];

        final result = await validator.validateEncodedFile(
          encodedBytes: emptyBytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
        expect(result.errors.first.errorCode, equals('EMPTY_FILE'));
        expect(result.errors.first.severity, equals(ValidationSeverity.critical));
      });

      test('should warn about large files exceeding validation limit', () async {
        final validator = PostWriteValidator(
          codecRegistry: codecRegistry,
          maxValidationFileSize: 100, // Very small limit for testing
        );

        final largeBytes = Uint8List(200); // Exceeds limit
        // Add minimal MP3 header to make it detectable
        largeBytes[0] = 0xFF;
        largeBytes[1] = 0xFB;

        final originalTags = [const TitleTag('Test Title')];

        final result = await validator.validateEncodedFile(
          encodedBytes: largeBytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((w) => w.errorCode == 'FILE_SIZE_LIMIT'), isTrue);
      });

      test('should fail validation for unrecognizable format', () async {
        final invalidBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final originalTags = [const TitleTag('Test Title')];

        final result = await validator.validateEncodedFile(
          encodedBytes: invalidBytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.errorCode == 'FORMAT_DETECTION_FAILED'), isTrue);
      });
    });

    group('Container Integrity Validation', () {
      test('should detect missing required containers', () async {
        // Create bytes that look like MP3 but missing expected containers
        final mp3Bytes = Uint8List(1000);
        mp3Bytes[0] = 0xFF; // MP3 frame sync
        mp3Bytes[1] = 0xFB;

        final originalTags = [const TitleTag('Test Title')];

        final result = await validator.validateEncodedFile(
          encodedBytes: mp3Bytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.errorCode == 'CONTAINER_NOT_FOUND'), isTrue);
      });

      test('should handle missing locators gracefully', () async {
        final emptyRegistry = CodecRegistry(
          codecList: [],
          containerLocatorList: [],
        );

        final validatorWithEmptyRegistry = PostWriteValidator(
          codecRegistry: emptyRegistry,
        );

        final mp3Bytes = Uint8List(1000);
        mp3Bytes[0] = 0xFF;
        mp3Bytes[1] = 0xFB;

        final originalTags = [const TitleTag('Test Title')];

        final result = await validatorWithEmptyRegistry.validateEncodedFile(
          encodedBytes: mp3Bytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.warnings.any((w) => w.errorCode == 'LOCATOR_NOT_FOUND'), isTrue);
      });
    });

    group('Validation Configuration', () {
      test('should skip deep validation when disabled', () async {
        final shallowValidator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: false,
          enableRoundTripValidation: false,
        );

        final mp3Bytes = Uint8List(1000);
        mp3Bytes[0] = 0xFF;
        mp3Bytes[1] = 0xFB;

        final originalTags = [const TitleTag('Test Title')];

        final result = await shallowValidator.validateEncodedFile(
          encodedBytes: mp3Bytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.validationLevel, equals('basic'));
      });

      test('should include all validation levels when enabled', () async {
        final fullValidator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: true,
          enableRoundTripValidation: true,
        );

        final mp3Bytes = Uint8List(1000);
        mp3Bytes[0] = 0xFF;
        mp3Bytes[1] = 0xFB;

        final originalTags = [const TitleTag('Test Title')];

        final result = await fullValidator.validateEncodedFile(
          encodedBytes: mp3Bytes,
          originalTags: originalTags,
          formatStrategy: formatStrategy,
        );

        expect(result.validationLevel, equals('basic+deep+round-trip'));
      });
    });

    group('ValidationResult', () {
      test('should provide correct summary for successful validation', () {
        final result = const ValidationResult(
          isValid: true,
          errors: [],
          warnings: [],
          validationLevel: 'basic',
        );

        expect(result.summary, equals('Validation passed with no issues'));
        expect(result.hasIssues, isFalse);
        expect(result.issueCount, equals(0));
      });

      test('should provide correct summary for validation with warnings', () {
        final warnings = [
          const ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Test warning',
            errorCode: 'TEST_WARNING',
          ),
        ];

        final result = ValidationResult(
          isValid: true,
          errors: [],
          warnings: warnings,
          validationLevel: 'basic',
        );

        expect(result.summary, equals('Validation passed with 1 warnings'));
        expect(result.hasIssues, isTrue);
        expect(result.issueCount, equals(1));
      });

      test('should provide correct summary for failed validation', () {
        final errors = [
          const ValidationError(
            severity: ValidationSeverity.error,
            message: 'Test error',
            errorCode: 'TEST_ERROR',
          ),
        ];

        final warnings = [
          const ValidationError(
            severity: ValidationSeverity.warning,
            message: 'Test warning',
            errorCode: 'TEST_WARNING',
          ),
        ];

        final result = ValidationResult(
          isValid: false,
          errors: errors,
          warnings: warnings,
          validationLevel: 'basic',
        );

        expect(result.summary, equals('Validation failed with 1 errors and 1 warnings'));
        expect(result.hasIssues, isTrue);
        expect(result.issueCount, equals(2));
      });
    });

    group('ValidationError', () {
      test('should format error messages correctly', () {
        final error = const ValidationError(
          severity: ValidationSeverity.error,
          message: 'Test error message',
          context: 'Test context',
          errorCode: 'TEST_ERROR',
        );

        expect(error.toString(), equals('ERROR: Test error message (Test context) [TEST_ERROR]'));
      });

      test('should format error messages without context', () {
        final error = const ValidationError(
          severity: ValidationSeverity.critical,
          message: 'Critical error',
          errorCode: 'CRITICAL_ERROR',
        );

        expect(error.toString(), equals('CRITICAL: Critical error [CRITICAL_ERROR]'));
      });
    });
  });
}
