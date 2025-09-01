import 'dart:typed_data';

import '../../core/codec_registry.dart';
import '../../core/merge_policy.dart';
import '../../core/phonic_audio_file_impl.dart';
import '../../utils/locators/id3v1_locator.dart';
import '../../utils/locators/id3v2_locator.dart';
import 'id3v1_codec.dart';
import 'id3v22_codec.dart';
import 'id3v23_codec.dart';
import 'id3v24_codec.dart';
import 'mp3_format_strategy.dart';

/// MP3-specific audio file implementation with ID3 metadata support.
///
/// Mp3AudioFile extends [PhonicAudioFileImpl] with MP3-specific configuration,
/// including the appropriate format strategy, codecs, and locators for handling
/// ID3v1, ID3v2.2, ID3v2.3, and ID3v2.4 metadata containers.
///
/// ## Supported Containers
///
/// This implementation supports all common ID3 metadata formats found in MP3 files:
/// - **ID3v2.4**: Primary target with UTF-8 support and enhanced features
/// - **ID3v2.3**: Widely supported with UTF-16 encoding
/// - **ID3v2.2**: Legacy format with 3-character frame IDs
/// - **ID3v1**: Basic compatibility format with fixed-length fields
///
/// ## Container Precedence
///
/// When reading MP3 files with multiple metadata containers, the following
/// precedence order is applied (highest to lowest):
/// 1. ID3v2.4 - Most recent version with full feature support
/// 2. ID3v2.3 - Widely compatible version
/// 3. ID3v2.2 - Legacy version for older files
/// 4. ID3v1 - Basic compatibility for legacy players
///
/// ## Fan-out Policy
///
/// When writing metadata, the following containers are targeted:
/// 1. ID3v2.4 - Primary target supporting all unified tag fields
/// 2. ID3v1 - Secondary target for maximum compatibility with legacy players
///
/// This dual-target approach ensures rich metadata is preserved in ID3v2.4
/// while basic information remains accessible through ID3v1.
///
/// ## Usage Examples
///
/// ### Creating from File Bytes
/// ```dart
/// final fileBytes = await File('song.mp3').readAsBytes();
/// final mp3File = Mp3AudioFile.fromBytes(fileBytes);
///
/// // Read tags
/// final title = mp3File.getTag(TagKey.title);
/// final genres = mp3File.getTags(TagKey.genre);
///
/// // Modify tags
/// mp3File.setTag(TitleTag('New Title'));
/// mp3File.setTag(GenreTag(['Rock', 'Alternative']));
///
/// // Save changes
/// if (mp3File.isDirty) {
///   final updatedBytes = await mp3File.encode();
///   await File('updated_song.mp3').writeAsBytes(updatedBytes);
///   mp3File.markClean();
/// }
/// ```
///
/// ### Working with Multiple Containers
/// ```dart
/// // Get all tags to see provenance information
/// final allTags = mp3File.getAllTags();
/// for (final tag in allTags) {
///   print('${tag.key}: ${tag.value}');
///   print('  Source: ${tag.provenance.containerKind} ${tag.provenance.containerVersion}');
/// }
///
/// // Tags are automatically written to both ID3v2.4 and ID3v1
/// mp3File.setTag(ArtistTag('New Artist')); // Written to both containers
/// mp3File.setTag(RatingTag(85)); // Only written to ID3v2.4 (ID3v1 doesn't support ratings)
/// ```
///
/// ## Memory Management
///
/// The implementation follows the same memory management principles as the base class:
/// - Artwork and large payloads are loaded lazily
/// - Container data is cached only when needed for writing
/// - Dispose method releases all cached resources
/// - Efficient memory usage for large MP3 collections
///
/// ## Error Handling
///
/// The implementation handles MP3-specific error conditions:
/// - Corrupted ID3 headers and frames
/// - Invalid synchsafe integers in ID3v2 tags
/// - Truncated or malformed containers
/// - Encoding errors in text fields
/// - Missing or invalid genre codes in ID3v1
///
/// ## Performance Characteristics
///
/// - Fast format detection using MP3 frame sync and ID3 signatures
/// - Efficient container extraction with minimal memory allocation
/// - Lazy loading of artwork and complex frame data
/// - Optimized encoding with container-specific normalization
///
/// ## Thread Safety
///
/// Like the base implementation, Mp3AudioFile is not thread-safe. Concurrent
/// access should be synchronized by the caller.
///
/// See also:
/// - [PhonicAudioFileImpl] for the base implementation
/// - [Mp3FormatStrategy] for MP3-specific format handling
/// - [Id3v24Codec], [Id3v23Codec], [Id3v22Codec], [Id3v1Codec] for container parsing
/// - [Id3v2Locator], [Id3v1Locator] for container location and injection
class Mp3AudioFile extends PhonicAudioFileImpl {
  /// Creates a new MP3 audio file instance from file bytes.
  ///
  /// This constructor initializes the MP3 audio file with all necessary
  /// components for handling ID3 metadata containers. The configuration
  /// includes:
  ///
  /// - **Format Strategy**: [Mp3FormatStrategy] for MP3-specific detection and precedence
  /// - **Codecs**: All ID3 codec implementations (v2.4, v2.3, v2.2, v1)
  /// - **Locators**: ID3v2 and ID3v1 locators for container extraction/injection
  /// - **Merge Policy**: Configured for MP3 precedence and fan-out rules
  ///
  /// ## Parameters
  ///
  /// - [fileBytes]: The complete MP3 file bytes including audio data and metadata
  /// - [isDirty]: Initial dirty state (defaults to false for newly loaded files)
  ///
  /// ## Initialization Process
  ///
  /// 1. Creates MP3-specific format strategy with precedence and fan-out rules
  /// 2. Builds codec registry with all supported ID3 codec implementations
  /// 3. Configures container locators for ID3v2 and ID3v1 detection
  /// 4. Sets up merge policy based on the format strategy
  /// 5. Initializes the base implementation with the configured components
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// // Load MP3 file
  /// final fileBytes = await File('song.mp3').readAsBytes();
  /// final mp3File = Mp3AudioFile.fromBytes(fileBytes);
  ///
  /// // File is ready for tag operations
  /// final title = mp3File.getTag(TagKey.title);
  /// ```
  ///
  /// ## Error Handling
  ///
  /// The constructor does not perform format validation - this allows for
  /// flexible usage and deferred error handling. Format validation occurs
  /// during the first tag operation or when explicitly requested.
  ///
  /// Invalid or corrupted files will be handled gracefully during tag
  /// extraction, with appropriate exceptions thrown for unrecoverable errors.
  ///
  /// ## Memory Considerations
  ///
  /// - File bytes are stored internally for encoding operations
  /// - No immediate parsing is performed to minimize initialization overhead
  /// - Container data is loaded on-demand during tag operations
  /// - Codec and locator instances are lightweight and shared
  Mp3AudioFile.fromBytes(
    Uint8List fileBytes, {
    bool isDirty = false,
  }) : super(
         fileBytes: fileBytes,
         formatStrategy: const Mp3FormatStrategy(),
         codecRegistry: _createMp3CodecRegistry(),
         mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
         isDirty: isDirty,
       );

