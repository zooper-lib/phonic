import 'dart:typed_data';

import 'container_kind.dart';
import 'media_kind.dart';

/// Abstract base class for format-specific detection and container precedence strategies.
///
/// FormatStrategy defines how the Phonic library handles different audio file formats,
/// including format detection, container precedence rules, and fan-out policies for
/// writing metadata. Each supported media format (MP3, FLAC, OGG, etc.) has its own
/// concrete strategy implementation.
///
/// The strategy pattern allows the library to:
/// - Detect audio file formats from binary data
/// - Define precedence rules when multiple containers exist
/// - Specify which containers to write to (fan-out policy)
/// - Handle format-specific detection logic
///
/// ## Container Precedence
///
/// When reading files with multiple metadata containers, precedence determines
/// which container's values take priority during tag merging. Higher precedence
/// containers override values from lower precedence ones.
///
/// Example MP3 precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
///
/// ## Fan-out Policy
///
/// When writing metadata, fan-out determines which containers receive the new
/// tag data. This allows writing to multiple containers simultaneously for
/// maximum compatibility.
///
/// Example MP3 fan-out: Write to ID3v2.4 (primary) and ID3v1 (compatibility)
///
/// ## Usage Example
///
/// ```dart
/// // Format detection
/// final strategy = Mp3FormatStrategy();
/// final fileBytes = await File('song.mp3').readAsBytes();
///
/// if (strategy.canHandle(fileBytes)) {
///   final mediaKind = strategy.detectFormat(fileBytes);
///   print('Detected format: $mediaKind');
///
///   // Access precedence rules
///   for (final (containerKind, version) in strategy.precedence) {
///     print('Container: $containerKind v$version');
///   }
///
///   // Access fan-out targets
///   for (final (containerKind, version) in strategy.fanout) {
///     print('Write target: $containerKind v$version');
///   }
/// }
/// ```
///
/// ## Implementation Requirements
///
/// Concrete strategy classes must:
/// - Implement reliable format detection in [canHandle]
/// - Return the correct [MediaKind] from [detectFormat]
/// - Define appropriate precedence and fan-out policies
/// - Handle edge cases in format detection gracefully
///
/// ## Performance Considerations
///
/// Format detection should be efficient as it may be called frequently:
/// - Check file signatures before complex parsing
/// - Limit the amount of data read for detection
/// - Use fast byte pattern matching where possible
/// - Avoid expensive operations in [canHandle]
///
/// ## Thread Safety
///
/// FormatStrategy implementations should be stateless and thread-safe,
/// as they may be used concurrently across multiple files.
abstract class FormatStrategy {
  /// The media kind that this strategy handles.
  ///
  /// This identifies the primary audio format type (MP3, FLAC, OGG, etc.)
  /// that this strategy is designed to process. Each strategy handles
  /// exactly one media kind.
  ///
  /// Example:
  /// ```dart
  /// final strategy = Mp3FormatStrategy();
  /// print(strategy.mediaKind); // MediaKind.mp3
  /// ```
  MediaKind get mediaKind;

  /// Container precedence order for reading operations.
  ///
  /// When multiple metadata containers exist in a file, this list defines
  /// the priority order for tag merging. Containers earlier in the list
  /// have higher precedence and their values override those from later
  /// containers.
  ///
  /// Each tuple contains:
  /// - [ContainerKind]: The type of metadata container
  /// - [String]: The container version (e.g., "2.4", "v1", "")
  ///
  /// Example for MP3 files:
  /// ```dart
  /// [
  ///   (ContainerKind.id3v2, "2.4"),  // Highest precedence
  ///   (ContainerKind.id3v2, "2.3"),
  ///   (ContainerKind.id3v2, "2.2"),
  ///   (ContainerKind.id3v1, "v1"),   // Lowest precedence
  /// ]
  /// ```
  ///
  /// The precedence order should reflect:
  /// - Newer versions over older versions
  /// - More capable containers over limited ones
  /// - Format-specific best practices and conventions
  List<(ContainerKind, String)> get precedence;

  /// Container fan-out targets for writing operations.
  ///
  /// When writing metadata to a file, this list defines which containers
  /// should receive the new tag data. This allows writing to multiple
  /// containers simultaneously for maximum compatibility.
  ///
  /// Each tuple contains:
  /// - [ContainerKind]: The type of metadata container to write
  /// - [String]: The container version to target
  ///
  /// Example for MP3 files:
  /// ```dart
  /// [
  ///   (ContainerKind.id3v2, "2.4"),  // Primary target (full features)
  ///   (ContainerKind.id3v1, "v1"),   // Compatibility target (basic fields)
  /// ]
  /// ```
  ///
  /// Fan-out considerations:
  /// - Primary target should support all desired features
  /// - Secondary targets provide compatibility with older software
  /// - Container capabilities determine which tags can be written
  /// - Order may affect write performance and file structure
  List<(ContainerKind, String)> get fanout;

  /// Determines if this strategy can handle the given file data.
  ///
  /// This method performs fast format detection by examining file signatures,
  /// headers, and other identifying characteristics. It should be efficient
  /// as it may be called frequently during format detection.
  ///
  /// The method should:
  /// - Check file signatures and magic numbers
  /// - Validate essential format structures
  /// - Return quickly for non-matching formats
  /// - Handle truncated or malformed data gracefully
  ///
  /// Parameters:
  /// - [fileBytes]: The beginning of the file data (typically first few KB)
  ///
  /// Returns:
  /// - `true` if this strategy can process the file format
  /// - `false` if the format is not supported by this strategy
  ///
  /// Example implementation pattern:
  /// ```dart
  /// @override
  /// bool canHandle(Uint8List fileBytes) {
  ///   if (fileBytes.length < 4) return false;
  ///
  ///   // Check for format signature
  ///   if (_hasFormatSignature(fileBytes)) return true;
  ///
  ///   // Check for container headers
  ///   if (_hasContainerHeaders(fileBytes)) return true;
  ///
  ///   return false;
  /// }
  /// ```
  ///
  /// Performance notes:
  /// - Should complete in microseconds for typical files
  /// - Avoid reading large amounts of data
  /// - Use byte pattern matching over string operations
  /// - Cache expensive computations if needed
  bool canHandle(Uint8List fileBytes);

  /// Detects the specific media format from file data.
  ///
  /// This method performs more detailed format analysis to determine the
  /// exact media type. It should only be called after [canHandle] returns
  /// true, as it may perform more expensive operations.
  ///
  /// The detection process may involve:
  /// - Parsing format-specific headers
  /// - Analyzing codec information
  /// - Examining container structure
  /// - Validating format compliance
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to analyze (may be complete file or prefix)
  ///
  /// Returns:
  /// - The detected [MediaKind] for the file
  ///
  /// Throws:
  /// - [UnsupportedFormatException] if format cannot be determined
  /// - [CorruptedContainerException] if file structure is invalid
  ///
  /// Example implementation:
  /// ```dart
  /// @override
  /// MediaKind detectFormat(Uint8List fileBytes) {
  ///   if (_isMp3Format(fileBytes)) return MediaKind.mp3;
  ///   if (_isM4aFormat(fileBytes)) return MediaKind.m4a;
  ///
  ///   throw UnsupportedFormatException('Cannot determine format');
  /// }
  /// ```
  ///
  /// The returned MediaKind should match this strategy's [mediaKind] property
  /// in most cases, but some strategies may handle multiple related formats
  /// (e.g., MP4 strategy handling both M4A and MP4 files).
  MediaKind detectFormat(Uint8List fileBytes);
}
