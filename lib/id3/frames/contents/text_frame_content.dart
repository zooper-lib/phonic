import 'dart:convert';

import 'package:zooper_flutter_encoding_utf16/zooper_flutter_encoding_utf16.dart';
import 'package:phonic/id3/constants/terminations.dart';
import 'package:phonic/id3/exceptions/unsupported_version_exception.dart';
import 'package:phonic/id3/frames/headers/id3v1_frame_header.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/frames/models/text_model.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';
import 'package:phonic/id3/tags/headers/id3v1_header.dart';
import 'package:phonic/id3/tags/headers/id3v2_header.dart';

import '../../helpers/encoding_helper.dart';
import '../headers/frame_header.dart';
import 'frame_content.dart';

abstract class TextFrameContent<TModel extends TextModel> extends FrameContent<TModel> {
  factory TextFrameContent.decode(Id3Header header, FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    if (frameHeader is Id3v2FrameHeader) {
      return Id3v2TextFrameContent.decode(bytes, startIndex, size) as TextFrameContent<TModel>;
    } else if (frameHeader is Id3v1FrameHeader) {
      return Id3v1TextFrameContent.decode(bytes, startIndex, size) as TextFrameContent<TModel>;
    }

    throw UnsupportedVersionException(frameHeader.toString());
  }

  factory TextFrameContent.create(Id3Header header, TModel model) {
    switch (header.runtimeType) {
      case Id3v2Header:
        return Id3v2TextFrameContent(model as Id3v2TextModel) as TextFrameContent<TModel>;
      case Id3v1Header:
        return Id3v1TextFrameContent(model as Id3v1TextModel) as TextFrameContent<TModel>;
      default:
        throw UnsupportedVersionException(header.version);
    }
  }

  TextFrameContent(TModel model) : super(model);

  @override
  String toString() => model.value;

  @override
  List<int> encode();
}

class Id3v2TextFrameContent extends TextFrameContent<Id3v2TextModel> {
  factory Id3v2TextFrameContent.decode(List<int> bytes, int startIndex, int size) {
    var sublist = bytes.sublist(startIndex, startIndex + size);

    // Handle no content
    if (sublist.isEmpty) {
      var model = Id3v2TextModel(getEncoding(0), '');
      return Id3v2TextFrameContent(model);
    }

    // Get the encoding
    var encoding = getEncoding(sublist[0]);

    // If there is no content or termination
    if (sublist.length == 1) {
      var model = Id3v2TextModel(encoding, '');
      return Id3v2TextFrameContent(model);
    }

    var termination = Terminations.getByEncoding(encoding);
    bool hasTermination = Terminations.hasTermination(sublist.sublist(1), termination);

    var end = hasTermination ? sublist.length - termination.length : sublist.length;

    // Decode the string
    var value = encoding.decode(sublist.sublist(1, end));

    var model = Id3v2TextModel(encoding, value);

    return Id3v2TextFrameContent(model);
  }

  Id3v2TextFrameContent(Id3v2TextModel model) : super(model);

  @override
  List<int> encode() {
    var encoded = model.encoding is UTF16 ? (model.encoding as UTF16).encodeWithBOM(model.value) : model.encoding.encode(model.value);

    var bytes = <int>[getIdFromEncoding(model.encoding), ...encoded, ...Terminations.getByEncoding(model.encoding)];

    return bytes;
  }
}

class Id3v1TextFrameContent extends TextFrameContent<Id3v1TextModel> {
  factory Id3v1TextFrameContent.decode(List<int> bytes, int startIndex, int size) {
    var subBytes = _clearZeros(bytes.sublist(startIndex, startIndex + size));

    var value = latin1.decode(subBytes);
    var model = Id3v1TextModel(value, size);

    return Id3v1TextFrameContent(model);
  }

  Id3v1TextFrameContent(Id3v1TextModel model) : super(model);

  @override
  List<int> encode() {
    return _filledArray(model.value, model.frameLength);
  }

  /// Removes the NULL characters
  ///
  /// [list]Contains the bytes with potential zeros
  static List<int> _clearZeros(List<int> list) {
    return list.where((i) => i != 0).toList();
  }

  /// Converts the input to a byte List of a specific size
  ///
  /// [inputString]The string to convert
  /// [size]The size of the outputted List
  List<int> _filledArray(String inputString, [int size = 30]) {
    final s = inputString.length > size ? inputString.substring(0, size) : inputString;
    return latin1.encode(s).toList()..addAll(List.filled(size - s.length, 0));
  }
}
