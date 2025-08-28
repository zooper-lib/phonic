import 'dart:convert';

import 'package:phonic/id3/exceptions/id3_exception.dart';
import 'package:zooper_flutter_encoding_utf16/zooper_flutter_encoding_utf16.dart';

class Terminations {
  static const latin1Termination = [0x00];
  static const utf16Termination = [0x00, 0x00];
  static const utf8Termiantion = [0x00];

  static List<int> getByEncoding(Encoding encoding) {
    switch (encoding.runtimeType) {
      case Latin1Codec:
        return latin1Termination;
      case UTF16LE:
      case UTF16BE:
        return utf16Termination;
      case Utf8Codec:
        return utf8Termiantion;
      default:
        throw UnimplementedError('Codec ${encoding.runtimeType} is not implemented yet');
    }
  }

  static bool hasTermination(List<int> bytes, List<int> termiantor) {
    if (termiantor.length == 1) {
      return bytes[bytes.length - 1] == termiantor[0];
    } else if (termiantor.length == 2) {
      return bytes[bytes.length - 2] == termiantor[0] && bytes[bytes.length - 1] == termiantor[1];
    }

    throw Id3Exception('Invlaid termination of Encoding');
  }
}
