import 'container_kind.dart';
import 'tag_key.dart';
import 'tag_semantics.dart';

/// Defines the metadata capabilities and constraints for a specific container format.
///
/// [TagCapability] encapsulates the complete set of supported tag fields and their
/// semantic constraints for a particular container format and version. This enables
/// the library to validate tag operations, apply format-specific normalization,
/// and provide accurate capability information to users.
///
/// The capability system is used throughout the library for:
/// - Validating tag values before writing to containers
/// - Determining which fields are supported by each format
/// - Applying format-specific constraints (length limits, value ranges)
/// - Normalizing values between different container formats
/// - Providing user feedback about format limitations
///
/// Example usage:
/// ```dart
/// // Define capability for ID3v1 format
/// const id3v1Capability = TagCapability(
///   containerKind: ContainerKind.id3v1,
///   containerVersion: 'v1',
///   semanticsByKey: {
///     TagKey.title: TagSemantics(maxTextLength: 30),
///     TagKey.artist: TagSemantics(maxTextLength: 30),
///     TagKey.album: TagSemantics(maxTextLength: 30),
///     TagKey.year: TagSemantics(maxTextLength: 4),
///     TagKey.comment: TagSemantics(maxTextLength: 30), // or 28 with track
///     TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
///     TagKey.genre: TagSemantics(minValue: 0, maxValue: 255),
///   },
/// );
///
/// // Check if a field is supported
/// if (id3v1Capability.supports(TagKey.artwork)) {
///   // This will be false - ID3v1 doesn't support artwork
/// }
///
/// // Get semantic constraints for a field
/// final titleSemantics = id3v1Capability.semantics(TagKey.title);
/// if (!titleSemantics.isValidTextLength(titleText.length)) {
///   titleText = titleSemantics.truncateText(titleText);
/// }
/// ```
///
/// Container-specific examples:
/// ```dart
/// // ID3v2.4 capability with UTF-8 support
/// const id3v24Capability = TagCapability(
///   containerKind: ContainerKind.id3v2,
///   containerVersion: '2.4',
///   semanticsByKey: {
///     TagKey.title: TagSemantics(allowedEncodings: {
///       TextEncoding.iso88591.standardName,
///       TextEncoding.utf16.standardName,
///       TextEncoding.utf8.standardName
///     }),
///     TagKey.genre: TagSemantics(multiValued: false), // Single TCON frame
///     TagKey.artwork: TagSemantics(multiValued: true), // Multiple APIC frames
///     TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
///   },
/// );
///
/// // Vorbis capability with multi-valued field support
/// const vorbisCapability = TagCapability(
///   containerKind: ContainerKind.vorbis,
///   containerVersion: '',
///   semanticsByKey: {
///     TagKey.genre: TagSemantics(multiValued: true, allowedEncodings: {TextEncoding.utf8.standardName}),
///     TagKey.artwork: TagSemantics(multiValued: true),
///   },
/// );
/// ```
class TagCapability {
  /// The container format this capability definition applies to.
  ///
  /// Identifies which metadata container format (ID3v1, ID3v2, Vorbis, MP4)
  /// this capability definition describes. This is used for format detection,
  /// codec selection, and provenance tracking.
  final ContainerKind containerKind;

  /// The specific version of the container format.
  ///
  /// Provides version-specific capability information, as different versions
  /// of the same container format may have different features and constraints.
  /// Examples: "v1" for ID3v1, "2.4" for ID3v2.4, "" for unversioned formats.
  ///
  /// Version-specific differences:
  /// - ID3v2.3 vs ID3v2.4: UTF-8 support, date field handling
  /// - Different MP4 implementations may have varying atom support
  /// - Vorbis implementations may have different extension support
  final String containerVersion;

  /// Map of tag fields to their semantic constraints for this container format.
  ///
  /// This map defines which tag fields are supported by the container format
  /// and what constraints apply to each field. Fields not present in this map
  /// are considered unsupported by the format.
  ///
  /// The semantics include:
  /// - Text length limitations (e.g., ID3v1's 30-character limits)
  /// - Numeric value ranges (e.g., rating scales, track number limits)
  /// - Multi-value support (e.g., Vorbis multi-valued fields)
  /// - Encoding restrictions (e.g., ID3v2.3 lacks UTF-8 support)
  ///
  /// Example:
  /// ```dart
  /// semanticsByKey: {
  ///   TagKey.title: TagSemantics(maxTextLength: 30),
  ///   TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
  ///   TagKey.genre: TagSemantics(multiValued: true),
  /// }
  /// ```
  final Map<TagKey, TagSemantics> semanticsByKey;

