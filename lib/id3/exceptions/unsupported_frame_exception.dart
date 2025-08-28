import 'id3_exception.dart';

class UnsupportedFrameException extends Id3Exception {
  UnsupportedFrameException(this.identifier);

  final String identifier;

  @override
  String toString() => '$UnsupportedFrameException: The Frame with identifier $identifier is not supported yet.';
}
