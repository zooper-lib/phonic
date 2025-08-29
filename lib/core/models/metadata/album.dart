import 'text_tag.dart';

/// Album - represents the album name
class Album extends TextTag {
  String? _value;
  
  Album([this._value]);
  
  @override
  String? get value => _value;
  
  @override
  set value(String? newValue) => _value = newValue;
  
  @override
  int? get maxLength => null; // No limit at domain level
}
