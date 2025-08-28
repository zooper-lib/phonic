import 'package:collection/collection.dart';
import 'package:phonic/id3/enums/picture_type.dart';
import 'package:phonic/id3/frames/contents/text_frame_content.dart';
import 'package:phonic/id3/frames/frame_identifiers.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/frames/id3v2_frame.dart';
import 'package:phonic/id3/frames/models/attached_picture_model.dart';
import 'package:phonic/id3/tags/contents/id3v2_content.dart';
import 'package:phonic/id3/tags/id3_tag.dart';

import '../enums/frame_name.dart';
import '../frames/models/text_model.dart';
import '../helpers/encoding_helper.dart';
import 'headers/id3v2_header.dart';

class Id3v2Tag extends Id3Tag<Id3v2Header, Id3v2Content, Id3v2Frame> {
  /// Decodes the Id3v2Tag
  static Id3v2Tag? decode(List<int> bytes, int startIndex) {
    var header = Id3v2Header.decode(bytes, startIndex);

    // If the header is not ID3v2 Header, just return
    if (header == null) {
      return null;
    }

    var content = Id3v2Content.decode(header, bytes, startIndex + header.headerSize);

    return Id3v2Tag(header, content);
  }

  Id3v2Tag(Id3v2Header header, Id3v2Content content) : super(header, content);

  /// Returns the full size of the v2 tag
  ///
  /// Because other softwares are setting the wrong tag size or padding
  /// this is needed in order to extract ALL audio data
  int get fullSize => header.headerSize + header.frameSize;

  @override
  List<int> encode() {
    // Don't encode if no frame is present
    if (content.frames.isEmpty) {
      return <int>[];
    }

    var frameBytes = content.encode();

    header.frameSize = frameBytes.length;
    var headerBytes = header.encode();

    return <int>[...headerBytes, ...frameBytes];
  }

  TextModel? getArtistModel() => getFramesByName(FrameName.artist).firstOrNull?.frameContent.model as TextModel?;

  TextModel? getTitleModel() => getFramesByName(FrameName.title).firstOrNull?.frameContent.model as TextModel?;

  TextModel? getAlbumModel() => getFramesByName(FrameName.album).firstOrNull?.frameContent.model as TextModel?;

  TextModel? getGenreModel() => getFramesByName(FrameName.contentType).firstOrNull?.frameContent.model as TextModel?;

  // TODO: Change this to an numeric Frame
  TextModel? getBPMModel() => getFramesByName(FrameName.bpm).firstOrNull?.frameContent.model as TextModel?;

  TextModel? getCommentModel() => getFramesByName(FrameName.comment).firstOrNull?.frameContent.model as TextModel?;

  TextModel? getContentGroupDescriptionModel() => getFramesByName(FrameName.contentGroupDescription).firstOrNull?.frameContent.model as TextModel?;

  List<AttachedPictureModel> getAttachedPictures() {
    List<AttachedPictureModel> models = [];

    var frames = getFramesByName(FrameName.picture);

    for (var frame in frames) {
      models.add(frame.frameContent.model as AttachedPictureModel);
    }

    return models;
  }

  AttachedPictureModel? getAttachedPictureByType(PictureType type) {
    var pictures = getAttachedPictures();

    return pictures.firstWhereOrNull((element) => element.pictureType == type);
  }

  void addArtist(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.artist, encodingType);

  void addTitle(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.title, encodingType);

  void addAlbum(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.album, encodingType);

  // TODO: Change this to an numeric Frame
  void addGenre(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.contentType, encodingType);

  void addBPM(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.bpm, encodingType);

  void addComment(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.comment, encodingType);

  void addContentGroupDescription(String content, [int encodingType = 2]) => _addTextFrame(content, FrameName.contentGroupDescription, encodingType);

  void _addTextFrame(String content, FrameName frameName, int encodingType) {
    var identifier = frameIdentifiers.firstWhere((element) => element.frameName == frameName);
    var frameHeader = Id3v2FrameHeader.create(header, identifier);

    var contentModel = Id3v2TextModel(getEncoding(encodingType), content);
    var frameContent = TextFrameContent.create(header, contentModel);

    var frame = Id3v2Frame(header, frameHeader, frameContent);

    addFrame(frame);
  }
}
