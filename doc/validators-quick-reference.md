# Tag Validators - Quick Reference

## Import

```dart
import 'package:phonic/phonic.dart';
```

## Basic Validation

```dart
// Validate a value
final error = TagValidators.rating.validate(userInput);

if (error == null) {
  // Valid ✓
  final tag = RatingTag(userInput);
} else {
  // Invalid ✗
  print('Error: $error');
}
```

## Quick Boolean Check

```dart
if (RatingValidator.isValid(userInput)) {
  // Value is valid
}
```

## reactive_forms Integration

```dart
final form = FormGroup({
  'rating': FormControl<int>(
    validators: [
      Validators.delegate(
        (control) => TagValidators.rating.validate(control.value),
      ),
    ],
  ),
});
```

## Custom Error Messages

```dart
ReactiveTextField<int>(
  formControlName: 'rating',
  validationMessages: {
    'outOfRange': (error) {
      final e = error as Map;
      return 'Must be ${e['min']}-${e['max']}, got ${e['actual']}';
    },
  },
)
```

## Error Structure

```dart
// RatingValidator returns:
{
  'outOfRange': {
    'min': 0,
    'max': 100,
    'actual': 150  // The invalid value
  }
}
```

## Available Validators

| Validator | Range/Rule | Access |
|-----------|------------|--------|
| RatingValidator | 0-100 | `TagValidators.rating` or `RatingTag.validator` |

## Common Patterns

### Pre-validate Input

```dart
void handleUserInput(String text) {
  final value = int.tryParse(text);
  final error = TagValidators.rating.validate(value);
  
  if (error != null) {
    showError(RatingTag.validator.formatErrorMessage(error));
    return;
  }
  
  audioFile.setTag(RatingTag(value!));
}
```

### Form Validation

```dart
class MetadataForm {
  final form = FormGroup({
    'rating': FormControl<int>(
      validators: [
        Validators.delegate((c) => TagValidators.rating.validate(c.value)),
      ],
    ),
  });
}
```

### Batch Validation

```dart
final validRatings = userInputs
  .where((value) => TagValidators.rating.validate(value) == null)
  .toList();
```

## API Methods

### TagValidator<T>

```dart
// Returns error map or null
Map<String, dynamic>? validate(T? value)

// Throws ArgumentError on invalid
T validateOrThrow(T value)

// Format error message
String formatErrorMessage(Map<String, dynamic> error)
```

### RatingValidator

```dart
// Constants
static const int min = 0;
static const int max = 100;
static const String outOfRangeError = 'outOfRange';

// Quick check
static bool isValid(int? value)
```

## Examples

See full examples in:
- `example/validator_usage_example.dart`
- `example/reactive_forms_integration_example.dart`
- `doc/validators.md`

## Error Messages

```dart
// Use validator's built-in formatting
final message = RatingTag.validator.formatErrorMessage(error);

// Or create custom messages
final data = error['outOfRange'];
final message = 'Rating ${data['actual']} is out of range (${data['min']}-${data['max']})';
```

## Best Practices

✅ **DO** validate early (on input change)  
✅ **DO** use `isValid()` for simple checks  
✅ **DO** reuse validator instances via `TagValidators`  
✅ **DO** provide helpful error messages  

❌ **DON'T** create new validator instances repeatedly  
❌ **DON'T** use exceptions for validation flow  
❌ **DON'T** forget to handle null values  

## Migration

```dart
// Old way (still works)
try {
  final tag = RatingTag(userInput);
} on ArgumentError catch (e) {
  showError(e.message);
}

// New way (recommended)
final error = TagValidators.rating.validate(userInput);
if (error == null) {
  final tag = RatingTag(userInput);
} else {
  showError(RatingTag.validator.formatErrorMessage(error));
}
```
