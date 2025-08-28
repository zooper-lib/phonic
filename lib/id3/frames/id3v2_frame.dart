import 'package:phonic/id3/frames/contents/frame_content.dart';
import 'package:phonic/id3/frames/contents/id3v2_frame_content_factory.dart';
import 'package:phonic/id3/frames/id3_frame.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';
import 'package:phonic/id3/tags/headers/id3v2_header.dart';

class Id3v2Frame extends Id3Frame<Id3v2FrameHeader, FrameContent> {
  const Id3v2Frame(
    Id3Header header,
    Id3v2FrameHeader frameHeader,
    FrameContent frameContent,
  ) : super(frameHeader, frameContent);

  static Id3v2Frame? decode(
    Id3Header header,
    List<int> bytes,
    int startIndex,
  ) {
    // Decode the header
    var frameHeader = Id3v2FrameHeader.decode(
      header as Id3v2Header,
      bytes,
      startIndex,
    );

    if (frameHeader == null) return null;

    // Decode the content
    var frameContent = Id3v2FrameContentFactory.decode(
      header,
      frameHeader,
      bytes,
      startIndex + frameHeader.headerSize,
      frameHeader.contentSize,
    );

    return Id3v2Frame(header, frameHeader, frameContent);
  }

  @override
  List<int> encode() {
    var frameContentBytes = frameContent.encode();
    frameHeader.contentSize = frameContentBytes.length;

    var frameHeaderBytes = frameHeader.encode();

    var frameBytes = <int>[
      ...frameHeaderBytes,
      ...frameContentBytes,
    ];

    return frameBytes;
  }
}
