import 'dart:convert';

import 'package:phonic/id3/frames/models/frame_content_model.dart';

abstract class TextModel extends FrameContentModel {
  late String value;

  TextModel(this.value);
}

class Id3v2TextModel extends TextModel {
  late Encoding encoding;

  Id3v2TextModel(this.encoding, String value) : super(value);
}

class Id3v1TextModel extends TextModel {
  final int frameLength;

  Id3v1TextModel(String value, this.frameLength) : super(value);
}