  /// Creates a codec registry configured for MP3 files with all ID3 codecs and locators.
  ///
  /// This method builds a complete [CodecRegistry] containing all the codecs
  /// and locators needed for MP3 file processing. The registry includes:
  ///
  /// ### Codecs
  /// - [Id3v24Codec]: For ID3v2.4 tags (primary target)
  /// - [Id3v23Codec]: For ID3v2.3 tags (wide compatibility)
  /// - [Id3v22Codec]: For ID3v2.2 tags (legacy support)
  /// - [Id3v1Codec]: For ID3v1 tags (basic compatibility)
  ///
  /// ### Locators
  /// - [Id3v2Locator]: For detecting and extracting ID3v2 tags at file beginning
  /// - [Id3v1Locator]: For detecting and extracting ID3v1 tags at file end
  ///
  /// ## Registry Configuration
  ///
  /// The registry is configured to support the complete range of ID3 metadata
  /// formats commonly found in MP3 files. This ensures maximum compatibility
  /// with files created by different software and across different time periods.
  ///
  /// ## Performance Considerations
  ///
  /// - All codec instances are stateless and can be safely reused
  /// - Locator instances are lightweight with minimal memory overhead
  /// - Registry lookup operations are optimized for frequent access
  /// - No dynamic loading or reflection is used for maximum performance
  ///
  /// ## Thread Safety
  ///
  /// The returned registry is thread-safe as all contained codecs and locators
  /// are stateless. Multiple threads can safely use the same registry instance
  /// for concurrent file processing.
  ///
  /// Returns:
  /// A fully configured [CodecRegistry] with all MP3-compatible codecs and locators.
  ///
  /// Example usage:
  /// ```dart
  /// final registry = _createMp3CodecRegistry();
  ///
  /// // Find codec for specific container
  /// final codec = registry.findCodec(ContainerKind.id3v2, '2.4');
  ///
  /// // Find locator for container type
  /// final locator = registry.findLocator(ContainerKind.id3v2);
  /// ```
  static CodecRegistry _createMp3CodecRegistry() {
    return CodecRegistry(
      codecList: [
        // ID3v2 codecs in order of preference (newest to oldest)
        const Id3v24Codec(), // Primary target with full UTF-8 support
        const Id3v23Codec(), // Widely supported with UTF-16
        const Id3v22Codec(), // Legacy support with 3-char frame IDs
        // ID3v1 codec for basic compatibility
        const Id3v1Codec(), // Fixed-length legacy format
      ],
      containerLocatorList: [
        // ID3v2 locator for tags at file beginning
        Id3v2Locator(),

        // ID3v1 locator for tags at file end
        Id3v1Locator(),
      ],
    );
  }
}
