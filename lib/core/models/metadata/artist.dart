import 'text_tag.dart';

/// Artist - represents the primary artist/performer
class Artist extends TextTag {
  String? _value;
  
  Artist([this._value]);
  
  @override
  String? get value => _value;
  
  @override
  set value(String? newValue) => _value = newValue;
  
  @override
  int? get maxLength => null; // No limit at domain level
}
