import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:phonic/id3/exceptions/unsupported_version_exception.dart';
import 'package:phonic/id3/frames/frame_identifier.dart';
import 'package:phonic/id3/frames/frame_identifiers.dart';
import 'package:phonic/id3/frames/headers/frame_header.dart';
import 'package:phonic/id3/helpers/size_calculator.dart';
import 'package:phonic/id3/tags/headers/id3v2_header.dart';

abstract class Id3v2FrameHeader extends FrameHeader {
  /// Decodes the FrameHeader
  ///
  /// Returns null if the FrameHeader could not be decoded
  static Id3v2FrameHeader? decode(Id3v2Header header, List<int> bytes, int startIndex) {
    switch (header.majorVersion) {
      case 4:
        return Id3v24FrameHeader.decode(header, bytes, startIndex);
      case 3:
        return Id3v23FrameHeader.decode(header, bytes, startIndex);
      case 2:
        return Id3v22FrameHeader.decode(header, bytes, startIndex);
    }

    return null;
  }

  factory Id3v2FrameHeader.create(Id3v2Header header, FrameIdentifier identifier) {
    switch (header.majorVersion) {
      case 4:
        return Id3v24FrameHeader.create(identifier);
      case 3:
        return Id3v23FrameHeader.create(identifier);
      case 2:
        return Id3v22FrameHeader.create(identifier);
      default:
        throw UnsupportedVersionException(header.version);
    }
  }

  Id3v2FrameHeader(FrameIdentifier identifier) : super(identifier);

  /// Encodes the header
  List<int> encode();

  List<int> encodeFrameSize(int frameSize);

  @override
  String toString() {
    return '${identifier.frameName.name} | ${identifier.v24Name ?? identifier.v23Name ?? identifier.v22Name}';
  }
}

class Id3v24FrameHeader extends Id3v23FrameHeader {
  static const int identifierFieldSize = 4;
  static const int sizeFieldSize = 4;
  static const int flagsFieldSize = 2;

  Id3v24FrameHeader(FrameIdentifier id, int size, List<int> flags) : super(id, size, flags);

  static Id3v24FrameHeader? decode(
    Id3v2Header id3v2Header,
    List<int> bytes,
    int startIndex,
  ) {
    String identifierId = latin1.decode(bytes.sublist(startIndex, startIndex + 4));
    FrameIdentifier? frameIdentifier = frameIdentifiers.firstWhereOrNull((element) => element.v24Name == identifierId);

    if (frameIdentifier == null) {
      return null;
    }

    var contentSize = _decodeFrameSize(bytes, startIndex + identifierFieldSize);
    var flags = _loadFlags(bytes, startIndex + identifierFieldSize + sizeFieldSize, flagsFieldSize);

    return Id3v24FrameHeader(frameIdentifier, contentSize, flags);
  }

  factory Id3v24FrameHeader.create(FrameIdentifier identifier) {
    return Id3v24FrameHeader(identifier, 0, <int>[0, 0]);
  }

  @override
  List<int> encode() {
    var encoded = <int>[
      ...utf8.encode(identifier.v24Name!),
      ...encodeFrameSize(contentSize),
      ...flags,
    ];
    return encoded;
  }

  @override
  List<int> encodeFrameSize(int frameSize) {
    return SizeCalculator.frameSizeInSynchSafeBytes(frameSize);
  }

  static int _decodeFrameSize(List<int> bytes, int startIndex) {
    return SizeCalculator.sizeOfSyncSafe(bytes.sublist(startIndex, startIndex + 4));
  }

  static List<int> _loadFlags(List<int> bytes, int startIndex, int flagsFieldSize) {
    return bytes.sublist(startIndex, startIndex + flagsFieldSize);
  }
}

class Id3v23FrameHeader extends Id3v2FrameHeader {
  static const int identifierFieldSize = 4;
  static const int sizeFieldSize = 4;
  static const int flagsFieldSize = 2;

  late List<int> _flags;

  @override
  int get headerSize => 10;

  List<int> get flags => _flags;

  static Id3v23FrameHeader? decode(
    Id3v2Header id3v2Header,
    List<int> bytes,
    int startIndex,
  ) {
    String identifierId = latin1.decode(bytes.sublist(startIndex, startIndex + 4));
    FrameIdentifier? frameIdentifier = frameIdentifiers.firstWhereOrNull((element) => element.v23Name == identifierId);

    if (frameIdentifier == null) {
      return null;
    }

    var contentSize = _decodeFrameSize(bytes, startIndex + identifierFieldSize);
    var flags = _loadFlags(bytes, startIndex + identifierFieldSize + sizeFieldSize, flagsFieldSize);

    return Id3v23FrameHeader(frameIdentifier, contentSize, flags);
  }

  factory Id3v23FrameHeader.create(FrameIdentifier identifier) {
    return Id3v23FrameHeader(identifier, 0, <int>[0, 0]);
  }

  Id3v23FrameHeader(FrameIdentifier id, int size, List<int> flags) : super(id) {
    contentSize = size;
    _flags = flags;
  }

  @override
  List<int> encode() {
    return <int>[
      ...utf8.encode(identifier.v23Name!),
      ...encodeFrameSize(contentSize),
      ...flags,
    ];
  }

  @override
  List<int> encodeFrameSize(int frameSize) {
    return SizeCalculator.frameSizeInBytes(frameSize);
  }

  static int _decodeFrameSize(List<int> bytes, int startIndex) {
    return SizeCalculator.sizeOf(bytes.sublist(startIndex, startIndex + 4));
  }

  static List<int> _loadFlags(List<int> bytes, int startIndex, int flagsFieldSize) {
    return bytes.sublist(startIndex, startIndex + flagsFieldSize);
  }
}

class Id3v22FrameHeader extends Id3v2FrameHeader {
  static const int identifierFieldSize = 3;
  static const int sizeFieldSize = 3;

  @override
  int get headerSize => 6;

  static Id3v22FrameHeader? decode(
    Id3v2Header id3v2Header,
    List<int> bytes,
    int startIndex,
  ) {
    String identifierId = latin1.decode(bytes.sublist(startIndex, startIndex + 3));
    FrameIdentifier? frameIdentifier = frameIdentifiers.firstWhereOrNull((element) => element.v22Name == identifierId);

    if (frameIdentifier == null) {
      return null;
    }

    var contentSize = _decodeFrameSize(bytes, startIndex + identifierFieldSize);

    return Id3v22FrameHeader(frameIdentifier, contentSize);
  }

  factory Id3v22FrameHeader.create(FrameIdentifier identifier) {
    return Id3v22FrameHeader(identifier, 0);
  }

  Id3v22FrameHeader(FrameIdentifier id, int size) : super(id) {
    contentSize = size;
  }

  @override
  List<int> encode() {
    return <int>[
      ...utf8.encode(identifier.v22Name!),
      ...encodeFrameSize(contentSize),
    ];
  }

  static int _decodeFrameSize(List<int> bytes, int startIndex) {
    return SizeCalculator.sizeOf3(bytes.sublist(startIndex, startIndex + 3));
  }

  @override
  List<int> encodeFrameSize(int frameSize) {
    return SizeCalculator.frameSizeIn3Bytes(frameSize);
  }
}
