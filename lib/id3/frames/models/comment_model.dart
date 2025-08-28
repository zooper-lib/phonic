import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:phonic/id3/frames/models/frame_content_model.dart';

class CommentModel extends FrameContentModel with EquatableMixin {
  late Encoding encoding;
  late String language;
  late String description;
  late String body;

  CommentModel(this.encoding, this.language, this.description, this.body);

  @override
  List<Object?> get props => [language, description, body];
}
