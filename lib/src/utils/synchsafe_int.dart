import 'dart:typed_data';

/// Utilities for encoding and decoding synchsafe integers as used in ID3v2 tags.
///
/// Synchsafe integers are a special encoding used in ID3v2 to avoid false
/// synchronization with MP3 frame headers. The most significant bit of each
/// byte is always 0, effectively using only 7 bits per byte for data.
///
/// This encoding prevents the occurrence of the MP3 frame sync pattern
/// (0xFF 0xE0 or higher) within ID3v2 tag data, which could otherwise
/// confuse MP3 parsers.
///
/// ## Format Details
///
/// - Each byte uses only the lower 7 bits (bit 7 is always 0)
/// - Maximum value for 4 bytes: 0x0FFFFFFF (268,435,455)
/// - Byte order is big-endian
/// - Used for tag sizes, frame sizes, and other length fields in ID3v2
///
/// ## Examples
///
/// ```dart
/// // Encoding a regular integer to synchsafe format
/// final synchsafe = SynchsafeInt.encode(0x12345);
/// print(synchsafe); // [0x00, 0x04, 0x68, 0x45]
///
/// // Decoding synchsafe bytes back to integer
/// final decoded = SynchsafeInt.decode([0x00, 0x04, 0x68, 0x45]);
/// print(decoded); // 0x12345
///
/// // Working with Uint8List
/// final bytes = Uint8List.fromList([0x00, 0x04, 0x68, 0x45]);
/// final value = SynchsafeInt.decodeBytes(bytes);
/// print(value); // 0x12345
/// ```
class SynchsafeInt {
  /// The maximum value that can be represented in a 4-byte synchsafe integer.
  ///
  /// This is 0x0FFFFFFF (268,435,455) because each byte can only use 7 bits.
  static const int maxValue = 0x0FFFFFFF;

  /// Encodes a regular integer into synchsafe format.
  ///
  /// The [value] must be non-negative and not exceed [maxValue].
  /// Returns a list of 4 bytes in big-endian order with the most significant
  /// bit of each byte set to 0.
  ///
  /// ## Parameters
  /// - [value]: The integer to encode (0 to 268,435,455)
  ///
  /// ## Returns
  /// A list of 4 bytes representing the synchsafe integer
  ///
  /// ## Throws
  /// - [ArgumentError] if [value] is negative or exceeds [maxValue]
  ///
  /// ## Example
  /// ```dart
  /// final encoded = SynchsafeInt.encode(0x12345);
  /// // Returns [0x00, 0x04, 0x68, 0x45]
  /// ```
  static List<int> encode(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Value cannot be negative');
    }
    if (value > maxValue) {
      throw ArgumentError.value(
        value,
        'value',
        'Value exceeds maximum synchsafe integer value ($maxValue)',
      );
    }

    // Extract 7-bit chunks from the 28-bit value
    final byte0 = (value >> 21) & 0x7F; // Bits 21-27
    final byte1 = (value >> 14) & 0x7F; // Bits 14-20
    final byte2 = (value >> 7) & 0x7F; // Bits 7-13
    final byte3 = value & 0x7F; // Bits 0-6

