/// Rating normalization utilities for converting between different rating scales.
///
/// This module provides utilities for converting rating values between the
/// unified 0-100 scale used by the Phonic API and the container-specific
/// scales used by different audio metadata formats.
///
/// The unified API uses a 0-100 scale for consistency and ease of use, but
/// different container formats use different internal scales:
/// - ID3v2 POPM frames: 0-255 scale
/// - Vorbis Comments: 0-100 scale (text representation)
/// - MP4 atoms: Various scales depending on implementation
/// - ID3v1: Not supported
///
/// This module handles the conversion between these scales while preserving
/// precision and handling edge cases appropriately.

import '../core/container_kind.dart';
import '../core/tag_capability.dart';
import '../core/tag_key.dart';

/// Utility class for rating scale conversion and normalization.
///
/// This class provides static methods for converting rating values between
/// the unified 0-100 scale and container-specific scales. All conversions
/// are designed to be reversible where possible and handle edge cases
/// gracefully.
///
/// The conversion algorithms use rounding to ensure that common rating
/// values (like 5-star systems) convert cleanly between scales.
///
/// Example usage:
/// ```dart
/// // Convert from ID3v2 POPM scale (0-255) to unified scale (0-100)
/// final unifiedRating = RatingNormalization.fromId3v2Scale(204); // Returns 80
///
/// // Convert from unified scale (0-100) to ID3v2 POPM scale (0-255)
/// final id3v2Rating = RatingNormalization.toId3v2Scale(80); // Returns 204
///
/// // Convert using container capability
/// final capability = id3v24Capability;
/// final normalized = RatingNormalization.normalizeFromContainer(
///   128,
///   capability,
/// ); // Returns 50
/// ```
class RatingNormalization {
  /// Private constructor to prevent instantiation of utility class.
  const RatingNormalization._();

  /// The minimum rating value in the unified scale.
  static const int unifiedMinRating = 0;

  /// The maximum rating value in the unified scale.
  static const int unifiedMaxRating = 100;

  /// The minimum rating value in the ID3v2 POPM scale.
  static const int id3v2MinRating = 0;

  /// The maximum rating value in the ID3v2 POPM scale.
  static const int id3v2MaxRating = 255;

  /// Converts a rating from the ID3v2 POPM scale (0-255) to the unified scale (0-100).
  ///
  /// This method converts ratings from the 8-bit scale used by ID3v2 POPM
  /// (Popularimeter) frames to the unified 0-100 scale. The conversion uses
  /// proportional scaling with rounding to ensure common values convert cleanly.
  ///
  /// The conversion formula is: `(id3v2Rating * 100 + 127) ~/ 255`
  /// The +127 provides rounding to the nearest integer for better precision.
  ///
  /// Common conversions:
  /// - 0 → 0 (no rating)
  /// - 51 → 20 (1 star equivalent)
  /// - 102 → 40 (2 stars)
  /// - 153 → 60 (3 stars)
  /// - 204 → 80 (4 stars)
  /// - 255 → 100 (5 stars/perfect)
  ///
  /// @param id3v2Rating The rating value in ID3v2 POPM scale (0-255)
  /// @returns The equivalent rating in unified scale (0-100)
  /// @throws ArgumentError if id3v2Rating is outside the valid range (0-255)
  ///
  /// Example:
  /// ```dart
  /// final rating = RatingNormalization.fromId3v2Scale(204); // Returns 80
  /// final maxRating = RatingNormalization.fromId3v2Scale(255); // Returns 100
  /// final noRating = RatingNormalization.fromId3v2Scale(0); // Returns 0
  /// ```
  static int fromId3v2Scale(int id3v2Rating) {
    if (id3v2Rating < id3v2MinRating || id3v2Rating > id3v2MaxRating) {
      throw ArgumentError.value(
        id3v2Rating,
        'id3v2Rating',
        'ID3v2 rating must be between $id3v2MinRating and $id3v2MaxRating (inclusive)',
      );
    }

    // Convert from 0-255 scale to 0-100 scale with rounding
    // Formula: (value * 100 + 127) ~/ 255
    // The +127 provides rounding to nearest integer (255/2 ≈ 127.5)
    return (id3v2Rating * unifiedMaxRating + (id3v2MaxRating ~/ 2)) ~/ id3v2MaxRating;
  }

