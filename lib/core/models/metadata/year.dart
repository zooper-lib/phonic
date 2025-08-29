import 'numeric_tag.dart';

/// Year - represents the release year
final class Year extends NumericTag {
  int? _value;

  Year([this._value]);

  @override
  int? get value => _value;

  @override
  set value(int? newValue) => _value = newValue;

  @override
  int? get minValue => 1900; // Reasonable minimum for music releases

  @override
  int? get maxValue => DateTime.now().year + 10; // Allow some future releases
}
