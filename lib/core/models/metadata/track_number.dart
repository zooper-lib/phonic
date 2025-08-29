import 'numeric_tag.dart';

/// TrackNumber - represents the track position in an album
class TrackNumber extends NumericTag {
  int? _value;
  
  TrackNumber([this._value]);
  
  @override
  int? get value => _value;
  
  @override
  set value(int? newValue) => _value = newValue;
  
  @override
  int? get minValue => 1;
  
  @override
  int? get maxValue => 9999; // Reasonable limit at domain level
}
