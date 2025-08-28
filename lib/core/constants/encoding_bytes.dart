class EncodingBytes {
  // [ISO-8859-1]. Terminated with $00.
  static const latin1 = 0x00;

  // [UTF-16] encoded Unicode [UNICODE] with BOM. All strings in the same frame SHALL have the same byteorder. Terminated with $00 00.
  static const utf16 = 0x01;

  // [UTF-16] encoded Unicode [UNICODE] without BOM. Terminated with $00 00.
  static const utf16be = 0x02;

  // [UTF-8] encoded Unicode [UNICODE]. Terminated with $00.
  static const utf8 = 0x03;
}
