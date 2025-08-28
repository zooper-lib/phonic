import 'dart:convert';
import 'package:collection/collection.dart' as collection;
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';

import '../../constants/terminations.dart';
import '../../enums/picture_type.dart';
import '../../helpers/encoding_helper.dart';
import '../models/attached_picture_model.dart';
import 'frame_content.dart';

abstract class AttachedPictureFrameContent extends FrameContent<AttachedPictureModel> {
  factory AttachedPictureFrameContent.decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    switch (header.majorVersion) {
      case 4:
      case 3:
        return Id3v23AttachedPictureFrameContent.decode(header, frameHeader, bytes, startIndex, size);
      case 2:
        return Id3v22AttachedPictureFrameContent.decode(header, frameHeader, bytes, startIndex, size);
      default:
        throw UnimplementedError('APIC frame decoding for version ${header.version} is not implemented yet');
    }
  }

  AttachedPictureFrameContent(AttachedPictureModel model) : super(model);

  static int _indexOfSplitPattern(List<int> list, List<int> pattern, [int initialOffset = 0]) {
    for (var i = initialOffset; i < list.length - pattern.length; i += pattern.length) {
      final l = list.sublist(i, i + pattern.length);
      if (const collection.ListEquality().equals(l, pattern)) {
        return i;
      }
    }
    return -1;
  }
}

class Id3v22AttachedPictureFrameContent extends AttachedPictureFrameContent {
  static Id3v22AttachedPictureFrameContent decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    var subBytes = bytes.sublist(startIndex, startIndex + size);

    // Get the encoding
    var encoding = getEncoding(subBytes[0]);

    // Get the MIME-type
    var mimeType = _decodeMIMEType(subBytes, 1, 4);

    // Get the picture type
    var pictureType = _decodePictureType(subBytes, 4);

    // Get the description
    var termination = Terminations.getByEncoding(encoding);
    const startOfDescription = 5;
    final endOfDescription = AttachedPictureFrameContent._indexOfSplitPattern(subBytes, termination, startOfDescription);
    var description = _decodeDescription(subBytes, startOfDescription, endOfDescription, encoding);

    // Get the data
    final startOfData = endOfDescription + termination.length;
    final imageData = _decodePictureData(subBytes, startOfData);

    var model = AttachedPictureModel(encoding, mimeType, pictureType, description, imageData);

    return Id3v22AttachedPictureFrameContent(model);
  }

  Id3v22AttachedPictureFrameContent(AttachedPictureModel model) : super(model);

  static String _decodeMIMEType(List<int> bytes, int start, int end) {
    return latin1.decode(bytes.sublist(start, end));
  }

  static PictureType _decodePictureType(List<int> bytes, int start) {
    return PictureType.values[bytes[start]];
  }

  static String _decodeDescription(List<int> bytes, int start, int end, Encoding encoding) {
    return encoding.decode(bytes.sublist(start, end));
  }

  static List<int> _decodePictureData(List<int> bytes, int start) {
    return bytes.sublist(start);
  }

  @override
  List<int> encode() {
    final mimeEncoded = model.encoding.encode(model.mimeType);
    final descriptionEncoded = model.encoding.encode(model.description);

    return <int>[
      getIdFromEncoding(model.encoding),
      ...mimeEncoded,
      model.pictureType.index,
      ...descriptionEncoded,
      ...Terminations.getByEncoding(model.encoding),
      ...model.imageData,
    ];
  }
}

class Id3v23AttachedPictureFrameContent extends AttachedPictureFrameContent {
  static Id3v23AttachedPictureFrameContent decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    var subBytes = bytes.sublist(startIndex, startIndex + size);

    // Get the encoding
    var encoding = getEncoding(subBytes[0]);

    // Get the MIME-type
    final endOfMIMEBytes = subBytes.indexOf(0x00, 1);
    var mimeType = _decodeMIMEType(subBytes, 1, endOfMIMEBytes);

    // Get the picture type
    var pictureType = _decodePictureType(subBytes, endOfMIMEBytes + 1);

    // Get the description
    var termination = Terminations.getByEncoding(encoding);
    final startOfDescription = endOfMIMEBytes + 2;
    final endOfDescription = AttachedPictureFrameContent._indexOfSplitPattern(subBytes, termination, startOfDescription);
    var description = _decodeDescription(subBytes, startOfDescription, endOfDescription, encoding);

    // Get the data
    final startOfData = endOfDescription + termination.length;
    final imageData = _decodePictureData(subBytes, startOfData);

    var model = AttachedPictureModel(encoding, mimeType, pictureType, description, imageData);

    return Id3v23AttachedPictureFrameContent(model);
  }

  Id3v23AttachedPictureFrameContent(AttachedPictureModel model) : super(model);

  static String _decodeMIMEType(List<int> bytes, int start, int end) {
    return latin1.decode(bytes.sublist(start, end));
  }

  static PictureType _decodePictureType(List<int> bytes, int start) {
    return PictureType.values[bytes[start]];
  }

  static String _decodeDescription(List<int> bytes, int start, int end, Encoding encoding) {
    return encoding.decode(bytes.sublist(start, end));
  }

  static List<int> _decodePictureData(List<int> bytes, int start) {
    return bytes.sublist(start);
  }

  @override
  List<int> encode() {
    final mimeEncoded = model.encoding.encode(model.mimeType);
    final descriptionEncoded = model.encoding.encode(model.description);

    return <int>[
      getIdFromEncoding(model.encoding),
      ...mimeEncoded,
      ...Terminations.getByEncoding(model.encoding),
      model.pictureType.index,
      ...descriptionEncoded,
      ...Terminations.getByEncoding(model.encoding),
      ...model.imageData,
    ];
  }
}
