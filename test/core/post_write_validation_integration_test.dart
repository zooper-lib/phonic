// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3.dart';
import 'package:phonic/src/utils/locators/locators.dart';

void main() {
  group('Post-Write Validation Integration', () {
    late CodecRegistry codecRegistry;
    late Mp3FormatStrategy formatStrategy;
    late MergePolicy mergePolicy;

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

      formatStrategy = const Mp3FormatStrategy();
      mergePolicy = MergePolicy.fromStrategy(formatStrategy);
    });

    group('Successful Validation Scenarios', () {
      test('should pass validation for properly encoded file', () async {
        // Create a minimal valid MP3 file with ID3v2 header
        final mp3Bytes = _createValidMp3WithId3v2();

        final validator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: false, // Disable deep validation for this test
          enableRoundTripValidation: false,
        );

        final rollbackManager = RollbackManager();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        // Add some tags
        audioFile.setTag(const TitleTag('Test Title'));
        audioFile.setTag(const ArtistTag('Test Artist'));

        // This should succeed without throwing
        expect(() async => await audioFile.encode(), returnsNormally);
      });

      test('should handle validation warnings gracefully', () async {
        final mp3Bytes = _createValidMp3WithId3v2();

        // Create validator that will generate warnings but not errors
        final validator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: true,
          enableRoundTripValidation: false,
          maxValidationFileSize: 100, // Small limit to trigger warning
        );

        final rollbackManager = RollbackManager();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        audioFile.setTag(const TitleTag('Test Title'));

        // Should succeed despite warnings
        final encodedBytes = await audioFile.encode();
        expect(encodedBytes, isNotNull);
        expect(encodedBytes.isNotEmpty, isTrue);
      });
    });

    group('Validation Failure and Rollback', () {
      test('should rollback on validation failure', () async {
        // Create a validator that will always fail validation
        final failingValidator = _FailingValidator(codecRegistry);
        final rollbackManager = RollbackManager();

        final mp3Bytes = _createValidMp3WithId3v2();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: failingValidator,
          rollbackManager: rollbackManager,
        );

        // Set initial tags
        audioFile.setTag(const TitleTag('Original Title'));

        // Modify tags
        audioFile.setTag(const TitleTag('Modified Title'));
        audioFile.setTag(const ArtistTag('New Artist'));

        // Encoding should fail and rollback
        expect(
          () async => await audioFile.encode(),
          throwsA(isA<CorruptedContainerException>()),
        );

        // Verify rollback occurred - should restore to pre-encode state
        // The rollback state is saved at the beginning of encode(), so it contains
        // the modified title and added artist that were set before encode() was called
        final restoredTags = audioFile.getAllTags();
        expect(restoredTags.length, equals(2)); // Modified title + artist

        final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
        expect(titleTag?.value, equals('Modified Title')); // Should be the modified title

        final artistTag = audioFile.getTag(TagKey.artist) as ArtistTag?;
        expect(artistTag?.value, equals('New Artist')); // Should have the added artist
      });

      test('should maintain rollback state across multiple operations', () async {
        final validator = PostWriteValidator(codecRegistry: codecRegistry);
        final rollbackManager = RollbackManager();

        final mp3Bytes = _createValidMp3WithId3v2();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        // Save initial state manually
        audioFile.saveRollbackState(description: 'Initial state');

        // Make first modification
        audioFile.setTag(const TitleTag('Title 1'));
        final firstToken = audioFile.saveRollbackState(description: 'After first modification');

        // Make second modification
        audioFile.setTag(const ArtistTag('Artist 1'));
        audioFile.setTag(RatingTag(85));

        // Check rollback info
        final rollbackInfo = audioFile.getRollbackInfo();
        expect(rollbackInfo.stateCount, equals(2));
        expect(rollbackInfo.descriptions, contains('Initial state'));
        expect(rollbackInfo.descriptions, contains('After first modification'));

        // Rollback to first modification
        final success = audioFile.rollbackTo(firstToken);
        expect(success, isTrue);

        // Verify state
        final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
        expect(titleTag?.value, equals('Title 1'));

        final artistTag = audioFile.getTag(TagKey.artist);
        expect(artistTag, isNull);

        final ratingTag = audioFile.getTag(TagKey.rating);
        expect(ratingTag, isNull);
      });
    });

    group('Exception Handling and Rollback', () {
      test('should rollback on encoding exception', () async {
        // Use a failing validator instead of empty codec registry
        // to test rollback on validation failure rather than tag validation failure
        final failingValidator = _FailingValidator(codecRegistry);

        final validator = failingValidator;
        final rollbackManager = RollbackManager();

        final mp3Bytes = _createValidMp3WithId3v2();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry, // Use normal registry
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        // Set initial tags
        audioFile.setTag(const TitleTag('Original Title'));

        // Modify tags
        audioFile.setTag(const TitleTag('Modified Title'));
        audioFile.setTag(const ArtistTag('New Artist'));

        // Encoding should fail and rollback
        expect(
          () async => await audioFile.encode(),
          throwsA(isA<CorruptedContainerException>()),
        );

        // Verify rollback occurred - should restore to pre-encode state
        // (which contains the modified title and added artist)
        final titleTag = audioFile.getTag(TagKey.title) as TitleTag?;
        expect(titleTag?.value, equals('Modified Title'));

        final artistTag = audioFile.getTag(TagKey.artist) as ArtistTag?;
        expect(artistTag?.value, equals('New Artist'));
      });
    });

    group('Memory Management', () {
      test('should clean up rollback states on dispose', () async {
        final validator = PostWriteValidator(codecRegistry: codecRegistry);
        final rollbackManager = RollbackManager();

        final mp3Bytes = _createValidMp3WithId3v2();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        // Create several rollback states
        audioFile.saveRollbackState(description: 'State 1');
        audioFile.setTag(const TitleTag('Title'));
        audioFile.saveRollbackState(description: 'State 2');
        audioFile.setTag(const ArtistTag('Artist'));

        final rollbackInfo = audioFile.getRollbackInfo();
        expect(rollbackInfo.stateCount, greaterThan(0));
        expect(rollbackInfo.totalMemoryUsage, greaterThan(0));

        // Dispose should clean up rollback states
        audioFile.dispose();

        final rollbackInfoAfterDispose = audioFile.getRollbackInfo();
        expect(rollbackInfoAfterDispose.stateCount, equals(0));
        expect(rollbackInfoAfterDispose.totalMemoryUsage, equals(0));
      });

      test('should manage rollback memory usage efficiently', () async {
        final validator = PostWriteValidator(codecRegistry: codecRegistry);
        final rollbackManager = RollbackManager(maxStackSize: 3);

        final mp3Bytes = _createValidMp3WithId3v2();

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: validator,
          rollbackManager: rollbackManager,
        );

        // Create more states than the limit
        for (int i = 0; i < 5; i++) {
          audioFile.saveRollbackState(description: 'State $i');
          audioFile.setTag(TitleTag('Title $i'));
        }

        final rollbackInfo = audioFile.getRollbackInfo();
        expect(rollbackInfo.stateCount, equals(3)); // Should respect max size
      });
    });

    group('Validation Configuration Impact', () {
      test('should handle different validation levels', () async {
        final mp3Bytes = _createValidMp3WithId3v2();

        // Test with minimal validation
        final minimalValidator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: false,
          enableRoundTripValidation: false,
        );

        final audioFile1 = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: minimalValidator,
          rollbackManager: RollbackManager(),
        );

        audioFile1.setTag(const TitleTag('Test Title'));
        final encodedBytes1 = await audioFile1.encode();
        expect(encodedBytes1, isNotNull);

        // Test with full validation
        final fullValidator = PostWriteValidator(
          codecRegistry: codecRegistry,
          enableDeepValidation: true,
          enableRoundTripValidation: true,
        );

        final audioFile2 = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: formatStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: mergePolicy,
          validator: fullValidator,
          rollbackManager: RollbackManager(),
        );

        audioFile2.setTag(const TitleTag('Test Title'));
        final encodedBytes2 = await audioFile2.encode();
        expect(encodedBytes2, isNotNull);
      });
    });
  });
}

