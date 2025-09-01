import 'dart:typed_data';

import '../../core/codec_registry.dart';
import '../../core/merge_policy.dart';
import '../../core/phonic_audio_file_impl.dart';
import '../../utils/locators/ogg_vorbis_locator.dart';
import 'opus_format_strategy.dart';
import 'vorbis_comments_codec.dart';

/// Opus-specific audio file implementation with Vorbis Comments metadata support.
///
/// OpusAudioFile extends [PhonicAudioFileImpl] with Opus-specific configuration,
/// including the appropriate format strategy, codec, and locator for handling
/// Vorbis Comments metadata stored in OGG Opus comment header packets.
///
/// ## Supported Containers
///
/// This implementation supports Vorbis Comments as the exclusive metadata format
/// for Opus files:
/// - **Vorbis Comments**: UTF-8 encoded key-value pairs with multi-value support
/// - **OpusTags Packets**: Embedded metadata in OGG Opus stream structure
///
/// ## Container Precedence
///
/// Opus files use only Vorbis Comments for metadata, so there is no precedence
/// hierarchy. All metadata is read from and written to OpusTags packets within
/// the OGG stream structure, following the Opus specification.
///
/// ## Fan-out Policy
///
/// When writing metadata, this implementation targets only Vorbis Comments,
/// as this is the standard and only metadata format supported by the Opus
/// specification.
///
/// ## Usage Examples
///
/// ### Creating from File Bytes
/// ```dart
/// final fileBytes = await File('song.opus').readAsBytes();
/// final opusFile = OpusAudioFile.fromBytes(fileBytes);
///
/// // Read tags
/// final title = opusFile.getTag(TagKey.title);
/// final genres = opusFile.getTags(TagKey.genre);
///
/// // Modify tags
/// opusFile.setTag(TitleTag('New Title'));
/// opusFile.setTag(GenreTag(['Electronic', 'Ambient']));
///
/// // Save changes
/// if (opusFile.isDirty) {
///   final updatedBytes = await opusFile.encode();
///   await File('updated_song.opus').writeAsBytes(updatedBytes);
///   opusFile.markClean();
/// }
/// ```
///
/// ### Working with Multi-Value Fields
/// ```dart
/// // Opus Vorbis Comments natively support multiple values
/// opusFile.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));
///
/// // Each genre is stored as a separate GENRE= field
/// final allTags = opusFile.getAllTags();
/// for (final tag in allTags) {
///   print('${tag.key}: ${tag.value}');
///   print('  Source: ${tag.provenance.containerKind}');
/// }
/// ```
///
/// ### Working with Artwork
/// ```dart
/// // Read existing artwork (if supported by the Opus implementation)
/// final artworkTags = opusFile.getTags(TagKey.artwork);
/// for (final artworkTag in artworkTags) {
///   final artwork = artworkTag as ArtworkTag;
///   print('Artwork type: ${artwork.value.type}');
///   print('MIME type: ${artwork.value.mimeType}');
///
///   // Load image data when needed
///   final imageBytes = await artwork.value.data;
/// }
///
/// // Add new artwork (if supported)
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'Album Cover',
///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
/// );
/// opusFile.setTag(ArtworkTag(artworkData));
/// ```
///
/// ## Memory Management
///
/// The implementation follows the same memory management principles as the base class:
/// - Artwork and large payloads are loaded lazily via OpusTags packet parsing
/// - Container data is cached only when needed for writing
/// - Dispose method releases all cached resources
/// - Efficient memory usage for large Opus collections
///
/// ## Error Handling
///
/// The implementation handles Opus-specific error conditions:
/// - Corrupted OGG signatures and page headers
/// - Invalid Opus page structures or checksums
/// - Malformed OpusTags packets
/// - Encoding errors in UTF-8 text fields
/// - Missing or corrupted OpusHead/OpusTags header packets
///
/// ## Performance Characteristics
///
/// - Fast format detection using OGG signature ("OggS") and OpusHead identification
/// - Efficient OGG page navigation with minimal memory allocation
/// - Lazy loading of artwork via OpusTags packet parsing
/// - Optimized encoding with UTF-8 text handling
/// - Native multi-value support eliminates delimiter parsing overhead
///
/// ## Opus Specification Compliance
///
/// This implementation follows the Opus and OGG specifications for:
/// - OGG page structure parsing and validation
/// - Opus stream header packet identification (OpusHead)
/// - OpusTags packet parsing (similar to Vorbis Comments)
/// - Proper UTF-8 encoding for all text fields
/// - Multi-value field support through separate key=value pairs
/// - Little-endian integer encoding in OGG structures
///
/// ## Thread Safety
///
/// Like the base implementation, OpusAudioFile is not thread-safe. Concurrent
/// access should be synchronized by the caller.
///
/// See also:
/// - [PhonicAudioFileImpl] for the base implementation
/// - [OpusFormatStrategy] for Opus-specific format handling
/// - [VorbisCommentsCodec] for Vorbis Comments parsing
/// - [OggVorbisLocator] for OGG comment packet location and injection
class OpusAudioFile extends PhonicAudioFileImpl {
  /// Creates a new Opus audio file instance from file bytes.
  ///
  /// This constructor initializes the Opus audio file with all necessary
  /// components for handling Vorbis Comments metadata in Opus files. The
  /// configuration includes:
  ///
  /// - **Format Strategy**: [OpusFormatStrategy] for Opus-specific detection
  /// - **Codec**: [VorbisCommentsCodec] for parsing Vorbis Comments
  /// - **Locator**: [OggVorbisLocator] for OGG comment packet extraction/injection
  /// - **Merge Policy**: Configured for Opus (Vorbis-only) rules
  ///
  /// ## Parameters
  ///
  /// - [fileBytes]: The complete Opus file bytes including audio data and metadata
  /// - [isDirty]: Initial dirty state (defaults to false for newly loaded files)
  ///
  /// ## Initialization Process
  ///
  /// 1. Creates Opus-specific format strategy with Vorbis-only precedence
  /// 2. Builds codec registry with VorbisCommentsCodec implementation
  /// 3. Configures OggVorbisLocator for OGG comment packet detection
  /// 4. Sets up merge policy based on the format strategy
  /// 5. Initializes the base implementation with the configured components
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// // Load Opus file
  /// final fileBytes = await File('song.opus').readAsBytes();
  /// final opusFile = OpusAudioFile.fromBytes(fileBytes);
  ///
  /// // File is ready for tag operations
  /// final title = opusFile.getTag(TagKey.title);
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
  /// - OpusTags packets are loaded on-demand during tag operations
  /// - Codec and locator instances are lightweight and shared
  /// - Artwork data uses lazy loading through OpusTags packet parsing
  OpusAudioFile.fromBytes(
    Uint8List fileBytes, {
    bool isDirty = false,
  }) : super(
         fileBytes: fileBytes,
         formatStrategy: const OpusFormatStrategy(),
         codecRegistry: _createOpusCodecRegistry(),
         mergePolicy: MergePolicy.fromStrategy(const OpusFormatStrategy()),
         isDirty: isDirty,
       );

