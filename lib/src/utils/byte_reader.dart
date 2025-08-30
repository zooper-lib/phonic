import 'dart:convert';
import 'dart:typed_data';

/// A utility class for efficient binary data parsing with bounds checking
/// and endianness handling.
///
/// The [ByteReader] provides methods for reading various data types from
/// binary data with automatic bounds checking and support for both big-endian
/// and little-endian byte order.
///
/// ## Example Usage
///
/// ```dart
/// final bytes = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);
/// final reader = ByteReader(bytes);
///
/// final firstByte = reader.readUint8(); // 0x48
/// final string = reader.readString(4, Encoding.ascii); // "ello"
/// ```
class ByteReader {
  final Uint8List _bytes;
  int _position = 0;

  /// Creates a new [ByteReader] from the given [bytes].
  ByteReader(this._bytes);

  /// The current position in the byte array.
  int get position => _position;

  /// The total length of the byte array.
  int get length => _bytes.length;

  /// The number of bytes remaining from the current position.
  int get remaining => _bytes.length - _position;

  /// Whether there are any bytes remaining to read.
  bool get hasRemaining => _position < _bytes.length;

  /// Sets the current position to the specified [position].
  ///
  /// Throws [RangeError] if [position] is negative or exceeds the buffer length.
  void seek(int position) {
    if (position < 0 || position > _bytes.length) {
      throw RangeError.range(position, 0, _bytes.length, 'position');
    }
    _position = position;
  }

  /// Skips the specified number of [bytes].
  ///
  /// Throws [RangeError] if skipping would exceed the buffer bounds.
  void skip(int bytes) {
    if (bytes < 0) {
      throw ArgumentError.value(bytes, 'bytes', 'Cannot skip negative bytes');
    }
    if (_position + bytes > _bytes.length) {
      throw RangeError(
        'Cannot skip $bytes bytes from position $_position: '
        'would exceed buffer length ${_bytes.length}',
      );
    }
    _position += bytes;
  }

  /// Reads a single unsigned 8-bit integer.
  ///
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readUint8() {
    _checkBounds(1);
    return _bytes[_position++];
  }

  /// Reads a single signed 8-bit integer.
  ///
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readInt8() {
    final value = readUint8();
    return value > 127 ? value - 256 : value;
  }

