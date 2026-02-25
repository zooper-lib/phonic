/// Example demonstrating how to use Phonic validators with reactive_forms
/// for input validation in Flutter applications.
///
/// This example shows:
/// 1. Basic validator usage for pre-validation
/// 2. Integration with reactive_forms
/// 3. Custom error messages
/// 4. Multiple validation scenarios
library;

// ignore_for_file: avoid_print

import 'package:phonic/phonic.dart';

void main() {
  // Example 1: Direct validation before creating a tag
  directValidationExample();

  // Example 2: Using validators with reactive_forms (pseudo-code)
  // This would be used in a real Flutter app
  reactiveFormsExample();

  // Example 3: Validation with custom error handling
  customErrorHandlingExample();

  // Example 4: Batch validation
  batchValidationExample();
}

/// Example 1: Direct validation before creating a tag
void directValidationExample() {
  print('=== Direct Validation Example ===');

  final userInput = 150; // Invalid rating

  // Validate before creating the tag
  final error = TagValidators.rating.validate(userInput);

  if (error != null) {
    final rangeError = error['outOfRange'] as Map<String, dynamic>;
    print('Invalid rating: $userInput');
    print('  Min allowed: ${rangeError['min']}');
    print('  Max allowed: ${rangeError['max']}');
    print('  You entered: ${rangeError['actual']}');
  } else {
    // Safe to create tag
    final tag = RatingTag(userInput);
    print('Created tag: ${tag.value}');
  }

  // Using the convenience method
  if (RatingValidator.isValid(85)) {
    final tag = RatingTag(85);
    print('Valid rating tag created: ${tag.value}');
  }

  print('');
}

/// Example 2: Integration with reactive_forms
///
/// This is pseudo-code showing how you would use the validators
/// in a real Flutter application with reactive_forms.
void reactiveFormsExample() {
  print('=== Reactive Forms Integration Example ===');
  print('''
In a Flutter app with reactive_forms:

```dart
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:phonic/phonic.dart';

class RatingForm extends StatelessWidget {
  final form = FormGroup({
    'rating': FormControl<int>(
      validators: [
        Validators.required,
        Validators.delegate(
          (control) => TagValidators.rating.validate(control.value),
        ),
      ],
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: form,
      child: Column(
        children: [
          ReactiveTextField<int>(
            formControlName: 'rating',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Rating (0-100)',
              helperText: 'Enter a rating between 0 and 100',
            ),
            validationMessages: {
              'required': (error) => 'Rating is required',
              'rating': (error) {
                final e = error as Map;
                return 'Rating must be \${e['min']}-\${e['max']}, you entered \${e['actual']}';
              },
            },
          ),
          ElevatedButton(
            onPressed: () {
              if (form.valid) {
                final rating = form.control('rating').value as int;
                // Create and save the tag
                final tag = RatingTag(rating);
                print('Rating tag created: \${tag.value}');
              }
            },
            child: Text('Save Rating'),
          ),
        ],
      ),
    );
  }
}
```
''');
  print('');
}

/// Example 3: Custom error handling
void customErrorHandlingExample() {
  print('=== Custom Error Handling Example ===');

  String? validateAndGetErrorMessage(int? value) {
    final error = TagValidators.rating.validate(value);
    if (error == null) return null;

    final data = error['outOfRange'] as Map<String, dynamic>;
    final actual = data['actual'] as int;
    final min = data['min'] as int;
    final max = data['max'] as int;

    if (actual < min) {
      return 'Rating is too low. Minimum is $min.';
    } else {
      return 'Rating is too high. Maximum is $max.';
    }
  }

  final testValues = [-10, 0, 50, 100, 150];

  for (final value in testValues) {
    final errorMessage = validateAndGetErrorMessage(value);
    if (errorMessage != null) {
      print('Rating $value: ✗ $errorMessage');
    } else {
      print('Rating $value: ✓ Valid');
    }
  }

  print('');
}

/// Example 4: Batch validation for multiple values
void batchValidationExample() {
  print('=== Batch Validation Example ===');

  final ratings = [85, 150, -5, 92, 200, 0, 100];

  final validRatings = <int>[];
  final invalidRatings = <Map<String, dynamic>>[];

  for (final rating in ratings) {
    final error = TagValidators.rating.validate(rating);
    if (error == null) {
      validRatings.add(rating);
    } else {
      invalidRatings.add({
        'value': rating,
        'error': error,
      });
    }
  }

  print('Valid ratings: $validRatings');
  print('Invalid ratings:');
  for (final invalid in invalidRatings) {
    final value = invalid['value'];
    final error = invalid['error'] as Map<String, dynamic>;
    final data = error['outOfRange'] as Map<String, dynamic>;
    print('  - $value (allowed range: ${data['min']}-${data['max']})');
  }

  print('');
}

/// Example 5: Using validators in a form builder pattern
class AudioMetadataForm {
  int? _rating;

  String? get ratingError {
    if (_rating == null) return null;
    final error = TagValidators.rating.validate(_rating);
    if (error == null) return null;
    return RatingTag.validator.formatErrorMessage(error);
  }

  bool get isValid => _rating != null && ratingError == null;

  void setRating(int value) {
    _rating = value;
  }

  RatingTag? createRatingTag() {
    if (!isValid) return null;
    return RatingTag(_rating!);
  }
}
