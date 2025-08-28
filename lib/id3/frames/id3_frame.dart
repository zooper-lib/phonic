import 'package:equatable/equatable.dart';
import 'package:phonic/id3/frames/contents/frame_content.dart';

import 'headers/frame_header.dart';

abstract class Id3Frame<THeader extends FrameHeader, TContent extends FrameContent> extends Equatable {
  final THeader _frameHeader;
  final TContent _frameContent;

  THeader get frameHeader => _frameHeader;
  TContent get frameContent => _frameContent;

  /// The total framesize inclusive header
  int get frameSize => frameHeader.headerSize + frameHeader.contentSize;

  const Id3Frame(
    this._frameHeader,
    this._frameContent,
  );

  /// Converts the Frame to a [List] of [int]
  List<int> encode();

  @override
  String toString() {
    return _frameHeader.identifier.frameName.name;
  }

  @override
  List<Object?> get props => [frameHeader, frameContent];
}