  /// Creates a new [TagCapability] instance for the specified container format.
  ///
  /// Parameters:
  /// - [containerKind]: The type of metadata container this capability describes
  /// - [containerVersion]: The specific version of the container format
  /// - [semanticsByKey]: Map of supported fields to their semantic constraints
  ///
  /// The [semanticsByKey] map should include all fields supported by the
  /// container format. Fields not included in the map will be considered
  /// unsupported and will return `false` from [supports].
  ///
  /// Example:
  /// ```dart
  /// const capability = TagCapability(
  ///   containerKind: ContainerKind.id3v1,
  ///   containerVersion: 'v1',
  ///   semanticsByKey: {
  ///     TagKey.title: TagSemantics(maxTextLength: 30),
  ///     TagKey.artist: TagSemantics(maxTextLength: 30),
  ///     // ... other supported fields
  ///   },
  /// );
  /// ```
  const TagCapability({
    required this.containerKind,
    required this.containerVersion,
    required this.semanticsByKey,
  });

  /// Returns `true` if the specified tag field is supported by this container format.
  ///
  /// A field is considered supported if it has an entry in the [semanticsByKey]
  /// map. Unsupported fields cannot be written to the container format and
  /// will be skipped during write operations.
  ///
  /// This method is used throughout the library to:
  /// - Filter tags before writing to containers
  /// - Provide user feedback about format limitations
  /// - Determine fan-out targets for multi-format writing
  /// - Validate tag operations before execution
  ///
  /// Example:
  /// ```dart
  /// const id3v1Capability = TagCapability(
  ///   containerKind: ContainerKind.id3v1,
  ///   containerVersion: 'v1',
  ///   semanticsByKey: {
  ///     TagKey.title: TagSemantics(maxTextLength: 30),
  ///     TagKey.artist: TagSemantics(maxTextLength: 30),
  ///   },
  /// );
  ///
  /// print(id3v1Capability.supports(TagKey.title));   // true
  /// print(id3v1Capability.supports(TagKey.artwork)); // false
  /// ```
  ///
  /// Parameters:
  /// - [key]: The tag field to check for support
  ///
  /// Returns:
  /// - `true` if the field is supported (has semantic constraints defined)
  /// - `false` if the field is not supported by this container format
  bool supports(TagKey key) => semanticsByKey.containsKey(key);

  /// Returns the semantic constraints for the specified tag field.
  ///
  /// Retrieves the [TagSemantics] instance that defines the constraints and
  /// capabilities for the given tag field in this container format. If the
  /// field is not supported, returns a default [TagSemantics] instance with
  /// no constraints.
  ///
  /// The returned semantics can be used to:
  /// - Validate tag values before writing
  /// - Apply format-specific normalization (truncation, clamping)
  /// - Determine encoding requirements
  /// - Check multi-value support
  ///
  /// Example:
  /// ```dart
  /// const capability = TagCapability(
  ///   containerKind: ContainerKind.id3v1,
  ///   containerVersion: 'v1',
  ///   semanticsByKey: {
  ///     TagKey.title: TagSemantics(maxTextLength: 30),
  ///     TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
  ///   },
  /// );
  ///
  /// // Get constraints for supported field
  /// final titleSemantics = capability.semantics(TagKey.title);
  /// print(titleSemantics.maxTextLength); // 30
  ///
  /// // Get constraints for unsupported field
  /// final artworkSemantics = capability.semantics(TagKey.artwork);
  /// print(artworkSemantics.hasConstraints); // false
  ///
  /// // Use semantics for validation and normalization
  /// String title = "This is a very long title that exceeds the limit";
  /// if (!titleSemantics.isValidTextLength(title.length)) {
  ///   title = titleSemantics.truncateText(title);
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [key]: The tag field to get semantic constraints for
  ///
  /// Returns:
  /// - [TagSemantics] instance with constraints for the field if supported
  /// - Default [TagSemantics] instance (no constraints) if field is unsupported
  TagSemantics semantics(TagKey key) => semanticsByKey[key] ?? const TagSemantics();

