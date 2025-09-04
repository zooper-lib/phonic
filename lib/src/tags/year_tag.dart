part of '../core/metadata_tag.dart';

/// Represents a year metadata tag for audio files.
///
/// YearTag contains the release year of the track or album, providing essential
/// chronological information for music libraries and organization systems.
/// This tag helps users sort, filter, and organize their music collections
/// by release date and discover music from specific time periods.
///
/// The year value must be within a reasonable range (1900-2100) representing
/// a four-digit year. This validation ensures data integrity while accommodating
/// historical recordings and future releases. Years outside this range are
/// considered invalid and will cause an ArgumentError during construction.
///
/// Format mappings:
/// - ID3v2: TYER frame (v2.3) or extracted from TDRC frame (v2.4)
/// - Vorbis: DATE field (year portion extracted)
/// - MP4: ©day atom (year portion extracted)
/// - ID3v1: Year field (4 characters, 1900-2155 range)
///
/// Example usage:
/// ```dart
/// // Create a basic year tag
/// final yearTag = YearTag(1995);
///
/// // Create with provenance information
/// final yearWithProvenance = YearTag(
///   2023,
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = yearTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The year value must be between 1900 and 2100 (inclusive). Values outside
/// this range will cause an ArgumentError to be thrown during construction.
/// This range accommodates the earliest commercial recordings through
/// reasonable future releases while preventing obviously invalid dates.
final class YearTag extends MetadataTag<int> {
  /// The minimum valid year value (inclusive).
  static const int minYear = 1900;

  /// The maximum valid year value (inclusive).
  static const int maxYear = 2100;

  /// Creates a new YearTag with the specified year.
  ///
  /// @param value The release year, must be between 1900 and 2100 (inclusive)
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is not within the valid year range
  ///
  /// Example:
  /// ```dart
  /// final tag = YearTag(1995);
  /// final recentTag = YearTag(2023);
  /// final vintageTag = YearTag(1920);
  /// ```
  YearTag(
    int value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: _validateYear(value),
         key: TagKey.year,
         provenance: provenance,
       );

  /// Validates that the year is within the acceptable range.
  ///
  /// @param value The year to validate
  /// @returns The validated year
  /// @throws ArgumentError if the year is not between 1900 and 2100 (inclusive)
  static int _validateYear(int value) {
    if (value < minYear || value > maxYear) {
      throw ArgumentError.value(
        value,
        'value',
        'Year must be between $minYear and $maxYear (inclusive)',
      );
    }
    return value;
  }

  /// Creates a new YearTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the year tag while preserving the year value. This is commonly
  /// used during tag processing operations where the same year needs to
  /// be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new YearTag instance with the same year but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = YearTag(1995);
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  YearTag withProvenance(TagProvenance newProvenance) {
    return YearTag(value, provenance: newProvenance);
  }

  /// Converts this YearTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a YearTag from a JSON Map.
  static YearTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as int?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return YearTag(value, provenance: provenance);
  }
}
