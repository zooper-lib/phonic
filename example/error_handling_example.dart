/// Example demonstrating improved error handling with descriptive error keys
///
/// This example shows how the new error structure makes it easy to:
/// 1. Identify specific validation problems
/// 2. Provide precise user feedback
/// 3. Handle different error types appropriately
library;

// ignore_for_file: avoid_print

import 'package:phonic/phonic.dart';

/// Simulate a form model
class RatingFormModel {
  int? _rating;
  bool _touched = false;

  void setRating(int? value) {
    _rating = value;
    _touched = true;
  }

  String? getError() {
    if (!_touched) return null;

    // In a real form, you might check for required first
    if (_rating == null) {
      return 'Rating is required';
    }

    // Then validate the value
    final error = TagValidators.rating.validate(_rating);
    if (error == null) return null;

    // Handle different error types with appropriate messages
    if (error.containsKey('outOfRange')) {
      final data = error['outOfRange'] as Map<String, dynamic>;
      return 'Rating must be between ${data['min']} and ${data['max']}. '
          'You entered ${data['actual']}.';
    }

    return 'Invalid rating';
  }

  bool get isValid => _touched && _rating != null && getError() == null;
}

void main() {
  print('=== Descriptive Error Keys Example ===\n');

  // Example 1: Specific error handling based on error type
  specificErrorHandling();

  // Example 2: User-friendly error messages
  userFriendlyMessages();

  // Example 3: Form validation with multiple error types
  formValidationExample();
}

/// Example 1: Handle different error types specifically
void specificErrorHandling() {
  print('Example 1: Specific Error Type Handling');
  print('─' * 50);

  final testCases = [
    (150, 'Value too high'),
    (-10, 'Value too low'),
    (50, 'Valid value'),
  ];

  for (final (value, description) in testCases) {
    final error = TagValidators.rating.validate(value);

    if (error == null) {
      print('✓ $description ($value): Valid');
    } else {
      // We can check the specific error type
      if (error.containsKey('outOfRange')) {
        final data = error['outOfRange'] as Map<String, dynamic>;
        final actual = data['actual'] as int;
        final min = data['min'] as int;
        final max = data['max'] as int;

        if (actual < min) {
          print('✗ $description ($value): Too low (minimum is $min)');
        } else {
          print('✗ $description ($value): Too high (maximum is $max)');
        }
      }
      // In the future, we could handle other error types:
      // else if (error.containsKey('required')) { ... }
      // else if (error.containsKey('invalidFormat')) { ... }
    }
  }
  print('');
}

/// Example 2: Generate user-friendly messages for different error types
void userFriendlyMessages() {
  print('Example 2: User-Friendly Error Messages');
  print('─' * 50);

  String getUserMessage(Map<String, dynamic> error) {
    // Handle outOfRange error
    if (error.containsKey('outOfRange')) {
      final data = error['outOfRange'] as Map<String, dynamic>;
      final actual = data['actual'] as int;
      final min = data['min'] as int;
      final max = data['max'] as int;

      if (actual < min) {
        return '🔻 Oops! The rating $actual is too low. '
            'Please choose a value of at least $min.';
      } else {
        return '🔺 Oops! The rating $actual is too high. '
            'Please choose a value no greater than $max.';
      }
    }

    // Future: Handle other error types
    // if (error.containsKey('required')) {
    //   return '⚠️ This field is required. Please enter a value.';
    // }
    // if (error.containsKey('invalidFormat')) {
    //   return '❌ The format is incorrect. Please check your input.';
    // }

    return 'Invalid value';
  }

  final testValues = [200, -5, 75];
  for (final value in testValues) {
    final error = TagValidators.rating.validate(value);
    if (error != null) {
      print(getUserMessage(error));
    } else {
      print('✅ Rating $value is perfect!');
    }
  }
  print('');
}

/// Example 3: Form validation with multiple potential error types
void formValidationExample() {
  print('Example 3: Form Validation');
  print('─' * 50);

  // Test the form model
  final form = RatingFormModel();

  print('Initial state:');
  print('  Error: ${form.getError()}');
  print('  Valid: ${form.isValid}');
  print('');

  print('After setting invalid value (150):');
  form.setRating(150);
  print('  Error: ${form.getError()}');
  print('  Valid: ${form.isValid}');
  print('');

  print('After setting valid value (85):');
  form.setRating(85);
  print('  Error: ${form.getError()}');
  print('  Valid: ${form.isValid}');
  print('');
}

/// Example 4: Error type routing (commented out, shows future possibilities)
/*
void errorTypeRouting() {
  print('Example 4: Error Type Routing');
  print('─' * 50);

  enum ValidationErrorType {
    outOfRange,
    required,
    invalidFormat,
    customError,
  }

  ValidationErrorType? getErrorType(Map<String, dynamic> error) {
    if (error.containsKey('outOfRange')) return ValidationErrorType.outOfRange;
    if (error.containsKey('required')) return ValidationErrorType.required;
    if (error.containsKey('invalidFormat')) return ValidationErrorType.invalidFormat;
    return ValidationErrorType.customError;
  }

  void handleError(Map<String, dynamic> error) {
    switch (getErrorType(error)) {
      case ValidationErrorType.outOfRange:
        final data = error['outOfRange'];
        print('Handle out of range: ${data['actual']} not in ${data['min']}-${data['max']}');
        break;
      case ValidationErrorType.required:
        print('Handle required field error');
        break;
      case ValidationErrorType.invalidFormat:
        print('Handle format error');
        break;
      case ValidationErrorType.customError:
        print('Handle unknown error type');
        break;
      case null:
        print('No error');
        break;
    }
  }

  final error = TagValidators.rating.validate(150);
  if (error != null) {
    handleError(error);
  }
}
*/
