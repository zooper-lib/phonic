import 'dart:typed_data';

class SizeCalculator {
  // Regular 32bit int
  static int sizeOf(List<int> block) {
    assert(block.length == 4);

    var len = block[0] << 24;
    len += block[1] << 16;
    len += block[2] << 8;
    len += block[3];

    return len;
  }

  static int sizeOf3(List<int> block) {
    assert(block.length == 3);

    var len = block[0] << 16;
    len += block[1] << 8;
    len += block[2];

    return len;
  }

  // Sync safe 32bit int
  static int sizeOfSyncSafe(List<int> block) {
    assert(block.length == 4);

    var len = block[0] << 21;
    len += block[1] << 14;
    len += block[2] << 7;
    len += block[3];

    return len;
  }

  static List<int> frameSizeIn3Bytes(int value) {
    assert(value <= 16777216);

    final block = List<int>.filled(3, 0);

    block[0] = (value >> 16);
    block[1] = (value >> 8);
    block[2] = (value >> 0);

    return block;
  }

  static List<int> frameSizeInBytes(int value) {
    var byte = Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);

    return byte.reversed.toList();
    //return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
    //return Uint8List(4)..buffer.asInt32List()[0] = value;
  }

  static List<int> frameSizeInSynchSafeBytes(int value) {
    assert(value <= 16777216);

    final block = List<int>.filled(4, 0);
    const sevenBitMask = 0x7f;

    block[0] = (value >> 21) & sevenBitMask;
    block[1] = (value >> 14) & sevenBitMask;
    block[2] = (value >> 7) & sevenBitMask;
    block[3] = (value >> 0) & sevenBitMask;

    return block;
  }
}