  /// Reads an unsigned 16-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readUint16([Endian endian = Endian.big]) {
    _checkBounds(2);
    final value = _bytes.buffer.asByteData().getUint16(_position, endian);
    _position += 2;
    return value;
  }

  /// Reads a signed 16-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readInt16([Endian endian = Endian.big]) {
    _checkBounds(2);
    final value = _bytes.buffer.asByteData().getInt16(_position, endian);
    _position += 2;
    return value;
  }

  /// Reads an unsigned 32-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readUint32([Endian endian = Endian.big]) {
    _checkBounds(4);
    final value = _bytes.buffer.asByteData().getUint32(_position, endian);
    _position += 4;
    return value;
  }

  /// Reads a signed 32-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readInt32([Endian endian = Endian.big]) {
    _checkBounds(4);
    final value = _bytes.buffer.asByteData().getInt32(_position, endian);
    _position += 4;
    return value;
  }

  /// Reads an unsigned 64-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readUint64([Endian endian = Endian.big]) {
    _checkBounds(8);
    final value = _bytes.buffer.asByteData().getUint64(_position, endian);
    _position += 8;
    return value;
  }

  /// Reads a signed 64-bit integer.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  int readInt64([Endian endian = Endian.big]) {
    _checkBounds(8);
    final value = _bytes.buffer.asByteData().getInt64(_position, endian);
    _position += 8;
    return value;
  }

  /// Reads a 32-bit floating point number.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  double readFloat32([Endian endian = Endian.big]) {
    _checkBounds(4);
    final value = _bytes.buffer.asByteData().getFloat32(_position, endian);
    _position += 4;
    return value;
  }

  /// Reads a 64-bit floating point number.
  ///
  /// [endian] specifies the byte order (defaults to big-endian).
  /// Throws [RangeError] if there are insufficient bytes remaining.
  double readFloat64([Endian endian = Endian.big]) {
    _checkBounds(8);
    final value = _bytes.buffer.asByteData().getFloat64(_position, endian);
    _position += 8;
    return value;
  }

  /// Reads a byte array of the specified [length].
  ///
  /// Throws [RangeError] if there are insufficient bytes remaining.
  Uint8List readBytes(int length) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Length cannot be negative');
    }
    _checkBounds(length);
    final result = _bytes.sublist(_position, _position + length);
    _position += length;
    return result;
  }

  /// Reads all remaining bytes from the current position.
  Uint8List readRemainingBytes() {
    final result = _bytes.sublist(_position);
    _position = _bytes.length;
    return result;
  }

  /// Reads a string of the specified [length] using the given [encoding].
  ///
  /// If [encoding] is not provided, UTF-8 is used by default.
  /// Throws [RangeError] if there are insufficient bytes remaining.
  /// Throws [FormatException] if the bytes cannot be decoded with the specified encoding.
  String readString(int length, [Encoding? encoding]) {
    encoding ??= utf8;
    final bytes = readBytes(length);
    try {
      return encoding.decode(bytes);
    } catch (e) {
      throw FormatException('Failed to decode string with ${encoding.name} encoding: $e');
    }
  }

  /// Reads a null-terminated string using the given [encoding].
  ///
  /// If [encoding] is not provided, UTF-8 is used by default.
  /// If [maxLength] is specified, reading stops at the null terminator or max length.
  /// Throws [RangeError] if no null terminator is found within the remaining bytes.
  /// Throws [FormatException] if the bytes cannot be decoded with the specified encoding.
  String readNullTerminatedString([Encoding? encoding, int? maxLength]) {
    encoding ??= utf8;
    final searchLimit = maxLength != null ? (_position + maxLength).clamp(0, _bytes.length) : _bytes.length;

    // Find null terminator
    int nullPosition = -1;
    for (int i = _position; i < searchLimit; i++) {
      if (_bytes[i] == 0) {
        nullPosition = i;
        break;
      }
    }

    if (nullPosition == -1) {
      if (maxLength != null) {
        // Read up to maxLength without null terminator
        final bytes = readBytes(maxLength);
        try {
          return encoding.decode(bytes);
        } catch (e) {
          throw FormatException('Failed to decode string with ${encoding.name} encoding: $e');
        }
      } else {
        throw RangeError('No null terminator found in remaining bytes');
      }
    }

    // Read string bytes (excluding null terminator)
    final stringLength = nullPosition - _position;
    final bytes = readBytes(stringLength);

    // Skip the null terminator
    skip(1);

    try {
      return encoding.decode(bytes);
    } catch (e) {
      throw FormatException('Failed to decode string with ${encoding.name} encoding: $e');
    }
  }

  /// Reads a Pascal string (length-prefixed string) where the first byte
  /// indicates the length of the string.
  ///
  /// If [encoding] is not provided, UTF-8 is used by default.
  /// Throws [RangeError] if there are insufficient bytes remaining.
  /// Throws [FormatException] if the bytes cannot be decoded with the specified encoding.
  String readPascalString([Encoding? encoding]) {
    final length = readUint8();
    return readString(length, encoding);
  }

  /// Peeks at the next [length] bytes without advancing the position.
  ///
  /// Throws [RangeError] if there are insufficient bytes remaining.
  Uint8List peekBytes(int length) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Length cannot be negative');
    }
    _checkBounds(length);
    return _bytes.sublist(_position, _position + length);
  }

  /// Peeks at the next byte without advancing the position.
  ///
  /// Throws [RangeError] if there are no bytes remaining.
  int peekUint8() {
    _checkBounds(1);
    return _bytes[_position];
  }

  /// Checks if the next [length] bytes match the given [pattern].
  ///
  /// Does not advance the position.
  /// Returns false if there are insufficient bytes remaining.
  bool matchesPattern(List<int> pattern) {
    if (_position + pattern.length > _bytes.length) {
      return false;
    }

    for (int i = 0; i < pattern.length; i++) {
      if (_bytes[_position + i] != pattern[i]) {
        return false;
      }
    }
    return true;
  }

  /// Finds the next occurrence of the given [pattern] starting from the current position.
  ///
  /// Returns the position of the pattern, or -1 if not found.
  /// Does not advance the position.
  int findPattern(List<int> pattern, [int? maxSearchLength]) {
    if (pattern.isEmpty) {
      return _position;
    }

    final searchLimit = maxSearchLength != null ? (_position + maxSearchLength).clamp(0, _bytes.length) : _bytes.length;

    for (int i = _position; i <= searchLimit - pattern.length; i++) {
      bool matches = true;
      for (int j = 0; j < pattern.length; j++) {
        if (_bytes[i + j] != pattern[j]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return i;
      }
    }
    return -1;
  }

  /// Checks if there are at least [requiredBytes] remaining.
  ///
  /// Throws [RangeError] if there are insufficient bytes.
  void _checkBounds(int requiredBytes) {
    if (_position + requiredBytes > _bytes.length) {
      throw RangeError(
        'Insufficient bytes: need $requiredBytes, '
        'but only ${remaining} remaining at position $_position',
      );
    }
  }

  @override
  String toString() {
    return 'ByteReader(position: $_position, length: ${_bytes.length}, '
        'remaining: $remaining)';
  }
}
