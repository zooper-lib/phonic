import 'dart:convert';

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:phonic/id3/exceptions/tag_not_found_exception.dart';
import 'package:phonic/id3/exceptions/unsupported_version_exception.dart';
import 'package:phonic/id3/helpers/size_calculator.dart';

import 'id3_header.dart';

class Id3v2Header extends Id3Header with EquatableMixin {
  static const String identifierText = 'ID3';

  late int _revisionVersion;
  late int _flags;

  @override
  int get headerSize => 10;

  @override
  String get identifier => identifierText;

  @override
  String get version => '2.$majorVersion.$revisionVersion';

  int get revisionVersion => _revisionVersion;

  int get flags => _flags;

  bool get useUnsynchronization => flags & 0x80 != 0;
  bool get hasExtendedHeader => flags & 0x40 != 0;
  bool get isExperimental => flags & 0x20 != 0;

  /// The size of all frames inclusive padding
  late int frameSize;

  static Id3v2Header? decode(List<int> bytes, int start) {
    var identifierBytes = bytes.sublist(start, start + identifierText.length);
    var parsedIdentifier = latin1.decode(identifierBytes);

    if (parsedIdentifier != identifierText) {
      return null;
    }

    return Id3v2Header._decode(bytes, start);
  }

  Id3v2Header._decode(List<int> bytes, int startIndex) {
    majorVersion = _decodeMajorVersion(bytes, startIndex);
    _revisionVersion = _decodeRevisionVersion(bytes, startIndex);
    _flags = _decodeFlags(bytes, startIndex);
    frameSize = _decodeSize(bytes, startIndex);
  }

  String readIdentifier(Uint8List bytes) {
    var identifierBytes = _sublist(bytes, 0, identifier.length);
    var readIdentifier = latin1.decode(identifierBytes);

    if (readIdentifier.toLowerCase() != identifier.toLowerCase()) {
      throw TagNotFoundException(identifier);
    }

    return identifier;
  }

  int _decodeMajorVersion(List<int> bytes, int start) {
    return bytes[start + 3];
  }

  int _decodeRevisionVersion(List<int> bytes, int start) {
    return bytes[start + 4];
  }

  int _decodeFlags(List<int> bytes, int start) {
    return bytes[start + 5];
  }

  int _decodeSize(List<int> bytes, int start) {
    return SizeCalculator.sizeOfSyncSafe(bytes.sublist(start + 6, start + 10));
  }

  List<int> _sublist(List<int> bytes, int start, int length) {
    return bytes.sublist(start, start + length);
  }

  @override
  String toString() => version;

  @override
  List<int> encode() {
    return <int>[
      ...latin1.encode(identifier),
      _encodeMajorVersion(majorVersion),
      ..._encodeRevisionVersion(revisionVersion),
      ..._encodeFlags(flags),
      ..._encodeSize(frameSize),
    ];
  }

  int _encodeMajorVersion(int majorVersion) {
    switch (majorVersion) {
      case 4:
        return 0x04;
      case 3:
        return 0x03;
      case 2:
        return 0x02;
      default:
        throw UnsupportedVersionException(version);
    }
  }

  List<int> _encodeRevisionVersion(int revisionVersion) {
    var list = Uint8List(4)..buffer.asInt32List()[0] = revisionVersion;

    return <int>[
      list.last,
    ];
  }

  List<int> _encodeFlags(int flags) {
    var list = Uint8List(4)..buffer.asInt32List()[0] = flags;

    return <int>[
      list.last,
    ];
  }

  List<int> _encodeSize(int size) {
    return SizeCalculator.frameSizeInSynchSafeBytes(size);
  }

  @override
  List<Object?> get props => [majorVersion, revisionVersion, flags];
}
