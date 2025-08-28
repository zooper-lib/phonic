import 'package:phonic/id3/frames/contents/text_frame_content.dart';
import 'package:phonic/id3/frames/headers/frame_header.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';

import 'frame_content.dart';

class Id3v1FrameContentFactory {
  static FrameContent decode(Id3Header header, FrameHeader frameHeader, List<int> bytes, int startIndex) {
    return TextFrameContent.decode(header, frameHeader, bytes, startIndex, frameHeader.identifier.v11Length);
  }
}
