/// Format-specific constraints and limitations for metadata containers.
///
/// This file contains enums and classes that define the structural limitations
/// and constraints of various audio metadata formats. These constraints are used
/// by capability definitions to validate and normalize metadata values.

import 'text_encoding.dart';

/// ID3v1 format constraints and structure definitions.
///
/// ID3v1 is a legacy metadata format with a fixed 128-byte structure located
/// at the end of MP3 files. This class defines all the structural constraints
/// and limitations of the format as compile-time constants.
///
/// Usage:
/// ```dart
/// // Get field length limit
/// final maxLength = ID3v1Constraints.maxTextLength;
///
/// // Check if a value is within range
/// if (trackNumber >= ID3v1Constraints.minTrackNumber &&
///     trackNumber <= ID3v1Constraints.maxTrackNumber) {
///   // Valid track number
/// }
/// ```
abstract class ID3v1Constraints {
  /// Maximum length for most text fields (title, artist, album).
  ///
  /// ID3v1 allocates exactly 30 bytes for the title, artist, and album
  /// fields. Text exceeding this length must be truncated.
  static const int maxTextLength = 30;

  /// Maximum length for the year field.
  ///
  /// The year field in ID3v1 is exactly 4 bytes and should contain
  /// a 4-digit year (e.g., "1995", "2023").
  static const int yearLength = 4;

  /// Maximum length for comment field when track number is present.
  ///
  /// When a track number is stored in the ID3v1 tag, it occupies the
  /// last byte of the comment field, reducing the available comment
  /// space from 30 to 28 characters plus a null terminator.
  static const int commentLengthWithTrack = 28;

  /// Maximum length for comment field when no track number is present.
  ///
  /// When no track number is stored, the full 30-byte comment field
  /// is available for comment text.
  static const int commentLengthWithoutTrack = 30;

  /// Minimum valid track number value.
  ///
  /// Track numbers in ID3v1 are stored as a single byte (0-255),
  /// but 0 is not considered a valid track number.
  static const int minTrackNumber = 1;

  /// Maximum valid track number value.
  ///
  /// Track numbers are stored as a single unsigned byte, limiting
  /// the maximum value to 255.
  static const int maxTrackNumber = 255;

  /// Minimum valid genre code.
  ///
  /// Genre codes in ID3v1 start at 0, which corresponds to "Blues"
  /// in the standard ID3v1 genre table.
  static const int minGenreCode = 0;

  /// Maximum valid genre code.
  ///
  /// Genre codes are stored as a single unsigned byte, with the
  /// standard ID3v1 genre table defining codes 0-255.
  static const int maxGenreCode = 255;

  /// Total size of the ID3v1 tag structure in bytes.
  ///
  /// The complete ID3v1 tag is exactly 128 bytes:
  /// - 3 bytes: "TAG" identifier
  /// - 30 bytes: Title
  /// - 30 bytes: Artist
  /// - 30 bytes: Album
  /// - 4 bytes: Year
  /// - 30 bytes: Comment (or 28 + null + track)
  /// - 1 byte: Genre
  static const int tagSize = 128;

  /// The ID3v1 tag identifier ("TAG").
  ///
  /// ID3v1 tags begin with this 3-byte ASCII identifier to mark
  /// the start of the metadata structure.
  static const String tagIdentifier = 'TAG';

  /// Set of encodings supported by ID3v1.
  ///
  /// ID3v1 only supports ISO-8859-1 (Latin-1) encoding, with no
  /// Unicode support available.
  static const Set<TextEncoding> supportedEncodings = {TextEncoding.iso88591};

  /// Returns the set of supported encoding names as strings.
  ///
  /// This is a convenience method for APIs that work with string-based
  /// encoding names rather than the TextEncoding enum.
  static Set<String> get supportedEncodingNames => supportedEncodings.map((e) => e.standardName).toSet();
}

/// ID3v2.3 format constraints and structure definitions.
///
/// ID3v2.3 is a widely-supported metadata format that allows variable-length
/// fields and supports multiple text encodings. This class defines the
/// constraints and limitations specific to the ID3v2.3 specification.
///
/// Key differences from ID3v2.4:
/// - No UTF-8 support (only ISO-8859-1 and UTF-16)
/// - Uses separate TYER/TDAT/TIME frames instead of TDRC
/// - Different frame size limits and encoding rules
///
/// Usage:
/// ```dart
/// // Check encoding support
/// if (ID3v23Constraints.supportedEncodings.contains(encoding)) {
///   // Encoding is supported in ID3v2.3
/// }
///
/// // Get rating range
/// final maxRating = ID3v23Constraints.maxRatingValue;
/// ```
abstract class ID3v23Constraints {
  /// Maximum frame size in ID3v2.3 (excluding header).
  ///
  /// ID3v2.3 uses 32-bit frame sizes, allowing frames up to ~4GB,
  /// but practical limits are much lower for compatibility.
  static const int maxFrameSize = 0x7FFFFFFF; // 2GB for safety

