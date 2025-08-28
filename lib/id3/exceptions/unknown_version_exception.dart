import 'id3_exception.dart';

class UnknownVersionException extends Id3Exception {
  @override
  String toString() => '$UnknownVersionException: unable to read the ID3 version';
}
