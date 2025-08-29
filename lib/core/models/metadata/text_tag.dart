import 'metadata_tag.dart';

/// Abstract base class for text-based tags
abstract class TextTag extends MetadataTag {
  String? get value;
  set value(String? newValue);

  @override
  bool get hasContent => value != null && value!.trim().isNotEmpty;

  @override
  void clear() => value = null;

  @override
  String toString() => value ?? '';

  /// Maximum allowed length for this tag (format-specific)
  int? get maxLength;

  @override
  bool get isValid {
    if (value == null) return true; // Null is always valid
    if (maxLength != null && value!.length > maxLength!) return false;
    return isValueValid(value!);
  }

  @override
  List<String> get validationErrors {
    final errors = <String>[];
    if (value != null) {
      if (maxLength != null && value!.length > maxLength!) {
        errors.add('Value exceeds maximum length of $maxLength characters');
      }
      errors.addAll(getValueValidationErrors(value!));
    }
    return errors;
  }

  /// Override this to add custom validation logic
  bool isValueValid(String value) => true;

  /// Override this to add custom validation error messages
  List<String> getValueValidationErrors(String value) => [];
}
