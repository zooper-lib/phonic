import 'package:flutter/foundation.dart';

abstract class Id3Header {
  static const int majorSize = 1;
  static const int minorSize = 1;

  late int _majorVersion;

  String get identifier;
  int get majorVersion => _majorVersion;

  String get version;

  int get headerSize;

  @protected
  set majorVersion(int value) {
    _majorVersion = value;
  }

  List<int> encode();
}
