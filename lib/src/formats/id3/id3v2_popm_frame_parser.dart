import 'dart:typed_data';

import '../../exceptions/corrupted_container_exception.dart';
import '../../utils/byte_reader.dart';

/// Utilities for parsing ID3v2 POPM (Popularimeter) frames.
///
/// POPM frames contain rating information with the following structure:
/// - Email address (null-terminated string, ISO-8859-1 encoding)
/// - Rating (1 byte, 0-255 scale where 0 = no rating)
/// - Counter (4 bytes, big-endian, optional)
///
/// ## ID3v2 POPM Frame Structure
///
/// ```
/// Offset  Length      Description
/// 0       Variable    Email address (null-terminated ISO-8859-1)
/// N       1           Rating (0-255, where 0 = no rating)
/// N+1     4           Play counter (optional, big-endian uint32)
/// ```
///
/// ## Rating Scale Conversion
///
/// The POPM frame uses a 0-255 rating scale, which is converted to the
/// unified 0-100 scale used by the tagging API:
/// - 0 → 0 (no rating)
/// - 1-255 → 0-100 (linear conversion)
///
/// ## Email Formats
///
/// Different applications use different email formats in POPM frames:
/// - Standard email addresses: "user@example.com"
/// - Application identifiers: "Windows Media Player 9 Series"
/// - Empty strings: "" (some applications use empty email)
///
/// ## Example Usage
///
/// ```dart
/// final frameData = Uint8List.fromList([
///   0x75, 0x73, 0x65, 0x72, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D, 0x00, // "user@example.com\0"
///   0xC8, // Rating: 200
///   0x00, 0x00, 0x00, 0x2A, // Counter: 42
/// ]);
///
/// final popm = Id3v2PopmFrameParser.parse(frameData);
/// print('Email: ${popm.email}');
/// print('Rating: ${popm.rating}');
/// print('Unified Rating: ${popm.unifiedRating}');
/// print('Counter: ${popm.counter}');
/// ```

/// Result of parsing POPM (Popularimeter) frame data.
class Id3v2PopmFrameData {
  /// The email address associated with this rating.
  final String email;

  /// The rating value (0-255 scale).
  final int rating;

  /// The play counter (optional, may be null if not present).
  final int? counter;

  /// Creates POPM frame data with the specified properties.
  const Id3v2PopmFrameData({
    required this.email,
    required this.rating,
    this.counter,
  });

  /// Converts the rating from ID3v2 POPM scale (0-255) to unified scale (0-100).
  ///
  /// The conversion formula handles the special case where 0 means "no rating":
  /// - 0 → 0 (no rating)
  /// - 1-255 → 0-100 (linear conversion: (rating - 1) * 100 / 254)
  int get unifiedRating {
    if (rating == 0) return 0; // No rating
    return ((rating - 1) * 100 / 254).round();
  }

  /// Converts a unified rating (0-100) back to POPM scale (0-255).
  ///
  /// This is useful when writing POPM frames from unified rating values.
  static int unifiedRatingToPopm(int unifiedRating) {
    if (unifiedRating == 0) return 0; // No rating
    return ((unifiedRating * 254 / 100) + 1).round();
  }

