import 'package:flutter/foundation.dart';
import 'package:quiver/collection.dart';
import 'package:phonic/id3/exceptions/frame_present_exception.dart';
import 'package:phonic/id3/exceptions/unsupported_frame_exception.dart';
import 'package:phonic/id3/frames/id3_frame.dart';

import '../../enums/frame_name.dart';
import '../../frames/models/frame_content_model.dart';

abstract class Id3Content<TFrame extends Id3Frame> {
  final List<TFrame> _frames = [];

  /// Gets all frames
  List<TFrame> get frames => _frames;

  /// Encodes the content with all frames
  List<int> encode();

  /// Returns the Frame stored inside, or null
  List<TFrame> getFramesByName(FrameName name) {
    return _frames.where((element) => element.frameHeader.identifier.frameName == name).toList();
  }

  /// Returns the Frames aas a Multimap
  ///
  /// A multimap is a type found inside
  /// [https://pub.dev/documentation/quiver/latest/quiver.collection/Multimap-class.html]
  Multimap<FrameName, FrameContentModel> getFramesAsMultimap() {
    var map = Multimap<FrameName, FrameContentModel>();

    for (var frame in frames) {
      map.add(frame.frameHeader.identifier.frameName, frame.frameContent.model);
    }

    return map;
  }

  /// Returns all the models of a given frame
  ///
  /// Note: Some frames can only exist once, some can be present multiple times
  List<FrameContentModel> getContentModelsByFrameName(FrameName frameName) {
    return getFramesAsMultimap()[frameName].toList();
  }

  /// Checks if a frame already exists
  bool frameExists(TFrame frame) {
    return _frames.any((element) => element == frame);
  }

  /// Checks if a frame already exists by it's name
  ///
  /// Note: Because there can be multiple frames with different descriptions
  /// which are not defined as "the same" frame, this will not check if the
  /// frame is one of this frames and has a different description.
  /// So if there is such a frame, this method will always return TRUE
  bool containsFrameWithIdentifier(FrameName name) {
    return frames.any((element) => element.frameHeader.identifier.frameName == name);
  }

  /// Checks if the frame is supported by this ID3 version
  bool isFrameSupported(TFrame frame);

  /// Adds a frame if it fits all conditions
  ///
  /// Throws a [UnsupportedFrameException] if the frame is not supported by this ID3 version
  /// Throws a [FramePresentException] if the frame already exists
  void addFrame(TFrame frame) {
    if (isFrameSupported(frame) == false) {
      throw UnsupportedFrameException(frame.frameHeader.identifier.frameName.name);
    }

    if (frameExists(frame)) {
      throw FramePresentException(frame.frameHeader.identifier.frameName.name);
    }

    _frames.insert(0, frame);
  }

  /// Deletes a specific frame
  void deleteFrame(Id3Frame frame);

  /// Deletes all frames with the given identifier
  void deleteFramesByName(FrameName frameName);

  /// Helper to count the frames by it's identifier
  @protected
  int countFramesByIdentifier(FrameName frameName) {
    return _frames.where((element) => element.frameHeader.identifier.frameName == frameName).length;
  }
}
