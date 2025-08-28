import 'package:phonic/id3/frames/frame_identifier.dart';
import 'package:phonic/id3/frames/headers/frame_header.dart';

class Id3v1FrameHeader extends FrameHeader {
  Id3v1FrameHeader(FrameIdentifier identifier) : super(identifier);

  @override
  int get contentSize => identifier.v11Length;

  @override
  int get headerSize => 0;
}
