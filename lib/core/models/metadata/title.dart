import 'text_tag.dart';

/// Title - represents the title of a track
class Title extends TextTag {
  String? _value;
  
  Title([this._value]);
  
  @override
  String? get value => _value;
  
  @override
  set value(String? newValue) => _value = newValue;
  
  @override
  int? get maxLength => null; // No limit at domain level
}