  /// Returns a list of all tag fields supported by this container format.
  ///
  /// This method provides a convenient way to enumerate all the tag fields
  /// that can be written to this container format. The returned list contains
  /// all keys from the [semanticsByKey] map.
  ///
  /// This is useful for:
  /// - Displaying format capabilities to users
  /// - Filtering tag collections before writing
  /// - Generating format comparison reports
  /// - Implementing format-specific UI elements
  ///
  /// Example:
  /// ```dart
  /// const capability = TagCapability(
  ///   containerKind: ContainerKind.id3v1,
  ///   containerVersion: 'v1',
  ///   semanticsByKey: {
  ///     TagKey.title: TagSemantics(maxTextLength: 30),
  ///     TagKey.artist: TagSemantics(maxTextLength: 30),
  ///     TagKey.album: TagSemantics(maxTextLength: 30),
  ///   },
  /// );
  ///
  /// final supportedFields = capability.supportedFields;
  /// print(supportedFields); // [TagKey.title, TagKey.artist, TagKey.album]
  ///
  /// // Use for filtering
  /// final tagsToWrite = allTags.where((tag) =>
  ///   supportedFields.contains(tag.key)).toList();
  /// ```
  ///
  /// Returns:
  /// - List of [TagKey] values representing all supported fields
  /// - Empty list if no fields are supported (though this would be unusual)
  List<TagKey> get supportedFields => semanticsByKey.keys.toList();

  /// Returns the number of tag fields supported by this container format.
  ///
  /// This provides a quick way to get the count of supported fields without
  /// creating a list. Useful for capacity planning, format comparison, and
  /// progress reporting.
  ///
  /// Example:
  /// ```dart
  /// print('ID3v1 supports ${id3v1Capability.supportedFieldCount} fields');
  /// print('ID3v2.4 supports ${id3v24Capability.supportedFieldCount} fields');
  /// ```
  ///
  /// Returns:
  /// - Integer count of supported tag fields
  int get supportedFieldCount => semanticsByKey.length;

  /// Returns `true` if this container format has any field constraints.
  ///
  /// Checks whether any of the supported fields have semantic constraints
  /// defined (length limits, value ranges, encoding restrictions, etc.).
  /// This can be useful for determining whether validation is necessary
  /// before writing to this format.
  ///
  /// Example:
  /// ```dart
  /// if (capability.hasConstraints) {
  ///   // Apply validation and normalization before writing
  ///   tags = validateAndNormalizeTags(tags, capability);
  /// }
  /// ```
  ///
  /// Returns:
  /// - `true` if any supported field has constraints
  /// - `false` if all fields are unconstrained (or no fields supported)
  bool get hasConstraints => semanticsByKey.values.any((semantics) => semantics.hasConstraints);

  /// Returns a string representation of this capability definition.
  ///
  /// Provides a human-readable description of the container format, version,
  /// and number of supported fields. Useful for debugging, logging, and
  /// displaying format information to users.
  ///
  /// Example output:
  /// ```
  /// TagCapability(ID3v1 v1: 7 fields)
  /// TagCapability(ID3v2 2.4: 18 fields)
  /// TagCapability(Vorbis : 15 fields)
  /// ```
  @override
  String toString() {
    final versionStr = containerVersion.isNotEmpty ? ' $containerVersion' : '';
    return 'TagCapability(${containerKind.name}$versionStr: ${supportedFieldCount} fields)';
  }

  /// Checks equality with another [TagCapability] instance.
  ///
  /// Two capability instances are considered equal if they have the same
  /// container kind, version, and semantic constraints for all fields.
  /// This is useful for testing and capability comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TagCapability) return false;

    return containerKind == other.containerKind && containerVersion == other.containerVersion && _mapEquals(semanticsByKey, other.semanticsByKey);
  }

  /// Returns a hash code for this capability instance.
  ///
  /// The hash code is based on the container kind, version, and semantic
  /// constraints, ensuring that equal capability instances have the same
  /// hash code for use in collections.
  @override
  int get hashCode {
    // Create a consistent hash for the semantics map
    final semanticsEntries = semanticsByKey.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index));

    final semanticsHash = Object.hashAll(semanticsEntries.expand((entry) => [entry.key, entry.value]));

    return Object.hash(containerKind, containerVersion, semanticsHash);
  }

  /// Helper method to compare two maps for equality.
  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
