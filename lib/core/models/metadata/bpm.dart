import 'double_tag.dart';

/// Bpm - represents the tempo of the track (Beats Per Minute)
class Bpm extends DoubleTag {
  double? _value;

  Bpm([this._value]);

  @override
  double? get value => _value;

  @override
  set value(double? newValue) => _value = newValue;

  @override
  double? get minValue => 1.0;

  @override
  double? get maxValue => 500.0; // Reasonable limit for music at domain level
}