  /// Converts a rating from the unified scale (0-100) to the ID3v2 POPM scale (0-255).
  ///
  /// This method converts ratings from the unified 0-100 scale to the 8-bit
  /// scale used by ID3v2 POPM frames. The conversion uses proportional scaling
  /// with rounding to preserve precision.
  ///
  /// The conversion formula is: `(unifiedRating * 255 + 50) ~/ 100`
  /// The +50 provides rounding to the nearest integer for better precision.
  ///
  /// Common conversions:
  /// - 0 → 0 (no rating)
  /// - 20 → 51 (1 star equivalent)
  /// - 40 → 102 (2 stars)
  /// - 60 → 153 (3 stars)
  /// - 80 → 204 (4 stars)
  /// - 100 → 255 (5 stars/perfect)
  ///
  /// @param unifiedRating The rating value in unified scale (0-100)
  /// @returns The equivalent rating in ID3v2 POMP scale (0-255)
  /// @throws ArgumentError if unifiedRating is outside the valid range (0-100)
  ///
  /// Example:
  /// ```dart
  /// final id3Rating = RatingNormalization.toId3v2Scale(80); // Returns 204
  /// final maxId3Rating = RatingNormalization.toId3v2Scale(100); // Returns 255
  /// final noId3Rating = RatingNormalization.toId3v2Scale(0); // Returns 0
  /// ```
  static int toId3v2Scale(int unifiedRating) {
    if (unifiedRating < unifiedMinRating || unifiedRating > unifiedMaxRating) {
      throw ArgumentError.value(
        unifiedRating,
        'unifiedRating',
        'Unified rating must be between $unifiedMinRating and $unifiedMaxRating (inclusive)',
      );
    }

    // Convert from 0-100 scale to 0-255 scale with rounding
    // Formula: (value * 255 + 50) ~/ 100
    // The +50 provides rounding to nearest integer (100/2 = 50)
    return (unifiedRating * id3v2MaxRating + (unifiedMaxRating ~/ 2)) ~/ unifiedMaxRating;
  }

  /// Normalizes a rating from a container-specific scale to the unified scale.
  ///
  /// This method uses the container's capability information to determine
  /// the appropriate conversion method. Different container formats use
  /// different rating scales, and this method handles the conversion
  /// automatically based on the container type.
  ///
  /// Supported container conversions:
  /// - ID3v2 (all versions): 0-255 scale → 0-100 scale
  /// - Vorbis Comments: 0-100 scale → 0-100 scale (no conversion)
  /// - MP4: 0-100 scale → 0-100 scale (no conversion, typically)
  /// - ID3v1: Not supported (returns input value)
  ///
  /// @param containerRating The rating value in the container's native scale
  /// @param capability The container capability defining the rating scale
  /// @returns The equivalent rating in unified scale (0-100)
  /// @throws ArgumentError if containerRating is outside the container's valid range
  ///
  /// Example:
  /// ```dart
  /// // ID3v2 conversion
  /// final id3Rating = RatingNormalization.normalizeFromContainer(
  ///   204,
  ///   id3v24Capability,
  /// ); // Returns 80
  ///
  /// // Vorbis conversion (no change needed)
  /// final vorbisRating = RatingNormalization.normalizeFromContainer(
  ///   85,
  ///   vorbisCapability,
  /// ); // Returns 85
  /// ```
  static int normalizeFromContainer(int containerRating, TagCapability capability) {
    switch (capability.containerKind) {
      case ContainerKind.id3v2:
        // ID3v2 uses 0-255 scale in POPM frames
        return fromId3v2Scale(containerRating);

      case ContainerKind.vorbis:
        // Vorbis Comments use 0-100 scale directly
        if (containerRating < unifiedMinRating || containerRating > unifiedMaxRating) {
          throw ArgumentError.value(
            containerRating,
            'containerRating',
            'Vorbis rating must be between $unifiedMinRating and $unifiedMaxRating (inclusive)',
          );
        }
        return containerRating;

      case ContainerKind.mp4:
        // MP4 typically uses 0-100 scale, but this can vary by implementation
        // For now, assume 0-100 scale like Vorbis
        if (containerRating < unifiedMinRating || containerRating > unifiedMaxRating) {
          throw ArgumentError.value(
            containerRating,
            'containerRating',
            'MP4 rating must be between $unifiedMinRating and $unifiedMaxRating (inclusive)',
          );
        }
        return containerRating;

      case ContainerKind.id3v1:
        // ID3v1 doesn't support ratings, but return the value as-is
        // This case should not normally occur in practice
        return containerRating;

      case ContainerKind.none:
        // No container, return as-is
        return containerRating;
    }
  }

