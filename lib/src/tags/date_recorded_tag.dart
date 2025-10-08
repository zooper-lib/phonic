part of '../core/metadata_tag.dart';

/// Represents a date recorded metadata tag for audio files.
///
/// DateRecordedTag contains the full recording or release date of the track,
/// providing precise temporal information for music libraries and organization
/// systems. This tag helps users sort, filter, and organize their music
/// collections by exact dates and discover music from specific time periods.
///
/// The date value must be in ISO-8601 format, supporting various levels of
/// precision from year-only to full date-time with timezone information.
/// This validation ensures data integrity and cross-platform compatibility
/// while accommodating different levels of date precision available in
/// source metadata.
///
/// Supported ISO-8601 formats:
/// - Year only: "2023"
/// - Year-month: "2023-03"
/// - Full date: "2023-03-15"
/// - Date with time: "2023-03-15T14:30:00"
/// - Date with timezone: "2023-03-15T14:30:00Z"
/// - Date with offset: "2023-03-15T14:30:00+02:00"
///
/// Format mappings:
/// - ID3v2: TDRC frame (v2.4) or TYER/TDAT/TIME combination (v2.3)
/// - Vorbis: DATE field
/// - MP4: ©day atom
/// - ID3v1: Not supported (year portion extracted to year field)
///
/// Example usage:
/// ```dart
/// // Create a basic date tag with full date
/// final dateTag = DateRecordedTag('2023-03-15');
///
/// // Create with year only
/// final yearOnlyTag = DateRecordedTag('2023');
///
/// // Create with full timestamp
/// final timestampTag = DateRecordedTag('2023-03-15T14:30:00Z');
///
/// // Create with provenance information
/// final dateWithProvenance = DateRecordedTag(
///   '2023-03-15',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = dateTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The date value must be a valid ISO-8601 formatted string. Invalid formats
/// will cause an ArgumentError to be thrown during construction. This ensures
/// consistent date handling across different container formats and platforms.
///
/// For validation and form integration, use [DateRecordedTag.validator]:
/// ```dart
/// // Pre-validate before creating tag
/// if (DateRecordedTag.validator.validate(userInput) == null) {
///   final tag = DateRecordedTag(userInput);
/// }
/// ```
final class DateRecordedTag extends MetadataTag<String> {
  /// Public validator for date recorded tag values.
  ///
  /// This validator can be used to pre-validate user input before creating
  /// a DateRecordedTag instance, or integrated with form validation libraries
  /// like reactive_forms.
  ///
  /// Example usage:
  /// ```dart
  /// // Pre-validate before creating tag
  /// if (DateRecordedTag.validator.validate(userInput) == null) {
  ///   final tag = DateRecordedTag(userInput);
  /// }
  /// ```
  static const validator = DateRecordedValidator();

  /// Creates a new DateRecordedTag with the specified ISO-8601 date.
  ///
  /// @param value The recording date in ISO-8601 format
  /// @param provenance Optional provenance information about the tag source
  /// @throws ArgumentError if value is not a valid ISO-8601 date format
  ///
  /// Example:
  /// ```dart
  /// final tag = DateRecordedTag('2023-03-15');
  /// final yearOnly = DateRecordedTag('2023');
  /// final withTime = DateRecordedTag('2023-03-15T14:30:00Z');
  /// ```
  DateRecordedTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: validator.validateOrThrow(value),
         key: TagKey.dateRecorded,
         provenance: provenance,
       );

  /// Creates a new DateRecordedTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the date recorded tag while preserving the date value. This is commonly
  /// used during tag processing operations where the same date needs to
  /// be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new DateRecordedTag instance with the same date but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = DateRecordedTag('2023-03-15');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  DateRecordedTag withProvenance(TagProvenance newProvenance) {
    return DateRecordedTag(value, provenance: newProvenance);
  }

  /// Converts this DateRecordedTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a DateRecordedTag from a JSON Map.
  static DateRecordedTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return DateRecordedTag(value, provenance: provenance);
  }
}