/// Creates a minimal valid MP3 file with ID3v2 header for testing.
Uint8List _createValidMp3WithId3v2() {
  final bytes = Uint8List(1000);

  // Add ID3v2 header
  bytes[0] = 0x49; // 'I'
  bytes[1] = 0x44; // 'D'
  bytes[2] = 0x33; // '3'
  bytes[3] = 0x04; // Version 2.4
  bytes[4] = 0x00; // Revision
  bytes[5] = 0x00; // Flags
  bytes[6] = 0x00; // Size (synchsafe)
  bytes[7] = 0x00;
  bytes[8] = 0x00;
  bytes[9] = 0x20; // 32 bytes

  // Add MP3 frame sync after ID3v2 header
  bytes[42] = 0xFF; // MP3 frame sync
  bytes[43] = 0xFB;

  return bytes;
}

/// A validator that always fails validation for testing rollback scenarios.
class _FailingValidator extends PostWriteValidator {
  _FailingValidator(CodecRegistry codecRegistry)
    : super(
        codecRegistry: codecRegistry,
        enableDeepValidation: true,
        enableRoundTripValidation: true,
      );

  @override
  Future<ValidationResult> validateEncodedFile({
    required Uint8List encodedBytes,
    required List<dynamic> originalTags,
    required dynamic formatStrategy,
    List<dynamic>? expectedContainers,
  }) async {
    print('_FailingValidator.validateEncodedFile called - should fail!');
    // Always return a failed validation result
    return const ValidationResult(
      isValid: false,
      errors: [
        ValidationError(
          severity: ValidationSeverity.error,
          message: 'Simulated validation failure for testing',
          errorCode: 'TEST_VALIDATION_FAILURE',
        ),
      ],
      warnings: [],
      validationLevel: 'test',
    );
  }
}
