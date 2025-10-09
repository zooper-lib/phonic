import 'dart:typed_data';

/// Helper functions to build MP4 atoms with proper nested 'data' atom structure
/// for use in tests.
///
/// iTunes MP4 metadata atoms have this structure:
/// [atom size: 4][atom type: 4][©nam, ©ART, etc.]
///   [data size: 4]['data': 4]
///     [version/flags: 8]
///     [actual payload]

/// Builds a text atom (©nam, ©ART, etc.) with proper nested 'data' atom structure
Uint8List buildTextAtom(String atomType, String text) {
  final textBytes = Uint8List.fromList(text.codeUnits);

  // Nested 'data' atom structure:
  // [data size: 4][data type: 4]['data'][version/flags: 8][text]
  final dataAtomContentSize = 8 + textBytes.length; // version/flags + text
  final dataAtomSize = 8 + dataAtomContentSize; // data atom header + content
  final atomSize = 8 + dataAtomSize; // outer atom header + data atom

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Outer atom header (©nam, ©ART, etc.)
  view.setUint32(0, atomSize, Endian.big); // total size
  result.setRange(4, 8, atomType.codeUnits); // atom type

  // Nested 'data' atom header
  view.setUint32(8, dataAtomSize, Endian.big); // data atom size
  result.setRange(12, 16, 'data'.codeUnits); // 'data' type

  // Data atom version/flags (8 bytes)
  view.setUint32(16, 0x00000001, Endian.big); // version + type indicator (UTF-8)
  view.setUint32(20, 0x00000000, Endian.big); // flags

  // Text data
  result.setRange(24, 24 + textBytes.length, textBytes);

  return result;
}

/// Builds a track number atom (trkn) with proper nested 'data' atom structure
Uint8List buildTrackNumberAtom(int trackNumber) {
  // Nested 'data' atom structure:
  // [data size: 4][data type: 4]['data'][version/flags: 8][track data: 8]
  const dataAtomContentSize = 8 + 8; // version/flags + track data (8 bytes)
  const dataAtomSize = 8 + dataAtomContentSize; // data atom header + content
  const atomSize = 8 + dataAtomSize; // trkn header + data atom

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Outer atom header (trkn)
  view.setUint32(0, atomSize, Endian.big); // total size
  result.setRange(4, 8, 'trkn'.codeUnits); // atom type

  // Nested 'data' atom header
  view.setUint32(8, dataAtomSize, Endian.big); // data atom size
  result.setRange(12, 16, 'data'.codeUnits); // 'data' type

  // Data atom version/flags (8 bytes)
  view.setUint32(16, 0x00000000, Endian.big); // version + type indicator (binary)
  view.setUint32(20, 0x00000000, Endian.big); // flags

  // Track data: [padding: 2][track: 2][total: 2][padding: 2]
  view.setUint16(24, 0, Endian.big); // padding
  view.setUint16(26, trackNumber, Endian.big); // track number
  view.setUint16(28, 0, Endian.big); // total tracks (unknown)
  view.setUint16(30, 0, Endian.big); // padding

  return result;
}

/// Builds a BPM atom (tmpo) with proper nested 'data' atom structure
Uint8List buildBpmAtom(int bpm) {
  // Nested 'data' atom structure:
  // [data size: 4][data type: 4]['data'][version/flags: 8][bpm: 2][padding: 2]
  const dataAtomContentSize = 8 + 4; // version/flags + bpm value (2 bytes) + padding (2 bytes)
  const dataAtomSize = 8 + dataAtomContentSize; // data atom header + content
  const atomSize = 8 + dataAtomSize; // tmpo header + data atom

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Outer atom header (tmpo)
  view.setUint32(0, atomSize, Endian.big); // total size
  result.setRange(4, 8, 'tmpo'.codeUnits); // atom type

  // Nested 'data' atom header
  view.setUint32(8, dataAtomSize, Endian.big); // data atom size
  result.setRange(12, 16, 'data'.codeUnits); // 'data' type

  // Data atom version/flags (8 bytes)
  view.setUint32(16, 0x00000015, Endian.big); // version + type indicator (16-bit int)
  view.setUint32(20, 0x00000000, Endian.big); // flags

  // BPM value (16-bit) with padding
  view.setUint16(24, bpm, Endian.big);
  view.setUint16(26, 0, Endian.big); // padding

  return result;
}

/// Builds an artwork atom (covr) with proper nested 'data' atom structure
Uint8List buildArtworkAtom(Uint8List imageData, {bool isPng = false}) {
  // Nested 'data' atom structure:
  // [data size: 4][data type: 4]['data'][version/flags: 8][image data]
  final dataAtomContentSize = 8 + imageData.length; // version/flags + image
  final dataAtomSize = 8 + dataAtomContentSize; // data atom header + content
  final atomSize = 8 + dataAtomSize; // covr header + data atom

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Outer atom header (covr)
  view.setUint32(0, atomSize, Endian.big); // total size
  result.setRange(4, 8, 'covr'.codeUnits); // atom type

  // Nested 'data' atom header
  view.setUint32(8, dataAtomSize, Endian.big); // data atom size
  result.setRange(12, 16, 'data'.codeUnits); // 'data' type

  // Data atom version/flags (8 bytes)
  // Type indicator: 0x0D for JPEG, 0x0E for PNG
  final dataType = isPng ? 0x0000000E : 0x0000000D;
  view.setUint32(16, dataType, Endian.big); // version + type indicator
  view.setUint32(20, 0x00000000, Endian.big); // flags

  // Image data
  result.setRange(24, 24 + imageData.length, imageData);

  return result;
}

/// Builds a disc number atom (disk) with proper nested 'data' atom structure
Uint8List buildDiscNumberAtom(int discNumber) {
  // Nested 'data' atom structure:
  // [data size: 4][data type: 4]['data'][version/flags: 8][disc data: 8]
  const dataAtomContentSize = 8 + 8; // version/flags + disc data (8 bytes)
  const dataAtomSize = 8 + dataAtomContentSize; // data atom header + content
  const atomSize = 8 + dataAtomSize; // disk header + data atom

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Outer atom header (disk)
  view.setUint32(0, atomSize, Endian.big); // total size
  result.setRange(4, 8, 'disk'.codeUnits); // atom type

  // Nested 'data' atom header
  view.setUint32(8, dataAtomSize, Endian.big); // data atom size
  result.setRange(12, 16, 'data'.codeUnits); // 'data' type

  // Data atom version/flags (8 bytes)
  view.setUint32(16, 0x00000000, Endian.big); // version + type indicator (binary)
  view.setUint32(20, 0x00000000, Endian.big); // flags

  // Disc data: [padding: 2][disc: 2][total: 2][padding: 2]
  view.setUint16(24, 0, Endian.big); // padding
  view.setUint16(26, discNumber, Endian.big); // disc number
  view.setUint16(28, 0, Endian.big); // total discs (unknown)
  view.setUint16(30, 0, Endian.big); // padding

  return result;
}
