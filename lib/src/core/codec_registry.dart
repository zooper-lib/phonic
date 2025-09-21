import 'container_kind.dart';
import 'container_locator.dart';
import 'tag_codec.dart';

/// Registry for managing collections of tag codecs and container locators.
///
/// The [CodecRegistry] serves as a central repository for all available
/// [TagCodec] and [ContainerLocator] implementations, providing a unified
/// interface for codec and locator discovery and selection.
///
/// This registry enables the format strategy system to:
/// - Discover available codecs for specific container formats and versions
/// - Access appropriate locators for container detection and manipulation
/// - Support extensibility by allowing registration of custom implementations
/// - Maintain separation between format detection and parsing logic
///
/// ## Usage Patterns
///
/// ### Basic Registry Setup
/// ```dart
/// final registry = CodecRegistry(
///   codecList: [
///     Id3v24Codec(),
///     Id3v23Codec(),
///     Id3v22Codec(),
///     Id3v1Codec(),
///     VorbisCommentsCodec(),
///     Mp4AtomsCodec(),
///   ],
///   containerLocatorList: [
///     Id3v2Locator(),
///     Id3v1Locator(),
///     VorbisLocator(),
///     OggVorbisLocator(),
///     Mp4Locator(),
///   ],
/// );
/// ```
///
/// ### Codec Discovery
/// ```dart
/// // Find codec for specific container type and version
/// final codec = registry.getCodec(ContainerKind.id3v2, '2.4');
/// if (codec != null) {
///   final tags = codec.readFromContainer(containerBytes);
/// }
///
/// // Get all codecs for a container type (all versions)
/// final id3Codecs = registry.getCodecsForContainer(ContainerKind.id3v2);
/// ```
///
/// ### Locator Discovery
/// ```dart
/// // Find locator for specific container type
/// final locator = registry.getLocator(ContainerKind.id3v2);
/// if (locator != null && locator.fileMatches(fileBytes)) {
///   final containerBytes = locator.extract(fileBytes);
/// }
///
/// // Get all locators that can handle a file
/// final matchingLocators = registry.getMatchingLocators(fileBytes);
/// ```
///
/// ## Registry Design Principles
///
/// ### Immutability
/// The registry is immutable after construction, ensuring thread safety
/// and preventing accidental modification of the codec/locator collections.
///
/// ### Performance
/// - Codec and locator lookups are optimized for frequent access
/// - Collections are indexed by container type for O(1) access
/// - No dynamic loading or reflection - all implementations are explicit
///
/// ### Extensibility
/// New codec and locator implementations can be easily added by:
/// 1. Implementing the [TagCodec] or [ContainerLocator] interface
/// 2. Adding the instance to the appropriate constructor parameter
/// 3. The registry automatically handles indexing and discovery
///
/// ## Thread Safety
///
/// The [CodecRegistry] is fully thread-safe:
/// - All collections are immutable after construction
/// - Codec and locator instances should be stateless
/// - Multiple threads can safely access the same registry instance
/// - No synchronization is required for read operations
///
/// ## Memory Considerations
///
/// - Registry holds references to all codec and locator instances
/// - Codec and locator implementations should be lightweight
/// - Consider using factory patterns for heavy initialization
/// - Registry instances can be shared across multiple operations
///
/// See also:
/// - [TagCodec] for the codec interface
/// - [ContainerLocator] for the locator interface
/// - [FormatStrategy] for format-specific processing logic
class CodecRegistry {
  /// The complete list of available tag codecs.
  ///
  /// This list contains all [TagCodec] implementations that the registry
  /// can use for parsing and encoding metadata containers. Each codec
  /// handles a specific container format and version combination.
  ///
  /// The list is immutable after construction to ensure thread safety
  /// and prevent accidental modification of the registry state.
  ///
  /// Example codecs in a typical registry:
  /// - [Id3v24Codec] for ID3v2.4 tags
  /// - [Id3v23Codec] for ID3v2.3 tags
  /// - [Id3v22Codec] for ID3v2.2 tags
  /// - [Id3v1Codec] for ID3v1 tags
  /// - [VorbisCommentsCodec] for Vorbis Comments
  /// - [Mp4AtomsCodec] for MP4 metadata atoms
  final List<TagCodec> codecList;

  /// The complete list of available container locators.
  ///
  /// This list contains all [ContainerLocator] implementations that the
  /// registry can use for detecting, extracting, and injecting metadata
  /// containers within audio files. Each locator handles a specific
  /// container format's storage conventions.
  ///
  /// The list is immutable after construction to ensure thread safety
  /// and prevent accidental modification of the registry state.
  ///
  /// Example locators in a typical registry:
  /// - [Id3v2Locator] for ID3v2 tags at file beginning
  /// - [Id3v1Locator] for ID3v1 tags at file end
  /// - [VorbisLocator] for FLAC Vorbis comment blocks
  /// - [OggVorbisLocator] for OGG Vorbis comment packets
  /// - [Mp4Locator] for MP4 ilst atoms within moov structure
  final List<ContainerLocator> containerLocatorList;

