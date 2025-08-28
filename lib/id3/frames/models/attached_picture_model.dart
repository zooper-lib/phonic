import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:phonic/id3/enums/picture_type.dart';
import 'package:phonic/id3/frames/models/frame_content_model.dart';

class AttachedPictureModel extends FrameContentModel with EquatableMixin {
  Encoding encoding;
  String mimeType;
  PictureType pictureType;
  String description;
  List<int> imageData;

  /// Returns image data as BASE64 string
  String get imageData64 => base64.encode(imageData);

  AttachedPictureModel(this.encoding, this.mimeType, this.pictureType, this.description, this.imageData);

  AttachedPictureModel.fromBase64(this.encoding, this.mimeType, this.pictureType, this.description, String base64String)
    : imageData = base64.decode(base64String);

  /// An attached picture is only equals, if the [description] is the same
  @override
  List<Object?> get props => [description];
}
