# Tag Validators

Phonic provides public validators for validating tag values before creating tags.

## Quick Start

```dart
import 'package:phonic/phonic.dart';

// Validate a rating value
final error = TagValidators.rating.validate(150);
if (error != null) {
  print('Invalid rating: ${error['outOfRange']}');
}

// Or use the convenience method
if (RatingValidator.isValid(85)) {
  final tag = RatingTag(85);
}
```

## Accessing Validators

```dart
// Via TagValidators
TagValidators.rating.validate(value);

// Via tag class
RatingTag.validator.validate(value);

// Direct instantiation
const RatingValidator().validate(value);
```

## Usage

### Pre-validation

```dart
final error = TagValidators.rating.validate(userInput);
if (error != null) {
  // Show error to user
  showError(RatingTag.validator.formatErrorMessage(error));
} else {
  audioFile.setTag(RatingTag(userInput));
}
```

### With Form Libraries

Validators return `null` for valid values and an error map for invalid values, making them compatible with form validation libraries like reactive_forms:

```dart
Validators.delegate((control) => TagValidators.rating.validate(control.value))
```

## Available Validators

- `RatingValidator` - Validates rating values (0-100 range)

See individual validator class documentation for detailed API reference.

## Examples

Complete examples are available in the [example directory](../example/):
- `validator_usage_example.dart` - Basic patterns
- `reactive_forms_integration_example.dart` - Form integration
- `error_handling_example.dart` - Custom error handling