  /// Converts a rating from the unified scale to a container-specific scale.
  ///
  /// This method uses the container's capability information to determine
  /// the appropriate conversion method. The rating is converted from the
  /// unified 0-100 scale to whatever scale the target container expects.
  ///
  /// Supported container conversions:
  /// - ID3v2 (all versions): 0-100 scale → 0-255 scale
  /// - Vorbis Comments: 0-100 scale → 0-100 scale (no conversion)
  /// - MP4: 0-100 scale → 0-100 scale (no conversion, typically)
  /// - ID3v1: Not supported (returns input value)
  ///
  /// @param unifiedRating The rating value in unified scale (0-100)
  /// @param capability The container capability defining the target rating scale
  /// @returns The equivalent rating in the container's native scale
  /// @throws ArgumentError if unifiedRating is outside the valid range (0-100)
  ///
  /// Example:
  /// ```dart
  /// // Convert to ID3v2 scale
  /// final id3Rating = RatingNormalization.normalizeToContainer(
  ///   80,
  ///   id3v24Capability,
  /// ); // Returns 204
  ///
  /// // Convert to Vorbis scale (no change needed)
  /// final vorbisRating = RatingNormalization.normalizeToContainer(
  ///   85,
  ///   vorbisCapability,
  /// ); // Returns 85
  /// ```
  static int normalizeToContainer(int unifiedRating, TagCapability capability) {
    if (unifiedRating < unifiedMinRating || unifiedRating > unifiedMaxRating) {
      throw ArgumentError.value(
        unifiedRating,
        'unifiedRating',
        'Unified rating must be between $unifiedMinRating and $unifiedMaxRating (inclusive)',
      );
    }

    switch (capability.containerKind) {
      case ContainerKind.id3v2:
        // ID3v2 uses 0-255 scale in POPM frames
        return toId3v2Scale(unifiedRating);

      case ContainerKind.vorbis:
        // Vorbis Comments use 0-100 scale directly
        return unifiedRating;

      case ContainerKind.mp4:
        // MP4 typically uses 0-100 scale, but this can vary by implementation
        // For now, assume 0-100 scale like Vorbis
        return unifiedRating;

      case ContainerKind.id3v1:
        // ID3v1 doesn't support ratings, but return the value as-is
        // This case should not normally occur in practice
        return unifiedRating;

      case ContainerKind.none:
        // No container, return as-is
        return unifiedRating;
    }
  }

  /// Checks if a container supports rating metadata.
  ///
  /// This method examines the container capability to determine if the
  /// container format supports rating metadata. Some formats like ID3v1
  /// do not support ratings at all.
  ///
  /// @param capability The container capability to check
  /// @returns true if the container supports ratings, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final supportsRating = RatingNormalization.supportsRating(id3v24Capability); // true
  /// final id3v1Supports = RatingNormalization.supportsRating(id3v1Capability); // false
  /// ```
  static bool supportsRating(TagCapability capability) {
    return capability.supports(TagKey.rating);
  }

  /// Gets the native rating scale range for a container format.
  ///
  /// This method returns the minimum and maximum rating values that the
  /// container format uses internally. This information can be useful
  /// for validation or display purposes.
  ///
  /// @param capability The container capability to examine
  /// @returns A record containing (min, max) rating values for the container
  ///
  /// Example:
  /// ```dart
  /// final (min, max) = RatingNormalization.getContainerRatingRange(id3v24Capability);
  /// // Returns (0, 255) for ID3v2 formats
  ///
  /// final (vMin, vMax) = RatingNormalization.getContainerRatingRange(vorbisCapability);
  /// // Returns (0, 100) for Vorbis Comments
  /// ```
  static (int min, int max) getContainerRatingRange(TagCapability capability) {
    switch (capability.containerKind) {
      case ContainerKind.id3v2:
        return (id3v2MinRating, id3v2MaxRating);

      case ContainerKind.vorbis:
      case ContainerKind.mp4:
        return (unifiedMinRating, unifiedMaxRating);

      case ContainerKind.id3v1:
      case ContainerKind.none:
        return (0, 0); // No rating support
    }
  }
}
