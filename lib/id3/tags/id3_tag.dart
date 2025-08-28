import 'package:quiver/collection.dart';
import 'package:phonic/id3/enums/frame_name.dart';
import 'package:phonic/id3/frames/id3_frame.dart';
import 'package:phonic/id3/frames/models/frame_content_model.dart';
import 'package:phonic/id3/tags/contents/id3_content.dart';

import 'headers/id3_header.dart';

abstract class Id3Tag<THeader extends Id3Header, TContent extends Id3Content, TFrame extends Id3Frame> {
  final THeader _header;
  final TContent _content;

  THeader get header => _header;
  TContent get content => _content;

  Id3Tag(this._header, this._content);

  /// Adds a frame to the list
  void addFrame(TFrame frame) {
    _content.addFrame(frame);
  }

  /// Returns the Frame stored inside, or null
  List<TFrame> getFramesByName(FrameName name) => content.getFramesByName(name).cast<TFrame>().toList();

  /// Gets all available frames
  List<TFrame> getFrames() => content.frames.cast<TFrame>();

  /// Returns the Frames aas a Multimap
  ///
  /// A multimap is a type found inside
  /// [https://pub.dev/documentation/quiver/latest/quiver.collection/Multimap-class.html]
  Multimap<FrameName, FrameContentModel> getFramesAsMultimap() => content.getFramesAsMultimap();

  /// Returns all the models of a given frame
  ///
  /// Note: Some frames can only exist once, some can be present multiple times
  List<FrameContentModel> getContentModelsByFrameName(FrameName frameName) =>
      content.getContentModelsByFrameName(frameName);

  /// Checks if a frame already exists by it's name
  ///
  /// Note: Because there can be multiple frames with different descriptions
  /// which are not defined as "the same" frame, this will not check if the
  /// frame is one of this frames and has a different description.
  /// So if there is such a frame, this method will always return TRUE
  bool containsFrameWithIdentifier(FrameName frameName) => content.containsFrameWithIdentifier(frameName);

  /// Encodes the tag
  List<int> encode();

  /// Deletes a specific frame
  void deleteFrame(Id3Frame frame) => content.deleteFrame(frame);

  /// Deletes all frames with the given identifier
  void deleteFramesByName(FrameName frameName) => content.deleteFramesByName(frameName);
}
