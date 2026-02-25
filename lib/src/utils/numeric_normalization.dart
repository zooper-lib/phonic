import '../core/container_kind.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';

/// Utility class for numeric value normalization and validation.
///
/// This class provides static methods for validating, clamping, and normalizing
/// numeric values used in audio metadata. All methods are designed to ensure
/// data integrity while handling edge cases gracefully.
///
/// The class supports both unified validation (consistent across all containers)
/// and container-specific validation based on capability constraints.
///
/// Example usage:
/// ```dart
/// // Validate a track number
/// final validTrack = NumericNormalization.validateTrackNumber(5); // Returns 5
///
/// // Clamp a BPM value to valid range
/// final clampedBpm = NumericNormalization.clampBpm(1500); // Returns 999
///
/// // Validate with container constraints
/// final normalizedValue = NumericNormalization.normalizeForContainer(
///   TagKey.trackNumber,
///   300,
///   id3v1Capability,
/// ); // Returns 255 (ID3v1 max track number)
/// ```
class NumericNormalization {
  /// Private constructor to prevent instantiation of utility class.
  const NumericNormalization._();

  // Track number constraints
  /// The minimum valid track number value.
  static const int minTrackNumber = 1;

  /// The maximum valid track number value (reasonable upper bound).
  static const int maxTrackNumber = 9999;

  // Disc number constraints
  /// The minimum valid disc number value.
  static const int minDiscNumber = 1;

  /// The maximum valid disc number value (reasonable upper bound).
  static const int maxDiscNumber = 999;

  // BPM constraints
  /// The minimum valid BPM value.
  static const int minBpm = 1;

  /// The maximum valid BPM value.
  static const int maxBpm = 999;

  // Rating constraints
  /// The minimum valid rating value.
  static const int minRating = 0;

  /// The maximum valid rating value.
  static const int maxRating = 100;

  // Year constraints
  /// The minimum valid year value.
  static const int minYear = 1900;

  /// The maximum valid year value.
  static const int maxYear = 2100;

  // Container-specific constraints
  /// ID3v1 maximum track number (single byte: 1-255).
  static const int id3v1MaxTrackNumber = 255;

  /// ID3v1 maximum year (4 characters, but limited by format).
  static const int id3v1MaxYear = 2155;

  /// Validates a track number value.
  ///
  /// Ensures the track number is within the valid range (1-9999).
  /// Track numbers must be positive integers representing the track's
  /// position within an album or collection.
  ///
  /// @param value The track number to validate
  /// @returns The validated track number
  /// @throws ArgumentError if the track number is outside the valid range
  ///
  /// Example:
  /// ```dart
  /// final valid = NumericNormalization.validateTrackNumber(5); // Returns 5
  /// final invalid = NumericNormalization.validateTrackNumber(0); // Throws ArgumentError
  /// ```
  static int validateTrackNumber(int value) {
    if (value < minTrackNumber || value > maxTrackNumber) {
      throw ArgumentError.value(
        value,
        'value',
        'Track number must be between $minTrackNumber and $maxTrackNumber (inclusive)',
      );
    }
    return value;
  }

  /// Validates a disc number value.
  ///
  /// Ensures the disc number is within the valid range (1-999).
  /// Disc numbers must be positive integers representing the disc's
  /// position within a multi-disc set.
  ///
  /// @param value The disc number to validate
  /// @returns The validated disc number
  /// @throws ArgumentError if the disc number is outside the valid range
  ///
  /// Example:
  /// ```dart
  /// final valid = NumericNormalization.validateDiscNumber(2); // Returns 2
  /// final invalid = NumericNormalization.validateDiscNumber(-1); // Throws ArgumentError
  /// ```
  static int validateDiscNumber(int value) {
    if (value < minDiscNumber || value > maxDiscNumber) {
      throw ArgumentError.value(
        value,
        'value',
        'Disc number must be between $minDiscNumber and $maxDiscNumber (inclusive)',
      );
    }
    return value;
  }

  /// Validates a BPM (beats per minute) value.
  ///
  /// Ensures the BPM is within the valid range (1-999).
  /// BPM values must represent realistic musical tempos.
  ///
  /// @param value The BPM to validate
  /// @returns The validated BPM
  /// @throws ArgumentError if the BPM is outside the valid range
  ///
  /// Example:
  /// ```dart
  /// final valid = NumericNormalization.validateBpm(120); // Returns 120
  /// final invalid = NumericNormalization.validateBpm(1000); // Throws ArgumentError
  /// ```
  static int validateBpm(int value) {
    if (value < minBpm || value > maxBpm) {
      throw ArgumentError.value(
        value,
        'value',
        'BPM must be between $minBpm and $maxBpm (inclusive)',
      );
    }
    return value;
  }

