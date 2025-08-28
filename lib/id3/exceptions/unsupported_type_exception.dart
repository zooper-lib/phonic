import 'id3_exception.dart';

class UnsupportedTypeException extends Id3Exception {
  UnsupportedTypeException(this.type);

  final Type type;

  @override
  String toString() => '$UnsupportedTypeException: The type $type is not supported yet.';
}
