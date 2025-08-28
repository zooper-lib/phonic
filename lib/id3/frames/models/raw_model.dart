import 'package:phonic/id3/frames/models/frame_content_model.dart';

class RawModel extends FrameContentModel {
  final List<int> _content;

  List<int> get content => _content;

  RawModel(this._content);
}
