import 'package:equatable/equatable.dart';

import 'container_kind.dart';
import 'tag_confidence.dart';

/// Tracks the origin and reliability of metadata tag values.
///
/// TagProvenance provides essential information about where a tag value
/// came from and how reliable it is. This information is crucial for
/// making informed decisions during tag merging, conflict resolution,
/// and data quality assessment.
///
/// The provenance includes three key pieces of information:
/// - Container type: Which metadata format contained the tag
/// - Container version: Specific version of the format (e.g., "2.4" for ID3v2.4)
/// - Confidence level: How reliable the tag value is considered to be
///
/// Example usage:
/// ```dart
/// // Tag read directly from ID3v2.4
/// final provenance = TagProvenance(
///   ContainerKind.id3v2,
///   '2.4',
///   TagConfidence.certain,
/// );
///
/// // Default provenance for unknown sources
/// final defaultProvenance = TagProvenance.none();
///
/// // Inferred tag with lower confidence
/// final inferredProvenance = TagProvenance(
///   ContainerKind.none,
///   '',
///   TagConfidence.inferred,
/// );
/// ```
///
/// Provenance information is used by the library to:
/// - Determine precedence during tag merging operations
/// - Provide transparency about data sources to users
/// - Enable auditing of metadata transformations
/// - Support debugging of tag parsing issues
class TagProvenance extends Equatable {
  /// The type of metadata container that provided this tag value.
  ///
  /// This identifies which metadata format the tag was read from,
  /// such as ID3v2, Vorbis Comments, or MP4 atoms. The container
  /// kind affects precedence during merge operations and determines
  /// which codec was used for parsing.
  final ContainerKind containerKind;

  /// The specific version of the metadata container format.
  ///
  /// Different versions of the same container format may have
  /// different capabilities, encoding support, or field semantics.
  /// This version string helps distinguish between format variants.
  ///
  /// Examples:
  /// - "2.4", "2.3", "2.2" for ID3v2 versions
  /// - "v1" for ID3v1
  /// - "" (empty string) for formats without meaningful versions
  final String containerVersion;

  /// The confidence level indicating how reliable this tag value is.
  ///
  /// This helps distinguish between values that were explicitly
  /// stored in the metadata versus values that were inferred,
  /// derived, or transformed during processing.
  final TagConfidence confidence;

  /// Creates a new TagProvenance with the specified container information.
  ///
  /// All parameters are required to ensure complete provenance tracking.
  /// Use [TagProvenance.none] for default or unknown provenance.
  ///
  /// @param containerKind The metadata container type
  /// @param containerVersion The specific version of the container format
  /// @param confidence The reliability level of the tag value
  const TagProvenance(
    this.containerKind,
    this.containerVersion,
    this.confidence,
  );

  /// Creates a default TagProvenance for unknown or unspecified sources.
  ///
  /// This constructor provides a convenient way to create provenance
  /// for tags that don't originate from a specific container, such as
  /// user-provided defaults, computed values, or placeholder data.
  ///
  /// The default provenance uses:
  /// - [ContainerKind.none] to indicate no specific container
  /// - Empty string for container version
  /// - [TagConfidence.certain] as the default confidence level
  ///
  /// Example:
  /// ```dart
  /// final tag = TitleTag('Default Title', provenance: TagProvenance.none());
  /// ```
  const TagProvenance.none() : containerKind = ContainerKind.none, containerVersion = '', confidence = TagConfidence.certain;

  @override
  List<Object?> get props => [containerKind, containerVersion, confidence];

  @override
  String toString() {
    if (containerKind == ContainerKind.none) {
      return 'TagProvenance.none()';
    }

    final versionPart = containerVersion.isNotEmpty ? ' v$containerVersion' : '';
    return 'TagProvenance(${containerKind.name}$versionPart, ${confidence.name})';
  }
}
