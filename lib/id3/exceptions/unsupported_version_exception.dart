import 'id3_exception.dart';

class UnsupportedVersionException extends Id3Exception {
  UnsupportedVersionException(this.versionName);

  final String versionName;

  @override
  String toString() => '$UnsupportedVersionException: the version $versionName'
      'is not supported yet.';
}
