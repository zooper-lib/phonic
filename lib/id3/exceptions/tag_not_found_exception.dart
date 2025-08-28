import 'id3_exception.dart';

class TagNotFoundException extends Id3Exception {
  TagNotFoundException(this.identifier);

  final String identifier;

  @override
  String toString() => '$TagNotFoundException: No tag existent with identifier $identifier';
}