  @override
  String toString() {
    return 'Id3v2PopmFrameData(email: "$email", rating: $rating, counter: $counter)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Id3v2PopmFrameData && runtimeType == other.runtimeType && email == other.email && rating == other.rating && counter == other.counter;

  @override
  int get hashCode => Object.hash(email, rating, counter);
}

/// Parser for ID3v2 POPM (Popularimeter) frames.
class Id3v2PopmFrameParser {
  /// Parses a POPM (Popularimeter) frame from frame data.
  ///
  /// POPM frames contain rating information with the following structure:
  /// - Email address (null-terminated string, ISO-8859-1 encoding)
  /// - Rating (1 byte, 0-255 scale where 0 = no rating)
  /// - Counter (4 bytes, big-endian, optional)
  ///
  /// ## Parameters
  /// - [frameData]: The raw frame data bytes
  ///
  /// ## Returns
  /// An [Id3v2PopmFrameData] object containing the parsed rating information
  ///
  /// ## Throws
  /// - [ArgumentError] if [frameData] is too short for a valid POPM frame
  /// - [CorruptedContainerException] if the frame format is invalid
  ///
  /// ## Example
  /// ```dart
  /// final popmData = Uint8List.fromList([
  ///   0x75, 0x73, 0x65, 0x72, 0x40, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D, 0x00, // "user@example.com\0"
  ///   0xC8, // Rating: 200 (0-255 scale)
  ///   0x00, 0x00, 0x00, 0x2A, // Counter: 42
  /// ]);
  /// final popm = Id3v2PopmFrameParser.parse(popmData);
  /// print('Email: ${popm.email}'); // "user@example.com"
  /// print('Rating: ${popm.rating}'); // 200
  /// print('Unified Rating: ${popm.unifiedRating}'); // 78 (converted to 0-100 scale)
  /// print('Counter: ${popm.counter}'); // 42
  /// ```
  static Id3v2PopmFrameData parse(Uint8List frameData) {
    if (frameData.length < 2) {
      throw ArgumentError.value(
        frameData.length,
        'frameData.length',
        'POPM frame data must be at least 2 bytes (email + rating)',
      );
    }

    final reader = ByteReader(frameData);

    // Find the null terminator for the email address
    int emailEndIndex = -1;
    for (int i = 0; i < frameData.length; i++) {
      if (frameData[i] == 0) {
        emailEndIndex = i;
        break;
      }
    }

    if (emailEndIndex == -1) {
      throw const CorruptedContainerException(
        'POPM frame email address is not null-terminated',
        context: 'ID3v2 POPM frame parsing',
      );
    }

    // Extract email address (ISO-8859-1 encoding)
    final emailBytes = reader.readBytes(emailEndIndex);
    final email = String.fromCharCodes(emailBytes);

    // Skip the null terminator
    reader.skip(1);

    // Check if we have at least one byte for the rating
    if (reader.remaining < 1) {
      throw const CorruptedContainerException(
        'POPM frame missing rating byte',
        context: 'ID3v2 POPM frame parsing',
      );
    }

    // Extract rating (1 byte, 0-255)
    final rating = reader.readUint8();

    // Validate rating is within expected range
    if (rating < 0 || rating > 255) {
      throw CorruptedContainerException(
        'POPM frame rating value out of range: $rating (expected 0-255)',
        context: 'ID3v2 POPM frame parsing',
      );
    }

    // Extract counter if present (4 bytes, big-endian, optional)
    int? counter;
    if (reader.remaining >= 4) {
      counter = reader.readUint32();
    } else if (reader.remaining > 0) {
      // Partial counter data - this is technically invalid but we'll be lenient
      // and just ignore the incomplete counter
      counter = null;
    }

    return Id3v2PopmFrameData(
      email: email,
      rating: rating,
      counter: counter,
    );
  }

  /// Validates that a POPM frame data structure is valid.
  ///
  /// ## Parameters
  /// - [popmData]: The POPM frame data to validate
  ///
  /// ## Returns
  /// `true` if the data is valid, `false` otherwise
  static bool isValid(Id3v2PopmFrameData popmData) {
    // Rating must be in valid range
    if (popmData.rating < 0 || popmData.rating > 255) {
      return false;
    }

    // Email should not contain null bytes (they're used as terminators)
    if (popmData.email.contains('\x00')) {
      return false;
    }

    // Counter, if present, should be non-negative
    if (popmData.counter != null && popmData.counter! < 0) {
      return false;
    }

    return true;
  }

  /// Encodes POPM frame data back to bytes for writing to ID3v2 tags.
  ///
  /// ## Parameters
  /// - [popmData]: The POPM frame data to encode
  ///
  /// ## Returns
  /// The encoded frame data as bytes
  ///
  /// ## Throws
  /// - [ArgumentError] if the POPM data is invalid
  static Uint8List encode(Id3v2PopmFrameData popmData) {
    if (!isValid(popmData)) {
      throw ArgumentError('Invalid POPM frame data: $popmData');
    }

    final bytes = <int>[];

    // Add email address (ISO-8859-1 encoding)
    bytes.addAll(popmData.email.codeUnits);
    bytes.add(0); // Null terminator

    // Add rating byte
    bytes.add(popmData.rating);

    // Add counter if present
    if (popmData.counter != null) {
      final counter = popmData.counter!;
      bytes.add((counter >> 24) & 0xFF);
      bytes.add((counter >> 16) & 0xFF);
      bytes.add((counter >> 8) & 0xFF);
      bytes.add(counter & 0xFF);
    }

    return Uint8List.fromList(bytes);
  }
}