  /// Validates a rating value.
  ///
  /// Ensures the rating is within the valid range (0-100).
  /// Rating values use a percentage-based scale.
  ///
  /// @param value The rating to validate
  /// @returns The validated rating
  /// @throws ArgumentError if the rating is outside the valid range
  ///
  /// Example:
  /// ```dart
  /// final valid = NumericNormalization.validateRating(85); // Returns 85
  /// final invalid = NumericNormalization.validateRating(150); // Throws ArgumentError
  /// ```
  static int validateRating(int value) {
    if (value < minRating || value > maxRating) {
      throw ArgumentError.value(
        value,
        'value',
        'Rating must be between $minRating and $maxRating (inclusive)',
      );
    }
    return value;
  }

  /// Validates a year value.
  ///
  /// Ensures the year is within the valid range (1900-2100).
  /// Year values must represent reasonable release years.
  ///
  /// @param value The year to validate
  /// @returns The validated year
  /// @throws ArgumentError if the year is outside the valid range
  ///
  /// Example:
  /// ```dart
  /// final valid = NumericNormalization.validateYear(1995); // Returns 1995
  /// final invalid = NumericNormalization.validateYear(1800); // Throws ArgumentError
  /// ```
  static int validateYear(int value) {
    if (value < minYear || value > maxYear) {
      throw ArgumentError.value(
        value,
        'value',
        'Year must be between $minYear and $maxYear (inclusive)',
      );
    }
    return value;
  }

  /// Clamps a track number to the valid range.
  ///
  /// If the value is below the minimum, returns the minimum.
  /// If the value is above the maximum, returns the maximum.
  /// Otherwise returns the original value.
  ///
  /// @param value The track number to clamp
  /// @returns The clamped track number within valid range
  ///
  /// Example:
  /// ```dart
  /// final clamped = NumericNormalization.clampTrackNumber(0); // Returns 1
  /// final unchanged = NumericNormalization.clampTrackNumber(5); // Returns 5
  /// final maxed = NumericNormalization.clampTrackNumber(10000); // Returns 9999
  /// ```
  static int clampTrackNumber(int value) {
    return value.clamp(minTrackNumber, maxTrackNumber);
  }

  /// Clamps a disc number to the valid range.
  ///
  /// If the value is below the minimum, returns the minimum.
  /// If the value is above the maximum, returns the maximum.
  /// Otherwise returns the original value.
  ///
  /// @param value The disc number to clamp
  /// @returns The clamped disc number within valid range
  ///
  /// Example:
  /// ```dart
  /// final clamped = NumericNormalization.clampDiscNumber(0); // Returns 1
  /// final unchanged = NumericNormalization.clampDiscNumber(2); // Returns 2
  /// final maxed = NumericNormalization.clampDiscNumber(1000); // Returns 999
  /// ```
  static int clampDiscNumber(int value) {
    return value.clamp(minDiscNumber, maxDiscNumber);
  }

  /// Clamps a BPM value to the valid range.
  ///
  /// If the value is below the minimum, returns the minimum.
  /// If the value is above the maximum, returns the maximum.
  /// Otherwise returns the original value.
  ///
  /// @param value The BPM to clamp
  /// @returns The clamped BPM within valid range
  ///
  /// Example:
  /// ```dart
  /// final clamped = NumericNormalization.clampBpm(0); // Returns 1
  /// final unchanged = NumericNormalization.clampBpm(120); // Returns 120
  /// final maxed = NumericNormalization.clampBpm(1500); // Returns 999
  /// ```
  static int clampBpm(int value) {
    return value.clamp(minBpm, maxBpm);
  }

  /// Clamps a rating value to the valid range.
  ///
  /// If the value is below the minimum, returns the minimum.
  /// If the value is above the maximum, returns the maximum.
  /// Otherwise returns the original value.
  ///
  /// @param value The rating to clamp
  /// @returns The clamped rating within valid range
  ///
  /// Example:
  /// ```dart
  /// final clamped = NumericNormalization.clampRating(-10); // Returns 0
  /// final unchanged = NumericNormalization.clampRating(85); // Returns 85
  /// final maxed = NumericNormalization.clampRating(150); // Returns 100
  /// ```
  static int clampRating(int value) {
    return value.clamp(minRating, maxRating);
  }

  /// Clamps a year value to the valid range.
  ///
  /// If the value is below the minimum, returns the minimum.
  /// If the value is above the maximum, returns the maximum.
  /// Otherwise returns the original value.
  ///
  /// @param value The year to clamp
  /// @returns The clamped year within valid range
  ///
  /// Example:
  /// ```dart
  /// final clamped = NumericNormalization.clampYear(1800); // Returns 1900
  /// final unchanged = NumericNormalization.clampYear(1995); // Returns 1995
  /// final maxed = NumericNormalization.clampYear(2200); // Returns 2100
  /// ```
  static int clampYear(int value) {
    return value.clamp(minYear, maxYear);
  }

