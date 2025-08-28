import 'package:phonic/id3/frames/contents/frame_content.dart';
import 'package:phonic/id3/frames/contents/id3v1_frame_content_factory.dart';
import 'package:phonic/id3/frames/frame_identifier.dart';
import 'package:phonic/id3/frames/headers/id3v1_frame_header.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';

import 'headers/frame_header.dart';
import 'id3_frame.dart';

class Id3v1Frame<T> extends Id3Frame {
  factory Id3v1Frame.decode(Id3Header header, List<int> bytes, int startIndex, FrameIdentifier identifier) {
    // Decode the header
    var frameHeader = Id3v1FrameHeader(identifier);

    // Decode the content
    var frameContent = Id3v1FrameContentFactory.decode(
      header,
      frameHeader,
      bytes,
      startIndex,
    );

    return Id3v1Frame(frameHeader, frameContent);
  }

  const Id3v1Frame(FrameHeader frameHeader, FrameContent frameContent) : super(frameHeader, frameContent);

  @override
  List<int> encode() {
    return frameContent.encode();
  }
}
