import 'dart:convert';

import 'package:phonic/id3/frames/id3v1_frame.dart';
import 'package:phonic/id3/tags/contents/id3v1_content.dart';
import 'package:phonic/id3/tags/id3_tag.dart';

import 'headers/id3v1_header.dart';

class Id3v1Tag extends Id3Tag<Id3v1Header, Id3v1Content, Id3v1Frame> {
  /// The length of the complete ID3v1 Tag
  ///
  /// This is always 128, everything else is an invalid size
  static const int tagLength = 128;

  Id3v1Tag(Id3v1Header header, Id3v1Content content) : super(header, content);

  /// Decodes the Tag
  ///
  /// Returns null if the tag could not be extracted
  static Id3v1Tag? decode(List<int> bytes) {
    var header = Id3v1Header.decode(bytes, bytes.length - tagLength);

    if (header == null) {
      return null;
    }

    var content = Id3v1Content.decode(header, bytes, bytes.length - tagLength + header.headerSize);

    return Id3v1Tag(header, content);
  }

  @override
  List<int> encode() {
    return <int>[
      ...latin1.encode(header.identifier),
      ...content.encode(),
    ];
  }
}
