import 'metadata_tag.dart';

/// Abstract base class for double numeric tags
abstract class DoubleTag extends MetadataTag {
  double? get value;
  set value(double? newValue);

  @override
  bool get hasContent => value != null;

  @override
  void clear() => value = null;

  @override
  String toString() => value?.toString() ?? '';

  /// Minimum allowed value
  double? get minValue;

  /// Maximum allowed value
  double? get maxValue;

  @override
  bool get isValid {
    if (!hasContent) return true; // Empty values are valid

    final val = value!;
    final min = minValue;
    final max = maxValue;

    if (min != null && val < min) return false;
    if (max != null && val > max) return false;

    return true;
  }

  @override
  List<String> get validationErrors {
    final errors = <String>[];

    if (!hasContent) return errors; // Empty values are valid

    final val = value!;
    final min = minValue;
    final max = maxValue;

    if (min != null && val < min) {
      errors.add('Value $val is below minimum $min');
    }

    if (max != null && val > max) {
      errors.add('Value $val is above maximum $max');
    }

    return errors;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DoubleTag && other.runtimeType == runtimeType && other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);
}
