import 'dart:typed_data';

import '../../core/codec_registry.dart';
import '../../core/merge_policy.dart';
import '../../core/phonic_audio_file_impl.dart';
import '../../utils/locators/mp4_locator.dart';
import 'mp4_atoms_codec.dart';
import 'mp4_format_strategy.dart';

/// MP4-specific audio file implementation with MP4 atoms metadata support.
///
/// Mp4AudioFile extends [PhonicAudioFileImpl] with MP4-specific configuration,
/// including the appropriate format strategy, codec, and locator for handling
/// MP4 atoms metadata stored in the ilst container within the MP4 atom hierarchy.
///
/// ## Supported Containers
///
/// This implementation supports MP4 atoms as the exclusive metadata format
/// for MP4 files:
/// - **MP4 Atoms**: iTunes-style atoms with hierarchical structure
/// - **Standard Atoms**: ©nam, ©ART, ©alb, trkn, disk, covr, etc.
/// - **Freeform Atoms**: ----:domain:name format for custom metadata
///
/// ## Container Precedence
///
/// MP4 files use only MP4 atoms for metadata, so there is no precedence
/// hierarchy. All metadata is read from and written to iTunes-style atoms
/// within the moov.udta.meta.ilst atom hierarchy.
///
/// ## Fan-out Policy
///
/// When writing metadata, this implementation targets only MP4 atoms,
/// as this is the standard and only metadata format supported by the MP4
/// specification for audio metadata.
///
/// ## Usage Examples
///
/// ### Creating from File Bytes
/// ```dart
/// final fileBytes = await File('song.mp4').readAsBytes();
/// final mp4File = Mp4AudioFile.fromBytes(fileBytes);
///
/// // Read tags
/// final title = mp4File.getTag(TagKey.title);
/// final genres = mp4File.getTags(TagKey.genre);
///
/// // Modify tags
/// mp4File.setTag(TitleTag('New Title'));
/// mp4File.setTag(GenreTag(['Electronic', 'Ambient']));
///
/// // Save changes
/// if (mp4File.isDirty) {
///   final updatedBytes = await mp4File.encode();
///   await File('updated_song.mp4').writeAsBytes(updatedBytes);
///   mp4File.markClean();
/// }
/// ```
///
/// ### Working with Multi-Value Fields
/// ```dart
/// // MP4 uses semicolon-separated strings for multiple genres
/// mp4File.setTag(GenreTag(['Rock', 'Alternative', 'Indie']));
///
/// // Stored as: "Rock;Alternative;Indie" in ©gen atom
/// final allTags = mp4File.getAllTags();
/// for (final tag in allTags) {
///   print('${tag.key}: ${tag.value}');
///   print('  Source: ${tag.provenance.containerKind}');
/// }
/// ```
///
/// ### Working with Artwork
/// ```dart
/// // Read existing artwork
/// final artworkTags = mp4File.getTags(TagKey.artwork);
/// for (final artworkTag in artworkTags) {
///   final artwork = artworkTag as ArtworkTag;
///   print('Artwork type: ${artwork.value.type}');
///   print('MIME type: ${artwork.value.mimeType}');
///
///   // Load image data when needed
///   final imageBytes = await artwork.value.data;
/// }
///
/// // Add new artwork
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'Album Cover',
///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
/// );
/// mp4File.setTag(ArtworkTag(artworkData));
/// ```
///
/// ### Working with Track and Disc Numbers
/// ```dart
/// // MP4 uses binary format for track/disc numbers
/// mp4File.setTag(TrackNumberTag(5));  // Stored as binary in trkn atom
/// mp4File.setTag(DiscNumberTag(2));   // Stored as binary in disk atom
///
/// // BPM and rating also use specific formats
/// mp4File.setTag(BpmTag(128));        // 16-bit integer in tmpo atom
/// mp4File.setTag(RatingTag(85));      // 8-bit integer in rtng atom
/// ```
///
/// ## Memory Management
///
/// The implementation follows the same memory management principles as the base class:
/// - Artwork and large payloads are loaded lazily via covr atom parsing
/// - Container data is cached only when needed for writing
/// - Dispose method releases all cached resources
/// - Efficient memory usage for large MP4 collections
///
/// ## Error Handling
///
/// The implementation handles MP4-specific error conditions:
/// - Corrupted MP4 signatures and atom headers
/// - Invalid atom sizes or hierarchical structure
/// - Malformed ilst atom containers
/// - Encoding errors in text atoms
/// - Missing or corrupted moov.udta.meta.ilst hierarchy
///
/// ## Performance Characteristics
///
/// - Fast format detection using MP4 ftyp atom and brand validation
/// - Efficient atom hierarchy navigation with minimal memory allocation
/// - Lazy loading of artwork via covr atom parsing
/// - Optimized encoding with UTF-8 text handling and binary number formats
/// - Type-aware atom parsing eliminates unnecessary conversions
///
/// ## MP4 Specification Compliance
///
/// This implementation follows the ISO/IEC 14496-12 and iTunes specifications for:
/// - File type box (ftyp) detection and brand validation
/// - Atom header parsing with big-endian integer encoding
/// - Hierarchical atom navigation (moov.udta.meta.ilst)
/// - iTunes-style metadata atom conventions
/// - UTF-8 encoding for all text atoms
/// - Binary formats for track/disc numbers, BPM, and ratings
/// - Multiple artwork support through covr atoms
///
/// ## Thread Safety
///
/// Like the base implementation, Mp4AudioFile is not thread-safe. Concurrent
/// access should be synchronized by the caller.
///
/// See also:
/// - [PhonicAudioFileImpl] for the base implementation
/// - [Mp4FormatStrategy] for MP4-specific format handling
/// - [Mp4AtomsCodec] for MP4 atoms parsing
/// - [Mp4Locator] for ilst atom location and injection
class Mp4AudioFile extends PhonicAudioFileImpl {
  /// Creates a new MP4 audio file instance from file bytes.
  ///
  /// This constructor initializes the MP4 audio file with all necessary
  /// components for handling MP4 atoms metadata in MP4 files. The
  /// configuration includes:
  ///
  /// - **Format Strategy**: [Mp4FormatStrategy] for MP4-specific detection
  /// - **Codec**: [Mp4AtomsCodec] for parsing MP4 atoms
  /// - **Locator**: [Mp4Locator] for ilst atom extraction/injection
  /// - **Merge Policy**: Configured for MP4 (atoms-only) rules
  ///
  /// ## Parameters
  ///
  /// - [fileBytes]: The complete MP4 file bytes including audio data and metadata
  /// - [isDirty]: Initial dirty state (defaults to false for newly loaded files)
  ///
  /// ## Initialization Process
  ///
  /// 1. Creates MP4-specific format strategy with atoms-only precedence
  /// 2. Builds codec registry with Mp4AtomsCodec implementation
  /// 3. Configures Mp4Locator for ilst atom detection
  /// 4. Sets up merge policy based on the format strategy
  /// 5. Initializes the base implementation with the configured components
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// // Load MP4 file
  /// final fileBytes = await File('song.mp4').readAsBytes();
  /// final mp4File = Mp4AudioFile.fromBytes(fileBytes);
  ///
  /// // File is ready for tag operations
  /// final title = mp4File.getTag(TagKey.title);
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
  /// - Atom hierarchy is navigated on-demand during tag operations
  /// - Codec and locator instances are lightweight and shared
  /// - Artwork data uses lazy loading through covr atom parsing
  Mp4AudioFile.fromBytes(
    Uint8List fileBytes, {
    super.isDirty,
  }) : super(
         fileBytes: fileBytes,
         formatStrategy: const Mp4FormatStrategy(),
         codecRegistry: _createMp4CodecRegistry(),
         mergePolicy: MergePolicy.fromStrategy(const Mp4FormatStrategy()),
       );

