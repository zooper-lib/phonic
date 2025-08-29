import 'metadata_tag.dart';

/// Abstract base class for numeric tags
abstract class NumericTag extends MetadataTag {
  int? get value;
  set value(int? newValue);

  @override
  bool get hasContent => value != null;

  @override
  void clear() => value = null;

  @override
  String toString() => value?.toString() ?? '';

  /// Minimum allowed value
  int? get minValue;

  /// Maximum allowed value
  int? get maxValue;

  @override
  bool get isValid {
    if (value == null) return true;
    if (minValue != null && value! < minValue!) return false;
    if (maxValue != null && value! > maxValue!) return false;
    return isValueValid(value!);
  }

  @override
  List<String> get validationErrors {
    final errors = <String>[];
    if (value != null) {
      if (minValue != null && value! < minValue!) {
        errors.add('Value must be at least $minValue');
      }
      if (maxValue != null && value! > maxValue!) {
        errors.add('Value must not exceed $maxValue');
      }
      errors.addAll(getValueValidationErrors(value!));
    }
    return errors;
  }

  /// Override this to add custom validation logic
  bool isValueValid(int value) => true;

  /// Override this to add custom validation error messages
  List<String> getValueValidationErrors(int value) => [];
}
