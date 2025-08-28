import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/frames/models/raw_model.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';

import 'frame_content.dart';

class IgnoredFrameContent extends FrameContent<RawModel> {
  factory IgnoredFrameContent.decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    var content = bytes.sublist(startIndex, startIndex + size);

    var model = RawModel(content);

    return IgnoredFrameContent(model);
  }

  IgnoredFrameContent(RawModel model) : super(model);

  @override
  List<int> encode() {
    return model.content;
  }
}
