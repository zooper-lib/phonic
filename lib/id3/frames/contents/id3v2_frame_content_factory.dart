import 'package:phonic/id3/enums/frame_name.dart';
import 'package:phonic/id3/frames/contents/attached_picture_frame_content.dart';
import 'package:phonic/id3/frames/contents/frame_content.dart';
import 'package:phonic/id3/frames/contents/ignored_frame_content.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';

import '../frame_type.dart';
import 'comment_frame_content.dart';
import 'text_frame_content.dart';

class Id3v2FrameContentFactory {
  static FrameContent decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    switch (frameHeader.identifier.frameType) {
      case FrameType.custom:
        switch (frameHeader.identifier.frameName) {
          case FrameName.picture:
            return AttachedPictureFrameContent.decode(header, frameHeader, bytes, startIndex, size);

          case FrameName.comment:
            return CommentFrameContent.decode(header, frameHeader, bytes, startIndex, size);

          // TODO: Implement additional info
          case FrameName.additionalInfo:
            return IgnoredFrameContent.decode(header, frameHeader, bytes, startIndex, size);

          default:
            return IgnoredFrameContent.decode(header, frameHeader, bytes, startIndex, size);
        }

      case FrameType.text:
        return TextFrameContent.decode(header, frameHeader, bytes, startIndex, size);

      case FrameType.url:
        // TODO: Implement URL frames
        return IgnoredFrameContent.decode(header, frameHeader, bytes, startIndex, size);

      case FrameType.other:
        return IgnoredFrameContent.decode(header, frameHeader, bytes, startIndex, size);
    }
  }

  /// Returns size of frame in bytes
  List<int> frameSizeInBytes(int value) {
    assert(value <= 16777216);

    final block = List<int>.filled(4, 0);
    const sevenBitMask = 0x7f;

    block[0] = (value >> 21) & sevenBitMask;
    block[1] = (value >> 14) & sevenBitMask;
    block[2] = (value >> 7) & sevenBitMask;
    block[3] = (value >> 0) & sevenBitMask;

    return block;
  }
}
