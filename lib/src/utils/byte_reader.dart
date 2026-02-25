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
  /// Reads one byte from the current position and returns it as an unsigned
  /// integer value (0-255). The position is advanced by 1 byte after reading.
  ///
  /// This method is commonly used for:
  /// - Reading single byte values and flags
  /// - Processing byte-oriented data structures
  /// - Reading length prefixes in variable-length encodings
  /// - Parsing binary protocol headers
  ///
  /// @returns An unsigned 8-bit integer (0-255)
  /// @throws RangeError if there are insufficient bytes remaining
  ///
  /// Example:
  /// ```dart
  /// final reader = ByteReader(Uint8List.fromList([0x48, 0x65, 0x6C]));
  /// final firstByte = reader.readUint8(); // 0x48 (72)
  /// final secondByte = reader.readUint8(); // 0x65 (101)
  /// print('Position: ${reader.position}'); // 2
  /// ```
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
  /// Reads the specified number of bytes from the current position and
  /// decodes them as a string using the provided encoding. The position
  /// is advanced by [length] bytes after reading.
  ///
  /// ## Encoding Support
  ///
  /// Common encodings used in audio metadata:
  /// - **UTF-8**: Universal encoding, used by Vorbis Comments and MP4
  /// - **UTF-16**: Used by ID3v2 for international text
  /// - **ISO-8859-1** (Latin-1): Used by ID3v2 for basic ASCII text
  /// - **ASCII**: Basic 7-bit encoding for simple text
  ///
  /// ## Error Handling
  ///
  /// The method handles encoding errors gracefully:
  /// - Invalid byte sequences throw [FormatException]
  /// - Insufficient bytes throw [RangeError]
  /// - The error message includes the encoding name for debugging
  ///
  /// @param length The number of bytes to read and decode
  /// @param encoding The text encoding to use (defaults to UTF-8)
  /// @returns The decoded string
  /// @throws RangeError if there are insufficient bytes remaining
  /// @throws FormatException if the bytes cannot be decoded with the specified encoding
  ///
  /// Example:
  /// ```dart
  /// // Read UTF-8 string (default encoding)
  /// final reader = ByteReader(Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]));
  /// final text = reader.readString(5); // "Hello"
  ///
  /// // Read with specific encoding
  /// final latin1Reader = ByteReader(Uint8List.fromList([0xC9, 0x6C, 0x69, 0x74, 0x65]));
  /// final latin1Text = reader.readString(5, latin1); // "Élite"
  ///
  /// // Handle encoding errors
  /// try {
  ///   final invalidUtf8 = ByteReader(Uint8List.fromList([0xFF, 0xFE]));
  ///   final text = invalidUtf8.readString(2, utf8);
  /// } on FormatException catch (e) {
  ///   print('Encoding error: $e');
  /// }
  /// ```
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
  /// Reads bytes from the current position until a null terminator (0x00)
  /// is found, then decodes the bytes as a string using the specified encoding.
  /// The position is advanced past the null terminator after reading.
  ///
  /// ## Null Terminator Handling
  ///
  /// - Searches for the first 0x00 byte from the current position
  /// - Reads all bytes up to (but not including) the null terminator
  /// - Automatically skips over the null terminator byte
  /// - If [maxLength] is specified, limits the search range
  ///
  /// ## Length Limiting
  ///
  /// When [maxLength] is provided:
  /// - Search stops at null terminator OR max length, whichever comes first
  /// - If no null terminator is found within max length, reads exactly [maxLength] bytes
  /// - Useful for parsing fixed-size string fields that may or may not be null-terminated
  ///
  /// ## Common Use Cases
  ///
  /// - Reading C-style strings from binary data
  /// - Parsing null-terminated fields in audio metadata
  /// - Processing variable-length string data
  /// - Reading strings from legacy file formats
  ///
  /// @param encoding The text encoding to use (defaults to UTF-8)
  /// @param maxLength Optional maximum number of bytes to search for null terminator
  /// @returns The decoded string (without the null terminator)
  /// @throws RangeError if no null terminator is found within the remaining bytes (when maxLength is not specified)
  /// @throws FormatException if the bytes cannot be decoded with the specified encoding
  ///
  /// Example:
  /// ```dart
  /// // Read null-terminated UTF-8 string
  /// final data = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x57, 0x6F, 0x72, 0x6C, 0x64]);
  /// final reader = ByteReader(data);
  /// final text = reader.readNullTerminatedString(); // "Hello"
  /// print('Position after read: ${reader.position}'); // 6 (past the null terminator)
  ///
  /// // Read with maximum length limit
  /// final limitedReader = ByteReader(Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]));
  /// final limitedText = limitedReader.readNullTerminatedString(utf8, 5); // "Hello" (no null found, reads 5 bytes)
  ///
  /// // Read with specific encoding
  /// final latin1Data = Uint8List.fromList([0xC9, 0x6C, 0x69, 0x74, 0x65, 0x00]);
  /// final latin1Reader = ByteReader(latin1Data);
  /// final latin1Text = latin1Reader.readNullTerminatedString(latin1); // "Élite"
  ///
  /// // Handle missing null terminator
  /// try {
  ///   final noNullReader = ByteReader(Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]));
  ///   final text = noNullReader.readNullTerminatedString(); // Throws RangeError
  /// } on RangeError catch (e) {
  ///   print('No null terminator found: $e');
  /// }
  /// ```
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
        'but only $remaining remaining at position $_position',
      );
    }
  }

  @override
  String toString() {
    return 'ByteReader(position: $_position, length: ${_bytes.length}, '
        'remaining: $remaining)';
  }
}