    return [byte0, byte1, byte2, byte3];
  }

  /// Encodes a regular integer into synchsafe format as a Uint8List.
  ///
  /// This is a convenience method that returns the encoded bytes as a Uint8List
  /// instead of a `List<int>`.
  ///
  /// ## Parameters
  /// - [value]: The integer to encode (0 to 268,435,455)
  ///
  /// ## Returns
  /// A Uint8List of 4 bytes representing the synchsafe integer
  ///
  /// ## Throws
  /// - [ArgumentError] if [value] is negative or exceeds [maxValue]
  ///
  /// ## Example
  /// ```dart
  /// final encoded = SynchsafeInt.encodeBytes(0x12345);
  /// // Returns Uint8List.fromList([0x00, 0x04, 0x68, 0x45])
  /// ```
  static Uint8List encodeBytes(int value) {
    return Uint8List.fromList(encode(value));
  }

  /// Decodes a synchsafe integer from a list of bytes.
  ///
  /// The [bytes] must contain exactly 4 bytes in big-endian order.
  /// Each byte must have its most significant bit set to 0.
  ///
  /// ## Parameters
  /// - [bytes]: List of 4 synchsafe bytes to decode
  ///
  /// ## Returns
  /// The decoded integer value
  ///
  /// ## Throws
  /// - [ArgumentError] if [bytes] length is not 4
  /// - [FormatException] if any byte has its MSB set (invalid synchsafe format)
  ///
  /// ## Example
  /// ```dart
  /// final decoded = SynchsafeInt.decode([0x00, 0x04, 0x68, 0x45]);
  /// // Returns 0x12345
  /// ```
  static int decode(List<int> bytes) {
    if (bytes.length != 4) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Synchsafe integer must be exactly 4 bytes',
      );
    }

    // Validate that all bytes are valid synchsafe format (MSB = 0)
    for (int i = 0; i < 4; i++) {
      if (bytes[i] < 0 || bytes[i] > 255) {
        throw ArgumentError.value(
          bytes[i],
          'bytes[$i]',
          'Byte value must be in range 0-255',
        );
      }
      if (bytes[i] & 0x80 != 0) {
        throw FormatException(
          'Invalid synchsafe format: byte $i (0x${bytes[i].toRadixString(16).padLeft(2, '0')}) '
          'has MSB set. Synchsafe bytes must have MSB = 0.',
        );
      }
    }

    // Combine the 7-bit chunks into a 28-bit value
    return (bytes[0] << 21) | (bytes[1] << 14) | (bytes[2] << 7) | bytes[3];
  }

  /// Decodes a synchsafe integer from a Uint8List.
  ///
  /// This is a convenience method that accepts a Uint8List instead of `List<int>`.
  /// The bytes must contain exactly 4 bytes in big-endian order.
  ///
  /// ## Parameters
  /// - [bytes]: Uint8List of 4 synchsafe bytes to decode
  ///
  /// ## Returns
  /// The decoded integer value
  ///
  /// ## Throws
  /// - [ArgumentError] if [bytes] length is not 4
  /// - [FormatException] if any byte has its MSB set (invalid synchsafe format)
  ///
  /// ## Example
  /// ```dart
  /// final bytes = Uint8List.fromList([0x00, 0x04, 0x68, 0x45]);
  /// final decoded = SynchsafeInt.decodeBytes(bytes);
  /// // Returns 0x12345
  /// ```
  static int decodeBytes(Uint8List bytes) {
    return decode(bytes.toList());
  }

  /// Decodes a synchsafe integer from a subset of bytes.
  ///
  /// Reads 4 bytes starting from [offset] in the provided [bytes] array.
  ///
  /// ## Parameters
  /// - [bytes]: The byte array containing synchsafe data
  /// - [offset]: Starting position to read from (default: 0)
  ///
  /// ## Returns
  /// The decoded integer value
  ///
  /// ## Throws
  /// - [RangeError] if [offset] + 4 exceeds [bytes] length
  /// - [FormatException] if any byte has its MSB set (invalid synchsafe format)
  ///
  /// ## Example
  /// ```dart
  /// final data = Uint8List.fromList([0xFF, 0x00, 0x04, 0x68, 0x45, 0xFF]);
  /// final decoded = SynchsafeInt.decodeBytesAt(data, 1);
  /// // Returns 0x12345 (reads bytes 1-4)
  /// ```
  static int decodeBytesAt(Uint8List bytes, [int offset = 0]) {
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Offset cannot be negative');
    }
    if (offset + 4 > bytes.length) {
      throw RangeError(
        'Insufficient bytes: need 4 bytes starting at offset $offset, '
        'but array length is ${bytes.length}',
      );
    }

    return decode(bytes.sublist(offset, offset + 4).toList());
  }

  /// Checks if a list of bytes represents a valid synchsafe integer.
  ///
  /// Returns true if the bytes are exactly 4 in length and each byte
  /// has its most significant bit set to 0.
  ///
  /// ## Parameters
  /// - [bytes]: The bytes to validate
  ///
  /// ## Returns
  /// True if the bytes represent a valid synchsafe integer
  ///
  /// ## Example
  /// ```dart
  /// final valid = SynchsafeInt.isValid([0x00, 0x04, 0x68, 0x45]);
  /// // Returns true
  ///
  /// final invalid = SynchsafeInt.isValid([0x80, 0x04, 0x68, 0x45]);
  /// // Returns false (first byte has MSB set)
  /// ```
  static bool isValid(List<int> bytes) {
    if (bytes.length != 4) {
      return false;
    }

    for (final byte in bytes) {
      if (byte < 0 || byte > 255 || (byte & 0x80) != 0) {
        return false;
      }
    }

    return true;
  }

  /// Checks if a Uint8List represents a valid synchsafe integer.
  ///
  /// This is a convenience method that accepts a Uint8List instead of `List<int>`.
  ///
  /// ## Parameters
  /// - [bytes]: The bytes to validate
  ///
  /// ## Returns
  /// True if the bytes represent a valid synchsafe integer
  ///
  /// ## Example
  /// ```dart
  /// final bytes = Uint8List.fromList([0x00, 0x04, 0x68, 0x45]);
  /// final valid = SynchsafeInt.isValidBytes(bytes);
  /// // Returns true
  /// ```
  static bool isValidBytes(Uint8List bytes) {
    return isValid(bytes.toList());
  }

  /// Converts a regular integer to its synchsafe representation and back.
  ///
  /// This is primarily useful for testing and debugging to verify that
  /// encoding and decoding operations are working correctly.
  ///
  /// ## Parameters
  /// - [value]: The integer to round-trip
  ///
  /// ## Returns
  /// The value after encoding to synchsafe format and decoding back
  ///
  /// ## Throws
  /// - [ArgumentError] if [value] is negative or exceeds [maxValue]
  ///
  /// ## Example
  /// ```dart
  /// final original = 0x12345;
  /// final roundTrip = SynchsafeInt.roundTrip(original);
  /// assert(original == roundTrip); // Should always be true for valid inputs
  /// ```
  static int roundTrip(int value) {
    return decode(encode(value));
  }
}