  /// Maximum tag size in ID3v2.3.
  ///
  /// The ID3v2.3 header uses synchsafe integers for size, limiting
  /// the total tag size to approximately 256MB.
  static const int maxTagSize = 0x0FFFFFFF; // ~256MB

  /// Rating value range minimum (POPM frame).
  ///
  /// ID3v2.3 POPM frames store ratings as a single byte (0-255),
  /// where 0 typically means "no rating".
  static const int minRatingValue = 0;

  /// Rating value range maximum (POPM frame).
  ///
  /// The maximum rating value in ID3v2.3 POPM frames is 255,
  /// which gets converted to the unified 0-100 scale.
  static const int maxRatingValue = 255;

  /// Minimum valid year value for TYER frame.
  ///
  /// While technically any 4-digit number is valid, years before
  /// 1000 are not musically meaningful in most contexts.
  static const int minYear = 1000;

  /// Maximum valid year value for TYER frame.
  ///
  /// This is set to a reasonable future year to catch obvious errors
  /// while allowing for reasonable future dates.
  static const int maxYear = 3000;

  /// Set of encodings supported by ID3v2.3.
  ///
  /// ID3v2.3 supports ISO-8859-1 and UTF-16 (both BE and LE),
  /// but does not support UTF-8 (which was added in ID3v2.4).
  static const Set<TextEncoding> supportedEncodings = {
    TextEncoding.iso88591,
    TextEncoding.utf16,
    TextEncoding.utf16be,
    TextEncoding.utf16le,
  };

  /// Returns the set of supported encoding names as strings.
  ///
  /// This is a convenience method for APIs that work with string-based
  /// encoding names rather than the TextEncoding enum.
  static Set<String> get supportedEncodingNames => supportedEncodings.map((e) => e.standardName).toSet();

  /// Converts a 0-255 POPM rating to the unified 0-100 scale.
  ///
  /// This handles the conversion from ID3v2.3's native rating scale
  /// to the unified rating system used by the tagging API.
  static int convertRatingFromPopm(int popmRating) {
    if (popmRating == 0) return 0; // No rating
    return ((popmRating - 1) * FieldConstraints.ratingMax.value / (maxRatingValue - 1)).round();
  }

  /// Converts a unified 0-100 rating to ID3v2.3 POPM format.
  ///
  /// This handles the conversion from the unified rating system
  /// to ID3v2.3's native 0-255 POPM rating scale.
  static int convertRatingToPopm(int unifiedRating) {
    if (unifiedRating == 0) return 0; // No rating
    return ((unifiedRating * (maxRatingValue - 1) / FieldConstraints.ratingMax.value) + 1).round();
  }

  /// Validates that a year value is reasonable for ID3v2.3.
  static bool isValidYear(int year) {
    return year >= minYear && year <= maxYear;
  }

  /// Validates that a POPM rating value is within the valid range.
  static bool isValidPopmRating(int rating) {
    return rating >= minRatingValue && rating <= maxRatingValue;
  }
}

/// Common field constraints used across multiple metadata formats.
///
/// These constraints define commonly used limits and ranges that appear
/// in multiple metadata formats or are used for normalization in the
/// unified tagging system.
enum FieldConstraints {
  /// Standard rating scale minimum value (0-100).
  ///
  /// The unified rating system uses a 0-100 scale, with 0 representing
  /// no rating and 100 representing the maximum rating.
  ratingMin(0),

  /// Standard rating scale maximum value (0-100).
  ///
  /// This is the maximum value in the unified rating system, which
  /// gets converted to format-specific scales during write operations.
  ratingMax(100),

  /// Minimum valid BPM (beats per minute) value.
  ///
  /// While technically BPM could be any positive number, values below
  /// 1 are not musically meaningful.
  bpmMin(1),

  /// Maximum reasonable BPM value for validation.
  ///
  /// While there's no technical limit, BPM values above 999 are
  /// extremely rare and may indicate data errors.
  bpmMax(999);

  /// Creates a FieldConstraints with the specified numeric value.
  const FieldConstraints(this.value);

  /// The numeric value of this constraint.
  final int value;

  /// Returns the range of the rating scale (0-100).
  static int get ratingRange => ratingMax.value - ratingMin.value;

  /// Returns the range of the BPM scale.
  static int get bpmRange => bpmMax.value - bpmMin.value;

  /// Validates that a rating value is within the standard range.
  static bool isValidRating(int rating) {
    return rating >= ratingMin.value && rating <= ratingMax.value;
  }

  /// Validates that a BPM value is within the reasonable range.
  static bool isValidBpm(int bpm) {
    return bpm >= bpmMin.value && bpm <= bpmMax.value;
  }

  /// Clamps a rating value to the valid range.
  static int clampRating(int rating) {
    return rating.clamp(ratingMin.value, ratingMax.value);
  }

  /// Clamps a BPM value to the valid range.
  static int clampBpm(int bpm) {
    return bpm.clamp(bpmMin.value, bpmMax.value);
  }
}
