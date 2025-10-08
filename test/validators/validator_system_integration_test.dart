import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

/// Integration tests for the public validator system
void main() {
  group('Validator System Integration', () {
    group('End-to-End Workflow', () {
      test('validates input, creates tag, and uses in audio file workflow', () {
        // Simulate user input
        final userInput = 85;

        // Step 1: Validate before creating tag
        final error = TagValidators.rating.validate(userInput);
        expect(error, isNull, reason: 'Input should be valid');

        // Step 2: Create tag since validation passed
        final tag = RatingTag(userInput);
        expect(tag.value, equals(userInput));

        // Step 3: Tag can be used in audio file operations
        expect(tag.key, equals(TagKey.rating));
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('prevents invalid tag creation through validation', () {
        final invalidInput = 150;

        // Step 1: Validate first
        final error = TagValidators.rating.validate(invalidInput);
        expect(error, isNotNull, reason: 'Invalid input should fail validation');

        // Step 2: Don't create tag if validation failed
        if (error != null) {
          final errorMessage = RatingTag.validator.formatErrorMessage(error);
          expect(errorMessage, contains('Rating must be between 0 and 100'));

          // Verify tag constructor would also fail
          expect(
            () => RatingTag(invalidInput),
            throwsA(isA<ArgumentError>()),
          );
        }
      });
    });

    group('Validator Consistency', () {
      test('tag validator and TagValidators provide same results', () {
        final testValues = [-10, 0, 50, 100, 150];

        for (final value in testValues) {
          final error1 = RatingTag.validator.validate(value);
          final error2 = TagValidators.rating.validate(value);

          expect(
            error1,
            equals(error2),
            reason: 'Both access methods should return identical results for $value',
          );
        }
      });

      test('validation and constructor behavior are aligned', () {
        final testCases = [
          (-1, false),
          (0, true),
          (50, true),
          (100, true),
          (101, false),
        ];

        for (final (value, shouldBeValid) in testCases) {
          final validationError = TagValidators.rating.validate(value);
          final isValidByValidator = validationError == null;

          expect(isValidByValidator, equals(shouldBeValid));

          if (shouldBeValid) {
            expect(() => RatingTag(value), returnsNormally);
          } else {
            expect(() => RatingTag(value), throwsA(isA<ArgumentError>()));
          }
        }
      });
    });

    group('Validator Access Patterns', () {
      test('all access patterns work correctly', () {
        final value = 75;

        // Pattern 1: Via TagValidators
        final result1 = TagValidators.rating.validate(value);

        // Pattern 2: Via tag class
        final result2 = RatingTag.validator.validate(value);

        // Pattern 3: Direct instantiation
        const validator = RatingValidator();
        final result3 = validator.validate(value);

        expect(result1, isNull);
        expect(result2, isNull);
        expect(result3, isNull);
        expect(result1, equals(result2));
        expect(result2, equals(result3));
      });

      test('validator constants are accessible from multiple sources', () {
        // From validator class
        expect(RatingValidator.min, equals(0));
        expect(RatingValidator.max, equals(100));

        // From tag class (should reference validator)
        expect(RatingTag.minRating, equals(RatingValidator.min));
        expect(RatingTag.maxRating, equals(RatingValidator.max));
      });
    });

    group('Error Message Consistency', () {
      test('formatted messages match expected format', () {
        final testCases = [
          (-1, 'Rating must be between 0 and 100 (inclusive)'),
          (101, 'Rating must be between 0 and 100 (inclusive)'),
          (1000, 'Rating must be between 0 and 100 (inclusive)'),
        ];

        for (final (value, expectedMessage) in testCases) {
          final error = TagValidators.rating.validate(value);
          expect(error, isNotNull);

          final message = RatingTag.validator.formatErrorMessage(error!);
          expect(message, equals(expectedMessage));
        }
      });

      test('ArgumentError from validateOrThrow uses formatted message', () {
        try {
          RatingTag.validator.validateOrThrow(150);
          fail('Should have thrown ArgumentError');
        } on ArgumentError catch (e) {
          expect(
            e.message,
            equals('Rating must be between 0 and 100 (inclusive)'),
          );
        }
      });
    });

    group('Null Handling', () {
      test('validators handle null appropriately', () {
        // Validators return null for null input (indicating "no error")
        final error = TagValidators.rating.validate(null);
        expect(error, isNull);

        // But tag constructor cannot accept null (compile-time type safety)
        // This would be a compile error: RatingTag(null);
      });

      test('isValid handles null correctly', () {
        expect(RatingValidator.isValid(null), isTrue);
        expect(RatingValidator.isValid(50), isTrue);
        expect(RatingValidator.isValid(150), isFalse);
      });
    });

    group('Form Integration Simulation', () {
      test('simulates reactive_forms validation flow', () {
        // Simulate form control value
        int? formValue = 50;

        // Validator function for forms
        Map<String, dynamic>? formValidator(dynamic value) {
          return TagValidators.rating.validate(value as int?);
        }

        // Valid value
        expect(formValidator(formValue), isNull);

        // Invalid value
        formValue = 150;
        final error = formValidator(formValue);
        expect(error, isNotNull);
        final rangeError = error!['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['actual'], equals(150));

        // Null value (optional field)
        formValue = null;
        expect(formValidator(formValue), isNull);
      });

      test('custom error message generation for forms', () {
        String getCustomErrorMessage(Map<String, dynamic> error) {
          final data = error['outOfRange'] as Map<String, dynamic>;
          return 'Please enter a value between ${data['min']} and ${data['max']}. You entered ${data['actual']}.';
        }

        final error = TagValidators.rating.validate(200);
        expect(error, isNotNull);

        final message = getCustomErrorMessage(error!);
        expect(
          message,
          equals('Please enter a value between 0 and 100. You entered 200.'),
        );
      });
    });

    group('Batch Validation Scenarios', () {
      test('filters valid values from batch', () {
        final inputs = [-5, 0, 25, 50, 75, 100, 150, 200];

        final validInputs = inputs.where((value) {
          return TagValidators.rating.validate(value) == null;
        }).toList();

        expect(validInputs, equals([0, 25, 50, 75, 100]));
      });

      test('collects errors for invalid values', () {
        final inputs = [-5, 150, 200];

        final errors = inputs.map((value) {
          final error = TagValidators.rating.validate(value);
          return {
            'value': value,
            'error': error,
          };
        }).toList();

        expect(errors.length, equals(3));
        expect(errors.every((e) => e['error'] != null), isTrue);
      });
    });

    group('Real-World Use Cases', () {
      test('pre-validation prevents exception handling', () {
        final userInputs = [85, 150, -5, 92];
        final validTags = <RatingTag>[];
        final errors = <String>[];

        for (final input in userInputs) {
          final error = TagValidators.rating.validate(input);
          if (error == null) {
            validTags.add(RatingTag(input));
          } else {
            errors.add(
              'Value $input: ${RatingTag.validator.formatErrorMessage(error)}',
            );
          }
        }

        expect(validTags.length, equals(2));
        expect(validTags.map((t) => t.value).toList(), equals([85, 92]));
        expect(errors.length, equals(2));
      });

      test('form model with validation', () {
        // Simulate a form model
        int? rating;

        String? getRatingError() {
          if (rating == null) return null;
          final error = TagValidators.rating.validate(rating);
          return error != null ? RatingTag.validator.formatErrorMessage(error) : null;
        }

        // No rating set
        expect(getRatingError(), isNull);

        // Valid rating
        rating = 85;
        expect(getRatingError(), isNull);

        // Invalid rating
        rating = 150;
        expect(getRatingError(), isNotNull);
        expect(getRatingError(), contains('Rating must be between'));
      });
    });

    group('Type Safety', () {
      test('validator is properly typed', () {
        const validator = RatingValidator();
        expect(validator, isA<TagValidator<int>>());
        expect(validator, isA<RatingValidator>());
      });

      test('error map structure is validated', () {
        final error = TagValidators.rating.validate(150);
        expect(error, isNotNull);
        expect(error!['outOfRange'], isA<Map<String, dynamic>>());

        final rangeError = error['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['min'], isA<int>());
        expect(rangeError['max'], isA<int>());
        expect(rangeError['actual'], isA<int>());
      });
    });
  });
}