  /// Creates a codec registry configured for Opus files with Vorbis Comments codec and locator.
  ///
  /// This method builds a complete [CodecRegistry] containing the codec
  /// and locator needed for Opus file processing. The registry includes:
  ///
  /// ### Codec
  /// - [VorbisCommentsCodec]: For parsing and encoding Vorbis Comments metadata
  ///
  /// ### Locator
  /// - [OggVorbisLocator]: For detecting and extracting OpusTags packets
  ///
  /// ## Registry Configuration
  ///
  /// The registry is configured specifically for Opus files, which use only
  /// Vorbis Comments for metadata storage. This ensures compatibility with
  /// the Opus specification and provides access to all standard metadata
  /// fields supported by Vorbis Comments.
  ///
  /// ## Performance Considerations
  ///
  /// - The codec instance is stateless and can be safely reused
  /// - The locator instance is lightweight with minimal memory overhead
  /// - Registry lookup operations are optimized for frequent access
  /// - No dynamic loading or reflection is used for maximum performance
  ///
  /// ## Thread Safety
  ///
  /// The returned registry is thread-safe as the contained codec and locator
  /// are stateless. Multiple threads can safely use the same registry instance
  /// for concurrent file processing.
  ///
  /// Returns:
  /// A fully configured [CodecRegistry] with Opus-compatible codec and locator.
  ///
  /// Example usage:
  /// ```dart
  /// final registry = _createOpusCodecRegistry();
  ///
  /// // Find codec for Vorbis Comments
  /// final codec = registry.findCodec(ContainerKind.vorbis, '');
  ///
  /// // Find locator for OGG comment packets
  /// final locator = registry.findLocator(ContainerKind.vorbis);
  /// ```
  static CodecRegistry _createOpusCodecRegistry() {
    return CodecRegistry(
      codecList: [
        // Vorbis Comments codec for Opus metadata
        const VorbisCommentsCodec(),
      ],
      containerLocatorList: [
        // OGG Vorbis locator for OpusTags packet extraction
        OggVorbisLocator(),
      ],
    );
  }
}