  /// Creates a codec registry configured for MP4 files with MP4 atoms codec and locator.
  ///
  /// This method builds a complete [CodecRegistry] containing the codec
  /// and locator needed for MP4 file processing. The registry includes:
  ///
  /// ### Codec
  /// - [Mp4AtomsCodec]: For parsing and encoding MP4 atoms metadata
  ///
  /// ### Locator
  /// - [Mp4Locator]: For detecting and extracting ilst atoms
  ///
  /// ## Registry Configuration
  ///
  /// The registry is configured specifically for MP4 files, which use only
  /// MP4 atoms for metadata storage. This ensures compatibility with
  /// the MP4 specification and provides access to all standard metadata
  /// fields supported by iTunes-style atoms.
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
  /// A fully configured [CodecRegistry] with MP4-compatible codec and locator.
  ///
  /// Example usage:
  /// ```dart
  /// final registry = _createMp4CodecRegistry();
  ///
  /// // Find codec for MP4 atoms
  /// final codec = registry.findCodec(ContainerKind.mp4, '');
  ///
  /// // Find locator for ilst atoms
  /// final locator = registry.findLocator(ContainerKind.mp4);
  /// ```
  static CodecRegistry _createMp4CodecRegistry() {
    return CodecRegistry(
      codecList: [
        // MP4 atoms codec for ilst metadata
        const Mp4AtomsCodec(),
      ],
      containerLocatorList: [
        // MP4 locator for ilst atom extraction
        Mp4Locator(),
      ],
    );
  }
}