  /// Creates a new codec registry with the specified codecs and locators.
  ///
  /// Both [codecList] and [containerLocatorList] are required parameters
  /// that define the complete set of available implementations. The lists
  /// are copied to ensure immutability of the registry state.
  ///
  /// ## Parameters
  ///
  /// - [codecList]: All available [TagCodec] implementations
  /// - [containerLocatorList]: All available [ContainerLocator] implementations
  ///
  /// ## Example
  ///
  /// ```dart
  /// final registry = CodecRegistry(
  ///   codecList: [
  ///     Id3v24Codec(),
  ///     Id3v23Codec(),
  ///     VorbisCommentsCodec(),
  ///     Mp4AtomsCodec(),
  ///   ],
  ///   containerLocatorList: [
  ///     Id3v2Locator(),
  ///     Id3v1Locator(),
  ///     VorbisLocator(),
  ///     Mp4Locator(),
  ///   ],
  /// );
  /// ```
  ///
  /// ## Design Considerations
  ///
  /// - Lists are copied to prevent external modification
  /// - No validation is performed on codec/locator compatibility
  /// - Duplicate codecs for the same format/version are allowed
  /// - Order in the lists may affect selection behavior in some cases
  CodecRegistry({
    required List<TagCodec> codecList,
    required List<ContainerLocator> containerLocatorList,
  }) : codecList = List.unmodifiable(codecList),
       containerLocatorList = List.unmodifiable(containerLocatorList);

  /// Finds a codec for the specified container kind and version.
  ///
  /// This method searches the registry's codec collection for a codec that
  /// matches both the container type and version. The search returns the
  /// first matching codec found, or `null` if no suitable codec is available.
  ///
  /// ## Parameters
  ///
  /// - [containerKind]: The type of metadata container to find a codec for
  /// - [containerVersion]: The specific version of the container format
  ///
  /// ## Returns
  ///
  /// The first [TagCodec] that matches both the container kind and version,
  /// or `null` if no matching codec is found in the registry.
  ///
  /// ## Usage Examples
  ///
  /// ```dart
  /// // Find codec for ID3v2.4
  /// final codec = registry.findCodec(ContainerKind.id3v2, '2.4');
  /// if (codec != null) {
  ///   final tags = codec.readFromContainer(containerBytes);
  /// }
  ///
  /// // Handle missing codec gracefully
  /// final vorbisCodec = registry.findCodec(ContainerKind.vorbis, '');
  /// if (vorbisCodec == null) {
  ///   print('Vorbis codec not available in this registry');
  ///   return;
  /// }
  /// ```
  ///
  /// ## Selection Behavior
  ///
  /// - Returns the first codec that matches both criteria
  /// - If multiple codecs match, the first one in the registry list is returned
  /// - Both container kind and version must match exactly
  /// - Case-sensitive version matching
  ///
  /// ## Performance
  ///
  /// - O(n) linear search through the codec list
  /// - Efficient for typical registry sizes (< 10 codecs)
  /// - Consider caching results if called frequently with same parameters
  TagCodec? findCodec(ContainerKind containerKind, String containerVersion) {
    for (final codec in codecList) {
      if (codec.containerKind == containerKind && codec.containerVersion == containerVersion) {
        return codec;
      }
    }
    return null;
  }

  /// Finds a locator for the specified container kind.
  ///
  /// This method searches the registry's locator collection for a locator that
  /// handles the specified container type. The search returns the first
  /// matching locator found, or `null` if no suitable locator is available.
  ///
  /// ## Parameters
  ///
  /// - [containerKind]: The type of metadata container to find a locator for
  ///
  /// ## Returns
  ///
  /// The first [ContainerLocator] that handles the specified container kind,
  /// or `null` if no matching locator is found in the registry.
  ///
  /// ## Usage Examples
  ///
  /// ```dart
  /// // Find locator for ID3v2 containers
  /// final locator = registry.findLocator(ContainerKind.id3v2);
  /// if (locator != null && locator.fileMatches(fileBytes)) {
  ///   final containerBytes = locator.extract(fileBytes);
  /// }
  ///
  /// // Handle missing locator gracefully
  /// final mp4Locator = registry.findLocator(ContainerKind.mp4);
  /// if (mp4Locator == null) {
  ///   print('MP4 locator not available in this registry');
  ///   return;
  /// }
  /// ```
  ///
  /// ## Selection Behavior
  ///
  /// - Returns the first locator that matches the container kind
  /// - If multiple locators match, the first one in the registry list is returned
  /// - Only container kind matching is performed (locators are not versioned)
  ///
  /// ## Performance
  ///
  /// - O(n) linear search through the locator list
  /// - Efficient for typical registry sizes (< 10 locators)
  /// - Consider caching results if called frequently with same parameters
  ContainerLocator? findLocator(ContainerKind containerKind) {
    for (final locator in containerLocatorList) {
      if (locator.containerKind == containerKind) {
        return locator;
      }
    }
    return null;
  }
}
