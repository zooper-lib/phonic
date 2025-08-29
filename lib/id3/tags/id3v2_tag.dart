import 'package:collection/collection.dart';
import 'package:phonic/id3/enums/picture_type.dart';
import 'package:phonic/id3/frames/contents/text_frame_content.dart';
import 'package:phonic/id3/frames/frame_identifiers.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/frames/id3v2_frame.dart';
import 'package:phonic/id3/frames/models/attached_picture_model.dart';
import 'package:phonic/id3/tags/contents/id3v2_content.dart';
import 'package:phonic/id3/tags/id3_tag.dart';
import 'package:phonic/core/models/metadata/metadata_tag.dart';
import 'package:phonic/core/models/metadata/text_tag.dart';
import 'package:phonic/core/models/metadata/numeric_tag.dart';
import 'package:phonic/core/models/metadata/double_tag.dart';
import 'package:phonic/core/models/metadata/title.dart';
import 'package:phonic/core/models/metadata/artist.dart';
import 'package:phonic/core/models/metadata/album.dart';
import 'package:phonic/core/models/metadata/genre.dart';
import 'package:phonic/core/models/metadata/year.dart';
import 'package:phonic/core/models/metadata/comment.dart';
import 'package:phonic/core/models/metadata/track_number.dart';
import 'package:phonic/core/models/metadata/bpm.dart';

import '../enums/frame_name.dart';
import '../frames/models/text_model.dart';
import '../helpers/encoding_helper.dart';
import 'headers/id3v2_header.dart';

class Id3v2Tag extends Id3Tag<Id3v2Header, Id3v2Content, Id3v2Frame> {
  /// Decodes the Id3v2Tag
  static Id3v2Tag? decode(List<int> bytes, int startIndex) {
    final header = Id3v2Header.decode(bytes, startIndex);

    // If the header is not ID3v2 Header, just return
    if (header == null) {
      return null;
    }

    final content = Id3v2Content.decode(header, bytes, startIndex + header.headerSize);

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

    final frameBytes = content.encode();

    header.frameSize = frameBytes.length;
    final headerBytes = header.encode();

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
    final List<AttachedPictureModel> models = [];

    final frames = getFramesByName(FrameName.picture);

    for (var frame in frames) {
      models.add(frame.frameContent.model as AttachedPictureModel);
    }

    return models;
  }

  AttachedPictureModel? getAttachedPictureByType(PictureType type) {
    final pictures = getAttachedPictures();

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
    final identifier = frameIdentifiers.firstWhere((element) => element.frameName == frameName);
    final frameHeader = Id3v2FrameHeader.create(header, identifier);

    final contentModel = Id3v2TextModel(getEncoding(encodingType), content);
    final frameContent = TextFrameContent.create(header, contentModel);

    final frame = Id3v2Frame(header, frameHeader, frameContent);

    addFrame(frame);
  }

  /// Sets a metadata tag using the domain model
  void setTag(MetadataTag tag) {
    final handler = _tagHandlers[tag.runtimeType];
    if (handler != null) {
      handler.setTag(this, tag);
    } else {
      throw UnsupportedError('Unsupported tag type: ${tag.runtimeType}');
    }
  }

  /// Gets a metadata tag by its type
  T? getTag<T extends MetadataTag>() {
    final handler = _tagHandlers[T];
    if (handler != null) {
      return handler.getTag<T>(this);
    }
    return null;
  }

  /// Registry of tag handlers
  static final Map<Type, _Id3v2TagHandler> _tagHandlers = {
    Title: _Id3v2TextTagHandler(FrameName.title, (value) => Title(value)),
    Artist: _Id3v2TextTagHandler(FrameName.artist, (value) => Artist(value)),
    Album: _Id3v2TextTagHandler(FrameName.album, (value) => Album(value)),
    Genre: _Id3v2TextTagHandler(FrameName.contentType, (value) => Genre(value)),
    Comment: _Id3v2TextTagHandler(FrameName.comment, (value) => Comment(value)),
    Year: _Id3v2IntegerTagHandler(FrameName.year, (value) => Year(value)),
    TrackNumber: _Id3v2IntegerTagHandler(FrameName.track, (value) => TrackNumber(value)),
    Bpm: _Id3v2DoubleTagHandler(FrameName.bpm, (value) => Bpm(value)),
  };
}

