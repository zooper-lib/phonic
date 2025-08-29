part of '../metadata_tag.dart';

/// Represents a grouping metadata tag for audio files.
///
/// GroupingTag contains content grouping or work classification information
/// for the track. This field is used to group related tracks together, such as
/// movements in a classical work, parts of a suite, or thematic groupings within
/// an album. Also known as "Content Group" in some formats.
///
/// Format mappings:
/// - ID3v2: TIT1 frame
/// - Vorbis: GROUPING field
/// - MP4: ©grp atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic grouping tag
/// final groupingTag = GroupingTag('Symphony No. 9 in D minor');
///
/// // Create with provenance information
/// final groupingWithProvenance = GroupingTag(
///   'Beethoven: Symphony No. 9',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = groupingTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The grouping value should be a string containing the work or group name.
/// Different container formats may have length limitations that are handled
/// automatically during encoding operations.
final class GroupingTag extends MetadataTag<String> {
  /// Creates a new GroupingTag with the specified grouping value.
  ///
  /// @param value The grouping or work classification text, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = GroupingTag('The Beatles: Sgt. Pepper\'s Lonely Hearts Club Band');
  /// ```
  const GroupingTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.grouping,
         provenance: provenance,
       );

  /// Creates a new GroupingTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the grouping tag while preserving the grouping value. This is commonly
  /// used during tag processing operations where the same grouping needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new GroupingTag instance with the same grouping but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = GroupingTag('Classical Suite');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  GroupingTag withProvenance(TagProvenance newProvenance) {
    return GroupingTag(value, provenance: newProvenance);
  }
}
