import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'id3_header.dart';

class Id3v1Header extends Id3Header with EquatableMixin {
  @override
  String get identifier => 'TAG';

  @override
  String get version => '1.$majorVersion';

  @override
  int get headerSize => 3;

  static Id3v1Header? decode(List<int> bytes, int startIndex) {
    Id3v1Header header = Id3v1Header();

    var identifierBytes = bytes.sublist(startIndex, startIndex + header.identifier.length);
    var parsedIdentifier = latin1.decode(identifierBytes);

    if (parsedIdentifier != header.identifier) {
      return null;
    }

    header.majorVersion = 1;

    return header;
  }

  @override
  String toString() => version;

  @override
  List<int> encode() {
    return <int>[
      ...latin1.encode(identifier),
    ];
  }

  @override
  List<Object?> get props => [majorVersion];
}
