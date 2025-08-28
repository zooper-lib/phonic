import '../models/frame_content_model.dart';

abstract class FrameContent<TModel extends FrameContentModel> {
  late TModel model;

  FrameContent(this.model);

  List<int> encode();
}