  /// Normalizes a numeric value for a specific container format.
  ///
  /// This method applies container-specific constraints based on the
  /// capability information. Different container formats have different
  /// limitations (e.g., ID3v1 track numbers are limited to 1-255).
  ///
  /// The method first validates the value against universal constraints,
  /// then applies container-specific clamping if needed.
  ///
  /// @param tagKey The type of tag being normalized
  /// @param value The numeric value to normalize
  /// @param capability The container capability defining constraints
  /// @returns The normalized value within container constraints
  /// @throws ArgumentError if the value cannot be normalized for the tag type
  ///
  /// Example:
  /// ```dart
  /// // ID3v1 has a 255 limit for track numbers
  /// final normalized = NumericNormalization.normalizeForContainer(
  ///   TagKey.trackNumber,
  ///   300,
  ///   id3v1Capability,
  /// ); // Returns 255
  ///
  /// // Other formats use the standard range
  /// final standard = NumericNormalization.normalizeForContainer(
  ///   TagKey.trackNumber,
  ///   300,
  ///   id3v24Capability,
  /// ); // Returns 300 (within standard range)
  /// ```
  static int normalizeForContainer(
    TagKey tagKey,
    int value,
    TagCapability capability,
  ) {
    // First apply universal validation/clamping
    int normalizedValue;
    switch (tagKey) {
      case TagKey.trackNumber:
        normalizedValue = clampTrackNumber(value);
        break;
      case TagKey.discNumber:
        normalizedValue = clampDiscNumber(value);
        break;
      case TagKey.bpm:
        normalizedValue = clampBpm(value);
        break;
      case TagKey.rating:
        normalizedValue = clampRating(value);
        break;
      case TagKey.year:
        normalizedValue = clampYear(value);
        break;
      default:
        throw ArgumentError.value(
          tagKey,
          'tagKey',
          'Unsupported numeric tag key: $tagKey',
        );
    }

    // Apply container-specific constraints
    return _applyContainerConstraints(tagKey, normalizedValue, capability);
  }

  /// Applies container-specific constraints to a normalized value.
  ///
  /// This internal method handles the container-specific limitations
  /// that may be more restrictive than the universal constraints.
  ///
  /// @param tagKey The type of tag being constrained
  /// @param value The already-normalized value
  /// @param capability The container capability defining constraints
  /// @returns The value with container constraints applied
  static int _applyContainerConstraints(
    TagKey tagKey,
    int value,
    TagCapability capability,
  ) {
    switch (capability.containerKind) {
      case ContainerKind.id3v1:
        return _applyId3v1Constraints(tagKey, value);
      case ContainerKind.id3v2:
      case ContainerKind.vorbis:
      case ContainerKind.mp4:
      case ContainerKind.none:
        // These formats use the standard constraints
        return value;
    }
  }

  /// Applies ID3v1-specific constraints.
  ///
  /// ID3v1 has more restrictive limits due to its fixed-size format:
  /// - Track numbers: 1-255 (single byte)
  /// - Year: 1900-2155 (4 ASCII characters)
  /// - Other numeric fields are not supported in ID3v1
  ///
  /// @param tagKey The type of tag being constrained
  /// @param value The normalized value
  /// @returns The value with ID3v1 constraints applied
  static int _applyId3v1Constraints(TagKey tagKey, int value) {
    switch (tagKey) {
      case TagKey.trackNumber:
        // ID3v1 track numbers are stored in a single byte (1-255)
        return value.clamp(minTrackNumber, id3v1MaxTrackNumber);
      case TagKey.year:
        // ID3v1 year is 4 ASCII characters, but practically limited
        return value.clamp(minYear, id3v1MaxYear);
      case TagKey.discNumber:
      case TagKey.bpm:
      case TagKey.rating:
        // These fields are not supported in ID3v1, return as-is
        // (they will be filtered out during encoding)
        return value;
      default:
        return value;
    }
  }