/// Base handler for ID3v2 tags
abstract class _Id3v2TagHandler {
  void setTag(Id3v2Tag id3v2Tag, MetadataTag tag);
  T? getTag<T extends MetadataTag>(Id3v2Tag id3v2Tag);
}

/// Handler for text-based tags
class _Id3v2TextTagHandler extends _Id3v2TagHandler {
  final FrameName frameName;
  final MetadataTag Function(String) factory;

  _Id3v2TextTagHandler(this.frameName, this.factory);

  @override
  void setTag(Id3v2Tag id3v2Tag, MetadataTag tag) {
    final textTag = tag as TextTag;
    id3v2Tag.deleteFramesByName(frameName);
    if (textTag.hasContent) {
      id3v2Tag._addTextFrame(textTag.value!, frameName, 2);
    }
  }

  @override
  T? getTag<T extends MetadataTag>(Id3v2Tag id3v2Tag) {
    final model = _getTextModel(id3v2Tag, frameName);
    if (model != null && model.value.isNotEmpty) {
      return factory(model.value) as T;
    }
    return null;
  }

  TextModel? _getTextModel(Id3v2Tag id3v2Tag, FrameName frameName) {
    return id3v2Tag.getFramesByName(frameName).firstOrNull?.frameContent.model as TextModel?;
  }
}

/// Handler for integer-based tags
class _Id3v2IntegerTagHandler extends _Id3v2TagHandler {
  final FrameName frameName;
  final MetadataTag Function(int) factory;

  _Id3v2IntegerTagHandler(this.frameName, this.factory);

  @override
  void setTag(Id3v2Tag id3v2Tag, MetadataTag tag) {
    final numericTag = tag as NumericTag;
    id3v2Tag.deleteFramesByName(frameName);
    if (numericTag.hasContent) {
      id3v2Tag._addTextFrame(numericTag.value.toString(), frameName, 2);
    }
  }

  @override
  T? getTag<T extends MetadataTag>(Id3v2Tag id3v2Tag) {
    final model = _getTextModel(id3v2Tag, frameName);
    if (model != null && model.value.isNotEmpty) {
      final intValue = int.tryParse(model.value);
      return intValue != null ? factory(intValue) as T : null;
    }
    return null;
  }

  TextModel? _getTextModel(Id3v2Tag id3v2Tag, FrameName frameName) {
    return id3v2Tag.getFramesByName(frameName).firstOrNull?.frameContent.model as TextModel?;
  }
}

/// Handler for double-based tags
class _Id3v2DoubleTagHandler extends _Id3v2TagHandler {
  final FrameName frameName;
  final MetadataTag Function(double) factory;

  _Id3v2DoubleTagHandler(this.frameName, this.factory);

  @override
  void setTag(Id3v2Tag id3v2Tag, MetadataTag tag) {
    final doubleTag = tag as DoubleTag;
    id3v2Tag.deleteFramesByName(frameName);
    if (doubleTag.hasContent) {
      id3v2Tag._addTextFrame(doubleTag.value.toString(), frameName, 2);
    }
  }

  @override
  T? getTag<T extends MetadataTag>(Id3v2Tag id3v2Tag) {
    final model = _getTextModel(id3v2Tag, frameName);
    if (model != null && model.value.isNotEmpty) {
      final doubleValue = double.tryParse(model.value);
      return doubleValue != null ? factory(doubleValue) as T : null;
    }
    return null;
  }

  TextModel? _getTextModel(Id3v2Tag id3v2Tag, FrameName frameName) {
    return id3v2Tag.getFramesByName(frameName).firstOrNull?.frameContent.model as TextModel?;
  }
}
