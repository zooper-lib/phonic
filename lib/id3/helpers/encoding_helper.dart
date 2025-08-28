import 'dart:convert';

import 'package:zooper_flutter_encoding_utf16/utf16.dart';

import '../../core/constants/encoding_bytes.dart';
import '../../core/constants/converters/hex_converter.dart';

/// Gets the [Encoding] by it's [typeId]
Encoding getEncoding(int typeId) {
  switch (typeId) {
    case EncodingBytes.latin1:
      return latin1;
    case EncodingBytes.utf8:
      return const Utf8Codec(allowMalformed: true);
    case EncodingBytes.utf16:
      return UTF16LE();
    case EncodingBytes.utf16be:
      return UTF16BE();
    default:
      return HEXConverter();
  }
}

/// Gets the type id of the [Encoding] by the [type]
int getIdFromEncoding(Encoding type) {
  switch (type.runtimeType) {
    case Latin1Codec:
      return EncodingBytes.latin1;
    case UTF16LE:
      return EncodingBytes.utf16;
    case UTF16BE:
      return EncodingBytes.utf16be;
    case Utf8Codec:
      return EncodingBytes.utf8;
    default:
      throw UnimplementedError('Encoding type $type is not implemented yet');
  }
}
