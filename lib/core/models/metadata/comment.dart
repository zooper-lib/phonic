import 'text_tag.dart';

/// Comment - represents user comments or notes
class Comment extends TextTag {
  String? _value;
  
  Comment([this._value]);
  
  @override
  String? get value => _value;
  
  @override
  set value(String? newValue) => _value = newValue;
  
  @override
  int? get maxLength => null; // No limit at domain level
}
