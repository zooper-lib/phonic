import 'package:phonic/id3/frames/frame_identifier.dart';

abstract class FrameHeader {
  final FrameIdentifier _identifier;

  FrameIdentifier get identifier => _identifier;
  int get headerSize;

  int contentSize = 0;

  FrameHeader(
    this._identifier,
  );
}
