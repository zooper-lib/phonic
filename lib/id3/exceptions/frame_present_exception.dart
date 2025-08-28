import 'id3_exception.dart';

class FramePresentException extends Id3Exception {
  FramePresentException(this.identifier);

  final String identifier;

  @override
  String toString() => '$FramePresentException: The Frame with identifier $identifier already exists.';
}