  /// Gets the valid range for a numeric tag key.
  ///
  /// Returns the minimum and maximum values allowed for the specified
  /// tag key in the universal constraints (before container-specific
  /// limitations are applied).
  ///
  /// @param tagKey The tag key to get the range for
  /// @returns A record containing (min, max) values for the tag
  /// @throws ArgumentError if the tag key is not a supported numeric type
  ///
  /// Example:
  /// ```dart
  /// final (min, max) = NumericNormalization.getValidRange(TagKey.trackNumber);
  /// // Returns (1, 9999)
  ///
  /// final (bpmMin, bpmMax) = NumericNormalization.getValidRange(TagKey.bpm);
  /// // Returns (1, 999)
  /// ```
  static (int min, int max) getValidRange(TagKey tagKey) {
    switch (tagKey) {
      case TagKey.trackNumber:
        return (minTrackNumber, maxTrackNumber);
      case TagKey.discNumber:
        return (minDiscNumber, maxDiscNumber);
      case TagKey.bpm:
        return (minBpm, maxBpm);
      case TagKey.rating:
        return (minRating, maxRating);
      case TagKey.year:
        return (minYear, maxYear);
      default:
        throw ArgumentError.value(
          tagKey,
          'tagKey',
          'Unsupported numeric tag key: $tagKey',
        );
    }
  }

  /// Gets the valid range for a numeric tag key in a specific container.
  ///
  /// Returns the minimum and maximum values allowed for the specified
  /// tag key when stored in the given container format. This accounts
  /// for container-specific limitations.
  ///
  /// @param tagKey The tag key to get the range for
  /// @param capability The container capability defining constraints
  /// @returns A record containing (min, max) values for the tag in the container
  /// @throws ArgumentError if the tag key is not a supported numeric type
  ///
  /// Example:
  /// ```dart
  /// final (min, max) = NumericNormalization.getContainerRange(
  ///   TagKey.trackNumber,
  ///   id3v1Capability,
  /// ); // Returns (1, 255)
  ///
  /// final (stdMin, stdMax) = NumericNormalization.getContainerRange(
  ///   TagKey.trackNumber,
  ///   id3v24Capability,
  /// ); // Returns (1, 9999)
  /// ```
  static (int min, int max) getContainerRange(
    TagKey tagKey,
    TagCapability capability,
  ) {
    final (universalMin, universalMax) = getValidRange(tagKey);

    switch (capability.containerKind) {
      case ContainerKind.id3v1:
        return _getId3v1Range(tagKey, universalMin, universalMax);
      case ContainerKind.id3v2:
      case ContainerKind.vorbis:
      case ContainerKind.mp4:
      case ContainerKind.none:
        return (universalMin, universalMax);
    }
  }

  /// Gets the ID3v1-specific range for a tag key.
  ///
  /// @param tagKey The tag key to get the range for
  /// @param universalMin The universal minimum value
  /// @param universalMax The universal maximum value
  /// @returns The ID3v1-constrained range
  static (int min, int max) _getId3v1Range(
    TagKey tagKey,
    int universalMin,
    int universalMax,
  ) {
    switch (tagKey) {
      case TagKey.trackNumber:
        return (universalMin, id3v1MaxTrackNumber);
      case TagKey.year:
        return (universalMin, id3v1MaxYear);
      case TagKey.discNumber:
      case TagKey.bpm:
      case TagKey.rating:
        // Not supported in ID3v1, return universal range
        return (universalMin, universalMax);
      default:
        return (universalMin, universalMax);
    }
  }

  /// Checks if a numeric value is valid for a specific tag key.
  ///
  /// This method performs validation without throwing exceptions,
  /// returning true if the value is within the valid range for
  /// the tag key, false otherwise.
  ///
  /// @param tagKey The tag key to validate against
  /// @param value The value to check
  /// @returns true if the value is valid, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = NumericNormalization.isValidValue(TagKey.trackNumber, 5); // true
  /// final isInvalid = NumericNormalization.isValidValue(TagKey.trackNumber, 0); // false
  /// ```
  static bool isValidValue(TagKey tagKey, int value) {
    try {
      switch (tagKey) {
        case TagKey.trackNumber:
          validateTrackNumber(value);
          break;
        case TagKey.discNumber:
          validateDiscNumber(value);
          break;
        case TagKey.bpm:
          validateBpm(value);
          break;
        case TagKey.rating:
          validateRating(value);
          break;
        case TagKey.year:
          validateYear(value);
          break;
        default:
          return false;
      }
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Checks if a numeric value is valid for a specific container.
  ///
  /// This method performs container-specific validation without
  /// throwing exceptions, returning true if the value is within
  /// the valid range for the tag key in the given container.
  ///
  /// @param tagKey The tag key to validate against
  /// @param value The value to check
  /// @param capability The container capability defining constraints
  /// @returns true if the value is valid for the container, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = NumericNormalization.isValidForContainer(
  ///   TagKey.trackNumber,
  ///   300,
  ///   id3v1Capability,
  /// ); // false (exceeds ID3v1 limit of 255)
  /// ```
  static bool isValidForContainer(
    TagKey tagKey,
    int value,
    TagCapability capability,
  ) {
    final (min, max) = getContainerRange(tagKey, capability);
    return value >= min && value <= max;
  }
}
