import 'text_tag.dart';

/// Genre - represents the music genre
class Genre extends TextTag {
  String? _value;
  
  Genre([this._value]);
  
  @override
  String? get value => _value;
  
  @override
  set value(String? newValue) => _value = newValue;
  
  @override
  int? get maxLength => null; // No limit at domain level
}
