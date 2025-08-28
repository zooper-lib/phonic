import 'dart:convert';
import 'package:collection/collection.dart' as collection;
import 'package:phonic/id3/constants/terminations.dart';
import 'package:phonic/id3/frames/headers/id3v2_frame_header.dart';
import 'package:phonic/id3/frames/models/comment_model.dart';
import 'package:phonic/id3/tags/headers/id3_header.dart';
import 'package:zooper_flutter_encoding_utf16/zooper_flutter_encoding_utf16.dart';

import '../../helpers/encoding_helper.dart';
import 'frame_content.dart';

class CommentFrameContent extends FrameContent<CommentModel> {
  factory CommentFrameContent.decode(Id3Header header, Id3v2FrameHeader frameHeader, List<int> bytes, int startIndex, int size) {
    var subBytes = bytes.sublist(startIndex, startIndex + size);

    // Get the encoding
    var encoding = getEncoding(subBytes[0]);
    var language = _decodeLanguage(subBytes, 1, 3);

    // The index where the description will end
    final splitIndex = encoding is UTF16 ? _indexOfSplitPattern(subBytes, [0x00, 0x00], 4) : subBytes.indexOf(0x00, 4);

    var description = _decodeDescription(subBytes, 4, splitIndex, encoding);

    final offset = splitIndex + (encoding is UTF16 ? 2 : 1);

    var body = _decodeBody(subBytes, offset, encoding);

    var model = CommentModel(encoding, language, description, body);

    return CommentFrameContent(model);
  }

  CommentFrameContent(CommentModel model) : super(model);

  @override
  List<int> encode() {
    return <int>[
      getIdFromEncoding(model.encoding),
      ...latin1.encode(model.language),
      ...model.encoding.encode(model.description),
      ...Terminations.getByEncoding(model.encoding),
      ...model.encoding.encode(model.body),
    ];
  }

  static String _decodeLanguage(List<int> bytes, int startIndex, int length) {
    return latin1.decode(bytes.sublist(startIndex, startIndex + length));
  }

  static String _decodeDescription(List<int> bytes, int startIndex, int endIndex, Encoding encoding) {
    return endIndex < 0 ? '' : encoding.decode(bytes.sublist(startIndex, endIndex));
  }

  static String _decodeBody(List<int> bytes, int startIndex, Encoding encoding) {
    final bodyBytes = bytes.sublist(startIndex);
    return encoding.decode(bodyBytes);
  }

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
